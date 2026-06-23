#!/usr/bin/env bash
# Focus an existing window matching a pattern, or spawn a new one.
#
# The pattern is matched case-insensitively against app_id and title.
#
# Usage: focus-or-spawn <pattern> [command...]
#
# Examples:
#   focus-or-spawn firefox firefox
#   focus-or-spawn "^org\.gnome\.Nautilus$" nautilus
#   focus-or-spawn slack slack --enable-features=UseOzonePlatform --ozone-platform=wayland
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <pattern> [command...]"
  echo
  echo "Examples:"
  echo "  $(basename "$0") firefox firefox"
  echo "  $(basename "$0") \"^org\\.gnome\\.Nautilus\$\" nautilus"
  echo "  $(basename "$0") slack slack --enable-features=UseOzonePlatform --ozone-platform=wayland"
  exit 1
fi

source "$(dirname "$(realpath "$0")")/../niri-helpers.sh"

niri_focus_or_spawn "$@"
