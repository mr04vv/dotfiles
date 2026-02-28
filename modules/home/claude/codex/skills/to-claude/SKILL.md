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
- ClaudeとCodexは**同じウィンドウ**内のペインに存在する前提

## 重要: このスキルはシェルコマンドを実行するスキルです

返答をテキストとして出力するのではなく、**必ずシェルで以下のコマンドを実行**すること。
コマンドを出力するだけでは動作しない。`shell` または `bash` ツールで実際に実行すること。

## 実行コマンド

以下を **1つのシェル呼び出しで実行** する：

```bash
tmux send-keys -t <claude_pane_id> "<response>" && sleep 1 && tmux send-keys -t <claude_pane_id> "" Enter
```

**重要**:
- 上記を1つのBashコマンドとして実行すること。`tmux send-keys` と `sleep 1 && tmux send-keys` に分割してはいけない
- `&&` はシェルの演算子。引数としてクォートしてはいけない
- 正しい例: `tmux send-keys -t %1 "hello" && sleep 1 && tmux send-keys -t %1 "" Enter`
- 誤った例（分割）: 1回目 `tmux send-keys -t %1 "hello"` / 2回目 `sleep 1 && tmux send-keys -t %1 "" Enter`

## 実行手順

1. Claudeから受け取ったリクエストの中からClaudeのpane IDを確認する
2. 分析・調査を実施する
3. 返答テキストを組み立てる（冒頭に `[Codex]` プレフィックスをつける）
4. **シェルで** 上記コマンドを1回実行して送信する
5. 追加の質問や指示があれば同様に返送する

## メッセージのルール

- 返答の冒頭に `[Codex]` プレフィックスをつけてClaudeが送信元を識別できるようにする
- 長い出力は複数回に分けて送信しない（1回にまとめる）
- 追加指示を求める場合は返答末尾に明示する

## 使用例

```bash
tmux send-keys -t %1 "[Codex] レビュー結果: 認証処理に問題があります。具体的には..." && sleep 1 && tmux send-keys -t %1 "" Enter
```

## やり取りのフロー

```
Codex                           Claude
  |                               |
  |  （Claudeからリクエスト受信）  |
  |  分析・処理中                 |
  |-- tmux send-keys (実行) ----> |  結果を返送
  |                               |  内容確認・追加指示
  | <------- tmux send-keys ----- |  フォローアップ受信
  |                               |
```
