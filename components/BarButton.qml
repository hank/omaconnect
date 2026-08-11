import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property int activeDeviceCount: 0
    property int lowestBattery: -1
    property bool isConnected: false
    property bool daemonAvailable: true
    property bool isPopoverOpen: false
    property var activeDevice: null

    signal clicked()

    implicitWidth: mainRow.implicitWidth + 24
    implicitHeight: 36

    activeFocusOnTab: true
    focus: true

    radius: Theme.radiusSm
    color: (mouseArea.containsMouse || root.activeFocus) ? Theme.bgSurfaceHover : (root.isPopoverOpen ? Theme.bgSurfaceHover : Theme.bgSurface)
    border.color: (root.activeFocus || root.isPopoverOpen) ? Theme.borderActive : Theme.borderSubtle
    border.width: root.activeFocus ? 2 : 1

    Keys.onReturnPressed: root.clicked()
    Keys.onSpacePressed: root.clicked()

    Behavior on color {
        ColorAnimation { duration: Theme.animDurationNormal; easing.type: Theme.easingTypeCubic }
    }

    scale: mouseArea.pressed ? 0.96 : ((mouseArea.containsMouse || root.activeFocus) ? 1.02 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: Theme.animDurationFast; easing.type: Theme.easingTypeBack }
    }

    RowLayout {
        id: mainRow
        anchors.centerIn: parent
        spacing: 8

        // Status / Phone Icon
        Text {
            text: !root.daemonAvailable ? "⚠️" : (root.isConnected ? "📱" : "📲")
            font.pixelSize: 14
            color: !root.daemonAvailable ? Theme.accentWarning : (root.isConnected ? Theme.accentPrimary : Theme.textMuted)
            Layout.alignment: Qt.AlignVCenter
        }

        // Title or Active Device Name Text
        Text {
            text: !root.daemonAvailable ? "OmaConnect (Daemon Offline)" : (root.isConnected ? (root.activeDevice && root.activeDevice.name ? root.activeDevice.name : "OmaConnect") : "OmaConnect (Disconnected)")
            font.pixelSize: 13
            font.weight: Font.Medium
            color: !root.daemonAvailable ? Theme.accentWarning : (root.isConnected ? Theme.textPrimary : Theme.textSecondary)
            Layout.alignment: Qt.AlignVCenter
        }

        // Active Device Count Badge
        Rectangle {
            visible: root.activeDeviceCount > 0
            implicitWidth: countText.implicitWidth + 10
            implicitHeight: 18
            radius: 9
            color: Theme.accentPrimary
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: countText
                anchors.centerIn: parent
                text: root.activeDeviceCount.toString()
                font.pixelSize: 11
                font.bold: true
                color: "#ffffff"
            }
        }

        // Battery Preview Indicator
        Rectangle {
            visible: root.isConnected && root.lowestBattery >= 0
            implicitWidth: batteryText.implicitWidth + 12
            implicitHeight: 18
            radius: 4
            color: Theme.getBatteryColor(root.lowestBattery, false)
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: batteryText
                anchors.centerIn: parent
                text: root.lowestBattery + "%"
                font.pixelSize: 10
                font.bold: true
                color: "#ffffff"
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
