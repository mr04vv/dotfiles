# Netskope 社内 CA と、それに伴うシステム変更のロールバック手順

社内プロキシ **Netskope** の SSL 傍受環境で Nix のビルド（fixed-output derivation の
git / cargo フェッチ）が TLS 検証に失敗する問題への対処一式。

- `netskope-ca.crt` … macOS Keychain から抽出した Netskope の 2 証明書
  （ルート `caadmin.netskope.com` + 中間 `ca.atrae.goskope.com`）。公開鍵のみ、秘密情報なし。

## 加えた変更の一覧

### A. dotfiles 内（git 管理・`git` で戻せる）
| ファイル | 変更 |
|----------|------|
| `flake.nix` | `neovim-nightly-overlay.overlays.default` の適用を 3 箇所から除去 |
| `flake.lock` | overlay 更新（結果的に不使用） |
| `modules/home/neovim.nix` | `package = pkgs.neovim-unwrapped`（安定版）に変更 |
| `modules/darwin/default.nix` | `security.pki.certificateFiles` を追加 |
| `modules/darwin/certs/netskope-ca.crt` | 新規追加 |

### B. システム側（手動変更・dotfiles 管理外・手動で戻す）
| 対象 | 変更 |
|------|------|
| `/etc/ssl/nix-ca-bundle.crt` | 標準 CA + Netskope CA の結合バンドルを新規配置 |
| `/etc/nix/nix.custom.conf` | `ssl-cert-file = /etc/ssl/nix-ca-bundle.crt` を追記 |
| `/Library/LaunchDaemons/systems.determinate.nix-daemon.plist` | `EnvironmentVariables` に `NIX_SSL_CERT_FILE` を追記 |

> 注: nvim-dap（codeberg 等 git フェッチ）を通すのに実効的なのは B の plist / custom.conf。
> 安定版 neovim への切り替え（A）は cargo/crates.io フェッチ回避のため。

## 完全に元に戻す手順

### A を戻す（dotfiles）
```bash
cd ~/dotfiles
git checkout d131769 -- flake.nix flake.lock modules/home/neovim.nix modules/darwin/default.nix
git rm modules/darwin/certs/netskope-ca.crt modules/darwin/certs/README.md
# もしくは変更をまだコミットしていなければ:
#   git restore --staged . && git checkout -- . && rm -rf modules/darwin/certs
```

### B を戻す（システム・要 sudo）
```bash
# 1. nix.custom.conf を空（Determinate 初期状態）に戻す
sudo tee /etc/nix/nix.custom.conf > /dev/null <<'CONF'
# Written by https://github.com/DeterminateSystems/nix-installer.
# The contents below are based on options specified at installation time.
CONF

# 2. daemon plist から EnvironmentVariables を除去（元の Determinate 版に戻す）
sudo cp ~/dotfiles/modules/darwin/certs/nix-daemon.plist.orig \
        /Library/LaunchDaemons/systems.determinate.nix-daemon.plist

# 3. 結合 CA バンドルを削除
sudo rm -f /etc/ssl/nix-ca-bundle.crt

# 4. daemon を再起動して反映
sudo launchctl bootout system/systems.determinate.nix-daemon 2>/dev/null || true
sudo rm -f /var/run/nix-daemon.socket /var/run/determinate-nixd.socket
sudo launchctl bootstrap system /Library/LaunchDaemons/systems.determinate.nix-daemon.plist

# 5. dotfiles を戻したうえで再適用
sudo darwin-rebuild switch --flake ~/dotfiles#mac-m1
```

`nix-daemon.plist.orig` はこのディレクトリに保存済みの、Determinate が生成した
オリジナル plist（`EnvironmentVariables` 無し）。
