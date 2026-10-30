{ config, pkgs, ... }:

let
  # Generate the zsh init script at build time instead of running
  # `atuin init zsh` on every shell start (each exec costs ~0.25s after the
  # Mac sits idle).
  atuinZshInit = pkgs.runCommand "atuin-init.zsh" { } ''
    HOME=$TMPDIR ${pkgs.lib.getExe config.programs.atuin.package} init zsh > $out
  '';
in
{
  programs.zsh.initContent = ''
    if [[ $options[zle] = on ]]; then
      source ${atuinZshInit}
    fi
  '';

  programs.atuin = {
    enable = true;
    # Replaced by the build-time init script above
    enableZshIntegration = false;
    settings = {
      # Disable cloud sync
      auto_sync = false;

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
