{ flake, config, lib, pkgs, ... }:

let
  b64 = import (flake.inputs.self + /modules/nixos/common/b64.nix) { inherit lib; };
  # Base64-encoded hardware identifiers (decoded at eval time)
  rootFsUuid = b64.decode "MDhkOWFiZWYtYTQyMC00OTA5LTkyZDYtZGI0YWNjNzNkMmQw";
  efiUuid = b64.decode "NkE4QS0zNUIy";
in
{
  boot = {
    kernelParams = [
      "console=ttyS0,115200n8"
      "console=tty0"
    ];
    loader.systemd-boot.enable = true;
    loader.efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/efi";
    };
    initrd.availableKernelModules = [ "sd_mod" "ahci" "ata_piix" "virtio_pci" "xen_blkfront" "hv_storvsc" "vmw_pvscsi" ];
    initrd.kernelModules = [ ];
    extraModulePackages = [ ];
  };

  # Filesystems (UUIDs base64-encoded to avoid exposing hardware identifiers)
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/" + rootFsUuid;
    fsType = "ext4";
  };

  fileSystems."/efi" = {
    device = "/dev/disk/by-uuid/" + efiUuid;
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [{ device = "/swapfile"; size = 1195; }];

  # Network: systemd-networkd with DHCP
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = true;
  };

  networking.usePredictableInterfaceNames = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  virtualisation.hypervGuest.enable = true;
}