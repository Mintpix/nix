{ flake, pkgs, ... }:
{
  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl
    flake.inputs.self.nixosModules.default
    (flake.inputs.self + /modules/nixos/services/podman.nix)
    (flake.inputs.self + /modules/nixos/services/opencode.nix)
  ];

  wsl = {
    enable = true;
    defaultUser = "mp";
    interop.register = true;
    wslConf.interop = {
      enabled = true;
      appendWindowsPath = false;
    };
  };

  users.users.mp = {
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "nixwsl";
  environment.systemPackages = with pkgs; [
    nodejs_22
    nodePackages.npm
  ];
}
