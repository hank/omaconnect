#!/usr/bin/env bash
set -uo pipefail

if [[ -n "${OMARCHY_PATH:-}" ]]; then
  export PATH="$OMARCHY_PATH/bin:$HOME/.local/bin:$PATH"
else
  export PATH="$HOME/.local/bin:$PATH"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/pick_file.py" "$@"
