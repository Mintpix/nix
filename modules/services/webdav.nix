# WebDAV on port 80, htpasswd bcrypt via sops.
{ config, lib, ... }:
{
  services.webdav-server-rs = {
    enable = true;
    user = "nobody";
    group = "nogroup";
    configFile = config.sops.templates."webdav-config".path;
  };

  # Override module hardening to allow binding port 80.
  systemd.services.webdav-server-rs = {
    serviceConfig = {
      NoNewPrivileges = lib.mkForce false;
      ProtectSystem = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      CapabilityBoundingSet = lib.mkForce [ "~" ];
      AmbientCapabilities = lib.mkForce [ ];
    };
  };

  sops.templates."webdav-config" = {
    content = ''
      [server]
      listen = ["0.0.0.0:80"]

      [accounts]
      auth-type = "htpasswd.default"

      [htpasswd.default]
      htpasswd = "${config.sops.secrets."webdav-htpasswd".path}"

      [[location]]
      route = ["/dav/*path"]
      directory = "${config.sops.placeholder."webdav-directory"}"
      handler = "filesystem"
      methods = ["webdav-rw"]
      autoindex = true
      auth = "true"
    '';
    path = "/run/secrets/webdav-config";
    mode = "0400";
  };
}
