-- ブラウザを vim 風に操作する（j/k: Google 検索結果の選択移動（それ以外のページではスクロール）、Shift+J/K: スクロール、
-- 入力欄の Ctrl+j/k: 検索候補の選択移動、Ctrl+h/l: Dia のサイドバー（タブ一覧）とページの行き来、タブ一覧の d: タブを閉じる）
local M = {}

local BROWSER_BUNDLE_IDS = { ["com.google.Chrome"] = true, ["company.thebrowser.dia"] = true }
local TEXT_ROLES = { AXTextArea = true, AXTextField = true, AXComboBox = true, AXSearchField = true }
-- 1 回のスクロールで送る矢印キーの回数
local SCROLL_KEY_REPEAT = 3
local MAX_ANCESTOR_DEPTH = 40
local MAX_SEARCH_DEPTH = 40
-- 候補を探すときにたどる要素数の上限（巨大なページで固まらないように）
local MAX_SEARCH_NODES = 5000
-- 要素の見えている部分がこの高さ（px）以上なら画面内とみなす（AX の矩形はスクロール領域で切り取られ、画面外は高さ 1 になる）
local MIN_VISIBLE_HEIGHT = 10
-- AX でフォーカスを移すときの応答待ち（秒）。Chromium はフォーカス変更の応答が遅く、既定値だと Hammerspoon が数秒固まる。
-- 応答を待たなくてもフォーカスは移る
local FOCUS_TIMEOUT = 0.1
-- フォーカスしたリンクがスクロールで画面内に入るのを待ってから枠を描き直す（秒）
local LINK_HIGHLIGHT_REDRAW_DELAY = 0.2
-- www.google.com / www.google.co.jp / www.google.com.au など
local GOOGLE_HOST_PATTERNS = { "^www%.google%.%a+$", "^www%.google%.co%.%a+$", "^www%.google%.com%.%a+$" }
local GOOGLE_SEARCH_PATH = "/search"
-- 通常の検索結果の見出し（h3）のクラス。動画・ニュース・X の投稿などのカードは別のクラスなので候補にしない
local RESULT_HEADING_CLASS = "LC20lb"
-- AI による概要の「もっと見る」ボタンのクラス。これも候補にする
local AI_OVERVIEW_MORE_CLASS = "Jzkafd"
local DIA_BUNDLE_ID = "company.thebrowser.dia"
-- Dia のサイドバーのタブは識別子が "tab" で始まる
local SIDEBAR_TAB_ID_PREFIX = "tab"
local HIGHLIGHT_COLOR = { red = 0.3, green = 0.6, blue = 1, alpha = 1 }
local HIGHLIGHT_WIDTH = 2
local HIGHLIGHT_RADIUS = 6
-- タブを閉じてからサイドバーの一覧を取り直すまでの待ち（秒）
local TAB_CLOSE_REFRESH_DELAY = 0.3

function M.isGoogleSearch(url)
  local host, path = url:match("^https?://([^/]+)(/[^?#]*)")
  if not host or path ~= GOOGLE_SEARCH_PATH then return false end
  for _, pattern in ipairs(GOOGLE_HOST_PATTERNS) do
    if host:match(pattern) then return true end
  end
  return false
end

-- スクロール { scroll = 1 | -1 }、リンクの選択移動 { select = 1 | -1 }、矢印キー { key = "down" | "up" }、
-- または nil（キーをそのまま通す）を返す
function M.decide(char, shift, editable, ctrl)
  local dir = ({ j = 1, k = -1 })[char]
  if not dir then return nil end
  if ctrl then return editable and { key = dir == 1 and "down" or "up" } or nil end
  if editable then return nil end
  if shift then return { scroll = dir } end
  return { select = dir }
end

-- 画面に映っている候補のうち、下方向なら一番上、上方向なら一番下の位置を返す
function M.visibleIndex(heights, dir)
  local from, to = 1, #heights
  if dir == -1 then from, to = #heights, 1 end
  for i = from, to, dir do
    if heights[i] >= MIN_VISIBLE_HEIGHT then return i end
  end
  return nil
