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

  # Corporate Netskope SSL-inspection CA (public certs only, no private keys).
  # Adds the CA to /etc/ssl/certs/ca-certificates.crt (NIX_SSL_CERT_FILE), which
  # covers host-side git/curl during flake evaluation.
  #
  # NOTE: with Determinate Nix (nix.enable = false) the build daemon uses its own
  # Keychain-synced bundle (/etc/nix/macos-keychain.crt), NOT this file, so it does
  # not fix fetches inside the FOD build sandbox. For that, the CA must be marked as
  # explicitly trusted (trustRoot) in the System keychain so Determinate syncs it:
  #   sudo security add-trusted-cert -d -r trustRoot \
  #     -k /Library/Keychains/System.keychain modules/darwin/certs/netskope-ca.crt
  security.pki.certificateFiles = [ ./certs/netskope-ca.crt ];

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
