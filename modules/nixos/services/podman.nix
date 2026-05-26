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
    dockerCompat = true;
    dockerSocket.enable = true;
  };

  virtualisation.containers.storage.settings.storage =
    lib.mkIf isRootZfs { driver = "zfs"; };

  # rootful 模式下使用 docker 组访问 /var/run/docker.sock
  users.extraGroups.docker.members = config.myusers;
}
