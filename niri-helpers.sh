#!/usr/bin/env bash
# Snapshot-based helpers for niri window management
# Intended to be sourced, not executed
#
# Call niri_init once to pre-fetch window/workspace/output state. Without it,
# each query function issues its own niri IPC request.

# App launcher used by niri_focus_or_spawn; override before sourcing if needed
NIRI_APP_LAUNCHER="${NIRI_APP_LAUNCHER:-uwsm-app}"

# -------------------------------------------------------------------
# Snapshot
# -------------------------------------------------------------------

# Pre-fetch all snapshots. Call this once at script start to avoid
# multiple IPC round-trips when using several query functions.
niri_init() {
  local windows workspaces outputs

  windows=$(niri msg --json windows) || return $?
  workspaces=$(niri msg --json workspaces) || return $?
  outputs=$(niri msg --json outputs) || return $?

  _NIRI_WINDOWS=$windows
  _NIRI_WORKSPACES=$workspaces
  _NIRI_OUTPUTS=$outputs
}

# Snapshot accessors. Return the pre-fetched snapshot if niri_init was
# called, otherwise fetch fresh from niri IPC.
#
# Don't add a write-back here: callers use subshells to capture the JSON, so
# the assignment would be discarded. Only niri_init can fill the cache.
niri_windows_json() {
  if [[ ${_NIRI_WINDOWS+x} ]]; then
    printf '%s\n' "$_NIRI_WINDOWS"
  else
    niri msg --json windows
  fi
}

niri_workspaces_json() {
  if [[ ${_NIRI_WORKSPACES+x} ]]; then
    printf '%s\n' "$_NIRI_WORKSPACES"
  else
    niri msg --json workspaces
  fi
}

niri_outputs_json() {
  if [[ ${_NIRI_OUTPUTS+x} ]]; then
    printf '%s\n' "$_NIRI_OUTPUTS"
  else
    niri msg --json outputs
  fi
}

# -------------------------------------------------------------------
# Internal helpers
# -------------------------------------------------------------------

# Send a niri action to each window ID read from stdin.
# Attempt every ID and return 1 if any action fails.
# Usage: _niri_message_to_ids <action>
_niri_message_to_ids() {
  local action="$1"
  local id status=0
  while IFS= read -r id; do
    if ! niri msg action "$action" --id "$id"; then
      status=1
      printf 'niri-helpers: %s failed for window %s\n' "$action" "$id" >&2
    fi
  done
  return "$status"
}

# -------------------------------------------------------------------
# Query primitives
# -------------------------------------------------------------------

# Return true if the given window ID is currently focused
niri_is_window_focused() {
  local window_id="$1"
  local windows
  windows=$(niri_windows_json) || return $?

  jq -e --argjson wid "$window_id" '
    any(.id == $wid and .is_focused)
  ' <<< "$windows" > /dev/null
}

# Return the ID of the focused window
niri_focused_window_id() {
  local windows
  windows=$(niri_windows_json) || return $?
  jq -r '.[] | select(.is_focused) | .id' <<< "$windows"
}

# Return the ID of the focused workspace
# Read from the workspaces snapshot so it still works on an empty workspace,
# where no window is focused.
niri_focused_workspace_id() {
  local workspaces
  workspaces=$(niri_workspaces_json) || return $?
  jq -r '.[] | select(.is_focused) | .id' <<< "$workspaces"
}

# Return all windows on a workspace as streamed JSON objects
# If no workspace ID is given, defaults to the focused workspace
niri_windows_on_workspace() {
  local ws_id="${1:-}"
  local windows

  if [[ -z "$ws_id" ]]; then
    ws_id=$(niri_focused_workspace_id) || return $?
  fi

  windows=$(niri_windows_json) || return $?
  jq -c --argjson ws "$ws_id" '.[] | select(.workspace_id == $ws)' <<< "$windows"
}

# Return tiled windows on a workspace in scrolling-layout order.
# If no workspace ID is given, defaults to the focused workspace.
niri_tiled_windows_on_workspace_sorted() {
  local windows
  windows=$(niri_windows_on_workspace "$@") || return $?
  jq -s '
    map(select(.is_floating | not))
    | sort_by([
        .layout.pos_in_scrolling_layout[0],
        .layout.pos_in_scrolling_layout[1]
      ])
    | .[]
  ' <<< "$windows"
}

