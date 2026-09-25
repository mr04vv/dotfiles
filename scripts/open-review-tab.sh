#!/usr/bin/env bash
set -euo pipefail

# gh-review-watcher hook: PRレビュー用のタブ (herdr ではワークスペース) を開く。
# watcher が動いているマルチプレクサ (herdr / zellij) を実行時に判定するので、
# 同じ config.toml がどちらのセッションでも壊れない。
# Arguments: {url} {number} {repo}

URL="$1"
NUMBER="$2"
REPO="$3"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB_NAME="Review: ${REPO}#${NUMBER}"

if [[ "${HERDR_ENV:-}" == "1" ]]; then
  # herdr では PR ごとに専用ワークスペースを作る (--no-focus で作業中の画面は奪わない)。
  OUT=$(herdr workspace create --label "$TAB_NAME" --no-focus)
  PANE_ID=$(printf '%s' "$OUT" | jq -r '.result.root_pane.pane_id')
  WORKSPACE_ID=$(printf '%s' "$OUT" | jq -r '.result.workspace.workspace_id')

  # pane run は引数をスペース結合してペインのシェルに打ち込むため、
  # 引数境界はここでシングルクォートを埋め込んで保つ。
  # herdr には --close-on-exit が無いので、review-pr.sh の終了後に自分の
  # ワークスペースを閉じるコマンドを連結して同じ挙動にする ([q] やエラー終了も含む)。
  # PRがレビュー中にマージされた場合は on_remove hook が先に閉じる。
  herdr pane run "$PANE_ID" \
    "'${SCRIPT_DIR}/review-pr.sh' '${URL}' '${NUMBER}' '${REPO}'; herdr workspace close '${WORKSPACE_ID}'" >/dev/null
elif [[ -n "${ZELLIJ:-}" ]]; then
  # 分析完了後にタブへフォーカスが移るため、起動直後は元タブに戻す
  zellij action new-tab --name "$TAB_NAME" --close-on-exit -- \
    "${SCRIPT_DIR}/review-pr.sh" "$URL" "$NUMBER" "$REPO"
  zellij action go-to-previous-tab
else
  echo "[open-review-tab] no multiplexer detected (HERDR_ENV/ZELLIJ unset); skipping" >&2
fi
