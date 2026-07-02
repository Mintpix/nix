# Podman container engine.
# Storage driver and /var/lib/containers mount are left to individual hosts
# to avoid reading config.fileSystems (which can cause infinite recursion).
{ config, lib, ... }:
{
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
  };

  # Add all non-root discovered users to docker group (for podman socket access)
  users.extraGroups.docker.members =
    builtins.filter (name: name != "root") config.discoveredUsers;
}
