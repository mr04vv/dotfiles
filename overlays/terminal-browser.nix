final: prev:

let
  version = "0.3.3";

  # Upstream ships a prebuilt bundle only; there are no GitHub release assets.
  # The versioned URL under terminal-browser.sh is what the official installer
  # (https://terminal-browser.sh/install) downloads.
  sources = {
    "aarch64-darwin" = {
      url = "https://terminal-browser.sh/install/dl/stable/v${version}/terminal-browser-darwin-arm64.tar.gz";
      hash = "sha256-gAQjGCeiscquAyL5mEgllp1xbtVTwtfM3HhNPPhH/Qk=";
    };
  };

  src = sources.${final.stdenv.hostPlatform.system}
    or (throw "terminal-browser supports Apple Silicon macOS only, not ${final.stdenv.hostPlatform.system}");
in
{
  terminal-browser = final.stdenvNoCC.mkDerivation {
    pname = "terminal-browser";
    inherit version;

    src = final.fetchurl {
      inherit (src) url hash;
    };

    sourceRoot = "terminal-browser";

    # The bundle is a code-signed Electron app; stripping or re-signing it in
    # fixupPhase would invalidate the signature, so ship the tree as-is.
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/libexec $out/bin
      cp -R . $out/libexec/terminal-browser

      # The bundled launcher derives its root from $0, so it breaks when
      # symlinked into bin/. Write a wrapper that execs the real path instead.
      cat > $out/bin/terminal-browser <<EOF
      #!${final.runtimeShell}
      exec "$out/libexec/terminal-browser/bin/terminal-browser" "\$@"
      EOF
      chmod +x $out/bin/terminal-browser

      # Agent skill definition; claude.nix deploys it to ~/.claude and ~/.codex.
      install -D -m 644 skill/SKILL.md $out/share/terminal-browser/SKILL.md

      runHook postInstall
    '';

    meta = {
      description = "Browser that runs directly inside your existing terminal";
      homepage = "https://github.com/zenbu-labs/terminal-browser";
      license = final.lib.licenses.mit;
      platforms = [ "aarch64-darwin" ];
      mainProgram = "terminal-browser";
    };
  };
}
