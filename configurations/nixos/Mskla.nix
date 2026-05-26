{ flake, config, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.default
    (flake.inputs.self + /modules/nixos/services/server.nix)
    (flake.inputs.self + /modules/nixos/hardware/x86-vps-la.nix)
    (flake.inputs.self + /modules/nixos/services/easytier.nix)
    (flake.inputs.self + /modules/nixos/services/easytier.nix)
  ];

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
