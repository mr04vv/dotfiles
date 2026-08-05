---
name: html-herdr
description: HTML の説明ドキュメントを作成し、herdr-browser plugin で herdr のペインに表示する（試験的）。「html-herdr」「herdr で解説を開いて」などと指示された場合に使う。herdr セッション内（HERDR_ENV=1）専用。
---

# HTML を作って herdr-browser で開く（試験的）

`html` スキルで HTML の説明ドキュメントを作り、生成物を herdr の
`herdr-browser` plugin（Chromium を CDP で描画する）でペインに表示する。
`html` スキルとの違いは表示手順を持つ点だけで、HTML そのものの作り方は
`html` スキルに完全に従う。

## 手順

1. **HTML を作る** — `html` スキルの規則（成果物・デザインシステム・構成・図・
   コード・数式）にそのまま従う。デザインシステムのアセット（`document.css`、
   `math-copy.js` など）は `html` スキル配下の `design-system/` を参照する。
2. **herdr-browser で開く** — 保存した HTML の**絶対パス**を `file://` URL に
   して、右分割・フォーカス付きでペインに開く。

```bash
herdr plugin pane open \
  --plugin official.browser \
  --entrypoint browser \
  --placement split \
  --direction right \
  --env HERDR_BROWSER_INITIAL_URL="file:///absolute/path/to/output.html" \
  --focus
```

## 条件とフォールバック

- `HERDR_ENV=1` のとき（herdr セッション内）のみ表示手順を実行する。未設定なら
  表示はスキップし、保存先の絶対パスをユーザーに伝えるにとどめる。
- 相対パスやパス内スペースに注意し、必ず絶対パスを使う。同じファイルを更新した
  場合も同手順で開き直してよい。
- plugin 未インストール・未対応端末などでコマンドが失敗した場合は、エラーを
  握り潰さずユーザーに報告し、保存先パスの提示にフォールバックする。
