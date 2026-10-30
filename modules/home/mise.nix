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

  # Shims only, no `mise activate`: its per-prompt `mise hook-env` slows tab
  # startup (each exec costs ~0.25s after the Mac sits idle). mkAfter keeps
  # the shims ahead of the volta/proto shims added by other initContent.
  programs.zsh.initContent = lib.mkAfter ''
    export PATH="$HOME/.local/share/mise/shims:$PATH"
  '';
}
