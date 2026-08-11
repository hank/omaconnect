# 01. Architecture Overview

## 1. System Context & Runtime Target

**OmaConnect** is built specifically for **Omarchy 4 (Omarchy Quattro)** on Linux.
Omarchy Quattro uses **Quickshell**—a modern Qt 6 / QML desktop shell engine for Hyprland and Wayland compositors.

```
+-----------------------------------------------------------------------+
|                         Omarchy 4 Desktop                             |
|                                                                       |
|   +---------------------------------------------------------------+   |
|   |                  Quickshell Topbar Panel                      |   |
|   |  [ Workspace ] [ Window Title ]  ...  [ OmaConnect BarButton ]|   |
|   +---------------------------------------+-----------------------+   |
|                                           |                           |
|                                           v                           |
|                               +-----------------------+               |
|                               | PopoverWindow.qml     |               |
|                               | (Interactive Dropdown)|               |
|                               +-----------+-----------+               |
|                                           |                           |
+-------------------------------------------|---------------------------+
                                            |
                                            v (Subprocess & D-Bus)
                        +---------------------------------------+
                        |      Session Bus (D-Bus)              |
                        |      org.kde.kdeconnect               |
                        +-------------------+-------------------+
                                            |
                                            v
                        +---------------------------------------+
                        |      KDE Connect Daemon               |
                        |      (kdeconnectd)                    |
                        +-------------------+-------------------+
                                            | (Encrypted TLS Socket)
                                            v
                        +---------------------------------------+
                        |      Mobile Device (Android / iOS)    |
                        +---------------------------------------+
```

---

## 2. Key Architecture Pillars

### 2.1 UI Layer (Qt 6 / QML via Quickshell)
- **Top Bar Item (`BarButton.qml`)**: Compact item placed directly into the top bar layout. Displays phone status icon, badge counter for active devices, and battery level preview.
- **Interactive Popover (`PopoverWindow.qml`)**: Glassmorphic dark drop-down menu triggered when the user clicks the top bar item. Provides full control over connected mobile devices.
- **Theme Integration**: Uses Omarchy system tokens (dark HSL backgrounds, subtle border glows, glass backdrop blurs, and smooth micro-animations).

### 2.2 Communication Layer (Hybrid Subprocess + D-Bus)
OmaConnect avoids re-implementing the complex TLS/network socket protocol of KDE Connect (which GSConnect does for GNOME). Instead, it interfaces directly with the native Linux `kdeconnectd` daemon:

1. **One-Shot Execution (`Quickshell.Io.Process`)**:
   - Executes `kdeconnect-cli` commands asynchronously.
   - Example: `kdeconnect-cli -d <device_id> --ring` to trigger phone ringing.
   - Example: `kdeconnect-cli -d <device_id> --share <file_path>` to push files.
2. **Real-time Event Streaming (`dbus-monitor` / Session D-Bus)**:
   - Spawns background process monitoring `org.kde.kdeconnect.device` signals.
   - Captures instant battery level changes, device connection/disconnection events, and incoming SMS notifications without polling loops.

---

## 3. System Dependencies

To run OmaConnect, the following software must be present on the host system:

| Dependency | Package Name (Arch Linux) | Purpose |
| :--- | :--- | :--- |
| **Quickshell** | `quickshell-git` | QML desktop shell engine |
| **KDE Connect** | `kdeconnect` | Background daemon (`kdeconnectd`) & CLI tool (`kdeconnect-cli`) |
| **wl-clipboard** | `wl-clipboard` | Wayland clipboard read/write (`wl-copy`, `wl-paste`) |
| **File Picker** | `kdialog` / `zenity` | Native file selection dialog for file transfers |

---

## 4. Security & Privacy Safeguards

- **Local Storage**: OmaConnect stores zero credentials. Pairing keys are managed entirely by the user's `kdeconnectd` daemon in `~/.config/kdeconnect/`.
- **Explicit File Sharing**: Files are only sent when the user explicitly triggers the file chooser action.
- **Clipboard Syncing**: Clipboard text is only pushed on user click (or when explicitly enabled in user settings).
