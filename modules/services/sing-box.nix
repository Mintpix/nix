# sing-box: per-host config from sops, unstable 1.12 package.
# Uses nixpkgs module for boilerplate; injects sops-based config.
# __HOST_TAG__ replacement must happen at activation time (after sops
# decrypts), so it's done in ExecStartPre via sed — not in sops.templates
# (replaceStrings on a placeholder marker is a no-op at eval time).
{ config, lib, flake, pkgs, ... }:
let
  inherit (lib) mkIf mkForce;
  inherit (lib.strings) toLower hasInfix removePrefix;

  hostName = config.networking.hostName;
  enable = !(hasInfix "nas" (toLower hostName) || hasInfix "wsl" (toLower hostName));
  tag = toLower (removePrefix "Msk" hostName);

  sing-box = (import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/25f538306313eae3927264466c70d7001dcea1df.tar.gz";
    sha256 = "sha256-ZsIrKmhp4vbBXoXXmR/tBXA/UCsAQiJL9vsgZEduhVY=";
  }) { system = pkgs.stdenv.hostPlatform.system; }).sing-box;

  secretPath = config.sops.secrets."singbox-config".path;
in
{
  config = mkIf enable {
    sops.secrets."singbox-config" = {
      sopsFile = flake.inputs.self + /secrets/sing-box-config.yaml;
      restartUnits = [ "sing-box.service" ];
    };

    # nixpkgs module handles users, groups, capabilities, restart, etc.
    services.sing-box = {
      enable = true;
      package = sing-box;
    };

    systemd.services.sing-box.serviceConfig = {
      ExecStart = mkForce [ "" "${sing-box}/bin/sing-box -D /var/lib/sing-box -C /run/sing-box run" ];
      ExecStartPre = mkForce "+${pkgs.writeShellScript "sing-box-prestart" ''
        ${pkgs.gnused}/bin/sed 's/__HOST_TAG__/${tag}/g' ${secretPath} > /run/sing-box/config.json
        ${pkgs.coreutils}/bin/chown sing-box:sing-box /run/sing-box/config.json
      ''}";
    };

    systemd.tmpfiles.rules = [
      "d /var/cache/acme 0750 sing-box sing-box -"
    ];
  };
}
