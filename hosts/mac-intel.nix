{ config, pkgs, ... }:

{
  # Intel Mac specific packages and configuration
  home.packages = with pkgs; [
    # Add Intel-specific packages here if needed
  ];

  # Intel-specific environment variables
  home.sessionVariables = {
    # Add any Intel-specific environment variables here
  };
}
