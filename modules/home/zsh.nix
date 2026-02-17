{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # History substring search (similar to Zim)
    historySubstringSearch.enable = true;

    # Completion settings (based on Zim's completion module)
    completionInit = ''
      # Load and initialize the completion system
      autoload -Uz compinit
      compinit -C -d "$HOME/.cache/zsh/zcompdump"

      # Compile the completion dumpfile for faster loading
      if [[ ! "$HOME/.cache/zsh/zcompdump.zwc" -nt "$HOME/.cache/zsh/zcompdump" ]]; then
        zcompile "$HOME/.cache/zsh/zcompdump"
      fi

      # ============================================================================
      # Zsh options
      # ============================================================================

      # Move cursor to end of word if a full completion is inserted
      setopt ALWAYS_TO_END

      # Case-insensitive globbing
      setopt NO_CASE_GLOB

      # Don't beep on ambiguous completions
      setopt NO_LIST_BEEP

      # ============================================================================
      # Completion module options
      # ============================================================================

      # Enable caching
      zstyle ':completion::complete:*' use-cache on
      zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache"

      # Case-insensitive completion with smart matching
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' '+r:|?=**'

      # Menu selection for completion
      zstyle ':completion:*:*:*:*:*' menu select

      # Group matches and describe
      zstyle ':completion:*:matches' group yes
      zstyle ':completion:*:options' description yes
      zstyle ':completion:*:options' auto-description '%d'
      zstyle ':completion:*:corrections' format '%F{green}-- %d (errors: %e) --%f'
      zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
      zstyle ':completion:*:messages' format '%F{purple}-- %d --%f'
      zstyle ':completion:*:warnings' format '%F{red}-- no matches found --%f'
      zstyle ':completion:*' format '%F{yellow}-- %d --%f'
      zstyle ':completion:*' group-name '''
      zstyle ':completion:*' verbose yes

      # Color completion (with fallback)
      if (( ''${+LS_COLORS} )); then
        zstyle ':completion:*:default' list-colors ''${(s.:.)LS_COLORS}
      else
        zstyle ':completion:*:default' list-colors 'di=1;34:ln=35:so=32:pi=33:ex=31:bd=1;36:cd=1;33:su=30;41:sg=30;46:tw=30;42:ow=30;43'
      fi

      # Ignore useless commands and functions
      zstyle ':completion:*:functions' ignored-patterns '(_*|pre(cmd|exec)|prompt_*)'

      # Array completion element sorting
      zstyle ':completion:*:*:-subscript-:*' tag-order 'indexes' 'parameters'

      # Directories
      zstyle ':completion:*:*:cd:*:directory-stack' menu yes select
      zstyle ':completion:*' squeeze-slashes true

      # History
      zstyle ':completion:*:history-words' stop yes
      zstyle ':completion:*:history-words' remove-all-dups yes
      zstyle ':completion:*:history-words' list false
      zstyle ':completion:*:history-words' menu yes

      # Populate hostname completion
      zstyle -e ':completion:*:hosts' hosts 'reply=(
        ''${=''${=''${=''${''${(f)"$(cat {/etc/ssh/ssh_,~/.ssh/}known_hosts{,2} 2>/dev/null)"}%%[#| ]*}//\]:[0-9]*/ }//,/ }//\[/ }
        ''${=''${(f)"$(cat /etc/hosts 2>/dev/null)"}%%(\#)*}
        ''${=''${''${''${(@M)''${(f)"$(cat ~/.ssh/config{,.d/*(N)} 2>/dev/null)"}:#Host *}#Host }:#*\**}:#*\?*}}
      )'

      # Don't complete uninteresting users
      zstyle ':completion:*:*:*:users' ignored-patterns \
        '_*' adm amanda apache avahi beaglidx bin cacti canna clamav daemon dbus \
        distcache dovecot fax ftp games gdm gkrellmd gopher hacluster haldaemon \
        halt hsqldb ident junkbust ldap lp mail mailman mailnull mldonkey mysql \
        nagios named netdump news nfsnobody nobody nscd ntp nut nx openvpn \
        operator pcap postfix postgres privoxy pulse pvm quagga radvd rpc rpcuser \
        rpm shutdown squid sshd sync uucp vcsa xfs

      # ... unless we really want to
      zstyle ':completion:*' single-ignored show

      # Ignore multiple entries
      zstyle ':completion:*:(rm|kill|diff):*' ignore-line other
      zstyle ':completion:*:rm:*' file-patterns '*:all-files'

      # Man pages
      zstyle ':completion:*:manuals' separate-sections true
      zstyle ':completion:*:manuals.(^1*)' insert-sections true
    '';

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
      # zsh-completions fpath
      # ============================================================================
      fpath=(${pkgs.zsh-completions}/share/zsh/site-functions $fpath)

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
    pure-prompt       # Pure prompt
    zoxide            # Smarter cd
    zsh-completions   # Additional completion definitions
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
