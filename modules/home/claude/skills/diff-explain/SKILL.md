---
name: diff-explain
description: >-
  Generate an annotated diff-review page in the browser: changes are grouped
  into semantic "change groups" (across files), each with an intent
  explanation, a risk level (要注意/注意/低リスク), tags, review findings
  (指摘), and a per-group "確認して承認" checkbox with an approval progress
  bar. Works for branch-vs-base diffs and also unstaged/staged/worktree
  diffs. Use this skill whenever the user asks to "explain the diff",
  "差分を解説して", "変更内容をレビュー画面で見たい", "未ステージの変更をまとめて",
  "レビュー前に変更を整理して", wants a visual/browser walkthrough of what
  changed on a branch vs main/master/develop, or wants to review their own
  uncommitted changes before committing. Also trigger for phrasings like
  "このブランチで何を変えたか説明して" or "diffをブラウザで見たい" even if
  "review" is not mentioned. Do NOT use for reviewing a remote PR by URL, or
  for one-line diff questions answerable inline in chat.
---

# Diff Explain

Build a self-contained review page for a diff, organized the way a reviewer
thinks — not file by file, but as **semantic change groups**: "URL・ホスト
判定の共通基盤", "設計文書と移行計画の更新", and so on. Each group carries an
intent (意図), a risk level, tags, annotated hunks, review findings (指摘),
and an approval checkbox. A progress bar in the header tracks 承認 N/M. The
output is one HTML file with zero network dependencies.

Division of labor: `scripts/build_diff_page.py` does everything
deterministic — diff extraction, parsing, global hunk ids, intraline
highlighting, HTML rendering, approval-state persistence. Your job is the
part that requires understanding the code: reading the diff and writing
`explanations.json`. Do not hand-write the HTML or re-parse the diff.

## Workflow

### 1. Extract the diff

```bash
python <skill-path>/scripts/build_diff_page.py extract [--mode MODE]
```

Pick the mode from what the user asked for:

- `branch` (default) — current branch vs base, three-dot style
  (`merge-base..HEAD`). Base auto-detects via `origin/HEAD` then
  `main`/`master`/`develop`; pass `--base <branch>` if the user names one.
- `unstaged` — working tree vs index (「未ステージの変更」).
- `staged` — index vs HEAD (「ステージした変更」).
- `worktree` — working tree vs HEAD (staged + unstaged together).

Add `--workdir <dir>` to reuse a directory when regenerating.

The script prints the workdir and a **hunk index**: every file with its
hunks and their global ids (`h001`, `h002`, …). Those ids are what you
assign to groups in `explanations.json`. It also writes `raw.diff` and
`diff_data.json`. If it exits with "No differences", report that and stop.

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
「その他の変更」 group — that's a fallback, not a dumping ground; prefer
assigning everything deliberately.

For large diffs, triage: read the hunk index first, read meaningful files
fully, skim mechanical mass-changes. If ±3 lines of context isn't enough to
understand a hunk, read the actual file in the repo — guessed explanations
are worse than short ones.

### 3. Write explanations.json

Write `<workdir>/explanations.json`:

