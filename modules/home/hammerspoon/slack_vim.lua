-- Slack を vim 風に操作する（j/k: 選択移動, J/K: スクロール, Ctrl+j/k: サイドバーのセクション単位で移動（入力欄ではメンションなどの候補の選択移動）, Ctrl+h/l: サイドバー/メッセージ一覧へ移動, Enter: スレッドを開く, Tab: 投稿内のリンク・添付ファイルを巡回, i: 入力欄へ, f: 検索）
local M = {}

local SLACK_BUNDLE_ID = "com.tinyspeck.slackmacgap"
local SCROLL_LINES = 3
-- スクロール対象が見つからないときにスクロールする位置（ウィンドウに対する比率）
local FALLBACK_SCROLL_POINT = { x = 0.65, y = 0.5 }
local MAX_ANCESTOR_DEPTH = 40
-- 投稿の見えている部分がこの高さ（px）以上なら画面内とみなす
local MIN_VISIBLE_HEIGHT = 30
-- サイドバーの行（高さ約 28px）が画面内とみなす見えている高さ（px）
local MIN_VISIBLE_ROW_HEIGHT = 24
local MAX_SEARCH_DEPTH = 50
-- 送った矢印キーの結果フォーカスが入力欄に入ったかを確かめるまでの待ち時間（秒）
local ARROW_GUARD_DELAY = 0.05
-- 矢印キーを 1 回ずつ送るときの間隔（秒）と最大回数（隣の投稿へ / 画面内の投稿へ選び直すとき）
local ARROW_STEP_DELAY = 0.06
-- フォーカスがこの回数続けて動かなければ端に着いたとみなす（Slack の反映が遅れることがあるため 1 回では判断しない）
local MAX_STALLS = 2
local MAX_ADJACENT_STEPS = 8
local MAX_REENTRY_STEPS = 100
-- Slack が自前で管理しているメッセージ一覧のカーソル（フォーカス枠が付く項目）のクラス
local CURSOR_CLASS = "c-virtual_list__item--focus"
-- 矢印キーを送った直後は、入力欄に入っても j/k を文字として通さない時間（秒）。キーリピート対策
local ARROW_TYPING_GRACE = 0.3
-- Esc を Slack が処理（補完ポップアップを閉じる等）してからフォーカスを移すための待ち時間（秒）
local ESCAPE_FOCUS_DELAY = 0.05
-- チャンネルを開いた後、Slack が入力欄にフォーカスするのとメッセージが読み込まれるのを待つ間隔（秒）と最大回数
local CHANNEL_SWITCH_POLL_INTERVAL = 0.1
local CHANNEL_SWITCH_MAX_POLLS = 30
local CTRL_KEYS = { j = true, k = true, h = true, l = true }
local HANDLED_KEYS = { j = true, k = true, h = true, l = true, i = true, f = true, escape = true, ["return"] = true, tab = true }
-- Slack の検索のショートカット（Cmd+G）
local SEARCH_KEY = "g"
local SEARCH_MODS = { "cmd" }
-- 選択中のメッセージをスレッドで開く Slack のショートカット
local REPLY_IN_THREAD_KEY = "t"
local TEXT_ROLES = { AXTextArea = true, AXTextField = true, AXComboBox = true, AXSearchField = true }
local SIDEBAR_CLASS = "p-channel_sidebar"
-- スレッド一覧などのページは行自体に、チャンネルは行の子要素に選択中クラスが付く
local SECTION_HEADING_ID_PREFIX = "sectionHeading-"
local SELECTED_ROW_CLASS = "p-channel_sidebar__static_list__item--selected"
local SELECTED_CHANNEL_CLASS = "p-channel_sidebar__channel--selected"
local MESSAGE_PANE_CLASS = "p-message_pane"
local THREADS_VIEW_CLASS = "p-threads_view"
local THREAD_PANE_CLASS = "p-threads_flexpane"
local PRIMARY_VIEW_CLASS = "p-view_contents--primary"
-- メッセージ入力欄（チャンネル・スレッド）を囲む要素のクラス。検索欄と区別する
local COMPOSER_CLASS = "c-wysiwyg_container"
local REPLY_COUNT_CLASS = "c-message__reply_count"
-- Tab 巡回から外すリンク（投稿時刻・ファイルのダウンロード等のアイコン）
local NON_CONTENT_LINK_CLASSES = { "c-timestamp", "c-message_actions__button" }
-- メンションはチャンネル・ユーザーとも c-member_slug が付くので、チャンネルだけ残す
local MENTION_CLASS = "c-member_slug"
local CHANNEL_MENTION_CLASS = "c-mrkdwn__channel"
-- ボタン部品だがリンク相当として巡回に含めるもの（「replied to a thread: 〜」の返信元スレッド）
local LINK_LIKE_BUTTON_CLASSES = { "c-message__broadcast_preamble_link" }
local SCROLL_CONTAINER_CLASSES = { "c-scrollbar__hider", "c-virtual_list__scroll_container" }
local MESSAGE_ID_PATTERN = "^message%-list_%d+%.%d+$"
local THREAD_ROOT_ID_PATTERN = "^threads_view_root%-"
local THREADS_VIEW_ID_PREFIX = "threads_view_"
local THREADS_VIEW_FOOTER_PREFIX = "threads_view_footer-"

-- 投稿そのもの（日付区切り・入力欄・スレッド一覧の見出しやフッター以外）の要素 ID か
function M.isMessageId(id)
  if not id:match("%d+%.%d+$") then return false end
  return not (id:match("heading") or id:match("footer") or id:match("load_older"))
