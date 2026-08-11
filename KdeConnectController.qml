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
        selectedDeviceId = next.id
        remoteCommands = []
        commandTargetId = ""
        commandsLoading = false
        if (commandsProcess.running) commandsProcess.running = false
    }

    function safeError(exitCode, operation) {
        return exitCode === 127 || exitCode === 69 ? operation + " unavailable" : operation + " failed"
    }

    function canAct(id) {
        var device = deviceById(id)
        return !!(device && device.paired && device.reachable)
    }

    function refresh() {
        if (scanProcess.running) return
        var nextGeneration = generation + 1
        generation = nextGeneration
        scanning = true
        discoveryState = "checking"
        discoveryMessage = "Checking KDE Connect"
        scanProcess.targetGeneration = nextGeneration
        scanProcess.command = ["bash", pluginPath + "/scripts/discover_devices.sh"]
        scanProcess.running = true
    }

    function parseScanLine(line) {
        var parts = String(line || "").split("\t")
        if (parts.length < 9 || parts[0] !== "DEVICE") return null
        var plugins = String(parts[8]).split(",")
        function hasPlugin(name) { return plugins.indexOf(name) !== -1 }
        return {
            id: parts[1],
            name: parts[2] || parts[1],
            type: parts[3] || "unknown",
            paired: parts[4] === "true",
            reachable: parts[5] === "true",
            battery: /^\d+$/.test(parts[6]) ? Number(parts[6]) : -1,
            isCharging: parts[7] === "true",
            capabilities: {
                battery: hasPlugin("kdeconnect_battery"),
                ping: hasPlugin("kdeconnect_ping"),
                ring: hasPlugin("kdeconnect_findmyphone"),
                text: hasPlugin("kdeconnect_share"),
                clipboard: hasPlugin("kdeconnect_clipboard"),
                file: hasPlugin("kdeconnect_share"),
                commands: hasPlugin("kdeconnect_runcommand"),
                pair: true
            }
        }
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
        if (selectedDeviceId && canAct(selectedDeviceId) && deviceById(selectedDeviceId).capabilities.commands)
            fetchRemoteCommands(selectedDeviceId)
    }

    function startAction(id, command, acceptedMessage, operation) {
        if (actionProcess.running || pairProcess.running || !canAct(id)) {
            actionState = "blocked"
            actionError = "Device must be paired and reachable"
            actionMessage = ""
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
        var device = deviceById(id)
        if (!text || !device || !device.capabilities.ping) return false
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--ping-msg", text], "Ping request accepted", "ping")
    }

    function shareText(id, text) {
        var value = String(text || "").trim()
        var device = deviceById(id)
        if (!value || !device || !device.capabilities.text) return false
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--share-text", value], "Text-share request accepted", "text share")
    }

    function ringDevice(id) {
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--ring"], "Ring request accepted", "ring")
    }

    function sendClipboard(id) {
        var device = deviceById(id)
        if (!device || !device.capabilities.clipboard) return false
        return startAction(id, ["kdeconnect-cli", "-d", String(id), "--send-clipboard"], "Clipboard request accepted", "clipboard")
    }

    function sendFile(id, path) {
        var value = String(path || "")
        var device = deviceById(id)
        if (!value || value.indexOf("\u0000") !== -1 || !device || !device.capabilities.file) return false
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
            var values = Array.isArray(json) ? json : Object.keys(json).map(function(key) {
                return { key: key, name: json[key] }
            })
            values.forEach(function(item) {
                if (typeof item === "string" && item.trim()) result.push({ key: item.trim(), name: item.trim() })
                else if (item && (item.key || item.id || item.command))
                    result.push({ key: String(item.key || item.id || item.command), name: String(item.name || item.label || item.title || item.key || item.id || item.command) })
            })
            return result
        } catch (error) {
            source.split("\n").forEach(function(line) {
                var value = line.replace(/^[-*]\s*/, "").trim()
                if (!value || /^no commands/i.test(value)) return
                var split = value.indexOf(":")
                result.push(split > 0
                    ? { key: value.slice(0, split).trim(), name: value.slice(split + 1).trim() || value.slice(0, split).trim() }
                    : { key: value, name: value })
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
        pendingPairing = Object.assign({}, pendingPairing, (function() { var x = {}; x[id] = "requesting"; return x })())
        pairProcess.targetDeviceId = String(id)
        pairProcess.targetGeneration = generation
        pairProcess.command = ["kdeconnect-cli", "-d", String(id), "--pair"]
        pairProcess.running = true
        return true
    }

    function unpairDevice(id) {
        var device = deviceById(id)
        if (!device || pairProcess.running || actionProcess.running || !device.capabilities.pair) return false
        pendingPairing = Object.assign({}, pendingPairing, (function() { var x = {}; x[id] = "removing"; return x })())
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
        command: ["bash", "-c", "set -u; base=/modules/kdeconnect; ids=$(gdbus call --session --dest org.kde.kdeconnect --object-path $base --method org.kde.kdeconnect.daemon.devices false false | sed -e 's/.*\\[//' -e 's/\\].*//' -e \"s/'//g\" -e 's/,/\\n/g' -e 's/ //g'); get(){ gdbus call --session --dest org.kde.kdeconnect --object-path \"$base/devices/$1\" --method org.freedesktop.DBus.Properties.Get org.kde.kdeconnect.device \"$2\" 2>/dev/null | sed -E \"s/^\\(<([^>]*)>.*$/\\1/\"; }; for id in $ids; do [ -n \"$id\" ] || continue; path=\"$base/devices/$id\"; name=$(get \"$id\" name); type=$(get \"$id\" type); paired=$(get \"$id\" isPaired); reachable=$(get \"$id\" isReachable); supported=$(get \"$id\" supportedPlugins | tr -d \"[]' \"); plugins=; for plugin in kdeconnect_battery kdeconnect_ping kdeconnect_share kdeconnect_runcommand; do if printf %s \"$supported\" | grep -qw \"$plugin\" && gdbus introspect --session --dest org.kde.kdeconnect --object-path \"$path/${plugin#kdeconnect_}\" >/dev/null 2>&1; then plugins=\"${plugins:+$plugins,}$plugin\"; fi; done; charge=-1; charging=false; if printf %s \"$plugins\" | grep -q kdeconnect_battery; then battery=\"$path/battery\"; charge=$(gdbus call --session --dest org.kde.kdeconnect --object-path \"$battery\" --method org.freedesktop.DBus.Properties.Get org.kde.kdeconnect.device.battery charge 2>/dev/null | sed -E 's/^\\(<([0-9-]+)>.*$/\\1/'); charging=$(gdbus call --session --dest org.kde.kdeconnect --object-path \"$battery\" --method org.freedesktop.DBus.Properties.Get org.kde.kdeconnect.device.battery isCharging 2>/dev/null | grep -q true && echo true || echo false); fi; printf 'DEVICE\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$name\" \"$type\" \"$paired\" \"$reachable\" \"$charge\" \"$charging\" \"$plugins\"; done"]
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
            if (targetGeneration !== root.actionGeneration) return
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
            var copy = Object.assign({}, root.pendingPairing)
            copy[targetDeviceId] = code === 0 ? "accepted" : "failed"
            root.pendingPairing = copy
            if (targetGeneration !== root.generation) return
            root.actionState = code === 0 ? "accepted" : "failed"
            root.actionMessage = code === 0 ? "Pairing request accepted" : ""
            root.actionError = code === 0 ? "" : root.safeError(code, "pairing")
            refresh()
        }
    }

    Process {
        id: signalProcess
        command: ["dbus-monitor", "--session", "type='signal',sender='org.kde.kdeconnect'"]
        stdout: SplitParser { onRead: function(line) {
            var value = String(line || "")
            if (value.indexOf("device") !== -1 || value.indexOf("chargeChanged") !== -1 || value.indexOf("stateChanged") !== -1 || value.indexOf("refreshed") !== -1)
                root.refresh()
        } }
        onExited: {
            signalRestart.interval = Math.min(30000, 1000 * Math.pow(2, monitorRestartCount))
            monitorRestartCount += 1
            signalRestart.start()
        }
    }

    Timer { id: signalRestart; repeat: false; onTriggered: if (!signalProcess.running) signalProcess.running = true }
    Timer { interval: 15000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: { root.refresh(); signalProcess.running = true }
    Component.onDestruction: { signalRestart.stop(); signalProcess.running = false; scanProcess.running = false; commandsProcess.running = false; actionProcess.running = false; pairProcess.running = false }
}
