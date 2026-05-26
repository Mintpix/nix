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
  me = {
    username = "root";
    fullname = "Mintpix";
    email = b64.decode "MTUxNTg1MTcrTWludHBpeEB1c2Vycy5ub3JlcGx5LmdpdGh1Yi5jb20=";
  };

  # Root's home directory is /root, not /home/root
  home.homeDirectory = "/root";
  home.stateVersion = "25.11";
}
