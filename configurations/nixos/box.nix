# NixOS configuration for the "box" container
# Used by: nspawn-box.nix (host creates container with this config via path)
# Also activatable standalone via: just ac box
{ flake, pkgs, lib, modulesPath, ... }:
let
  inherit (flake.inputs) self;
in
{
  # Import base NixOS modules (home-manager, common settings, etc.)
  imports = [
    self.nixosModules.default
    (flake.inputs.self + /modules/nixos/services/podman.nix)
  ];

  # nspawn container specific configuration
  boot.isContainer = true;
  boot.loader.grub.enable = false;

  # Minimal filesystem for nspawn container
  fileSystems."/" = {
    device = "rootfs";
    fsType = "tmpfs";
    options = [ "mode=755" ];
  };

  # Hostname must match the configuration name for nixos-unified
  networking.hostName = "box";
  nixpkgs.hostPlatform = "x86_64-linux";

  # User setup (UID/GID must match host for bind mounts)
  users.users.mp = {
    isNormalUser = true;
    uid = 1000;
    group = "users";
    extraGroups = [ "wheel" "video" "render" ];
    shell = pkgs.zsh;
    home = "/home/mp";
  };
  users.groups.users.gid = 100;

  # Root user configuration
  users.users.root = {
    shell = pkgs.zsh;
  };
  # Enable home-manager for root on this host
  home-manager.users.root = {
    imports = [ (self + /configurations/home/root.nix) ];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # SSH service on port 2222
  services.openssh = {
    enable = true;
    startWhenNeeded = false;
    settings = {
      Port = 2222;
      PasswordAuthentication = true;
      PermitRootLogin = "prohibit-password";
      # Read key from /etc/ssh/authorized_keys/{user} (copied by host ExecStartPre)
      AuthorizedKeysFile = lib.mkForce "/etc/ssh/authorized_keys/%u";
    };
  };

  # Disable container firewall (host handles network isolation)
  networking.firewall.enable = false;

  # Network configuration
  # Container module handles IP/routing via hostAddress/localAddress
  # Do NOT enable systemd-networkd (conflicts with container init script)
  networking.useDHCP = false;

  # DNS: use host's resolved via veth IP (192.168.100.1)
  # Disable resolved to avoid conflict with useHostResolvConf=false
  services.resolved.enable = false;
  networking.useHostResolvConf = false;
  networking.nameservers = [ "192.168.100.1" ];
}
