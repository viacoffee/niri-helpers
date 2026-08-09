#!/usr/bin/env bash
# Fuzzy window switcher — pick any open window from a menu and focus it.
#
# Uses fuzzel in dmenu mode by default. To use a different launcher, replace
# the fuzzel call with: rofi -dmenu, wofi --dmenu, dmenu, etc. The input is
# tab-separated "id\tdisplay_label", so preserve --with-nth=2 (or equivalent)
# to show only the label column to the user.
set -euo pipefail

source "$(dirname "$(realpath "$0")")/../niri-helpers.sh"

niri_init

# Build tab-separated list: "id\t[ws_idx]  app_id: title"
# Focused window sorted first and marked with *.
entries="$(jq -r --argjson ws "$(niri_workspaces_json)" '
  ($ws | map({(.id | tostring): .idx}) | add) as $ws_map
  | sort_by(.is_focused | not)
  | .[]
  | ($ws_map[.workspace_id | tostring] // "?") as $idx
  | (if .is_focused then "* " else "  " end) as $mark
  | "\(.id)\t\($mark)[\($idx)]  \(.app_id // "unknown"): \(.title // "untitled")"
' <<< "$(niri_windows_json)")"

[[ -z "$entries" ]] && exit 0

selected="$(echo "$entries" \
  | fuzzel -d --width=65 --lines=10 --placeholder=' Switch to window...' --no-sort --with-nth=2 \
  || true)"

[[ -z "$selected" ]] && exit 0

niri msg action focus-window --id "$(cut -f1 <<< "$selected")"
