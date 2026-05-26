{ config, lib, ... }:

{
  services.samba = {
    enable = true;

    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "NixOS Samba Server";
        "security" = "user";
        "map to guest" = "Bad User";
        "guest account" = "nobody";
        "include" = config.sops.templates."samba-hosts-allow-conf".path;
      };

      "public" = {
        "path" = "/npool";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "nobody";
        "force group" = "nogroup";
      };
    };
  };

  # Samba hosts allow — the consumer of samba-hosts-allow secret
  sops.templates."samba-hosts-allow-conf" = {
    content = ''
      hosts allow = ${config.sops.placeholder."samba-hosts-allow"}
    '';
    path = "/run/secrets/samba-hosts-allow-conf";
    mode = "0644";
  };
}