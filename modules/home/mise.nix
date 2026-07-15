{ config, pkgs, lib, ... }:

{
  home.packages = [ pkgs.mise ];

  # mkAfter ensures mise activate runs after other initContent (including PATH setup),
  # so mise shims take priority over volta/proto shims.
  programs.zsh.initContent = lib.mkAfter ''
    # mise activation
    eval "$(mise activate zsh)"
    # Ensure mise shims are on PATH for non-interactive child processes
    # (e.g. prek / git hooks) where `mise activate` does not propagate.
    export PATH="$HOME/.local/share/mise/shims:$PATH"
  '';
}
