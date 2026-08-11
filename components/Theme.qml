pragma Singleton
import QtQuick

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
    readonly property color accentDanger: "#ef4444"   // Red (Battery <= 20%)

    // Glassmorphism & Radii
    readonly property real radiusSm: 6
    readonly property real radiusMd: 12
    readonly property real radiusLg: 16
    readonly property real backdropBlur: 20

    // Motion & Animation Constants
    property bool animationsEnabled: true
    readonly property int animDurationFast: animationsEnabled ? 120 : 0
    readonly property int animDurationNormal: animationsEnabled ? 150 : 0
    readonly property int animDurationSlow: animationsEnabled ? 300 : 0
    readonly property int easingTypeCubic: Easing.OutCubic
    readonly property int easingTypeBack: Easing.OutBack

    function getBatteryColor(percentage, isCharging) {
        if (isCharging) return accentSuccess;
        if (percentage <= 20) return accentDanger;
        if (percentage <= 45) return accentWarning;
        return accentSuccess;
    }
}
