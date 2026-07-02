# Standalone home-manager configurations for non-NixOS containers.
# Auto-discovers users from home/users/*/ and profiles from each user dir.
# Generates homeConfigurations.<user>-<profile> for every <user>/<profile>.nix found.
{ inputs, lib, ... }:
let
  inherit (inputs) self;

  mkHome = modules: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    inherit modules;
    extraSpecialArgs = { inherit inputs; flake = { inherit inputs; }; };
  };

  usersDir = self + /home/users;
  userNames = builtins.attrNames (builtins.readDir usersDir);

  # For each user, list available profiles (files in their dir, minus .nix suffix).
  profilesOf = user:
    let
      dir = usersDir + "/${user}";
      files = builtins.attrNames (builtins.readDir dir);
      nixFiles = builtins.filter (f: lib.hasSuffix ".nix" f) files;
      profileNames = map (f: lib.removeSuffix ".nix" f) nixFiles;
    in profileNames;

  # Generate homeConfigurations: <user>-<profile> for every combination.
  # user and profile are captured directly in the closure — no string parsing.
  homeConfigurations = lib.foldl' (acc: user:
    acc // builtins.listToAttrs (map (profile: {
      name = "${user}-${profile}";
      value = mkHome [
        self.homeModules.default
        (usersDir + "/${user}/${profile}.nix")
      ];
    }) (profilesOf user))
  ) {} userNames;
in
{
  flake.homeConfigurations = homeConfigurations;
}
