---
name: diff-review
description: >-
  Generate an annotated diff-REVIEW page in the browser: changes are grouped
  into semantic "change groups" (across files), each with an intent
  explanation, a risk level (要注意/注意/低リスク), tags, AI review findings
  (指摘) and 要改善, per-line and multi-line human comments, a per-group
  "確認して承認" checkbox with an approval progress bar, and — for branch
  diffs — direct GitHub PR review submission (approve / request changes /
  comment) via gh. Use this skill when the user asks to REVIEW a diff:
  "レビューして", "review the diff", "問題ないか見て", "PRにレビューを送りたい",
  "変更をレビュー画面で見たい", "レビュー前に変更を整理して", wants findings /
  指摘 on their branch or uncommitted changes, or wants to line-comment and
  send a review to a PR. For explanation-only (解説だけ, no findings), use the
  sibling skill **diff-explain** instead. Do NOT use for reviewing a remote PR
  by URL, or for one-line diff questions answerable inline in chat.
---

# Diff Review

Build a self-contained **review** page for a diff, organized the way a
reviewer thinks — not file by file, but as **semantic change groups**. Each
group carries an intent (意図), a risk level, tags, annotated hunks, AI review
findings (指摘) and 要改善, and an approval checkbox. Humans can add per-line
and multi-line comments, pick which AI findings to keep, and — on a branch
diff — send the whole thing to the GitHub PR as a review. A progress bar in
the header tracks 承認 N/M. The output is one HTML file with zero network
dependencies.

このスキルは **レビューあり** 版。指摘 (findings) と要改善 (unclear) を出し、
PR への行コメント送信まで行う。純粋な解説だけが欲しい（指摘不要）ときは姉妹
スキル **diff-explain** を使う。

Division of labor: `scripts/build_diff_page.py` does everything deterministic
— diff extraction, parsing, global hunk ids, intraline highlighting, HTML
rendering, approval-state persistence. Your job is the part that requires
understanding the code: reading the diff and writing `explanations.json`, and
reviewing critically. Do not hand-write the HTML or re-parse the diff.

## Workflow

### 1. Extract the diff

```bash
python <skill-path>/scripts/build_diff_page.py extract [--mode MODE]
```

Pick the mode from what the user asked for:

- `branch` (default) — current branch vs base, three-dot style
  (`merge-base..HEAD`). Base auto-detects via `origin/HEAD` then
  `main`/`master`/`develop`; pass `--base <branch>` if the user names one.
  **PR 送信は branch モードのみ。**
- `unstaged` — working tree vs index (「未ステージの変更」).
- `staged` — index vs HEAD (「ステージした変更」).
- `worktree` — working tree vs HEAD (staged + unstaged together).

Add `--workdir <dir>` to reuse a directory when regenerating.

**解説量 `--detail {small|medium|large}`** (default `medium`): 生成する解説
プロセ（意図・コード解説・解説）の分量レベル。指摘/要改善はレベル非依存で、
言うべきことは常に出す。ユーザーが「軽く/詳しく」等と言ったら選ぶ。

The script prints the workdir and a **hunk index**: every file with its hunks
and their global ids (`h001`, `h002`, …). Those ids are what you assign to
groups in `explanations.json`. 各ファイルには `[status]` と行数、lockfile・
vendored deps・ビルド生成物・生成コードには **`(generated — 解説不要)`**
マークが付く。It also writes `raw.diff` and `diff_data.json`. If it exits with
"No differences", report that and stop.

### 2. Read the diff and plan the groups

Read `<workdir>/raw.diff`. Then decide the change groups. Good groups follow
the *logical structure of the change*, not the directory tree: a group can
(and usually does) span files. Aim for roughly 3–8 groups; a reviewer should
be able to approve them one at a time. Typical shapes:

- 新しい基盤・共通化 (the core of the change — usually the highest risk)
- それを使う側の機械的な置き換え (broad but mechanical — medium risk)
- テストの追従、docs、生成物 (low risk)

Order groups by where a reviewer should start: core first, mechanical and
low-risk later. Every hunk you don't assign lands in an automatic
「その他の変更」 group — a fallback, not a dumping ground.

For large diffs, triage: read the hunk index first, read meaningful files
fully, skim mechanical mass-changes. If ±3 lines of context isn't enough to
understand a hunk, read the actual file in the repo — guessed explanations
are worse than short ones.

### 3. Write explanations.json

Write `<workdir>/explanations.json`:

