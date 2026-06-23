#!/usr/bin/env bash
# Snapshot-based helpers for niri window management
# Intended to be sourced, not executed
#
# Call niri_init to pre-fetch window/workspace state once. All functions
# lazy-cache on first call if niri_init was not called explicitly.

# App launcher used by niri_focus_or_spawn; override before sourcing if needed
NIRI_APP_LAUNCHER="${NIRI_APP_LAUNCHER:-uwsm-app}"

# -------------------------------------------------------------------
# Snapshot
# -------------------------------------------------------------------

# Pre-fetch all snapshots. Call this once at script start to avoid
# multiple IPC round-trips when using several query functions.
niri_init() {
  _NIRI_WINDOWS=$(niri msg --json windows)
  _NIRI_WORKSPACES=$(niri msg --json workspaces)
  _NIRI_OUTPUTS=$(niri msg --json outputs)
}

# -------------------------------------------------------------------
# Internal helpers
# -------------------------------------------------------------------

# Lazy-cached snapshot accessors — fetch from niri IPC on first call,
# return the cached value on subsequent calls within the same process.
# Call niri_init upfront to pre-warm all three at once.
_niri_windows_json() {
  _NIRI_WINDOWS="${_NIRI_WINDOWS:-$(niri msg --json windows)}"
  echo "$_NIRI_WINDOWS"
}

_niri_workspaces_json() {
  _NIRI_WORKSPACES="${_NIRI_WORKSPACES:-$(niri msg --json workspaces)}"
  echo "$_NIRI_WORKSPACES"
}

_niri_outputs_json() {
  _NIRI_OUTPUTS="${_NIRI_OUTPUTS:-$(niri msg --json outputs)}"
  echo "$_NIRI_OUTPUTS"
}

# Extract .id from streamed JSON objects
_niri_extract_ids() {
  jq -r '.id'
}

# Send a niri action to each window ID read from stdin
# Usage: _niri_message_to_ids <action>
_niri_message_to_ids() {
  local action="$1"
  while read -r id; do
    niri msg action "$action" --id "$id"
  done
}

# -------------------------------------------------------------------
# Query primitives
# -------------------------------------------------------------------

# Return true if the given window ID is currently focused
niri_is_window_focused() {
  local window_id="$1"

  _niri_windows_json |
    jq -e --argjson wid "$window_id" '
      any(.id == $wid and .is_focused)
    ' > /dev/null
}

# Return the ID of the focused window
niri_focused_window_id() {
  _niri_windows_json |
    jq -r '.[] | select(.is_focused) | .id'
}

# Return the ID of the focused workspace
# Read from the workspaces snapshot so it still works on an empty workspace,
# where no window is focused.
niri_focused_workspace_id() {
  _niri_workspaces_json |
    jq -r '.[] | select(.is_focused) | .id'
}

# Return all windows on a workspace as streamed JSON objects
# If no workspace ID is given, defaults to the focused workspace
niri_windows_on_workspace() {
  local ws_id="${1:-}"

  if [[ -z "$ws_id" ]]; then
    ws_id="$(niri_focused_workspace_id)"
  fi

  _niri_windows_json |
    jq -c --argjson ws "$ws_id" '.[] | select(.workspace_id == $ws)'
}

# Return windows matching a pattern in app_id or title as streamed JSON objects
niri_windows_matching() {
  local pattern="$1"

  _niri_windows_json |
    jq -c --arg p "$pattern" '
      .[]
      | select(
          (.app_id // "" | test($p; "i")) or
          (.title  // "" | test($p; "i"))
        )
    '
}

# -------------------------------------------------------------------
# Window actions
# -------------------------------------------------------------------

# Close all windows
niri_close_all_windows() {
  _niri_windows_json |
    jq -r '.[].id' |
    _niri_message_to_ids close-window
}

# Close all windows on a workspace (default: focused workspace)
niri_close_all_on_workspace() {
  niri_windows_on_workspace "$@" |
    _niri_extract_ids |
    _niri_message_to_ids close-window
}

# Close all unfocused windows on a workspace (default: focused workspace)
niri_close_unfocused_on_workspace() {
  niri_windows_on_workspace "$@" |
    jq -r 'select(.is_focused | not) | .id' |
    _niri_message_to_ids close-window
}

# Close all windows matching a pattern
niri_close_matching() {
  local pattern="$1"
  niri_windows_matching "$pattern" |
    _niri_extract_ids |
    _niri_message_to_ids close-window
}

# Focus an existing window matching a pattern, or spawn a new process
niri_focus_or_spawn() {
  local pattern="$1"
  shift

  local window_id
  window_id="$(
    _niri_windows_json |
      jq -r --arg p "$pattern" '
        first(
          .[]
          | select(
              (.app_id // "" | test($p; "i")) or
              (.title  // "" | test($p; "i"))
            )
        ).id // empty
      '
  )"

  if [[ -n "$window_id" ]]; then
    _niri_message_to_ids focus-window <<<"$window_id"
  else
    $NIRI_APP_LAUNCHER -- "$@" &
  fi
}

# -------------------------------------------------------------------
# Named workspace navigation
# -------------------------------------------------------------------

# Return the name of the focused workspace (empty if unnamed)
niri_focused_workspace_name() {
  _niri_workspaces_json |
    jq -r '.[] | select(.is_focused) | .name // empty'
}

# Return workspace JSON object(s) matching a name
niri_workspace_by_name() {
  local name="$1"
  _niri_workspaces_json |
    jq -c --arg n "$name" '.[] | select(.name == $n)'
}

# -------------------------------------------------------------------
# Output-aware operations
# -------------------------------------------------------------------

# Return the name of the focused output
niri_focused_output() {
  _niri_workspaces_json |
    jq -r '.[] | select(.is_focused) | .output'
}

# Return all workspaces on an output as streamed JSON objects
niri_workspaces_on_output() {
  local output="$1"
  _niri_workspaces_json |
    jq -c --arg out "$output" '.[] | select(.output == $out)'
}

# Return all windows on an output as streamed JSON objects
niri_windows_on_output() {
  local output="$1"
  jq -cn \
    --argjson wins "$(_niri_windows_json)" \
    --argjson ws "$(_niri_workspaces_json)" \
    --arg out "$output" '
      ([$ws[] | select(.output == $out) | .id]) as $ws_ids
      | $wins[]
      | select(.workspace_id as $wid | $ws_ids | any(. == $wid))
    '
}
