{ config, pkgs, ... }:

{
  programs.zellij = {
    enable = true;
  };

  xdg.configFile."zellij/config.kdl".text = ''
    keybinds {
      shared {
        bind "Alt [" { MoveFocus "Left"; }
        bind "Alt ]" { MoveFocus "Right"; }
        bind "Super Alt [" { GoToPreviousTab; }
        bind "Super Alt ]" { GoToNextTab; }
        bind "Ctrl Alt [" { GoToPreviousTab; }
        bind "Ctrl Alt ]" { GoToNextTab; }
      }
    }
  '';
}
