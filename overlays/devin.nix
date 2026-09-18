final: prev:

let
  version = "3000.10.31";

  # Upstream ships prebuilt bundles only. URLs and checksums come from the
  # release manifest the official installer reads
  # (https://static.devin.ai/cli/current/manifest.json); bumping the version
  # means refreshing both from that manifest.
  sources = {
    "aarch64-darwin" = {
      url = "https://static.devin.ai/cli/${version}/devin-${version}-aarch64-apple-darwin.tar.gz";
      hash = "sha256-BR388p4PXLXwoHx1edyXJV/ufwLOTG/qzH1AZc52tb0=";
    };
    "x86_64-darwin" = {
      url = "https://static.devin.ai/cli/${version}/devin-${version}-x86_64-apple-darwin.tar.gz";
      hash = "sha256-ykUKE6fi2DosbmQcD4CEKCb5RMrTypO6iSp63jlIVVo=";
    };
    "x86_64-linux" = {
      url = "https://static.devin.ai/cli/${version}/devin-${version}-x86_64-unknown-linux.tar.gz";
      hash = "sha256-QyGNgO5JV29PhKH/1KTOx1XFRbXKmMWybvzlNAgk8zE=";
    };
    "aarch64-linux" = {
      url = "https://static.devin.ai/cli/${version}/devin-${version}-aarch64-unknown-linux.tar.gz";
      hash = "sha256-balrnIwjN4ksDa0KEseqp+Vov+91crv1TnoOyIkWujM=";
    };
  };

  src = sources.${final.stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${final.stdenv.hostPlatform.system}");
in
{
  devin = final.stdenvNoCC.mkDerivation {
    pname = "devin";
    inherit version;

    src = final.fetchurl {
      inherit (src) url hash;
    };

    sourceRoot = ".";

    # The macOS binary is Developer ID signed with the hardened runtime, which
    # gates its Keychain access; stripping or re-signing it in fixupPhase would
    # invalidate the signature. The Linux build is static-pie, so it needs no
    # patching either.
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      install -D -m 755 bin/devin $out/bin/devin
      cp -R share $out/share

      runHook postInstall
    '';

    meta = {
      description = "Devin CLI, Cognition's coding agent for the terminal";
      homepage = "https://devin.ai";
      license = final.lib.licenses.unfree;
      platforms = builtins.attrNames sources;
      mainProgram = "devin";
    };
  };
}
