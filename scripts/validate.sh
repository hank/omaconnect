#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

python3 - <<'PY'
import json
from pathlib import Path

manifest = json.loads(Path("manifest.json").read_text())
required = {"schemaVersion", "id", "name", "version", "kinds", "entryPoints"}
assert required <= manifest.keys()
assert manifest["id"] == "omaconnect"
assert set(manifest["kinds"]) == {"service", "bar-widget"}
assert manifest["entryPoints"] == {"service": "Service.qml", "barWidget": "BarWidget.qml"}
assert manifest.get("barWidget", {}).get("allowMultiple", False) is False

def parse(line):
    content = line.strip()[2:]
    name, rest = content.split(":", 1)
    status = rest[rest.find("(") + 1:rest.rfind(")")] if "(" in rest else ""
    ident = rest.split("(", 1)[0].strip().split(" on ", 1)[0].split()[0]
    return name.strip(), ident, "reachable" in status or "connected" in status, "paired" in status

assert parse("- Pixel: abc123 on 192.168.1.2 via LAN (reachable and paired)") == ("Pixel", "abc123", True, True)
assert parse("- Phone: abc123 (paired)") == ("Phone", "abc123", False, True)

qml = Path("components/KdeConnectController.qml").read_text()
assert '"--list-devices"' in qml
assert "org.freedesktop.DBus.Properties.Get" in qml
assert 'pendingMonitorMember === "refreshed"' in qml
assert "StdioCollector" in qml
assert "targetGeneration" in qml
assert "paired === true && dev.reachable === true" in qml
assert "Stopped ringing" not in Path("components/ActionGrid.qml").read_text()
assert "notificationPosted" in qml and "addNotification" not in qml[qml.index('function flushPendingNotificationArgs'):qml.index('function getPairingState')]

bar = Path("BarWidget.qml").read_text()
assert "BarWidget {" in bar and "PopupCard {" in bar and "serviceFor(\"omaconnect\")" in bar
assert 'target: "omaconnect"' in bar
assert "PanelWindow" not in bar
print("manifest, parser, controller, and native bar contract checks passed")
PY

if command -v qmllint >/dev/null 2>&1; then
    qmllint -I /home/sastauser/code/temp/omarchy/shell BarWidget.qml Service.qml components/*.qml
else
    echo "qmllint not installed; skipped"
fi

if command -v bash >/dev/null 2>&1; then
    bash -n scripts/share_file.sh
fi

echo "validation passed"
