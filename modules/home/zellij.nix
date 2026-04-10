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

  xdg.configFile."zellij/layouts/work.kdl".text = let
    worksRoot = "${config.home.homeDirectory}/Works/Atrae";
    ghqRoot = "${config.home.homeDirectory}/src/github.com/Atrae";
  in ''
    layout {
      default_tab_template {
        pane size=1 borderless=true {
          plugin location="tab-bar"
        }
        children
        pane size=1 borderless=true {
          plugin location="status-bar"
        }
      }

      tab name="wevox" focus=true {
        pane split_direction="vertical" {
          pane split_direction="horizontal" {
            pane cwd="${worksRoot}/wevox-mono-web"
            pane cwd="${worksRoot}/wevox-rest-bff"
          }
          pane split_direction="horizontal" {
            pane cwd="${worksRoot}/wevox-front"
            pane cwd="${worksRoot}/wevox"
          }
          pane split_direction="horizontal" {
            pane cwd="${worksRoot}/wevox-cerberus"
            pane
          }
        }
      }

      tab name="infra" {
        pane split_direction="vertical" {
          pane split_direction="horizontal" {
            pane cwd="${worksRoot}/wevox-k8s-front-mani"
            pane cwd="${worksRoot}/wevox-k8s-backend-mani"
          }
          pane split_direction="horizontal" {
            pane cwd="${ghqRoot}/wevox-k8s-admin-mani"
            pane cwd="${worksRoot}/wevox-k8s-web-mani"
          }
        }
      }

      tab name="other" {
        pane split_direction="vertical" {
          pane split_direction="horizontal" {
            pane cwd="${worksRoot}/atrae-github"
            pane cwd="${worksRoot}/wevox-manual-mysql-query"
          }
          pane split_direction="horizontal" {
            pane
            pane
          }
        }
      }

      tab name="gh-review-watcher" {
        pane command="gh-review-watcher"
      }
    }
  '';
}
