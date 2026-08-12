#!/usr/bin/env bash
set -uo pipefail

if [[ -n "${OMARCHY_PATH:-}" ]]; then
  export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH"
else
  export PATH="$HOME/.local/bin:$PATH"
fi

paths="${HOME}/Downloads:${HOME}/Documents:${HOME}/Pictures:${HOME}/Videos"
formats="jpg jpeg png webp gif heic avif mp4 mov m4v mkv webm avi pdf txt zip tar gz iso"

exec omarchy-menu-file "Select file to send" "$paths" "$formats" --width 800
