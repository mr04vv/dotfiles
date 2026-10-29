{ config, pkgs, lib, ... }:

{
  programs.mise = {
    enable = true;
    # Activated by hand below so the shims land after the other PATH setup.
    enableZshIntegration = false;
    globalConfig.tools = {
      bun = "latest";
      pnpm = "12.6.0";
    };
  };

  # Fetch the tools above so a fresh machine has them without a manual `mise install`.
  home.activation.miseInstall = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run env MISE_YES=1 ${lib.getExe pkgs.mise} install \
      || echo "mise install failed; run it by hand" >&2
  '';

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
