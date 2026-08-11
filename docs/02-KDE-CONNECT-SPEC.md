# 02. KDE Connect API & Protocol Specification

This document provides a comprehensive reference of the D-Bus interfaces and CLI tool commands exposed by `kdeconnectd` for use by OmaConnect.

---

## 1. D-Bus Interface Specifications

Service Bus Name: `org.kde.kdeconnect`

### 1.1 Daemon Interface (`/modules/kdeconnect`)
- **Bus Object Path**: `/modules/kdeconnect`
- **Interface**: `org.kde.kdeconnect.daemon`

#### Methods:
| Method Name | Parameters | Return Type | Description |
| :--- | :--- | :--- | :--- |
| `devices` | `onlyReachable: bool, onlyPaired: bool` | `Array of String` (Device IDs) | List connected or paired device IDs |
| `deviceNames` | `onlyReachable: bool, onlyPaired: bool` | `Dict of String->String` | Map of `DeviceId -> DeviceName` |
| `forceOnNetworkChange` | None | `void` | Force redetection of devices on current network |

#### Signals:
| Signal Name | Arguments | Description |
| :--- | :--- | :--- |
| `deviceAdded` | `id: String` | Fired when a new device is discovered on local Wi-Fi |
| `deviceRemoved` | `id: String` | Fired when a device leaves local network |
| `deviceVisibilityChanged` | `id: String, visible: bool` | Fired when connection state changes |

---

### 1.2 Device Interface (`/modules/kdeconnect/devices/<DEVICE_ID>`)
- **Bus Object Path**: `/modules/kdeconnect/devices/<DEVICE_ID>`
- **Interface**: `org.kde.kdeconnect.device`

#### Properties:
| Property Name | Type | Description |
| :--- | :--- | :--- |
| `name` | `String` | Device display name (e.g. "Pixel 8 Pro") |
| `type` | `String` | Device category (`phone`, `tablet`, `laptop`) |
| `isReachable` | `bool` | `true` if connected on local network |
| `isPaired` | `bool` | `true` if paired with desktop |
| `hasPairRequests` | `bool` | `true` if phone is actively requesting pairing |

#### Methods:
| Method Name | Parameters | Return Type | Description |
| :--- | :--- | :--- | :--- |
| `requestPair` | None | `void` | Send pair request to phone |
| `unpair` | None | `void` | Remove pairing |
| `ping` | `message: String` | `void` | Send notification ping to phone |

---

### 1.3 Plugin Interfaces per Device

#### A. Battery Plugin (`.../devices/<DEVICE_ID>/battery`)
- **Interface**: `org.kde.kdeconnect.device.battery`
- **Signals**:
  - `chargeChanged(int charge)`: Fired when battery percentage changes.
  - `stateChanged(bool isCharging)`: Fired when charging plug is connected/disconnected.
- **Methods**:
  - `charge()` -> `int` (Returns 0–100)
  - `isCharging()` -> `bool`

#### B. Find My Phone (`.../devices/<DEVICE_ID>/findmyphone`)
- **Interface**: `org.kde.kdeconnect.device.findmyphone`
- **Methods**:
  - `ring()` -> `void`: Rings phone at maximum volume until cancelled.

#### C. Share Plugin (`.../devices/<DEVICE_ID>/share`)
- **Interface**: `org.kde.kdeconnect.device.share`
- **Methods**:
  - `shareUrl(String url)` -> `void`: Open link on phone.
  - `shareText(String text)` -> `void`: Send text string / clipboard to phone.

#### D. Remote Commands (`.../devices/<DEVICE_ID>/remotecommands`)
- **Interface**: `org.kde.kdeconnect.device.remotecommands`
- **Methods**:
  - `commandList()` -> `String` (JSON string of configured commands)
  - `runCommand(String key)` -> `void`: Execute script on mobile device.

---

## 2. `kdeconnect-cli` Command Reference

When D-Bus calls are executed via process wrappers in QML, `kdeconnect-cli` provides standard flags:

```bash
# List all connected devices
kdeconnect-cli -l

# Output format example:
# - Pixel 8 Pro: 3a9f02123abcd (reachable and paired)
# - iPad Air: 994827104bdef (reachable)
# 2 devices found

# List only device IDs & names in machine-friendly format
kdeconnect-cli -a --name-only

# Ring phone
kdeconnect-cli -d <DEVICE_ID> --ring

# Send file
kdeconnect-cli -d <DEVICE_ID> --share /path/to/photo.jpg

# Send URL / text
kdeconnect-cli -d <DEVICE_ID> --share-text "https://omarchyplugins.com"

# Send ping
kdeconnect-cli -d <DEVICE_ID> --ping-msg "Hello from Omarchy!"

# List remote commands
kdeconnect-cli -d <DEVICE_ID> --list-commands

# Execute remote command
kdeconnect-cli -d <DEVICE_ID> --execute-command <COMMAND_KEY>
```

---

## 3. Real-Time D-Bus Monitor Command Strategy

In QML via `Quickshell.Io.Process`, real-time updates are streamed using:

```bash
dbus-monitor --session "type='signal',sender='org.kde.kdeconnect'"
```

Parsing stdout line-by-line using QML's `DataStreamParser` allows immediate UI reaction to:
- `chargeChanged` -> Updates `BatteryBar.qml` percentage without polling.
- `stateChanged` -> Toggles charging icon in top bar and popover.
- `deviceVisibilityChanged` -> Updates `BarButton.qml` device counter badge.
