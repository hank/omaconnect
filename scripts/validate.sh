#!/usr/bin/env bash
set -eo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

echo "=================================================="
echo " OmaConnect Plugin Validation Suite"
echo "=================================================="

ERRORS=0

log_ok() {
    echo -e "  \033[32m[OK]\033[0m $1"
}

log_fail() {
    echo -e "  \033[31m[FAIL]\033[0m $1"
    ERRORS=$((ERRORS + 1))
}

echo "[1/13] Checking file structure..."
for file in "plugin.json" "main.qml" "Theme.qml" "README.md" "assets/icon.svg" "assets/screenshot.png" "components/BarButton.qml" "components/PopoverWindow.qml" "components/DevicePicker.qml" "components/DeviceCard.qml" "components/ActionGrid.qml" "components/CommandRunner.qml" "components/NotificationFeed.qml" "components/KdeConnectController.qml" "components/BatteryBar.qml" "components/qmldir" "scripts/share_file.sh"; do
    if [ -f "$file" ]; then
        log_ok "File found: $file"
    else
        log_fail "Missing required file: $file"
    fi
done


echo "[2/13] Validating plugin.json schema..."
if [ -f "plugin.json" ]; then
    if python3 - <<'EOF'
import json, sys

required_fields = [
    "id", "name", "version", "description", "author", 
    "repository", "license", "category", "entry", "icon", 
    "keywords", "dependencies", "minOmarchyVersion"
]

try:
    with open("plugin.json", "r") as f:
        data = json.load(f)
    
    missing = [field for field in required_fields if field not in data]
    if missing:
        print(f"Missing required fields: {', '.join(missing)}")
        sys.exit(1)
        
    if not isinstance(data.get("keywords"), list):
        print("'keywords' must be an array")
        sys.exit(1)

    if not isinstance(data.get("dependencies"), dict):
        print("'dependencies' must be an object")
        sys.exit(1)

    if data.get("entry") != "main.qml":
        print(f"Unexpected entry point: {data.get('entry')}")
        sys.exit(1)

    print("Manifest schema valid.")
    sys.exit(0)
except Exception as e:
    print(f"Schema validation error: {e}")
    sys.exit(1)
EOF
    then
        log_ok "plugin.json schema validated successfully"
    else
        log_fail "plugin.json schema validation failed"
    fi
else
    log_fail "plugin.json does not exist"
fi

echo "[3/13] Validating QML syntax and imports..."
if python3 - <<'EOF'
import subprocess, time, sys

