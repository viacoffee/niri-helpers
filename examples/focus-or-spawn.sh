#!/usr/bin/env bash
# Focus an existing window matching a pattern, or spawn a new one.
#
# The pattern is matched case-insensitively against app_id and title.
#
# Usage: focus-or-spawn <window_pattern> [launch_command [args...]]
#
# With no launch command, the pattern is used as the command.
#
# Examples:
#   focus-or-spawn firefox
#   focus-or-spawn alacritty
#   focus-or-spawn slack slack --enable-features=UseOzonePlatform --ozone-platform=wayland
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <window_pattern> [launch_command [args...]]"
  echo
  echo "Examples:"
  echo "  $(basename "$0") firefox"
  echo "  $(basename "$0") alacritty"
  echo "  $(basename "$0") slack slack --enable-features=UseOzonePlatform --ozone-platform=wayland"
  exit 1
fi

source "$(dirname "$(realpath "$0")")/../niri-helpers.sh"

pattern="$1"
shift

if [[ $# -eq 0 ]]; then
  niri_focus_or_spawn "$pattern" "$pattern"
else
  niri_focus_or_spawn "$pattern" "$@"
fi
