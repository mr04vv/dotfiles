{ config, lib, pkgs, ... }:

{
  # WSL specific packages and configuration
  home.packages = with pkgs; [
    # WSL で必要な追加パッケージがあればここに追加
  ];

  # WSL-specific environment variables
  home.sessionVariables = {
    # WSL 固有の環境変数があればここに追加
  };

  # デフォルトシェルを Nix 管理の zsh に設定
  home.activation.setDefaultShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    NIX_ZSH="$HOME/.nix-profile/bin/zsh"
    if [ -x "$NIX_ZSH" ]; then
      if ! /usr/bin/grep -qF "$NIX_ZSH" /etc/shells 2>/dev/null; then
        echo "$NIX_ZSH" | /usr/bin/sudo /usr/bin/tee -a /etc/shells >/dev/null
      fi
      CURRENT_SHELL=$(/usr/bin/getent passwd "$USER" | /usr/bin/cut -d: -f7)
      if [ "$CURRENT_SHELL" != "$NIX_ZSH" ]; then
        /usr/bin/sudo /usr/bin/chsh -s "$NIX_ZSH" "$USER"
      fi
    fi
  '';

  # WezTerm configuration (Windows側にコピーして使う)
  home.file.".config/wezterm/wezterm.lua" = {
    force = true;
    text = ''
      local wezterm = require 'wezterm'
      local act = wezterm.action
      local config = wezterm.config_builder()

      config.initial_cols = 120
      config.initial_rows = 28
      config.font_size = 10
      config.color_scheme = 'Desert'
      config.default_prog = { "wsl.exe", "--cd", "~" }

      config.keys = {
        { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
        { key = 'd', mods = 'CTRL', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
        { key = 'd', mods = 'CTRL|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
        { key = 'w', mods = 'CTRL', action = act.CloseCurrentPane { confirm = false } },
        { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
        { key = 'q', mods = 'CTRL', action = act.QuitApplication },
        { key = '[', mods = 'CTRL', action = act.ActivatePaneDirection 'Prev' },
        { key = ']', mods = 'CTRL', action = act.ActivatePaneDirection 'Next' },
        { key = '{', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
        { key = '}', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(1) },
      }

      return config
    '';
  };

  # WezTerm設定をWindows側にコピー
  home.activation.syncWezTermConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    WIN_HOME="/mnt/c/Users/mr04v"
    if [ -d "$WIN_HOME" ]; then
      /usr/bin/cp -f "$HOME/.config/wezterm/wezterm.lua" "$WIN_HOME/.wezterm.lua"
    fi
  '';

  # Ghostty configuration for Linux
  # macOS とはパスが異なるため上書き
  home.file.".config/ghostty/config" = {
    force = true;
    text = ''
      # Fonts
      font-family = "Jetbrains Mono"
      font-family = "Noto Sans JP"
      font-family = "Noto Color Emoji"
      font-size = 14

      window-padding-x = 10
      window-padding-y = 10
      command = /bin/zsh
      theme = Desert

      # Quick terminal settings
      quick-terminal-position = "bottom"
      quick-terminal-screen = "mouse"
      quick-terminal-animation-duration = 0
      quick-terminal-space-behavior = "remain"
      quick-terminal-autohide = "false"
      keybind = "global:shift+cmd+\=toggle_quick_terminal"
      keybind = shift+enter=text:\n
      font-feature = "-dlig"
    '';
  };
}
