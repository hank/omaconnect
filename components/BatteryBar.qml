import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property int batteryLevel: -1
    property bool isCharging: false
    property bool isReachable: true

    implicitWidth: parent ? parent.width : 280
    implicitHeight: 44

    radius: Theme.radiusSm
    color: Qt.rgba(1, 1, 1, 0.03)
    border.color: Theme.borderSubtle
    border.width: 1

    readonly property bool hasValidBattery: root.isReachable
        && root.batteryLevel !== undefined
        && root.batteryLevel !== null
        && typeof root.batteryLevel === "number"
        && !isNaN(root.batteryLevel)
        && root.batteryLevel >= 0
        && root.batteryLevel <= 100

    readonly property color barColor: root.hasValidBattery
        ? Theme.getBatteryColor(root.batteryLevel, root.isCharging)
        : Theme.textMuted

    RowLayout {
        id: mainRow
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 8

        // Icon + Percentage
        RowLayout {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.isCharging ? "⚡" : "🔋"
                font.pixelSize: 14
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.hasValidBattery ? (root.batteryLevel + "%") : "N/A"
                font.pixelSize: 13
                font.weight: Font.Bold
                color: root.barColor
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                visible: root.hasValidBattery && root.isCharging
                text: "Charging"
                font.pixelSize: 11
                color: Theme.accentSuccess
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item { Layout.fillWidth: true }

        // Progress Bar Container
        Rectangle {
            Layout.preferredWidth: 100
            Layout.preferredHeight: 8
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: Qt.rgba(0, 0, 0, 0.3)
            border.color: Theme.borderSubtle
            border.width: 1
            clip: true

            Rectangle {
                id: fillBar
                height: parent.height
                width: root.hasValidBattery ? Math.max(0, Math.min(parent.width, parent.width * (root.batteryLevel / 100.0))) : 0
                radius: 4
                color: root.barColor

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animDurationNormal
                        easing.type: Theme.easingTypeCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animDurationNormal
                    }
                }
            }
        }
    }
}
