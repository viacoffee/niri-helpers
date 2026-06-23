#!/usr/bin/env bash
# Print a summary of the current niri session: focused output and workspace,
# then all workspaces on the focused output with their open windows.
#
# Useful as a starting point for status bar scripts, debugging, or exploring
# the niri-helpers query functions.
set -euo pipefail

source "$(dirname "$(realpath "$0")")/../niri-helpers.sh"

niri_init

focused_output="$(niri_focused_output)"
focused_ws_name="$(niri_focused_workspace_name)"

echo "Output:    $focused_output"
echo "Workspace: ${focused_ws_name:-<unnamed>}"
echo

niri_workspaces_on_output "$focused_output" | while read -r ws; do
  ws_id="$(jq -r '.id' <<< "$ws")"
  ws_idx="$(jq -r '.idx' <<< "$ws")"
  ws_name="$(jq -r '.name // ""' <<< "$ws")"
  is_focused="$(jq -r '.is_focused' <<< "$ws")"

  label="[$ws_idx]"
  [[ -n "$ws_name" ]] && label="$label $ws_name"
  [[ "$is_focused" = "true" ]] && label="* $label" || label="  $label"
  echo "$label"

  niri_windows_on_workspace "$ws_id" | \
    jq -r '"    \(.app_id // "?"): \(.title // "?")"'
done

# List any named workspaces across all outputs
named="$(jq -r '.[] | select(.name != null) | "  \(.name) → [\(.idx)] on \(.output)"' \
  <<< "$_NIRI_WORKSPACES")"

if [[ -n "$named" ]]; then
  echo
  echo "Named workspaces:"
  echo "$named"
fi
