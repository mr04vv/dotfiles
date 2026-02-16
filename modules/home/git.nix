{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      # User information
      user = {
        name = "mr04vv";
        email = "mr04vv@gmail.com";
      };

      # Core settings
      core = {
        editor = "nvim";
        pager = "less -FRX";
      };

      # Pull behavior
      pull.rebase = false;

      # Init default branch
      init.defaultBranch = "main";

      # ghq root
      ghq.root = "~/dev";

      # URL rewrites for GitHub
      url."git@github.com:".insteadOf = "https://github.com/";

      # Git aliases
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      };
    };
  };
}
