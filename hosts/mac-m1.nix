{ config, lib, pkgs, ... }:

{
  imports = [ ../modules/home/bootstrap.nix ];

  # M1 Mac specific packages and configuration
  home.packages = with pkgs; [
    # ARM development tools (M1/M2 Mac only)
    gcc-arm-embedded  # ARM GCC toolchain
    qmk               # QMK firmware builder (requires gcc-arm-embedded)

    # Upstream ships an Apple Silicon build only, so this cannot live in
    # modules/home/default.nix alongside the cross-host packages.
    terminal-browser  # Browser rendered inside the terminal
  ];

  # Herdr's GUI app is not in nixpkgs and ships no Intel Mac build. The
  # official installer keeps the release signature intact and the app updates
  # itself afterwards, so this only bootstraps it when missing.
  home.activation.herdrApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "$HOME/Applications/Herdr.app" ]; then
      run env PATH="${lib.makeBinPath [ pkgs.curl pkgs.gnutar ]}:/usr/bin:/bin" \
        ${pkgs.bash}/bin/sh -c '${pkgs.curl}/bin/curl -fsSL https://releases.herdr.dev/app/install.sh | sh' \
        || echo "herdr: Herdr.app install failed; rerun darwin-rebuild to retry" >&2
    fi
  '';

  # M1-specific environment variables
  home.sessionVariables = {
    # Add any M1-specific environment variables here
  };
}
