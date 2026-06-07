{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.mise ];

  # mkAfter ensures mise activate runs after other initContent (including PATH setup),
  # so mise shims take priority over volta/proto shims.
  programs.zsh.initContent = lib.mkAfter ''
    # mise activation
    eval "$(mise activate zsh)"
  '';
}
