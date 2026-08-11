# 05. Component Implementation Blueprints

This document specifies the internal properties, signals, and interface contracts for every QML file and script component in the OmaConnect repository.

---

## 1. Component Tree Hierarchy

```
main.qml (Scope & Main Controller)
 ├── KdeConnectController (State & IPC Manager)
 ├── BarButton.qml (Topbar Widget Item)
 └── PopoverWindow.qml (Glassmorphic Dropdown Panel)
      ├── DevicePicker.qml (Header & Device Selector)
      ├── DeviceCard.qml (Active Device Status)
      │    └── BatteryBar.qml (Dynamic Battery Visualizer)
      ├── ActionGrid.qml (Quick Actions: Ring, File, Clip, SMS)
      └── CommandRunner.qml (Remote Phone Commands)
```

---

## 2. File Specifications & Component Contracts

### 2.1 `main.qml` (Entry Point)
- **Role**: Root component loaded by Quickshell.
- **Imports**: `Quickshell`, `QtQuick`, `./components`.
- **Properties**:
  - `property var connectedDevices: []`: List of active device objects.
  - `property bool isPopoverOpen: false`: Popover visibility toggle.

---

### 2.2 `components/BarButton.qml`
- **Role**: Rendered inside the top bar panel layout.
- **Properties**:
  - `property int activeDeviceCount`: Number of connected devices.
  - `property int lowestBattery`: Battery % preview.
  - `property bool isConnected`: True if at least 1 device reachable.
- **Signals**:
  - `signal clicked()`: Emitted when user clicks topbar item to toggle popover.

---

### 2.3 `components/PopoverWindow.qml`
- **Role**: Floating panel anchored to `BarButton`.
- **Properties**:
  - `property var activeDevice`: Currently selected device object.
- **Child Elements**:
  - Translucent glassmorphic background container (`#cc12151b`).
  - Column layout containing `DevicePicker`, `DeviceCard`, `ActionGrid`, and `CommandRunner`.

---

### 2.4 `components/BatteryBar.qml`
- **Role**: Visual progress bar for phone battery level.
- **Properties**:
  - `property int chargeLevel`: Integer 0–100.
  - `property bool isCharging`: Boolean flag.
- **Visuals**:
  - Inner fill width bound to `(chargeLevel / 100) * parent.width`.
  - Color dynamically computed via HSL gradient helper (`#10b981` green, `#f59e0b` amber, `#ef4444` red).
  - Bolt icon animated when `isCharging === true`.

---

### 2.5 `components/ActionGrid.qml`
- **Role**: Grid layout of quick action buttons.
- **Buttons**:
  1. **Ring Phone**: Icon `bell-symbolic`. Calls `kdeconnect-cli -d <id> --ring`.
  2. **Send File**: Icon `folder-symbolic`. Calls `scripts/share_file.sh <id>`.
  3. **Push Clipboard**: Icon `clipboard-symbolic`. Reads Wayland clipboard via `wl-paste` and sends to phone.
  4. **Send Ping**: Icon `paper-plane-symbolic`. Sends test ping notification.

---

### 2.6 `components/CommandRunner.qml`
- **Role**: ListView displaying remote execution commands configured on user's phone.
- **Behavior**:
  - Runs `kdeconnect-cli -d <id> --list-commands` on popover open.
  - Parses command keys and labels into interactive QML chips.
  - Clicking a chip executes `kdeconnect-cli -d <id> --execute-command <key>`.

---

### 2.7 `scripts/share_file.sh`
- **Role**: Helper script for launching file chooser dialog on Wayland.
- **Code Logic**:
```bash
#!/usr/bin/env bash
DEVICE_ID="$1"
FILE=$(kdialog --getopenfilename ~ "Select File to Share" 2>/dev/null || zenity --file-selection 2>/dev/null)
if [ -n "$FILE" ]; then
    kdeconnect-cli -d "$DEVICE_ID" --share "$FILE"
fi
```
