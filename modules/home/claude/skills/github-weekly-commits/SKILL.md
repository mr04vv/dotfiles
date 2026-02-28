---
name: github-weekly-commits
description: 今週のGitHub commit履歴を取得し、アウトプット（ブログ記事、技術共有など）できそうな内容を分析・提案します。「今週のcommit」「アウトプットネタ」「commit履歴から記事」などと指示された場合に実行されます。
---

# GitHub Weekly Commits Analyzer

今週のGitHub commit履歴を取得し、アウトプット可能なテーマを提案するスキルです。

## 実行フロー

### 1. GitHubユーザー名の取得
```bash
gh api user --jq '.login'
```

### 2. 今週のcontribution概要を取得
GraphQL APIで今週のcommit数とリポジトリを確認します。
- 公開リポジトリへのcommit
- プライベートリポジトリへのcommit数（restrictedContributionsCount）

### 3. 組織リポジトリのcommit詳細を取得
ユーザーに組織名を確認し、詳細なcommitメッセージを取得します。
```bash
gh search commits --author=<username> --owner=<org> --committer-date=">YYYY-MM-DD" --json repository,commit --limit 100
```

### 4. commit内容の分析
- リポジトリ別のcommit数集計
- commitメッセージからテーマを抽出
- 技術的なトピックを分類

### 5. アウトプット候補の提案
以下の観点で記事ネタを提案：
- 新機能の実装（設計思想、技術選定理由）
- インフラ構築（IaC、Kubernetes、CI/CD）
- バグ修正（原因分析、解決方法）
- リファクタリング（改善のポイント）
- ツール・自動化（効率化の工夫）

## 出力フォーマット

### commit概要テーブル
| リポジトリ | commits | 主な内容 |
|-----------|---------|---------|
| repo-name | N | 概要 |

### アウトプット候補リスト
1. **テーマ名**（優先度）
   - 概要説明
   - 含まれる技術要素
   - 想定読者

## 使用例

ユーザーが以下のように指示したら実行：
- 「今週のcommitからアウトプットネタを探して」
- 「GitHub履歴からブログ記事のネタを提案して」
- 「今週何やったか振り返りたい」

## 注意事項

- gh CLI がインストール・認証済みである必要があります
- プライベートリポジトリの詳細取得には組織名の指定が必要です
- 日付は実行日を基準に「今週」（月曜〜日曜）を計算します