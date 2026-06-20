# WebDAV server (webdav-server-rs) — shares a directory over WebDAV on port 80
# Uses htpasswd with bcrypt hash from sops (no plaintext password).
# The shared directory path is also stored in sops.
{ config, lib, ... }:
{
  services.webdav-server-rs = {
    enable = true;
    user = "nobody";
    group = "nogroup";
    configFile = config.sops.templates."webdav-config".path;
  };

  # Allow binding to port 80.
  # The module's default hardening restricts CapabilityBoundingSet which
  # prevents binding to privileged ports even as root. Override it.
  systemd.services.webdav-server-rs = {
    serviceConfig = {
      NoNewPrivileges = lib.mkForce false;
      ProtectSystem = lib.mkForce false;
      PrivateDevices = lib.mkForce false;
      # Reset capability restrictions so root can bind to port 80
      CapabilityBoundingSet = lib.mkForce [ "~" ];
      AmbientCapabilities = lib.mkForce [ ];
    };
  };

  # Generate config file at runtime from sops secrets
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

  # htpasswd file with bcrypt hash for mp — stored in sops.
  # Generate with:
  #   echo -n "Password: "; read -s pw; echo; nix shell nixpkgs#httpd -c htpasswd -nbB mp "$pw"
  # The output (mp:$2y$...) goes into secrets.yaml as webdav-htpasswd.
  # Also add webdav-directory: /npool (or your shared path) to secrets.yaml.
}
