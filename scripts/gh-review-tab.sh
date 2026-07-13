#!/usr/bin/env bash
# gh-review-tab.sh — Pre-review a PR in the background, then open an interactive
# zellij tab that shows the cached result and asks how to act on it.
# Called by gh-review-watcher's on_new_pr hook.
# Environment variables: PR_REPO, PR_NUMBER, PR_TITLE, PR_URL

set -euo pipefail

REPO="${PR_REPO:?PR_REPO required}"
NUMBER="${PR_NUMBER:?PR_NUMBER required}"
TITLE="${PR_TITLE:?PR_TITLE required}"
URL="${PR_URL:?PR_URL required}"

# Remove surrounding single quotes added by gh-review-watcher's shell_escape
TITLE="${TITLE#\'}"
TITLE="${TITLE%\'}"

TAB_NAME="#${NUMBER} ${TITLE}"

# Trusted directory used to run Claude non-interactively (avoids the workspace
# trust prompt, which only -p / non-interactive mode skips).
REVIEW_DIR="${HOME}/dotfiles"

# Per-PR working directory holding the cached review result, the prompt file,
# and the layout. Everything here is removed once the review is submitted.
SAFE_REPO="${REPO//\//-}"
WORK_DIR="/tmp/gh-review-cache/${SAFE_REPO}-${NUMBER}"
mkdir -p "$WORK_DIR"

RESULT_FILE="${WORK_DIR}/result.md"
PENDING_FILE="${WORK_DIR}/pending"
PROMPT_FILE="${WORK_DIR}/prompt.txt"
LAYOUT_FILE="${WORK_DIR}/layout.kdl"

# --- Phase 1: pre-review in the background (non-interactive, no trust prompt) ---
: > "$PENDING_FILE"
(
  cd "$REVIEW_DIR"
  claude -p "/review ${URL}" > "$RESULT_FILE" 2>&1 || \
    echo "レビューの自動実行に失敗しました。タブ内で /review ${URL} を手動実行してください。" > "$RESULT_FILE"
  rm -f "$PENDING_FILE"
) &

# --- Phase 2: interactive tab that consumes the cached result ---
# The prompt lives in its own file so the KDL layout never has to embed
# multi-line text or quotes (which would break KDL parsing).
cat > "$PROMPT_FILE" <<PROMPT_EOF
PR ${URL} のレビューはバックグラウンドで先行実行済み(またはまだ実行中)です。

手順:
1. 結果ファイル ${RESULT_FILE} を読む。もし ${PENDING_FILE} が存在する場合はまだレビュー実行中なので、消えるまで数秒待ってから読み込む。
2. レビュー結果の要点を簡潔に提示する。
3. 続けて以下の4つの選択肢を番号付きで提示する:
   1. コメント付きでapprove
   2. このままレビュー内容についてClaudeと議論する
   3. request changes(修正要求)
   4. コメントのみ comment

ユーザーの選択に応じた動作:
- 選択肢2(議論)以外は、必要なコメント内容を先にユーザーから聞き取る。
- コメントを受け取ったら(選択肢2以外)、レビュー送信と後片付けをバックグラウンドに投げてから直ちにこのタブを閉じる。
  送信はタブを閉じても継続させたいので、以下を必ず nohup + バックグラウンド(&)で起動し、その直後に zellij action close-tab を実行すること:

  選択肢1: nohup bash ${WORK_DIR}/submit.sh approve   '<コメント>' >/dev/null 2>&1 &
  選択肢3: nohup bash ${WORK_DIR}/submit.sh changes   '<コメント>' >/dev/null 2>&1 &
  選択肢4: nohup bash ${WORK_DIR}/submit.sh comment   '<コメント>' >/dev/null 2>&1 &

  上記コマンドを実行したら、送信結果を待たずに即 zellij action close-tab でタブを閉じる。
- 選択肢2(議論)を選んだ場合のみ、タブは閉じずそのまま議論を続ける。議論が終わって
  ユーザーがレビューを送信すると決めたら、そのとき改めて上記の submit.sh を同じ形式で呼び出す。
PROMPT_EOF

# submit.sh: runs gh pr review in the background, then removes the whole
# per-PR working directory. Detached from the tab so closing the tab is instant.
cat > "${WORK_DIR}/submit.sh" <<SUBMIT_EOF
#!/usr/bin/env bash
set -euo pipefail
action="\$1"
body="\${2:-}"
# --comment requires a body; approve/request-changes accept an empty one, in
# which case --body must be omitted (gh rejects an empty --body value).
body_arg=()
[[ -n "\$body" ]] && body_arg=(--body "\$body")
case "\$action" in
  approve) gh pr review "${NUMBER}" --repo "${REPO}" --approve         "\${body_arg[@]}" ;;
  changes) gh pr review "${NUMBER}" --repo "${REPO}" --request-changes "\${body_arg[@]}" ;;
  comment) gh pr review "${NUMBER}" --repo "${REPO}" --comment         --body "\$body" ;;
  *) echo "unknown action: \$action" >&2; exit 1 ;;
esac
# All done — clean up every temp file for this PR.
rm -rf "${WORK_DIR}"
SUBMIT_EOF
chmod +x "${WORK_DIR}/submit.sh"

# Build the layout. The args string is a short, quote-free instruction telling
# Claude to read the prompt file — the real (multi-line) prompt lives in
# PROMPT_FILE, so the KDL never embeds text that could break its parser.
cat > "$LAYOUT_FILE" <<LAYOUT
layout {
    pane size=1 borderless=true {
        plugin location="tab-bar"
    }
    pane command="claude" {
        args "--permission-mode" "default" "${PROMPT_FILE} を読んで その内容の指示に厳密に従って"
    }
    pane size=1 borderless=true {
        plugin location="status-bar"
    }
}
LAYOUT

zellij action new-tab --layout "$LAYOUT_FILE" --name "$TAB_NAME"
