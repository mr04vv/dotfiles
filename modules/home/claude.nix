{ config, lib, ... }:

{
  home.activation.claudeConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Single files
    install -D -m 644 ${./claude/CLAUDE.md} ${config.home.homeDirectory}/.claude/CLAUDE.md
    install -D -m 644 ${./claude/settings.json} ${config.home.homeDirectory}/.claude/settings.json
    install -D -m 644 ${./claude/keybindings.json} ${config.home.homeDirectory}/.claude/keybindings.json
    install -D -m 755 ${./claude/statusline.py} ${config.home.homeDirectory}/.claude/statusline.py
    install -D -m 755 ${./claude/statusline-command.sh} ${config.home.homeDirectory}/.claude/statusline-command.sh
    install -D -m 755 ${./claude/scripts/deny-check.sh} ${config.home.homeDirectory}/.claude/scripts/deny-check.sh
    install -D -m 644 ${./claude/cat.mp3} ${config.home.homeDirectory}/.claude/cat.mp3
    install -D -m 644 ${./claude/cat-amae.mp3} ${config.home.homeDirectory}/.claude/cat-amae.mp3

    # skills (chmod before cp to handle read-only files from previous runs)
    mkdir -p ${config.home.homeDirectory}/.claude/skills
    chmod -R u+w ${config.home.homeDirectory}/.claude/skills 2>/dev/null || true
    cp -r ${./claude/skills}/. ${config.home.homeDirectory}/.claude/skills/

    # commands
    mkdir -p ${config.home.homeDirectory}/.claude/commands
    chmod -R u+w ${config.home.homeDirectory}/.claude/commands 2>/dev/null || true
    cp -r ${./claude/commands}/. ${config.home.homeDirectory}/.claude/commands/

    # codex
    install -D -m 644 ${./claude/codex/config.toml} ${config.home.homeDirectory}/.codex/config.toml
    mkdir -p ${config.home.homeDirectory}/.codex/skills/to-claude
    chmod -R u+w ${config.home.homeDirectory}/.codex/skills 2>/dev/null || true
    cp -r ${./claude/codex/skills}/. ${config.home.homeDirectory}/.codex/skills/
  '';
}
