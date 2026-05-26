{ flake, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    (flake.inputs.self + /modules/nixos/services/server.nix)
    (flake.inputs.self + /modules/nixos/hardware/arm-vps/default.nix)
    (flake.inputs.self + /modules/nixos/services/easytier.nix)
  ];
  networking.hostName = "Mskse";
}
