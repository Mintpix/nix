{ flake, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    (flake.inputs.self + /modules/nixos/services/server.nix)
    (flake.inputs.self + /modules/nixos/services/ups.nix)
    (flake.inputs.self + /modules/nixos/services/easytier.nix)
    (flake.inputs.self + /modules/nixos/services/sanoid.nix)
    (flake.inputs.self + /modules/nixos/services/efi-backup.nix)
    (flake.inputs.self + /modules/nixos/hardware/nas/default.nix)
    (flake.inputs.self + /modules/nixos/services/samba.nix)
    (flake.inputs.self + /modules/nixos/services/nspawn-box.nix)
  ];

  services.openssh.settings.PasswordAuthentication = true;
  services.easytier.instances.MskR.extraSettings.flags = {
    disable_sym_hole_punching = true;
    disable_udp_hole_punching = true;
    disable_p2p = true;
  };

  # echo "your-password" | sha256sum | cut -d' ' -f1 | xxd -r -p > /etc/zfs/npool.key
  boot.zfs.requestEncryptionCredentials = true;
  boot.zfs.extraPools = [ "npool" ];

  networking.hostName = "MskNAS";
}
