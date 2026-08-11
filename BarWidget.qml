pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
    id: root
    moduleName: "omaconnect"

    readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
        ? bar.shell.serviceFor("omaconnect") : null
    readonly property var device: service ? service.selectedDevice : null
    readonly property string deviceName: device && typeof device.name === "string" ? device.name : "KDE Connect"
    property bool opened: false
    property string draftPing: ""
    property string draftText: ""
    property string focusSection: "devices"
    property int selectedIndex: 0
    property bool cursorActive: false

    function open() { opened = true }
    function close() { opened = false }
    function toggle() { opened = !opened }
    function select(delta) {
        var list = service ? service.devices : []
        if (!list.length) return
        selectedIndex = Math.max(0, Math.min(list.length - 1, selectedIndex + delta))
        if (cursorActive && service) service.selectDevice(list[selectedIndex].id)
        Qt.callLater(function() { if (deviceList.count) deviceList.positionViewAtIndex(selectedIndex, ListView.Contain) })
    }
    function activate() {
        if (focusSection === "devices") {
            var list = service ? service.devices : []
            if (list[selectedIndex]) service.selectDevice(list[selectedIndex].id)
        } else if (focusSection === "refresh") { if (service) service.refresh() }
        else if (focusSection === "ring" && service) service.ringDevice(device.id)
        else if (focusSection === "clipboard" && service) service.sendClipboard(device.id)
        else if (focusSection === "file") fileDialog.open()
        else if (focusSection === "commands" && service) service.fetchRemoteCommands(device.id)
    }

    implicitWidth: button.implicitWidth
    implicitHeight: barSize

    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰄀"
        tooltipText: root.deviceName
        onPressed: root.toggle()
    }

    KeyboardPanel {
        id: panel
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: panel.fittedContentWidth(Style.space(380))
        contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            blocked: pingInput.activeFocus || textInput.activeFocus
            onMoveRequested: function(dx, dy) {
                if (!root.cursorActive) { root.cursorActive = true; return }
                if (dy) root.select(dy)
            }
            onActivateRequested: root.activate()
            onCloseRequested: root.close()
            onTabRequested: function(direction) { if (root.bar && typeof root.bar.switchPanelFrom === "function") root.bar.switchPanelFrom(root, direction) }
            onTextKey: function(value) {
                var key = String(value).toLowerCase()
                if (key === "r" && root.service) root.service.refresh()
                else if (key === "j" || key === "down") root.select(1)
                else if (key === "k" || key === "up") root.select(-1)
                else if (key === "l" || key === "right") root.focusSection = root.focusSection === "devices" ? "actions" : "devices"
                else if (key === "h" || key === "left") root.focusSection = "devices"
            }

            Column {
                id: contentColumn
                width: parent.width
                spacing: Style.space(12)

                Item {
                    width: parent.width
                    implicitHeight: hero.implicitHeight
                    Column {
                        id: hero
                        width: Math.max(1, parent.width - refreshButton.width - Style.space(8))
                        spacing: Style.space(2)
                        Text { text: "KDE Connect"; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                        Text {
                            width: parent.width
                            text: root.service ? root.service.discoveryMessage : "Service unavailable"
                            color: root.service && root.service.discoveryState === "ready" ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.4)
                            font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight
                        }
                    }
                    Button { id: refreshButton; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; iconText: "󰑐"; tooltipText: "Refresh"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.refresh() }
                }

                PanelSeparator { foreground: root.bar.foreground }

                PanelSectionHeader { text: "DEVICES"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
                ListView {
                    id: deviceList
                    width: parent.width
                    height: Math.min(contentHeight, Style.space(220))
                    clip: true
                    interactive: contentHeight > height
                    model: root.service ? root.service.devices : []
                    currentIndex: root.cursorActive ? root.selectedIndex : -1
                    delegate: CursorSurface {
                        required property var modelData
                        required property int index
                        width: deviceList.width
                        implicitHeight: row.implicitHeight + Style.space(8)
                        hasCursor: root.cursorActive && root.focusSection === "devices" && root.selectedIndex === index
                        current: root.service && root.service.selectedDeviceId === modelData.id
                        foreground: root.bar.foreground
                        fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
                        currentFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                         onEntered: {
                                 root.cursorActive = true
                                 root.selectedIndex = index
                                 if (root.service) root.service.selectDevice(modelData.id)
                            }
                            onClicked: if (root.service) root.service.selectDevice(modelData.id)
                        }
                        Row {
                            id: row
                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(8)
                            Text { text: modelData.name; width: Math.max(1, row.width - status.implicitWidth - 8); color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }
                            Text { id: status; text: !modelData.paired ? "Pair" : (modelData.reachable ? "Reachable" : "Offline"); color: modelData.reachable ? Color.accent : Qt.darker(root.bar.foreground, 1.5); font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption }
                        }
                    }
                }
                Text { visible: !root.service || root.service.devices.length === 0; text: root.service && root.service.scanning ? "Scanning" : "No devices"; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }

                PanelSeparator { visible: !!root.device; foreground: root.bar.foreground }
                PanelSectionHeader { visible: !!root.device; text: root.device ? root.device.type.toUpperCase() : ""; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
                Text { visible: !!root.device; text: root.device ? (root.device.paired ? (root.device.reachable ? "Paired and reachable" : "Paired, not reachable") : "Not paired") : ""; color: Qt.darker(root.bar.foreground, 1.3); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
                Text { visible: !!root.device && root.device.capabilities.battery; text: root.device ? (root.device.battery >= 0 ? (root.device.battery + "%" + (root.device.isCharging ? " charging" : "")) : "Battery unavailable") : ""; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }

                Row {
                    visible: !!root.device && root.device.paired && root.device.reachable
                    spacing: Style.space(6)
                    Button { enabled: !root.service || root.service.actionState !== "running"; visible: root.device && root.device.capabilities.ping; text: "Ping"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: { root.focusSection = "ping"; pingInput.forceActiveFocus() } }
                    Button { visible: root.device && root.device.capabilities.text; text: "Text"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: textInput.forceActiveFocus() }
                    Button { visible: root.device && root.device.capabilities.commands; text: "Commands"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.fetchRemoteCommands(root.device.id) }
                    Button { enabled: !root.service || root.service.actionState !== "running"; visible: root.device && root.device.capabilities.ring; text: "Ring"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.ringDevice(root.device.id) }
                    Button { enabled: !root.service || root.service.actionState !== "running"; visible: root.device && root.device.capabilities.clipboard; text: "Clipboard"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.sendClipboard(root.device.id) }
                    Button { enabled: !root.service || root.service.actionState !== "running"; visible: root.device && root.device.capabilities.file; text: "File"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: fileDialog.open() }
                }
                Row {
                    visible: !!root.device && root.device.capabilities.pair
                    spacing: Style.space(6)
                    Button { visible: root.device && !root.device.paired; enabled: !root.service.pendingPairing[root.device.id]; text: root.service.pendingPairing[root.device.id] === "requesting" ? "Pairing..." : "Pair"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.pairDevice(root.device.id) }
                    Button { visible: root.device && root.device.paired; enabled: !root.service.pendingPairing[root.device.id]; text: root.service.pendingPairing[root.device.id] === "removing" ? "Unpairing..." : "Unpair"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.unpairDevice(root.device.id) }
                }
                Row {
                    visible: !!root.device && root.device.paired && root.device.reachable && root.device.capabilities.ping
                    spacing: Style.space(6)
                    TextField { id: pingInput; width: Math.max(1, parent.width - sendPing.implicitWidth - Style.space(6)); placeholderText: "Ping message"; text: root.draftPing; onTextChanged: root.draftPing = text; onAccepted: sendPing.clicked() }
                    Button { id: sendPing; text: "Send"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.pingDevice(root.device.id, root.draftPing) }
                }
                Row {
                    visible: !!root.device && root.device.paired && root.device.reachable && root.device.capabilities.text
                    spacing: Style.space(6)
                    TextField { id: textInput; width: Math.max(1, parent.width - sendText.implicitWidth - Style.space(6)); placeholderText: "Text or link"; text: root.draftText; onTextChanged: root.draftText = text; onAccepted: sendText.clicked() }
                    Button { id: sendText; text: "Send"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.shareText(root.device.id, root.draftText) }
                }
                PanelSeparator { visible: !!root.device && root.device.capabilities.commands; foreground: root.bar.foreground }
                PanelSectionHeader { visible: !!root.device && root.device.capabilities.commands; text: "REMOTE COMMANDS"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
                Text { visible: !!root.device && root.device.capabilities.commands && root.service.commandsLoading; text: "Loading commands"; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
                Text { visible: !!root.device && root.device.capabilities.commands && !root.service.commandsLoading && root.service.remoteCommands.length === 0; text: "No remote commands configured"; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }
                Repeater {
                    model: root.service ? root.service.remoteCommands : []
                    Button { required property var modelData; text: modelData.name; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily; onClicked: if (root.service) root.service.executeRemoteCommand(root.device.id, modelData.key) }
                }
                Text { visible: root.service && root.service.actionMessage !== ""; text: root.service ? root.service.actionMessage : ""; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; width: parent.width }
                Text { visible: root.service && root.service.actionError !== ""; text: root.service ? root.service.actionError : ""; color: Color.urgent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; width: parent.width }
            }
        }
    }

    Connections {
        target: root.service
        function onDevicesChanged() {
            var list = root.service ? root.service.devices : []
            var selected = root.service ? root.service.selectedDeviceId : ""
            for (var i = 0; i < list.length; i++) if (list[i].id === selected) root.selectedIndex = i
            if (list.length) Qt.callLater(function() { deviceList.positionViewAtIndex(root.selectedIndex, ListView.Contain) })
        }
    }

    FileDialog {
        id: fileDialog
        title: "Choose a file to send"
        fileMode: FileDialog.OpenFile
        onAccepted: if (root.service && root.device) root.service.sendFile(root.device.id, selectedFile.toString().replace(/^file:\/\//, ""))
    }

    IpcHandler {
        target: "omaconnect"
        function open(): void { root.open() }
        function close(): void { root.close() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
        function toggle(): void { root.toggle() }
    }
}
