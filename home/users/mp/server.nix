# mp + server profile (for cc/os/se/la/sg).
{ flake, ... }:
{
  home.username = "mp";
  home.homeDirectory = "/home/mp";

  imports = [
    flake.inputs.self.homeModules.default
  ];
}
