{ flake, pkgs, lib, config, ... }:

let
  cfg = config.services.nomad;
in
{
  options.nomad_server = lib.mkEnableOption "Enable Nomad server mode";

  config = lib.mkMerge [
    { nixpkgs.config.allowUnfree = true; }

    {
      services.nomad = {
        enable = true;
        enableDocker = false;
        dropPrivileges = false;
        extraPackages = with pkgs; [ dmidecode cifs-utils podman ];
        extraSettingsPlugins = [ pkgs.nomad-driver-podman ];
        settings = {
          bind_addr = "0.0.0.0";

          consul = {
            auto_advertise = false;
            server_auto_join = false;
            client_auto_join = false;
          };

          client = {
            enabled = true;
          };

          plugin.podman = {
            config = {
              allow_privileged = true;
            };
          };
        };
        extraSettingsPaths = [
          config.sops.templates."nomad-client-servers".path
        ];
      };

      sops.templates."nomad-client-servers" = {
        content = ''
          {
            "client": {
              "servers": [
                "${config.sops.placeholder."easytier-ipv4-Mskos"}",
                "${config.sops.placeholder."easytier-ipv4-MskNAS"}"
              ]
            }
          }
        '';
        mode = "0600";
      };
    }

    (lib.mkIf config.nomad_server {
      services.nomad = {
        settings.server = {
          enabled = true;
          bootstrap_expect = 2;
        };
        extraSettingsPaths = [
          config.sops.templates."nomad-advertise".path
        ];
      };

      sops.templates."nomad-advertise" = {
        content = ''
          {
            "advertise": {
              "http": "${config.sops.placeholder."easytier-ipv4-${config.networking.hostName}"}",
              "rpc": "${config.sops.placeholder."easytier-ipv4-${config.networking.hostName}"}",
              "serf": "${config.sops.placeholder."easytier-ipv4-${config.networking.hostName}"}"
            }
          }
        '';
        mode = "0600";
      };
    })
  ];
}
