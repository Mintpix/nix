# User configuration — passwords from sops, SSH keys via sops templates
{ flake, pkgs, lib, config, ... }:
{
  users.mutableUsers = false;
  users.users.mp = {
    isNormalUser = true;
    shell = pkgs.zsh;
    hashedPasswordFile = config.sops.secrets."user-password-hash".path;
    extraGroups = [ "wheel" ];
  };
  users.users.root = {
    hashedPasswordFile = config.sops.secrets."root-password-hash".path;
  };

  # SSH authorized_keys rendered by sops templates — the consumer of ssh-authorized-key
  sops.templates = {
    "ssh-authorized-keys-mp" = {
      content = config.sops.placeholder."ssh-authorized-key";
      path = "/etc/ssh/authorized_keys.d/mp";
      mode = "0440";
      owner = "mp";
      group = "users";
    };
    "ssh-authorized-keys-root" = {
      content = config.sops.placeholder."ssh-authorized-key";
      path = "/etc/ssh/authorized_keys.d/root";
      mode = "0600";
      owner = "root";
      group = "root";
    };
  };
}