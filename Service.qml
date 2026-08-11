import QtQuick

Item {
    id: root
    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null

    KdeConnectController { id: controller }
    onOmarchyPathChanged: controller.pluginPath = omarchyPath

    property alias daemonAvailable: controller.daemonAvailable
    property alias sessionBusAvailable: controller.sessionBusAvailable
    property alias scanning: controller.scanning
    property alias discoveryState: controller.discoveryState
    property alias discoveryMessage: controller.discoveryMessage
    property alias actionState: controller.actionState
    property alias actionMessage: controller.actionMessage
    property alias actionError: controller.actionError
    property alias devices: controller.devices
    property alias reachableDevices: controller.reachableDevices
    property alias selectedDeviceId: controller.selectedDeviceId
    property alias selectedDevice: controller.selectedDevice
    property alias remoteCommands: controller.remoteCommands
    property alias commandsLoading: controller.commandsLoading
    property alias pendingPairing: controller.pendingPairing
    property alias capabilities: controller.capabilities
    property alias fileBusy: controller.fileBusy

    function refresh() { controller.refresh() }
    function selectDevice(id) { controller.selectDevice(id) }
    function pingDevice(id, text) { return controller.pingDevice(id, text) }
    function shareText(id, text) { return controller.shareText(id, text) }
    function fetchRemoteCommands(id) { return controller.fetchRemoteCommands(id) }
    function executeRemoteCommand(id, key) { return controller.executeRemoteCommand(id, key) }
    function pairDevice(id) { return controller.pairDevice(id) }
    function unpairDevice(id) { return controller.unpairDevice(id) }
    function ringDevice(id) { return controller.ringDevice(id) }
    function sendClipboard(id) { return controller.sendClipboard(id) }
    function sendFile(id, path) { return controller.sendFile(id, path) }
}
