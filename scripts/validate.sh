#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

python3 -m unittest -q tests/test_state.py
bash -n scripts/validate.sh

validator=/home/sastauser/code/temp/omarchy/bin/omarchy-plugin-validate
if [ -x "$validator" ]; then "$validator" .; else printf '%s\n' "exact Omarchy validator unavailable; skipped"; fi

if command -v qmllint >/dev/null 2>&1; then
    qml_output="$(mktemp)"
    trap 'rm -f "$qml_output"' EXIT
    set +e
    qmllint -I /home/sastauser/code/temp/omarchy/shell \
        -I /home/sastauser/code/temp/omarchy/shell/Ui \
        -I /home/sastauser/code/temp/omarchy/shell/Commons \
        Service.qml BarWidget.qml KdeConnectController.qml >"$qml_output" 2>&1
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        printf '%s\n' "qmllint reported actual errors; runtime loader checks are also required"
        printf '%s\n' "$(<"$qml_output")"
        exit "$status"
    elif grep -q 'Warning:' "$qml_output"; then
        printf '%s\n' "qmllint emitted host-import/unqualified-type diagnostics; not claimed warning-free"
        printf '%s\n' "QML loader/runtime verification is the authoritative error check"
    else
        printf '%s\n' "qmllint completed without diagnostics"
    fi
else
    printf '%s\n' "qmllint unavailable; skipped"
fi

printf '%s\n' "validation completed"
