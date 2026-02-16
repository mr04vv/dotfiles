# Homebrew → Nix 移行計画

## 移行方針
- 全てのパッケージをNixに移行
- GUIアプリもNixで管理（nixpkgs提供 or homebrew cask）
- 組み込み開発ツール（AVR/ARM/QMK）もNix管理
- 言語バージョン管理はdirenv + nix-shellに移行
- voltaはチーム開発用にNix経由でインストール

## パッケージ分類

### 🛠️ CLI開発ツール（優先度: 高）
- [x] bat → pkgs.bat
- [x] eza → pkgs.eza
- [x] fd → pkgs.fd
- [x] fzf → pkgs.fzf
- [x] gh → pkgs.gh
- [x] ghq → pkgs.ghq
- [x] git → pkgs.git
- [x] jq → pkgs.jq
- [x] lazygit → pkgs.lazygit
- [x] neovim → pkgs.neovim（nightly）
- [x] ripgrep → pkgs.ripgrep
- [x] starship → programs.starship
- [x] tmux → pkgs.tmux
- [x] tree → pkgs.tree
- [x] zoxide → pkgs.zoxide
- [ ] act → pkgs.act
- [ ] actionlint → pkgs.actionlint
- [ ] adr-tools → pkgs.adr-tools
- [ ] aqua → 要調査（GitHub CLI ecosystem tool）
- [ ] clang-format → pkgs.clang-tools
- [ ] fastfetch → pkgs.fastfetch
- [ ] gnu-sed → pkgs.gnused
- [ ] golangci-lint → pkgs.golangci-lint
- [ ] grpcurl → pkgs.grpcurl
- [ ] jnv → pkgs.jnv
- [ ] lazysql → 要調査
- [ ] nnn → pkgs.nnn
- [ ] peco → pkgs.peco
- [ ] shellcheck → pkgs.shellcheck
- [ ] usage → 要調査
- [ ] websocat → pkgs.websocat

### 🌐 ネットワーク/インフラツール
- [ ] awscli → pkgs.awscli2
- [ ] kubernetes-cli → pkgs.kubectl
- [ ] kubeseal → pkgs.kubeseal
- [ ] minikube → pkgs.minikube
- [ ] nginx → pkgs.nginx
- [ ] ngrok → pkgs.ngrok
- [ ] redis → pkgs.redis
- [ ] telnet → pkgs.inetutils
- [ ] terraform → pkgs.terraform

### 📦 プログラミング言語/ランタイム
- [ ] go → pkgs.go
- [ ] python@3.13 → pkgs.python313
- [ ] mise → 削除（direnvに移行）
- [ ] volta → pkgs.volta（チーム開発用）
- [ ] pipx → pkgs.pipx
- [ ] uv → pkgs.uv

### 🔧 ビルドツール/プロトコル
- [ ] buf → pkgs.buf
- [ ] protobuf → pkgs.protobuf
- [ ] protoc-gen-go → pkgs.protoc-gen-go
- [ ] protoc-gen-go-grpc → pkgs.protoc-gen-go-grpc
- [ ] ghz → pkgs.ghz

### 🔌 組み込み開発（AVR/ARM/QMK）
- [ ] avr-gcc@9 → pkgs.pkgsCross.avr.buildPackages.gcc
- [ ] avr-binutils → pkgs.pkgsCross.avr.buildPackages.binutils
- [ ] avrdude → pkgs.avrdude
- [ ] arm-none-eabi-gcc@8 → pkgs.gcc-arm-embedded
- [ ] arm-none-eabi-binutils → （gcc-arm-embeddedに含まれる）
- [ ] qmk → pkgs.qmk
- [ ] dfu-programmer → pkgs.dfu-programmer
- [ ] dfu-util → pkgs.dfu-util
- [ ] teensy_loader_cli → pkgs.teensy-loader-cli
- [ ] bootloadhid → 要調査
- [ ] hid_bootloader_cli → 要調査
- [ ] hidapi → pkgs.hidapi
- [ ] libftdi → pkgs.libftdi1
- [ ] libusb → pkgs.libusb1
- [ ] libusb-compat → pkgs.libusb-compat-0_1
- [ ] mdloader → 要調査

### 🗄️ データベース
- [ ] mysql-client → pkgs.mysql80
- [ ] mysql@8.0 → pkgs.mysql80
- [ ] postgresql@14 → pkgs.postgresql_14

### 🎬 メディア処理
- [ ] ffmpeg → pkgs.ffmpeg
- [ ] imagemagick@6 → pkgs.imagemagick

### 📚 ライブラリ（自動依存で不要な可能性）
brew経由でインストールされているライブラリ系は、Nixパッケージの依存関係で自動的に解決されるため、多くは明示的インストール不要：
- openssl, zlib, libyaml, pcre, readline等
- 必要に応じて開発時のみnix-shell経由で導入

### 💻 GUIアプリケーション（Cask）
- [ ] amethyst → 未確認（要調査）
- [ ] arc → 未確認
- [ ] bruno → 未確認
- [ ] cursor → 未確認
- [ ] docker → pkgs.docker or homebrew-cask経由
- [ ] figma → homebrew-cask経由
- [ ] firefox → pkgs.firefox-bin
- [ ] github → homebrew-cask経由
- [ ] karabiner-elements → homebrew-cask経由（macOS固有）
- [ ] logi-options+ → homebrew-cask経由（ハードウェア固有）
- [ ] microsoft-edge → homebrew-cask経由
- [ ] notion → homebrew-cask経由
- [ ] obsidian → homebrew-cask経由
- [ ] qmk-toolbox → homebrew-cask経由
- [ ] raycast → homebrew-cask経由
- [ ] screen-studio → homebrew-cask経由
- [ ] sequel-ace → homebrew-cask経由
- [ ] tableplus → homebrew-cask経由
- [ ] wezterm → pkgs.wezterm

### ❌ 削除対象
- ansible（使用頻度低ければ削除）
- mercurial（git移行済みなら削除）
- pure（zsh theme、starshipに移行済み）
- zsh-async（pure依存、不要）
- fig（廃止済みサービス？）

## 移行順序

### Phase 1: 基本CLIツール（既に完了）
- bat, fd, fzf, gh, ghq, git, jq, lazygit, ripgrep, tree等

### Phase 2: 追加CLIツール
- act, actionlint, clang-format, fastfetch, golangci-lint等

### Phase 3: 開発環境
- go, python, volta, protobuf系

### Phase 4: インフラツール
- awscli, kubectl, terraform, minikube等

### Phase 5: 組み込み開発
- AVR/ARMツールチェーン、QMK

### Phase 6: データベース
- mysql, postgresql

### Phase 7: GUIアプリ
- 可能なものからNix管理に移行

## Nixパッケージ検索方法
```bash
# パッケージ検索
nix search nixpkgs <package-name>

# 詳細確認
nix-env -qaP | grep <package-name>
```
