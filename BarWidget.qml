import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "./components" as Components

BarWidget {
    id: root

    moduleName: "omaconnect"

    readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
        ? bar.shell.serviceFor("omaconnect") : null
    Components.KdeConnectController {
        id: localController
        active: root.service === null
    }
    readonly property var controller: root.service || localController
    readonly property bool opened: popupOpen
    property bool popupOpen: false

    function open() { popupOpen = true }
    function close() { popupOpen = false }
    function toggle() { popupOpen = !popupOpen }

    implicitWidth: button.implicitWidth
    implicitHeight: barSize

    WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰄀"
        fontSize: Style.font.icon
        tooltipText: root.controller.daemonAvailable
            ? (root.controller.isConnected && root.controller.activeDevice
                ? "KDE Connect: " + root.controller.activeDevice.name : "KDE Connect: offline")
            : "KDE Connect unavailable"
        active: root.opened
        activeColor: root.bar ? root.bar.urgent : Color.urgent
        onPressed: function(button) {
            if (button === Qt.LeftButton) root.toggle()
        }
    }

    PopupCard {
        id: popup
        anchorItem: button
        bar: root.bar
        owner: root
        open: root.opened
        triggerMode: "click"
        contentWidth: popup.fittedContentWidth(Style.space(380))
        contentHeight: popup.fittedContentHeight(content.implicitHeight)

        Components.PopoverWindow {
            id: content
            width: parent.width
            isOpen: root.opened
            actionRunner: root.controller
            onCloseRequested: root.close()
            onRefreshRequested: root.controller.refresh()
            onDeviceSelected: function(device) {
                if (device && device.id) root.controller.selectDevice(device.id)
            }
            onRingDeviceRequested: function(deviceId) { root.controller.ringDevice(deviceId) }
            onPingDeviceRequested: function(deviceId) { root.controller.pingDevice(deviceId) }
            onShareTextRequested: function(deviceId, text) { root.controller.shareText(deviceId, text) }
            onPairDeviceRequested: function(deviceId) { root.controller.pairDevice(deviceId) }
            onUnpairDeviceRequested: function(deviceId) { root.controller.unpairDevice(deviceId) }
            onDismissNotificationRequested: function(notificationId) { root.controller.dismissNotification(notificationId) }
            onClearAllNotificationsRequested: root.controller.clearAllNotifications()

            isConnected: root.controller.isConnected
            daemonAvailable: root.controller.daemonAvailable
            sessionBusAvailable: root.controller.sessionBusAvailable
            allDevices: root.controller.allDevices
            connectedDevices: root.controller.reachableDevices
            activeDevice: root.controller.activeDevice
            statusMessage: root.controller.statusMessage
            pairingStates: root.controller.pairingStates
            notifications: root.controller.notifications
        }
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
