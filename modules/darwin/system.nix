{ config, pkgs, ... }:

{
  system.defaults = {
    # Finder settings
    finder = {
      AppleShowAllExtensions = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle = "Nlsv"; # List view
      _FXShowPosixPathInTitle = true;
    };

    # NSGlobalDomain (system-wide) settings
    NSGlobalDomain = {
      # Dark mode
      AppleInterfaceStyle = "Dark";

      # Key repeat settings
      KeyRepeat = 2;
      InitialKeyRepeat = 15;

      # Expand save and print panels by default
      NSNavPanelExpandedStateForSaveMode = true;
      NSNavPanelExpandedStateForSaveMode2 = true;
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;

      # Disable automatic capitalization
      NSAutomaticCapitalizationEnabled = false;

      # Disable smart dashes
      NSAutomaticDashSubstitutionEnabled = false;

      # Disable automatic period substitution
      NSAutomaticPeriodSubstitutionEnabled = false;

      # Disable smart quotes
      NSAutomaticQuoteSubstitutionEnabled = false;

      # Disable auto-correct
      NSAutomaticSpellingCorrectionEnabled = false;

      # Enable full keyboard access for all controls
      AppleKeyboardUIMode = 3;
    };

    # Trackpad settings
    trackpad = {
      Clicking = true; # Tap to click
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
    };

    # Screencapture settings
    screencapture = {
      location = "~/Pictures/Screenshots";
      type = "png";
    };
  };

  # Keyboard settings
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };
}
