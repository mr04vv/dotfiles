{ config, pkgs, arto, ... }:

{
  imports = [
    ./git.nix
    ./zsh.nix
    ./neovim.nix
    ./tmux.nix
    ./ghostty.nix
    ./hammerspoon.nix
    ./claude.nix
    ./fonts.nix
  ];

  # Let Home Manager manage itself
  programs.home-manager.enable = true;

  # Common packages
  home.packages = with pkgs; [
    # ============================================================================
    # CLI Tools
    # ============================================================================
    bat               # cat with syntax highlighting
    eza               # modern ls replacement
    fd                # find alternative
    fzf               # fuzzy finder
    jq                # JSON processor
    jnv               # interactive JSON filter
    nnn               # terminal file manager
    peco              # interactive filtering tool
    ripgrep           # grep alternative
    tree              # directory tree
    wget
    curl
    htop
    fastfetch         # system information

    # ============================================================================
    # Development Tools - Git & GitHub
    # ============================================================================
    git
    gh                # GitHub CLI
    ghq               # repository management
    lazygit           # TUI for git

    # ============================================================================
    # Development Tools - Actions & CI
    # ============================================================================
    act               # Run GitHub Actions locally
    actionlint        # GitHub Actions linter

    # ============================================================================
    # Development Tools - Code Quality
    # ============================================================================
    clang-tools       # clang-format, clang-tidy
    shellcheck        # shell script linter

    # ============================================================================
    # Build Tools
    # ============================================================================
    gcc
    gnumake
    autoconf
    libtool

    # ============================================================================
    # Programming Languages & Runtimes
    # ============================================================================
    go                # Go language
    python313         # Python 3.13
    nodejs            # Node.js (for Neovim, Copilot, etc.)

    # Language version managers (team compatibility)
    volta             # Node.js version manager (for team projects)

    # Python tools
    pipx              # Install Python apps in isolated environments
    uv                # Fast Python package installer

    # ============================================================================
    # Protocol Buffers & gRPC
    # ============================================================================
    buf               # Protocol buffer toolkit
    protobuf          # Protocol buffers
    protoc-gen-go     # Go plugin for protoc
    protoc-gen-go-grpc # gRPC Go plugin
    grpcurl           # gRPC curl-like tool
    ghz               # gRPC benchmarking tool
    grpcurl           # gRPC curl-like tool

    # ============================================================================
    # Cloud & Infrastructure
    # ============================================================================
    awscli2           # AWS CLI
    kubectl           # Kubernetes CLI
    kubernetes-helm   # Kubernetes package manager
    kubeseal          # Sealed Secrets
    minikube          # Local Kubernetes
    terraform         # Infrastructure as Code
    ngrok             # Tunneling service

    # ============================================================================
    # Databases
    # ============================================================================
    mysql80           # MySQL 8.0
    postgresql_14     # PostgreSQL 14
    redis             # Redis server

    # ============================================================================
    # Network Tools
    # ============================================================================
    inetutils         # telnet, etc.
    websocat          # WebSocket client

    # ============================================================================
    # Embedded Development - AVR
    # ============================================================================
    pkgsCross.avr.buildPackages.gcc
    pkgsCross.avr.buildPackages.binutils
    avrdude           # AVR programmer

    # ============================================================================
    # Embedded Development - QMK/Keyboards
    # ============================================================================
    # qmk - Disabled: requires gcc-arm-embedded which is not available on Intel Mac
    dfu-programmer    # USB DFU programmer
    dfu-util          # DFU utilities
    teensy-loader-cli # Teensy loader

    # ============================================================================
    # USB/Hardware Libraries
    # ============================================================================
    hidapi            # HID API library
    libftdi1          # FTDI USB library
    libusb1           # USB library

    # ============================================================================
    # Media Tools
    # ============================================================================
    ffmpeg            # Video/audio processing
    imagemagick       # Image processing

    # ============================================================================
    # Other Tools
    # ============================================================================
    unzip
    gzip
    adr-tools         # Architecture Decision Records
    nginx             # Web server
    golangci-lint     # Go linter

    # ============================================================================
    # GUI Applications (macOS)
    # ============================================================================
    # Note: Some GUI apps may not be available in nixpkgs for macOS.
    # Those will need to be installed via other means or added to homebrew cask.
  ] ++ (if pkgs.stdenv.isDarwin then [
    # macOS-specific GUI applications available in nixpkgs
    ghostty-bin       # Ghostty terminal emulator
    shottr            # Screenshot app with OCR and annotation
    arto.packages.${pkgs.system}.default  # Arto note-taking app
  ] else [
    # Linux-specific packages
    ghostty           # Ghostty terminal emulator (Linux)
    libnotify         # Desktop notifications (notify-send)
    pulseaudio        # Audio system (paplay)
    alsa-utils        # ALSA utilities (aplay)
  ]);
}
