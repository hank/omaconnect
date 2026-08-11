import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    // --- Exposed State Properties ---
    property bool daemonAvailable: false
    property bool sessionBusAvailable: false
    property bool dependenciesMet: false
    property bool isConnected: false
    property int activeDeviceCount: 0
    property int lowestBattery: -1
    property var allDevices: []
    property var reachableDevices: []
    property var activeDevice: null
    property string statusMessage: "Initializing OmaConnect..."
    property bool monitorRunning: false
    property var remoteCommands: []
    property bool fetchingCommands: false
    property var pairingStates: ({})
    property var notifications: []
    readonly property int maxNotifications: 10
    property var pendingNotifArgs: []

    // Signal emitted when a real-time D-Bus signal event is processed
    signal presenceEventReceived(string eventType, string deviceId)
    signal pairingStateChanged(string deviceId, string state)

    // Temporary storage for accumulator during device scan
    property var parsedAccumulator: []
    property string pendingSignalMember: ""
    property string pendingMonitorDevId: ""
    property string pendingMonitorMember: ""

    function addNotification(notif) {
        if (!notif || typeof notif !== "object") return;
        var list = root.notifications.slice();

        var id = notif.id || ("notif_" + Date.now() + "_" + Math.floor(Math.random() * 10000));
        var devId = notif.deviceId || "";
        var dev = root.getDevice(devId);
        var devName = notif.deviceName || (dev ? dev.name : (root.activeDevice ? root.activeDevice.name : "Phone"));
        var appName = notif.appName || notif.app || "Notification";
        var title = notif.title || appName;
        var body = notif.body || "";
        var isSms = notif.isSms !== undefined ? notif.isSms : (appName.toLowerCase().indexOf("sms") !== -1 || appName.toLowerCase().indexOf("messages") !== -1);
        var timeStr = notif.timestamp || new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

        var newObj = {
            id: String(id),
            deviceId: String(devId),
            deviceName: String(devName),
            appName: String(appName),
            title: String(title),
            body: String(body),
            timestamp: String(timeStr),
            isSms: !!isSms
        };

        list.unshift(newObj);

        if (list.length > root.maxNotifications) {
            list = list.slice(0, root.maxNotifications);
        }

        root.notifications = list;
    }

    function dismissNotification(id) {
        if (!id) return;
        var list = root.notifications.slice();
        var updated = [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].id !== String(id)) {
                updated.push(list[i]);
            }
        }
        root.notifications = updated;
    }

    function clearAllNotifications() {
        root.notifications = [];
    }

    function flushPendingNotificationArgs() {
        if (!pendingNotifArgs || pendingNotifArgs.length === 0) return;
        var isNotifMember = (pendingMonitorMember === "notificationAdded" ||
                             pendingMonitorMember === "displayNotification" ||
                             pendingMonitorMember === "notificationPosted" ||
                             pendingMonitorMember === "notificationReceived" ||
                             pendingMonitorMember === "receiveNotification");
        if (!isNotifMember) return;

        var app = "Notification";
        var title = "Phone";
        var body = "";

        if (pendingNotifArgs.length === 1) {
            body = pendingNotifArgs[0];
        } else if (pendingNotifArgs.length === 2) {
            title = pendingNotifArgs[0];
            body = pendingNotifArgs[1];
        } else if (pendingNotifArgs.length >= 3) {
            app = pendingNotifArgs[0];
            title = pendingNotifArgs[1];
            body = pendingNotifArgs[2];
        }

        addNotification({
            deviceId: pendingMonitorDevId,
            appName: app,
            title: title,
            body: body
        });

        pendingNotifArgs = [];
    }

    function getPairingState(deviceId) {
        if (!deviceId || !pairingStates) return "idle";
        return pairingStates[deviceId] || "idle";
    }

    function setPairingState(deviceId, state) {
        if (!deviceId) return;
        var copy = Object.assign({}, pairingStates);
        copy[deviceId] = state;
        pairingStates = copy;
        pairingStateChanged(deviceId, state);

        if (state === "accepted" || state === "rejected" || state === "failed") {
            resetPairingStateTimer.targetDeviceId = deviceId;
            resetPairingStateTimer.restart();
        }
    }

    Timer {
        id: resetPairingStateTimer
        property string targetDeviceId: ""
        interval: 5000
        repeat: false
        onTriggered: {
            if (targetDeviceId !== "") {
                root.setPairingState(targetDeviceId, "idle");
            }
        }
    }

    Timer {
        id: pairTimeoutTimer
        property string targetDeviceId: ""
        interval: 30000
        repeat: false
        onTriggered: {
            if (targetDeviceId !== "" && root.getPairingState(targetDeviceId) === "pending") {
                var dev = root.getDevice(targetDeviceId);
                if (dev && dev.paired) {
                    root.setPairingState(targetDeviceId, "accepted");
                } else {
                    root.setPairingState(targetDeviceId, "rejected");
                }
            }
        }
    }

    // Helper to retrieve device by ID
    function getDevice(deviceId) {
        for (var i = 0; i < allDevices.length; i++) {
            if (allDevices[i].id === deviceId) {
                return allDevices[i];
            }
        }
        return null;
    }

    // Select a device by ID
    function selectDevice(deviceId) {
        for (var i = 0; i < allDevices.length; i++) {
            if (allDevices[i].id === deviceId) {
                if (activeDevice && activeDevice.id === deviceId) return;
                activeDevice = allDevices[i];
                if (actionProcess.running) actionProcess.running = false;
                if (listCommandsProcess.running) listCommandsProcess.running = false;
                remoteCommands = [];
                fetchingCommands = false;
                return;
            }
        }
    }

    // Trigger full health and device scan
    function refresh() {
        parsedAccumulator = [];
        healthCheckProcess.running = true;
    }

    // Debounced refresh for real-time presence signals
    Timer {
        id: debounceRefreshTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (!deviceCheckProcess.running) {
                parsedAccumulator = [];
                deviceCheckProcess.running = true;
            }
        }
    }

    function triggerPresenceRefresh() {
        if (!debounceRefreshTimer.running) {
            debounceRefreshTimer.restart();
        }
    }

    // Debounced battery refresh
    Timer {
        id: debounceBatteryTimer
        interval: 300
        repeat: false
        onTriggered: fetchBatteryStatus()
    }

    function triggerBatteryRefresh() {
        if (!debounceBatteryTimer.running) {
            debounceBatteryTimer.restart();
        }
    }

    // Action Execution Methods with Reachability Guard
    function ringDevice(deviceId) {
        var dev = getDevice(deviceId);
        if (!dev || !dev.reachable) {
            console.log("Cannot ring device: device is offline or unreachable.");
            return false;
        }
        actionProcess.command = ["kdeconnect-cli", "-d", deviceId, "--ring"];
        actionProcess.running = true;
        return true;
    }

    function pingDevice(deviceId, msg) {
        var dev = getDevice(deviceId);
        if (!dev || !dev.reachable) {
            console.log("Cannot ping device: device is offline or unreachable.");
            return false;
        }
        var message = msg || "Hello from OmaConnect!";
        actionProcess.command = ["kdeconnect-cli", "-d", deviceId, "--ping-msg", message];
        actionProcess.running = true;
        return true;
    }

    function sendFile(deviceId) {
        var dev = getDevice(deviceId);
        if (!dev || !dev.reachable) {
            console.log("Cannot send file: device is offline or unreachable.");
            return false;
        }
        var helperPath = Qt.resolvedUrl("../scripts/share_file.sh").toString();
        if (helperPath.indexOf("file://") === 0) helperPath = decodeURIComponent(helperPath.substring(7));
        actionProcess.command = ["bash", helperPath, deviceId];
        actionProcess.running = true;
        return true;
    }

    function shareText(deviceId, text) {
        var dev = getDevice(deviceId);
        if (!dev || !dev.reachable) {
            console.log("Cannot share text: device is offline or unreachable.");
            return false;
        }
        if (!text || text.trim().length === 0) {
            console.log("Cannot share text: text content is empty.");
            return false;
        }
        actionProcess.command = ["kdeconnect-cli", "-d", deviceId, "--share-text", text];
        actionProcess.running = true;
        return true;
    }

    function fetchRemoteCommands(deviceId) {
        var dev = getDevice(deviceId);
        if (!dev || !dev.reachable) {
            console.log("Cannot fetch remote commands: device is offline or unreachable.");
            root.remoteCommands = [];
            root.fetchingCommands = false;
            return false;
        }
        listCommandsProcess.pendingOutput = "";
        listCommandsProcess.command = ["kdeconnect-cli", "-d", deviceId, "--list-commands"];
        root.fetchingCommands = true;
        listCommandsProcess.running = true;
        return true;
    }

    function executeRemoteCommand(deviceId, key) {
        var dev = getDevice(deviceId);
        if (!dev || !dev.reachable) {
            console.log("Cannot execute remote command: device is offline or unreachable.");
            return false;
        }
        if (!key || key.trim() === "") {
            console.log("Cannot execute remote command: key is empty.");
            return false;
        }
        actionProcess.command = ["kdeconnect-cli", "-d", deviceId, "--execute-command", key.trim()];
        actionProcess.running = true;
        return true;
    }

    function parseRemoteCommandsOutput(text) {
        if (!text || typeof text !== "string" || text.trim() === "") {
            return [];
        }
        var trimmed = text.trim();
        if (trimmed.indexOf("No commands") !== -1 || trimmed.indexOf("error:") !== -1 || trimmed.indexOf("Device unreachable") !== -1) {
            return [];
        }
        var result = [];
        if ((trimmed.startsWith("{") && trimmed.endsWith("}")) || (trimmed.startsWith("[") && trimmed.endsWith("]"))) {
            try {
                var parsed = JSON.parse(trimmed);
                if (Array.isArray(parsed)) {
                    for (var i = 0; i < parsed.length; i++) {
                        var item = parsed[i];
                        if (typeof item === "object" && item !== null) {
                            var k = item.key || item.id || item.command || "";
                            var n = item.name || item.label || item.title || k;
                            if (k) {
                                result.push({ key: String(k), name: String(n) });
                            }
                        } else if (typeof item === "string" && item.trim()) {
                            result.push({ key: item.trim(), name: item.trim() });
                        }
                    }
                    return result;
                } else if (typeof parsed === "object" && parsed !== null) {
                    var keys = Object.keys(parsed);
                    for (var j = 0; j < keys.length; j++) {
                        var keyName = keys[j];
                        var val = parsed[keyName];
                        var dispName = keyName;
                        if (typeof val === "string") {
                            dispName = val;
                        } else if (typeof val === "object" && val !== null) {
                            dispName = val.name || val.label || val.title || keyName;
                        }
                        result.push({ key: String(keyName), name: String(dispName) });
                    }
                    return result;
                }
            } catch (e) {
                // Ignore JSON error and fall through to line parsing
            }
        }
        var lines = trimmed.split("\n");
        for (var l = 0; l < lines.length; l++) {
            var line = lines[l].trim();
            if (!line) continue;
            if (line.startsWith("- ") || line.startsWith("* ")) {
                line = line.substring(2).trim();
            }
            if (!line) continue;
            var colonIdx = line.indexOf(":");
            if (colonIdx > 0) {
                var keyPart = line.substring(0, colonIdx).trim();
                var namePart = line.substring(colonIdx + 1).trim();
                if (keyPart) {
                    result.push({ key: keyPart, name: namePart !== "" ? namePart : keyPart });
                    continue;
                }
            }
            var dashIdx = line.indexOf(" - ");
            if (dashIdx > 0) {
                var kDash = line.substring(0, dashIdx).trim();
                var nDash = line.substring(dashIdx + 3).trim();
                if (kDash) {
                    result.push({ key: kDash, name: nDash !== "" ? nDash : kDash });
                    continue;
                }
            }
            result.push({ key: line, name: line });
        }
        return result;
    }

    Process {
        id: listCommandsProcess
        command: []
        running: false
        property string pendingOutput: ""

        stdout: SplitParser {
            onRead: line => {
                listCommandsProcess.pendingOutput += line + "\n";
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.fetchingCommands = false;
            if (exitCode === 0) {
                root.remoteCommands = root.parseRemoteCommandsOutput(listCommandsProcess.pendingOutput);
            } else {
                root.remoteCommands = [];
            }
        }
    }

    function pairDevice(deviceId) {
        var dev = getDevice(deviceId);
        if (!dev) {
            setPairingState(deviceId, "failed");
            return false;
        }

        setPairingState(deviceId, "pending");
        pairProcess.targetDeviceId = deviceId;
        pairProcess.command = ["kdeconnect-cli", "-d", deviceId, "--pair"];
        pairProcess.running = true;

        pairTimeoutTimer.targetDeviceId = deviceId;
        pairTimeoutTimer.restart();
        return true;
    }

    function unpairDevice(deviceId) {
        var dev = getDevice(deviceId);
        if (!dev) return false;

        unpairProcess.targetDeviceId = deviceId;
        unpairProcess.command = ["kdeconnect-cli", "-d", deviceId, "--unpair"];
        unpairProcess.running = true;

        setPairingState(deviceId, "idle");
        return true;
    }

    Process {
        id: actionProcess
        command: []
        running: false
    }

    Process {
        id: pairProcess
        property string targetDeviceId: ""
        command: []
        running: false

        stdout: SplitParser {
            onRead: line => {
                if (line && (line.indexOf("rejected") !== -1 || line.indexOf("refused") !== -1 || line.indexOf("denied") !== -1)) {
                    root.setPairingState(pairProcess.targetDeviceId, "rejected");
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                var st = root.getPairingState(pairProcess.targetDeviceId);
                if (st === "pending") {
                    root.setPairingState(pairProcess.targetDeviceId, "failed");
                }
            }
        }
    }

    Process {
        id: unpairProcess
        property string targetDeviceId: ""
        command: []
        running: false

        onExited: (exitCode, exitStatus) => {
            root.refresh();
        }
    }

    // --- Process 1: System Health & D-Bus Session Check ---
    Process {
        id: healthCheckProcess
        command: ["bash", "-c", "which kdeconnect-cli >/dev/null 2>&1 && dbus-send --session --dest=org.freedesktop.DBus --type=method_call /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1"]
        running: false

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.dependenciesMet = true;
                root.sessionBusAvailable = true;
                deviceCheckProcess.running = true;
                if (!presenceMonitorProcess.running) {
                    presenceMonitorProcess.running = true;
                    root.monitorRunning = true;
                }
            } else {
                root.dependenciesMet = false;
                root.daemonAvailable = false;
                root.sessionBusAvailable = false;
                root.isConnected = false;
                root.allDevices = [];
                root.reachableDevices = [];
                root.activeDevice = null;
                root.activeDeviceCount = 0;
                root.statusMessage = "Missing system dependencies (kdeconnect-cli) or D-Bus session bus unavailable.";
            }
        }
    }

    // --- Process 2: Real-Time D-Bus Monitor Process ---
    Process {
        id: presenceMonitorProcess
        command: ["dbus-monitor", "--session", "type='signal',sender='org.kde.kdeconnect'"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                root.parseMonitorLine(line);
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.monitorRunning = false;
            if (root.dependenciesMet && root.sessionBusAvailable) {
                monitorRecoveryTimer.restart();
            }
        }
    }

    Timer {
        id: monitorRecoveryTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (root.dependenciesMet && root.sessionBusAvailable && !presenceMonitorProcess.running) {
                presenceMonitorProcess.running = true;
                root.monitorRunning = true;
            }
        }
    }

    function parseMonitorLine(line) {
        if (!line || typeof line !== "string") return;
        try {
            var trimmed = line.trim();
            if (trimmed === "") return;

            // Direct line format check 1: NOTIF:deviceId:appName:title:body
            if (trimmed.startsWith("NOTIF:")) {
                var parts = trimmed.split(":");
                if (parts.length >= 5) {
                    var nDevId = parts[1];
                    var nApp = parts[2];
                    var nTitle = parts[3];
                    var nBody = parts.slice(4).join(":");
                    addNotification({
                        deviceId: nDevId,
                        appName: nApp,
                        title: nTitle,
                        body: nBody
                    });
                }
                return;
            }

            // Direct line format check 2: JSON format {"deviceId":..., "appName":...}
            if (trimmed.startsWith("{") && trimmed.endsWith("}") && (trimmed.indexOf("appName") !== -1 || trimmed.indexOf("title") !== -1 || trimmed.indexOf("body") !== -1)) {
                try {
                    var obj = JSON.parse(trimmed);
                    if (obj && (obj.appName || obj.title || obj.body)) {
                        addNotification(obj);
                        return;
                    }
                } catch (e) {}
            }

            // D-Bus Monitor signal line header check
            if (trimmed.startsWith("signal ") || trimmed.indexOf("member=") !== -1) {
                flushPendingNotificationArgs();

                var pathMatch = trimmed.match(/path=\/modules\/kdeconnect\/devices\/([^\/;]+)/);
                if (pathMatch && pathMatch.length > 1) {
                    pendingMonitorDevId = pathMatch[1];
                }
                var memberMatch = trimmed.match(/member=([A-Za-z0-9_]+)/);
                if (memberMatch && memberMatch.length > 1) {
                    pendingMonitorMember = memberMatch[1];
                }

                pendingNotifArgs = [];

                if (pendingMonitorMember === "deviceAdded" || pendingMonitorMember === "deviceRemoved" || pendingMonitorMember === "deviceVisibilityChanged" || pendingMonitorMember === "reachableChanged" || pendingMonitorMember === "deviceListChanged" || pendingMonitorMember === "pairStateChanged") {
                    root.triggerPresenceRefresh();
                } else if (pendingMonitorMember === "chargeChanged" || pendingMonitorMember === "stateChanged") {
                    root.triggerBatteryRefresh();
                }
                return;
            }

            // Signal argument lines for notification members
            if (pendingMonitorMember === "notificationAdded" ||
                pendingMonitorMember === "displayNotification" ||
                pendingMonitorMember === "notificationPosted" ||
                pendingMonitorMember === "notificationReceived" ||
                pendingMonitorMember === "receiveNotification") {

                if (trimmed.startsWith('string "')) {
                    var qStart = trimmed.indexOf('"');
                    var qEnd = trimmed.lastIndexOf('"');
                    if (qStart >= 0 && qEnd > qStart) {
                        var strVal = trimmed.substring(qStart + 1, qEnd);
                        pendingNotifArgs.push(strVal);
                        if (pendingNotifArgs.length >= 3) {
                            flushPendingNotificationArgs();
                        }
                    }
                }
                return;
            }

            if (pendingMonitorDevId !== "" && pendingMonitorMember !== "") {
                if (pendingMonitorMember === "chargeChanged" && trimmed.indexOf("int32") !== -1) {
                    var numMatch = trimmed.match(/int32\s+([0-9]+)/);
                    if (numMatch && numMatch.length > 1) {
                        var cVal = parseInt(numMatch[1]);
                        var dObj = getDevice(pendingMonitorDevId);
                        var curChg = dObj ? (dObj.isCharging || false) : false;
                        updateDeviceBattery(pendingMonitorDevId, cVal, curChg);
                    }
                    pendingMonitorDevId = "";
                    pendingMonitorMember = "";
                } else if (pendingMonitorMember === "stateChanged" && trimmed.indexOf("boolean") !== -1) {
                    var boolMatch = trimmed.match(/boolean\s+(true|false)/);
                    if (boolMatch && boolMatch.length > 1) {
                        var isChg = boolMatch[1] === "true";
                        var dObj2 = getDevice(pendingMonitorDevId);
                        var curLvl = dObj2 ? (dObj2.batteryLevel !== undefined ? dObj2.batteryLevel : -1) : -1;
                        updateDeviceBattery(pendingMonitorDevId, curLvl, isChg);
                    }
                    pendingMonitorDevId = "";
                    pendingMonitorMember = "";
                }
            }
        } catch (err) {
            console.log("Error parsing monitor line:", err);
        }
    }


    // --- Process 3: Fetch and Parse Devices from kdeconnect-cli ---
    Process {
        id: deviceCheckProcess
        command: ["kdeconnect-cli", "-l"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                root.parseDeviceLine(line);
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.daemonAvailable = true;
                root.finalizeDeviceCheck();
            } else {
                root.daemonAvailable = false;
                root.isConnected = false;
                root.allDevices = [];
                root.reachableDevices = [];
                root.activeDevice = null;
                root.activeDeviceCount = 0;
                root.statusMessage = "kdeconnect-cli error (" + exitCode + "). Is kdeconnectd daemon running?";
            }
        }
    }

    function parseDeviceLine(line) {
        if (!line || typeof line !== "string" || line.trim() === "") return;
        try {
            var trimmed = line.trim();

            if (trimmed.startsWith("- ")) {
                var content = trimmed.substring(2);
                var colonIdx = content.indexOf(":");
                if (colonIdx > 0) {
                    var name = content.substring(0, colonIdx).trim();
                    var rest = content.substring(colonIdx + 1).trim();
                    var parenIdx = rest.indexOf("(");
                    var id = (parenIdx > 0 ? rest.substring(0, parenIdx) : rest).trim();
                    var status = parenIdx > 0 ? rest.substring(parenIdx + 1, rest.lastIndexOf(")")) : "";

                    var isReachable = status.indexOf("reachable") !== -1 || status.indexOf("connected") !== -1;
                    var isPaired = status.indexOf("paired") !== -1;

                    var lowerName = name.toLowerCase();
                    var type = "phone";
                    if (lowerName.indexOf("ipad") !== -1 || lowerName.indexOf("tablet") !== -1 || lowerName.indexOf("tab") !== -1) {
                        type = "tablet";
                    } else if (lowerName.indexOf("laptop") !== -1 || lowerName.indexOf("book") !== -1 || lowerName.indexOf("macbook") !== -1 || lowerName.indexOf("pc") !== -1 || lowerName.indexOf("desktop") !== -1) {
                        type = "laptop";
                    }

                    var existingDev = getDevice(id);
                    var existingCharge = (existingDev && existingDev.batteryLevel !== undefined) ? existingDev.batteryLevel : -1;
                    var existingIsCharging = (existingDev && existingDev.isCharging !== undefined) ? existingDev.isCharging : false;

                    var devObj = {
                        id: id,
                        name: name,
                        type: type,
                        paired: isPaired,
                        reachable: isReachable,
                        status: status,
                        batteryLevel: existingCharge,
                        isCharging: existingIsCharging
                    };

                    var existingIdx = -1;
                    for (var k = 0; k < parsedAccumulator.length; k++) {
                        if (parsedAccumulator[k].id === id) {
                            existingIdx = k;
                            break;
                        }
                    }
                    if (existingIdx >= 0) {
                        parsedAccumulator[existingIdx] = devObj;
                    } else {
                        parsedAccumulator.push(devObj);
                    }
                }
            }
        } catch (err) {
            console.log("Error parsing device line:", err);
        }
    }

    function finalizeDeviceCheck() {
        var all = parsedAccumulator.slice();
        var reachable = [];
        for (var i = 0; i < all.length; i++) {
            if (all[i].reachable) {
                reachable.push(all[i]);
            }
            var curSt = getPairingState(all[i].id);
            if (curSt === "pending" && all[i].paired) {
                setPairingState(all[i].id, "accepted");
                pairTimeoutTimer.stop();
            }
        }

        root.allDevices = all;
        root.reachableDevices = reachable;
        root.activeDeviceCount = reachable.length;
        root.isConnected = reachable.length > 0;

        var prevActiveId = root.activeDevice ? root.activeDevice.id : null;
        var foundActive = null;

        if (prevActiveId) {
            for (var j = 0; j < all.length; j++) {
                if (all[j].id === prevActiveId) {
                    foundActive = all[j];
                    break;
                }
            }
        }

        if (!foundActive) {
            foundActive = reachable.length > 0 ? reachable[0] : (all.length > 0 ? all[0] : null);
        }

        root.activeDevice = foundActive;

        if (!root.daemonAvailable) {
            root.statusMessage = "kdeconnect-cli error. Is kdeconnectd daemon running?";
        } else if (all.length === 0) {
            root.statusMessage = "No KDE Connect devices paired or connected.";
        } else if (reachable.length === 0) {
            root.statusMessage = all.length + " paired device(s) found, but none currently reachable on network.";
        } else {
            root.statusMessage = "Connected to " + (root.activeDevice ? root.activeDevice.name : reachable[0].name);
        }

        fetchBatteryStatus();
    }

    // --- Process 4: Fetch Battery Status via D-Bus gdbus Helper ---
    Process {
        id: batteryCheckProcess
        command: []
        running: false

        stdout: SplitParser {
            onRead: line => {
                root.parseBatteryLine(line);
            }
        }
    }

    function fetchBatteryStatus() {
        if (!root.dependenciesMet || root.allDevices.length === 0) {
            updateLowestBattery();
            return;
        }
        var ids = [];
        for (var i = 0; i < root.allDevices.length; i++) {
            if (root.allDevices[i].reachable) {
                ids.push(root.allDevices[i].id);
            }
        }
        if (ids.length === 0) {
            updateLowestBattery();
            return;
        }

        var cmd = ["bash", "-c",
            'for id in "$@"; do charge=$(gdbus call --session --dest org.kde.kdeconnect --object-path /modules/kdeconnect/devices/$id/battery --method org.kde.kdeconnect.device.battery.charge 2>/dev/null | grep -oE "[0-9]+" || echo "-1"); charging=$(gdbus call --session --dest org.kde.kdeconnect --object-path /modules/kdeconnect/devices/$id/battery --method org.kde.kdeconnect.device.battery.isCharging 2>/dev/null | grep -o "true" || echo "false"); echo "BATTERY:$id:$charge:$charging"; done',
            "inline_script"
        ];
        for (var j = 0; j < ids.length; j++) {
            cmd.push(ids[j]);
        }

        batteryCheckProcess.command = cmd;
        batteryCheckProcess.running = true;
    }

    function parseBatteryLine(line) {
        if (!line || typeof line !== "string" || !line.trim().startsWith("BATTERY:")) return;
        var parts = line.trim().split(":");
        if (parts.length >= 4) {
            var devId = parts[1];
            var charge = parseInt(parts[2]);
            var charging = parts[3] === "true";
            if (isNaN(charge) || charge < 0 || charge > 100) {
                charge = -1;
            }
            updateDeviceBattery(devId, charge, charging);
        }
    }

    function updateDeviceBattery(devId, charge, charging) {
        var updated = false;
        var all = root.allDevices.slice();
        for (var i = 0; i < all.length; i++) {
            if (all[i].id === devId) {
                all[i].batteryLevel = charge;
                all[i].isCharging = charging;
                updated = true;
                break;
            }
        }

        if (updated) {
            root.allDevices = all;
            var reachable = [];
            for (var j = 0; j < all.length; j++) {
                if (all[j].reachable) {
                    reachable.push(all[j]);
                }
            }
            root.reachableDevices = reachable;

            if (root.activeDevice && root.activeDevice.id === devId) {
                for (var k = 0; k < all.length; k++) {
                    if (all[k].id === devId) {
                        root.activeDevice = all[k];
                        break;
                    }
                }
            }
            updateLowestBattery();
        }
    }

    function updateLowestBattery() {
        var minBat = -1;
        for (var i = 0; i < root.reachableDevices.length; i++) {
            var dev = root.reachableDevices[i];
            if (dev.batteryLevel !== undefined && dev.batteryLevel !== null && typeof dev.batteryLevel === "number" && !isNaN(dev.batteryLevel) && dev.batteryLevel >= 0 && dev.batteryLevel <= 100) {
                if (minBat === -1 || dev.batteryLevel < minBat) {
                    minBat = dev.batteryLevel;
                }
            }
        }
        root.lowestBattery = minBat;
    }

    Component.onCompleted: {
        refresh();
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: refresh()
    }
}
