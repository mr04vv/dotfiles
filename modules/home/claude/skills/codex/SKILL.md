---
name: codex
description: |
  Codex CLI（OpenAI）を使用してコードや文言について相談・レビューを行う。
  トリガー: "codex", "codexと相談", "codexに聞いて", "コードレビュー", "レビューして"
  使用場面: (1) 文言・メッセージの検討、(2) コードレビュー、(3) 設計の相談、(4) バグ調査、(5) 解消困難な問題の調査
allowed-tools: Bash(tmux *)
---

# Codex

Codex CLIが動作しているtmuxペインにリクエストを送信し、相互にやり取りするスキル。

## 前提

- tmuxの**現在のウィンドウ**の別ペインでCodex CLIが起動済みであること
- ペインIDは現在のウィンドウ内で特定すること

## 実行手順

1. 現在開いているペイン一覧を取得し、ユーザーにCodexペインを確認する
2. 自分（Claude）のペインIDを取得する
3. プロンプトを組み立てる（下記ルール参照）
4. `tmux send-keys -t <pane_id>` でCodexペインにリクエストを送信する
5. リクエスト送信後はそのまま待機する。`tmux capture-pane` でのポーリングは絶対に行わないこと。Codexからの返答はユーザーが転送してくれる。

## ペイン一覧の取得

```bash
# 現在のウィンドウのペイン一覧を取得（-a ではなく現在のウィンドウのみ）
tmux list-panes -F "#{pane_id} #{pane_index} #{pane_current_command}"
```

```bash
# 自分（Claude）のペインIDを確認
tmux display-message -p "#{pane_id}"
```

## プロンプトのルール

**重要**: codexに渡すリクエストには以下を必ず含めること：

1. 作業対象のプロジェクトディレクトリ（`--cd <dir>` に相当する文脈）
2. 「確認や質問は不要です。具体的な提案・修正案・コード例まで自主的に出力してください。」
3. 返答先のClaudeペインIDの通知：
   > 「返答はto-claudeスキルを使ってClaudeのペイン（pane ID: <claude_pane_id>）に送信してください。
   > テキストとして出力するのではなく、必ずシェルで以下の2コマンドを順番に実行してください。
   > 1. `tmux send-keys -t <claude_pane_id> "<返答内容>"`
   > 2. `sleep 1 && tmux send-keys -t <claude_pane_id> "" Enter`」

## コマンド形式

以下を **1回のBash呼び出し** で実行すること。2回に分けてはいけない：

```
tmux send-keys -t <codex_pane_id> "<request>" && sleep 1 && tmux send-keys -t <codex_pane_id> "" Enter
```

**重要**:
- 上記を1つのBashコマンドとして実行すること。`tmux send-keys` と `sleep 1 && tmux send-keys` に分割してはいけない
- `&&` はシェルの演算子。引数としてクォートしてはいけない
- `Enter` はキー名であり文字列に含めてはいけない

## 使用例

### コードレビュー依頼の送信例

```bash
tmux send-keys -t <codex_pane_id> "プロジェクト /path/to/project のコードをレビューして改善点を指摘してください。確認や質問は不要です。具体的な修正案とコード例まで自主的に出力してください。返答はtmuxを使ってClaudeのペイン（pane ID: <claude_pane_id>）に送信してください。" && sleep 1 && tmux send-keys -t <codex_pane_id> "" Enter
```

### バグ調査依頼の送信例

```bash
tmux send-keys -t <codex_pane_id> "/path/to/project の認証処理でエラーが発生する原因を調査してください。確認や質問は不要です。原因の特定と具体的な修正案まで自主的に出力してください。返答はtmuxを使ってClaudeのペイン（pane ID: <claude_pane_id>）に送信してください。" && sleep 1 && tmux send-keys -t <codex_pane_id> "" Enter
```

## やり取りのフロー

```
Claude                          Codex
  |                               |
  |-- tmux send-keys -t --------> |  リクエスト送信
  |                               |  （分析・処理中）
  | <------- tmux send-keys ----- |  結果・質問を返送
  |                               |
  |  内容確認・追加指示            |
  |-- tmux send-keys -t --------> |  フォローアップ
  |                               |
```