# Return windows matching a pattern in app_id or title as streamed JSON objects
niri_windows_matching() {
  local pattern="$1"
  local windows
  windows=$(niri_windows_json) || return $?

  jq -c --arg p "$pattern" '
    .[]
    | select(
        (.app_id // "" | test($p; "i")) or
        (.title  // "" | test($p; "i"))
      )
  ' <<< "$windows"
}

# -------------------------------------------------------------------
# Window actions
# -------------------------------------------------------------------

# Close all windows
niri_close_all_windows() {
  local windows ids
  windows=$(niri_windows_json) || return $?
  ids=$(jq -r '.[].id' <<< "$windows") || return $?
  if [[ -n "$ids" ]]; then
    _niri_message_to_ids close-window <<< "$ids"
  fi
}

# Close all windows on a workspace (default: focused workspace)
niri_close_all_on_workspace() {
  local windows ids
  windows=$(niri_windows_on_workspace "$@") || return $?
  ids=$(jq -r '.id' <<< "$windows") || return $?
  if [[ -n "$ids" ]]; then
    _niri_message_to_ids close-window <<< "$ids"
  fi
}

# Close all unfocused windows on a workspace (default: focused workspace)
niri_close_unfocused_on_workspace() {
  local windows ids
  windows=$(niri_windows_on_workspace "$@") || return $?
  ids=$(jq -r 'select(.is_focused | not) | .id' <<< "$windows") || return $?
  if [[ -n "$ids" ]]; then
    _niri_message_to_ids close-window <<< "$ids"
  fi
}

# Close all windows matching a pattern
niri_close_matching() {
  local pattern="$1"
  local windows ids
  windows=$(niri_windows_matching "$pattern") || return $?
  ids=$(jq -r '.id' <<< "$windows") || return $?
  if [[ -n "$ids" ]]; then
    _niri_message_to_ids close-window <<< "$ids"
  fi
}

# Focus an existing window matching a pattern, or spawn a new process
niri_focus_or_spawn() {
  local pattern="$1"
  shift

  local window_id
  # -s slurps the whole stream so first() can't close the pipe early and
  # hand jq a SIGPIPE under `set -o pipefail`
  window_id="$(set -o pipefail; niri_windows_matching "$pattern" | jq -r -s 'first(.[]).id // empty')" || return $?

  if [[ -n "$window_id" ]]; then
    niri msg action focus-window --id "$window_id"
  else
    # unquoted on purpose: launcher may include args
    $NIRI_APP_LAUNCHER -- "$@" &
  fi
}

# -------------------------------------------------------------------
# Named workspace navigation
# -------------------------------------------------------------------

# Return the name of the focused workspace (empty if unnamed)
niri_focused_workspace_name() {
  local workspaces
  workspaces=$(niri_workspaces_json) || return $?
  jq -r '.[] | select(.is_focused) | .name // empty' <<< "$workspaces"
}

# Return workspace JSON object(s) matching a name
niri_workspace_by_name() {
  local name="$1"
  local workspaces
  workspaces=$(niri_workspaces_json) || return $?
  jq -c --arg n "$name" '.[] | select(.name == $n)' <<< "$workspaces"
}

# -------------------------------------------------------------------
# Output-aware operations
# -------------------------------------------------------------------

# Return the name of the focused output
niri_focused_output() {
  local workspaces
  workspaces=$(niri_workspaces_json) || return $?
  jq -r '.[] | select(.is_focused) | .output' <<< "$workspaces"
}

# Return all workspaces on an output as streamed JSON objects
niri_workspaces_on_output() {
  local output="$1"
  local workspaces
  workspaces=$(niri_workspaces_json) || return $?
  jq -c --arg out "$output" '.[] | select(.output == $out)' <<< "$workspaces"
}

# Return all windows on an output as streamed JSON objects
niri_windows_on_output() {
  local output="$1"
  local windows workspaces
  windows=$(niri_windows_json) || return $?
  workspaces=$(niri_workspaces_json) || return $?
  jq -cn \
    --argjson wins "$windows" \
    --argjson ws "$workspaces" \
    --arg out "$output" '
      ([$ws[] | select(.output == $out) | .id]) as $ws_ids
      | $wins[]
      | select(.workspace_id as $wid | $ws_ids | any(. == $wid))
    '
}
