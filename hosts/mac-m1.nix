{ config, pkgs, ... }:

{
  # M1 Mac specific packages and configuration
  home.packages = with pkgs; [
    # Add M1-specific packages here if needed
  ];

  # M1-specific environment variables
  home.sessionVariables = {
    # Add any M1-specific environment variables here
  };
}
