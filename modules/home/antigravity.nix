{ lib, pkgs, ... }:

let
  installUrl = "https://antigravity.google/cli/install.sh";
  agyBin = "$HOME/.local/bin/agy";
in
{
  # nixpkgs has no package for the Antigravity CLI (`agy`), and the binary
  # updates itself, so nix cannot pin it. The official installer is a no-op when
  # agy is already present, so this only runs on the first activation. A failed
  # download is reported but does not abort the rebuild. The installer shells
  # out to system tools (shasum, xattr) that activation's PATH lacks, hence the
  # /usr/bin fallback.
  home.activation.antigravityCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -x "${agyBin}" ]; then
      ${pkgs.curl}/bin/curl -fsSL ${installUrl} | PATH="${pkgs.curl}/bin:$PATH:/usr/bin:/bin" ${pkgs.bash}/bin/bash \
        || echo "warning: Antigravity CLI install failed" >&2
    fi
  '';
}
