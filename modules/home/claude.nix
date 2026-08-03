{ config, lib, pkgs, ... }:

{
  home.activation.claudeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (''
    # Single files
    install -D -m 644 ${./claude/CLAUDE.md} ${config.home.homeDirectory}/.claude/CLAUDE.md
    install -D -m 644 ${./claude/settings.json} ${config.home.homeDirectory}/.claude/settings.json
    install -D -m 644 ${./claude/keybindings.json} ${config.home.homeDirectory}/.claude/keybindings.json
    install -D -m 755 ${./claude/statusline.py} ${config.home.homeDirectory}/.claude/statusline.py
    install -D -m 755 ${./claude/statusline-command.sh} ${config.home.homeDirectory}/.claude/statusline-command.sh
    install -D -m 755 ${./claude/scripts/deny-check.sh} ${config.home.homeDirectory}/.claude/scripts/deny-check.sh
    install -D -m 644 ${./claude/cat.mp3} ${config.home.homeDirectory}/.claude/cat.mp3
    install -D -m 644 ${./claude/cat-amae.mp3} ${config.home.homeDirectory}/.claude/cat-amae.mp3
    install -D -m 644 ${./claude/themes/midnight.json} ${config.home.homeDirectory}/.claude/themes/midnight.json

    # skills (chmod before cp to handle read-only files from previous runs)
    mkdir -p ${config.home.homeDirectory}/.claude/skills
    chmod -R u+w ${config.home.homeDirectory}/.claude/skills 2>/dev/null || true
    cp -r ${./claude/skills}/. ${config.home.homeDirectory}/.claude/skills/
    # _shared is a source-only dir (holds the diff-page script shared by
    # diff-explain and diff-review); it is not a skill, so drop it from the
    # deployed skills tree and fan the script out into each skill's scripts/.
    # chmod first: files copied from the nix store are read-only, and macOS
    # rm refuses to remove read-only files.
    chmod -R u+w ${config.home.homeDirectory}/.claude/skills/_shared 2>/dev/null || true
    rm -rf ${config.home.homeDirectory}/.claude/skills/_shared
    for skill in diff-explain diff-review; do
      mkdir -p ${config.home.homeDirectory}/.claude/skills/$skill/scripts
      install -m 755 ${./claude/skills/_shared/build_diff_page.py} \
        ${config.home.homeDirectory}/.claude/skills/$skill/scripts/build_diff_page.py
    done

    # commands
    mkdir -p ${config.home.homeDirectory}/.claude/commands
    chmod -R u+w ${config.home.homeDirectory}/.claude/commands 2>/dev/null || true
    cp -r ${./claude/commands}/. ${config.home.homeDirectory}/.claude/commands/

    # codex
    install -D -m 644 ${./claude/codex/config.toml} ${config.home.homeDirectory}/.codex/config.toml
    mkdir -p ${config.home.homeDirectory}/.codex/skills/to-claude
    chmod -R u+w ${config.home.homeDirectory}/.codex/skills 2>/dev/null || true
    cp -r ${./claude/codex/skills}/. ${config.home.homeDirectory}/.codex/skills/
    # shared skills (single source in claude/skills, deployed to both claude and codex)
    # copy CONTENTS into a named dir so the target is ~/.codex/skills/<skill>
    # (not the nix store's <hash>-<skill> path), and fan out the shared script.
    for skill in diff-explain diff-review; do
      mkdir -p ${config.home.homeDirectory}/.codex/skills/$skill/scripts
      cp -r ${./claude/skills}/$skill/. ${config.home.homeDirectory}/.codex/skills/$skill/
      install -m 755 ${./claude/skills/_shared/build_diff_page.py} \
        ${config.home.homeDirectory}/.codex/skills/$skill/scripts/build_diff_page.py
    done
    # skills vendored from third-party repos (see claude/VENDORED-SKILLS.md
    # for origins and update procedure). Plain copies -- no shared-script
    # fan-out needed.
    for skill in paper-details html documenting-with-sources writing-quotation explain \
                 grilling grill-me navigating quizzing tutoring; do
      mkdir -p ${config.home.homeDirectory}/.codex/skills/$skill
      cp -r ${./claude/skills}/$skill/. ${config.home.homeDirectory}/.codex/skills/$skill/
    done
  ''
  # terminal-browser ships its own agent skill. Upstream only builds for Apple
  # Silicon, so referencing the package on any other system would throw.
  + lib.optionalString (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") ''
    for base in .claude .codex; do
      install -D -m 644 ${pkgs.terminal-browser}/share/terminal-browser/SKILL.md \
        ${config.home.homeDirectory}/$base/skills/terminal-browser/SKILL.md
    done
  '');
}
