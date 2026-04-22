final: prev:

{
  gh = prev.gh.overrideAttrs (oldAttrs: rec {
    version = "2.90.0";

    src = prev.fetchFromGitHub {
      owner = "cli";
      repo = "cli";
      tag = "v${version}";
      hash = "sha256-yVc4UvC+CsW+pP/BJRjcOGX7h8zO2M8yM0m57Mr89JY=";
    };

    vendorHash = "sha256-hz6oMLTibnSLB11vEWsO0O5ZFGKYJaVce6POqINObnI=";
  });
}
