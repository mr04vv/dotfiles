final: prev:

let
  version = "0.20.2";

  sources = {
    "aarch64-darwin" = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_darwin_arm64.zip";
      hash = "sha256-wjzbnRSwZBTdzOvZH+sc1jZy/nbCjJyL26gB4BjVwNI=";
    };
    "x86_64-darwin" = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_darwin_amd64.zip";
      hash = "sha256-ioIUq49uCldVZbnMoqBKvntP+euajkVPan0M+5Mhhno=";
    };
    "x86_64-linux" = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_linux_amd64.tar.gz";
      hash = "sha256-ncDgVF2xZHPumZLE/kQXtwkfoObC83ePcFCHrZSan20=";
    };
    "aarch64-linux" = {
      url = "https://github.com/k1LoW/mo/releases/download/v${version}/mo_v${version}_linux_arm64.tar.gz";
      hash = "sha256-2xqtCpogdbj0kTQYBNkpLLIgsG94GToAZOiUWH1o64A=";
    };
  };

  src = sources.${final.stdenv.hostPlatform.system} or (throw "Unsupported system: ${final.stdenv.hostPlatform.system}");
in
{
  mo = final.stdenv.mkDerivation {
    pname = "mo";
    inherit version;

    src = final.fetchurl {
      inherit (src) url hash;
    };

    nativeBuildInputs = final.lib.optionals final.stdenv.isDarwin [ final.unzip ];

    sourceRoot = ".";

    installPhase = ''
      install -D -m 755 mo $out/bin/mo
    '';

    meta = {
      description = "Markdown viewer powered by browser with GitHub-flavored rendering";
      homepage = "https://github.com/k1LoW/mo";
      license = final.lib.licenses.mit;
      mainProgram = "mo";
    };
  };
}
