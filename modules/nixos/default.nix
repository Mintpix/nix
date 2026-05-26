# Base NixOS configuration — imported by all hosts via nixosModules.default
# For server-specific config (openssh, fail2ban, etc.), see services/server.nix
# For home configuration, see /modules/home/*
{ flake, pkgs, lib, config, ... }:
{
  imports = [
    flake.inputs.self.nixosModules.common
  ];

  # --- Programs (universal) ---
  programs.git.enable = true;
  programs.nix-ld.enable = true;
  programs.zsh.enable = true;

  # --- System ---
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";
  environment.systemPackages = with pkgs; [ vim git wget curl toybox ];

  # --- Nix ---
  nix.gc = {
    automatic = true;
    dates = "monthly";
    options = "--delete-older-than 30d";
    persistent = true;
  };
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [ "flakes" "nix-command" "ca-derivations" ];
  };

  system.stateVersion = "25.11";
}
