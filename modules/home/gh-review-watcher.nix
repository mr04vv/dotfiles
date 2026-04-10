{ config, pkgs, ... }:

{
  xdg.configFile."gh-review-watcher/config.toml".text = ''
    interval = 120

    # 新規PR検出時: ログファイルに記録（デバッグ用）
    [[on_new_pr]]
    name = "log"
    command = "echo '[NEW PR] {repo} #{number} {title} by @{author}' >> /tmp/gh-review-watcher-hooks.log"

    # 新規PR検出時: macOS通知
    [[on_new_pr]]
    name = "notify"
    command = """/Applications/Utilities/Notifier.app/Contents/MacOS/Notifier \
      --type banner \
      --title 'PR Review Request' \
      --subtitle '{repo} #{number}' \
      --message '{title} by @{author}' \
      --sound default"""

    # 新規PR検出時: zellijの新しいタブでClaude Codeにレビューさせる
    [[on_new_pr]]
    name = "review-tab"
    command = """PR_REPO={repo} PR_NUMBER={number} PR_TITLE={title} PR_URL={url} ${config.home.homeDirectory}/dotfiles/scripts/gh-review-tab.sh"""

    # 毎ポーリング: "yolo" ラベルがついていたらClaude Codeでレビュー判定（PR単位で1回のみ実行）
    [[on_poll]]
    name = "yolo-review"
    command = """echo {labels} | grep -q yolo && claude --permission-mode default -p '/yolo-review {number} {repo}'"""

    # Enter押下時: ブラウザでPRを開く
    [on_select]
    command = "open {url}"
  '';
}
