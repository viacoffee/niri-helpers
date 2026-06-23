#!/usr/bin/env bash
# Gracefully close all niri windows before rebooting or shutting down.
# Gives apps a moment to exit cleanly before the system command runs.
#
# Usage: graceful-shutdown [reboot|shutdown]
#        Default: shutdown
set -euo pipefail

action="${1:-shutdown}"

source "$(dirname "$(realpath "$0")")/../niri-helpers.sh"

niri_close_all_windows || true
sleep 1

case "$action" in
  reboot)   systemctl reboot --no-wall ;;
  shutdown) systemctl poweroff --no-wall ;;
  *) echo "Usage: $(basename "$0") [reboot|shutdown]"; exit 1 ;;
esac
