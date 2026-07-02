# Easytier VPN: per-host IPv4 from sops, keyed by hostname.
{ flake, config, lib, ... }:
let
  hostName = config.networking.hostName;
  ipv4Key = "easytier-ipv4-${hostName}";
in
{
  options.easytier_center = lib.mkEnableOption "easytier center node (exposes listeners)";

  config.services.easytier = {
    enable = true;
    instances."MskR" = {
      settings = {
        network_name = "MskR";
      };
      environmentFiles = [
        config.sops.templates."easytier-env".path
      ];
    };
  };

  config.sops.templates."easytier-env" = {
    content = ''
      ET_NETWORK_SECRET=${config.sops.placeholder."easytier-network-secret"}
      ET_NETWORK_NAME=MskR
      ET_IPV4=${config.sops.placeholder.${ipv4Key}}/24
      ${lib.optionalString config.easytier_center ''
        ET_LISTENERS=tcp://0.0.0.0:${config.sops.placeholder."easytier-port"},tcp://[::]:${config.sops.placeholder."easytier-port"}
      ''}
      ${lib.optionalString (!config.easytier_center) "ET_PEERS=${config.sops.placeholder."easytier-peers"}"}
    '';
    path = "/run/secrets/easytier-env";
    mode = "0600";
    restartUnits = [ "easytier-MskR.service" ];
  };
}
