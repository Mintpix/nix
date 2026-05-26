{ config, lib, ... }:
let
  isRootZfs = lib.any
    (fs: fs.mountPoint == "/" && fs.fsType == "zfs")
    (lib.attrValues config.fileSystems);
in
{
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.containers.storage.settings.storage =
    lib.mkIf isRootZfs { driver = "zfs"; };

  users.extraGroups.podman.members = config.myusers;
}
