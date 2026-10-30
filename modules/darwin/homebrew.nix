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
      "fayazara/tap"        # Screendrop
    ];

    # GUI Applications (Casks)
    casks = [
      # Browsers
      "arc"
      "thebrowsercompany-dia"
      "firefox"
      "microsoft-edge"

      # Development Tools
      "bruno"               # API client
      "docker-desktop"      # Docker Desktop
      "tableplus"           # Database GUI
      "sequel-ace"          # MySQL GUI

      # Design & Collaboration
      "figma"               # Design tool
      "notion"              # Note-taking
      "obsidian"            # Note-taking

      # Productivity
      "claude"              # Claude Desktop (self-updates)
      "raycast"             # Spotlight replacement
      "amethyst"            # Tiling window manager
      "nani"                # Nani Translate

      # Hardware-specific
      "logi-options+"       # Logitech Options+

      # Screen Recording
      "screen-studio"       # Screen recorder
      "fayazara/tap/screendrop" # Screenshot + screen recorder

      # Keyboard Firmware
      "qmk-toolbox"         # QMK Toolbox

      # Utilities
      "ngrok"               # Tunnel service
      "flux-app"            # Blue light filter (f.lux)
      "hammerspoon"         # Automation tool
      "codexbar"            # Menu bar usage monitor for Codex/Claude
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
