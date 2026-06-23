#!/usr/bin/env bash
# Close all windows whose app_id or title matches a pattern.
# The pattern is a case-insensitive extended regex matched against both fields.
#
# Usage: close-by-pattern <pattern>
#
# Examples:
#   close-by-pattern firefox
#   close-by-pattern "^Alacritty$"
#   close-by-pattern "GitLens|GitHub Copilot"
#   close-by-pattern "localhost|127\.0\.0\.1"
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <pattern>"
  echo
  echo "Examples:"
  echo "  $(basename "$0") firefox"
  echo "  $(basename "$0") \"^Alacritty\$\""
  echo "  $(basename "$0") \"GitLens|GitHub Copilot\""
  exit 1
fi

source "$(dirname "$(realpath "$0")")/../niri-helpers.sh"

# Pre-fetch once so both calls below share the same snapshot
niri_init

matches="$(niri_windows_matching "$1")"

if [[ -z "$matches" ]]; then
  echo "No windows matching: $1"
  exit 0
fi

echo "$matches" | jq -r '"Closing: \(.app_id // "?"): \(.title // "?")"'
niri_close_matching "$1"
