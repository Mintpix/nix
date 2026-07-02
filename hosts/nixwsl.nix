{ flake, lib, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    flake.inputs.nixos-wsl.nixosModules.wsl
    (flake.inputs.self + /modules/services/podman.nix)
    (flake.inputs.self + /modules/services/opencode.nix)
  ];

  homeProfile = "dev";

  # WSL: no sops, users managed by Windows interop
  users.mutableUsers = lib.mkForce true;

  wsl = {
    enable = true;
    defaultUser = "mp";
    interop.register = true;
    wslConf.interop = {
      enabled = true;
      appendWindowsPath = false;
    };
  };

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "nixwsl";
}