end

-- スレッド一覧画面の要素 ID から、属するスレッドのキー（"チャンネルID-親投稿の時刻"）を取り出す
function M.threadKey(id)
  return id:match("([%u%d]+%-%d+%.%d+)")
end

-- AX が返す矩形はスクロール領域で切り取られる（画面外は高さ 1）ので、見えている高さで表示中かを判定する
function M.isVisible(height)
  return height >= MIN_VISIBLE_HEIGHT
end

-- 表示中の投稿のうち、下方向（dir = 1）なら一番上、上方向（dir = -1）なら一番下の位置を返す
function M.visibleMessageIndex(ids, heights, dir)
  local from, to = 1, #ids
  if dir == -1 then from, to = #ids, 1 end
  for i = from, to, dir do
    if M.isMessageId(ids[i]) and M.isVisible(heights[i]) then return i end
  end
  return nil
end

-- サイドバーを上から並べた行のうち current 番目から、dir 方向で最寄りのセクション見出しまでの矢印キー回数（符号付き）を返す。
-- 見出しはそのセクションのチャンネルより前に並ぶので、上方向でセクション内にいればその見出しが最寄りになる
function M.headingSteps(isHeading, current, dir)
  local i = current + dir
  while i >= 1 and i <= #isHeading do
    if isHeading[i] then return i - current end
    i = i + dir
  end
  return nil
end

-- サイドバーの行で画面に映っているもののうち、下方向なら一番上、上方向なら一番下の位置を返す
function M.visibleRowIndex(heights, dir)
  local from, to = 1, #heights
  if dir == -1 then from, to = #heights, 1 end
  for i = from, to, dir do
    if heights[i] >= MIN_VISIBLE_ROW_HEIGHT then return i end
  end
  return nil
end

-- target 番目の投稿へ矢印キー 1 回分の距離から近づくための起点（手前の投稿、なければ後ろの投稿）と、そこから送る向き
function M.anchorIndex(ids, target)
  local before = M.nextMessageIndex(ids, target, -1)
  if before then return before, 1 end
  local after = M.nextMessageIndex(ids, target, 1)
  if after then return after, -1 end
  return nil
end

-- ids[index] から dir（1: 下, -1: 上）方向で次の投稿の位置を返す。見出し・フッター・入力欄は飛ばす
function M.nextMessageIndex(ids, index, dir)
  local i = index + dir
  while i >= 1 and i <= #ids do
    if M.isMessageId(ids[i]) then return i end
    i = i + dir
  end
  return nil
end

-- 送るキー { key, mods }、スクロール { scroll = 1 | -1 }、セクション移動 { section = 1 | -1 }、フォーカス移動 { focus = "sidebar" | "messages" }、
-- フォーカス移動の focus は "sidebar" | "messages" | "input"。waitForInput = true は入力欄にフォーカスが移るのを待ってから移す。
-- スレッドを開く { openThread = true }、投稿内リンク巡回 { cycleLink = 1 | -1 }、または nil（キーをそのまま通す）を返す。
-- passthrough = true はキーを通したうえでフォーカスを移す
function M.decide(char, shift, role, pane, ctrl, emptyComposer)
  -- 入力欄では Esc で抜けてメッセージ一覧へ移る
  if char == "escape" and TEXT_ROLES[role] then return { focus = "messages", passthrough = true } end
  -- フォーカス不明時に入力中の文字を食わないよう、role が取れないときは素通しする
  if role == nil then return nil end
  local dir = ({ j = 1, k = -1 })[char]
  if ctrl then
    -- ペインの移動は入力欄でも効かせる。スレッド欄からは真ん中のメッセージ一覧へ戻る
    if char == "h" then return { focus = pane == "thread" and "messages" or "sidebar" } end
    if char == "l" then return { focus = "messages" } end
    if not dir then return nil end
    if pane == "sidebar" then return { section = dir } end
    -- メンション・検索などの候補の選択移動（選択中は Slack が候補の項目にフォーカスを移すので、入力欄の外でも送る）。
    -- 空のメッセージ入力欄の ↑ は直前の投稿の編集になるので送らない
    if emptyComposer then return nil end
    return { press = dir == 1 and "down" or "up" }
  end
  if TEXT_ROLES[role] then return nil end
  if char == "f" and not shift then return { press = SEARCH_KEY, pressMods = SEARCH_MODS } end
  if char == "i" and not shift then return { focus = "input" } end
  if char == "return" then
    if shift then return nil end
    -- チャンネルを開くと Slack は入力欄にフォーカスするので、その後メッセージ一覧へ移す
    if pane == "sidebar" then return { focus = "messages", passthrough = true, waitForInput = true } end
    return { openThread = true }
  end
  if char == "tab" then
    if pane == "sidebar" then return nil end
    return { cycleLink = shift and -1 or 1 }
  end
  if not dir then return nil end
  if shift then return { scroll = dir } end
  return { key = dir == 1 and "down" or "up" }
end

local function hasClass(el, class)
  local classes = el:attributeValue("AXDOMClassList")
  if type(classes) ~= "table" then return false end
  for _, c in ipairs(classes) do
    if c == class then return true end
  end
  return false
end

local function centerOf(el)
  local pos, size = el:attributeValue("AXPosition"), el:attributeValue("AXSize")
  if not (pos and size) then return nil end
  return { x = pos.x + size.w / 2, y = pos.y + size.h / 2 }
