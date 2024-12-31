# Amazon Q pre block. Keep at the top of this file.
[[ -f "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh" ]] && builtin source "${HOME}/Library/Application Support/amazon-q/shell/zshrc.pre.zsh"
# #
# # Input/output
# #
HISTFILE=~/.zsh_history
HISTSIZE=100
SAVEHIST=100
# Set editor default keymap to emacs (`-e`) or vi (`-v`)
bindkey -e
setopt share_history 
setopt append_history        # 履歴を追加 (毎回 .zsh_history を作るのではなく)
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^[[A" history-beginning-search-backward-end
bindkey "^[[B" history-beginning-search-forward-end

# Remove path separator from WORDCHARS.
# WORDCHARS=${WORDCHARS//[\/]}

# -----------------
# Zim configuration
# -----------------

#
# zsh-syntax-highlighting
#

# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)


# ------------------
# Initialize modules
# ------------------

ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh \
        https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi
# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
# Initialize modules.
source ${ZIM_HOME}/init.zsh

source "$ZRCDIR/base.zsh"
source "$ZRCDIR/alias.zsh"

export PATH="$PROTO_HOME/shims:$PROTO_HOME/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export LIBRARY_PATH="/opt/homebrew/lib$LIBRARY_PATH"
export CPATH="/opt/homebrew/include$CPATH"
export PATH="$HOME/.gvm/bin:$PATH"

export VOLTA_FEATURE_PNPM=1
# Created by `pipx` on 2024-09-10 04:34:52
export PATH="$PATH:/Users/takutomori/.local/bin"
export PATH="/opt/homebrew/opt/mysql@8.0/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/takutomori/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/takutomori/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/takutomori/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/takutomori/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

fpath+=("/opt/homebrew/share/zsh/site-functions")
PURE_PROMPT_SYMBOL='🐈'

zstyle ':prompt:pure:user' color white
autoload -U promptinit; promptinit
prompt pure
zstyle :prompt:pure:user show yes