#!/usr/bin/env bash
set -euo pipefail

DEVICE_ID="${1:-}"

if [ -z "$DEVICE_ID" ]; then
    echo "Error: Device ID argument is required." >&2
    exit 1
fi

PICKER=""
if command -v kdialog >/dev/null 2>&1; then
    PICKER="kdialog"
elif command -v zenity >/dev/null 2>&1; then
    PICKER="zenity"
else
    echo "Error: No supported file picker (kdialog or zenity) found." >&2
    exit 2
fi

FILE=""
if [ "$PICKER" = "kdialog" ]; then
    FILE=$(kdialog --getopenfilename ~ "Select File to Share" 2>/dev/null || true)
elif [ "$PICKER" = "zenity" ]; then
    FILE=$(zenity --file-selection --title="Select File to Share" 2>/dev/null || true)
fi

if [ -z "$FILE" ]; then
    echo "File selection cancelled." >&2
    exit 3
fi

if [ ! -f "$FILE" ] || [ ! -r "$FILE" ]; then
    echo "Error: File does not exist or is not readable: $FILE" >&2
    exit 4
fi

if ! kdeconnect-cli -d "$DEVICE_ID" --share "$FILE"; then
    echo "Error: kdeconnect-cli failed to transfer file." >&2
    exit 5
fi

echo "Successfully initiated file transfer: $FILE"
exit 0
