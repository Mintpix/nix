{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ripgrep fd sd tree gnumake
    cachix nil nix-info nixpkgs-fmt
    less
  ];

  programs = {
    bat.enable = true;
    fzf.enable = true;
    jq.enable = true;
    btop.enable = true;
  };
}
