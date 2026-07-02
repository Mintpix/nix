# btrbk: btrfs subvolume snapshot management.
# Replaces sanoid for btrfs volumes. NAS runs both: btrbk for btrfs, sanoid for ZFS.
#
# Snapshots @persist, @var (the PERSIST + SNAP group).
# Does NOT snapshot @nix, @containers, @nixos-containers, @box-nix, @box-persist (NO SNAP group).
{ ... }:
{
  # Ensure snapshot_dir exists (btrbk requires it before running)
  systemd.tmpfiles.rules = [ "d /persist/.btrbk/snapshots 0755 root root -" ];

  services.btrbk.instances."persist" = {
    onCalendar = "*-01,04,07,10-01 00:00:00";
    settings = {
      timestamp_format = "long";
      snapshot_dir = "/persist/.btrbk/snapshots";
      snapshot_preserve = "36m";
      snapshot_preserve_min = "4m";

      # Snapshot the btrfs root subvolumes
      subvolume."/persist" = { };
      subvolume."/var" = { };
    };
  };
}
