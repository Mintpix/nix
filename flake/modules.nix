# Export reusable NixOS and Home Manager modules.
# Services are NOT listed here — hosts import them directly by path:
#   (flake.inputs.self + /modules/services/<name>.nix)
# Top-level modules and profiles are auto-discovered.
{ inputs, lib, ... }:
let
  inherit (inputs) self;

  # Auto-discover top-level modules: every .nix in modules/ → nixosModules.<name>
  # "default" is reserved for common.nix; upstream overrides take precedence (see below).
  modulesDir = self + /modules;
  localModules = lib.mapAttrs'
    (name: _: lib.nameValuePair
      (lib.removeSuffix ".nix" name)
      (import (modulesDir + "/${name}")))
    (lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".nix" name)
      (builtins.readDir modulesDir));

  # Auto-discover profiles: every .nix in home/profiles/ → homeModules.<name>
  profilesDir = self + /home/profiles;
  profileModules = lib.mapAttrs'
    (name: _: lib.nameValuePair
      (lib.removeSuffix ".nix" name)
      (import (profilesDir + "/${name}")))
    (lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".nix" name)
      (builtins.readDir profilesDir));
in
{
  flake = {
    # localModules first, then explicit overrides on top (// is right-biased).
    # - default: alias for common.nix (convention: nixosModules.default)
    # - impermanence: upstream module, not local modules/impermanence.nix
    #   (hosts import the local one separately by path)
    nixosModules = localModules // {
      default = localModules.common;
      impermanence = inputs.impermanence.nixosModules.impermanence;
    };

    homeModules = {
      default = import ../home/common.nix;
    } // profileModules;
  };
}
