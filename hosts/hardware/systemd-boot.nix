# Unified UEFI bootloader config for all EFI machines (arm-vps/sg/nas).
{ pkgs, ... }:
{
  boot.loader = {
    efi.efiSysMountPoint = "/efi";
    systemd-boot = {
      enable = true;
      extraInstallCommands = ''
        ${pkgs.coreutils}/bin/mkdir -p /efi/EFI/netbootxyz
        ${pkgs.coreutils}/bin/cp ${pkgs.netbootxyz-efi} /efi/EFI/netbootxyz/netboot.xyz.efi
        ${pkgs.coreutils}/bin/cat > /efi/loader/entries/netbootxyz.conf <<EOF
title  netboot.xyz
efi    /EFI/netbootxyz/netboot.xyz.efi
sort-key zz_netbootxyz
EOF
      '';
    };
  };
}
