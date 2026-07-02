# mp + dev profile (for box/nas/nixwsl).
{ flake, ... }:
{
  home.username = "mp";
  home.homeDirectory = "/home/mp";

  imports = [
    flake.inputs.self.homeModules.default
    flake.inputs.self.homeModules.dev
  ];
}
