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

## How to Add a New Tool

1. If Home Manager has a `programs.<tool>` module: create `modules/home/<tool>.nix`, enable the program, and add the import to `modules/home/default.nix`
2. If it's a simple package with no config: add it to `home.packages` in `modules/home/default.nix`
3. If it's a GUI-only macOS app: add it as a cask in `modules/darwin/homebrew.nix`
4. **Always `git add` new `.nix` files** — Nix flakes only see git-tracked files

## Conventions

- Platform-specific code uses `pkgs.stdenv.isDarwin` / `pkgs.stdenv.isLinux` conditionals
- Host-specific overrides go in `hosts/<name>.nix`, shared config goes in `modules/home/`
- Neovim config is fully declarative Lua embedded in `neovim.nix` (not external config files)
- Claude Code / Codex config (`~/.claude`, `~/.codex`) is not managed here; it lives in the separate `mr04vv/agent-config` repo and is symlinked by its `install.sh`
- Nix language (`.nix` files): use nixpkgs-unstable conventions
