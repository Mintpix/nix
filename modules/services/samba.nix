{ config, lib, ... }:

{
  services.samba = {
    enable = true;

    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "NixOS Samba Server";
        "security" = "user";
        "include" = config.sops.templates."samba-hosts-allow-conf".path;
      };

      "public" = {
        "path" = "/npool";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "mp";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "nobody";
        "force group" = "nogroup";
      };
    };
  };

  # NTLM hash (irreversible). Generate: printf '%s' "$pw" | iconv -t UTF-16LE | openssl dgst -md4
  systemd.services.samba-set-mp-password = {
    after = [ "samba.target" "sops-nix.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      nt_hash=$(cat ${config.sops.secrets."samba-mp-nt-hash".path})
      # Create user if missing, then set NT hash directly
      ${config.services.samba.package}/bin/pdbedit -L -u mp >/dev/null 2>&1 || \
        printf '\n\n' | ${config.services.samba.package}/bin/smbpasswd -s -a mp
      ${config.services.samba.package}/bin/pdbedit -u mp --set-nt-hash="$nt_hash"
    '';
  };

  sops.templates."samba-hosts-allow-conf" = {
    content = ''
      hosts allow = ${config.sops.placeholder."samba-hosts-allow"}
    '';
    path = "/run/secrets/samba-hosts-allow-conf";
    mode = "0644";
  };
}
