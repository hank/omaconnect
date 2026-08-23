#!/usr/bin/env bash
# Restart the kdeconnectd background service. Useful when the daemon wedges
# (owns its D-Bus name but stops responding, so devices vanish from the UI).
# No sudo or user interaction required.
set -uo pipefail
pkill -x kdeconnectd 2>/dev/null || true
sleep 1
pkill -9 -x kdeconnectd 2>/dev/null || true
sleep 1
setsid nohup kdeconnectd >/dev/null 2>&1 &
sleep 3
exit 0
