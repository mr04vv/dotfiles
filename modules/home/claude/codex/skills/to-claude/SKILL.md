---
name: to-claude
description: |
  分析結果や返答をtmux経由でClaudeのペインに送信するスキル。
  Claudeからリクエストを受け取った後、結果をClaudeに返送する際に使用する。
  トリガー: "Claudeに返答", "Claudeに送信", "結果をClaudeに"
---

# to-claude

分析・調査結果をtmux経由でClaudeのペインに送り返すスキル。

## 前提

- tmuxが起動していること
- ClaudeのペインIDが既知であること（リクエスト受信時に通知される）

## 実行コマンド

```bash
# Claudeペインに結果を送信
tmux send-keys -t <claude_pane_id> "<response>"
tmux send-keys -t <claude_pane_id> "" Enter
```

## 実行手順

1. Claudeから受け取ったリクエストの中からClaudeのpane IDを確認する
2. 分析・調査を実施する
3. 結果をまとめて `tmux send-keys -t <claude_pane_id>` でClaudeのペインに送信する
4. 追加の質問や指示があれば同様に返送する

## メッセージのルール

- 返答の冒頭に `[Codex]` プレフィックスをつけてClaudeが送信元を識別できるようにする
- 長い出力は複数回に分けて送信しない（1回にまとめる）
- 追加指示を求める場合は返答末尾に明示する

## 使用例

```bash
# コードレビュー結果を返送
tmux send-keys -t %1 "[Codex] レビュー結果: 認証処理に問題があります。具体的には..."
tmux send-keys -t %1 "" Enter

# 追加情報を求める場合
tmux send-keys -t %1 "[Codex] 調査完了。エラーの原因は特定できましたが、スタックトレースの全文を共有してもらえますか？"
tmux send-keys -t %1 "" Enter
```

## やり取りのフロー

```
Codex                           Claude
  |                               |
  |  （Claudeからリクエスト受信）  |
  |  分析・処理中                 |
  |-- tmux send-keys -t --------> |  結果を返送
  |                               |  内容確認・追加指示
  | <------- tmux send-keys ----- |  フォローアップ受信
  |                               |
```
