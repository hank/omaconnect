import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: root

    property var device: null
    property string pairingState: "idle" // "idle", "pending", "accepted", "rejected", "failed"
    property bool showUnpairConfirm: false

    signal ringRequested(string deviceId)
    signal pingRequested(string deviceId)
    signal pairRequested(string deviceId)
    signal unpairRequested(string deviceId)

    onDeviceChanged: {
        showUnpairConfirm = false;
    }

    implicitWidth: parent ? parent.width : 320
    implicitHeight: mainColumn.implicitHeight + 24

    radius: Theme.radiusSm
    color: Theme.bgSurface
    border.color: (device && device.reachable && device.paired) ? Theme.borderActive : (device && device.paired ? Theme.accentWarning : Theme.borderSubtle)
    border.width: 1

    Behavior on border.color {
        ColorAnimation { duration: Theme.animDurationNormal; easing.type: Theme.easingTypeCubic }
    }

    function getDeviceIcon(type) {
        if (!type) return "📱";
        var t = type.toLowerCase();
        if (t === "tablet") return "📱";
        if (t === "laptop" || t === "desktop") return "💻";
        return "📱";
    }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        // Header Row: Type Icon + Device Name + Connection Badge
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Device Type Icon Container
            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: Theme.radiusSm
                color: (root.device && root.device.reachable && root.device.paired) ? Qt.rgba(0.23, 0.51, 0.96, 0.15) : Qt.rgba(0.61, 0.64, 0.69, 0.15)
                border.color: (root.device && root.device.reachable && root.device.paired) ? Theme.accentPrimary : Theme.borderSubtle

                Text {
                    anchors.centerIn: parent
                    text: root.device ? root.getDeviceIcon(root.device.type) : "📱"
                    font.pixelSize: 16
                }
            }

            // Name and Type label
            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                Text {
                    text: root.device ? (root.device.name || "Mobile Device") : "No Device Selected"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: root.device ? (root.device.type ? (root.device.type.charAt(0).toUpperCase() + root.device.type.slice(1)) : "Mobile Device") : "Offline"
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }
            }

            // Status Badge
            Rectangle {
                implicitWidth: badgeText.implicitWidth + 12
                implicitHeight: 20
                radius: 10
                color: root.device ? (!root.device.paired ? Theme.textMuted : (root.device.reachable ? Theme.accentSuccess : Theme.accentWarning)) : Theme.textMuted

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.device ? (!root.device.paired ? "Unpaired" : (root.device.reachable ? "Connected" : "Offline")) : "No Device"
                    font.pixelSize: 10
                    font.bold: true
                    color: "#ffffff"
                }
            }
        }

        // Offline Disconnected Active Device Banner (for paired devices)
        Rectangle {
            visible: root.device !== null && root.device.paired && !root.device.reachable
            Layout.fillWidth: true
            implicitHeight: offlineNoticeText.implicitHeight + 12
            radius: Theme.radiusSm
            color: Qt.rgba(0.96, 0.62, 0.04, 0.1)
            border.color: Theme.accentWarning
            border.width: 1

            Text {
                id: offlineNoticeText
                anchors.fill: parent
                anchors.margins: 6
                text: "⚠️ Device is offline. Reconnect to Wi-Fi to send commands."
                font.pixelSize: 11
                color: Theme.accentWarning
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Pairing Action & Outcome Banner (for unpaired devices)
        Rectangle {
            visible: root.device !== null && !root.device.paired
            Layout.fillWidth: true
            implicitHeight: pairColumn.implicitHeight + 16
            radius: Theme.radiusSm
            color: root.pairingState === "pending" ? Qt.rgba(0.23, 0.51, 0.96, 0.1) : (root.pairingState === "accepted" ? Qt.rgba(0.06, 0.73, 0.51, 0.1) : (root.pairingState === "rejected" || root.pairingState === "failed" ? Qt.rgba(0.94, 0.38, 0.38, 0.1) : Theme.bgSurfaceHover))
            border.color: root.pairingState === "pending" ? Theme.accentPrimary : (root.pairingState === "accepted" ? Theme.accentSuccess : (root.pairingState === "rejected" || root.pairingState === "failed" ? Theme.accentDanger : Theme.borderSubtle))
            border.width: 1

            ColumnLayout {
                id: pairColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: root.pairingState === "rejected" || root.pairingState === "failed" ? Theme.accentDanger : (root.pairingState === "accepted" ? Theme.accentSuccess : Theme.textSecondary)
                    text: {
                        if (root.pairingState === "pending") return "⏳ Pairing request sent. Please accept request on " + (root.device ? root.device.name : "device") + "...";
                        if (root.pairingState === "accepted") return "✅ Pairing request accepted!";
                        if (root.pairingState === "rejected") return "❌ Pairing request rejected by " + (root.device ? root.device.name : "device") + ".";
                        if (root.pairingState === "failed") return "⚠️ Pairing request failed. Device unreachable or offline.";
                        return "Device discovered on network. Pair to enable commands and sync.";
                    }
                }

                // Pair / Retry Button
                Rectangle {
                    id: pairBtn
                    visible: root.pairingState !== "pending" && root.pairingState !== "accepted"
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: pairBtnLayout.implicitWidth + 24
                    implicitHeight: 28
                    radius: Theme.radiusSm
                    activeFocusOnTab: pairBtn.visible
                    focus: true
                    color: (pairMouse.containsMouse || pairBtn.activeFocus) ? Theme.bgSurfaceHover : Theme.bgSurface
                    border.color: pairBtn.activeFocus ? Theme.borderActive : Theme.accentPrimary
                    border.width: pairBtn.activeFocus ? 2 : 1

                    Keys.onReturnPressed: {
                        if (root.device) root.pairRequested(root.device.id);
                    }
                    Keys.onSpacePressed: {
                        if (root.device) root.pairRequested(root.device.id);
                    }

                    RowLayout {
                        id: pairBtnLayout
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: root.pairingState === "rejected" || root.pairingState === "failed" ? "🔄" : "🔗"
                            font.pixelSize: 11
                        }
                        Text {
                            text: root.pairingState === "rejected" || root.pairingState === "failed" ? "Retry Pairing" : "Pair Device"
                            font.pixelSize: 11
                            font.bold: true
                            color: Theme.accentPrimary
                        }
                    }

                    MouseArea {
                        id: pairMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.device) {
                                root.pairRequested(root.device.id);
                            }
                        }
                    }
                }
            }
        }

        // Live Battery Bar Indicator
        BatteryBar {
            visible: root.device !== null && root.device.paired
            Layout.fillWidth: true
            batteryLevel: (root.device && root.device.batteryLevel !== undefined && root.device.batteryLevel !== null) ? root.device.batteryLevel : -1
            isCharging: (root.device && root.device.isCharging !== undefined && root.device.isCharging !== null) ? root.device.isCharging : false
            isReachable: root.device ? root.device.reachable : false
        }

        // Details Divider
        Rectangle {
            visible: root.device !== null
            Layout.fillWidth: true
            height: 1
            color: Theme.borderSubtle
        }

        // Details Row: Device ID
        RowLayout {
            visible: root.device !== null
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Device ID:"
                font.pixelSize: 11
                color: Theme.textMuted
            }

            Text {
                text: root.device ? (root.device.id || "") : ""
                font.pixelSize: 11
                font.family: "Monospace"
                color: Theme.textSecondary
                elide: Text.ElideMiddle
                Layout.fillWidth: true
            }
        }

        // Action Buttons Row (For paired devices)
        RowLayout {
            visible: root.device !== null && root.device.paired
            Layout.fillWidth: true
            spacing: 8

            // Ring Phone Button
            Rectangle {
                id: ringBtn
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusSm
                enabled: root.device !== null && root.device.reachable
                opacity: enabled ? 1.0 : 0.4
                activeFocusOnTab: ringBtn.enabled
                focus: true
                color: (ringMouse.containsMouse || ringBtn.activeFocus) && enabled ? Theme.bgSurfaceHover : Theme.bgSurface
                border.color: ringBtn.activeFocus ? Theme.borderActive : Theme.borderSubtle
                border.width: ringBtn.activeFocus ? 2 : 1

                Keys.onReturnPressed: {
                    if (ringBtn.enabled && root.device) root.ringRequested(root.device.id);
                }
                Keys.onSpacePressed: {
                    if (ringBtn.enabled && root.device) root.ringRequested(root.device.id);
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "🔔"
                        font.pixelSize: 11
                    }
                    Text {
                        text: "Ring Phone"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: ringBtn.enabled ? Theme.textPrimary : Theme.textMuted
                    }
                }

                MouseArea {
                    id: ringMouse
                    anchors.fill: parent
                    hoverEnabled: ringBtn.enabled
                    cursorShape: ringBtn.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        if (ringBtn.enabled && root.device) {
                            root.ringRequested(root.device.id);
                        }
                    }
                }
            }

            // Send Ping Button
            Rectangle {
                id: pingBtn
                Layout.fillWidth: true
                implicitHeight: 30
                radius: Theme.radiusSm
                enabled: root.device !== null && root.device.reachable
                opacity: enabled ? 1.0 : 0.4
                activeFocusOnTab: pingBtn.enabled
                focus: true
                color: (pingMouse.containsMouse || pingBtn.activeFocus) && enabled ? Theme.bgSurfaceHover : Theme.bgSurface
                border.color: pingBtn.activeFocus ? Theme.borderActive : Theme.borderSubtle
                border.width: pingBtn.activeFocus ? 2 : 1

                Keys.onReturnPressed: {
                    if (pingBtn.enabled && root.device) root.pingRequested(root.device.id);
                }
                Keys.onSpacePressed: {
                    if (pingBtn.enabled && root.device) root.pingRequested(root.device.id);
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "💬"
                        font.pixelSize: 11
                    }
                    Text {
                        text: "Send Ping"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: pingBtn.enabled ? Theme.textPrimary : Theme.textMuted
                    }
                }

                MouseArea {
                    id: pingMouse
                    anchors.fill: parent
                    hoverEnabled: pingBtn.enabled
                    cursorShape: pingBtn.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        if (pingBtn.enabled && root.device) {
                            root.pingRequested(root.device.id);
                        }
                    }
                }
            }
        }

        // Unpair Action Section (For paired devices)
        ColumnLayout {
            visible: root.device !== null && root.device.paired
            Layout.fillWidth: true
            spacing: 6

            // Unpair Button (when confirmation prompt is closed)
            Rectangle {
                id: unpairBtn
                visible: !root.showUnpairConfirm
                Layout.alignment: Qt.AlignRight
                implicitWidth: unpairBtnLayout.implicitWidth + 16
                implicitHeight: 26
                radius: Theme.radiusSm
                activeFocusOnTab: unpairBtn.visible
                focus: true
                color: (unpairMouse.containsMouse || unpairBtn.activeFocus) ? Qt.rgba(0.94, 0.38, 0.38, 0.15) : "transparent"
                border.color: unpairBtn.activeFocus ? Theme.borderActive : Theme.borderSubtle
                border.width: unpairBtn.activeFocus ? 2 : 1

                Keys.onReturnPressed: root.showUnpairConfirm = true
                Keys.onSpacePressed: root.showUnpairConfirm = true

                RowLayout {
                    id: unpairBtnLayout
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: "⛓️‍💥"
                        font.pixelSize: 10
                    }
                    Text {
                        text: "Unpair Device"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Theme.accentDanger
                    }
                }

                MouseArea {
                    id: unpairMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.showUnpairConfirm = true;
                    }
                }
            }

            // Inline Confirmation Box (when user clicks Unpair Device)
            Rectangle {
                id: confirmUnpairBox
                visible: root.showUnpairConfirm
                Layout.fillWidth: true
                implicitHeight: confirmColumn.implicitHeight + 16
                radius: Theme.radiusSm
                color: Qt.rgba(0.94, 0.38, 0.38, 0.1)
                border.color: Theme.accentDanger
                border.width: 1

                ColumnLayout {
                    id: confirmColumn
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 8

                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        text: "Unpair " + (root.device ? root.device.name : "this device") + "? You will need to pair again to share files and commands."
                        font.pixelSize: 11
                        color: Theme.accentDanger
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12

                        // Confirm Unpair Button
                        Rectangle {
                            id: confirmUnpairBtn
                            implicitWidth: confirmText.implicitWidth + 16
                            implicitHeight: 26
                            radius: Theme.radiusSm
                            activeFocusOnTab: confirmUnpairBox.visible
                            focus: true
                            color: (confirmUnpairMouse.containsMouse || confirmUnpairBtn.activeFocus) ? Qt.rgba(0.85, 0.25, 0.25, 1) : Theme.accentDanger
                            border.color: confirmUnpairBtn.activeFocus ? Theme.borderActive : "transparent"
                            border.width: confirmUnpairBtn.activeFocus ? 2 : 0

                            Keys.onReturnPressed: {
                                root.showUnpairConfirm = false;
                                if (root.device) root.unpairRequested(root.device.id);
                            }
                            Keys.onSpacePressed: {
                                root.showUnpairConfirm = false;
                                if (root.device) root.unpairRequested(root.device.id);
                            }

                            Text {
                                id: confirmText
                                anchors.centerIn: parent
                                text: "Confirm Unpair"
                                font.pixelSize: 10
                                font.bold: true
                                color: "#ffffff"
                            }

                            MouseArea {
                                id: confirmUnpairMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showUnpairConfirm = false;
                                    if (root.device) {
                                        root.unpairRequested(root.device.id);
                                    }
                                }
                            }
                        }

                        // Cancel Button
                        Rectangle {
                            id: cancelUnpairBtn
                            implicitWidth: cancelText.implicitWidth + 16
                            implicitHeight: 26
                            radius: Theme.radiusSm
                            activeFocusOnTab: confirmUnpairBox.visible
                            focus: true
                            color: (cancelUnpairMouse.containsMouse || cancelUnpairBtn.activeFocus) ? Theme.bgSurfaceHover : Theme.bgSurface
                            border.color: cancelUnpairBtn.activeFocus ? Theme.borderActive : Theme.borderSubtle
                            border.width: cancelUnpairBtn.activeFocus ? 2 : 1

                            Keys.onReturnPressed: root.showUnpairConfirm = false
                            Keys.onSpacePressed: root.showUnpairConfirm = false

                            Text {
                                id: cancelText
                                anchors.centerIn: parent
                                text: "Cancel"
                                font.pixelSize: 10
                                color: Theme.textSecondary
                            }

                            MouseArea {
                                id: cancelUnpairMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.showUnpairConfirm = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

