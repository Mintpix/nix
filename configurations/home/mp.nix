{ flake, pkgs, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  b64 = import (self + /modules/nixos/common/b64.nix) { lib = pkgs.lib; };
in
{
  imports = [
    self.homeModules.default
  ];

  # Defined by /modules/home/me.nix
  # And used all around in /modules/home/*
  me = {
    username = "mp";
    fullname = "Mintpix";
    email = b64.decode "MTUxNTg1MTcrTWludHBpeEB1c2Vycy5ub3JlcGx5LmdpdGh1Yi5jb20=";
  };

  home.stateVersion = "25.11";
}
