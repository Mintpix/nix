# root + server profile: bash only, nothing else.
{ pkgs, ... }:
{
  home.username = "root";
  home.homeDirectory = "/root";
  home.stateVersion = "25.11";

  programs.bash.enable = true;
}
