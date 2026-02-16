{ config, pkgs, username, ... }:

{
  imports = [
    ./dock.nix
    ./system.nix
    ./homebrew.nix
  ];

  # Primary user for per-user defaults
  system.primaryUser = username;

  # Enable zsh
  programs.zsh.enable = true;

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
