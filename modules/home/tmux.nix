{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    mouse = true;
    prefix = "C-t";
    escapeTime = 0;
    historyLimit = 50000;

    extraConfig = ''
      # Enable true color support
      set-option -sa terminal-overrides ",xterm*:Tc"

      # Window and pane indexing
      set -g base-index 1
      set -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      # Split panes without prefix
      bind -n C-\\ split-window -h -c "#{pane_current_path}"
      bind -n C-- split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Kill pane without prefix
      bind -n C-x kill-pane

      # Pane navigation with Shift+Arrow
      bind -n S-Left select-pane -L
      bind -n S-Down select-pane -D
      bind -n S-Up select-pane -U
      bind -n S-Right select-pane -R

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Display panes time
      set -g display-panes-time 2000

      # Status bar
      set -g status-bg black
      set -g status-fg white
      set -g status-left-length 60
      set -g status-left "#[fg=green][#S] #[fg=yellow]C-t:Prefix | Shift+Arrow:Move "
      set -g status-right-length 60
      set -g status-right "#[fg=cyan]C-\\:V-Split C--:H-Split #[fg=white]%H:%M"
    '';
  };
}
