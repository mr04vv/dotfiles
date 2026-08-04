{ config, pkgs, ... }:

let
  scriptsDir = "${config.home.homeDirectory}/dotfiles/scripts";
in
{
  xdg.configFile."gh-review-watcher/config.toml".text = ''
    # ポーリング間隔（秒）
    interval = 120

    # --- on_new_pr: 新規PR検出時 ---

    # ログファイルに記録（デバッグ用）
    [[on_new_pr]]
    name = "log"
    command = "echo '[NEW PR] {repo} #{number} {title} by @{author}' >> /tmp/gh-review-watcher-hooks.log"

    # macOS通知
    [[on_new_pr]]
    name = "notify"
    command = """/Applications/Utilities/Notifier.app/Contents/MacOS/Notifier \
      --type banner \
      --title 'PR Review Request' \
      --subtitle '{repo} #{number}' \
      --message {title} \
      --sound default"""

    # yoloラベルがなければ新タブでClaude Codeレビューを実行。
    # タブの開き方は open-review-tab.sh が herdr / zellij を実行時判定するので、
    # watcher をどちらのマルチプレクサ内で動かしても同じ config で機能する。
    [[on_new_pr]]
    name = "review-tab"
    command = """echo '{labels}' | grep -q yolo || ${scriptsDir}/open-review-tab.sh '{url}' '{number}' '{repo}'"""

    # --- on_poll: 毎ポーリング ---

    # "yolo" ラベルがついたPRはClaude Codeで自動レビュー判定。
    # 何が起きたか追えるよう各分岐をログに残している（CHECK→RUN/SKIP）。
    [[on_poll]]
    name = "yolo-review"
    command = """echo '[YOLO-CHECK] {repo}#{number} labels=[{labels}]' >> /tmp/gh-review-watcher-hooks.log && (echo '{labels}' | grep -q yolo && echo '[YOLO-RUN] {repo}#{number}' >> /tmp/gh-review-watcher-hooks.log && claude --dangerously-skip-permissions -p '/yolo-review {number} {repo}' >> /tmp/gh-review-watcher-hooks.log 2>&1 || echo '[YOLO-SKIP] {repo}#{number}' >> /tmp/gh-review-watcher-hooks.log)"""

    # --- on_remove: PRがリストから消えた時（マージ・クローズ・レビュー解除等） ---

    # レビュータブを自動で閉じる（実行内容をログにも残す）
    [[on_remove]]
    name = "close-review-tab"
    command = "echo '[REMOVE] {repo}#{number}' >> /tmp/gh-review-watcher-hooks.log && ${scriptsDir}/close-merged-review-tab.sh '{number}' '{repo}' >> /tmp/gh-review-watcher-hooks.log 2>&1"

    # --- on_select: Enter押下時 ---

    # ブラウザでPRを開く
    [on_select]
    command = "open {url}"

    # --- actions: `a` で開くメニューから選択実行（選択中PRに対して） ---
    # TUIで `a` → j/k で選び Enter で実行、Esc で閉じる。
    # 1件も定義がないと `a` は無反応になる（フッターのヒントは常に出る）。

    [[actions]]
    name = "Rebase (update branch)"
    command = "gh pr update-branch {number} -R {repo} --rebase"

    [[actions]]
    name = "Approve"
    command = "gh pr review {number} -R {repo} --approve --body 'LGTM 👍 (manual)'"

    [[actions]]
    name = "Request changes"
    command = "gh pr review {number} -R {repo} --request-changes --body 'CI/変更点を確認してください'"

    [[actions]]
    name = "Open CI checks (web)"
    command = "gh pr checks {number} -R {repo} --web"

    [[actions]]
    name = "Re-review with Claude (new tab)"
    command = "${scriptsDir}/open-review-tab.sh '{url}' '{number}' '{repo}'"

    [[actions]]
    name = "Copy URL"
    command = "printf %s {url} | pbcopy"
  '';
}