```json
{
  "title": "app/system URL整理の未ステージ差分レビュー",
  "groups": [
    {
      "name": "URL・ホスト判定の共通基盤",
      "risk": "high",
      "tags": ["core"],
      "description": "一覧に出す60字程度の要約(省略時はintent先頭を使用)",
      "intent": "従来はcontroller・view・batchの三箇所でURLを個別に組み立てており、deployment modeを追加するたびに分岐が増え不整合の温床になっていた。本グループではURL生成とhost判定を`UrlResolver`一か所へ集約し、legacy-path方式とsubdomain方式をmodeフラグで切り替える形に再設計する。呼び出し側は文字列連結をやめて`resolver.url_for(...)`を呼ぶだけになり、影響範囲は三モジュールに広がるが判定ロジックの重複は解消される。subdomain方式はDNS設定が前提のため、未設定環境では従来のlegacy-pathへ安全にfallbackする設計にした。既存URLの後方互換は保つが、生成順序が変わるためリダイレクトのテストは要確認。",
      "hunks": ["h079", "h080", "h081"],
      "hunk_intents": {
        "h080": "このハンク固有の意図(紫)。このハンクだけで何を狙って変えたか。グループ全体のintentとは別に、この差分片の目的を一言で。"
      },
      "code_notes": {
        "h080": "コード解説(緑)。変更後のコードが実際に何をしているかの逐次的な読解補助。`resolver.url_for`はmode→builder関数の辞書を引き、該当がなければlegacy builderにfallbackして絶対URLを返す。"
      },
      "hunk_notes": {
        "h080": "解説(青)。なぜこう変えたか・非自明な点。modeフラグの判定をここで一度だけ行い結果をキャッシュしている。呼び出しごとに環境変数を読むとhot pathで無視できないコストになるため。`nil`のときにlegacy扱いになる点が後方互換の要で、明示的にfalseと区別している。"
      },
      "findings": {
        "h081": "指摘(赤)。レビューで対応を検討すべき問題点や懸念。"
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

Field guidance:

- **risk**: `high` (要注意) = behavior changes, security/auth boundaries,
  concurrency, data migration — anything where a bug is expensive. `medium`
  (注意) = broad but mechanical changes worth a scan. `low` (低リスク) =
  docs, generated files, pure renames. Judge by consequence of a mistake,
  not by line count.
- **tags**: 1–2 short lowercase words (`core`, `refactor`, `docs`, `test`,
  `deps`, `config`). They render as mono pills in the overview.
- **intent** answers: なぜこの変更か、どういう設計判断か、影響範囲はどこまでか。
  各グループで最低でも 3〜5 文（目安 150〜300 字）書き、次を順に埋める:
  (1) この変更が解こうとしている問題・背景、(2) 採った設計・実装アプローチと
  その理由、(3) 影響範囲（呼び出し側・データ・互換性・パフォーマンス）、
  (4) 検討したが採らなかった代替案や既知のトレードオフがあれば。箇条書きで
  構造化してよい。Markdown subset available: paragraphs, bullets, `code`,
  **bold**, fenced blocks. 憶測は「〜と思われる」と明示する。要約で済ませず、
  レビュアーがそのグループのコードを読まなくても判断の土台が分かる密度を目指す。
- **ハンク単位の注釈は3種ある**。同じハンクに複数付けてよいが、内容は
  役割で書き分け、重複させない。表示順は 意図 → コード解説 → 解説。
  - **hunk_intents** (意図, purple) — そのハンク *固有* の変更意図。「この
    差分片で何を狙ったか」を 1〜2 文で。グループの `intent` が全体を語るのに
    対し、これは 1 ハンクの目的にズームインする。グループに 1 ハンクしか
    なく intent と重複するなら省略してよい。
  - **code_notes** (コード解説, green) — 変更 *後* のコードが実際に何を
    しているかの読解補助。レビュー観点（良し悪し）ではなく、処理の流れ・
    データの動き・戻り値を淡々と説明する。非自明なアルゴリズムや読みづらい
    式があるハンクで有効。自明なコードには付けない。
  - **hunk_notes** (解説, blue) — *why* と非自明な点。コードの言い換えでは
    なく「なぜこう書いたか」「この行が何を保証/変えているか」「読み手が
    誤解しやすい点」を 2〜4 文（目安 80〜200 字）で。関連ハンクや既存コード
    との関係、境界条件、副作用にも触れる。
  いずれも本当に自明なハンク（純粋なrename、import追加、フォーマットのみ）
  には無理に付けず省略する（水増しは avoid）。密度を上げるのは「非自明さ」が
  ある箇所に限る。code_notes が「何を」、hunk_notes が「なぜ」、hunk_intents
  が「その一片の狙い」— この住み分けを守る。
- **findings** (指摘, red) are things the author should act on or
  consciously accept: bugs, missing invalidation, boundary conditions,
  behavior changes that need a call-out, docs claiming completion of
  unfinished work. Only raise findings you'd stand behind in a real review
  — the header counts them, so noise erodes trust. A hunk can have both a
  finding and a note.
- **unclear** (要改善, amber) marks two things: changes with clear room for
  improvement that fall short of a definite problem, and — importantly —
  changes whose *intent you cannot determine* from the diff and the repo.
  Never paper over an unintelligible change with a plausible-sounding
  explanation; marking it 要改善 ("この変更の意図が読み取れません。〜のため
  であれば問題ありませんが確認を推奨") is the honest and more useful output.
- **Display order is risk order**: the renderer stable-sorts groups
  high → medium → low, so a reviewer always meets the dangerous changes
  first. Your authored order is preserved within the same risk level — use
  it to put the conceptual core before its dependents.
- **Language**: match the user's language (この文脈ではほぼ日本語).
- Hunk ids must come from the extract output. Each id should appear in at
  most one group.

### 4. 忖度対策: two-stage review (when a plan/spec exists)

If the change was implemented from a plan, spec, or instructions that are
visible to you (in context, in the repo, or provided by the user), there is
a known failure mode: reviewing against the plan makes you excuse mediocre
implementation with "planに則っているのでOK". Counter it by reviewing in two
stages:

1. **Blind pass** — review the diff *without consulting the plan*, judging
   the code purely on its own merits: correctness, boundary conditions,
   design, naming. In Claude Code, prefer spawning a subagent that receives
   only `raw.diff` (plus repo read access) and no plan, and returns its
   findings. Without subagents, write your blind findings down *before*
   (re)reading the plan.
2. **Plan-aware pass** — now compare against the plan: does the diff cover
   it, deviate from it, or silently skip parts of it? Add plan-dependent
   findings ("planではXも対象だが未実装").

Merge the two: blind findings survive even when the plan justifies the
implementation — note the justification in the finding text ("plan上は
意図通りだが、〜の懸念は残る") rather than deleting the finding. Plan-only
findings (things only detectable by reading the plan) stay too.

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
which group to review first, and the findings count if any.

### 6. GitHub PR にレビューを送信する（branch モードのみ）

`branch` モードで生成したページには「PR送信用にコピー」ボタンと、末尾に
**03 / PRレビューを送信** パネル（判定ラジオ + 全体コメント欄）がある。人間は
各ハンクのコメント欄に行コメントを書き、判定を APPROVE / REQUEST_CHANGES /
COMMENT から選び、ボタンで **送信用 JSON** をクリップボードにコピーする。その
JSON を作業セッションに貼って「PR に送って」と依頼されたら、あなたが `gh` で
GitHub PR レビューとして投稿する。

コピーされる JSON の形:

```json
{
  "event": "REQUEST_CHANGES",
  "body": "レビュー全体のサマリー（任意）",
  "comments": [
    { "path": "app/foo.rb", "line": 42, "side": "RIGHT",
      "body": "人間が h012 のコメント欄に書いた内容" }
  ],
  "_context": { "head": "feature-x", "base": "main", "mode": "branch",
                "title": "...", "skipped_hunks": [] }
}
```

- 行コメントは **人間が書いたもの限定**。レビュー AI の指摘（findings/
  unclear）は含まれない（それらは「まとめをコピー」の担当）。ソースは 2 つ:
  各行の「＋」で付けた **行コメント**（その行そのものに紐づく）と、ハンク末尾
  の **ハンクコメント欄**（ハンク代表行に紐づく）。
- 行コメントの `line`/`side` はその行の新側行番号・RIGHT。ハンクコメントの
  `line`/`side` は代表行（新側の最終追加行を優先、なければ文脈行、それも
  無ければ旧側の削除行）に自動で対応づけられている。
- `_context.skipped_hunks` にハンク id が入っていたら、そのハンクは行を
  特定できずコメントを落としている。ユーザーに知らせ、必要なら PR 全体
  コメント（`body`）へ回すか手動対応を促すこと。

送信手順:

1. PR 番号を特定する。`_context.head` を使う:
   ```bash
   gh pr view <head-branch> --json number,url -q '.number'
   ```
   見つからなければ「その branch に対応する open PR が無い」旨を伝え、勝手に
   PR を作らない。
2. JSON をそのまま GitHub API に渡す（`event`/`body`/`comments` はそのまま
   使える形にしてある。`_context` は送信前に取り除く）:
   ```bash
   gh api repos/{owner}/{repo}/pulls/<pr-number>/reviews \
     --method POST --input <(jq 'del(._context)' review.json)
   ```
   `{owner}/{repo}` は `gh repo view --json nameWithOwner -q .nameWithOwner`
   で解決できる。
3. **送信は破壊的で外向きの操作**。実行前に「PR #N に event=<...>、行コメント
   M 件を送信します」と要約し、ユーザーの承認を得てから叩く。APPROVE /
   REQUEST_CHANGES は特に、明示的な確認を取る。
4. 送信後、返ってきたレビュー URL をユーザーに提示する。

`comments` が空で `event` が COMMENT のとき、GitHub は body 必須。空レビューに
ならないよう、その場合は body を促すか送信を見送る。

## The generated page

So you can answer questions about it: a sticky header shows a DIFF REVIEW
label, the title, `N files / M hunks +A −D`, an approval progress bar
(承認 X/Y), a まとめをコピー button, and a "?" button with a legend. Section
01 lists the groups in risk order — left border colored by risk
(red/amber/gray), description, tags, hunk count, 指摘/要改善 counts — each
linking to its detail card in section 02. Detail cards have the risk badge,
意図, and a 確認して承認 checkbox. Hunks render with their id, file path,
`@@` range, two line-number columns, and intraline highlighting of changed
spans. Annotation boxes sit directly under their hunk in a fixed order —
意図 (purple, hunk-level intent), コード解説 (green, what the code does),
指摘 (red), 要改善 (amber), 解説 (blue, why) — followed by a free-text
comment box (one per hunk, one per group).

**行コメント**: diff の各行（追加行・文脈行 = RIGHT 側）にホバーすると左端に
「＋」ボタンが出る。押すとその行の直下にインラインでコメント欄が開き、GitHub
の PR 画面と同じ感覚で特定の行にコメントを残せる。1 行に複数コメント可、各欄に
「削除」ボタンあり。書いた内容は行番号・side に紐づいて localStorage に保存
され、リロード時に該当行の下へ復元される。削除行 (LEFT 側) と meta 行には
コメントを付けられない。

For `branch`-mode diffs the header also shows a **PR送信用にコピー** button,
and a **03 / PRレビューを送信** panel at the foot carries the APPROVE /
REQUEST_CHANGES / COMMENT radio and an overall-body box (see §6). 行コメントは
その行そのものへ、ハンク末尾のコメント欄はハンク代表行へ紐づいて送信 JSON の
`comments[]` に入る。

The **まとめをコピー** button assembles a Markdown summary — all 指摘 and
要改善 with hunk ids and file paths, every comment the human wrote in the
boxes, and the list of unapproved groups — and puts it on the clipboard,
ready to paste back into the working session (e.g. the Claude Code session
that produced the change) as actionable feedback. Approval state and
comments persist in localStorage, keyed by title + merge-base. When you
hand over the page, mention this button — it's the return path of the
review loop.

## Iterating

If the user asks to refine ("この指摘もう少し詳しく", "グループ分け直して"),
edit `explanations.json` in the same workdir and re-run `render` — no need
to re-extract unless the code changed. Note that regrouping changes group
indices, which resets saved approval checkboxes for that page.
