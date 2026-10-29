{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      # User information
      user = {
        name = "mr04vv";
        email = "24749358+mr04vv@users.noreply.github.com";
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

      # Remove remote-tracking branches deleted on the remote
      fetch.prune = true;

      # Fetch GitHub over HTTPS (gh auth) even for SSH URLs
      url."https://github.com/".insteadOf = "git@github.com:";

      # Authenticate GitHub HTTPS with gh's token (the empty entry drops osxkeychain)
      credential."https://github.com".helper = [ "" "!gh auth git-credential" ];

      # ghq root
      ghq.root = "~/src";

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
