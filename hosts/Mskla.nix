# la: QEMU/KVM (BIOS) VPS, legacy boot, btrfs root.
{ flake, pkgs, config, modulesPath, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    flake.inputs.self.nixosModules.server
    flake.inputs.self.nixosModules.impermanence
    (flake.inputs.self + /modules/impermanence.nix)
    (flake.inputs.self + /hosts/hardware/x86-vps.nix)
    (flake.inputs.self + /hosts/hardware/disk-config-legacy.nix)
    (flake.inputs.self + /modules/services/easytier.nix)
    (flake.inputs.self + /modules/services/sing-box.nix)
    (flake.inputs.self + /modules/services/safe-gc.nix)
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  homeProfile = "server";
  safe-gc.enable = true;

  # QEMU BIOS: GRUB 嵌入 1MB EF02 分区
  # device 由 disko 的 EF02 分区自动设置，无需手动指定
  boot.loader.grub = {
    enable = true;
    efiSupport = false;
  };

  # Rescue: GRUB 菜单项引导到 netboot.xyz
  systemd.services.netboot-xyz-download = {
    description = "Download netboot.xyz for GRUB rescue";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.curl}/bin/curl -fsSL -o /boot/netboot.xyz.lkrn https://boot.netboot.xyz/ipxe/netboot.xyz.lkrn || true
    '';
  };

  boot.loader.grub.extraEntries = ''
    menuentry "netboot.xyz (rescue)" {
      linux16 /netboot.xyz.lkrn
    }
  '';

  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" ];
  boot.kernelModules = [ "kvm-intel" ];

  # 网络：静态 IP 由 sops 注入，这里只写 DNS
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "eth0";
    networkConfig.DNS = [ "1.1.1.1" "8.8.8.8" "2606:4700:4700::1111" "2001:4860:4860::8888" ];
  };

  # Per-host sops template: systemd-networkd drop-in for LA static IPs
  sops.templates."la-network-addresses" = {
    content = ''
      [Network]
      Address=${config.sops.placeholder."la-ipv4"}/25
      Address=${config.sops.placeholder."la-ipv6"}/64
      Gateway=${config.sops.placeholder."la-gateway"}
      Gateway=${config.sops.placeholder."la-gateway6"}
    '';
    path = "/run/systemd/network/10-uplink.network.d/addresses.conf";
    mode = "0644";
    restartUnits = [ "systemd-networkd.service" ];
  };

  networking.hostName = "Mskla";
}
