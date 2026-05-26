{ flake, config, lib, pkgs, modulesPath, ... }:

let
  b64 = import (flake.inputs.self + /modules/nixos/common/b64.nix) { inherit lib; };
  # Base64-encoded hardware identifiers (decoded at eval time)
  disk1Id = b64.decode "bnZtZS1TT0xJRElHTV9TU0RQRktLVzAxMFg3X1NZQzFOMDI1MjEwOTAyMjFY";
  disk2Id = b64.decode "bnZtZS1TT0xJRElHTV9TU0RQRktLVzAxMFg3X1NZQzFOMDI1MjE1NTAyMjNJ";
in
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  disko.devices = {
    disk.disk1 = {
      type = "disk";
      device = "/dev/disk/by-id/" + disk1Id;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/efi";
              mountOptions = [ "fmask=0077" "dmask=0077" ];
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };
    # Secondary disk
    disk.disk2 = {
      type = "disk";
      device = "/dev/disk/by-id/" + disk2Id;
      content = {
        type = "gpt";
        partitions = {
          # Reserve ESP on secondary disk for backup
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/efi1";
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };
    zpool.rpool = {
      type = "zpool";
      mode = "mirror"; # Mirror mode for redundancy
      options = {
        ashift = "12";
        autotrim = "on";
        autoexpand = "on";
        autoreplace = "on";
      };
      rootFsOptions = {
        relatime = "on";
        acltype = "posixacl";
        canmount = "off";
        compression = "lz4";
        dnodesize = "auto";
        normalization = "formD";
        xattr = "sa";
        mountpoint = "/";
      };
      datasets = {
        root = {
          type = "zfs_fs";
          mountpoint = "/";
        };
        nix = {
          type = "zfs_fs";
          mountpoint = "/nix";
        };
        "var/log" = {
          type = "zfs_fs";
          mountpoint = "/var/log";
          options.compression = "zstd";
        };
        "var/cache" = {
          type = "zfs_fs";
          mountpoint = "/var/cache";
        };
        "home" = {
          type = "zfs_fs";
          mountpoint = "/home";
        };
        "home/root" = {
          type = "zfs_fs";
          mountpoint = "/root";
        };
      };
    };
  };

}

