# Unified btrfs disk config for all UEFI machines (cc/os/se/sg/nas).
#
# Layout:
#   ESP (vfat, 300M) → /efi
#   btrfs (100%) with subvolumes:
#     @persist          → /persist
#     @persist/nix      → /nix
#     @persist/var      → /var
#
# NAS overrides this with a mirror (see hosts/hardware/x86-nas.nix).
# la uses disk-config-legacy.nix instead (BIOS + EF02).
#
# /var/lib/containers and /var/lib/nixos-containers are separate subvols
# that shadow @persist/var (declared per-host as needed).
{ lib, ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "300M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/efi";
              mountOptions = [ "fmask=0077" "dmask=0077" ];
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

  # Mount critical paths early (before activation).
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var".neededForBoot = true;
  fileSystems."/efi".neededForBoot = true;
}