end

-- 次に選ぶ候補の位置。選択中の候補が画面内なら隣、画面外（スクロールした後）や未選択なら画面内の端
function M.targetIndex(current, currentVisible, heights, dir)
  if current and currentVisible then
    local next = current + dir
    return heights[next] and next or nil
  end
  return M.visibleIndex(heights, dir)
end

-- サイドバーのタブのうち、ウィンドウタイトル（「プロファイル名: タブのタイトル」で長いと … で省略）に合うものの位置
function M.currentTabIndex(titles, windowTitle)
  if #titles == 0 then return nil end
  local shown = windowTitle:gsub("^[^:]*: ", "", 1):gsub("…$", "")
  for i, title in ipairs(titles) do
    if title:sub(1, #shown) == shown then return i end
  end
  return 1
end

function M.moveIndex(index, dir, count)
  return math.max(1, math.min(count, index + dir))
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

local function scrollEvents(dir)
  local events = {}
  for _ = 1, SCROLL_KEY_REPEAT do
    for _, ev in ipairs(keyEvents({}, dir == 1 and "down" or "up")) do table.insert(events, ev) end
  end
  return events
end

local function visibleHeightOf(el)
  local size = el:attributeValue("AXSize")
  return size and size.h or 0
end

local function webAreaOf(el)
  for _ = 1, MAX_ANCESTOR_DEPTH do
    if not el then return nil end
    if el:attributeValue("AXRole") == "AXWebArea" then return el end
    el = el:attributeValue("AXParent")
  end
  return nil
end

local function urlOf(webArea)
  local url = webArea:attributeValue("AXURL")
  if type(url) == "table" then url = url.url end
  return type(url) == "string" and url or ""
end

local function hasClass(el, name)
  for _, class in ipairs(el:attributeValue("AXDOMClassList") or {}) do
    if class == name then return true end
  end
  return false
end

-- Google の検索結果は見出し（h3.LC20lb）を含むリンク
local function isResultLink(el)
  for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
    if child:attributeValue("AXRole") == "AXHeading" and hasClass(child, RESULT_HEADING_CLASS) then return true end
  end
  return false
end

-- Google 検索結果ページの検索結果（と AI による概要の「もっと見る」）を文書順に集める。それ以外のページでは空
local function candidateLinks(webArea)
  local links, visited = {}, 0
  if not M.isGoogleSearch(urlOf(webArea)) then return links end
  local function walk(el, depth)
    visited = visited + 1
    if visited > MAX_SEARCH_NODES then return end
    local role = el:attributeValue("AXRole")
    if role == "AXLink" then
      if isResultLink(el) then table.insert(links, el) end
      return
    end
    if role == "AXButton" and hasClass(el, AI_OVERVIEW_MORE_CLASS) then
      table.insert(links, el)
      return
    end
    if depth <= 0 then return end
    for _, child in ipairs(el:attributeValue("AXChildren") or {}) do walk(child, depth - 1) end
  end
  walk(webArea, MAX_SEARCH_DEPTH)
  return links
end

local function frameOf(el)
  local pos, size = el:attributeValue("AXPosition"), el:attributeValue("AXSize")
  return pos and size and { x = pos.x, y = pos.y, w = size.w, h = size.h }
end

-- el の位置に枠を描く（canvas があれば動かす）。描いた canvas を返す
local function drawHighlight(canvas, el)
  local frame = frameOf(el)
  if not frame then return canvas end
  if canvas then return canvas:frame(frame) end
  return hs.canvas.new(frame):appendElements({
    type = "rectangle",
    action = "stroke",
    strokeColor = HIGHLIGHT_COLOR,
    strokeWidth = HIGHLIGHT_WIDTH,
    roundedRectRadii = { xRadius = HIGHLIGHT_RADIUS, yRadius = HIGHLIGHT_RADIUS },
  }):show()
end

-- マウス操作の後は AX でフォーカスしてもページのフォーカスリングが出ない（:focus-visible はキーボード操作の後だけ）ので、
-- 選んだリンクには Hammerspoon 側で枠を描く。スクロールすると位置がずれるので、j/k 以外の操作で消す
local linkCanvas = nil

local function clearLinkHighlight()
  if linkCanvas then linkCanvas:delete() end
  linkCanvas = nil
end

local function focusLink(link)
  link:setTimeout(FOCUS_TIMEOUT)
  link:setAttributeValue("AXFocused", true)
  linkCanvas = drawHighlight(linkCanvas, link)
  hs.timer.doAfter(LINK_HIGHLIGHT_REDRAW_DELAY, function()
    if linkCanvas then linkCanvas = drawHighlight(linkCanvas, link) end
  end)
end

local busy = false

-- 選択中のリンクから dir 方向の候補へ。候補がひとつもないページではスクロールする
local function selectLink(webArea, focused, dir)
  local links = candidateLinks(webArea)
  if #links == 0 then
    for _, ev in ipairs(scrollEvents(dir)) do ev:post() end
    return
  end
  local heights, current = {}, nil
  for i, link in ipairs(links) do
    heights[i] = visibleHeightOf(link)
    if link == focused then current = i end
  end
  local target = M.targetIndex(current, current and heights[current] >= MIN_VISIBLE_HEIGHT, heights, dir)
  if target then focusLink(links[target]) end
end

-- Dia のサイドバーはネイティブ UI で、AX でフォーカスを移すとフォーカスが消えてしまう。
-- そのため Hammerspoon 側で選択中のタブに枠を描き、Enter でそのタブを開く「サイドバーモード」として扱う
local sidebar = nil -- { tabs = { AX 要素 }, index = 選択中の位置, window = ウィンドウ, canvas = 枠 }

local function sidebarTabs(window)
  local tabs = {}
  local function walk(el, depth)
    if el:attributeValue("AXRole") == "AXWebArea" then return end
    local id = el:attributeValue("AXIdentifier") or ""
    if id:sub(1, #SIDEBAR_TAB_ID_PREFIX) == SIDEBAR_TAB_ID_PREFIX then
      table.insert(tabs, el)
      return
    end
    if depth <= 0 then return end
    for _, child in ipairs(el:attributeValue("AXChildren") or {}) do walk(child, depth - 1) end
  end
  walk(window, MAX_SEARCH_DEPTH)
  return tabs
end

local function tabTitle(tab)
  local function find(el, depth)
    if el:attributeValue("AXRole") == "AXStaticText" then return el:attributeValue("AXValue") end
    if depth <= 0 then return nil end
    for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
      local title = find(child, depth - 1)
      if title then return title end
    end
    return nil
  end
  return find(tab, MAX_ANCESTOR_DEPTH) or ""
end


local function showHighlight()
  sidebar.canvas = drawHighlight(sidebar.canvas, sidebar.tabs[sidebar.index])
end

local function focusPage(window)
  local function find(el, depth)
    if el:attributeValue("AXRole") == "AXWebArea" then return el end
    if depth <= 0 then return nil end
    for _, child in ipairs(el:attributeValue("AXChildren") or {}) do
      local found = find(child, depth - 1)
      if found then return found end
    end
    return nil
  end
  local webArea = find(window, MAX_ANCESTOR_DEPTH)
  if not webArea then return end
  webArea:setTimeout(FOCUS_TIMEOUT)
  webArea:setAttributeValue("AXFocused", true)
end

local function exitSidebar()
  if sidebar and sidebar.canvas then sidebar.canvas:delete() end
  sidebar = nil
end

local function enterSidebar(appEl)
  local window = appEl:attributeValue("AXFocusedWindow")
  local tabs = window and sidebarTabs(window) or {}
  local titles = {}
  for i, tab in ipairs(tabs) do titles[i] = tabTitle(tab) end
  local index = M.currentTabIndex(titles, window and window:attributeValue("AXTitle") or "")
  if not index then return end
  sidebar = { tabs = tabs, index = index, window = window }
  showHighlight()
end

-- サイドバーモード中のキー。戻り値は eventtap のコールバックと同じ（true でキーを捨てる）
-- el の中央を click（hs.eventtap.leftClick など）でクリックし、マウスの位置を戻す
local function clickCenter(el, click)
  local frame = frameOf(el)
  if not frame then return end
  local original = hs.mouse.absolutePosition()
  click({ x = frame.x + frame.w / 2, y = frame.y + frame.h / 2 })
  hs.mouse.absolutePosition(original)
end

local function onSidebarKey(char, flags)
  if (char == "j" or char == "k") and not (flags.ctrl or flags.shift) then
    sidebar.index = M.moveIndex(sidebar.index, char == "j" and 1 or -1, #sidebar.tabs)
    showHighlight()
    return true
  end
  if char == "return" then
    -- タブは AXPress を名乗るが実際には未対応（kAXErrorActionUnsupported）なので、クリックして開く
    local tab = sidebar.tabs[sidebar.index]
    exitSidebar()
    clickCenter(tab, hs.eventtap.leftClick)
    return true
  end
  if char == "d" and not (flags.ctrl or flags.shift) then
    -- 閉じるボタンは AX に出てこないので、中クリックで閉じる（開かずに閉じられる）
    clickCenter(sidebar.tabs[sidebar.index], hs.eventtap.otherClick)
    hs.timer.doAfter(TAB_CLOSE_REFRESH_DELAY, function()
      if not sidebar then return end
      sidebar.tabs = sidebarTabs(sidebar.window)
      if #sidebar.tabs == 0 then return exitSidebar() end
      sidebar.index = M.moveIndex(sidebar.index, 0, #sidebar.tabs)
      showHighlight()
    end)
    return true
  end
  local toPage = flags.ctrl and char == "l"
  local leave = toPage or char == "escape"
  local window = sidebar.window
  exitSidebar()
  -- ページに戻ったら j/k がすぐ効くよう、ページ本体にフォーカスを置く
  if toPage then hs.timer.doAfter(0, function() focusPage(window) end) end
  return leave
end

local function onKeyDown(e)
  local eventType = e:getType()
  -- クリック・スクロールしたらサイドバーモードとリンクの枠を消す
  if eventType == hs.eventtap.event.types.leftMouseDown or eventType == hs.eventtap.event.types.scrollWheel then
    exitSidebar()
    clearLinkHighlight()
    return false
  end
  local flags = e:getFlags()
  local char = hs.keycodes.map[e:getKeyCode()]
  if not ((char == "j" or char == "k") and not (flags.shift or flags.ctrl or flags.cmd or flags.alt)) then
    clearLinkHighlight()
  end
  local app = hs.application.frontmostApplication()
  if not app or not BROWSER_BUNDLE_IDS[app:bundleID()] then
    exitSidebar()
    return false
  end
  if sidebar then return onSidebarKey(char, flags) end
  if flags.cmd or flags.alt or flags.fn then return false end
  local ctrlH = flags.ctrl and char == "h"
  if char ~= "j" and char ~= "k" and not ctrlH then return false end
  -- 候補を探している途中の j/k は捨てる（押しっぱなしでも順に進む）
  if busy then return true end

  local appEl = hs.axuielement.applicationElement(app)
  -- Chromium はこれを立てないと Web ページの中身を AX に公開しない
  appEl:setAttributeValue("AXManualAccessibility", true)
  local focused = appEl:attributeValue("AXFocusedUIElement")
  local editable = focused ~= nil
    and (TEXT_ROLES[focused:attributeValue("AXRole")] or focused:attributeValue("AXEditableAncestor") ~= nil)
  if ctrlH then
    -- 入力欄の Ctrl+h（1 文字削除）はそのまま通す。サイドバーがあるのは Dia だけ
    if editable or app:bundleID() ~= DIA_BUNDLE_ID then return false end
    hs.timer.doAfter(0, function() enterSidebar(appEl) end)
    return true
  end
  -- フォーカス不明時は入力中の文字を食わないよう素通しする
  if not focused then return false end
  local webArea = not editable and webAreaOf(focused)
  -- アドレスバー以外のブラウザ UI（タブ・サイドバー等）にフォーカスがあるときも素通しする
  if not editable and not webArea then return false end
  local action = M.decide(char, flags.shift == true, editable, flags.ctrl == true)
  if not action then return false end
  if action.key then return true, keyEvents({}, action.key) end
  if action.scroll then return true, scrollEvents(action.scroll) end

  -- ページ全体をたどるので、イベントタップのコールバック外で実行する
  busy = true
  hs.timer.doAfter(0, function()
    local ok, err = pcall(selectLink, webArea, focused, action.select)
    -- 失敗しても j/k が捨てられ続けないよう、先に解除してからエラーを伝える
    busy = false
    if not ok then error(err) end
  end)
  return true
end

-- 再度 dofile したときに前のタップを止められるようグローバルに保持する
function M.start()
  if browserVimTap then browserVimTap:stop() end
  browserVimTap = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.scrollWheel,
  }, onKeyDown)
  browserVimTap:start()
end

-- 自己チェック: Hammerspoon 外で `lua browser_vim.lua` を実行する
if not hs then
  assert(M.isGoogleSearch("https://www.google.com/search?q=hammerspoon"))
  assert(M.isGoogleSearch("https://www.google.co.jp/search?q=a&hl=ja"))
  assert(not M.isGoogleSearch("https://www.google.com/maps/search/cafe"))
  assert(not M.isGoogleSearch("https://example.com/search?q=a"))
  assert(M.isGoogleSearch("https://www.google.com.au/search?q=a"))
  assert(not M.isGoogleSearch("https://www.google.com.evil.example/search?q=a"))
  assert(not M.isGoogleSearch(""))

  local function same(a, b)
    a, b = a or {}, b or {}
    return a.scroll == b.scroll and a.select == b.select and a.key == b.key
  end
  local cases = {
    { "j", false, true, nil },
    { "j", false, true, { key = "down" }, true }, -- 入力欄の Ctrl+j/k は候補の選択移動
    { "k", false, true, { key = "up" }, true },
    { "j", false, false, nil, true },
    { "j", false, false, { select = 1 } },
    { "k", false, false, { select = -1 } },
    { "j", true, false, { scroll = 1 } },
    { "k", true, false, { scroll = -1 } },
    { "h", false, false, nil },
  }
  for i, c in ipairs(cases) do
    assert(same(M.decide(c[1], c[2], c[3], c[5]), c[4]), ("case %d failed"):format(i))
  end

  -- targetIndex(選択中の位置, 選択中が画面内か, 各候補の見えている高さ, 向き)
  local heights = { 1, 1, 79, 79, 1 }
  assert(M.targetIndex(3, true, heights, 1) == 4) -- 画面内なら隣へ
  assert(M.targetIndex(3, true, heights, -1) == 2)
  assert(M.targetIndex(5, true, heights, 1) == nil) -- 末尾より先はない
  assert(M.targetIndex(1, false, heights, 1) == 3) -- 画面外なら画面内の端から
  assert(M.targetIndex(nil, false, heights, -1) == 4)
  assert(M.targetIndex(nil, false, { 1, 1 }, 1) == nil)
  -- Dia のウィンドウタイトルは「プロファイル名: タブのタイトル（長いと … で省略）」
  local titles = { "New Tab", "XユーザーのAikido Community Japanさん", "猫が部屋のドアを" }
  assert(M.currentTabIndex(titles, "Atrae: XユーザーのAikido Comm…") == 2)
  assert(M.currentTabIndex(titles, "Atrae: New Tab") == 1)
  assert(M.currentTabIndex(titles, "Atrae: 見つからない") == 1)
  assert(M.currentTabIndex({}, "Atrae: x") == nil)
  assert(M.moveIndex(1, -1, 3) == 1 and M.moveIndex(3, 1, 3) == 3 and M.moveIndex(2, 1, 3) == 3)
  assert(M.moveIndex(3, 0, 2) == 2) -- 末尾のタブを閉じたら新しい末尾へ
  print("ok")
  return M
end

return M
