{ config, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    mouse = true;
    prefix = "C-b";
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

      # Split panes using | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display "Config reloaded!"

      # Status bar
      set -g status-style 'bg=default,fg=white'
      set -g status-left-length 40
      set -g status-right-length 60
    '';
  };
}
