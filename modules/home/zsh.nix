{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # Environment variables
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      NNN_PLUG = "p:preview-tui";
      GOPATH = "$HOME/go";
      VOLTA_FEATURE_PNPM = "1";
      PROTO_HOME = "$HOME/.proto";
      VOLTA_HOME = "$HOME/.volta";
    };

    # Shell aliases (from existing config)
    shellAliases = {
      nnn = "nnn -e -aP p";
      ls = "eza";
      cat = "bat";
      grep = "rg";
      cdghq = "cd $(ghq root)/$(ghq list | peco)";
      lg = "lazygit";
    };

    # History settings (custom path for compatibility)
    history = {
      size = 50000;
      save = 50000;
      path = "${config.home.homeDirectory}/.config/zsh/.zsh_history";
      ignoreDups = true;
      share = true;
      extended = true;
    };

    # Pure prompt + existing config
    initContent = ''
      # ============================================================================
      # PATH Configuration
      # ============================================================================
      export PATH="$HOME/.local/bin:$PATH"
      export PATH="$PROTO_HOME/shims:$PROTO_HOME/bin:$PATH"
      export PATH="$VOLTA_HOME/bin:$PATH"
      export PATH="$GOPATH/bin:$PATH"

      # ============================================================================
      # Pure Prompt Configuration
      # ============================================================================
      fpath+=("${pkgs.pure-prompt}/share/zsh/site-functions")
      PURE_PROMPT_SYMBOL='🐈'

      zstyle ':prompt:pure:user' color white
      autoload -U promptinit; promptinit
      prompt pure
      zstyle :prompt:pure:user show yes

      # Set paw emoji as username
      prompt_pure_state[username]='🐾'

      # ============================================================================
      # Google Cloud SDK
      # ============================================================================
      if [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]; then
        . "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"
      fi
      if [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]; then
        . "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"
      fi

      # ============================================================================
      # Amazon Q
      # ============================================================================
      if [[ -f "$HOME/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]]; then
        builtin source "$HOME/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
      fi

      # ============================================================================
      # Claude CLI wrapper (disable dangerous options)
      # ============================================================================
      claude() {
        for arg in "$@"; do
          if [[ "$arg" = "--dangerously-skip-permissions" ]]; then
            echo "エラー: '--dangerously-skip-permissions' オプションは無効化されています。" >&2
            return 1
          fi
        done
        command claude "$@"
      }

      # ============================================================================
      # Custom Functions
      # ============================================================================

      # ghq + fzf integration with preview
      function cdg() {
        local repo=$(ghq list --full-path | fzf --reverse --preview "ls -F --color=always {}")
        if [ -n "$repo" ]; then
          cd "$repo"
        fi
      }

      # ghq cd with peco (alternative)
      function cdghq() {
        cd "$(ghq root)/$(ghq list | peco)"
      }

      # ============================================================================
      # Zoxide (smarter cd)
      # ============================================================================
      eval "$(${pkgs.zoxide}/bin/zoxide init --cmd cd zsh)"

      # ============================================================================
      # Source local configuration
      # ============================================================================
      if [ -f "$HOME/.zshrc.local" ]; then
        source "$HOME/.zshrc.local"
      fi
    '';
  };

  # direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  # starship is disabled in favor of pure prompt
  programs.starship.enable = false;

  # Additional packages for zsh
  home.packages = with pkgs; [
    pure-prompt  # Pure prompt
    zoxide       # Smarter cd
  ];

  # Local zsh configuration that gets sourced
  home.file.".zshrc.local" = {
    force = true;
    text = ''
      # Add ~/.local/bin to PATH
      export PATH="$HOME/.local/bin:$PATH"
    '';
  };
}
