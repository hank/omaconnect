# 03. Quickshell & QML UI Design Patterns

This document details the code standards, QML components, styling tokens, and interaction patterns required for building OmaConnect in Quickshell.

---

## 1. Quickshell Architecture & Core QML Types

Quickshell extends Qt 6 QML with desktop shell primitives:

### Key Quickshell Modules:
- `import Quickshell`: Core engine (`Scope`, `PanelWindow`, `Variants`).
- `import Quickshell.Io`: I/O primitives (`Process`, `DataStreamParser`, `FileWatcher`).
- `import Quickshell.Hyprland`: Hyprland window manager integration.
- `import Quickshell.Widgets`: System tray, popups, menus.

### Recommended `Process` Invocation Pattern:
```qml
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string deviceId: ""
    property bool isRinging: false

    Process {
        id: ringProcess
        command: ["kdeconnect-cli", "-d", root.deviceId, "--ring"]
        running: false
        
        onExited: (exitCode, exitStatus) => {
            console.log("Ring process completed with code:", exitCode)
            root.isRinging = false
        }
    }

    function triggerRing() {
        root.isRinging = true
        ringProcess.running = true
    }
}
```

---

## 2. Omarchy Visual Design System Tokens

OmaConnect strictly follows Omarchy's dark glassmorphism aesthetic:

### 2.1 Palette Tokens (Dark Mode Baseline)
```qml
QtObject {
    id: theme

    // Backgrounds
    readonly property color bgBase: "#0d0f12"
    readonly property color bgSurface: "#16191f"
    readonly property color bgSurfaceHover: "#212630"
    readonly property color bgGlass: "#cc12151b" // Translucent dark for popover

    // Borders & Separators
    readonly property color borderSubtle: "#2a303c"
    readonly property color borderActive: "#3b82f6"

    // Text & Foregrounds
    readonly property color textPrimary: "#f3f4f6"
    readonly property color textSecondary: "#9ca3af"
    readonly property color textMuted: "#6b7280"

    // Accents & State Colors
    readonly property color accentPrimary: "#3b82f6"  // Blue accent
    readonly property color accentSuccess: "#10b981"  // Green (Battery > 50%)
    readonly property color accentWarning: "#f59e0b"  // Amber (Battery 20-50%)
    readonly property color accentDanger: "#ef4444"   // Red (Battery < 20%)

    // Glassmorphism & Radii
    readonly property real radiusSm: 6
    readonly property real radiusMd: 12
    readonly property real radiusLg: 16
    readonly property real backdropBlur: 20
}
```

---

## 3. Dynamic HSL Battery Color Mapping

To compute battery bar color dynamically in QML based on percentage:

```qml
function getBatteryColor(percentage, isCharging) {
    if (isCharging) return theme.accentSuccess;
    if (percentage <= 20) return theme.accentDanger;
    if (percentage <= 45) return theme.accentWarning;
    return theme.accentSuccess;
}
```

---

## 4. UI Layout & Micro-Animations

### 4.1 Hover Micro-Interactions
Every interactive button should specify smooth scale/opacity transitions:

```qml
Rectangle {
    id: button
    color: mouseArea.containsMouse ? theme.bgSurfaceHover : theme.bgSurface
    radius: theme.radiusSm
    
    Behavior on color {
        ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    scale: mouseArea.pressed ? 0.96 : (mouseArea.containsMouse ? 1.02 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutBack }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }
}
```

### 4.2 Popover Window Anchoring
The popover dropdown window attaches directly to the `BarButton` anchor in Quickshell:

```qml
PanelWindow {
    id: popover
    visible: false
    color: "transparent"
    
    // Positioning relative to Topbar
    anchors {
        top: barButton.bottom
        right: barButton.right
        topMargin: 8
    }

    width: 320
    height: contentColumn.implicitHeight + 32

    Rectangle {
        anchors.fill: parent
        color: theme.bgGlass
        radius: theme.radiusMd
        border.color: theme.borderSubtle
        border.width: 1
    }
}
```
