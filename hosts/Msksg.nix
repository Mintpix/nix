# sg: Hyper-V Gen2 (EFI) VPS, btrfs root.
{ flake, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    flake.inputs.self.nixosModules.server
    flake.inputs.self.nixosModules.impermanence
    (flake.inputs.self + /modules/impermanence.nix)
    (flake.inputs.self + /hosts/hardware/x86-vps.nix)
    (flake.inputs.self + /hosts/hardware/disk-config-uefi.nix)
    (flake.inputs.self + /hosts/hardware/systemd-boot.nix)
    (flake.inputs.self + /modules/services/easytier.nix)
    (flake.inputs.self + /modules/services/sing-box.nix)
    (flake.inputs.self + /modules/services/safe-gc.nix)
  ];

  homeProfile = "server";
  safe-gc.enable = true;

  # Hyper-V 驱动
  boot.initrd.availableKernelModules = [ "sd_mod" "hv_storvsc" ];
  boot.kernelParams = [ "console=ttyS0,115200n8" "console=tty0" ];

  virtualisation.hypervGuest.enable = true;

  # 网络：DHCP
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = true;
  };

  networking.hostName = "Msksg";
}
