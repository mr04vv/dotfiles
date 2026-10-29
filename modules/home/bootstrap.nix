{ config, lib, pkgs, ... }:
# Sets up what lives outside Nix on a fresh Mac, so one darwin-rebuild brings it
# up. Each step skips itself once done and only warns when it fails, so a
# rebuild never stops halfway because of the network or a missing login.
let
  home = config.home.homeDirectory;
  localBin = "${home}/.local/bin";
  # Activation runs with a bare PATH. ~/.local/bin is on it so the installers
  # see it already there and leave the Home Manager-owned shell rc alone.
  path = lib.makeBinPath (with pkgs; [ curl coreutils ]) + ":${localBin}:/usr/bin:/bin";
in
{
  # Claude Code and Codex use their own installers, which keep them updated;
  # the nixpkgs builds lag behind releases.
  home.activation.agentClis = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (
      export PATH=${path}:$PATH
      if [ ! -x ${localBin}/claude ]; then
        run sh -c 'curl -fsSL https://claude.ai/install.sh | bash' </dev/null \
          || echo "Claude Code install failed; run: curl -fsSL https://claude.ai/install.sh | bash" >&2
      fi
      if [ ! -x ${localBin}/codex ]; then
        run sh -c 'curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh' </dev/null \
          || echo "Codex install failed; run: curl -fsSL https://chatgpt.com/codex/install.sh | sh" >&2
      fi
    )
  '';
}
