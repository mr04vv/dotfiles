{ config, pkgs, ... }:

{
  # WSL specific packages and configuration
  home.packages = with pkgs; [
    # WSL で必要な追加パッケージがあればここに追加
  ];

  # WSL-specific environment variables
  home.sessionVariables = {
    # WSL 固有の環境変数があればここに追加
  };

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
