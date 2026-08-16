#!/usr/bin/env bash
set -euo pipefail

echo "Installing KDE Connect..."
sudo pacman -S --needed kdeconnect glib2 dbus
echo "Installed."
sleep 1
