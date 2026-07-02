# ZFS Event Daemon: email via Cloudflare API, secrets via sops.
{ config, lib, pkgs, ... }:
{
  services.zfs.zed = {
    # 26.05: enableMail requires services.mail.n (sendmail wrapper).
    # We use a custom Cloudflare API wrapper instead, so disable it.
    enableMail = false;
    settings = lib.mkForce { ZED_EMAIL_ADDR = "placeholder"; };
  };

  environment.etc."zfs/zed.d/zed.rc".source =
    lib.mkForce config.sops.templates."zed-rc".path;

  sops.templates."zed-rc" = {
    content = ''
      ZED_EMAIL_ADDR="${config.sops.placeholder."zfs-alert-email"}"
      ZED_EMAIL_PROG="zed-email-wrapper"
      ZED_EMAIL_OPTS="@ADDRESS@ @SUBJECT@"
      ZED_NOTIFY_INTERVAL_SECS=3600
      ZED_NOTIFY_VERBOSE=0
      ZED_USE_ENCLOSURE_LEDS=true
      ZED_SCRUB_AFTER_RESILVER=true
      PATH="${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:${pkgs.systemd}/bin:/run/current-system/sw/bin"
    '';
    path = "/run/secrets/zed-rc";
    mode = "0444";
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "zed-email-wrapper" ''
      exec ${pkgs.bash}/bin/bash ${config.sops.templates."zed-email-script".path} "$@"
    '')
  ];

  sops.templates."zed-email-script" = {
    content = ''
      #!${pkgs.bash}/bin/bash
      TO="$1"
      shift
      SUBJECT="$*"
      BODY=$(cat)
      ACCOUNT_ID=$(cat ${config.sops.secrets."cf-account-id".path})
      API_TOKEN=$(cat ${config.sops.secrets."cf-api-token".path})
      SENDER=$(cat ${config.sops.secrets."zfs-alert-sender".path})

      ${pkgs.jq}/bin/jq -n \
        --arg to "$TO" \
        --arg from "$SENDER" \
        --arg subject "$SUBJECT" \
        --arg text "$BODY" \
        '{to: $to, from: $from, subject: $subject, text: $text}' \
      | ${pkgs.curl}/bin/curl -s -X POST \
        "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/email/sending/send" \
        --header "Authorization: Bearer $API_TOKEN" \
        --header "Content-Type: application/json" \
        --data-binary @-
    '';
    path = "/run/secrets/zed-email-script";
    mode = "0500";
  };
}
