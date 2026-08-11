# OmaConnect

OmaConnect is a native Omarchy bar plugin that integrates KDE Connect device state and control into the Quickshell desktop environment. It consists of a single manifest (`manifest.json`), a shared headless service (`Service.qml`), a D-Bus device controller (`KdeConnectController.qml`), and a per-monitor panel widget (`BarWidget.qml`).
<img width="468" height="425" alt="image" src="https://github.com/user-attachments/assets/1a225f83-ec1b-4827-a200-0e29f531f0ed" />
<img width="455" height="430" alt="image" src="https://github.com/user-attachments/assets/af30d475-7d46-4bd8-81f8-7284c1b7c1c6" />

## Panel Experience & UX Hierarchy

Opening OmaConnect presents one clean, cohesive layout hierarchy:

1. **Header Overview**: Identifies the currently selected device name, displays its paired & reachable status **once** in plain language ("Paired & reachable", "Paired, offline", "Not paired"), and shows battery percentage and charging state with Omarchy theme tokens (`Color.urgent` for low battery, `Color.accent` for charging). Includes a quick refresh button.
2. **Device Selection & Pairing Management**: A unified device list showing all enumerated devices with status indicators (`●` for reachable, `Offline` for paired offline). Unpaired devices display an inline **Pair** button; paired devices display an inline **Unpair** button with a safe two-step inline confirmation ("Confirm?" / **Confirm** / **Cancel**).
3. **Primary Device Actions**: Action controls for **Ring** (Find My Phone), **Clipboard** (Send Clipboard), **File** (Send File), **Ping** (Send Ping message), and **Text** (Share text/link). Actions are strictly capability-gated: only actions supported by the selected device's active KDE Connect plugins are visible. Unsupported or unreachable devices display no dead buttons or empty gaps.
4. **Focused Composer Input Drawers**: Temporary inline overlays for Ping and Text Share. Entering text and pressing **Enter** submits the request; **Escape** or **Cancel** closes the composer and returns focus to the action row. Empty or whitespace-only inputs are blocked with immediate local validation feedback. Switching device selection resets composer drafts.
5. **Secondary Remote Commands**: A collapsible on-demand drawer for Remote Commands (`kdeconnect-cli --list-commands`). Commands are fetched only when the section is expanded or refreshed by the user, keeping the initial panel lightweight. If no commands are configured, it displays "No remote commands configured".

## Keyboard Navigation & Shortcuts

OmaConnect provides complete keyboard accessibility across all panel sections:

- **Panel Toggle**: `omaconnect` IPC (`open`, `close`, `show`, `hide`, `toggle`) or bar button activation.
- **Section Navigation**: `l` / `Right` or `h` / `Left` cycles focus between `DEVICES`, `ACTIONS`, and `REMOTE COMMANDS` sections and steps through individual primary action buttons.
- **Item Navigation**: `j` / `Down` or `k` / `Up` moves selection within the device list, primary actions row, or expanded remote commands list.
- **Activation**: `Enter` or `Space` activates the currently focused item (selects device, triggers pair/unpair confirm, executes primary action, or toggles/executes remote command).
- **Pairing Shortcuts** (in `DEVICES` section):
  - `p`: Send pair request for selected unpaired device.
  - `u`: Request unpair confirmation for selected paired device.
  - `y`: Confirm unpairing when confirmation prompt is active.
  - `c` or `Esc`: Cancel unpairing when confirmation prompt is active.
- **Composer Controls**:
  - `Enter`: Submit valid ping message or text share.
  - `Esc`: Close composer overlay and return focus to key catcher.
- **Global Actions**:
  - `r`: Refresh device discovery snapshot and D-Bus properties.

## Safety & "Request Accepted" Semantics

- **Single-Flight & Generation Guarding**: All asynchronous D-Bus and process calls track target device ID and generation counters. Stale completions from previous scans or device selections are silently ignored.
- **"Request Accepted" Semantics**: Success messages (e.g., "Ping request accepted", "Ring request accepted", "File-transfer request accepted", "Pairing request accepted") explicitly indicate that the local request was successfully handed to KDE Connect. They do not claim remote completion or phone confirmation.
- **Error Categorization**: Non-zero process exits are mapped to concise user-facing error categories (e.g., "unavailable", "rejected", "timed out") without dumping raw process stderr.
- **Safe Execution & Path Handling**: Device IDs, clipboard values, and file paths are passed using structured argument arrays (`Process.command = [...]`) to prevent shell injection vulnerabilities. File URI paths are decoded and sanitized; cancellation in the native file picker is handled gracefully without error.
- **Privacy Boundaries**: OmaConnect does not store, read, or process notification payloads or SMS content. All interactions occur locally over the user session D-Bus bus or `kdeconnect-cli`.

## Dependencies

- Omarchy desktop environment and Quickshell shell.
- `gdbus`, `sed`, `grep`, `tr`, `kdeconnect-cli`.
- A running `kdeconnectd` session daemon.

If KDE Connect is unavailable, the UI reports "KDE Connect unavailable" rather than displaying an empty device list.

## Installation & Operation

Place this directory at `~/.config/omarchy/plugins/omaconnect` or layout directory, add `omaconnect` to your Omarchy topbar layout, and run `omarchy-restart-shell`.

IPC commands:
```bash
omarchy-shell ipc call omaconnect toggle
omarchy-shell ipc call omaconnect open
omarchy-shell ipc call omaconnect close
```

## Verification & Testing

To run the complete automated test suite and plugin validation checks:

```bash
# Deterministic unit tests, shell syntax, plugin validator, and QML linting
bash scripts/validate.sh

# Run installed Omarchy plugin validator directly
/home/sastauser/code/temp/omarchy/bin/omarchy-plugin-validate .

# Live rescan check (if shell is running)
OMARCHY_PATH=/home/sastauser/code/temp/omarchy /home/sastauser/code/temp/omarchy/bin/omarchy-shell shell rescanPlugins
```
