# root + plain profile: bash only, no dependencies.
# For non-NixOS containers where root needs minimal shell.
{ pkgs, ... }:
{
  home.username = "root";
  home.homeDirectory = "/root";
  home.stateVersion = "25.11";

  programs.bash.enable = true;
}
