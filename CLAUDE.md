# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Nix flake-based dotfiles managing three hosts via nix-darwin + Home Manager (macOS) and NixOS-WSL (Linux). All packages and configurations are declared in Nix — **never use Homebrew to install CLI tools or packages**. Homebrew is only used for GUI casks (`modules/darwin/homebrew.nix`).

## Key Commands

```bash
# Apply configuration (macOS, requires sudo)
sudo darwin-rebuild switch --flake ~/dotfiles#mac-m1    # M1 Mac (takutomori)
sudo darwin-rebuild switch --flake ~/dotfiles#mac-intel  # Intel Mac (mooriii)

# Apply configuration (WSL)
sudo nixos-rebuild switch --flake ~/dotfiles#wsl

# Apply home-manager only (WSL, no sudo)
home-manager switch --flake ~/dotfiles#wsl

# Update flake inputs
nix flake update

# IMPORTANT: New .nix files must be git-tracked before rebuild
git add <new-file>.nix
```

## Architecture

```
flake.nix                   # Entry point: defines 3 hosts, wires inputs
├── hosts/
│   ├── mac-m1.nix          # Host-specific overrides (ARM tools, qmk)
│   ├── mac-intel.nix       # (currently empty)
│   └── wsl.nix             # WSL shell setup, AHK/WezTerm configs synced to Windows
├── modules/
│   ├── home/               # Home Manager modules (shared across all hosts)
│   │   ├── default.nix     # Package list + imports all sub-modules
│   │   ├── git.nix         # Git config, aliases, ghq
│   │   ├── zsh.nix         # Zsh + Pure prompt, aliases, PATH, zoxide
│   │   ├── neovim.nix      # Neovim nightly, 80+ plugins, LSP, Copilot (~1500 lines)
│   │   ├── tmux.nix        # Tmux with vi mode, custom keybinds
│   │   ├── zellij.nix      # Zellij multiplexer
│   │   ├── ghostty.nix     # Ghostty terminal config
│   │   ├── hammerspoon.nix # macOS window management (Lua)
│   │   ├── claude.nix      # Claude CLI: skills, settings, hooks, statusline
│   │   └── fonts.nix       # Font installation (JetBrains Mono, Noto)
│   └── darwin/             # nix-darwin modules (macOS only)
│       ├── default.nix     # Imports + nix config + Touch ID sudo
│       ├── system.nix      # macOS defaults (Finder, keyboard, trackpad)
│       ├── dock.nix        # Dock preferences
│       └── homebrew.nix    # GUI casks only (Arc, Docker, Figma, etc.)
└── overlays/               # Custom package overlays (currently empty)
```

## How to Add a New Tool

1. If Home Manager has a `programs.<tool>` module: create `modules/home/<tool>.nix`, enable the program, and add the import to `modules/home/default.nix`
2. If it's a simple package with no config: add it to `home.packages` in `modules/home/default.nix`
3. If it's a GUI-only macOS app: add it as a cask in `modules/darwin/homebrew.nix`
4. **Always `git add` new `.nix` files** — Nix flakes only see git-tracked files

## Conventions

- Platform-specific code uses `pkgs.stdenv.isDarwin` / `pkgs.stdenv.isLinux` conditionals
- Host-specific overrides go in `hosts/<name>.nix`, shared config goes in `modules/home/`
- Neovim config is fully declarative Lua embedded in `neovim.nix` (not external config files)
- `claude.nix` deploys Claude CLI configuration from `modules/home/claude/` to `~/.claude/` via activation hooks
- Nix language (`.nix` files): use nixpkgs-unstable conventions
