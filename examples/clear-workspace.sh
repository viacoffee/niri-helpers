#!/usr/bin/env bash
# Close windows on the current workspace.
#
# Usage:
#   clear-workspace           Close all windows on the focused workspace
#   clear-workspace --keep    Close all windows except the focused one
#
# Examples:
#   clear-workspace           Wipes the workspace clean
#   clear-workspace --keep    Clears clutter while keeping what you're looking at
set -euo pipefail

if [[ $# -gt 1 || ( $# -eq 1 && ${1:-} != --keep ) ]]; then
  printf 'Usage: %s [--keep]\n' "${0##*/}" >&2
  exit 2
fi

source "$(dirname "$(realpath "$0")")/../niri-helpers.sh"

case "${1:-}" in
  --keep) niri_close_unfocused_on_workspace ;;
  *)      niri_close_all_on_workspace ;;
esac
