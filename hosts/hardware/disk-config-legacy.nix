# Legacy BIOS disk config for la (QEMU/KVM, GRUB EF02).
#
# Layout:
#   EF02 (1M, BIOS boot partition for GRUB embedding)
#   boot (vfat, 400M) → /boot
#   swap (2G)
#   btrfs (100%) with subvolumes:
#     @persist          → /persist
#     @persist/nix      → /nix
#     @persist/var      → /var
{ lib, ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = lib.mkDefault "/dev/vda";
      content = {
        type = "gpt";
        partitions = {
          # 1MB BIOS boot partition for GRUB embedding (no --force needed)
          bios = {
            size = "1M";
            type = "EF02";
          };
          boot = {
            size = "400M";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
          swap = {
            size = "2G";
            content = {
              type = "swap";
            };
          };
          btrfs = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "@persist" = {
                  mountpoint = "/persist";
                  mountOptions = [ "compress=zstd" ];
                };
                "@persist/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [ "compress=zstd" "noatime" ];
                };
                "@persist/var" = {
                  mountpoint = "/var";
                  mountOptions = [ "compress=zstd" ];
                };
              };
            };
          };
        };
      };
    };
  };

  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var".neededForBoot = true;
  fileSystems."/boot".neededForBoot = true;
}
