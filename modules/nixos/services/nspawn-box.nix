# NixOS Container Module
# Provides an isolated NixOS development environment with:
# - Private network (veth) isolated from EasyTier VPN
# - Shared nix store and /shared bind mount
# - SSH access on port 2222
{ config, lib, pkgs, ... }:

let
  containerName = "box";
  containerSubnet = "192.168.100";
  hostIP = "${containerSubnet}.1";
  containerIP = "${containerSubnet}.2";
  mpUid = config.users.users.mp.uid;
  mpGid = config.users.groups.users.gid;
in
{
  options.services.nspawnNixos = {
    copyAuthorizedKeys = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Copy the rendered mp authorized_keys into the container rootfs before start.";
    };
  };

  config = {
    # ============================================================================
    # Container Configuration
    # ============================================================================
    containers.${containerName} = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = hostIP;
      localAddress = containerIP;
      hostAddress6 = "fd00:100::1";
      localAddress6 = "fd00:100::2";

      # Bind mounts from host
      bindMounts = {
        "/nix" = { hostPath = "/nix"; isReadOnly = true; };
        "/shared" = { hostPath = "/npool/shared"; isReadOnly = false; };
        # SSH key is copied to container rootfs by ExecStartPre (see below)
      };

      # Container's NixOS configuration
      # This is a minimal inline config for initial container creation.
      # After creation, use `just ac box` from inside the container to apply
      # the full configuration from configurations/nixos/box.nix
      config = { pkgs, ... }: {
        system.stateVersion = "25.11";

        # User setup (UID/GID must match host for bind mounts)
        users.users.mp = {
          isNormalUser = true;
          uid = mpUid;
          group = "users";
          extraGroups = [ "wheel" ];
          shell = pkgs.zsh;
          home = "/home/mp";
        };
        users.groups.users.gid = mpGid;

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
            PasswordAuthentication = false;
            PermitRootLogin = "prohibit-password";
            # Read key from /etc/ssh/authorized_keys/{user} (copied by host ExecStartPre)
            AuthorizedKeysFile = lib.mkForce "/etc/ssh/authorized_keys/%u";
          };
        };

        # Disable container firewall (host handles network isolation)
        networking.firewall.enable = false;

        # System locale and timezone
        time.timeZone = "Asia/Shanghai";
        i18n.defaultLocale = "en_US.UTF-8";

        # Basic tools
        programs.zsh.enable = true;
        programs.git.enable = true;
        environment.systemPackages = with pkgs; [ vim wget curl ];

        # Network configuration
        # Note: Container module handles IP/routing via hostAddress/localAddress
        # Do NOT enable systemd-networkd (conflicts with container init script)
        networking.useDHCP = false;

        # DNS: use host's resolved via veth IP
        # Note: Disable resolved to avoid conflict with useHostResolvConf=false
        services.resolved.enable = false;
        networking.useHostResolvConf = false;
        networking.nameservers = [ hostIP ];

        # Nix configuration (use host's nix store)
        nix.settings.experimental-features = [ "flakes" "nix-command" ];
      };
    };

    # ============================================================================
    # Host-side Network Configuration
    # ============================================================================

    # Copy SSH authorized keys into container rootfs before starting
    # (bind mount doesn't work for files inside already-mounted directories)
    systemd.services."container@${containerName}".serviceConfig.ExecStartPre =
      lib.optionals config.services.nspawnNixos.copyAuthorizedKeys [
        "${pkgs.coreutils}/bin/install -d -m 755 /var/lib/nixos-containers/${containerName}/etc/ssh/authorized_keys"
        "${pkgs.coreutils}/bin/cp -f /run/secrets/rendered/ssh-authorized-keys-mp /var/lib/nixos-containers/${containerName}/etc/ssh/authorized_keys/mp"
        "${pkgs.coreutils}/bin/chmod 644 /var/lib/nixos-containers/${containerName}/etc/ssh/authorized_keys/mp"
        "${pkgs.coreutils}/bin/cp -f /run/secrets/rendered/ssh-authorized-keys-root /var/lib/nixos-containers/${containerName}/etc/ssh/authorized_keys/root"
        "${pkgs.coreutils}/bin/chmod 644 /var/lib/nixos-containers/${containerName}/etc/ssh/authorized_keys/root"
      ];

    # DNS: Listen on veth interface for container DNS queries
    services.resolved.extraConfig = ''
      DNSStubListenerExtra=${hostIP}
    '';

    # Enable IPv4 forwarding for container NAT/port-forwarding
    boot.kernel.sysctl."net.ipv4.ip_forward" = true;

    # NAT and firewall rules
    # SSH port forwarding is handled here (DNAT to container)
    networking.nftables.tables.nspawn-nat = {
      family = "inet";
      content = ''
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
          tcp dport 2222 dnat ip to ${containerIP}:2222
        }
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          iifname "ve-${containerName}" masquerade
        }
        chain forward {
          type filter hook forward priority filter; policy accept;
          # Block EasyTier VPN access from container
          iifname "ve-${containerName}" ip daddr 172.16.0.0/12 drop
          # Allow container outbound
          iifname "ve-${containerName}" accept
          # Allow DNATed inbound SSH to container
          oifname "ve-${containerName}" ip daddr ${containerIP} tcp dport 2222 accept
          # Allow return traffic
          ct state established,related accept
        }
      '';
    };
  };
}
