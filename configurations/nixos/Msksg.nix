{ flake, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    (flake.inputs.self + /modules/nixos/services/server.nix)
    (flake.inputs.self + /modules/nixos/hardware/x86-vps-sg.nix)
    (flake.inputs.self + /modules/nixos/services/easytier.nix)
  ];
  networking.hostName = "Msksg";
}
