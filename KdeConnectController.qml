pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool daemonAvailable: false
    property bool sessionBusAvailable: false
    property bool scanning: false
    property string discoveryState: "starting"
    property string discoveryMessage: "Checking KDE Connect"
    property string pluginPath: ""
    property string actionState: "idle"
    property string actionMessage: ""
    property string actionError: ""
    property string selectedDeviceId: ""
    property var devices: []
    property var remoteCommands: []
    property bool commandsLoading: false
    property string commandTargetId: ""
    property int generation: 0
    property int actionGeneration: 0
    property var pendingPairing: ({})
    property bool fileBusy: false
    property var capabilities: ({})
    property int monitorRestartCount: 0

    readonly property var reachableDevices: devices.filter(function(device) { return device.reachable })
    readonly property var selectedDevice: deviceById(selectedDeviceId)
    readonly property bool connected: reachableDevices.length > 0

    function deviceById(id) {
        for (var i = 0; i < devices.length; i++)
            if (devices[i].id === String(id)) return devices[i]
        return null
    }

    function selectDevice(id) {
        var next = deviceById(id)
        if (!next) return
        if (selectedDeviceId !== next.id) {
            actionState = "idle"
            actionMessage = ""
            actionError = ""
            fileBusy = false
        }
        selectedDeviceId = next.id
        remoteCommands = []
        commandTargetId = ""
        commandsLoading = false
        if (commandsProcess.running) commandsProcess.running = false
    }

    function safeError(exitCode, operation) {
        if (exitCode === 127 || exitCode === 69) return operation + " unavailable"
        if (exitCode === 2) return operation + " rejected"
        if (exitCode === 3) return operation + " timed out"
        return operation + " failed"
    }

    function setPendingPairing(id, state) {
        var copy = Object.assign({}, pendingPairing)
        if (state) {
            copy[String(id)] = state
        } else {
            delete copy[String(id)]
        }
        pendingPairing = copy
    }

    function canAct(id) {
        var device = deviceById(id)
        return !!(device && device.paired && device.reachable)
    }

    function getScriptPath() {
        var resolved = Qt.resolvedUrl("scripts/discover_devices.sh").toString().replace(/^file:\/\//, "")
        return resolved
    }

    function getPickerScriptPath() {
        var resolved = Qt.resolvedUrl("scripts/pick_file.sh").toString().replace(/^file:\/\//, "")
        return resolved
    }

    function getSmsScriptPath() {
        var resolved = Qt.resolvedUrl("scripts/open_sms.sh").toString().replace(/^file:\/\//, "")
        return resolved
    }

    function refresh(forceNetwork) {
        if (scanProcess.running) return
        var nextGeneration = generation + 1
        generation = nextGeneration
        scanning = true
        if (discoveryState !== "ready") {
            discoveryState = "checking"
            discoveryMessage = "Checking KDE Connect"
        }
        scanProcess.targetGeneration = nextGeneration
        var cmd = ["bash", getScriptPath()]
        if (forceNetwork) cmd.push("--refresh")
        scanProcess.command = cmd
        scanProcess.running = true
    }

    function deviceOverviewStatus(device) {
        if (!device) return "No devices found"
        if (!device.paired) return "Not paired"
        if (!device.reachable) return "Paired, offline"
        return "Paired & reachable"
    }

    function deviceBatteryText(device) {
        if (!device) return ""
        var batteryText = ""
        if (device.capabilities && device.capabilities.battery) {
            if (device.battery < 0) {
                batteryText = "Battery unavailable"
            } else {
                var charging = !!(device.isCharging || device.charging)
                if (charging) batteryText = device.battery + "% • Charging"
                else if (device.battery <= 20) batteryText = device.battery + "% • Low battery"
                else batteryText = device.battery + "% • Discharging"
            }
        }
        var netText = ""
        if (device.networkType) {
            var type = String(device.networkType).trim()
            if (type && type !== "null") {
                var str = device.networkStrength
                if (typeof str === "number" && str >= 0) netText = type + " (" + str + "/4)"
                else netText = type
            }
        }
        if (batteryText && netText) return batteryText + " • " + netText
        if (batteryText) return batteryText
        if (netText) return netText
        return ""
    }

    function deviceBatteryIcon(device) {
        if (!device || !device.capabilities || !device.capabilities.battery || device.battery < 0) return "󰂑"
        var charging = !!(device.isCharging || device.charging)
        if (charging) return "󰂄"
        if (device.battery <= 20) return "󰂃"
        if (device.battery <= 50) return "󰁽"
        return "󰁹"
    }

    function deviceNetworkText(device) {
        if (!device || !device.networkType) return ""
        var type = String(device.networkType).trim()
        if (!type || type === "null") return ""
        var str = device.networkStrength
        if (typeof str === "number" && str >= 0) return type + " (" + str + "/4)"
        return type
    }

    function deviceNetworkIcon(device) {
        if (!device || !device.networkType) return "󰀂"
        var str = device.networkStrength
        if (str === 4) return "󰤨"
        if (str === 3) return "󰤥"
        if (str === 2) return "󰤢"
        if (str === 1) return "󰤟"
        if (str === 0) return "󰤯"
        return "󰀂"
    }

    function parseScanLine(line) {
        var cleanLine = String(line || "").trim()
        var parts = cleanLine.split("\t")
        if (parts.length < 9 || parts[0] !== "DEVICE") return null
        var plugins = String(parts[8] || "").split(",")
        function hasPlugin(name) { return plugins.indexOf(name) !== -1 }
        var netType = parts.length > 9 ? String(parts[9] || "").trim() : ""
        var netStrengthRaw = parts.length > 10 ? String(parts[10] || "").trim() : ""
        var netStrength = /^\d+$/.test(netStrengthRaw) ? Number(netStrengthRaw) : -1
        return {
            id: parts[1],
            name: parts[2] || parts[1],
            type: parts[3] || "unknown",
            paired: parts[4] === "true",
            reachable: parts[5] === "true",
            battery: /^\d+$/.test(parts[6]) ? Number(parts[6]) : -1,
            isCharging: parts[7] === "true",
            charging: parts[7] === "true",
            networkType: netType,
            networkStrength: netStrength,
            capabilities: {
                battery: hasPlugin("kdeconnect_battery"),
                ping: hasPlugin("kdeconnect_ping"),
                ring: hasPlugin("kdeconnect_findmyphone"),
                text: hasPlugin("kdeconnect_share"),
                clipboard: hasPlugin("kdeconnect_clipboard"),
                file: hasPlugin("kdeconnect_share"),
                commands: hasPlugin("kdeconnect_runcommand"),
                network: hasPlugin("kdeconnect_connectivity_report"),
                sms: hasPlugin("kdeconnect_sms"),
                pair: true
            }
        }
    }

    function openSmsApp(id) {
        var device = deviceById(id)
        if (!device || !canAct(id)) return false
        return startAction(id, ["bash", getSmsScriptPath(), String(id)], "SMS app opened", "SMS app")
    }



    function applyScan(output, targetGeneration) {
        if (targetGeneration !== generation) return
        var next = []
        String(output || "").split("\n").forEach(function(line) {
            var device = root.parseScanLine(line)
            if (device) next.push(device)
        })
        devices = next
        if (!deviceById(selectedDeviceId))
            selectedDeviceId = next.length ? next[0].id : ""
        scanning = false
        daemonAvailable = scanProcess.exitCode === 0
        sessionBusAvailable = daemonAvailable
        discoveryState = daemonAvailable ? "ready" : "unavailable"
        discoveryMessage = daemonAvailable
            ? (next.length ? "Device state is current" : "No KDE Connect devices")
            : "KDE Connect unavailable"
    }

    function startAction(id, command, acceptedMessage, operation) {
        if (actionProcess.running || pairProcess.running || !canAct(id)) {
            actionState = "blocked"
            actionError = "Device must be paired and reachable"
            actionMessage = ""
            fileBusy = false
            return false
        }
        actionGeneration += 1
        actionProcess.targetGeneration = actionGeneration
        actionProcess.targetDeviceId = String(id)
        actionProcess.command = command
        actionProcess.acceptedMessage = acceptedMessage
        actionProcess.operation = operation
        actionState = "running"
        actionMessage = "Requesting " + operation
        actionError = ""
        fileBusy = operation === "file transfer"
        actionProcess.running = true
        return true
    }

    function pingDevice(id, message) {
        var text = String(message || "").trim()
        if (!text) {
            actionState = "blocked"
            actionError = "Message cannot be empty"
            actionMessage = ""
            return false
        }
        var device = deviceById(id)
        if (!device || !device.capabilities.ping || !canAct(id)) return false
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--ping-msg", text], "Ping request accepted", "ping")
    }

    function shareText(id, text) {
        var value = String(text || "").trim()
        if (!value) {
            actionState = "blocked"
            actionError = "Message cannot be empty"
            actionMessage = ""
            return false
        }
        var device = deviceById(id)
        if (!device || !device.capabilities.text || !canAct(id)) return false
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--share-text", value], "Text-share request accepted", "text share")
    }

    function ringDevice(id) {
        var device = deviceById(id)
        if (!device || !device.capabilities.ring) return false
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--ring"], "Ring request accepted", "ring")
    }

    function sendClipboard(id) {
        var device = deviceById(id)
        if (!device || !device.capabilities.clipboard) return false
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--send-clipboard"], "Clipboard request accepted", "clipboard")
    }

    function startFileSelection(id) {
        var device = deviceById(id)
        if (!device || !device.capabilities.file || !canAct(id)) return false
        if (filePickerProcess.running) filePickerProcess.running = false
        fileBusy = true
        actionState = "busy"
        actionMessage = "Selecting file"
        actionError = ""
        filePickerProcess.targetDeviceId = String(id)
        filePickerProcess.running = true
        return true
    }

    function cancelFileSelection() {
        if (filePickerProcess.running) filePickerProcess.running = false
        fileBusy = false
        actionState = "cancelled"
        actionMessage = "File selection cancelled"
        actionError = ""
    }

    function sendFile(id, path) {
        var value = String(path || "").trim()
        if (value.indexOf("file://") === 0) {
            value = value.replace(/^file:\/\//, "")
            try {
                value = decodeURIComponent(value)
            } catch (e) {}
        }
        var device = deviceById(id)
        if (!value || value.indexOf("\u0000") !== -1 || !device || !device.capabilities.file) {
            fileBusy = false
            return false
        }
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--share", value], "File-transfer request accepted", "file transfer")
    }

    function fetchRemoteCommands(id) {
        var device = deviceById(id)
        if (commandsProcess.running || pairProcess.running || !canAct(id) || !device.capabilities.commands) return false
        commandsLoading = true
        commandTargetId = String(id)
        commandsProcess.targetGeneration = generation
        commandsProcess.targetDeviceId = String(id)
        commandsProcess.output = ""
        commandsProcess.command = ["kdeconnect-cli", "-d", String(id), "--list-commands"]
        commandsProcess.running = true
        return true
    }

    function parseRemoteCommands(text) {
        var source = String(text || "").trim()
        if (!source) return []
        var result = []
        try {
            var json = JSON.parse(source)
            if (json === null || typeof json !== "object") return []
            var values = Array.isArray(json) ? json : Object.keys(json).map(function(key) {
                return { key: key, name: json[key] }
            })
            values.forEach(function(item) {
                if (typeof item === "string" && item.trim()) {
                    result.push({ key: item.trim(), name: item.trim() })
                } else if (item && typeof item === "object") {
                    var k = item.key || item.id || item.command
                    if (k !== undefined && k !== null) {
                        var kStr = String(k).trim()
                        if (kStr) {
                            var n = item.name || item.label || item.title || kStr
                            result.push({ key: kStr, name: String(n).trim() || kStr })
                        }
                    }
                }
            })
            return result
        } catch (error) {
            source.split("\n").forEach(function(line) {
                var value = String(line || "").trim()
                value = value.replace(/^[-*•]\s*|^\d+\.\s*/, "").trim()
                if (!value || /no.*commands/i.test(value)) return
                var split = value.indexOf(":")
                if (split > 0) {
                    var k = value.slice(0, split).trim()
                    var n = value.slice(split + 1).trim()
                    if (k) result.push({ key: k, name: n || k })
                } else if (value) {
                    result.push({ key: value, name: value })
                }
            })
            return result
        }
    }

    function executeRemoteCommand(id, key) {
        var value = String(key || "").trim()
        var device = deviceById(id)
        if (!value || !device || !device.capabilities.commands) return false
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--execute-command", value], "Remote-command request accepted", "remote command")
    }

    function pairDevice(id) {
        var device = deviceById(id)
        if (!device || pairProcess.running || actionProcess.running || !device.capabilities.pair) return false
        setPendingPairing(id, "requesting")
        actionState = "accepted"
        actionMessage = "Pairing request accepted"
        actionError = ""
        pairProcess.targetDeviceId = String(id)
        pairProcess.targetGeneration = generation
        pairProcess.command = ["kdeconnect-cli", "-d", String(id), "--pair"]
        pairProcess.running = true
        return true
    }

    function unpairDevice(id) {
        var device = deviceById(id)
        if (!device || pairProcess.running || actionProcess.running || !device.capabilities.pair) return false
        setPendingPairing(id, "removing")
        pairProcess.targetDeviceId = String(id)
        pairProcess.targetGeneration = generation
        pairProcess.command = ["kdeconnect-cli", "-d", String(id), "--unpair"]
        pairProcess.running = true
        return true
    }

    Process {
        id: scanProcess
        property int targetGeneration: 0
        property int exitCode: -1
        command: ["bash", getScriptPath()]
        stdout: StdioCollector { waitForEnd: true }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            exitCode = code
            root.applyScan(stdout.text, targetGeneration)
        }
    }

    Process {
        id: commandsProcess
        property string output: ""
        property string targetDeviceId: ""
        property int targetGeneration: 0
        stdout: SplitParser { onRead: function(line) { commandsProcess.output += line + "\n" } }
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            root.commandsLoading = false
            if (targetGeneration !== root.generation || targetDeviceId !== root.selectedDeviceId) return
            root.remoteCommands = code === 0 ? root.parseRemoteCommands(output) : []
        }
    }

    Process {
        id: actionProcess
        property string targetDeviceId: ""
        property int targetGeneration: 0
        property string acceptedMessage: "Request accepted"
        property string operation: "action"
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            if (targetGeneration !== root.actionGeneration || targetDeviceId !== root.selectedDeviceId) return
            root.fileBusy = false
            root.actionState = code === 0 ? "accepted" : "failed"
            root.actionMessage = code === 0 ? acceptedMessage : ""
            root.actionError = code === 0 ? "" : root.safeError(code, operation)
        }
    }

    Process {
        id: pairProcess
        property string targetDeviceId: ""
        property int targetGeneration: 0
        stderr: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            var isPair = pairProcess.command && pairProcess.command.indexOf("--pair") !== -1
            var op = isPair ? "pairing" : "unpairing"
            root.setPendingPairing(targetDeviceId, code === 0 ? "accepted" : "failed")
            if (targetGeneration !== root.generation || targetDeviceId !== root.selectedDeviceId) {
                root.refresh()
                return
            }
            if (code === 0) {
                root.actionState = "accepted"
                root.actionMessage = isPair ? "Pairing request accepted" : "Unpair request accepted"
                root.actionError = ""
            } else {
                root.actionState = "failed"
                root.actionMessage = ""
                root.actionError = root.safeError(code, op)
            }
            root.refresh()
        }
    }

    Timer { id: dbusDebounceTimer; interval: 300; repeat: false; onTriggered: root.refresh() }

    Process {
        id: signalProcess
        command: ["dbus-monitor", "--session", "type='signal',sender='org.kde.kdeconnect'"]
        stdout: SplitParser { onRead: function(line) {
            var value = String(line || "")
            if (value.indexOf("device") !== -1 || value.indexOf("chargeChanged") !== -1 || value.indexOf("stateChanged") !== -1 || value.indexOf("refreshed") !== -1)
                dbusDebounceTimer.restart()
        } }
        onExited: {
            signalRestart.interval = Math.min(30000, 1000 * Math.pow(2, monitorRestartCount))
            monitorRestartCount += 1
            signalRestart.start()
        }
    }

    Process {
        id: filePickerProcess
        property string targetDeviceId: ""
        command: ["bash", getPickerScriptPath()]
        stdout: StdioCollector { waitForEnd: true }
        onExited: function(code) {
            filePickerProcess.running = false
            var selectedPath = stdout.text.trim()
            if (code === 0 && selectedPath) {
                root.sendFile(targetDeviceId, selectedPath)
            } else {
                root.cancelFileSelection()
            }
        }
    }

    Timer { id: signalRestart; repeat: false; onTriggered: if (!signalProcess.running) signalProcess.running = true }
    Timer { interval: 15000; running: !signalProcess.running; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: { root.refresh(); signalProcess.running = true }
    Component.onDestruction: { dbusDebounceTimer.stop(); signalRestart.stop(); signalProcess.running = false; scanProcess.running = false; commandsProcess.running = false; actionProcess.running = false; pairProcess.running = false; filePickerProcess.running = false }
}