end

local function findFirst(el, pred, depth)
  if pred(el) then return el end
  if depth <= 0 then return nil end
  for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
    local found = findFirst(child, pred, depth - 1)
    if found then return found end
  end
  return nil
end

local function ancestorWithClass(el, class)
  for _ = 1, MAX_ANCESTOR_DEPTH do
    if not el then return nil end
    if hasClass(el, class) then return el end
    el = el:attributeValue("AXParent")
  end
  return nil
end

local function slackElement(app)
  local appEl = hs.axuielement.applicationElement(app)
  -- Electron アプリはこれを立てないと DOM 由来の要素を公開しない
  appEl:setAttributeValue("AXManualAccessibility", true)
  return appEl
end

-- フォーカス中要素の role、ペイン（"sidebar" | "thread" | nil）、スクロールさせる座標、フォーカス中要素を返す
local function inspectFocus(appEl)
  local focused = appEl:attributeValue("AXFocusedUIElement")
  if not focused then return nil, nil, nil, nil end
  local role = focused:attributeValue("AXRole")
  if TEXT_ROLES[role] then return role, nil, nil, focused end
  local pane, scrollPoint = nil, nil
  local el = focused
  for _ = 1, MAX_ANCESTOR_DEPTH do
    if not el then break end
    if not scrollPoint then
      for _, class in ipairs(SCROLL_CONTAINER_CLASSES) do
        if hasClass(el, class) then scrollPoint = centerOf(el); break end
      end
    end
    if hasClass(el, SIDEBAR_CLASS) then pane = "sidebar"; break end
    if hasClass(el, THREAD_PANE_CLASS) then pane = "thread"; break end
    el = el:attributeValue("AXParent")
  end
  return role, pane, scrollPoint, focused
end

local function fallbackScrollPoint(app)
  local win = app:focusedWindow()
  if not win then return nil end
  local f = win:frame()
  return { x = f.x + f.w * FALLBACK_SCROLL_POINT.x, y = f.y + f.h * FALLBACK_SCROLL_POINT.y }
end

-- スクロールイベントはポインタ位置の要素に届くため、一瞬ポインタを移動してから元に戻す
local lastScrollPoint = nil
-- 最後にスクロールしたペイン（"sidebar" | "thread" | nil）と一覧の要素。スクロールでフォーカスが外れた後の j/k の行き先に使う。
-- （Hammerspoon から AX ツリー全体を探索すると数秒以上かかるため、スクロール時に要素を覚えておく）
local lastScrollPane = nil
local lastScrollList = nil

local function scrollAt(point, dir)
  lastScrollPoint = point
  local original = hs.mouse.absolutePosition()
  hs.eventtap.event.newScrollEvent({ 0, -dir * SCROLL_LINES }, {}, "line"):location(point):post()
  hs.mouse.absolutePosition(original)
end

local function focusSidebar(win)
  local row = findFirst(win, function(el) return hasClass(el, SELECTED_ROW_CLASS) end, MAX_SEARCH_DEPTH)
  if not row then
    local selected = findFirst(win, function(el) return hasClass(el, SELECTED_CHANNEL_CLASS) end, MAX_SEARCH_DEPTH)
    row = selected and selected:attributeValue("AXParent")
  end
  if not row then
    hs.alert.show("slack_vim: 選択中のチャンネルが見つかりません")
    return
  end
  row:setAttributeValue("AXFocused", true)
end

local function listItems(container)
  local list = findFirst(container, function(el) return el:attributeValue("AXRole") == "AXList" end, MAX_SEARCH_DEPTH)
  return list and list:attributeValue("AXChildren") or {}
end

local function focusItem(items, pattern, from, to, step)
  for i = from, to, step do
    local id = items[i]:attributeValue("AXDOMIdentifier")
    if id and id:match(pattern) then
      items[i]:setAttributeValue("AXFocused", true)
      return true
    end
  end
  return false
end

