{ flake, pkgs, ... }:
{
  home.file.".p10k.zsh" = {
    text = builtins.readFile ./p10k.zsh;
    force = true;
  };

  home.file.".config/sheldon/plugins.toml".text = ''
    shell = "zsh"

    [templates]
    defer = "{% for file in files %}zsh-defer source \"{{ file }}\"\n{% endfor %}"

    [plugins.zsh-defer]
    github = "romkatv/zsh-defer"

    [plugins.powerlevel10k]
    github = "romkatv/powerlevel10k"
    use = ["powerlevel10k.zsh-theme"]

    [plugins.ohmyzsh-lib]
    github = "ohmyzsh/ohmyzsh"
    use = ["lib/completion.zsh", "lib/key-bindings.zsh", "lib/history.zsh"]

    [plugins.ohmyzsh-plugins]
    github = "ohmyzsh/ohmyzsh"
    use = ["plugins/sudo/sudo.plugin.zsh", "plugins/extract/extract.plugin.zsh", "plugins/history/history.plugin.zsh", "plugins/gnu-utils/gnu-utils.plugin.zsh", "plugins/rsync/rsync.plugin.zsh"]

    [plugins.zsh-completions]
    github = "zsh-users/zsh-completions"

    [plugins.zsh-autosuggestions]
    github = "zsh-users/zsh-autosuggestions"

    [plugins.zsh-z]
    github = "agkozak/zsh-z"
  '';

  home.packages = with pkgs; [
    sheldon
  ];

  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;

      history = {
        ignoreAllDups = true;
        ignoreSpace = true;
        saveNoDups = true;
      };

      initContent = ''
        # Load p10k config first (includes instant prompt)
        source "$HOME/.p10k.zsh"

        setopt auto_cd
        setopt pushd_ignore_dups
        setopt pushd_minus
        setopt interactive_comments
        setopt hist_reduce_blanks
        setopt INC_APPEND_HISTORY

        # Add ~/.cache/zsh-patina to PATH
        export PATH="$HOME/.cache/zsh-patina:$PATH"

        # Download zsh-patina if not exists
        if [[ ! -f "$HOME/.cache/zsh-patina/zsh-patina" ]]; then
          mkdir -p "$HOME/.cache/zsh-patina"
          # Detect architecture
          local arch=$(uname -m)
          local rust_arch=""
          case "$arch" in
            x86_64)  rust_arch="x86_64-unknown-linux-gnu" ;;
            aarch64) rust_arch="aarch64-unknown-linux-gnu" ;;
            *)       echo "Unsupported architecture: $arch" ;;
          esac
          # Get latest version from GitHub API
          local version=$(curl -fsSL https://api.github.com/repos/michel-kraemer/zsh-patina/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
          curl -fsSL "https://github.com/michel-kraemer/zsh-patina/releases/download/''${version}/zsh-patina-v''${version}-''${rust_arch}.tar.gz" | tar xz --strip-components=1 -C "$HOME/.cache/zsh-patina"
          chmod +x "$HOME/.cache/zsh-patina/zsh-patina"
        fi

        # Load sheldon plugins
        eval "$(sheldon source)"

        # Autosuggestions keybinding
        bindkey ',,' autosuggest-accept

        # Syntax highlighting (zsh-patina, must be last)
        eval "$(zsh-patina activate)"
      '';
    };
  };
}
