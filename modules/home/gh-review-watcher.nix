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

    # yoloラベルがなければZellijの新タブでClaude Codeレビューを実行
    # 分析完了後にタブにフォーカスが移るため、起動直後はgo-to-previous-tabで元タブに戻す
    [[on_new_pr]]
    name = "review-tab"
    command = """echo '{labels}' | grep -q yolo || (zellij action new-tab --name 'Review: {repo}#{number}' --close-on-exit -- \
      ${scriptsDir}/review-pr.sh '{url}' '{number}' '{repo}' && zellij action go-to-previous-tab)"""

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
  '';
}
