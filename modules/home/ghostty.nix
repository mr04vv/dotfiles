{ config, pkgs, lib, ... }:

{
  # Ghostty terminal configuration
  # Note: This is macOS-specific config
  # Linux config is in hosts/wsl.nix

  # ghostty-browser: open a URL in terminal-browser inside a fresh Ghostty tab.
  # Used as an escape hatch while the herdr-browser plugin is unstable -- an
  # agent running inside herdr calls `ghostty-browser <URL>` and Ghostty opens a
  # new tab on the OUTSIDE of herdr, so the browser is not subject to herdr's own
  # graphics pipeline. The tab's `initial input` runs the command on spawn, so no
  # separate keystroke injection is needed. terminal-browser is referenced by its
  # store path: a new tab runs the command before the login shell adds the Nix
  # profile to PATH, so the bare name would not resolve. macOS + Ghostty 1.3+
  # only; the first run prompts for Automation permission. Tabs live outside
  # herdr and are not managed by it.
  home.packages = lib.optionals pkgs.stdenv.isDarwin [
    (pkgs.writeShellScriptBin "ghostty-browser" ''
      if [ -z "$1" ]; then
        echo "usage: ghostty-browser <URL>" >&2
        exit 1
      fi
      osascript - "$1" <<'APPLESCRIPT'
      on run argv
        set targetUrl to item 1 of argv
        tell application "Ghostty"
          new tab in front window with configuration {initial input:"${pkgs.terminal-browser}/bin/terminal-browser open " & quoted form of targetUrl & "
      "}
        end tell
      end run
      APPLESCRIPT
    '')
  ];

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
    keybind = alt+left=unbind
    keybind = alt+right=unbind
    macos-option-as-alt = true
    font-feature = "-dlig"
    '';
  };
}
