# Sing-box configuration with sops template
{ config, lib, flake, pkgs, ... }:
let
  hostName = config.networking.hostName;
  hostNameLower = lib.strings.toLower hostName;
  enableByHost = !(lib.strings.hasInfix "nas" hostNameLower || lib.strings.hasInfix "wsl" hostNameLower);
  configKey = "singbox-config";
  hostSuffix = lib.strings.toLower (lib.strings.removePrefix "Msk" hostName);
  secretsFile = flake.inputs.self + /secrets/sing-box-config.yaml;
in
{
  disabledModules = [ "services/networking/sing-box.nix" ];
  imports = [
    (flake.inputs.nixpkgs-unstable + "/nixos/modules/services/networking/sing-box.nix")
  ];

  config = lib.mkIf enableByHost {
    sops.secrets.${configKey} = {
      sopsFile = secretsFile;
    };

    services.sing-box = {
      enable = true;
    };

    systemd.services.sing-box.serviceConfig.ExecStartPre =
      let
        script = pkgs.writeShellScript "sing-box-prestart" ''
          set -euo pipefail
          src=${config.sops.templates."sing-box-config".path}
          dst=/run/sing-box/config.json
          tag=${lib.escapeShellArg hostSuffix}
          ${pkgs.gnused}/bin/sed "s/__HOST_TAG__/$tag/g" "$src" > "$dst"
          ${pkgs.coreutils}/bin/chown sing-box:sing-box "$dst"
          ${pkgs.coreutils}/bin/chmod 600 "$dst"
        '';
      in
      lib.mkForce "+${script}";

    systemd.tmpfiles.rules = [
      "d /var/cache/acme 0750 sing-box sing-box -"
    ];

    sops.templates."sing-box-config" = {
      content = lib.strings.replaceStrings
        [ "__HOST_TAG__" ]
        [ hostSuffix ]
        config.sops.placeholder.${configKey};
      path = "/run/secrets/sing-box.json";
      mode = "0600";
      restartUnits = [ "sing-box.service" ];
    };
  };
}
