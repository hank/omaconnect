#!/usr/bin/env bash
set -euo pipefail

if command -v ufw >/dev/null 2>&1; then
    echo "Opening UFW firewall for KDE Connect (ports 1714-1764 TCP/UDP)..."
    sudo ufw allow 1714:1764/tcp comment 'KDE Connect'
    sudo ufw allow 1714:1764/udp comment 'KDE Connect'
    sudo ufw reload
    echo "Firewall rules applied."
    sleep 2
else
    echo "UFW is not installed; skipping firewall configuration."
    sleep 2
fi
