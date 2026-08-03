final: prev:

{
  # pipx 1.14.0's tests/test_inject.py fails at collection time under the
  # pytest 9 in nixpkgs 26.11: `parametrize("pkg_spec", "black==22.8.0")` is
  # now iterated character by character instead of being treated as a single
  # value, so pytest reports 1 name against 13 values. Upstream nixpkgs already
  # lists "inject" in `disabledTests`, but that is a `-k` filter and runs after
  # collection, so it cannot suppress this. Ignore the file outright until
  # nixpkgs ships a fixed pipx.
  pipx = prev.pipx.overridePythonAttrs (old: {
    disabledTestPaths = (old.disabledTestPaths or [ ]) ++ [ "tests/test_inject.py" ];
  });
}
