# Users: passwords and SSH keys via sops.
# All discovered users share the same password hash and SSH authorized key.
# Uses mkDefault so containers (e.g. box) can override with bind-mounted paths.
# sops templates only rendered when sops is actually available.
{ flake, pkgs, lib, config, options, ... }:
let
  sopsAvailable = options ? sops;
  users = config.discoveredUsers;
in
{
  config = {
    users.mutableUsers = false;

    # Each user: isNormalUser (except root), shell, extraGroups, password.
    # All users share the same password hash and SSH key.
    users.users = lib.genAttrs users (name: {
      isNormalUser = lib.mkDefault (name != "root");
      shell = pkgs.zsh;
      extraGroups = lib.mkDefault [ "wheel" ];
      hashedPasswordFile = lib.mkIf sopsAvailable
        (lib.mkDefault config.sops.secrets."user-password-hash".path);
    });
  } // lib.optionalAttrs sopsAvailable {
    # SSH authorized_keys for each user (shared key).
    sops.templates = lib.listToAttrs (map (name: {
      name = "ssh-authorized-keys-${name}";
      value = {
        content = config.sops.placeholder."ssh-authorized-key";
        path = "/etc/ssh/authorized_keys.d/${name}";
        mode = if name == "root" then "0600" else "0440";
        owner = name;
        group = if name == "root" then "root" else "users";
      };
    }) users);
  };
}
