# Stateless NixOS: ephemeral root + impermanence.
#
# Two modes:
#   - tmpfsRoot = true  (default, bare-metal/VPS): tmpfs as /
#   - tmpfsRoot = false (nspawn container): nspawn ephemeral handles /,
#     impermanence binds /var etc. to /persist
#
# Requires:
#   - A persistent btrfs subvol or bind mount at /persist (neededForBoot = true)
#   - impermanence nixosModule imported
#   - home-manager impermanence module (auto-loaded)
{ lib, config, flake, ... }:
let
  commonUserDirs = [
    ".ssh"
    ".cache"
    ".local"
  ];
in
{
  options.impermanence.tmpfsRoot = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Mount tmpfs as / (disable for containers using nspawn ephemeral)";
  };

  config = {
    # tmpfs root: wiped on every boot (bare-metal/VPS only).
    fileSystems."/" = lib.mkIf config.impermanence.tmpfsRoot {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=755" ];
    };

    # System-level persistent files + per-user dirs.
    environment.persistence."/persist" = {
      hideMounts = true;
      files = [
        "/etc/machine-id"
        "/etc/adjtime"
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ] ++ lib.optional config.boot.zfs.enabled "/etc/zfs/zpool.cache";

      # Bare-metal: /var is a btrfs subvol (already persistent), don't bind.
      # Container: /var is on ephemeral root, must bind to /persist.
      directories = lib.optionals (!config.impermanence.tmpfsRoot) [
        "/var"
      ];

      users = lib.genAttrs config.discoveredUsers (_: {
        directories = commonUserDirs;
      });
    };

    # Extra user persistent dirs (vscode-server etc.)
    home-manager.sharedModules = [
      (flake.inputs.self + /home/modules/persist.nix)
    ];
  };
}
