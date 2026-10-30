{ config, pkgs, username, ... }:

{
  imports = [
    ./dock.nix
    ./system.nix
    ./homebrew.nix
  ];

  # Primary user for per-user defaults
  system.primaryUser = username;

  # Enable zsh. Prompt and compinit are set up by Home Manager's ~/.zshrc
  # (Pure + `compinit -C`), so skip the duplicate work in /etc/zshrc.
  programs.zsh = {
    enable = true;
    promptInit = "";
    enableGlobalCompInit = false;
    enableBashCompletion = false;
  };

  # Touch ID for sudo
  security.pam.services.sudo_local = {
    touchIdAuth = true;
  };

  # Nix settings
  nix = {
    # Determinate Nix compatibility
    enable = false;

    # Cachix substituters
    settings = {
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      experimental-features = [ "nix-command" "flakes" ];
    };
  };

  # System configuration
  system.stateVersion = 5;
}
