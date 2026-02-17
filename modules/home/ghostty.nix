{ config, pkgs, lib, ... }:

{
  # Ghostty terminal configuration
  # Note: This is macOS-specific config
  # Linux config is in hosts/wsl.nix

  home.file."Library/Application Support/com.mitchellh.ghostty/config" = lib.mkIf pkgs.stdenv.isDarwin {
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
