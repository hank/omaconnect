#!/usr/bin/env bash
set -uo pipefail

export PATH="$HOME/code/temp/omarchy/bin:$HOME/.local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/pick_file.py" "$@"
