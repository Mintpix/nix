# Server-specific configuration — imported by all server hosts (NOT WSL)
# Contains kernel tuning, networking, and security services that only apply
# to bare-metal/VM servers.
{ flake, config, lib, ... }:
{
  imports = [
    (flake.inputs.self + /modules/nixos/common/user-config.nix)
    (flake.inputs.self + /modules/nixos/common/sops.nix)
    (flake.inputs.self + /modules/nixos/common/sops-templates.nix)
    (flake.inputs.self + /modules/nixos/services/sing-box.nix)
    flake.inputs.sops-nix.nixosModules.sops
  ];

  # Enable sops-nix for home-manager (provides home-level sops.secrets/templates)
  home-manager.sharedModules = [
    flake.inputs.sops-nix.homeManagerModules.sops
  ];

  # --- Kernel tuning ---
  boot = {
    kernelModules = [ "tcp_bbr" ];
    kernel.sysctl = {
      "net.ipv4.tcp_congestion_control" = "bbr";
      "net.core.default_qdisc" = "fq";
    };
    kernelParams = [
      "audit=0"
      "net.ifnames=0"
    ];
    tmp.useTmpfs = true;
  };

  # --- Networking ---
  networking = {
    nftables.enable = true;
    firewall.enable = false;
    useNetworkd = true;
    useDHCP = true;
    # Auto-derive hostId from hostName (needed by ZFS)
    hostId = lib.mkDefault (builtins.substring 0 8 (builtins.hashString "md5" config.networking.hostName));
  };
  systemd.network.enable = true;
  services.resolved.enable = true;
  services.timesyncd.enable = true;

  # --- Services ---
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = lib.mkDefault false;
    };
  };
  services.zfs.autoScrub.enable = true;
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    ignoreIP = [
      "172.16.0.0/12"
      "192.168.0.0/16"
    ];
    bantime = "24h";
    bantime-increment = {
      enable = true;
      formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
      maxtime = "168h";
      overalljails = true;
    };
  };

  # --- System ---
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # --- Auto-derived ---
  nixos-unified.sshTarget = lib.mkDefault "root@${config.networking.hostName}";
}
