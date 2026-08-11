# OmaConnect

OmaConnect is a native Omarchy bar plugin that integrates KDE Connect device state and control into the Quickshell desktop environment. It consists of a single manifest (`manifest.json`), a shared headless service (`Service.qml`), a D-Bus device controller (`KdeConnectController.qml`), and a per-monitor panel widget (`BarWidget.qml`).

## Core Capabilities

- **Device State Monitoring**: Continuously tracks paired status, reachability, battery percentage, and charging state via D-Bus properties, applying Omarchy design tokens dynamically.
- **Pairing Management**: Unified list of all enumerated devices with inline pairing controls. Unpairing requests require a strict two-step confirmation prompt.
- **Action Dispatch**: Provides controls for Ring, Send Clipboard, Send File (using native `xdg-desktop-portal` file pickers), Ping, and Text Share. Actions are capability-gated, meaning only plugins actively supported by the remote device are presented.
- **Remote Commands**: Collapsible, on-demand drawer that enumerates and executes remote commands configured on the target device.
- **Keyboard Navigation**: Fully keyboard-accessible panel with vim-style bindings and dedicated hotkeys for primary actions.

## Security & Architecture

OmaConnect is designed with strict boundaries and process isolation:

- **Shell Injection Prevention**: All external commands are executed using strict array arguments (e.g., `Process.command = ["kdeconnect-cli", "-d", id, ...]`). Target IDs, clipboard contents, and file paths are never interpolated into raw shell strings.
- **Async State Consistency**: Asynchronous D-Bus scans and action requests track target generation counters. Stale completions from previous scans or rapidly switched devices are silently dropped, preventing race conditions in the UI state.
- **Error Handling**: Non-zero process exits are mapped to concise user-facing error categories (e.g., "unavailable", "rejected", "timed out") without dumping raw standard error output to the shell.
- **Privacy Boundaries**: OmaConnect strictly interfaces with the local user session D-Bus and `kdeconnect-cli`. It does not parse, store, or intercept notification payloads or SMS content.

## Keyboard Shortcuts

The panel supports complete navigation without a mouse:

| Key Binding                | Action                                                      |
| :------------------------- | :---------------------------------------------------------- |
| `h`, `l` / `Left`, `Right` | Switch focus between Devices, Actions, and Remote Commands  |
| `j`, `k` / `Down`, `Up`    | Navigate items within the currently focused section         |
| `Enter`, `Space`           | Activate the focused item or submit the active composer     |
| `p`                        | Pair the currently selected device                          |
| `u`                        | Request unpair confirmation for the selected device         |
| `y`, `c` / `Esc`           | Confirm (`y`) or cancel (`c`/`Esc`) an active unpair prompt |
| `r`                        | Force a manual refresh of D-Bus properties                  |
| `Esc`                      | Close the active composer or hide the panel                 |

## Dependencies

OmaConnect relies on the following system packages:

- `kdeconnect` (provides `kdeconnect-cli` and the `kdeconnectd` session daemon)
- `glib2` (provides `gdbus` for state queries)
- `dbus` (provides `dbus-monitor` for real-time daemon signals)

On Omarchy/Arch, install them via:

```bash
omarchy-pkg-add kdeconnect glib2 dbus
```

If the KDE Connect daemon is not running or unavailable, the plugin falls back gracefully and reports "KDE Connect unavailable" rather than failing to load.

## Installation & Configuration

### Using the Plugin Manager

```bash
omarchy-plugin-add https://github.com/jitendradara12/omaconnect
```

### Manual Installation

Clone this repository into the standard Omarchy plugins directory:

```bash
git clone https://github.com/jitendradara12/omaconnect ~/.config/omarchy/plugins/omaconnect
omarchy-restart-shell
```

### IPC Controls

OmaConnect can be toggled externally via Omarchy's IPC:

```bash
omarchy-shell ipc call omaconnect toggle
omarchy-shell ipc call omaconnect open
omarchy-shell ipc call omaconnect close
```

## Testing & Validation

OmaConnect ships with a Python-based test suite that verifies state transitions, JSON parsing, and capability detection.

```bash
# Run unit tests, shell syntax checks, and QML linting
bash scripts/validate.sh

# Run the strict Omarchy plugin manifest validator
/home/sastauser/code/temp/omarchy/bin/omarchy-plugin-validate .
```
