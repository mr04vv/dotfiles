{ config, pkgs, ... }:

{
  # M1 Mac specific packages and configuration
  home.packages = with pkgs; [
    # ARM development tools (M1/M2 Mac only)
    gcc-arm-embedded  # ARM GCC toolchain
    qmk               # QMK firmware builder (requires gcc-arm-embedded)
  ];

  # M1-specific environment variables
  home.sessionVariables = {
    # Add any M1-specific environment variables here
  };
}
