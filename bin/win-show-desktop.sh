#!/usr/bin/env bash
# Show-desktop toggle for the Omarchy Windows-style taskbar.
#
# Every visible window is moved into a hidden special workspace; the original
# workspace of each window is remembered in a state file so a second run puts
# them all back where they were.

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy"
STATE_FILE="$STATE_DIR/winbar-desktop.json"
SPECIAL="special:winbar-min"

mkdir -p "$STATE_DIR"

# Second click: restore.
if [[ -s "$STATE_FILE" ]]; then
  jq -c '.[]?' "$STATE_FILE" 2>/dev/null | while IFS= read -r row; do
    addr=$(jq -r '.address // empty' <<<"$row" 2>/dev/null)
    ws=$(jq -r '.workspace // empty' <<<"$row" 2>/dev/null)
    [[ -n "$addr" && -n "$ws" ]] || continue
    hyprctl dispatch \
      "hl.dsp.window.move({ window = \"address:$addr\", workspace = \"$ws\", follow = false })" \
      >/dev/null 2>&1
  done
  rm -f "$STATE_FILE"
  exit 0
fi

# First click: minimise everything.
hyprctl clients -j 2>/dev/null | jq -c --arg special "$SPECIAL" \
  '[.[] | select((.workspace.name // "") != $special and (.workspace.id // 0) > 0)
      | { address: .address, workspace: (.workspace.id | tostring) }]' > "$STATE_FILE"

if [[ ! -s "$STATE_FILE" ]]; then
  rm -f "$STATE_FILE"
  exit 0
fi

jq -r '.[]? | .address // empty' "$STATE_FILE" 2>/dev/null | while IFS= read -r addr; do
  [[ -n "$addr" ]] || continue
  hyprctl dispatch \
    "hl.dsp.window.move({ window = \"address:$addr\", workspace = \"$SPECIAL\", follow = false })" \
    >/dev/null 2>&1
done
