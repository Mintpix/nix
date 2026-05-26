{ config, ... }:
{
  home.shellAliases = {
    g = "git";
    # lg = "lazygit";
  };

  # Make ~/.gitconfig the global git config entrypoint.
  home.sessionVariables = {
    GIT_CONFIG_GLOBAL = "${config.home.homeDirectory}/.gitconfig";
  };

  # Keep Home Manager managed config in XDG path and include it from ~/.gitconfig.
  home.file.".gitconfig".text = ''
    [include]
      path = ~/.config/git/config
  '';

  # https://nixos.asia/en/git
  programs = {
    git = {
      enable = true;
      settings.user = {
        name = config.me.fullname;
        email = config.me.email;
      };
      ignores = [ "*~" "*.swp" ];
      settings.alias = {
        ci = "commit";
      };
    };
    lazygit.enable = true;
  };

}
