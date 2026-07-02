{ flake, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    flake.inputs.self.nixosModules.server
    flake.inputs.self.nixosModules.impermanence
    (flake.inputs.self + /modules/impermanence.nix)
    (flake.inputs.self + /hosts/hardware/arm-vps.nix)
    (flake.inputs.self + /modules/services/easytier.nix)
    (flake.inputs.self + /modules/services/sing-box.nix)
    (flake.inputs.self + /modules/services/safe-gc.nix)
  ];

  homeProfile = "server";
  safe-gc.enable = true;

  easytier_center = true;
  networking.hostName = "Mskos";
}
