command -v nvim

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
# Set editor default keymap to emacs (`-e`) or vi (`-v`)
bindkey -e
setopt share_history 
setopt append_history        # 履歴を追加 (毎回 .zsh_history を作るのではなく)
autoload -U history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^[[A" history-beginning-search-backward-end
bindkey "^[[B" history-beginning-search-forward-end

if command -v nvim >/dev/null 2>&1; then
  export EDITOR=${EDITOR:-nvim}
else
  export EDITOR=${EDITOR:-vim}
fi


export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
export PROTO_HOME="$HOME/.proto"
export PATH="$PROTO_HOME/shims:$PROTO_HOME/bin:$PATH"