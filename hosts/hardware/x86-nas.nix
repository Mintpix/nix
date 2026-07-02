# NAS hardware: ASPEED AST2000 BMC + AMD Renoir APU, btrfs mirror root, ZFS npool.
#
# Root: btrfs RAID1 mirror across two NVMe drives (replaces old ZFS rpool).
# ZFS: npool retained as encrypted data pool (not root).
{ flake, lib, pkgs, modulesPath, ... }:
let
  inherit (flake) inputs;
  b64 = import (flake.inputs.self + /modules/lib/b64.nix) { inherit lib; };
  disk1Id = b64.decode "bnZtZS1TT0xJRElHTV9TU0RQRktLVzAxMFg3X1NZQzFOMDI1MjEwOTAyMjFY";
  disk2Id = b64.decode "bnZtZS1TT0xJRElHTV9TU0RQRktLVzAxMFg3X1NZQzFOMDI1MjE1NTAyMjNJ";

  # NAS firmware: ASPEED BMC + AMD Renoir APU
  nasFirmware = pkgs.runCommand "nas-firmware" { } ''
    mkdir -p $out/lib/firmware/amdgpu
    find ${pkgs.linux-firmware}/lib/firmware -name ast_dp501_fw.bin -exec cp {} $out/lib/firmware/ \;
    find ${pkgs.linux-firmware}/lib/firmware/amdgpu -name 'renoir_*.bin' -exec cp {} $out/lib/firmware/amdgpu/ \;
    find ${pkgs.linux-firmware}/lib/firmware/amdgpu -name 'green_sardine_*.bin' -exec cp {} $out/lib/firmware/amdgpu/ \;
    cp -r ${pkgs.linux-firmware}/lib/firmware/amd-ucode $out/lib/firmware/
  '';
in
{
  imports = [
    inputs.disko.nixosModules.disko
    (modulesPath + "/installer/scan/not-detected.nix")
    ./systemd-boot.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.blacklistedKernelModules = [ "snd_hda_intel" ];

  hardware.firmware = [ nasFirmware ];
  hardware.cpu.amd.updateMicrocode = lib.mkForce true;

  # === btrfs RAID1 mirror root (replaces old ZFS rpool) ===
  # disko processes disks in alphabetical order. The plain partition disk (main1)
  # must be created BEFORE the RAID disk (main2), because main2's extraArgs
  # references main1's partition. Hence main1 < main2 alphabetically.
  # partlabels: disk-main1-btrfs2 (plain), disk-main2-btrfs (RAID1)
  disko.devices = {
    disk.main1 = {
      type = "disk";
      device = "/dev/disk/by-id/" + disk2Id;
      content = {
        type = "gpt";
        partitions = {
          ESP1 = {
            size = "300M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/efi1";
            };
          };
          btrfs2 = {
            size = "100%";
            # Plain partition — no content type, no formatting.
            # disk.main2's btrfs RAID1 picks up this partition via extraArgs.
          };
        };
      };
    };
    disk.main2 = {
      type = "disk";
      device = "/dev/disk/by-id/" + disk1Id;
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
              extraArgs = [ "-f" "-d raid1" "-m raid1" "/dev/disk/by-partlabel/disk-main1-btrfs2" ];
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
                # archbox: Arch Linux nspawn container (ephemeral root + persistent home)
                "@persist/archbox/root" = {
                  mountpoint = null;
                };
                "@persist/archbox/persist" = {
                  mountpoint = null;
                };

              };
            };
          };
        };
      };
    };
  };

  # EFI mirror sync (activation script)
  system.activationScripts.syncEfiMirror = {
    text = ''
      if mountpoint -q /efi1; then
        ${pkgs.rsync}/bin/rsync -a --delete /efi/ /efi1/
      else
        echo "Warning: /efi1 is not mounted, skipping EFI sync." >&2
      fi
    '';
  };

  # Mount critical paths early
  fileSystems."/nix".neededForBoot = true;
  fileSystems."/persist".neededForBoot = true;
  fileSystems."/var".neededForBoot = true;
  fileSystems."/efi".neededForBoot = true;
  fileSystems."/efi1".neededForBoot = true;

  # === archbox: Arch Linux nspawn container ===
  # @persist/archbox/root: pacstrap Arch rootfs (ephemeral snapshot source)
  # @persist/archbox/persist: mp user persistent data (home-manager, nix, .ssh)
  fileSystems."/var/lib/archbox/root" = {
    device = "/dev/disk/by-partlabel/disk-main2-btrfs";
    fsType = "btrfs";
    options = [ "subvol=@persist/archbox/root" "compress=zstd" ];
    neededForBoot = false;
  };
  fileSystems."/var/lib/archbox/persist" = {
    device = "/dev/disk/by-partlabel/disk-main2-btrfs";
    fsType = "btrfs";
    options = [ "subvol=@persist/archbox/persist" "compress=zstd" ];
    neededForBoot = false;
  };

  # === ZFS npool: encrypted data pool (not root) ===
  # boot.supportedFilesystems triggers boot.zfs.enabled (read-only), which builds
  # the ZFS kernel module, installs zfs userspace, and generates zfs-import-*.services.
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs = {
    requestEncryptionCredentials = false;
    extraPools = [ "npool" ];
  };
  systemd.services.zfs-load-npool-key = {
    description = "Load npool encryption key";
    after = [ "zfs-import-npool.service" "persist-persist.mount" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    unitConfig.RequiresMountsFor = [ "/persist" ];
    path = [ pkgs.zfs ];
    script = ''
      # Key may already be loaded (e.g. during activate without reboot)
      zfs load-key npool < /persist/etc/zfs/npool.key 2>/dev/null || true
      zfs mount npool 2>/dev/null || true
    '';
  };
}
