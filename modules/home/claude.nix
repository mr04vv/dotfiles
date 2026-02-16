{ config, pkgs, ... }:

{
  # Claude Code configuration
  home.file.".claude/settings.json" = {
    force = true;
    text = builtins.toJSON {
    "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    env = {
      CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
    };
    permissions = {
      allow = [
        "Bash(rg:*)"
        "Bash(find:*)"
        "Bash(ls:*)"
        "Bash(grep:*)"
        "Bash(diff:*)"
        "Bash(mkdir:*)"
        "Bash(cat:*)"
        "Bash(gh pr view:*)"
        "Bash(gh pr diff:*)"
        "Bash(docker compose:*)"
        "Bash(docker compose exec:*)"
        "Bash(docker compose logs:*)"
        "Bash(pnpm remove*)"
        "Bash(pnpm run build)"
        "Bash(mkdir -p*)"
        "Edit(**/src/**/*.ts)"
        "Edit(**/src/**/*.tsx)"
        "Edit(**/src/**/*.go)"
        "Edit(**/src/**/*.rb)"
        "Read(**/src/**/*.ts)"
        "Read(**/src/**/*.tsx)"
        "Read(**/*.md)"
        "Read(**/src/**/*.go)"
        "Read(**/src/**/*.rb)"
        "Read(**/Atrae/**/*)"
        "Edit(**/Atrae/**/*)"
        "WebFetch"
        "Bash(ni)"
        "Edit(**/.claude/settings.json)"
        "Edit(**/.claude/CLAUDE.md)"
        "Read(**/.claude/CLAUDE.md)"
        "Read(**/.claude/settings.json)"
        "Bash(gh pr:*)"
        "Bash(gh run list:*)"
        "Bash(gh run view:*)"
        "Bash(git log:*)"
        "Bash(git show:*)"
      ];
      deny = [
        "Bash(git push -f *)"
        "Bash(git push --force *)"
        "Bash(sudo:*)"
        "Bash(rm -rf:*)"
        "Bash(git config:*)"
        "Bash(git reset:*)"
        "Bash(git rebase:*)"
        "Bash(chmod 777:*)"
        "Bash(gh repo delete:*)"
        "Read(.env.*)"
        "Read(id_rsa)"
        "Read(id_ed25519)"
        "Read(**/*token*)"
        "Write(.env*)"
        "Write(**/secrets/**)"
        "Bash(pnpm publish *)"
        "Bash(nr publish *)"
        "Read(~/.ssh/**)"
        "Read(~/.aws/**)"
        "Bash(grep *)"
        "Bash(find *)"
        "Bash(cat *)"
        "Bash(head *)"
        "Bash(tail *)"
        "Bash(curl *)"
        "Bash(wget *)"
      ];
      ask = [
        "Read(**/Atrae/**/.*)"
        "Edit(**/Atrae/**/.*)"
        "Bash(ni:*)"
        "Bash(pnpm add:*)"
        "Bash(yarn add:*)"
        "Bash(npm i:*)"
        "Bash(npm install:*)"
      ];
      defaultMode = "default";
    };
    model = "opusplan";
    hooks = {
      PreToolUse = [
        {
          matcher = "Bash";
          hooks = [
            {
              type = "command";
              command = "~/.claude/scripts/deny-check.sh";
            }
          ];
        }
      ];
      PostToolUse = [
        {
          matcher = "Edit|MultiEdit|Write";
          hooks = [
            {
              type = "command";
              command = "if [ -f biome.json ] || [ -f biome.jsonc ]; then nr check:fix; fi";
            }
          ];
        }
      ];
      Notification = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "/Applications/Utilities/Notifier.app/Contents/MacOS/Notifier --type banner --title \"許可待ち通知\" --message \"Claudeが許可を求めてるにゃ🐈️\" --messageaction \"/usr/bin/open /Applications/Ghostty.app\"";
            }
          ];
        }
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "/usr/bin/afplay --volume 0.02 ~/.claude/cat-amae.mp3";
            }
          ];
        }
      ];
      Stop = [
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "/Applications/Utilities/Notifier.app/Contents/MacOS/Notifier --type banner --title \"完了通知\" --message \"Claudeのタスクが完了したにゃ🐈️\" --messageaction \"/usr/bin/open /Applications/Ghostty.app\"";
            }
          ];
        }
        {
          matcher = "";
          hooks = [
            {
              type = "command";
              command = "/usr/bin/afplay --volume 0.02 ~/.claude/cat.mp3";
            }
          ];
        }
      ];
    };
    statusLine = {
      type = "command";
      command = "~/.claude/statusline.py";
      padding = 0;
    };
    alwaysThinkingEnabled = false;
    };
  };

  # Claude scripts
  home.file.".claude/scripts/deny-check.sh" = {
    force = true;
    source = ./claude/scripts/deny-check.sh;
    executable = true;
  };

  home.file.".claude/statusline.py" = {
    force = true;
    source = ./claude/statusline.py;
    executable = true;
  };

  # Claude audio files
  home.file.".claude/cat.mp3" = {
    force = true;
    source = ./claude/cat.mp3;
  };
  home.file.".claude/cat-amae.mp3" = {
    force = true;
    source = ./claude/cat-amae.mp3;
  };

  # Global CLAUDE.md
  home.file.".claude/CLAUDE.md" = {
    force = true;
    source = ./claude/CLAUDE.md;
  };
}
