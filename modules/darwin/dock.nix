{ config, pkgs, ... }:

{
  system.defaults.dock = {
    autohide = true;
    show-recents = false;
    tilesize = 48;
    orientation = "bottom";

    # Don't automatically rearrange Spaces based on most recent use
    mru-spaces = false;

    # Minimize windows into application icon
    minimize-to-application = true;

    # Disable magnification
    magnification = false;

    # Show indicator lights for open applications
    show-process-indicators = true;
  };
}
