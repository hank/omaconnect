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
    property string activeComposer: "none"
    property string draftPing: ""
    property string draftText: ""
    property string composerError: ""
    property string focusSection: "devices"
    property int selectedIndex: 0
    property int actionSelectedIndex: 0
    property bool cursorActive: false
    property bool commandsExpanded: false
    property int commandSelectedIndex: 0
    property string unpairConfirmingId: ""

    function open() { opened = true }
    function close() { opened = false }
    function toggle() { opened = !opened }

    function availableActions() {
        if (!root.device || !root.device.paired || !root.device.reachable) return []
        var caps = root.device.capabilities || {}
        var res = []
        if (caps.ring) res.push("ring")
        if (caps.clipboard) res.push("clipboard")
        if (caps.file) res.push("file")
        if (caps.ping) res.push("ping")
        if (caps.text) res.push("text")
        return res
    }

    function triggerAction(actionId) {
        if (!service || !device) return
        if (actionId === "ring") service.ringDevice(device.id)
        else if (actionId === "clipboard") service.sendClipboard(device.id)
        else if (actionId === "file") { if (service.startFileSelection(device.id)) fileDialog.open() }
        else if (actionId === "ping") {
            if (activeComposer === "ping") closeComposer()
            else openComposer("ping")
        }
        else if (actionId === "text") {
            if (activeComposer === "text") closeComposer()
            else openComposer("text")
        }
    }

    function requestUnpairConfirm(id) {
        unpairConfirmingId = id
        if (service && typeof service.setPendingPairing === "function") service.setPendingPairing(id, "unpair_confirm")
    }

    function cancelUnpairConfirm(id) {
        if (!id || unpairConfirmingId === id) unpairConfirmingId = ""
        if (service && id && typeof service.setPendingPairing === "function") service.setPendingPairing(id, "")
    }

    function confirmUnpair(id) {
        unpairConfirmingId = ""
        if (service) service.unpairDevice(id)
    }

    function openComposer(type) {
        composerError = ""
        activeComposer = type
        if (type === "ping") {
            focusSection = "ping"
            Qt.callLater(function() { if (pingInput) pingInput.forceActiveFocus() })
        } else if (type === "text") {
            focusSection = "text"
            Qt.callLater(function() { if (textInput) textInput.forceActiveFocus() })
        }
    }

    function closeComposer() {
        activeComposer = "none"
        composerError = ""
        focusSection = "actions"
        if (keyCatcher) keyCatcher.forceActiveFocus()
    }

    function resetComposer() {
        activeComposer = "none"
        draftPing = ""
        draftText = ""
        composerError = ""
    }

    function submitPing() {
        var val = draftPing.trim()
        if (!val) {
            composerError = "Message cannot be empty"
            if (service) {
                service.actionState = "blocked"
                service.actionError = "Message cannot be empty"
                service.actionMessage = ""
            }
            return false
        }
        if (service && device) {
            var success = service.pingDevice(device.id, val)
            if (success) {
                draftPing = ""
                closeComposer()
            }
            return success
        }
        return false
    }

    function submitText() {
        var val = draftText.trim()
        if (!val) {
            composerError = "Message cannot be empty"
            if (service) {
                service.actionState = "blocked"
                service.actionError = "Message cannot be empty"
                service.actionMessage = ""
            }
            return false
        }
        if (service && device) {
            var success = service.shareText(device.id, val)
            if (success) {
                draftText = ""
                closeComposer()
            }
            return success
        }
        return false
    }

    function select(delta) {
        var list = service ? service.devices : []
        if (!list.length) return
        selectedIndex = Math.max(0, Math.min(list.length - 1, selectedIndex + delta))
        if (cursorActive && service) service.selectDevice(list[selectedIndex].id)
        Qt.callLater(function() { if (deviceList.count) deviceList.positionViewAtIndex(selectedIndex, ListView.Contain) })
    }

    function toggleCommandsExpanded() {
        commandsExpanded = !commandsExpanded
        if (commandsExpanded && service && device && device.capabilities && device.capabilities.commands) {
            service.fetchRemoteCommands(device.id)
        }
    }

    function selectCommand(delta) {
        var list = (service && service.remoteCommands) ? service.remoteCommands : []
        if (!list.length) return
        commandSelectedIndex = Math.max(0, Math.min(list.length - 1, commandSelectedIndex + delta))
    }

    function activate() {
        if (focusSection === "devices") {
            var list = service ? service.devices : []
            var dev = list[selectedIndex]
            if (dev && service) {
                service.selectDevice(dev.id)
                var pending = (service.pendingPairing && service.pendingPairing[dev.id]) ? service.pendingPairing[dev.id] : ""
                if (root.unpairConfirmingId === dev.id || pending === "unpair_confirm") {
                    root.confirmUnpair(dev.id)
                } else if (!dev.paired) {
                    if (pending !== "requesting") service.pairDevice(dev.id)
                } else {
                    if (pending !== "removing") root.requestUnpairConfirm(dev.id)
                }
            }
        } else if (focusSection === "refresh") { if (service) service.refresh() }
        else if (focusSection === "actions") {
            var acts = availableActions()
            if (acts.length > 0) {
                var actIdx = Math.max(0, Math.min(acts.length - 1, actionSelectedIndex))
                triggerAction(acts[actIdx])
            }
        } else if (focusSection === "ring" && service && device) service.ringDevice(device.id)
        else if (focusSection === "clipboard" && service && device) service.sendClipboard(device.id)
        else if (focusSection === "file" && service && device) { if (service.startFileSelection(device.id)) fileDialog.open() }
        else if (focusSection === "ping") {
            if (activeComposer === "ping") submitPing()
            else openComposer("ping")
        } else if (focusSection === "text") {
            if (activeComposer === "text") submitText()
            else openComposer("text")
        } else if (focusSection === "commands" && service && device) {
            if (!commandsExpanded) {
                toggleCommandsExpanded()
            } else if (service.remoteCommands.length > 0) {
                var idx = Math.max(0, Math.min(service.remoteCommands.length - 1, commandSelectedIndex))
                var cmd = service.remoteCommands[idx]
                if (cmd) service.executeRemoteCommand(device.id, cmd.key)
            } else {
                service.fetchRemoteCommands(device.id)
            }
        }
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
            blocked: (pingInput && pingInput.activeFocus) || (textInput && textInput.activeFocus)
            onMoveRequested: function(dx, dy) {
                if (!root.cursorActive) { root.cursorActive = true; return }
                if (dy) {
                    if (root.focusSection === "commands" && root.commandsExpanded) root.selectCommand(dy)
                    else if (root.focusSection === "actions") {
                        var acts = root.availableActions()
                        if (acts.length > 0) {
                            if (dy > 0 && root.actionSelectedIndex < acts.length - 1) root.actionSelectedIndex++
                            else if (dy < 0 && root.actionSelectedIndex > 0) root.actionSelectedIndex--
                        }
                    }
                    else root.select(dy)
                }
            }
            onActivateRequested: root.activate()
            onCloseRequested: root.close()
            onTabRequested: function(direction) { if (root.bar && typeof root.bar.switchPanelFrom === "function") root.bar.switchPanelFrom(root, direction) }
            onTextKey: function(value) {
                var key = String(value).toLowerCase()
                if (key === "r" && root.service) root.service.refresh()
                else if (key === "j" || key === "down") {
                    if (root.focusSection === "commands" && root.commandsExpanded) root.selectCommand(1)
                    else if (root.focusSection === "actions") {
                        var actsD = root.availableActions()
                        if (actsD.length > 0 && root.actionSelectedIndex < actsD.length - 1) root.actionSelectedIndex++
                        else if (root.device && root.device.capabilities && root.device.capabilities.commands) root.focusSection = "commands"
                        else root.focusSection = "devices"
                    }
                    else root.select(1)
                }
                else if (key === "k" || key === "up") {
                    if (root.focusSection === "commands" && root.commandsExpanded) root.selectCommand(-1)
                    else if (root.focusSection === "actions") {
                        if (root.actionSelectedIndex > 0) root.actionSelectedIndex--
                        else root.focusSection = "devices"
                    }
                    else root.select(-1)
                }
                else if (key === "l" || key === "right") {
                    if (root.focusSection === "devices") {
                        var availableL0 = root.availableActions()
                        if (availableL0.length > 0) {
                            root.focusSection = "actions"
                            root.actionSelectedIndex = 0
                        } else if (root.device && root.device.capabilities && root.device.capabilities.commands) {
                            root.focusSection = "commands"
                        }
                    }
                    else if (root.focusSection === "actions") {
                        var availableL = root.availableActions()
                        if (root.actionSelectedIndex < availableL.length - 1) {
                            root.actionSelectedIndex++
                        } else if (root.device && root.device.capabilities && root.device.capabilities.commands) {
                            root.focusSection = "commands"
                        } else {
                            root.focusSection = "devices"
                        }
                    }
                    else if (root.focusSection === "commands") root.focusSection = "devices"
                }
                else if (key === "h" || key === "left") {
                    if (root.focusSection === "commands") {
                        var availableCmdH = root.availableActions()
                        if (availableCmdH.length > 0) {
                            root.focusSection = "actions"
                            root.actionSelectedIndex = availableCmdH.length - 1
                        } else {
                            root.focusSection = "devices"
                        }
                    }
                    else if (root.focusSection === "actions") {
                        if (root.actionSelectedIndex > 0) {
                            root.actionSelectedIndex--
                        } else {
                            root.focusSection = "devices"
                        }
                    }
                    else if (root.focusSection === "devices") {
                        if (root.device && root.device.capabilities && root.device.capabilities.commands) root.focusSection = "commands"
                        else {
                            var availableDevH = root.availableActions()
                            if (availableDevH.length > 0) {
                                root.focusSection = "actions"
                                root.actionSelectedIndex = availableDevH.length - 1
                            }
                        }
                    }
                }
                else if (key === "p" && root.focusSection === "devices") {
                    var listP = root.service ? root.service.devices : []
                    var devP = listP[root.selectedIndex]
                    if (devP && !devP.paired && root.service) {
                        var pendP = (root.service.pendingPairing && root.service.pendingPairing[devP.id]) ? root.service.pendingPairing[devP.id] : ""
                        if (pendP !== "requesting") root.service.pairDevice(devP.id)
                    }
                }
                else if (key === "u" && root.focusSection === "devices") {
                    var listU = root.service ? root.service.devices : []
                    var devU = listU[root.selectedIndex]
                    if (devU && devU.paired && root.service) {
                        var pendU = (root.service.pendingPairing && root.service.pendingPairing[devU.id]) ? root.service.pendingPairing[devU.id] : ""
                        if (pendU !== "removing") root.requestUnpairConfirm(devU.id)
                    }
                }
                else if (key === "y" && (root.unpairConfirmingId !== "" || (root.service && root.service.selectedDeviceId && root.service.pendingPairing && root.service.pendingPairing[root.service.selectedDeviceId] === "unpair_confirm"))) {
                    var targetIdY = root.unpairConfirmingId || (root.service ? root.service.selectedDeviceId : "")
                    if (targetIdY) root.confirmUnpair(targetIdY)
                }
                else if ((key === "c" || key === "escape") && (root.unpairConfirmingId !== "" || (root.service && root.service.selectedDeviceId && root.service.pendingPairing && root.service.pendingPairing[root.service.selectedDeviceId] === "unpair_confirm"))) {
                    var targetIdC = root.unpairConfirmingId || (root.service ? root.service.selectedDeviceId : "")
                    if (targetIdC) root.cancelUnpairConfirm(targetIdC)
                }
            }

            Column {
                id: contentColumn
                width: parent.width
                spacing: Style.space(12)

                Item {
                    width: parent.width
                    implicitHeight: heroLayout.implicitHeight

                    Item {
                        id: heroLayout
                        width: parent.width
                        implicitHeight: Math.max(hero.implicitHeight, refreshButton.implicitHeight)

                        Button {
                            id: refreshButton
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            iconText: "󰑐"
                            tooltipText: "Refresh"
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            onClicked: if (root.service) root.service.refresh()
                        }

                        Column {
                            id: hero
                            anchors.left: parent.left
                            anchors.right: refreshButton.left
                            anchors.rightMargin: Style.space(8)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(2)

                            Text {
                                text: root.device ? root.deviceName : "KDE Connect"
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.title
                                font.bold: true
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                width: parent.width
                                text: {
                                    if (!root.service) return "Service unavailable"
                                    if (root.service.discoveryState !== "ready") return root.service.discoveryMessage
                                    return root.service.deviceOverviewStatus(root.device)
                                }
                                color: (root.service && root.service.discoveryState === "ready" && root.device && root.device.reachable)
                                    ? root.bar.foreground
                                    : Qt.darker(root.bar.foreground, 1.4)
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.caption
                                elide: Text.ElideRight
                            }

                            Row {
                                visible: !!(root.device && root.device.capabilities && root.device.capabilities.battery)
                                spacing: Style.space(6)

                                Text {
                                    text: root.service ? root.service.deviceBatteryIcon(root.device) : ""
                                    color: (root.device && root.device.battery >= 0 && root.device.battery <= 20 && !(root.device.isCharging || root.device.charging))
                                        ? Color.urgent
                                        : ((root.device && (root.device.isCharging || root.device.charging)) ? Color.accent : root.bar.foreground)
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.bodySmall
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: root.service ? root.service.deviceBatteryText(root.device) : ""
                                    color: (root.device && root.device.battery >= 0 && root.device.battery <= 20 && !(root.device.isCharging || root.device.charging))
                                        ? Color.urgent
                                        : ((root.device && (root.device.isCharging || root.device.charging)) ? Color.accent : root.bar.foreground)
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.bodySmall
                                    font.bold: !!(root.device && root.device.battery >= 0 && root.device.battery <= 20 && !(root.device.isCharging || root.device.charging))
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
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
                        readonly property string devicePendingState: (root.service && root.service.pendingPairing && root.service.pendingPairing[modelData.id]) ? root.service.pendingPairing[modelData.id] : ""
                        readonly property bool isUnpairConfirming: root.unpairConfirmingId === modelData.id || devicePendingState === "unpair_confirm"

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
                        Item {
                            id: row
                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(8)
                            implicitHeight: Math.max(nameText.implicitHeight, rightActionItem.implicitHeight) + Style.space(4)

                            Row {
                                id: rightActionItem
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Style.space(6)

                                Text {
                                    id: statusText
                                    text: !modelData.paired ? "" : (!modelData.reachable ? "Offline" : "●")
                                    color: modelData.paired && modelData.reachable ? Color.accent : Qt.darker(root.bar.foreground, 1.5)
                                    font.family: root.bar.fontFamily
                                    font.pixelSize: Style.font.caption
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: text !== ""
                                }

                                Row {
                                    id: actionRow
                                    spacing: Style.space(4)
                                    visible: !!(modelData && modelData.capabilities && modelData.capabilities.pair)

                                    Row {
                                        visible: isUnpairConfirming
                                        spacing: Style.space(4)
                                        Text {
                                            text: "Confirm?"
                                            color: Color.urgent
                                            font.family: root.bar.fontFamily
                                            font.pixelSize: Style.font.caption
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Button {
                                            text: "Confirm"
                                            foreground: root.bar.foreground
                                            fontFamily: root.bar.fontFamily
                                            onClicked: root.confirmUnpair(modelData.id)
                                        }
                                        Button {
                                            text: "Cancel"
                                            foreground: root.bar.foreground
                                            fontFamily: root.bar.fontFamily
                                            onClicked: root.cancelUnpairConfirm(modelData.id)
                                        }
                                    }

                                    Button {
                                        visible: !isUnpairConfirming && devicePendingState === "requesting"
                                        enabled: false
                                        text: "Pairing..."
                                        foreground: root.bar.foreground
                                        fontFamily: root.bar.fontFamily
                                    }
                                    Button {
                                        visible: !isUnpairConfirming && devicePendingState === "removing"
                                        enabled: false
                                        text: "Unpairing..."
                                        foreground: root.bar.foreground
                                        fontFamily: root.bar.fontFamily
                                    }

                                    Button {
                                        visible: !isUnpairConfirming && !modelData.paired && devicePendingState !== "requesting"
                                        text: "Pair"
                                        foreground: root.bar.foreground
                                        fontFamily: root.bar.fontFamily
                                        onClicked: if (root.service) root.service.pairDevice(modelData.id)
                                    }

                                    Button {
                                        visible: !isUnpairConfirming && modelData.paired && devicePendingState !== "removing"
                                        text: "Unpair"
                                        foreground: root.bar.foreground
                                        fontFamily: root.bar.fontFamily
                                        onClicked: root.requestUnpairConfirm(modelData.id)
                                    }
                                }
                            }

                            Text {
                                id: nameText
                                anchors.left: parent.left
                                anchors.right: rightActionItem.left
                                anchors.rightMargin: Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.body
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                Text { visible: !root.service || root.service.devices.length === 0; text: root.service && root.service.scanning ? "Scanning..." : "No devices found"; color: Qt.darker(root.bar.foreground, 1.4); font.family: root.bar.fontFamily; font.pixelSize: Style.font.bodySmall }

                PanelSeparator { visible: !!root.device; foreground: root.bar.foreground }
                PanelSectionHeader { visible: !!root.device; text: root.device ? (root.device.type.toUpperCase() + " ACTIONS") : "ACTIONS"; foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }

                Row {
                    visible: !!root.device && root.device.paired && root.device.reachable
                    spacing: Style.space(6)
                    Repeater {
                        model: root.availableActions()
                        delegate: CursorSurface {
                            required property string modelData
                            required property int index
                            readonly property string actionName: {
                                if (modelData === "ring") return "Ring"
                                if (modelData === "clipboard") return "Clipboard"
                                if (modelData === "file") return "File"
                                if (modelData === "ping") return "Ping"
                                if (modelData === "text") return "Text"
                                return modelData
                            }

                            implicitWidth: actionBtnText.implicitWidth + Style.space(16)
                            implicitHeight: actionBtnText.implicitHeight + Style.space(8)
                            hasCursor: root.cursorActive && root.focusSection === "actions" && root.actionSelectedIndex === index
                            current: (modelData === "ping" && root.activeComposer === "ping") || (modelData === "text" && root.activeComposer === "text")
                            foreground: root.bar.foreground
                            fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
                            currentFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
                            enabled: !root.service || (root.service.actionState !== "running" && !root.service.fileBusy)

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    root.cursorActive = true
                                    root.focusSection = "actions"
                                    root.actionSelectedIndex = index
                                }
                                onClicked: root.triggerAction(modelData)
                            }

                            Text {
                                id: actionBtnText
                                anchors.centerIn: parent
                                text: parent.actionName
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.bodySmall
                            }
                        }
                    }
                }
                Column {
                    visible: root.activeComposer === "ping" && !!root.device && root.device.paired && root.device.reachable && root.device.capabilities.ping
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                        text: "Ping " + root.deviceName
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(6)

                        TextField {
                            id: pingInput
                            width: Math.max(1, parent.width - sendPing.implicitWidth - cancelPing.implicitWidth - Style.space(12))
                            placeholderText: "Ping message"
                            text: root.draftPing
                            onTextChanged: {
                                root.draftPing = text
                                if (text.trim().length > 0) root.composerError = ""
                            }
                            onAccepted: root.submitPing()
                            Keys.onEscapePressed: root.closeComposer()
                        }

                        Button {
                            id: sendPing
                            text: "Send"
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            onClicked: root.submitPing()
                        }

                        Button {
                            id: cancelPing
                            text: "Cancel"
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            onClicked: root.closeComposer()
                        }
                    }
                }
                Column {
                    visible: root.activeComposer === "text" && !!root.device && root.device.paired && root.device.reachable && root.device.capabilities.text
                    width: parent.width
                    spacing: Style.space(6)

                    Text {
                        text: "Share text or link with " + root.deviceName
                        color: root.bar.foreground
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(6)

                        TextField {
                            id: textInput
                            width: Math.max(1, parent.width - sendText.implicitWidth - cancelText.implicitWidth - Style.space(12))
                            placeholderText: "Text or link"
                            text: root.draftText
                            onTextChanged: {
                                root.draftText = text
                                if (text.trim().length > 0) root.composerError = ""
                            }
                            onAccepted: root.submitText()
                            Keys.onEscapePressed: root.closeComposer()
                        }

                        Button {
                            id: sendText
                            text: "Send"
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            onClicked: root.submitText()
                        }

                        Button {
                            id: cancelText
                            text: "Cancel"
                            foreground: root.bar.foreground
                            fontFamily: root.bar.fontFamily
                            onClicked: root.closeComposer()
                        }
                    }
                }
                PanelSeparator { visible: !!root.device && root.device.capabilities.commands; foreground: root.bar.foreground }
                Row {
                    visible: !!root.device && root.device.capabilities.commands
                    width: parent.width
                    spacing: Style.space(6)
                    CursorSurface {
                        width: Math.max(1, parent.width - (root.commandsExpanded ? refreshCmdBtn.implicitWidth + Style.space(6) : 0))
                        implicitHeight: headerRow.implicitHeight + Style.space(4)
                        hasCursor: root.cursorActive && root.focusSection === "commands" && !root.commandsExpanded
                        foreground: root.bar.foreground
                        fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
                        currentFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: {
                                root.cursorActive = true
                                root.focusSection = "commands"
                            }
                            onClicked: root.toggleCommandsExpanded()
                        }
                        Row {
                            id: headerRow
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Style.space(6)
                            Text {
                                text: root.commandsExpanded ? "󰅀" : "󰅂"
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.caption
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            PanelSectionHeader {
                                text: "REMOTE COMMANDS"
                                foreground: root.bar.foreground
                                fontFamily: root.bar.fontFamily
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                    Button {
                        id: refreshCmdBtn
                        visible: root.commandsExpanded
                        iconText: "󰑐"
                        tooltipText: "Refresh commands"
                        foreground: root.bar.foreground
                        fontFamily: root.bar.fontFamily
                        enabled: !root.service || !root.service.commandsLoading
                        onClicked: if (root.service && root.device) root.service.fetchRemoteCommands(root.device.id)
                    }
                }
                Column {
                    visible: !!root.device && root.device.capabilities.commands && root.commandsExpanded
                    width: parent.width
                    spacing: Style.space(6)
                    Text {
                        visible: !!root.service && root.service.commandsLoading
                        text: "Loading commands..."
                        color: Qt.darker(root.bar.foreground, 1.4)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.bodySmall
                    }
                    Text {
                        visible: !!root.service && !root.service.commandsLoading && root.service.remoteCommands.length === 0
                        text: "No remote commands configured"
                        color: Qt.darker(root.bar.foreground, 1.4)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.bodySmall
                    }
                    Repeater {
                        model: root.service ? root.service.remoteCommands : []
                        delegate: CursorSurface {
                            required property var modelData
                            required property int index
                            width: parent.width
                            implicitHeight: cmdBtnText.implicitHeight + Style.space(8)
                            hasCursor: root.cursorActive && root.focusSection === "commands" && root.commandsExpanded && root.commandSelectedIndex === index
                            foreground: root.bar.foreground
                            fill: Style.hoverFillFor(root.bar.foreground, Color.accent)
                            currentFill: Style.selectedFillFor(root.bar.foreground, Color.accent)
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    root.cursorActive = true
                                    root.focusSection = "commands"
                                    root.commandSelectedIndex = index
                                }
                                onClicked: if (root.service && root.device) root.service.executeRemoteCommand(root.device.id, modelData.key)
                            }
                            Text {
                                id: cmdBtnText
                                anchors.left: parent.left
                                anchors.leftMargin: Style.space(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                color: root.bar.foreground
                                font.family: root.bar.fontFamily
                                font.pixelSize: Style.font.bodySmall
                                elide: Text.ElideRight
                                width: parent.width - Style.space(16)
                            }
                        }
                    }
                }
                Text { visible: root.service && root.service.actionMessage !== ""; text: root.service ? root.service.actionMessage : ""; color: root.bar.foreground; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; width: parent.width }
                Text { visible: (root.service && root.service.actionError !== "") || root.composerError !== ""; text: root.composerError !== "" ? root.composerError : (root.service ? root.service.actionError : ""); color: Color.urgent; font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; wrapMode: Text.WordWrap; width: parent.width }
            }
        }
    }

    Connections {
        target: root.service
        function onDevicesChanged() { root.updateSelectedIndex() }
        function onSelectedDeviceIdChanged() {
            root.updateSelectedIndex()
            root.resetComposer()
            root.commandsExpanded = false
            root.commandSelectedIndex = 0
            root.actionSelectedIndex = 0
        }
    }

    function updateSelectedIndex() {
        var list = root.service ? root.service.devices : []
        var selected = root.service ? root.service.selectedDeviceId : ""
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === selected) {
                root.selectedIndex = i
                if (deviceList.count) Qt.callLater(function() { deviceList.positionViewAtIndex(i, ListView.Contain) })
                return
            }
        }
        if (list.length > 0) {
            root.selectedIndex = 0
        }
    }

    FileDialog {
        id: fileDialog
        title: "Choose a file to send"
        fileMode: FileDialog.OpenFile
        onAccepted: if (root.service && root.device) root.service.sendFile(root.device.id, selectedFile.toString())
        onRejected: if (root.service) root.service.cancelFileSelection()
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
