import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property var devices: []
    property var activeDevice: null
    property bool expanded: false

    signal deviceSelected(var device)

    implicitWidth: parent ? parent.width : 320
    implicitHeight: containerColumn.implicitHeight + 16

    radius: Theme.radiusSm
    color: Theme.bgSurface
    border.color: Theme.borderSubtle
    border.width: 1

    ColumnLayout {
        id: containerColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        // Dropdown Header Row
        Rectangle {
            id: headerButton
            Layout.fillWidth: true
            implicitHeight: 32
            radius: Theme.radiusSm
            activeFocusOnTab: root.devices.length > 1
            focus: true
            color: (headerMouse.containsMouse || headerButton.activeFocus) ? Theme.bgSurfaceHover : "transparent"
            border.color: headerButton.activeFocus ? Theme.borderActive : "transparent"
            border.width: headerButton.activeFocus ? 2 : 0

            Keys.onReturnPressed: {
                if (root.devices.length > 1) root.expanded = !root.expanded;
            }
            Keys.onSpacePressed: {
                if (root.devices.length > 1) root.expanded = !root.expanded;
            }

            Behavior on color {
                ColorAnimation { duration: Theme.animDurationFast }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: "📱"
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "Target Device:"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Theme.textSecondary
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: root.activeDevice ? root.activeDevice.name : (root.devices.length > 0 ? "Select Device" : "No Devices")
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: root.activeDevice ? Theme.textPrimary : Theme.textMuted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                // Count badge
                Rectangle {
                    visible: root.devices.length > 0
                    implicitWidth: countLabel.implicitWidth + 8
                    implicitHeight: 16
                    radius: 8
                    color: Qt.rgba(0.23, 0.51, 0.96, 0.2)
                    border.color: Theme.accentPrimary
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: root.devices.length.toString()
                        font.pixelSize: 10
                        font.bold: true
                        color: Theme.accentPrimary
                    }
                }

                // Toggle Arrow
                Text {
                    visible: root.devices.length > 1
                    text: root.expanded ? "▲" : "▼"
                    font.pixelSize: 10
                    color: Theme.textSecondary
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            MouseArea {
                id: headerMouse
                anchors.fill: parent
                hoverEnabled: root.devices.length > 1
                cursorShape: root.devices.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.devices.length > 1) {
                        root.expanded = !root.expanded;
                    }
                }
            }
        }

        // Expanded Device List
        ColumnLayout {
            id: deviceListColumn
            visible: root.expanded || (root.devices.length > 0 && root.devices.length <= 2)
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.devices

                delegate: Rectangle {
                    id: itemRow
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Theme.radiusSm
                    activeFocusOnTab: true
                    focus: true

                    property bool isActive: root.activeDevice && root.activeDevice.id === modelData.id
                    color: (itemMouse.containsMouse || itemRow.activeFocus) ? Theme.bgSurfaceHover : (isActive ? Qt.rgba(0.23, 0.51, 0.96, 0.15) : "transparent")
                    border.color: itemRow.activeFocus ? Theme.borderActive : (isActive ? Theme.borderActive : "transparent")
                    border.width: itemRow.activeFocus ? 2 : 1

                    Keys.onReturnPressed: {
                        root.deviceSelected(modelData);
                        if (root.devices.length > 2) root.expanded = false;
                    }
                    Keys.onSpacePressed: {
                        root.deviceSelected(modelData);
                        if (root.devices.length > 2) root.expanded = false;
                    }

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDurationFast }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        // Status Dot (Green for paired & reachable, Amber for paired & offline, Muted Gray for unpaired)
                        Rectangle {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: !modelData.paired ? Theme.textMuted : (modelData.reachable ? Theme.accentSuccess : Theme.accentWarning)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Device Icon
                        Text {
                            text: modelData.type === "laptop" || modelData.type === "desktop" ? "💻" : "📱"
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Device Name
                        Text {
                            text: modelData.name || "Unknown Device"
                            font.pixelSize: 12
                            font.weight: isActive ? Font.Bold : Font.Normal
                            color: isActive ? Theme.textPrimary : Theme.textSecondary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Unpaired Tag Badge
                        Rectangle {
                            visible: !modelData.paired
                            implicitWidth: unpairedTagText.implicitWidth + 8
                            implicitHeight: 16
                            radius: Theme.radiusSm
                            color: Qt.rgba(0.5, 0.5, 0.5, 0.15)
                            border.color: Theme.borderSubtle
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                id: unpairedTagText
                                anchors.centerIn: parent
                                text: "Unpaired"
                                font.pixelSize: 9
                                font.weight: Font.Medium
                                color: Theme.textMuted
                            }
                        }

                        // Status Label
                        Text {
                            text: !modelData.paired ? "Unpaired" : (modelData.reachable ? "Reachable" : "Offline")
                            font.pixelSize: 10
                            color: !modelData.paired ? Theme.textMuted : (modelData.reachable ? Theme.accentSuccess : Theme.textMuted)
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Checkmark if active
                        Text {
                            visible: isActive
                            text: "✓"
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.accentPrimary
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.deviceSelected(modelData);
                            if (root.devices.length > 2) {
                                root.expanded = false;
                            }
                        }
                    }
                }
            }
        }

        // Empty state when devices array is empty
        Rectangle {
            visible: root.devices.length === 0
            Layout.fillWidth: true
            implicitHeight: 36
            color: "transparent"

            RowLayout {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: "🔍"
                    font.pixelSize: 12
                }

                Text {
                    text: "No paired or reachable devices"
                    font.pixelSize: 11
                    color: Theme.textMuted
                }
            }
        }
    }
}
