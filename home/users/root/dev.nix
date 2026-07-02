# root + dev profile (homeDirectory=/root).
{ flake, ... }:
{
  imports = [
    flake.inputs.self.homeModules.default
    flake.inputs.self.homeModules.dev
  ];

  home.username = "root";
  home.homeDirectory = "/root";
}
