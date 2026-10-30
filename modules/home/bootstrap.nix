{ config, lib, pkgs, ... }:
# Sets up what lives outside Nix on a fresh Mac, so one darwin-rebuild brings it
# up. Each step skips itself once done and only warns when it fails, so a
# rebuild never stops halfway because of the network or a missing login.
let
  home = config.home.homeDirectory;
  localBin = "${home}/.local/bin";
  dotfiles = "${home}/dotfiles";
  agentConfig = "${home}/src/github.com/mr04vv/agent-config";
  todoSessions = "${home}/src/github.com/mr04vv/claude-todo-sessions";
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

  # Clones what repos.txt and repos.private.txt list and is not there yet. The
  # lists are read at activation time: repos.private.txt is gitignored and must
  # not end up in the world-readable Nix store. Private repositories need the gh
  # login, so the step waits for it.
  home.activation.cloneRepos = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    (
      export PATH=${lib.makeBinPath (with pkgs; [ git gh ghq coreutils ])}:$PATH
      if ! gh auth status >/dev/null 2>&1; then
        echo "Skipping repository clone: run gh auth login, then rebuild" >&2
      else
        root=$(ghq root)
        # if, not &&: activation runs under set -e and pipefail, and a false
        # test as a loop's last command would abort it.
        missing=$(for list in ${dotfiles}/repos.txt ${dotfiles}/repos.private.txt; do
          if [ -f "$list" ]; then cat "$list"; fi
        done | while read -r repo; do
          if [ -n "$repo" ] && [ ! -d "$root/$repo" ]; then echo "$repo"; fi
        done)
        if [ -n "$missing" ]; then
          printf '%s\n' "$missing" | run ghq get --parallel \
            || echo "Some repositories failed to clone; see above" >&2
        fi
      fi
    )
  '';

  # Links the Claude Code and Codex config from agent-config. install.sh is
  # safe to re-run and needs a Python with tomllib (3.11+).
  home.activation.agentConfig = lib.hm.dag.entryAfter [ "cloneRepos" ] ''
    (
      export PATH=${lib.makeBinPath (with pkgs; [ python3 coreutils findutils ])}:/usr/bin:/bin:$PATH
      if [ -x ${agentConfig}/install.sh ]; then
        run ${agentConfig}/install.sh || echo "agent-config install.sh failed; see above" >&2
      fi
    )
  '';

  # The todo-sessions plugin's MCP server is a symlink to target/release/cts,
  # which a clone does not have, so build it before installing the plugin.
  # The marketplace and the enabled flag come from agent-config's settings.json.
  # The build links with /usr/bin/cc (the repo's .cargo/config.toml). Only cts
  # is built: the workspace's Tauri app needs the frontend and Chromium too.
  home.activation.todoSessionsPlugin = lib.hm.dag.entryAfter [ "agentClis" "agentConfig" ] ''
    (
      export PATH=${lib.makeBinPath (with pkgs; [ rustup coreutils gnugrep ])}:/usr/bin:/bin:$PATH
      if [ -d ${todoSessions} ] && [ -x ${localBin}/claude ]; then
        if [ ! -x ${todoSessions}/target/release/cts ]; then
          rustup show active-toolchain >/dev/null 2>&1 || run rustup default stable
          (cd ${todoSessions} && run cargo build --release -p cts) \
            || echo "cts build failed; run cargo build --release -p cts in ${todoSessions}" >&2
        fi
        if [ -x ${todoSessions}/target/release/cts ] \
          && ! grep -qs '"todo-sessions@claude-todo-sessions"' ${home}/.claude/plugins/installed_plugins.json; then
          { run ${localBin}/claude plugin marketplace add ${todoSessions} \
            && run ${localBin}/claude plugin install todo-sessions@claude-todo-sessions; } </dev/null \
            || echo "todo-sessions plugin install failed; see above" >&2
        fi
      fi
    )
  '';
}
