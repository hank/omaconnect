import QtQuick
import QtQuick.Layouts
Item {
    id: root

    property bool isConnected: false
    property bool daemonAvailable: true
    property bool sessionBusAvailable: true
    property var allDevices: []
    property var connectedDevices: []
    property var activeDevice: null
    property string statusMessage: ""
    property bool isOpen: false
    property var pairingStates: ({})
    property var notifications: []
    property var actionRunner: null

    function getPairingState(deviceId) {
        if (!deviceId || !pairingStates) return "idle";
        return pairingStates[deviceId] || "idle";
    }

    signal closeRequested()
    signal refreshRequested()
    signal deviceSelected(var device)
    signal ringDeviceRequested(string deviceId)
    signal pingDeviceRequested(string deviceId)
    signal shareTextRequested(string deviceId, string text)
    signal pairDeviceRequested(string deviceId)
    signal unpairDeviceRequested(string deviceId)
    signal dismissNotificationRequested(string notificationId)
    signal clearAllNotificationsRequested()


    onIsOpenChanged: {
        if (root.isOpen) {
            cardContainer.forceActiveFocus();
        }
    }

    implicitWidth: 360
    implicitHeight: Math.min(600, cardContainer.implicitHeight)
    width: parent ? parent.width : implicitWidth

    Rectangle {
        id: cardContainer
        width: root.width
        implicitHeight: mainHeaderColumn.implicitHeight + scrollArea.implicitHeight + 32
        color: Theme.bgGlass
        radius: Theme.radiusMd
        border.color: Theme.borderSubtle
        border.width: 1
        activeFocusOnTab: true
        focus: root.isOpen

        Keys.onEscapePressed: root.closeRequested()

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            // Header Section
            ColumnLayout {
                id: mainHeaderColumn
                Layout.fillWidth: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RowLayout {
                        spacing: 8
                        Text {
                            text: "📱"
                            font.pixelSize: 18
                        }
                        Text {
                            text: "OmaConnect"
                            font.pixelSize: 16
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Device Count Badge
                    Rectangle {
                        visible: root.allDevices.length > 0
                        implicitWidth: countText.implicitWidth + 10
                        implicitHeight: 20
                        radius: 10
                        color: root.isConnected ? Qt.rgba(0.06, 0.73, 0.51, 0.15) : Qt.rgba(0.96, 0.62, 0.04, 0.15)
                        border.color: root.isConnected ? Theme.accentSuccess : Theme.accentWarning

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: root.connectedDevices.length + "/" + root.allDevices.length + " Online"
                            font.pixelSize: 10
                            font.bold: true
                            color: root.isConnected ? Theme.accentSuccess : Theme.accentWarning
                        }
                    }

                    // Refresh Button
                    Rectangle {
                        id: refreshBtn
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        activeFocusOnTab: true
                        focus: true
                        color: (refreshMouse.containsMouse || refreshBtn.activeFocus) ? Theme.bgSurfaceHover : Theme.bgSurface
                        border.color: refreshBtn.activeFocus ? Theme.borderActive : Theme.borderSubtle
                        border.width: refreshBtn.activeFocus ? 2 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "🔄"
                            font.pixelSize: 12
                        }

                        Keys.onReturnPressed: root.refreshRequested()
                        Keys.onSpacePressed: root.refreshRequested()

                        MouseArea {
                            id: refreshMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refreshRequested()
                        }
                    }

                    // Close Button
                    Rectangle {
                        id: closeBtn
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        activeFocusOnTab: true
                        focus: true
                        color: (closeMouse.containsMouse || closeBtn.activeFocus) ? Theme.bgSurfaceHover : Theme.bgSurface
                        border.color: closeBtn.activeFocus ? Theme.borderActive : Theme.borderSubtle
                        border.width: closeBtn.activeFocus ? 2 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 12
                            color: Theme.textSecondary
                        }

                        Keys.onReturnPressed: root.closeRequested()
                        Keys.onSpacePressed: root.closeRequested()

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Theme.borderSubtle
                }
            }

            // Scrollable Content Area for Narrow Viewports
            Flickable {
                id: scrollArea
                Layout.fillWidth: true
                implicitHeight: Math.min(500, bodyLayout.implicitHeight)
                contentWidth: width
                contentHeight: bodyLayout.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: bodyLayout
                    width: scrollArea.width
                    spacing: 12

                    // --- State 1: Daemon / Dependencies / D-Bus Unavailable ---
                    ColumnLayout {
                        visible: !root.daemonAvailable || !root.sessionBusAvailable
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: errorColumn.implicitHeight + 20
                            color: Qt.rgba(0.94, 0.38, 0.38, 0.12)
                            radius: Theme.radiusSm
                            border.color: Theme.accentDanger
                            border.width: 1

                            ColumnLayout {
                                id: errorColumn
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                Text {
                                    text: !root.sessionBusAvailable ? "⚠️ D-Bus Session Unavailable" : "⚠️ KDE Connect Daemon Missing / Offline"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: Theme.accentDanger
                                }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: root.statusMessage !== "" ? root.statusMessage : "Please ensure kdeconnect is installed and kdeconnectd is running on your session bus."
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }

                    // --- State 2: Daemon active, but ZERO devices paired or connected ---
                    ColumnLayout {
                        visible: root.daemonAvailable && root.sessionBusAvailable && root.allDevices.length === 0
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: emptyColumn.implicitHeight + 20
                            color: Theme.bgSurface
                            radius: Theme.radiusSm
                            border.color: Theme.borderSubtle
                            border.width: 1

                            ColumnLayout {
                                id: emptyColumn
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                Text {
                                    text: "📲 No Devices Found"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: Theme.textPrimary
                                }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: "Pair your Android or iOS device using the KDE Connect app on your local Wi-Fi network."
                                    font.pixelSize: 12
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }

                    // --- State 3 & 4: Paired Devices Exist (Reachable or Unreachable) ---
                    ColumnLayout {
                        visible: root.daemonAvailable && root.sessionBusAvailable && root.allDevices.length > 0
                        Layout.fillWidth: true
                        spacing: 12

                        // Offline Notice Banner (If paired devices exist but none are currently reachable)
                        Rectangle {
                            visible: !root.isConnected
                            Layout.fillWidth: true
                            implicitHeight: offlineNoticeColumn.implicitHeight + 16
                            color: Qt.rgba(0.96, 0.62, 0.04, 0.12)
                            radius: Theme.radiusSm
                            border.color: Theme.accentWarning
                            border.width: 1

                            ColumnLayout {
                                id: offlineNoticeColumn
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4

                                Text {
                                    text: "📶 Device Unreachable"
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    color: Theme.accentWarning
                                }

                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                    text: root.statusMessage !== "" ? root.statusMessage : "Paired device found, but not reachable on network."
                                    font.pixelSize: 11
                                    color: Theme.textSecondary
                                }
                            }
                        }

                        // Device Picker Selector
                        DevicePicker {
                            id: devicePicker
                            devices: root.allDevices
                            activeDevice: root.activeDevice
                            Layout.fillWidth: true
                            onDeviceSelected: device => root.deviceSelected(device)
                        }

                        // Selected Active Device Card with Action Signals
                        DeviceCard {
                            id: deviceCard
                            device: root.activeDevice
                            pairingState: root.getPairingState(root.activeDevice ? root.activeDevice.id : "")
                            Layout.fillWidth: true
                            onRingRequested: deviceId => root.ringDeviceRequested(deviceId)
                            onPingRequested: deviceId => root.pingDeviceRequested(deviceId)
                            onPairRequested: deviceId => root.pairDeviceRequested(deviceId)
                            onUnpairRequested: deviceId => root.unpairDeviceRequested(deviceId)
                        }

                        // Quick Actions Grid (Ring Phone, Send File, Send Ping)
                        ActionGrid {
                            id: actionGrid
                            activeDevice: root.activeDevice
                            actionRunner: root.actionRunner
                            Layout.fillWidth: true
                        }

                        // Remote Device Commands Runner
                        CommandRunner {
                            id: commandRunner
                            activeDevice: root.activeDevice
                            actionRunner: root.actionRunner
                            Layout.fillWidth: true
                        }

                        // Incoming Phone Notifications Feed
                        NotificationFeed {
                            id: notificationFeed
                            notifications: root.notifications
                            Layout.fillWidth: true
                            onDismissRequested: notificationId => root.dismissNotificationRequested(notificationId)
                            onClearAllRequested: () => root.clearAllNotificationsRequested()
                        }
                    }
                }
            }
        }
    }
}
