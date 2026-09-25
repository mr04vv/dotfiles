#!/usr/bin/env bash
set -euo pipefail

# review-pr.sh の完了通知をクリックしたときに Notifier から呼ばれる。
# herdr クライアントが動いている Ghostty のタブを前面に出し、レビューのワークスペースへ移動する。
# 通知の外からは herdr のセッションを判別できないため、ソケットとバイナリを引数で受け取る。
# Arguments: {herdr_bin} {socket_path} {workspace_id}
HERDR_BIN="$1"
SOCKET_PATH="$2"
WORKSPACE_ID="$3"

# Ghostty のタブ名は起動コマンドになっているので、セッション名からタブを特定する。
# 名前付きセッションのソケットは ~/.config/herdr/sessions/<name>/herdr.sock にある。
if [[ "$SOCKET_PATH" =~ /sessions/([^/]+)/herdr\.sock$ ]]; then
  CLIENT_TITLE="herdr --session ${BASH_REMATCH[1]}"
else
  CLIENT_TITLE="herdr"
fi

# タブが見つからなければ Ghostty を前面に出すだけにする。
/usr/bin/osascript - "$CLIENT_TITLE" <<'APPLESCRIPT'
on run argv
  tell application "Ghostty"
    set targets to (every terminal whose name is (item 1 of argv))
    if targets is not {} then focus (item 1 of targets)
    activate
  end tell
end run
APPLESCRIPT

HERDR_SOCKET_PATH="$SOCKET_PATH" "$HERDR_BIN" workspace focus "$WORKSPACE_ID" >/dev/null
