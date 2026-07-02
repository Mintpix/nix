# mp + plain profile (standalone, no sops dependency).
# Based on dev, but for non-NixOS containers that don't have sops.
{ flake, ... }:
{
  home.username = "mp";
  home.homeDirectory = "/home/mp";

  imports = [
    flake.inputs.self.homeModules.default
    flake.inputs.self.homeModules.dev
  ];
}
