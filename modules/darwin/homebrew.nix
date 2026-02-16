{ config, pkgs, ... }:

{
  # Homebrew configuration for GUI apps and macOS-specific tools
  # that are not available or well-supported in nixpkgs
  homebrew = {
    enable = true;

    # Automatically update Homebrew and upgrade packages
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";  # Uninstall packages not listed
    };

    # Taps (third-party repositories)
    taps = [
      # homebrew/cask and homebrew/cask-versions are no longer needed
      # They are built-in to modern Homebrew
    ];

    # GUI Applications (Casks)
    casks = [
      # Browsers
      "arc"
      "firefox"
      "microsoft-edge"

      # Development Tools
      "cursor"              # AI-powered code editor
      "bruno"               # API client
      "docker"              # Docker Desktop
      "wezterm"             # Terminal emulator
      "tableplus"           # Database GUI
      "sequel-ace"          # MySQL GUI

      # Design & Collaboration
      "figma"               # Design tool
      "notion"              # Note-taking
      "obsidian"            # Note-taking

      # Productivity
      "raycast"             # Spotlight replacement
      "amethyst"            # Tiling window manager
      "karabiner-elements"  # Keyboard customizer

      # Hardware-specific
      "logi-options+"       # Logitech Options+

      # Screen Recording
      "screen-studio"       # Screen recorder

      # GitHub
      "github"              # GitHub Desktop

      # Keyboard Firmware
      "qmk-toolbox"         # QMK Toolbox

      # Utilities
      "ngrok"               # Tunnel service
      "flux"                # Blue light filter (f.lux)
      "hammerspoon"         # Automation tool
    ];

    # CLI tools via Homebrew (if not available in nixpkgs)
    brews = [
      # Most CLI tools are managed via Nix now
      # Only keep here if absolutely necessary
    ];

    # Mac App Store apps (requires mas-cli)
    masApps = {
      # Add Mac App Store apps here if needed
      # Example: "Xcode" = 497799835;
    };
  };
}
