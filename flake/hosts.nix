# Scan hosts/*.nix → nixosConfigurations. Zero hostnames hardcoded.
# Each host file imports its own base modules + hardware + services.
{ inputs, lib, ... }:
let
  inherit (inputs) self;
  hostsDir = self + /hosts;

  # Auto-discover hosts: every .nix in hosts/ (excluding hardware/ subdir).
  # Strip .nix suffix so attr key = hostname (e.g. "Mskcc", not "Mskcc.nix").
  hostFiles = lib.mapAttrs'
    (name: _: lib.nameValuePair (lib.removeSuffix ".nix" name) name)
    (lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".nix" name)
      (builtins.readDir hostsDir));

  mkNixos = filename: inputs.nixpkgs.lib.nixosSystem {
    modules = [ (hostsDir + "/${filename}") ];
    specialArgs = { inherit inputs; flake = { inherit inputs; }; };
  };
in
{
  flake.nixosConfigurations = lib.mapAttrs (_: filename: mkNixos filename) hostFiles;
}
