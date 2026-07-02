# Common home-manager config: me + shell + git + packages.
# Shared by all users who import homeModules.default.
{ flake, pkgs, lib, config, ... }:
let
  inherit (flake) inputs;
  inherit (inputs) self;
  b64 = import (self + /modules/lib/b64.nix) { inherit lib; };
in
{
  imports = [
    ./modules/me.nix
    ./modules/shell.nix
    ./modules/git.nix
    ./modules/packages.nix
  ];

  me = {
    fullname = "Mintpix";
    email = b64.decode "MTUxNTg1MTcrTWludHBpeEB1c2Vycy5ub3JlcGx5LmdpdGh1Yi5jb20=";
  };

  home.stateVersion = "25.11";
}
