# Shared config for all server hosts (bare-metal + VPS, not WSL, not container).
{ flake, config, lib, ... }:
{
  imports = [
    flake.inputs.sops-nix.nixosModules.sops
  ];

  # Disable full linux-firmware (~773MB); hosts declare only what they need.
  hardware.enableRedistributableFirmware = lib.mkForce false;

  home-manager.sharedModules = [
    flake.inputs.sops-nix.homeManagerModules.sops
  ];

  boot = {
    kernelModules = [ "tcp_bbr" ];
    kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";
      "vm.swappiness" = 10;
      "vm.vfs_cache_pressure" = 50;
    };
    kernelParams = [ "audit=0" "net.ifnames=0" "quiet" "vt.global_cursor_default=0" ];
    tmp.useTmpfs = true;
  };

  networking = {
    nftables.enable = true;
    firewall.enable = false;
    useNetworkd = true;
    useDHCP = true;
    hostId = lib.mkDefault (builtins.substring 0 8 (builtins.hashString "md5" config.networking.hostName));
  };
  systemd.network.enable = true;
  services.resolved.enable = true;
  services.timesyncd.enable = true;

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    MaxRetentionSec=1year
  '';

  # Saves ~5s on boot: these block startup until all udev events / network are settled.
  systemd.services."systemd-udev-settle".enable = lib.mkForce false;
  systemd.services."systemd-networkd-wait-online".enable = lib.mkForce false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = lib.mkDefault false;
    };
  };
  services.zfs.autoScrub.enable = lib.mkIf config.boot.zfs.enabled true;
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [ "172.16.0.0/12" "192.168.0.0/16" ];
    bantime = "24h";
    bantime-increment = {
      enable = true;
      formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
      maxtime = "168h";
      overalljails = true;
    };
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };
}
