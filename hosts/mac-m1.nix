{ config, pkgs, ... }:

{
  # M1 Mac specific packages and configuration
  home.packages = with pkgs; [
    # ARM development tools (M1/M2 Mac only)
    gcc-arm-embedded  # ARM GCC toolchain
    qmk               # QMK firmware builder (requires gcc-arm-embedded)

    # Upstream ships an Apple Silicon build only, so this cannot live in
    # modules/home/default.nix alongside the cross-host packages.
    terminal-browser  # Browser rendered inside the terminal
  ];

  # M1-specific environment variables
  home.sessionVariables = {
    # Add any M1-specific environment variables here
  };
}
