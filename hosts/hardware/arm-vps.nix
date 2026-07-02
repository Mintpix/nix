# ARM VPS hardware: QEMU guest, UEFI, btrfs root.
{ flake, lib, pkgs, modulesPath, ... }:
{
  imports = [
    flake.inputs.disko.nixosModules.disko
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config-uefi.nix
    ./systemd-boot.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot.initrd.availableKernelModules = [ "xhci_pci" "virtio_pci" "virtio_scsi" "usbhid" ];
  networking.useDHCP = lib.mkDefault true;
}
