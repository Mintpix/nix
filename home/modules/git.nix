{ config, ... }:
{
  home.shellAliases.g = "git";

  home.sessionVariables.GIT_CONFIG_GLOBAL = "${config.home.homeDirectory}/.gitconfig";

  home.file.".gitconfig".text = ''
    [include]
      path = ~/.config/git/config
  '';

  programs = {
    git = {
      enable = true;
      settings.user = {
        name = config.me.fullname;
        email = config.me.email;
      };
      ignores = [ "*~" "*.swp" ];
      settings.alias.ci = "commit";
    };
    lazygit.enable = true;
  };
}
