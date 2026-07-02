{ flake, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    flake.inputs.self.nixosModules.server
    flake.inputs.self.nixosModules.impermanence
    (flake.inputs.self + /modules/impermanence.nix)
    (flake.inputs.self + /hosts/hardware/x86-nas.nix)
    (flake.inputs.self + /modules/services/ups.nix)
    (flake.inputs.self + /modules/services/easytier.nix)
    (flake.inputs.self + /modules/services/safe-gc.nix)
    (flake.inputs.self + /modules/services/sanoid.nix)
    (flake.inputs.self + /modules/services/btrbk.nix)
    (flake.inputs.self + /modules/services/samba.nix)
    (flake.inputs.self + /modules/services/webdav.nix)
    (flake.inputs.self + /modules/services/zfs-zed.nix)
    (flake.inputs.self + /modules/services/archbox.nix)
  ];

  homeProfile = "dev";
  safe-gc.enable = true;

  services.openssh.settings.PasswordAuthentication = true;
  services.easytier.instances.MskR.extraSettings.flags = {
    disable_sym_hole_punching = true;
    disable_udp_hole_punching = true;
    disable_p2p = true;
  };

  networking.hostName = "MskNAS";
}
