{ pkgs, ... }:
{
  programs = {
    zsh = {
      enable = true;
      enableCompletion = true;

      history = {
        ignoreAllDups = true;
        ignoreSpace = true;
        saveNoDups = true;
        # share = true;
      };

      initContent = ''
        setopt auto_cd
        setopt pushd_ignore_dups
        setopt pushd_minus
        setopt interactive_comments
        setopt hist_reduce_blanks
        setopt INC_APPEND_HISTORY

        bindkey ',,' autosuggest-accept

        P10K_CONFIG="$HOME/.p10k.zsh"
        if [[ ! -f "$P10K_CONFIG" ]]; then
          echo "Downloading p10k config..."
          P10K_URL="$(cat /run/secrets/p10k-url)"
          curl -fsL "$P10K_URL" | tr -d '\r' > "$P10K_CONFIG"
        fi
        source "$P10K_CONFIG"
      '';

      antidote = {
        enable = true;

        plugins = [
          "romkatv/powerlevel10k"
          # Utility plugins (zsh-defer must come first for deferred loading)
          "romkatv/zsh-defer"
          "agkozak/zsh-z"

          # Oh My Zsh library files
          "ohmyzsh/ohmyzsh path:lib/completion.zsh"
          "ohmyzsh/ohmyzsh path:lib/key-bindings.zsh"
          "ohmyzsh/ohmyzsh path:lib/history.zsh"

          # Oh My Zsh plugins
          "ohmyzsh/ohmyzsh path:plugins/sudo"
          "ohmyzsh/ohmyzsh path:plugins/extract"
          "ohmyzsh/ohmyzsh path:plugins/history"
          "ohmyzsh/ohmyzsh path:plugins/gnu-utils"
          "ohmyzsh/ohmyzsh path:plugins/rsync"

          # Third-party plugins
          "zsh-users/zsh-completions"
          "zsh-users/zsh-autosuggestions"

          # Antidote supports kind:defer natively when zsh-defer is already in the list
          "zsh-users/zsh-syntax-highlighting kind:defer"
        ];
      };
    };
  };
}

