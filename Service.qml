import QtQuick
import "./components" as Components

Item {
    id: root
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null

    Components.KdeConnectController { id: controller }

    property alias daemonAvailable: controller.daemonAvailable
    property alias sessionBusAvailable: controller.sessionBusAvailable
    property alias isConnected: controller.isConnected
    property alias activeDeviceCount: controller.activeDeviceCount
    property alias lowestBattery: controller.lowestBattery
    property alias allDevices: controller.allDevices
    property alias reachableDevices: controller.reachableDevices
    property alias activeDevice: controller.activeDevice
    property alias statusMessage: controller.statusMessage
    property alias pairingStates: controller.pairingStates
    property alias notifications: controller.notifications
    property alias remoteCommands: controller.remoteCommands
    property alias fetchingCommands: controller.fetchingCommands
    property alias lastActionError: controller.lastActionError
    property alias actionStatusMessage: controller.statusMessage

    function refresh() { controller.refresh() }
    function selectDevice(id) { controller.selectDevice(id) }
    function ringDevice(id) { return controller.ringDevice(id) }
    function pingDevice(id, message) { return controller.pingDevice(id, message) }
    function shareText(id, text) { return controller.shareText(id, text) }
    function sendFile(id) { return controller.sendFile(id) }
    function fetchRemoteCommands(id) { return controller.fetchRemoteCommands(id) }
    function executeRemoteCommand(id, key) { return controller.executeRemoteCommand(id, key) }
    function pairDevice(id) { return controller.pairDevice(id) }
    function unpairDevice(id) { return controller.unpairDevice(id) }
    function dismissNotification(id) { controller.dismissNotification(id) }
    function clearAllNotifications() { controller.clearAllNotifications() }
}