```json
{
  "title": "app/system URL整理のブランチレビュー",
  "groups": [
    {
      "name": "URL・ホスト判定の共通基盤",
      "risk": "high",
      "tags": ["core"],
      "description": "一覧に出す60字程度の要約(省略時はintent先頭を使用)",
      "intent": "従来はcontroller・view・batchの三箇所でURLを個別に組み立てており、deployment modeを追加するたびに分岐が増え不整合の温床になっていた。本グループではURL生成とhost判定を`UrlResolver`一か所へ集約し、legacy-path方式とsubdomain方式をmodeフラグで切り替える形に再設計する。呼び出し側は文字列連結をやめて`resolver.url_for(...)`を呼ぶだけになり、影響範囲は三モジュールに広がるが判定ロジックの重複は解消される。既存URLの後方互換は保つが、生成順序が変わるためリダイレクトのテストは要確認。",
      "hunks": ["h079", "h080", "h081"],
      "hunk_intents": {
        "h080": "このハンク固有の意図(紫)。グループ全体のintentとは別に、この差分片の目的を一言で。"
      },
      "code_notes": {
        "h080:142": "コード解説(緑)。142行目: `resolver.url_for`はmode→builder関数の辞書を引き、該当がなければlegacy builderにfallbackして絶対URLを返す。"
      },
      "hunk_notes": {
        "h080": "解説(青)。なぜこう変えたか・非自明な点。modeフラグ判定を一度だけ行いキャッシュしている理由など。"
      },
      "findings": {
        "h081:88": "指摘(赤)。88行目: この分岐は境界値でnilが渡り得る。行キーなのでPR送信時に88行目へ正確にアンカーされる。",
        "h081:95-102": "指摘(赤)。95-102行目: このtry/exceptブロック全体が例外を握り潰している。範囲キーなのでPR送信時にstart_line=95〜line=102でアンカーされる。"
      },
      "unclear": {
        "h082": "要改善(アンバー)。改善余地がある、または変更の意図が差分とリポジトリから読み取れない箇所。"
      }
    },
    {
      "name": "設計文書と移行計画の更新",
      "risk": "low",
      "tags": ["docs"],
      "intent": "architectureとmigration planを現在の責務分離へ更新。",
      "hunks": ["h101", "h102"]
    }
  ]
}
```

**解説量レベル (`--detail`)** — 解説系 (hunk_intents / code_notes /
hunk_notes) の分量を調整する。指摘/要改善は「言うべきことは言う」もので
レベル非依存（small でも重要な指摘は必ず出す）。

- **small** — 要点のみ。`intent` は 1〜2 文、hunk 解説は本当に非自明な箇所だけ。
- **medium**（既定）— `intent` 3〜5 文、非自明な hunk に 2〜4 文。
- **large** — 手厚く。設計判断・境界条件・代替案・影響範囲まで踏み込む。
  ただし自明な hunk を無理に膨らませない（水増しは全レベルで avoid）。

**生成物・lock ファイルは解説しない** — extract で `(generated — 解説不要)`
と付いた hunk には意図・コード解説・解説を付けない。低リスクグループ
（`tags: ["deps"]` 等）にまとめ、`intent` に一言添えれば十分。findings も、
生成物に実質的レビュー価値がある稀なケースを除き付けない。判定は extract の
マークに従う。

Field guidance:

- **risk**: `high` (要注意) = behavior changes, security/auth boundaries,
  concurrency, data migration. `medium` (注意) = broad but mechanical.
  `low` (低リスク) = docs, generated files, pure renames. Judge by
  consequence of a mistake, not line count.
- **tags**: 1–2 short lowercase words (`core`, `refactor`, `docs`, `test`,
  `deps`, `config`).
- **intent**: なぜこの変更か、設計判断、影響範囲。各グループ 3〜5 文
  （150〜300 字目安）で (1) 問題・背景 (2) アプローチと理由 (3) 影響範囲
  (4) 代替案/トレードオフ を順に。憶測は「〜と思われる」と明示。
- **ハンク単位の解説は3種**（同じハンクに複数可、役割で書き分け重複させない。
  表示順 意図 → コード解説 → 解説）:
  - **hunk_intents** (意図, purple) — そのハンク固有の変更意図を 1〜2 文。
  - **code_notes** (コード解説, green) — 変更後コードが何をしているかの読解
    補助（良し悪しではなく処理の流れ）。
  - **hunk_notes** (解説, blue) — why と非自明な点を 2〜4 文。
  自明なハンク（rename・import 追加・フォーマットのみ）には付けない。
- **findings** (指摘, red) — 対応すべき/意識的に受け入れるべき点: bug、
  invalidation 漏れ、境界条件、要注意の挙動変更、未完了を完了と偽る docs。
  実際のレビューで主張できるものだけ。ヘッダーが件数を数えるのでノイズは信頼
  を損なう。
