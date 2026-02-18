{ config, lib, pkgs, ... }:

{
  # WSL specific packages and configuration
  home.packages = with pkgs; [
    # WSL で必要な追加パッケージがあればここに追加
  ];

  # WSL-specific environment variables
  home.sessionVariables = {
    # WSL 固有の環境変数があればここに追加
  };

  # デフォルトシェルを Nix 管理の zsh に設定
  home.activation.setDefaultShell = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    NIX_ZSH="$HOME/.nix-profile/bin/zsh"
    if [ -x "$NIX_ZSH" ]; then
      if ! /usr/bin/grep -qF "$NIX_ZSH" /etc/shells 2>/dev/null; then
        echo "$NIX_ZSH" | /usr/bin/sudo /usr/bin/tee -a /etc/shells >/dev/null
      fi
      CURRENT_SHELL=$(/usr/bin/getent passwd "$USER" | /usr/bin/cut -d: -f7)
      if [ "$CURRENT_SHELL" != "$NIX_ZSH" ]; then
        /usr/bin/sudo /usr/bin/chsh -s "$NIX_ZSH" "$USER"
      fi
    fi
  '';

  # AutoHotkey v2 ウィンドウ管理スクリプト (Hammerspoon相当)
  home.file.".config/autohotkey/window-manager.ahk" = {
    force = true;
    text = ''
      #Requires AutoHotkey v2.0
      #SingleInstance Force

      ; 管理者権限で再起動
      if !A_IsAdmin {
        Run '*RunAs "' A_ScriptFullPath '"'
        ExitApp
      }

      ; 前回のスナップ状態を記録 { hwnd: { dir: "left"|"right"|"up"|"down", monitor: N } }
      prevSnap := Map()

      ; ウィンドウが最大化状態かを判定
      IsMaximized(hwnd) {
        curMon := GetMonitorIndex(hwnd)
        MonitorGetWorkArea(curMon, &mL, &mT, &mR, &mB)
        WinGetPos(&wX, &wY, &wW, &wH, hwnd)
        return (Abs(wX - mL) < 10 && Abs(wY - mT) < 10 && Abs(wW - (mR - mL)) < 10 && Abs(wH - (mB - mT)) < 10)
              || (WinGetMinMax(hwnd) = 1)
      }

      ; ウィンドウをスナップ or 隣のモニターに移動
      SnapOrMove(dir) {
        active := WinGetID("A")
        if !active
          return

        curMon := GetMonitorIndex(active)

        ; 最大化中なら隣のモニターに最大化のまま移動
        if IsMaximized(active) {
          nextMon := GetAdjacentMonitor(curMon, dir)
          if nextMon != curMon {
            WinRestore(active)
            MonitorGetWorkArea(nextMon, &mL, &mT, &mR, &mB)
            WinMove(mL, mT, mR - mL, mB - mT, active)
            if prevSnap.Has(active)
              prevSnap.Delete(active)
            return
          }
        }

        ; 前回と同じ方向 & 同じモニターなら隣のモニターに移動
        if prevSnap.Has(active) && prevSnap[active].dir = dir && prevSnap[active].monitor = curMon {
          nextMon := GetAdjacentMonitor(curMon, dir)
          if nextMon != curMon {
            MoveToMonitorWithSnap(active, nextMon, dir)
            prevSnap[active] := { dir: dir, monitor: nextMon }
            return
          }
        }

        ; スナップ実行
        WinRestore(active)
        MonitorGetWorkArea(curMon, &mL, &mT, &mR, &mB)
        mW := mR - mL
        mH := mB - mT

        if (dir = "left")
          WinMove(mL, mT, mW // 2, mH, active)
        else if (dir = "right")
          WinMove(mL + mW // 2, mT, mW // 2, mH, active)
        else if (dir = "up")
          WinMove(mL, mT, mW, mH // 2, active)
        else if (dir = "down")
          WinMove(mL, mT + mH // 2, mW, mH // 2, active)

        prevSnap[active] := { dir: dir, monitor: curMon }
      }

      ; 隣のモニターにスナップ状態を維持して移動
      MoveToMonitorWithSnap(hwnd, targetMon, dir) {
        MonitorGetWorkArea(targetMon, &mL, &mT, &mR, &mB)
        mW := mR - mL
        mH := mB - mT

        if (dir = "left")
          WinMove(mL, mT, mW // 2, mH, hwnd)
        else if (dir = "right")
          WinMove(mL + mW // 2, mT, mW // 2, mH, hwnd)
        else if (dir = "up")
          WinMove(mL, mT, mW, mH // 2, hwnd)
        else if (dir = "down")
          WinMove(mL, mT + mH // 2, mW, mH // 2, hwnd)
      }

      ; 指定方向の隣のモニターを取得
      GetAdjacentMonitor(curMon, dir) {
        MonitorGetWorkArea(curMon, &cL, &cT, &cR, &cB)
        cCenterX := (cL + cR) // 2
        cCenterY := (cT + cB) // 2
        bestMon := curMon
        bestDist := 999999

        loop MonitorGetCount() {
          if A_Index = curMon
            continue
          MonitorGetWorkArea(A_Index, &mL, &mT, &mR, &mB)
          mCenterX := (mL + mR) // 2
          mCenterY := (mT + mB) // 2

          valid := false
          if (dir = "left" && mCenterX < cCenterX)
            valid := true
          else if (dir = "right" && mCenterX > cCenterX)
            valid := true
          else if (dir = "up" && mCenterY < cCenterY)
            valid := true
          else if (dir = "down" && mCenterY > cCenterY)
            valid := true

          if valid {
            dist := Abs(mCenterX - cCenterX) + Abs(mCenterY - cCenterY)
            if dist < bestDist {
              bestDist := dist
              bestMon := A_Index
            }
          }
        }
        return bestMon
      }

      ^!Left::SnapOrMove("left")
      ^!Right::SnapOrMove("right")
      ^!Up::SnapOrMove("up")
      ^!Down::SnapOrMove("down")

      ; Ctrl+Q: アクティブウィンドウを閉じる
      ^q::WinClose("A")

      ; Ctrl+[ / Ctrl+]: ブラウザバック / フォワード (WezTerm以外)
      #HotIf !WinActive("ahk_exe wezterm-gui.exe")
      ^[::Send("{Alt down}{Left}{Alt up}")
      ^]::Send("{Alt down}{Right}{Alt up}")

      ; Ctrl+{ / Ctrl+}: タブを前 / 次に切り替え (WezTerm以外)
      ^+[::Send("{Ctrl down}{Shift down}{Tab}{Shift up}{Ctrl up}")
      ^+]::Send("{Ctrl down}{Tab}{Ctrl up}")
      #HotIf

      ; Alt+←→: ワード単位で移動
      !Left::Send("{Ctrl down}{Left}{Ctrl up}")
      !Right::Send("{Ctrl down}{Right}{Ctrl up}")

      ; Alt+Shift+←→: ワード単位で選択
      !+Left::Send("{Ctrl down}{Shift down}{Left}{Shift up}{Ctrl up}")
      !+Right::Send("{Ctrl down}{Shift down}{Right}{Shift up}{Ctrl up}")

      ; Ctrl+←→: 行頭/行末に移動
      ^Left::Send("{Home}")
      ^Right::Send("{End}")

      ; Ctrl+Shift+←→: カーソル位置から行頭/行末まで選択
      ^+Left::Send("{Shift down}{Home}{Shift up}")
      ^+Right::Send("{Shift down}{End}{Shift up}")

      ; Ctrl+Alt+Enter: 今いるモニターで最大化トグル
      ^!Enter:: {
        active := WinGetID("A")
        if !active
          return
        minMax := WinGetMinMax(active)
        if (minMax = 1) {
          WinRestore(active)
        } else {
          ; 現在のモニターのワークエリアに合わせて最大化
          curMon := GetMonitorIndex(active)
          MonitorGetWorkArea(curMon, &mL, &mT, &mR, &mB)
          WinRestore(active)
          WinMove(mL, mT, mR - mL, mB - mT, active)
        }
        if prevSnap.Has(active)
              prevSnap.Delete(active)
      }

      ; Win+<key> → Ctrl+<key> (一般的な編集・操作ショートカット)
      #a::Send("{Ctrl down}a{Ctrl up}")
      #c::Send("{Ctrl down}c{Ctrl up}")
      #d::Send("{Ctrl down}d{Ctrl up}")
      #e::Send("{Ctrl down}e{Ctrl up}")
      #f::Send("{Ctrl down}f{Ctrl up}")
      #g::Send("{Ctrl down}g{Ctrl up}")
      #h::Send("{Ctrl down}h{Ctrl up}")
      #i::Send("{Ctrl down}i{Ctrl up}")
      #k::Send("{Ctrl down}k{Ctrl up}")
      #l::Send("{Ctrl down}l{Ctrl up}")
      #m::Send("{Ctrl down}m{Ctrl up}")
      #r::Send("{Ctrl down}r{Ctrl up}")
      #s::Send("{Ctrl down}s{Ctrl up}")
      #t::Send("{Ctrl down}t{Ctrl up}")
      #v::Send("{Ctrl down}v{Ctrl up}")
      #w::Send("{Ctrl down}w{Ctrl up}")
      #x::Send("{Ctrl down}x{Ctrl up}")
      #y::Send("{Ctrl down}y{Ctrl up}")
      #z::Send("{Ctrl down}z{Ctrl up}")

      ; ウィンドウが属するモニター番号を取得
      GetMonitorIndex(hwnd) {
        WinGetPos(&wX, &wY, &wW, &wH, hwnd)
        centerX := wX + wW // 2
        centerY := wY + wH // 2
        loop MonitorGetCount() {
          MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
          if (centerX >= l && centerX < r && centerY >= t && centerY < b)
            return A_Index
        }
        return 1
      }
    '';
  };

  # AutoHotkeyスクリプトをWindows側にコピー
  home.activation.syncAutoHotkeyConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    WIN_HOME="/mnt/c/Users/mr04v"
    AHK_DIR="$WIN_HOME/Documents/AutoHotkey"
    if [ -d "$WIN_HOME" ]; then
      /usr/bin/mkdir -p "$AHK_DIR"
      /usr/bin/cp -f "$HOME/.config/autohotkey/window-manager.ahk" "$AHK_DIR/window-manager.ahk"
    fi
  '';

  # WezTerm configuration (Windows側にコピーして使う)
  home.file.".config/wezterm/wezterm.lua" = {
    force = true;
    text = ''
      local wezterm = require 'wezterm'
      local act = wezterm.action
      local config = wezterm.config_builder()

      config.initial_cols = 120
      config.initial_rows = 28
      config.font_size = 10
      config.color_scheme = 'Desert'
      config.default_prog = { "wsl.exe", "--cd", "~" }

      config.keys = {
        { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
        { key = 'd', mods = 'CTRL', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
        { key = 'd', mods = 'CTRL|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
        { key = 'w', mods = 'CTRL', action = act.CloseCurrentPane { confirm = false } },
        { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = false } },
        { key = 'q', mods = 'CTRL', action = act.QuitApplication },
        { key = '[', mods = 'CTRL', action = act.ActivatePaneDirection 'Prev' },
        { key = ']', mods = 'CTRL', action = act.ActivatePaneDirection 'Next' },
        { key = '{', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
        { key = '}', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(1) },
      }

      return config
    '';
  };

  # WezTerm設定をWindows側にコピー
  home.activation.syncWezTermConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    WIN_HOME="/mnt/c/Users/mr04v"
    if [ -d "$WIN_HOME" ]; then
      /usr/bin/cp -f "$HOME/.config/wezterm/wezterm.lua" "$WIN_HOME/.wezterm.lua"
    fi
  '';

  # Ghostty configuration for Linux
  # macOS とはパスが異なるため上書き
  home.file.".config/ghostty/config" = {
    force = true;
    text = ''
      # Fonts
      font-family = "Jetbrains Mono"
      font-family = "Noto Sans JP"
      font-family = "Noto Color Emoji"
      font-size = 14

      window-padding-x = 10
      window-padding-y = 10
      command = /bin/zsh
      theme = Desert

      # Quick terminal settings
      quick-terminal-position = "bottom"
      quick-terminal-screen = "mouse"
      quick-terminal-animation-duration = 0
      quick-terminal-space-behavior = "remain"
      quick-terminal-autohide = "false"
      keybind = "global:shift+cmd+\=toggle_quick_terminal"
      keybind = shift+enter=text:\n
      font-feature = "-dlig"
    '';
  };
}
