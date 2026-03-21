{ config, pkgs, ... }:

{
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      # Disable cloud sync
      auto_sync = false;
      sync_address = "";

      # Search settings
      search_mode = "fuzzy";
      filter_mode = "global";

      # UI
      style = "compact";
      inline_height = 20;
      show_preview = true;

      # Store timestamps in UTC
      dialect = "us";
    };
  };
}
