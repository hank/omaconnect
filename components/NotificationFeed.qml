import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var notifications: []

    signal dismissRequested(string notificationId)
    signal clearAllRequested()

    implicitWidth: parent ? parent.width : 320
    implicitHeight: contentColumn.implicitHeight

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 8

        // --- Header Row ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "🔔"
                font.pixelSize: 13
            }

            Text {
                text: "Phone Notifications"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: Theme.textSecondary
            }

            // Count Badge
            Rectangle {
                visible: root.notifications && root.notifications.length > 0
                implicitWidth: countText.implicitWidth + 8
                implicitHeight: 16
                radius: 8
                color: Qt.rgba(0.23, 0.51, 0.96, 0.2)
                border.color: Theme.accentPrimary

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: root.notifications ? root.notifications.length.toString() : "0"
                    font.pixelSize: 10
                    font.bold: true
                    color: Theme.accentPrimary
                }
            }

            Item { Layout.fillWidth: true }

            // Clear All Button
            Rectangle {
                visible: root.notifications && root.notifications.length > 0
                implicitWidth: clearText.implicitWidth + 12
                implicitHeight: 20
                radius: Theme.radiusSm
                color: clearMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                border.color: Theme.borderSubtle

                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear All"
                    font.pixelSize: 10
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearAllRequested()
                }
            }
        }

        // --- Empty State Banner ---
        Rectangle {
            visible: !root.notifications || root.notifications.length === 0
            Layout.fillWidth: true
            implicitHeight: emptyRow.implicitHeight + 16
            color: Theme.bgSurface
            radius: Theme.radiusSm
            border.color: Theme.borderSubtle
            border.width: 1

            RowLayout {
                id: emptyRow
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "🔕"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignVCenter
                }

                Text {
                    text: "No recent notifications"
                    font.pixelSize: 11
                    color: Theme.textMuted
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }

        // --- Bounded Notifications Feed List ---
        ColumnLayout {
            visible: root.notifications && root.notifications.length > 0
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: root.notifications || []

                Rectangle {
                    id: itemCard
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: cardLayout.implicitHeight + 16
                    color: Theme.bgSurface
                    radius: Theme.radiusSm
                    border.color: (modelData && modelData.isSms) ? Qt.rgba(0.23, 0.51, 0.96, 0.4) : Theme.borderSubtle
                    border.width: 1

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 4

                        // Card Header: App Badge, Device & Timestamp, Dismiss Button
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // App Tag / SMS Badge
                            Rectangle {
                                implicitWidth: appTagText.implicitWidth + 8
                                implicitHeight: 16
                                radius: 4
                                color: (modelData && modelData.isSms) ? Qt.rgba(0.23, 0.51, 0.96, 0.25) : Qt.rgba(1, 1, 1, 0.06)

                                Text {
                                    id: appTagText
                                    anchors.centerIn: parent
                                    text: (modelData && modelData.appName) ? modelData.appName : "Notification"
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: (modelData && modelData.isSms) ? Theme.accentPrimary : Theme.textSecondary
                                }
                            }

                            // Device Name & Time
                            Text {
                                text: {
                                    if (!modelData) return "";
                                    var dev = modelData.deviceName || "";
                                    var time = modelData.timestamp || "";
                                    if (dev && time) return dev + " • " + time;
                                    return dev || time;
                                }
                                font.pixelSize: 10
                                color: Theme.textMuted
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Dismiss Button
                            Rectangle {
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 9
                                color: dismissMouse.containsMouse ? Theme.bgSurfaceHover : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.pixelSize: 10
                                    color: dismissMouse.containsMouse ? Theme.accentDanger : Theme.textMuted
                                }

                                MouseArea {
                                    id: dismissMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData && modelData.id) {
                                            root.dismissRequested(modelData.id);
                                        }
                                    }
                                }
                            }
                        }

                        // Title Row (if title exists and differs from appName)
                        Text {
                            visible: modelData && modelData.title && modelData.title !== modelData.appName
                            text: (modelData && modelData.title) ? modelData.title : ""
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.textPrimary
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Notification Body Content
                        Text {
                            visible: modelData && modelData.body && modelData.body !== ""
                            text: (modelData && modelData.body) ? modelData.body : ""
                            font.pixelSize: 11
                            color: Theme.textSecondary
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
