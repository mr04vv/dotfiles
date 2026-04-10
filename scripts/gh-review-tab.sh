#!/usr/bin/env bash
# gh-review-tab.sh — Open a new zellij tab with Claude Code PR review
# Called by gh-review-watcher's on_new_pr hook
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

# Create a temporary layout file for the new tab
LAYOUT_FILE=$(mktemp /tmp/zellij-review-XXXXXX.kdl)

cat > "$LAYOUT_FILE" <<LAYOUT
layout {
    pane command="claude" {
        args "--permission-mode" "default" "${URL} をレビューして、完了したらapprove/comment/request changesのどれにするか聞いて。ユーザーの回答に応じてgh prコマンドで実行して。"
    }
}
LAYOUT

zellij action new-tab --layout "$LAYOUT_FILE" --name "$TAB_NAME"

# Clean up after a short delay to ensure zellij has read the file
(sleep 2 && rm -f "$LAYOUT_FILE") &
