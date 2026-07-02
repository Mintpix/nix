# archbox: Arch Linux nspawn container with ephemeral root + persistent home.
#
# Uses systemd.nspawn + systemd.services directly (not NixOS containers module).
# Rootfs is extracted from the Arch bootstrap tarball.
# ephemeral: btrfs snapshot from rootfs on each start, destroyed on stop.
# /home/mp is bind-mounted from @persist/archbox/persist for persistence.
#
# References:
#   nspawn.nix module: nixos/modules/system/boot/systemd/nspawn.nix
#   nspawn config file: systemd.nspawn(5)
#   nspawn service template: systemd-nspawn@.service (from systemd package)
{ config, lib, pkgs, ... }:

let
  containerName = "archbox";
  hostIP = "192.168.100.1";
  containerIP = "192.168.100.2";
  hostIP6 = "fd00:100::1";
  containerIP6 = "fd00:100::2";
  rootfsDir = "/var/lib/${containerName}/root";
  persistDir = "/var/lib/${containerName}/persist";
  bootstrapUrl = "https://mirrors.tuna.tsinghua.edu.cn/archlinux/iso/latest/archlinux-bootstrap-x86_64.tar.zst";
in
{
  # Ensure directories exist.
  # tmpfiles: d = create directory, mode owner group - = no age
  systemd.tmpfiles.rules = [
    "d ${rootfsDir} 0755 root root -"
    "d ${persistDir} 0755 1000 100 -"
  ];

  # Download and extract Arch bootstrap rootfs if not already done.
  systemd.services."${containerName}-init-rootfs" = {
    description = "Initialize Arch rootfs from bootstrap tarball";
    # Run after the rootfs mount is available
    after = [ "var-lib-${containerName}-root.mount" ];
    # Run before the container starts
    before = [ "systemd-nspawn@${containerName}.service" ];
    # Container requires this to complete before starting
    requiredBy = [ "systemd-nspawn@${containerName}.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.curl pkgs.zstd pkgs.gnutar pkgs.coreutils pkgs.gnused pkgs.findutils pkgs.util-linux pkgs.procps ];
    script = ''
      REINSTALL_FLAG="/tmp/${containerName}-reinstall"

      if [ -f "$REINSTALL_FLAG" ]; then
        echo "Reinstall flag detected, clearing rootfs..."
        # Unmount leftover bind/virtual mounts UNDER rootfs (dev/proc/sys).
        # Do NOT use umount -R — it would unmount the rootfs subvolume itself.
        # Only unmount known sub-mounts, then delete contents.
        for sub in dev/pts dev proc sys run; do
          ${pkgs.util-linux}/bin/umount "${rootfsDir}/$sub" 2>/dev/null || true
        done
        # Verify rootfs is still mounted (btrfs subvol), not a plain dir
        if ! ${pkgs.util-linux}/bin/findmnt -n -o SOURCE "${rootfsDir}" >/dev/null 2>&1; then
          echo "ERROR: ${rootfsDir} is not mounted, refusing to delete"
          exit 1
        fi
        find "${rootfsDir}" -mindepth 1 -delete 2>/dev/null || true
        rm -f "$REINSTALL_FLAG"
      elif [ -x "${rootfsDir}/usr/bin/pacman" ] && [ -f "${rootfsDir}/etc/hostname" ]; then
        echo "rootfs already initialized, skipping"
        exit 0
      fi
      echo "Downloading Arch bootstrap tarball..."
      curl -fsSLo /tmp/arch-bootstrap.tar.zst "${bootstrapUrl}"
      echo "Extracting to ${rootfsDir}..."
      mkdir -p "${rootfsDir}"
      tar -x --use-compress-program=zstd -f /tmp/arch-bootstrap.tar.zst -C "${rootfsDir}" --strip-components=1
      rm -f /tmp/arch-bootstrap.tar.zst

      echo "Configuring Arch rootfs..."
      ROOT="${rootfsDir}"

      # Copy resolv.conf for DNS resolution inside chroot
      cp /etc/resolv.conf "$ROOT/etc/resolv.conf"

      # Mount /dev /proc /sys for chroot (pacman-key needs /dev/urandom, gpg)
      mount --bind /dev "$ROOT/dev"
      mount --bind /dev/pts "$ROOT/dev/pts"
      mount -t proc /proc "$ROOT/proc"
      mount -t sysfs /sys "$ROOT/sys"

      # Pacman mirrors (tuna)
      mkdir -p "$ROOT/etc/pacman.d"
      cat > "$ROOT/etc/pacman.d/mirrorlist" << 'MIRROR'
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
MIRROR

      # Pacman config
      cat > "$ROOT/etc/pacman.conf" << 'PACMAN'
[options]
Architecture = auto
CheckSpace
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

[archlinuxcn]
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinuxcn/$arch
SigLevel = Optional TrustedOnly
PACMAN

      # Bootstrap pacman keyring
      # chroot doesn't inherit PATH, so use env to set it
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin pacman-key --init
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin pacman-key --populate archlinux

      # Install archlinuxcn-keyring (provides GPG keys for archlinuxcn repo)
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin pacman -Sy --noconfirm archlinuxcn-keyring

      # Install packages: openssh, sudo, zsh, paru (from archlinuxcn), nix
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin pacman -S --noconfirm openssh sudo zsh paru nix

      # Nix: enable experimental features (nix-command + flakes)
      mkdir -p "$ROOT/etc/nix"
      cat > "$ROOT/etc/nix/nix.conf" << 'NIXCONF'
experimental-features = nix-command flakes
build-users-group = nixbld
NIXCONF
      # Create nixbld group + builders (nix-daemon needs them)
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin groupadd -r nixbld 2>/dev/null || true
      for i in $(seq 1 10); do
        chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin useradd -r -g nixbld -G nixbld -d /var/empty -s /usr/bin/nologin "nixbld$i" 2>/dev/null || true
      done
      # Add mp to nix group so it can use nix-daemon
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin usermod -aG nix mp 2>/dev/null || true
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin systemctl enable nix-daemon

      # Create mp user (UID 1000, matching host for bind mount permissions)
      # groupadd may fail if group exists with different GID, use || true
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin groupadd -g 1000 users 2>/dev/null || true
      # If users group exists with wrong GID, create a new one
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin groupadd -g 1000 mp 2>/dev/null || true
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin useradd -m -u 1000 -g 1000 -G wheel -s /usr/bin/zsh mp 2>/dev/null || \
        chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin usermod -u 1000 -g 1000 -G wheel -s /usr/bin/zsh mp 2>/dev/null || true
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin bash -c 'echo "mp:mp" | chpasswd' 2>/dev/null || true

      # Sudo: wheel group no password
      sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' "$ROOT/etc/sudoers"

      # SSHd config
      sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' "$ROOT/etc/ssh/sshd_config"
      sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$ROOT/etc/ssh/sshd_config"
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin systemctl enable sshd

      # Network: static IP
      # nspawn VirtualEthernet creates interface named "host0" inside container.
      # Arch's systemd ships /usr/lib/systemd/network/80-container-host0.network
      # with DHCP=yes. We override it with the same filename in /etc (higher priority).
      mkdir -p "$ROOT/etc/systemd/network"
      cat > "$ROOT/etc/systemd/network/80-container-host0.network" << 'NET'
[Match]
Name=host0

[Network]
Address=${containerIP}/24
Address=${containerIP6}/64
Gateway=${hostIP}
Gateway=${hostIP6}
DNS=${hostIP}
DNS=${hostIP6}
DHCP=no
LinkLocalAddressing=no
NET
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin systemctl enable systemd-networkd
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin systemctl enable systemd-resolved

      # Hostname
      echo "${containerName}" > "$ROOT/etc/hostname"

      # Timezone
      ln -sf /usr/share/zoneinfo/Asia/Shanghai "$ROOT/etc/localtime"

      # Locale
      echo "en_US.UTF-8 UTF-8" >> "$ROOT/etc/locale.gen"
      chroot "$ROOT" /usr/bin/env PATH=/usr/bin:/bin locale-gen
      echo "LANG=en_US.UTF-8" > "$ROOT/etc/locale.conf"

      # SSH authorized_keys: copy to persist dir (not rootfs, because /home/mp
      # is bind-mounted from persist, overwriting rootfs's /home/mp)
      mkdir -p "${persistDir}/.ssh"
      if [ -f "/run/secrets/rendered/ssh-authorized-keys-mp" ]; then
        cp /run/secrets/rendered/ssh-authorized-keys-mp "${persistDir}/.ssh/authorized_keys"
        chown 1000:100 "${persistDir}/.ssh/authorized_keys"
        chmod 600 "${persistDir}/.ssh/authorized_keys"
      fi

      echo "Done. rootfs initialized at ${rootfsDir}"

      # Cleanup chroot mounts
      umount "$ROOT/dev/pts" 2>/dev/null || true
      umount "$ROOT/dev" 2>/dev/null || true
      umount "$ROOT/proc" 2>/dev/null || true
      umount "$ROOT/sys" 2>/dev/null || true
    '';
  };

  # nspawn container configuration file (.nspawn).
  # This generates /etc/systemd/nspawn/archbox.nspawn
  # See: systemd.nspawn(5) for all options
  # See: nixos/modules/system/boot/systemd/nspawn.nix for NixOS module validation
  systemd.nspawn."${containerName}" = {
    enable = true;
    # [Exec] section — see systemd.nspawn(5), validated by checkExec in nspawn.nix
    execConfig = {
      Boot = true; # Boot into container (run /sbin/init)
      Ephemeral = true; # btrfs snapshot from rootfs, destroyed on stop
      PrivateUsers = false; # No user namespace remapping
      NotifyReady = true; # Container sends READY=1 to systemd
      Timezone = "bind"; # Bind host timezone into container
    };
    # [Files] section — validated by checkFiles in nspawn.nix
    filesConfig = {
      # Format: "source:target" or "source" (same path in container)
      Bind = [
        "${persistDir}:/home/mp"
        "/npool/shared:/home/mp/shared"
        "/dev/dri"
        "/dev/kfd"
        "/dev/kvm"
      ];
      BindReadOnly = [
        "${config.sops.templates."copilot-env".path}:/run/secrets/copilot-env"
      ];
    };
    # [Network] section — validated by checkNetwork in nspawn.nix
    networkConfig = {
      Private = true; # Private network namespace
      VirtualEthernet = true; # Create veth pair (ve-archbox on host, host0 in container)
    };
  };

  # Override the systemd-nspawn@.service template for archbox.
  # The default template uses /var/lib/machines/%i as rootfs. We need to override
  # ExecStart to point to our rootfs and add --ephemeral.
  #
  # overrideStrategy = "asDropin": creates a drop-in overrides.conf that merges
  # with the template. This preserves the template's Unit section (PartOf=machines.target,
  # After=network.target, etc.) while overriding ExecStart and RequiresMountsFor.
  # Per nixpkgs docs: "asDropin is mainly needed to define instances for systemd
  # template units (e.g. systemd-nspawn@mycontainer.service)."
  # See: nixos/lib/systemd-unit-options.nix
  systemd.services."systemd-nspawn@${containerName}" = {
    overrideStrategy = "asDropin";
    unitConfig = {
      # Override template's RequiresMountsFor=/var/lib/machines/%i
      RequiresMountsFor = rootfsDir;
    };
    serviceConfig = {
      Type = "notify";
      # Clear template's ExecStart (empty string = reset), then set our own
      ExecStart = [
        ""
        "${pkgs.systemd}/bin/systemd-nspawn --quiet --keep-unit --boot --machine=${containerName} --directory=${rootfsDir} --ephemeral"
      ];
      DeviceAllow = [ "char-* rwm" "block-* rwm" ];
    };
    # Network configuration after container starts
    serviceConfig.ExecStartPost = [
      (pkgs.writeShellScript "archbox-net" ''
        ${pkgs.iproute2}/bin/ip addr replace ${hostIP}/32 dev ve-${containerName} 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip -6 addr replace ${hostIP6}/128 dev ve-${containerName} 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip route replace ${containerIP}/32 dev ve-${containerName} 2>/dev/null || true
        ${pkgs.iproute2}/bin/ip -6 route replace ${containerIP6}/128 dev ve-${containerName} 2>/dev/null || true

        # Sysfs bind mounts for GPU access inside container.
        PID="$(${pkgs.systemd}/bin/machinectl show ${containerName} -p Leader --value 2>/dev/null || true)"
        if [ -z "$PID" ]; then
          exit 0
        fi
        for p in /sys/class/drm /sys/class/hwmon /sys/module; do
          ${pkgs.util-linux}/bin/nsenter -t "$PID" -m ${pkgs.coreutils}/bin/mkdir -p "$p" 2>/dev/null || true
          ${pkgs.util-linux}/bin/nsenter -t "$PID" -m ${pkgs.util-linux}/bin/mount --bind "$p" "$p" 2>/dev/null || true
        done
      '')
    ];
    # Auto-start with machines.target
    wantedBy = [ "machines.target" ];
  };

  # Network config for ve-archbox interface on the host side.
  # This configures the host end of the veth pair created by nspawn.
  systemd.network.networks."10-ve-${containerName}" = {
    matchConfig = {
      Kind = "veth";
      Name = "ve-${containerName}";
    };
    networkConfig = {
      LinkLocalAddressing = "no";
      DHCPServer = false;
      IPMasquerade = false;
      IPv6AcceptRA = false;
      IPv6SendRA = false;
      LLDP = false;
      EmitLLDP = false;
    };
    routes = [
      { Destination = "${containerIP}/32"; }
      { Destination = "${containerIP6}/128"; }
    ];
  };

  # DNS for container — container uses hostIP as DNS server.
  services.resolved.settings.Resolve.DNSStubListenerExtra = [ hostIP ];

  # IP forwarding for NAT.
  boot.kernel.sysctl."net.ipv4.ip_forward" = true;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = true;

  # NAT + port forwarding: NAS:2222 → archbox:22
  networking.nftables.tables."nspawn-nat" = {
    family = "inet";
    content = ''
      chain prerouting {
        type nat hook prerouting priority dstnat - 10; policy accept;
        tcp dport 2222 dnat ip to ${containerIP}:22
      }
      chain output {
        type nat hook output priority dstnat - 10; policy accept;
        ip daddr != 127.0.0.0/8 tcp dport 2222 dnat ip to ${containerIP}:22
      }
      chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        iifname "ve-${containerName}" masquerade
        oifname "ve-${containerName}" masquerade
      }
      chain forward {
        type filter hook forward priority filter; policy accept;
        iifname "ve-${containerName}" ip daddr 172.16.0.0/12 drop
        iifname "ve-${containerName}" accept
        oifname "ve-${containerName}" ip daddr ${containerIP} tcp dport 22 accept
        ct state established,related accept
      }
    '';
  };

  # Copilot env rendered on NAS, bind-mounted into archbox.
  sops.templates."copilot-env" = {
    content = ''
      COPILOT_PROVIDER_BASE_URL=${config.sops.placeholder."byok-api"}
      COPILOT_PROVIDER_API_KEY=${config.sops.placeholder."byok-key"}
      COPILOT_MODEL=glm-5.2
      COPILOT_OFFLINE=false
      COPILOT_AUTO_UPDATE=false
      COPILOT_PROVIDER_MAX_PROMPT_TOKENS=991000
      COPILOT_PROVIDER_MAX_OUTPUT_TOKENS=128000
    '';
    mode = "0444";
  };
}