- **unclear** (要改善, amber) — 改善余地はあるが明確な問題未満のもの、および
  **意図が差分とリポジトリから読み取れない箇所**。もっともらしい説明で誤魔化
  さず「この変更の意図が読み取れません。〜のためであれば問題ありませんが確認
  を推奨」と正直に印を付ける方が有用。
- **注釈・指摘は行単位・範囲でも付けられる**。5 種すべてのキーは 3 形式:
    - `"h012"` — ハンク全体
    - `"h012:58"` — 特定行（58 = **新側 (RIGHT) 行番号**）
    - `"h012:58-63"` — **複数行の範囲**（58〜63 行、両端とも新側 RIGHT 行）
  - 行キー・範囲キーは終了行の直下にインライン表示。指摘は「どこの話か」が
    一目で分かるので **可能な限り行/範囲キーで**。無関係な複数箇所は
    `"h012:58"` `"h012:63"` と分け、ひとまとまりの問題（例: ある関数全体、
    連続するブロック）は `"h012:58-63"` と範囲で付ける。
  - findings/unclear を行キーで付けると PR 送信時にその行へ、範囲キーは
    `start_line`〜`line` でその範囲へ正確にアンカー（§6）。ハンクキーは
    代表行にフォールバック。
  - 行番号は extract 出力に実在する新側行のみ。範囲は **両端とも実在** する
    こと。存在しない行/端はハンク単位にフォールバックし stderr に警告。
- **Display order is risk order**: renderer が high → medium → low で安定
  ソート。同一行内の複数注釈は 意図 → コード解説 → 指摘 → 要改善 → 解説 の順。
- **Language**: match the user's language (ほぼ日本語).
- Hunk ids・行キーの行番号は extract 出力から取る。各 id は 1 グループのみ。

### 4. 忖度対策: two-stage review (when a plan/spec exists)

If the change was implemented from a plan, spec, or instructions visible to
you, there is a known failure mode: reviewing against the plan makes you
excuse mediocre implementation with "planに則っているのでOK". Counter it:

1. **Blind pass** — review the diff *without consulting the plan*, judging the
   code on its own merits: correctness, boundary conditions, design, naming.
   Prefer spawning a subagent that receives only `raw.diff` (plus repo read
   access) and no plan, returning its findings. Without subagents, write blind
   findings *before* (re)reading the plan.
2. **Plan-aware pass** — compare against the plan: does the diff cover it,
   deviate, or silently skip parts? Add plan-dependent findings.

Merge the two: blind findings survive even when the plan justifies the
implementation — note the justification ("plan上は意図通りだが〜の懸念は残る")
rather than deleting. Plan-only findings stay too.

For small diffs with no plan in play, a single pass is fine — don't
manufacture ceremony.

### 5. Render and open

```bash
python <skill-path>/scripts/build_diff_page.py render --workdir <workdir>
```

It prints the path to `diff_review.html`. Open it:

- macOS: `open <path>` / Linux with display: `xdg-open <path>`
- No display / Claude.ai container: present the HTML file to the user
  directly instead, and mention it works offline.

Then give a short recap in chat (2–4 sentences): the shape of the change,
which group to review first, and the findings count.

### 6. GitHub PR にレビューを送信する（branch モードのみ）

`branch` モードのページには「PR送信用にコピー」ボタンと、末尾に **03 /
PRレビューを送信** パネル（判定ラジオ + 全体コメント欄）がある。人間は行
コメント・範囲コメント・ハンクコメントを書き、送りたい AI 指摘にチェックを
付け、判定を APPROVE / REQUEST_CHANGES / COMMENT から選び、ボタンで **送信用
JSON** をコピーする。その JSON を作業セッションに貼って「PR に送って」と依頼
されたら、あなたが `gh` で投稿する。

コピーされる JSON の形:

```json
{
  "event": "REQUEST_CHANGES",
  "body": "レビュー全体のサマリー（任意）",
  "comments": [
    { "path": "app/foo.rb", "line": 42, "side": "RIGHT",
      "body": "人間が書いた行コメント", "author": "human" },
    { "path": "app/foo.rb", "line": 60, "side": "RIGHT",
      "start_line": 55, "start_side": "RIGHT",
      "body": "55-60行の範囲コメント", "author": "human" },
    { "path": "app/foo.rb", "line": 58, "side": "RIGHT",
      "body": "🤖 Claude (指摘): nullチェックが抜けている", "author": "ai" },
    { "path": "app/foo.rb", "line": 102, "side": "RIGHT",
      "start_line": 95, "start_side": "RIGHT",
      "body": "🤖 Claude (指摘): 95-102の例外処理が握り潰し", "author": "ai" }
  ],
  "_context": { "head": "feature-x", "base": "main", "mode": "branch",
                "title": "...", "counts": { "human": 2, "ai": 2 },
                "skipped_hunks": [] }
}
```

