{ flake, pkgs, ... }:
{
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
        path = "$HOME/.local/share/zsh/.zsh_history";
        ignoreAllDups = true;
        ignoreSpace = true;
        saveNoDups = true;
      };

      initContent = ''
        setopt auto_cd
        setopt pushd_ignore_dups
        setopt pushd_minus
        setopt interactive_comments
        setopt hist_reduce_blanks
        setopt INC_APPEND_HISTORY

        export PATH="$HOME/.cache/zsh-patina:$PATH"

        if [[ ! -f "$HOME/.cache/zsh-patina/zsh-patina" ]]; then
          mkdir -p "$HOME/.cache/zsh-patina"
          local arch=$(uname -m)
          local rust_arch=""
          case "$arch" in
            x86_64)  rust_arch="x86_64-unknown-linux-gnu" ;;
            aarch64) rust_arch="aarch64-unknown-linux-gnu" ;;
            *)       echo "Unsupported architecture: $arch" ;;
          esac
          local version=$(curl -fsSL https://api.github.com/repos/michel-kraemer/zsh-patina/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
          curl -fsSL "https://github.com/michel-kraemer/zsh-patina/releases/download/''${version}/zsh-patina-v''${version}-''${rust_arch}.tar.gz" | tar xz --strip-components=1 -C "$HOME/.cache/zsh-patina"
          chmod +x "$HOME/.cache/zsh-patina/zsh-patina"
        fi

        eval "$(sheldon source)"

        # Powerlevel10k: source lean preset, then override for single-line ascii
        source "''${HOME}/.local/share/sheldon/repos/github.com/romkatv/powerlevel10k/config/p10k-lean.zsh"
        # Override preset defaults after source
        typeset -g POWERLEVEL9K_MODE=ascii
        typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs prompt_char)
        # lean 预设的 RIGHT_PROMPT_ELEMENTS 含 newline 元素（两行布局），
        # 移除它以保持 right prompt 单行，与 left 一致
        typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(''${POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS:#newline})
        typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
        typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose

        bindkey ',,' autosuggest-accept

        eval "$(zsh-patina activate)"
      '';
    };
  };
}