-- チャンネルは最新（末尾）のメッセージ、スレッド一覧は先頭のスレッドにフォーカスする。
-- フォーカスできたら true を返す。silent = true なら見つからなくても通知しない
local function focusMessages(win, silent)
  local pane = findFirst(win, function(el)
    return hasClass(el, MESSAGE_PANE_CLASS) or hasClass(el, THREADS_VIEW_CLASS)
  end, MAX_SEARCH_DEPTH)
  if pane then
    local items = listItems(pane)
    local focused
    if hasClass(pane, THREADS_VIEW_CLASS) then
      focused = focusItem(items, THREAD_ROOT_ID_PATTERN, 1, #items, 1)
    else
      focused = focusItem(items, MESSAGE_ID_PATTERN, #items, 1, -1)
    end
    if focused then return true end
  end
  if not silent then hs.alert.show("slack_vim: メッセージ一覧が見つかりません") end
  return false
end

-- キャッシュのないチャンネルはメッセージの読み込みに時間がかかるので、読み込まれるまで繰り返す
local function focusMessagesWhenLoaded(win, remaining)
  if focusMessages(win, remaining > 0) or remaining <= 0 then return end
  hs.timer.doAfter(CHANNEL_SWITCH_POLL_INTERVAL, function() focusMessagesWhenLoaded(win, remaining - 1) end)
end

-- 修飾キーは mods だけにする（押している Ctrl などが引き継がれると Ctrl+↓ のように別のキーになる）
local function keyEvents(mods, key)
  local flags = {}
  for _, mod in ipairs(mods or {}) do flags[mod] = true end
  return {
    hs.eventtap.event.newKeyEvent(mods or {}, key, true):setFlags(flags),
    hs.eventtap.event.newKeyEvent(mods or {}, key, false):setFlags(flags),
  }
end

local function isRow(el)
  return el:attributeValue("AXRole") == "AXRow"
end

-- セクション見出し行の配下にあるチャンネル行（折りたたみ中は未読などで表示されているものだけ）
local function channelRowsOf(sectionRow)
  local rows = {}
  for _, group in ipairs(sectionRow:attributeValue("AXChildren") or {}) do
    for _, child in ipairs(group:attributeValue("AXChildren") or {}) do
      if isRow(child) then table.insert(rows, child) end
    end
  end
  return rows
end

-- サイドバーを上から並べた行（最上位の行と、セクション配下のチャンネル行）
local function sidebarRows(outline)
  local rows = {}
  for _, top in ipairs(outline:attributeValue("AXChildren") or {}) do
    if isRow(top) then
      table.insert(rows, top)
      for _, row in ipairs(channelRowsOf(top)) do table.insert(rows, row) end
    end
  end
  return rows
end

local function outlineOf(el)
  for _ = 1, MAX_ANCESTOR_DEPTH do
    if not el then return nil end
    if el:attributeValue("AXRole") == "AXOutline" then return el end
    el = el:attributeValue("AXParent")
  end
  return nil
end

-- Slack はサイドバーのカーソル位置を自前で持っており、AX でフォーカスを移しても追従せずフォーカス枠も出ない。
-- そのため最寄りのセクション見出しまでの行数を数え、その回数だけ矢印キーを送る
local function sectionKeyEvents(focused, dir)
  local outline = outlineOf(focused)
  if not outline then return nil end
  local isHeading, current = {}, nil
  for i, row in ipairs(sidebarRows(outline)) do
    local id = row:attributeValue("AXDOMIdentifier") or ""
    isHeading[i] = id:sub(1, #SECTION_HEADING_ID_PREFIX) == SECTION_HEADING_ID_PREFIX
    if row == focused then current = i end
  end
  local steps = current and M.headingSteps(isHeading, current, dir)
  if not steps then return nil end
  local events = {}
  for _ = 1, math.abs(steps) do
    for _, ev in ipairs(keyEvents({}, dir == 1 and "down" or "up")) do table.insert(events, ev) end
  end
  return events
end

-- 返信があるメッセージなら「N件の返信」ボタンを押してスレッドを開く
local function messageItemOf(el)
  for _ = 1, MAX_ANCESTOR_DEPTH do
    if not el then return nil end
    local id = el:attributeValue("AXDOMIdentifier")
    if id and M.isMessageId(id) then return el end
    el = el:attributeValue("AXParent")
  end
  return nil
end

-- スレッドがあれば返信数のボタンを押し、なければ Slack の「スレッドで返信」（選択中のメッセージで T）を送る
local function openThread(message)
  local button = findFirst(message, function(el) return hasClass(el, REPLY_COUNT_CLASS) end, MAX_SEARCH_DEPTH)
  if button then
    button:performAction("AXPress")
    return true
  end
  if not messageItemOf(message) then return false end
  return true, keyEvents({}, REPLY_IN_THREAD_KEY)
end

-- 本文のリンク・チャンネル名・添付ファイル（いずれも AXLink）と返信元スレッドを巡回対象にする
local function isLinkTarget(el)
  local role = el:attributeValue("AXRole")
  if role == "AXButton" then
    for _, class in ipairs(LINK_LIKE_BUTTON_CLASSES) do
      if hasClass(el, class) then return true end
    end
    return false
  end
  if role ~= "AXLink" then return false end
  for _, class in ipairs(NON_CONTENT_LINK_CLASSES) do
    if hasClass(el, class) then return false end
  end
  return not hasClass(el, MENTION_CLASS) or hasClass(el, CHANNEL_MENTION_CLASS)
end

-- テーブルは行と列の両方から同じセルを子に持つため、列はたどらない（重複すると巡回が先へ進まない）
local function collect(el, pred, out, depth)
  if pred(el) then table.insert(out, el) end
  if depth <= 0 then return out end
  for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
    if child:attributeValue("AXRole") ~= "AXColumn" then
      collect(child, pred, out, depth - 1)
    end
  end
  return out
end

-- 投稿 → リンク1 → リンク2 → … → 投稿 の順にフォーカスを巡回する。投稿外にフォーカスがあれば false を返す
local function cycleLink(focused, dir)
  local item = messageItemOf(focused)
  if not item then return false end
  local stops = collect(item, isLinkTarget, { item }, MAX_SEARCH_DEPTH)
  local current = 1
  for i, el in ipairs(stops) do
    if el == focused then current = i; break end
  end
  stops[(current - 1 + dir) % #stops + 1]:setAttributeValue("AXFocused", true)
  return true
end

local function visibleHeightOf(el)
  local size = el:attributeValue("AXSize")
  return size and size.h or 0
end

-- スクロールで選択中の行が画面外に出たら、画面に映っている端の行から選び直す。
-- AX でのフォーカスだけでは枠が出ないため、目的の行にフォーカスした後に矢印キーで一度往復させる
local function sidebarReentryEvents(outline, dir)
  local rows = sidebarRows(outline)
  local heights = {}
  for i, row in ipairs(rows) do heights[i] = visibleHeightOf(row) end
  local target = M.visibleRowIndex(heights, dir)
  if not target then return nil end
  rows[target]:setAttributeValue("AXFocused", true)
  if not rows[target + dir] then return {} end
  local events = keyEvents({}, dir == 1 and "down" or "up")
  for _, ev in ipairs(keyEvents({}, dir == 1 and "up" or "down")) do table.insert(events, ev) end
  return events
end

-- Slack はメッセージ一覧のカーソル位置を自前で持っており、AX でフォーカスを移してもフォーカス枠が出ず、
-- 次の矢印キーも元のカーソル位置から動く。そのため投稿の移動はすべて矢印キーで行う
local lastArrowAt = 0
local stepping = false

local function messageIdOf(el)
  local item = el and messageItemOf(el)
  return item and item:attributeValue("AXDOMIdentifier")
end

-- 矢印キーを 1 回ずつ送り、isDone(フォーカス中の要素) が真になるか、フォーカスが動かなくなるまで繰り返す。
-- 途中で返信欄（スレッド一覧のフッター）を通過しても止まらない
local function stepArrows(appEl, key, isDone, remaining, previous, stalls)
  stepping = true
  lastArrowAt = hs.timer.secondsSinceEpoch()
  for _, ev in ipairs(keyEvents({}, key)) do ev:post() end
  hs.timer.doAfter(ARROW_STEP_DELAY, function()
    local now = appEl:attributeValue("AXFocusedUIElement")
    local stalled = now == previous and (stalls or 0) + 1 or 0
    if (now ~= nil and isDone(now)) or remaining <= 1 or now == nil or stalled >= MAX_STALLS then
      stepping = false
      return
    end
    stepArrows(appEl, key, isDone, remaining - 1, now, stalled)
  end)
end

local function listState(list, targetId)
  local children = list:attributeValue("AXChildren") or {}
  local ids, heights, cursorIndex, targetIndex = {}, {}, nil, nil
  for i, child in ipairs(children) do
    ids[i] = child:attributeValue("AXDOMIdentifier") or ""
    heights[i] = visibleHeightOf(child)
    if hasClass(child, CURSOR_CLASS) then cursorIndex = i end
    if targetId and ids[i] == targetId then targetIndex = i end
  end
  return children, ids, heights, cursorIndex, targetIndex
end

-- list の target 番目の投稿まで、Slack のカーソルを矢印キーで運ぶ
local function stepToTarget(appEl, list, target, focused)
  local children, ids, _, cursorIndex = listState(list)
  local targetId = ids[target]
  if cursorIndex == target then
    children[target]:setAttributeValue("AXFocused", true)
    return true
  end
  local function reached(el) return messageIdOf(el) == targetId end
  if not cursorIndex then
    -- カーソルの投稿が一覧から消えている（画面外へスクロールした）と、Slack は AX で置いたフォーカスを起点に動く。
    -- そこで目的の投稿の 1 つ手前に置き、矢印キーで目的の投稿へ入ってフォーカス枠を出す
    local anchor, anchorDir = M.anchorIndex(ids, target)
    if not anchor then
      children[target]:setAttributeValue("AXFocused", true)
      return true
    end
    children[anchor]:setAttributeValue("AXFocused", true)
    stepArrows(appEl, anchorDir == 1 and "down" or "up", reached, MAX_ADJACENT_STEPS, children[anchor])
    return true
  end
  -- カーソルが一覧にある間は、AX でフォーカスを移しても Slack はカーソル位置から動くので、カーソルから目的の投稿まで運ぶ
  local stepDir = target > cursorIndex and 1 or -1
  if not messageItemOf(focused) then children[cursorIndex]:setAttributeValue("AXFocused", true) end
  stepArrows(appEl, stepDir == 1 and "down" or "up", reached, MAX_REENTRY_STEPS, nil)
  return true
end

-- j/k の投稿移動。戻り値 true でキーを処理済みとする
local function moveMessage(appEl, focused, dir)
  local item = messageItemOf(focused)
  local list = item and item:attributeValue("AXParent") or lastScrollList
  if not list then return false end
  local _, ids, heights, cursorIndex = listState(list)
  local itemId = item and item:attributeValue("AXDOMIdentifier")
  local index = nil
  for i, id in ipairs(ids) do
    if id == itemId then index = i end
  end
  local visible = index ~= nil and M.isVisible(heights[index])
  if not visible then
    -- スクロールでフォーカス中の投稿が画面外に出た（または外れた）ら、画面内の投稿から選び直す
    local target = M.visibleMessageIndex(ids, heights, dir)
    return target ~= nil and stepToTarget(appEl, list, target, focused)
  end
  -- l などで AX から移したフォーカスは Slack のカーソルとずれているので、まずカーソルをそこへ運ぶ
  if index ~= cursorIndex then return stepToTarget(appEl, list, index, focused) end
  -- 最後の投稿より下はメインの入力欄なので止める
  if dir == 1 and not M.nextMessageIndex(ids, index, 1) then return true end
  local startId = ids[index]
  stepArrows(appEl, dir == 1 and "down" or "up", function(el)
    local id = messageIdOf(el)
    return id ~= nil and id ~= startId
  end, MAX_ADJACENT_STEPS, focused)
  return true
end

-- 矢印キーでフォーカスが入力欄に入ってしまったら元の要素に戻す
local function guardArrow(appEl, previous)
  hs.timer.doAfter(ARROW_GUARD_DELAY, function()
    local now = appEl:attributeValue("AXFocusedUIElement")
    if now and TEXT_ROLES[now:attributeValue("AXRole")] then
      previous:setAttributeValue("AXFocused", true)
    end
  end)
end

local function isTextArea(el)
  return el:attributeValue("AXRole") == "AXTextArea"
end

-- スレッド一覧画面では、フォーカス中のスレッドのフッターにある返信欄を返す
local function threadsViewInput(focused)
  local el = focused
  for _ = 1, MAX_ANCESTOR_DEPTH do
    if not el then return nil end
    local id = el:attributeValue("AXDOMIdentifier")
    local key = id and id:sub(1, #THREADS_VIEW_ID_PREFIX) == THREADS_VIEW_ID_PREFIX and M.threadKey(id)
    if key then
      local list = el:attributeValue("AXParent")
      local footer = list and findFirst(list, function(c)
        return c:attributeValue("AXDOMIdentifier") == THREADS_VIEW_FOOTER_PREFIX .. key
      end, 1)
      return footer and findFirst(footer, isTextArea, MAX_SEARCH_DEPTH)
    end
    el = el:attributeValue("AXParent")
  end
  return nil
end

-- スレッド一覧画面では選択中スレッドの返信欄、スレッド欄ではその返信欄、それ以外はメイン画面の入力欄にフォーカスする
local function focusInput(win, focused)
  local input = threadsViewInput(focused)
  if not input then
    local container = ancestorWithClass(focused, THREAD_PANE_CLASS)
      or findFirst(win, function(el) return hasClass(el, PRIMARY_VIEW_CLASS) end, MAX_SEARCH_DEPTH)
    input = container and findFirst(container, isTextArea, MAX_SEARCH_DEPTH)
  end
  if not input then
    hs.alert.show("slack_vim: 入力欄が見つかりません")
    return
  end
  input:setAttributeValue("AXFocused", true)
end

local function waitForInputThen(appEl, fn, remaining)
  local focused = appEl:attributeValue("AXFocusedUIElement")
  if focused and TEXT_ROLES[focused:attributeValue("AXRole")] then return fn() end
  if remaining <= 0 then return end
  hs.timer.doAfter(CHANNEL_SWITCH_POLL_INTERVAL, function() waitForInputThen(appEl, fn, remaining - 1) end)
end

local function onKeyDown(e)
  local flags = e:getFlags()
  if flags.cmd or flags.alt or flags.fn then return false end
  local char = hs.keycodes.map[e:getKeyCode()]
  if not HANDLED_KEYS[char] then return false end
  if flags.ctrl and not CTRL_KEYS[char] then return false end
  local app = hs.application.frontmostApplication()
  if not app or app:bundleID() ~= SLACK_BUNDLE_ID then return false end

  -- 矢印キーを送っている途中の j/k は捨てる（押しっぱなしでも順に進む）
  if stepping and (char == "j" or char == "k") then return true end
  local appEl = slackElement(app)
  local role, pane, scrollPoint, focused = inspectFocus(appEl)
  -- inspectFocus は入力中の負荷を避けて入力欄のペインを調べないので、Ctrl+h でスレッド欄から戻るときだけ調べる
  if flags.ctrl and TEXT_ROLES[role] and ancestorWithClass(focused, THREAD_PANE_CLASS) then pane = "thread" end
  if TEXT_ROLES[role] and (char == "j" or char == "k")
    and hs.timer.secondsSinceEpoch() - lastArrowAt < ARROW_TYPING_GRACE then
    return true
  end
  local emptyComposer = false
  if flags.ctrl and TEXT_ROLES[role] then
    local value = focused:attributeValue("AXValue")
    emptyComposer = not (type(value) == "string" and value:match("%S"))
      and ancestorWithClass(focused, COMPOSER_CLASS) ~= nil
  end
  local action = M.decide(char, flags.shift == true, role, pane, flags.ctrl == true, emptyComposer)
  if not action then return false end
  if action.press then return true, keyEvents(action.pressMods, action.press) end
  if action.section then
    local events = sectionKeyEvents(focused, action.section)
    if not events then return true end
    return true, events
  end
  if action.key then
    local dir = action.key == "down" and 1 or -1
    -- サイドバーをスクロールして選択中の行が画面外に出た（フォーカスが外れた場合も含む）ら、画面内の行から選び直す
    local sidebarScrolledAway = pane == "sidebar" and visibleHeightOf(focused) < MIN_VISIBLE_ROW_HEIGHT
    local sidebarFocusLost = pane == nil and lastScrollPane == "sidebar" and not messageItemOf(focused)
    if sidebarScrolledAway or sidebarFocusLost then
      local outline = sidebarScrolledAway and outlineOf(focused) or lastScrollList
      local events = outline and sidebarReentryEvents(outline, dir)
      if events then
        lastArrowAt = hs.timer.secondsSinceEpoch()
        return true, events
      end
      -- フォーカスが外れたまま矢印キーを送ると真ん中のペインがスクロールしてしまうので捨てる
      return true
    end
    if pane ~= "sidebar" and moveMessage(appEl, focused, dir) then return true end
    lastArrowAt = hs.timer.secondsSinceEpoch()
    guardArrow(appEl, focused)
    return true, keyEvents(action.mods, action.key)
  end
  if action.cycleLink then return cycleLink(focused, action.cycleLink) end
  if action.openThread then return openThread(focused) end

  if action.focus then
    lastScrollPane, lastScrollList = nil, nil
    local win = appEl:attributeValue("AXFocusedWindow")
    if not win then return false end
    local function run()
      if action.focus == "sidebar" then focusSidebar(win)
      elseif action.focus == "input" then focusInput(win, focused)
      elseif action.waitForInput then focusMessagesWhenLoaded(win, CHANNEL_SWITCH_MAX_POLLS)
      else focusMessages(win) end
    end
    -- ツリー探索は重いので、イベントタップのコールバック外で実行する
    hs.timer.doAfter(action.passthrough and ESCAPE_FOCUS_DELAY or 0, function()
      if action.waitForInput then waitForInputThen(appEl, run, CHANNEL_SWITCH_MAX_POLLS) else run() end
    end)
    return not action.passthrough
  end

  -- スクロールでフォーカスが外れた後も、同じ一覧をスクロールし続ける
  local point = scrollPoint or lastScrollPoint or fallbackScrollPoint(app)
  if scrollPoint then
    lastScrollPane = pane
    local item = messageItemOf(focused)
    lastScrollList = pane == "sidebar" and outlineOf(focused) or (item and item:attributeValue("AXParent"))
  end
  if not point then return false end
  scrollAt(point, action.scroll)
  return true
end

-- 再度 dofile したときに前のタップを止められるようグローバルに保持する
function M.start()
  if slackVimTap then slackVimTap:stop() end
  slackVimTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, onKeyDown)
  slackVimTap:start()
end

-- 自己チェック: Hammerspoon 外で `lua slack_vim.lua` を実行する
if not hs then
  local function same(a, b)
    a, b = a or {}, b or {}
    return a.key == b.key and a.scroll == b.scroll and a.focus == b.focus and a.passthrough == b.passthrough
      and a.openThread == b.openThread and a.cycleLink == b.cycleLink and a.waitForInput == b.waitForInput
      and a.section == b.section and a.press == b.press
      and table.concat(a.pressMods or {}, "+") == table.concat(b.pressMods or {}, "+")
  end
  local cases = {
    { "j", false, "AXTextArea", nil, nil },
    { "j", false, "AXTextField", "sidebar", nil },
    { "j", false, nil, nil, nil },
    { "h", false, "AXTextArea", nil, { focus = "sidebar" }, true }, -- 入力欄でも Ctrl+h/l でペインを移る
    { "l", false, "AXTextArea", nil, { focus = "messages" }, true },
    { "h", false, "AXTextArea", "thread", { focus = "messages" }, true },
    -- 入力欄の Ctrl+j/k はメンション・検索などの候補の選択移動（空のメッセージ入力欄の ↑ は直前の投稿の編集になるので送らない）
    { "j", false, "AXTextArea", nil, { press = "down" }, true },
    { "k", false, "AXTextArea", nil, { press = "up" }, true },
    { "k", false, "AXTextArea", nil, nil, true, true },
    -- f で検索（Cmd+G）
    { "f", false, "AXGroup", nil, { press = "g", pressMods = { "cmd" } } },
    { "f", false, "AXRow", "sidebar", { press = "g", pressMods = { "cmd" } } },
    { "f", false, "AXTextArea", nil, nil },
    { "f", true, "AXGroup", nil, nil },
    { "j", false, "AXGroup", nil, { key = "down" } },
    { "k", false, "AXGroup", nil, { key = "up" } },
    { "j", true, "AXGroup", nil, { scroll = 1 } },
    { "k", true, "AXGroup", nil, { scroll = -1 } },
    { "j", false, "AXRow", "sidebar", { key = "down" } },
    { "k", false, "AXRow", "sidebar", { key = "up" } },
    { "j", true, "AXRow", "sidebar", { scroll = 1 } },
    { "k", true, "AXRow", "sidebar", { scroll = -1 } },
    { "j", false, "AXRow", "sidebar", { section = 1 }, true },
    { "k", false, "AXRow", "sidebar", { section = -1 }, true },
    -- 候補の選択中は Slack が候補の項目（AXStaticText）にフォーカスを移すので、入力欄の外でも Ctrl+j/k は ↓/↑
    { "j", false, "AXStaticText", nil, { press = "down" }, true },
    { "k", false, "AXGroup", nil, { press = "up" }, true },
    { "h", false, "AXRow", "sidebar", { focus = "sidebar" }, true },
    { "j", false, "AXTextArea", nil, { press = "down" }, true },
    { "h", false, "AXGroup", nil, { focus = "sidebar" }, true },
    { "l", false, "AXRow", "sidebar", { focus = "messages" }, true },
    { "h", false, "AXGroup", nil, nil }, -- ペイン移動は Ctrl+h/l だけ
    { "l", false, "AXRow", "sidebar", nil },
    { "a", false, "AXGroup", nil, nil },
    { "escape", false, "AXTextArea", nil, { focus = "messages", passthrough = true } },
    { "escape", false, "AXTextField", nil, { focus = "messages", passthrough = true } },
    { "escape", false, "AXGroup", nil, nil },
    { "escape", false, nil, nil, nil },
    { "return", false, "AXGroup", nil, { openThread = true } },
    { "return", false, "AXTextArea", nil, nil },
    { "return", false, "AXRow", "sidebar", { focus = "messages", passthrough = true, waitForInput = true } },
    { "return", true, "AXGroup", nil, nil },
    { "h", false, "AXGroup", "thread", { focus = "messages" }, true },
    { "j", false, "AXGroup", "thread", { key = "down" } },
    { "j", true, "AXGroup", "thread", { scroll = 1 } },
    { "i", false, "AXGroup", nil, { focus = "input" } },
    { "i", false, "AXRow", "sidebar", { focus = "input" } },
    { "i", false, "AXTextArea", nil, nil },
    { "i", true, "AXGroup", nil, nil },
    { "tab", false, "AXGroup", nil, { cycleLink = 1 } },
    { "tab", true, "AXLink", nil, { cycleLink = -1 } },
    { "tab", false, "AXTextArea", nil, nil },
    { "tab", false, "AXRow", "sidebar", nil },
  }
  assert(M.isMessageId("message-list_1792484052.356979"))
  assert(M.isMessageId("C01UPDXPLPN-1792822708.986999-thread-list-Thread_1792822859.856049"))
  assert(M.isMessageId("threads_view_root-C0820JC79L2-1792736015.782369"))
  assert(not M.isMessageId("message-list_1792422000000.C01LSV3E8F3"))
  assert(not M.isMessageId("C01UPDXPLPN-1792822708.986999-thread-list-Thread_input"))
  assert(not M.isMessageId("threads_view_heading-C0820JC79L2-1792736015.782369"))
  assert(not M.isMessageId("threads_view_footer-C0820JC79L2-1792736015.782369"))
  assert(M.threadKey("threads_view_root-C0820JC79L2-1792736015.782369") == "C0820JC79L2-1792736015.782369")
  assert(M.threadKey("threads_view_C0820JC79L2-1792736015.782369-1792841681.776799") == "C0820JC79L2-1792736015.782369")
  assert(M.threadKey("threads_view_footer-D01U6FLSJ4Q-1792736015.782369") == "D01U6FLSJ4Q-1792736015.782369")
  assert(M.threadKey("message-list_1792484052.356979") == nil)
  -- サイドバーを上から並べたときに各行がセクション見出しかどうか（static, static, 見出しA, ch, ch, 見出しB, 見出しC, ch）
  local headings = { false, false, true, false, false, true, true, false }
  assert(M.headingSteps(headings, 1, 1) == 2)
  assert(M.headingSteps(headings, 3, 1) == 3)
  assert(M.headingSteps(headings, 7, 1) == nil)
  assert(M.headingSteps(headings, 5, -1) == -2) -- セクション内のチャンネルからはその見出しへ
  assert(M.headingSteps(headings, 6, -1) == -3)
  assert(M.headingSteps(headings, 3, -1) == nil)
  local ids = { "message-list_1.1", "message-list_2.2", "message-list_bottomSpacer" }
  assert(M.nextMessageIndex(ids, 1, 1) == 2)
  assert(M.nextMessageIndex(ids, 2, 1) == nil)
  assert(M.nextMessageIndex(ids, 2, -1) == 1)
  assert(M.nextMessageIndex(ids, 1, -1) == nil)
  local thread = { "C1-1.1-thread-list-Thread_1.1", "C1-1.1-thread-list-Thread_2.2", "C1-1.1-thread-list-Thread_input" }
  assert(M.nextMessageIndex(thread, 2, 1) == nil)
  local threadsView = {
    "threads_view_C1-1.1-2.2", "threads_view_footer-C1-1.1", "threads_view_heading-C2-3.3", "threads_view_root-C2-3.3",
  }
  assert(M.nextMessageIndex(threadsView, 1, 1) == 4)
  assert(M.nextMessageIndex(threadsView, 4, -1) == 1)
  -- AX が返す矩形はスクロール領域で切り取られ、画面外の投稿は高さ 1 になる
  local heights = { 1, 149, 178, 1, 1 }
  local all = { "message-list_1.1", "message-list_2.2", "message-list_3.3", "message-list_4.4", "message-list_5.5" }
  assert(M.isVisible(149) and not M.isVisible(1) and not M.isVisible(20))
  assert(M.visibleMessageIndex(all, heights, 1) == 2)
  assert(M.visibleMessageIndex(all, heights, -1) == 3)
  assert(M.visibleMessageIndex({ "message-list_1.1", "message-list_bottomSpacer" }, { 100, 200 }, -1) == 1)
  assert(M.visibleMessageIndex(all, { 1, 1, 1, 1, 1 }, 1) == nil)
  assert(M.visibleRowIndex({ 1, 1, 20, 40, 40, 1 }, 1) == 4)
  assert(M.visibleRowIndex({ 1, 1, 20, 40, 40, 1 }, -1) == 5)
  assert(M.visibleRowIndex({ 1, 1 }, 1) == nil)
  local anchorIds = { "threads_view_C1-1.1-2.2", "threads_view_footer-C1-1.1", "threads_view_heading-C2-3.3", "threads_view_root-C2-3.3" }
  local anchor, anchorDir = M.anchorIndex(anchorIds, 4)
  assert(anchor == 1 and anchorDir == 1) -- 手前の投稿から下へ（見出し・返信欄は矢印キーで通過する）
  anchor, anchorDir = M.anchorIndex(anchorIds, 1)
  assert(anchor == 4 and anchorDir == -1) -- 手前になければ後ろの投稿から上へ
  assert(M.anchorIndex({ "message-list_1.1" }, 1) == nil)
  for i, c in ipairs(cases) do
    assert(same(M.decide(c[1], c[2], c[3], c[4], c[6] == true, c[7] == true), c[5]),
      ("case %d failed: %s shift=%s %s %s ctrl=%s"):format(i, c[1], c[2], c[3], c[4], c[6]))
  end
  print("ok")
  return M
end

return M