- コメントのソースは **3 つ**、`author` で区別:
  1. 各行の「＋」または **行番号のドラッグ選択** で付けた行/範囲コメント
     （author=human。範囲は `start_line`/`start_side` を持つ）
  2. ハンク末尾のコメント欄（代表行に紐づく、author=human）
  3. **AI の指摘・要改善** のうち「PRに送る」にチェックされたもの
     （author=ai、本文に `🤖 Claude (指摘|要改善):` prefix。行キーはその行、
     範囲キーは `start_line`〜`line`、ハンクキーは代表行にアンカー）。既定
     ON、人間が不要分のチェックを外す。
- GitHub はアカウントを偽装できないため、AI/人間の区別は **本文の prefix
  のみ**（`author` は送信前に落とす）。
- `_context.skipped_hunks` にハンク id が入っていたら行を特定できずコメントを
  落としている。ユーザーに知らせ、PR 全体コメント（`body`）へ回すか手動対応を
  促す。

送信手順:

1. PR 番号を特定する（`_context.head` を使う）:
   ```bash
   gh pr view <head-branch> --json number,url -q '.number'
   ```
   見つからなければ「その branch に対応する open PR が無い」と伝え、勝手に PR
   を作らない。
2. GitHub API 用に整形（`_context` と各コメントの `author` を落とす）:
   ```bash
   gh api repos/{owner}/{repo}/pulls/<pr-number>/reviews \
     --method POST --input <(jq 'del(._context) |
       .comments |= map(del(.author))' review.json)
   ```
   `{owner}/{repo}` は `gh repo view --json nameWithOwner -q .nameWithOwner`。
3. **送信は破壊的で外向きの操作**。実行前に「PR #N に event=<...>、人間 H 件 /
   AI A 件のコメントを送信します」と `_context.counts` で要約し、ユーザーの
   承認を得てから叩く。APPROVE / REQUEST_CHANGES は特に明示的な確認を取る。
4. 送信後、返ってきたレビュー URL をユーザーに提示する。

`comments` が空で `event` が COMMENT のとき GitHub は body 必須。空レビューに
ならないよう body を促すか送信を見送る。

## The generated page

A sticky header shows a DIFF REVIEW label, the title, `N files / M hunks
+A −D`, an approval progress bar (承認 X/Y), a まとめをコピー button, a
PR送信用にコピー button (branch mode), and a "?" legend. Section 01 lists the
groups in risk order — left border colored by risk, description, tags, hunk
count, 指摘/要改善 counts — each linking to its detail card in section 02. A
meta line shows 対象範囲・生成日時・解説量レベル・指摘/要改善件数. Detail
cards have the risk badge, 意図, and a 確認して承認 checkbox. Hunks render
with id, file path, `@@` range, two line-number columns, intraline
highlighting; lockfile/生成物 hunks get a `generated` badge. Annotation boxes
render in a fixed order — 意図 (purple), コード解説 (green), 指摘 (red),
要改善 (amber), 解説 (blue). 行キーの注釈は該当行の直下にインライン表示、
ハンクキーはハンク下にまとめて表示。

**行コメント・範囲コメント**: diff の各行（追加行・文脈行 = RIGHT 側）にホバー
すると左端に「＋」が出て、その行にコメントできる。さらに **行番号列をドラッグ**
すると複数行を範囲選択でき、離すと範囲コメント欄が開く（GitHub の PR 画面と
同じ）。1 行/範囲に複数コメント可、各欄に「削除」ボタン。内容は localStorage
に保存されリロードで復元。範囲は `start_line`〜`line` で PR 送信される。削除行
(LEFT 側)・meta 行にはコメント不可。

各 指摘/要改善 の下には「PRに送る」チェックボックス（既定 ON）があり、チェック
したものが author=ai の行コメントとして（🤖 Claude prefix 付きで）送信対象に
加わる。人間はこれで AI 指摘を取捨選択できる。

The **まとめをコピー** button assembles a Markdown summary — all 指摘/要改善
with ids and paths, every human comment, and unapproved groups — for pasting
back into the working session. Approval state and comments persist in
localStorage, keyed by title + merge-base.

## Iterating

If the user asks to refine ("この指摘もう少し詳しく", "グループ分け直して"),
edit `explanations.json` in the same workdir and re-run `render` — no need to
re-extract unless the code changed. Regrouping changes group indices, which
resets saved approval checkboxes for that page.