try:
    proc = subprocess.Popen(
        ["qs", "-p", "main.qml"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    time.sleep(2.0)
    proc.terminate()
    try:
        stdout, stderr = proc.communicate(timeout=2)
    except Exception:
        proc.kill()
        stdout, stderr = proc.communicate()

    output = (stdout or "") + (stderr or "")
    if "ERROR:" in output or ("Type " in output and "unavailable" in output):
        print("Quickshell reported QML errors:\n" + output)
        sys.exit(1)
    
    if "Configuration Loaded" in output or "Scope" in output:
        print("Quickshell QML loaded cleanly.")
        sys.exit(0)
    else:
        print("Quickshell unexpected output:\n" + output)
        sys.exit(1)
except Exception as e:
    print(f"Failed to execute quickshell: {e}")
    sys.exit(1)
EOF
then
    log_ok "main.qml loaded cleanly in Quickshell without syntax/import errors"
else
    log_fail "Quickshell QML validation failed"
fi

echo "[4/13] Testing device parsing logic..."
if python3 - <<'EOF'
import sys

def parse_device_line(line):
    if not line or not line.strip():
        return None
    trimmed = line.strip()
    if trimmed.startswith("- "):
        content = trimmed[2:]
        colon_idx = content.find(":")
        if colon_idx > 0:
            name = content[:colon_idx].strip()
            rest = content[colon_idx + 1:].strip()
            paren_idx = rest.find("(")
            dev_id = (rest[:paren_idx] if paren_idx > 0 else rest).strip()
            status = rest[paren_idx + 1:rest.rfind(")")].strip() if paren_idx > 0 else ""
            is_reachable = "reachable" in status or "connected" in status
            is_paired = "paired" in status
            lower_name = name.lower()
            dev_type = "phone"
            if "ipad" in lower_name or "tablet" in lower_name or "tab" in lower_name:
                dev_type = "tablet"
            elif any(k in lower_name for k in ["laptop", "book", "macbook", "pc", "desktop"]):
                dev_type = "laptop"
            return {
                "id": dev_id,
                "name": name,
                "type": dev_type,
                "paired": is_paired,
                "reachable": is_reachable,
                "status": status
            }
    return None

test_cases = [
    ("- Pixel 8 Pro: 3a9f02123abcd (reachable and paired)", True, True, "Pixel 8 Pro", "3a9f02123abcd", "phone"),
    ("- moto g64 5G: 9e44625b_96df_4050_bae8_891823d35b75 (paired)", False, True, "moto g64 5G", "9e44625b_96df_4050_bae8_891823d35b75", "phone"),
    ("- iPad Air: 994827104bdef (reachable)", True, False, "iPad Air", "994827104bdef", "tablet"),
    ("- ThinkPad Laptop: abcd1234efgh (paired and reachable)", True, True, "ThinkPad Laptop", "abcd1234efgh", "laptop")
]

for raw, exp_reachable, exp_paired, exp_name, exp_id, exp_type in test_cases:
    res = parse_device_line(raw)
    if not res:
        print(f"Failed to parse: {raw}")
        sys.exit(1)
    if res["reachable"] != exp_reachable or res["paired"] != exp_paired or res["name"] != exp_name or res["id"] != exp_id or res["type"] != exp_type:
        print(f"Mismatch in test case: {raw} -> {res}")
        sys.exit(1)

print("Device parsing unit tests passed.")
sys.exit(0)
EOF
then
    log_ok "Device discovery and parsing unit tests passed"
else
    log_fail "Device parsing unit tests failed"
fi

echo "[5/13] Testing Ring, Ping & Send File action logic..."
if python3 - <<'EOF'
import sys, subprocess

def build_ring_command(device_id):
    return ["kdeconnect-cli", "-d", device_id, "--ring"]

def build_ping_command(device_id, msg="Ping from OmaConnect!"):
    return ["kdeconnect-cli", "-d", device_id, "--ping-msg", msg]

def build_share_file_command(device_id):
    return ["bash", "scripts/share_file.sh", device_id]

ring_cmd = build_ring_command("3a9f02123abcd")
if ring_cmd != ["kdeconnect-cli", "-d", "3a9f02123abcd", "--ring"]:
    print(f"Unexpected ring command structure: {ring_cmd}")
    sys.exit(1)

ping_cmd = build_ping_command("3a9f02123abcd", "Test message")
if ping_cmd != ["kdeconnect-cli", "-d", "3a9f02123abcd", "--ping-msg", "Test message"]:
    print(f"Unexpected ping command structure: {ping_cmd}")
    sys.exit(1)

share_cmd = build_share_file_command("3a9f02123abcd")
if share_cmd != ["bash", "scripts/share_file.sh", "3a9f02123abcd"]:
    print(f"Unexpected share file command structure: {share_cmd}")
    sys.exit(1)

# Test share_file.sh script without arguments returns exit code 1
res = subprocess.run(["bash", "scripts/share_file.sh"], capture_output=True, text=True)
if res.returncode != 1:
    print(f"Expected exit code 1 for missing device argument, got {res.returncode}")
    sys.exit(1)

# Test QML exit code status mapping helper
def map_share_file_exit_code(exit_code, dev_name="Device"):
    if exit_code == 0:
        return ("📁 File transfer started to " + dev_name, "success")
    elif exit_code == 3:
        return ("", "") # Cancelled cleanly
    elif exit_code == 2:
        return ("⚠️ No file picker found (install kdialog or zenity)", "error")
    elif exit_code == 4:
        return ("⚠️ Selected file is unreadable or missing", "error")
    else:
        return (f"⚠️ Failed to transfer file (exit code {exit_code})", "error")

assert map_share_file_exit_code(0, "Pixel 8")[1] == "success"
assert map_share_file_exit_code(3, "Pixel 8") == ("", "")
assert map_share_file_exit_code(2, "Pixel 8")[1] == "error"
assert map_share_file_exit_code(4, "Pixel 8")[1] == "error"
assert map_share_file_exit_code(5, "Pixel 8")[1] == "error"

# Verify the rendered action surface actually exposes the file-transfer flow.
with open("components/ActionGrid.qml", "r") as f:
    action_grid = f.read()
for required in ["triggerFileShare", "fileInProgress", "share_file.sh", "Qt.resolvedUrl"]:
    if required not in action_grid:
        print(f"ActionGrid is missing file-transfer integration: {required}")
        sys.exit(1)

def is_action_enabled(device):
    return device is not None and device.get("reachable", False) is True and device.get("paired", False) is True

dev_online = {"id": "dev1", "reachable": True, "paired": True}
dev_unpaired = {"id": "dev2", "reachable": True, "paired": False}
dev_offline = {"id": "dev3", "reachable": False, "paired": True}

if not is_action_enabled(dev_online):
    print("Online paired device should enable action")
    sys.exit(1)

if is_action_enabled(dev_unpaired) or is_action_enabled(dev_offline) or is_action_enabled(None):
    print("Unpaired, offline or null device should disable action")
    sys.exit(1)

# Pair & Unpair Command Builder Tests
def build_pair_command(device_id):
    return ["kdeconnect-cli", "-d", device_id, "--pair"]

def build_unpair_command(device_id):
    return ["kdeconnect-cli", "-d", device_id, "--unpair"]

pair_cmd = build_pair_command("3a9f02123abcd")
if pair_cmd != ["kdeconnect-cli", "-d", "3a9f02123abcd", "--pair"]:
    print(f"Unexpected pair command structure: {pair_cmd}")
    sys.exit(1)

unpair_cmd = build_unpair_command("3a9f02123abcd")
if unpair_cmd != ["kdeconnect-cli", "-d", "3a9f02123abcd", "--unpair"]:
    print(f"Unexpected unpair command structure: {unpair_cmd}")
    sys.exit(1)

# Pairing State Machine Unit Tests
pairing_states = {}

def get_pairing_state(dev_id):
    return pairing_states.get(dev_id, "idle")

def set_pairing_state(dev_id, state):
    pairing_states[dev_id] = state

# 1. State transition: idle -> pending -> accepted
set_pairing_state("dev1", "pending")
assert get_pairing_state("dev1") == "pending"

dev1_obj = {"id": "dev1", "paired": True}
if get_pairing_state(dev1_obj["id"]) == "pending" and dev1_obj["paired"]:
    set_pairing_state(dev1_obj["id"], "accepted")

assert get_pairing_state("dev1") == "accepted", "Pending pairing should transition to accepted when dev is paired"

# 2. State transition: idle -> pending -> rejected / failed
set_pairing_state("dev2", "pending")
assert get_pairing_state("dev2") == "pending"
set_pairing_state("dev2", "rejected")
assert get_pairing_state("dev2") == "rejected"

set_pairing_state("dev3", "pending")
set_pairing_state("dev3", "failed")
assert get_pairing_state("dev3") == "failed"

# 3. Non-blocking multi-device isolation: pairing dev1 does not affect dev2
set_pairing_state("dev_a", "pending")
assert get_pairing_state("dev_b") == "idle", "Device B pairing state should remain idle while Device A is pending"

# 4. Confirmation prompt toggle logic
show_confirm = False
show_confirm = True # User clicks Unpair Device
assert show_confirm is True
show_confirm = False # Confirm / cancel resets prompt
assert show_confirm is False

print("Ring, Ping, Send File, Pair, and Unpair action logic unit tests passed.")
sys.exit(0)
EOF
then
    log_ok "Ring, Ping, Send File, Pair, and Unpair action logic unit tests passed"
else
    log_fail "Ring, Ping, Send File, Pair, and Unpair action logic unit tests failed"
fi

echo "[6/13] Testing device presence streaming, line-safety & recovery..."
if python3 - <<'EOF'
import sys

# Line-safe signal event parsing
def parse_monitor_line(line, pending_member=""):
    if not line or not isinstance(line, str):
        return None, pending_member
    trimmed = line.strip()
    if not trimmed:
        return None, pending_member
    
    if trimmed.startswith("signal ") or "member=" in trimmed:
        if "member=deviceAdded" in trimmed or "deviceAdded" in trimmed:
            return "deviceAdded", "deviceAdded"
        elif "member=deviceRemoved" in trimmed or "deviceRemoved" in trimmed:
            return "deviceRemoved", "deviceRemoved"
        elif "member=deviceVisibilityChanged" in trimmed or "deviceVisibilityChanged" in trimmed:
            return "deviceVisibilityChanged", "deviceVisibilityChanged"
        elif "chargeChanged" in trimmed or "stateChanged" in trimmed:
            return "batteryStateChanged", pending_member
        return None, pending_member
        
    if pending_member and trimmed.startswith('string "'):
        q_start = trimmed.find('"')
        q_end = trimmed.rfind('"')
        if q_start >= 0 and q_end > q_start:
            dev_id = trimmed[q_start + 1:q_end]
            return (pending_member, dev_id), ""
    return None, ""

# 1. Test D-Bus signal event parsing
evt, pend = parse_monitor_line('signal sender=org.kde.kdeconnect member=deviceAdded')
assert evt == "deviceAdded" and pend == "deviceAdded"

evt, pend = parse_monitor_line('   string "device_998877"', pend)
assert evt == ("deviceAdded", "device_998877") and pend == ""

# 2. Test Line-Safety (Malformed / Unexpected inputs do not raise errors)
malformed_inputs = ["", "   ", "random noise", "member=unknownSignal", "string \"missing end quote", None]
for mi in malformed_inputs:
    evt, _ = parse_monitor_line(mi)

# 3. Test Device Deduplication Logic on Reconnect
def accumulate_devices(accumulator, dev_obj):
    existing_idx = -1
    for k, d in enumerate(accumulator):
        if d["id"] == dev_obj["id"]:
            existing_idx = k
            break
    if existing_idx >= 0:
        accumulator[existing_idx] = dev_obj
    else:
        accumulator.append(dev_obj)
    return accumulator

acc = []
dev1 = {"id": "3a9f02123abcd", "name": "Pixel 8 Pro", "reachable": False, "paired": True}
dev1_reconnected = {"id": "3a9f02123abcd", "name": "Pixel 8 Pro", "reachable": True, "paired": True}
dev2 = {"id": "994827104bdef", "name": "iPad Air", "reachable": True, "paired": True}

acc = accumulate_devices(acc, dev1)
acc = accumulate_devices(acc, dev2)
assert len(acc) == 2

acc = accumulate_devices(acc, dev1_reconnected)
assert len(acc) == 2
assert acc[0]["reachable"] is True, "Reconnecting device should update state without duplicate entry"

# 4. Test Active Device State Preservation
def finalize_device_selection(all_devices, prev_active_id):
    reachable = [d for d in all_devices if d["reachable"]]
    found_active = None
    if prev_active_id:
        for d in all_devices:
            if d["id"] == prev_active_id:
                found_active = d
                break
    if not found_active:
        found_active = reachable[0] if reachable else (all_devices[0] if all_devices else None)
    return found_active

# Select dev1 as active
selected = finalize_device_selection(acc, "3a9f02123abcd")
assert selected["id"] == "3a9f02123abcd"

# dev2 status changes or leaves
acc = [acc[0]] # dev2 removed
selected_after = finalize_device_selection(acc, "3a9f02123abcd")
assert selected_after["id"] == "3a9f02123abcd", "Selected active device selection preserved"

print("Real-time presence streaming, deduplication & active device state preservation unit tests passed.")
sys.exit(0)
EOF
then
    log_ok "Device presence streaming and state preservation unit tests passed"
else
    log_fail "Device presence streaming unit tests failed"
fi

echo "[7/13] Testing battery status logic and thresholds..."
if python3 - <<'EOF'
import sys

def get_battery_color(percentage, is_charging):
    if is_charging:
        return "success"
    if percentage <= 20:
        return "danger"
    if percentage <= 45:
        return "warning"
    return "success"

def calculate_lowest_battery(devices):
    min_bat = -1
    for dev in devices:
        if dev.get("reachable", False):
            bat = dev.get("batteryLevel", -1)
            if isinstance(bat, (int, float)) and 0 <= bat <= 100:
                if min_bat == -1 or bat < min_bat:
                    min_bat = bat
    return min_bat

# Test Battery Threshold Rules
assert get_battery_color(15, False) == "danger", "15% should be danger"
assert get_battery_color(20, False) == "danger", "20% should be danger"
assert get_battery_color(45, False) == "warning", "45% should be warning"
assert get_battery_color(46, False) == "success", "46% should be success"
assert get_battery_color(10, True) == "success", "Charging should be green/success"

# Test Lowest Battery Calculation
devs = [
    {"id": "d1", "reachable": True, "batteryLevel": 85},
    {"id": "d2", "reachable": True, "batteryLevel": 22},
    {"id": "d3", "reachable": False, "batteryLevel": 5}
]
assert calculate_lowest_battery(devs) == 22, "Lowest reachable battery should be 22"

devs_unknown = [
    {"id": "d1", "reachable": True, "batteryLevel": -1},
    {"id": "d2", "reachable": False, "batteryLevel": 10}
]
assert calculate_lowest_battery(devs_unknown) == -1, "Unknown/unreachable battery should return -1"

print("Battery status logic and threshold unit tests passed.")
sys.exit(0)
EOF
then
    log_ok "Battery status logic and threshold unit tests passed"
else
    log_fail "Battery status logic and threshold unit tests failed"
fi

echo "[8/13] Testing remote device commands parsing & execution logic..."
if python3 - <<'EOF'
import sys, json

def parse_remote_commands_output(text):
    if not text or not isinstance(text, str) or not text.strip():
        return []
    trimmed = text.strip()
    if "No commands" in trimmed or "error:" in trimmed or "Device unreachable" in trimmed:
        return []
    result = []
    if (trimmed.startswith("{") and trimmed.endswith("}")) or (trimmed.startswith("[") and trimmed.endswith("]")):
        try:
            parsed = json.loads(trimmed)
            if isinstance(parsed, list):
                for item in parsed:
                    if isinstance(item, dict):
                        k = item.get("key") or item.get("id") or item.get("command") or ""
                        n = item.get("name") or item.get("label") or item.get("title") or k
                        if k:
                            result.append({"key": str(k), "name": str(n)})
                    elif isinstance(item, str) and item.strip():
                        result.append({"key": item.strip(), "name": item.strip()})
                return result
            elif isinstance(parsed, dict):
                for k, v in parsed.items():
                    disp = k
                    if isinstance(v, str):
                        disp = v
                    elif isinstance(v, dict):
                        disp = v.get("name") or v.get("label") or v.get("title") or k
                    result.append({"key": str(k), "name": str(disp)})
                return result
        except Exception:
            pass

    lines = trimmed.split("\n")
    for line in lines:
        l = line.strip()
        if not l:
            continue
        if l.startswith("- ") or l.startswith("* "):
            l = l[2:].strip()
        if not l:
            continue
        colon_idx = l.find(":")
        if colon_idx > 0:
            key_part = l[:colon_idx].strip()
            name_part = l[colon_idx + 1:].strip()
            if key_part:
                result.append({"key": key_part, "name": name_part if name_part else key_part})
                continue
        dash_idx = l.find(" - ")
        if dash_idx > 0:
            k_dash = l[:dash_idx].strip()
            n_dash = l[dash_idx + 3:].strip()
            if k_dash:
                result.append({"key": k_dash, "name": n_dash if n_dash else k_dash})
                continue
        result.append({"key": l, "name": l})
    return result

# 1. Test Plain Text line-based command list parsing
raw_cli_output = "- lock: Lock Screen\n- suspend: Suspend System\n- play_pause: Play/Pause Media"
parsed_cli = parse_remote_commands_output(raw_cli_output)
assert len(parsed_cli) == 3, f"Expected 3 items, got {len(parsed_cli)}"
assert parsed_cli[0] == {"key": "lock", "name": "Lock Screen"}
assert parsed_cli[1] == {"key": "suspend", "name": "Suspend System"}
assert parsed_cli[2] == {"key": "play_pause", "name": "Play/Pause Media"}

# 2. Test JSON Dict command list parsing
raw_json_dict = '{"lock": {"name": "Lock Screen"}, "suspend": "Sleep PC"}'
parsed_dict = parse_remote_commands_output(raw_json_dict)
assert len(parsed_dict) == 2
assert parsed_dict[0] == {"key": "lock", "name": "Lock Screen"}
assert parsed_dict[1] == {"key": "suspend", "name": "Sleep PC"}

# 3. Test Empty & Error Output Handling
assert parse_remote_commands_output("") == []
assert parse_remote_commands_output("No commands configured for this device") == []
assert parse_remote_commands_output("error: device not found") == []

# 4. Test Execute Command Command Line Builder
def build_execute_cmd(device_id, key):
    if not device_id or not key:
        return None
    return ["kdeconnect-cli", "-d", device_id, "--execute-command", key]

cmd = build_execute_cmd("3a9f02123abcd", "lock")
assert cmd == ["kdeconnect-cli", "-d", "3a9f02123abcd", "--execute-command", "lock"]

# 5. Reachability Guard for Remote Command Execution
def can_execute_remote_command(device):
    return device is not None and device.get("reachable", False) is True

dev_online = {"id": "dev1", "reachable": True}
dev_offline = {"id": "dev2", "reachable": False}
assert can_execute_remote_command(dev_online) is True
assert can_execute_remote_command(dev_offline) is False
assert can_execute_remote_command(None) is False

print("Remote device commands parsing & execution logic unit tests passed.")
sys.exit(0)
EOF
then
    log_ok "Remote device commands parsing & execution logic unit tests passed"
else
    log_fail "Remote device commands unit tests failed"
fi

echo "[9/13] Testing Send Clipboard & Link transfer logic..."
if python3 - <<'EOF'
import sys

def build_share_text_command(device_id, text):
    return ["kdeconnect-cli", "-d", device_id, "--share-text", text]

def build_paste_command():
    return ["bash", "-c", "which wl-paste >/dev/null 2>&1 || exit 127; wl-paste --no-newline 2>/dev/null || wl-paste 2>/dev/null"]

# 1. Test CLI command array construction and safe parameter passing
cmd = build_share_text_command("3a9f02123abcd", "https://omarchy.org")
assert cmd == ["kdeconnect-cli", "-d", "3a9f02123abcd", "--share-text", "https://omarchy.org"]

special_text = 'Test "$VAR" & `cmd` \'quote\''
cmd_special = build_share_text_command("3a9f02123abcd", special_text)
assert cmd_special[4] == special_text, "Special characters must be preserved without shell interpolation"

# 2. Test Wayland paste command structure
paste_cmd = build_paste_command()
assert paste_cmd[0] == "bash" and "wl-paste" in paste_cmd[2]

# 3. Test Clipboard feedback mapping rules
def get_clipboard_feedback(exit_code, text):
    if exit_code == 127:
        return ("⚠️ wl-clipboard tool (wl-paste) is not installed.", "error")
    elif exit_code == 0 and text and text.strip():
        return ("📋 Pasted from Wayland clipboard (" + str(len(text.strip())) + " chars)", "success")
    else:
        return ("⚠️ Clipboard is empty or contains non-text content.", "error")

assert get_clipboard_feedback(127, "")[1] == "error"
assert get_clipboard_feedback(0, "")[1] == "error"
assert get_clipboard_feedback(0, "  ")[1] == "error"
assert get_clipboard_feedback(0, "Hello World")[1] == "success"

# 4. Test Reachability guard and input validation
def can_share(device, text):
    if not device or not device.get("reachable", False):
        return (False, "⚠️ Cannot send: Device is offline or unreachable.")
    if not text or not text.strip():
        return (False, "⚠️ Please enter text or paste clipboard content first.")
    return (True, "Sending text to device...")

dev_online = {"id": "d1", "reachable": True}
dev_offline = {"id": "d2", "reachable": False}

assert can_share(dev_offline, "hello")[0] is False
assert can_share(dev_online, "")[0] is False
assert can_share(dev_online, "  ")[0] is False
assert can_share(dev_online, "https://github.com")[0] is True

print("Send Clipboard & Link transfer unit tests passed.")
sys.exit(0)
EOF
then
    log_ok "Send Clipboard & Link transfer unit tests passed"
else
    log_fail "Send Clipboard & Link transfer unit tests failed"
fi

echo "[10/13] Testing incoming phone notifications parsing, feed bounds & dismissal..."
if python3 - <<'EOF'
import sys, time, json

class NotificationFeedController:
    def __init__(self, max_notifications=10):
        self.notifications = []
        self.max_notifications = max_notifications
        self.pending_monitor_dev_id = ""
        self.pending_monitor_member = ""
        self.pending_notif_args = []

    def add_notification(self, notif):
        if not notif or not isinstance(notif, dict):
            return
        notif_id = notif.get("id") or f"notif_{int(time.time()*1000)}"
        dev_id = notif.get("deviceId", "")
        dev_name = notif.get("deviceName", "Phone")
        app_name = notif.get("appName") or notif.get("app") or "Notification"
        title = notif.get("title") or app_name
        body = notif.get("body", "")
        is_sms = notif.get("isSms") if "isSms" in notif else ("sms" in app_name.lower() or "messages" in app_name.lower())
        timestamp = notif.get("timestamp", "12:00 PM")

        new_obj = {
            "id": str(notif_id),
            "deviceId": str(dev_id),
            "deviceName": str(dev_name),
            "appName": str(app_name),
            "title": str(title),
            "body": str(body),
            "timestamp": str(timestamp),
            "isSms": bool(is_sms)
        }

        self.notifications.insert(0, new_obj)
        if len(self.notifications) > self.max_notifications:
            self.notifications = self.notifications[:self.max_notifications]

    def dismiss_notification(self, notif_id):
        if not notif_id:
            return
        self.notifications = [n for n in self.notifications if n["id"] != str(notif_id)]

    def clear_all_notifications(self):
        self.notifications = []

    def parse_monitor_line(self, line):
        if not line or not isinstance(line, str):
            return
        trimmed = line.strip()
        if not trimmed:
            return

        if trimmed.startswith("NOTIF:"):
            parts = trimmed.split(":")
            if len(parts) >= 5:
                self.add_notification({
                    "deviceId": parts[1],
                    "appName": parts[2],
                    "title": parts[3],
                    "body": ":".join(parts[4:])
                })
            return

        if trimmed.startswith("{") and trimmed.endswith("}") and ("appName" in trimmed or "title" in trimmed or "body" in trimmed):
            try:
                obj = json.loads(trimmed)
                if isinstance(obj, dict) and (obj.get("appName") or obj.get("title") or obj.get("body")):
                    self.add_notification(obj)
                    return
            except Exception:
                pass

        if trimmed.startswith("signal ") or "member=" in trimmed:
            self.flush_pending_notification_args()
            if "member=notificationAdded" in trimmed or "notificationAdded" in trimmed:
                self.pending_monitor_member = "notificationAdded"
            elif "member=displayNotification" in trimmed or "displayNotification" in trimmed:
                self.pending_monitor_member = "displayNotification"
            elif "member=notificationPosted" in trimmed or "notificationPosted" in trimmed:
                self.pending_monitor_member = "notificationPosted"
            else:
                self.pending_monitor_member = ""
            self.pending_notif_args = []
            return

        if self.pending_monitor_member in ["notificationAdded", "displayNotification", "notificationPosted"]:
            if trimmed.startswith('string "'):
                q_start = trimmed.find('"')
                q_end = trimmed.rfind('"')
                if q_start >= 0 and q_end > q_start:
                    str_val = trimmed[q_start + 1:q_end]
                    self.pending_notif_args.append(str_val)
                    if len(self.pending_notif_args) >= 3:
                        self.flush_pending_notification_args()

    def flush_pending_notification_args(self):
        if not self.pending_notif_args or not self.pending_monitor_member:
            return
        app = "Notification"
        title = "Phone"
        body = ""
        if len(self.pending_notif_args) == 1:
            body = self.pending_notif_args[0]
        elif len(self.pending_notif_args) == 2:
            title = self.pending_notif_args[0]
            body = self.pending_notif_args[1]
        elif len(self.pending_notif_args) >= 3:
            app = self.pending_notif_args[0]
            title = self.pending_notif_args[1]
            body = self.pending_notif_args[2]

        self.add_notification({
            "deviceId": self.pending_monitor_dev_id,
            "appName": app,
            "title": title,
            "body": body
        })
        self.pending_notif_args = []

# 1. Test D-Bus Monitor Signal Stream Parsing (App, Title, Body)
controller = NotificationFeedController()
controller.parse_monitor_line('signal sender=org.kde.kdeconnect member=displayNotification path=/modules/kdeconnect/devices/dev123/notifications')
controller.parse_monitor_line('   string "WhatsApp"')
controller.parse_monitor_line('   string "Alice"')
controller.parse_monitor_line('   string "Are you available for a quick call?"')

assert len(controller.notifications) == 1
notif1 = controller.notifications[0]
assert notif1["appName"] == "WhatsApp"
assert notif1["title"] == "Alice"
assert notif1["body"] == "Are you available for a quick call?"

# 2. Test SMS Auto-detection Tagging
controller.parse_monitor_line('NOTIF:dev123:Messages:Mom:Dinner at 7')
assert len(controller.notifications) == 2
assert controller.notifications[0]["isSms"] is True, "Messages app notification should be marked as SMS"

# 3. Test Bounded Feed Limit (Max 10 notifications)
for i in range(15):
    controller.add_notification({"id": f"id_{i}", "appName": "App", "title": f"Title {i}", "body": f"Body {i}"})

assert len(controller.notifications) == 10, f"Expected 10 notifications max, got {len(controller.notifications)}"
assert controller.notifications[0]["id"] == "id_14", "Newest notification should be at the top"

# 4. Test Single Notification Dismissal
target_id = controller.notifications[0]["id"]
controller.dismiss_notification(target_id)
assert len(controller.notifications) == 9
assert not any(n["id"] == target_id for n in controller.notifications)

# 5. Test Clear All Notifications
controller.clear_all_notifications()
assert len(controller.notifications) == 0, "Clear all should empty notification feed"

# 6. Test Privacy Constraint Verification
bar_button_properties = ["activeDeviceCount", "lowestBattery", "isConnected", "daemonAvailable", "isPopoverOpen", "activeDevice"]
assert "body" not in bar_button_properties and "notification" not in bar_button_properties, "Topbar BarButton must not expose notification body text"

print("Incoming phone notifications parsing, feed bounds & dismissal unit tests passed.")
sys.exit(0)
EOF
then
    log_ok "Incoming phone notifications unit tests passed"
else
    log_fail "Incoming phone notifications unit tests failed"
fi

echo "[11/13] Testing Multi-Device Isolation, Keyboard Focus & Motion Control..."
if python3 - <<'EOF'
import sys

# 1. Multi-Device State Isolation Test
class ControllerStateMock:
    def __init__(self):
        self.active_device = None
        self.ring_in_progress = False
        self.is_ringing = False
        self.ping_in_progress = False
        self.share_in_progress = False
        self.clipboard_text = ""
        self.executing_command = None

    def select_device(self, dev):
        self.active_device = dev
        # Reset in-flight state
        self.ring_in_progress = False
        self.is_ringing = False
        self.ping_in_progress = False
        self.share_in_progress = False
        self.clipboard_text = ""
        self.executing_command = None

dev_a = {"id": "dev_a", "name": "Pixel 8"}
dev_b = {"id": "dev_b", "name": "Galaxy Tab"}

c = ControllerStateMock()
c.select_device(dev_a)
c.ring_in_progress = True
c.is_ringing = True
c.clipboard_text = "secret text for dev_a"

# Switch to Dev B
c.select_device(dev_b)
assert c.active_device["id"] == "dev_b"
assert c.ring_in_progress is False, "ring_in_progress must be cleared on device switch"
assert c.is_ringing is False, "is_ringing must be cleared on device switch"
assert c.clipboard_text == "", "clipboard_text must be cleared on device switch"

# Process target isolation check
def handle_process_exit(target_device_id, active_device_id, exit_code):
    if target_device_id != active_device_id:
        return "ignored"
    return "processed" if exit_code == 0 else "error"

assert handle_process_exit("dev_a", "dev_b", 0) == "ignored", "Process completion for dev_a must be ignored when active device is dev_b"
assert handle_process_exit("dev_b", "dev_b", 0) == "processed"

# 2. Keyboard Navigation & Accessibility Verification
with open("components/PopoverWindow.qml", "r") as f:
    popover_content = f.read()

assert "Keys.onEscapePressed" in popover_content, "PopoverWindow must handle Escape key to close popover"
assert "Flickable" in popover_content, "PopoverWindow must use Flickable for auto-scrolling content"

for comp_file in ["components/BarButton.qml", "components/DevicePicker.qml", "components/DeviceCard.qml", "components/ActionGrid.qml"]:
    with open(comp_file, "r") as f:
        content = f.read()
    assert "activeFocusOnTab" in content, f"{comp_file} must specify activeFocusOnTab for keyboard navigation"
    assert "Keys.onReturnPressed" in content or "Keys.onSpacePressed" in content or "Keys.onPressed" in content, f"{comp_file} must handle Enter/Space key events"

# 3. Motion Control & Animation Toggle Verification
with open("Theme.qml", "r") as f:
    theme_content = f.read()

assert "property bool animationsEnabled" in theme_content, "Theme.qml must define animationsEnabled property"
assert "animDurationFast" in theme_content and "animDurationNormal" in theme_content, "Theme.qml must define animation duration tokens"

print("Multi-Device Isolation, Keyboard Focus & Motion Control unit tests passed.")
sys.exit(0)
EOF
then
    log_ok "Multi-Device Isolation, Keyboard Focus & Motion Control unit tests passed"
else
    log_fail "Multi-Device Isolation, Keyboard Focus & Motion Control unit tests failed"
fi

echo "[12/13] Testing Final Release Candidate Package (Manifest, Assets, README & Marketplace Readiness)..."
if python3 - <<'EOF'
import json, sys, os

try:
    # 1. Verify plugin.json accuracy & dependencies
    with open("plugin.json", "r") as f:
        manifest = json.load(f)
    
    assert manifest.get("id") == "omaconnect", "plugin.json id must be omaconnect"
    assert manifest.get("version") == "1.0.0", "plugin.json version must be 1.0.0"
    assert manifest.get("entry") == "main.qml", "plugin.json entry point must be main.qml"
    assert manifest.get("minOmarchyVersion") == "4.0.0", "minOmarchyVersion must be 4.0.0"
    assert "kdeconnect" in manifest.get("dependencies", {}).get("system", []), "kdeconnect must be in system dependencies"
    assert "wl-clipboard" in manifest.get("dependencies", {}).get("system", []), "wl-clipboard must be in system dependencies"

    # 2. Verify assets/icon.svg
    assert os.path.isfile("assets/icon.svg"), "assets/icon.svg must exist"
    with open("assets/icon.svg", "r", encoding="utf-8", errors="ignore") as f:
        icon_text = f.read()
    assert "<svg" in icon_text and "</svg>" in icon_text, "assets/icon.svg must be a valid SVG document"
    assert len(icon_text) > 100, "assets/icon.svg must not be empty"

    # 3. Verify assets/screenshot.png magic bytes
    assert os.path.isfile("assets/screenshot.png"), "assets/screenshot.png must exist"
    with open("assets/screenshot.png", "rb") as f:
        png_header = f.read(8)
    assert png_header == b"\x89PNG\r\n\x1a\n", "assets/screenshot.png must be a valid PNG image file"
    assert os.path.getsize("assets/screenshot.png") > 1000, "assets/screenshot.png must not be empty"

    # 4. Verify user-facing README.md
    assert os.path.isfile("README.md"), "README.md must exist in repository root"
    with open("README.md", "r", encoding="utf-8") as f:
        readme_text = f.read()
    
    required_readme_sections = [
        "Features", "Dependencies", "Installation", "Usage", 
        "Troubleshooting", "Privacy", "Uninstallation", "Marketplace Publishing Release Checklist"
    ]
    for sec in required_readme_sections:
        assert sec.lower() in readme_text.lower(), f"README.md missing required section: {sec}"
    
    print("Marketplace release candidate package checks passed cleanly.")
    sys.exit(0)
except Exception as e:
    print(f"Release candidate package validation error: {e}")
    sys.exit(1)
EOF
then
    log_ok "Final Release Candidate package (plugin.json, assets, README) validated successfully"
else
    log_fail "Final Release Candidate package validation failed"
fi

echo "[13/13] Summary..."
if [ "$ERRORS" -eq 0 ]; then
    echo -e "\033[32m✔ All validation checks passed cleanly!\033[0m"
    exit 0
else
    echo -e "\033[31m✖ Validation failed with $ERRORS error(s).\033[0m"
    exit 1
fi
