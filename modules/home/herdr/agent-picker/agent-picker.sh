#!/usr/bin/env bash
# Fuzzy picker over herdr's workspaces, tabs, and agents.
#
# herdr's built-in navigator lists workspace -> tab -> agent, but never the
# agent's terminal title. With several Claude panes open that title is the only
# thing telling them apart, so this picker leads with it.
#
# Rows are built from `herdr workspace|tab|agent list` and piped through fzf;
# the selection is dispatched back through the matching `herdr ... focus`.
set -euo pipefail

readonly SELF="${BASH_SOURCE[0]}"

# Field separator for row payloads. Tab is safe here because herdr labels come
# from workspace/tab names and terminal titles, none of which can contain one.
readonly SEP=$'\t'

die() {
  printf 'agent-picker: %s\n' "$*" >&2
  exit 1
}

require() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

# Emit "<kind> <id> <status> <label> <meta>" rows, tab separated. The caller
# keeps the first two fields for dispatch and renders the rest.
collect_rows() {
  local ws_json tab_json agent_json ws_labels

  ws_json="$(herdr workspace list 2>/dev/null)" ||
    die 'herdr workspace list failed; is the server running?'
  tab_json="$(herdr tab list 2>/dev/null)" || tab_json=''
  agent_json="$(herdr agent list 2>/dev/null)" || agent_json=''

  # Workspace labels caption the tab and agent rows, so they are resolved once
  # here and joined inside jq rather than re-queried per row.
  ws_labels="$(printf '%s' "$ws_json" | jq -c '
    [.result.workspaces[] | {key: .workspace_id, value: .label}] | from_entries
  ')"

  printf '%s' "$ws_json" | jq -r --arg sep "$SEP" '
    .result.workspaces[]
    | [ "workspace",
        .workspace_id,
        (.agent_status // "unknown"),
        .label,
        ((.tab_count | tostring) + " tabs, " + (.pane_count | tostring) + " panes")
      ] | join($sep)
  '

  if [ -n "$tab_json" ]; then
    printf '%s' "$tab_json" | jq -r --arg sep "$SEP" --argjson ws "$ws_labels" '
      .result.tabs[]
      | [ "tab",
          .tab_id,
          (.agent_status // "unknown"),
          (($ws[.workspace_id] // .workspace_id) + " / " + .label),
          ((.pane_count | tostring) + " panes")
        ] | join($sep)
    '
  fi

  if [ -n "$agent_json" ]; then
    # terminal_title_stripped is the whole point of this picker: it is the only
    # field describing what an agent is actually doing. Agents that have not set
    # a title fall back to their cwd basename.
    printf '%s' "$agent_json" | jq -r --arg sep "$SEP" --argjson ws "$ws_labels" '
      .result.agents[]
      | ((.terminal_title_stripped // "") | gsub("^\\s+|\\s+$"; "")) as $title
      | (if $title == "" then ((.cwd // "/") | split("/") | last) else $title end) as $label
      | [ "agent",
          .pane_id,
          (.agent_status // "unknown"),
          (($ws[.workspace_id] // .workspace_id) + " / " + $label),
          .agent
        ] | join($sep)
    '
  fi
}

# Width of the label column, in terminal cells. Exported rather than readonly so
# the formatter below can receive it as an environment variable.
LABEL_WIDTH=52
export LABEL_WIDTH

# Render rows for display, keeping the dispatch prefix intact for fzf.
#
# This is Python rather than shell because the label column has to be padded by
# display width: shell printf pads by bytes and macOS awk indexes by bytes, so
# both misalign every row containing CJK -- which is most of them, since Claude
# titles are usually Japanese. unicodedata gives the real cell count.
format_rows() {
  python3 -c '
import os, sys, unicodedata

WIDTH = int(os.environ["LABEL_WIDTH"])
RESET = "\033[0m"
TAGS = {
    "workspace": ("\033[1;35m", "WS "),
    "tab":       ("\033[36m",   "TAB"),
    "agent":     ("\033[33m",   "AGT"),
}
ICONS = {
    "working": ("\033[33m", "*"),
    "idle":    ("\033[32m", "*"),
    "done":    ("\033[36m", "*"),
    "blocked": ("\033[31m", "!"),
}

def cells(text):
    return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in text)

def pad(text, width):
    out, used = [], 0
    for ch in text:
        w = 2 if unicodedata.east_asian_width(ch) in "WF" else 1
        if used + w > width - 1:
            out.append("~")
            used += 1
            break
        out.append(ch)
        used += w
    return "".join(out) + " " * max(0, width - used)

for line in sys.stdin:
    parts = line.rstrip("\n").split("\t")
    if len(parts) < 5:
        continue
    kind, ident, status, label, meta = parts[:5]
    tag_color, tag_text = TAGS.get(kind, ("", "   "))
    icon_color, icon_text = ICONS.get(status, ("\033[90m", "-"))
    sys.stdout.write(
        f"{kind}\t{ident}\t{tag_color}{tag_text}{RESET} "
        f"{icon_color}{icon_text}{RESET} {pad(label, WIDTH)} "
        f"\033[90m{meta}{RESET}\n"
    )
'
}

cmd_list() {
  collect_rows | format_rows
}

# Agent-only view, for the toggle bound below.
cmd_list_agents() {
  collect_rows | awk -F'\t' '$1 == "agent"' | format_rows
}

# Dispatch a chosen row. Exposed as a subcommand so fzf can call back into this
# same script for reload and preview without duplicating the mapping.
cmd_focus() {
  local kind="${1:-}" id="${2:-}"
  [ -n "$kind" ] && [ -n "$id" ] || die 'focus requires <kind> <id>'

  case "$kind" in
    workspace) herdr workspace focus "$id" >/dev/null ;;
    tab)       herdr tab focus "$id" >/dev/null ;;
    agent)     herdr agent focus "$id" >/dev/null ;;
    *)         die "unknown row kind: $kind" ;;
  esac
}

# Preview pane: recent output for agents, structure for the rest.
cmd_preview() {
  local kind="${1:-}" id="${2:-}"
  case "$kind" in
    agent) herdr agent read "$id" --lines 40 2>/dev/null || echo '(no output)' ;;
    tab)   herdr tab get "$id" 2>/dev/null | jq . 2>/dev/null || echo '(no detail)' ;;
    *)     herdr workspace get "$id" 2>/dev/null | jq . 2>/dev/null || echo '(no detail)' ;;
  esac
}

# The "open" action is what a keybinding invokes, and herdr runs actions
# headless -- no terminal is attached, so fzf would have nowhere to draw and the
# process would hang forever. Actions therefore only ask herdr to open the pane
# entrypoint, which does get a real terminal; cmd_ui is what actually renders.
cmd_open() {
  exec herdr plugin pane open \
    --plugin agent-picker \
    --entrypoint picker \
    --placement overlay >/dev/null
}

cmd_ui() {
  require fzf
  require jq

  local self selection kind id
  self="$(printf '%q' "$SELF")"

  # --with-nth=3.. hides the dispatch prefix while leaving it in the output.
  # ctrl-a swaps the source to agents only and ctrl-s swaps it back, which is
  # cheaper than filtering on the tag text and keeps the counter honest.
  selection="$(
    cmd_list | fzf \
      --ansi \
      --delimiter="$SEP" \
      --with-nth='3..' \
      --prompt='herdr > ' \
      --header='[enter] focus  [ctrl-a] agents only  [ctrl-s] show all  [ctrl-r] reload  [ctrl-/] preview' \
      --info=inline \
      --layout=reverse \
      --border=rounded \
      --height=100% \
      --preview="$self preview {1} {2}" \
      --preview-window='right,50%,border-left,wrap,hidden' \
      --bind="ctrl-/:toggle-preview" \
      --bind="ctrl-a:change-prompt(agents > )+reload($self list-agents)" \
      --bind="ctrl-s:change-prompt(herdr > )+reload($self list)" \
      --bind="ctrl-r:reload($self list)"
  )" || exit 0

  [ -n "$selection" ] || exit 0

  IFS="$SEP" read -r kind id _ <<<"$selection"
  cmd_focus "$kind" "$id"
}

main() {
  case "${1:-open}" in
    open)        cmd_open ;;
    ui)          cmd_ui ;;
    list)        cmd_list ;;
    list-agents) cmd_list_agents ;;
    preview)     shift; cmd_preview "$@" ;;
    focus)       shift; cmd_focus "$@" ;;
    *)           die "unknown subcommand: ${1:-}" ;;
  esac
}

main "$@"
