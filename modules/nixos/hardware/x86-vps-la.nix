{ flake, config, lib, pkgs, modulesPath, ... }:

let
  b64 = import (flake.inputs.self + /modules/nixos/common/b64.nix) { inherit lib; };
  # Base64-encoded hardware identifiers (decoded at eval time)
  rootFsUuid = b64.decode "YmMwZDI4NzQtZjYwNC00ZmZmLWFlOGEtMzE2YjI4ZWE1ZDVh";
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    kernelModules = [ "kvm-intel" ];
    loader.grub = {
      enable = true;
      device = "/dev/vda";
    };
    initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_blk" "ahci" "xen_blkfront" "vmw_pvscsi" ];
    initrd.kernelModules = [ ];
    extraModulePackages = [ ];
  };

  # Filesystems (UUID base64-encoded to avoid exposing hardware identifiers)
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/" + rootFsUuid;
    fsType = "ext4";
  };

  swapDevices = [
    { device = "/swapfile"; size = 1076; }
  ];

  # Network: systemd-networkd with static IPs from sops drop-in
  # Static addresses and gateways come from sops template at:
  # /run/systemd/network/10-uplink.network.d/addresses.conf
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "eth0";
    networkConfig.DNS = [ "1.1.1.1" "8.8.8.8" "2606:4700:4700::1111" "2001:4860:4860::8888" ];
  };

  networking.usePredictableInterfaceNames = false;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}