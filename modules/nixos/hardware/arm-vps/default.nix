# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ flake, inputs, config, lib, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
in
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disk-config.nix
  ];

  boot.loader = {
    efi.efiSysMountPoint = "/efi";
    systemd-boot = {
      enable = true;
      configurationLimit = 2;
      netbootxyz.enable = true;
    };
  };
}
