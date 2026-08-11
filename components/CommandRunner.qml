import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // --- Public Properties ---
    property var activeDevice: null
    property var commandList: []
    property bool isLoading: false
    property string executingKey: ""

    // --- Visual Feedback States ---
    property string statusMessage: ""
    property string statusType: "" // "success", "error", "info", ""

    // --- Reachability Guard ---
    readonly property bool isDeviceReachable: activeDevice !== null && activeDevice !== undefined && activeDevice.reachable === true && activeDevice.paired === true

    implicitWidth: parent ? parent.width : 320
    implicitHeight: mainColumn.implicitHeight

    // Re-fetch commands when active device changes
    onActiveDeviceChanged: {
        if (listProcess.running) listProcess.running = false;
        if (executeProcess.running) executeProcess.running = false;
        commandList = [];
        executingKey = "";
        statusMessage = "";
        statusType = "";
        if (isDeviceReachable) {
            fetchCommands();
        }
    }

    // Auto-clear status message after 5 seconds
    Timer {
        id: statusTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (root.statusType !== "error") {
                root.statusMessage = "";
                root.statusType = "";
            }
        }
    }

    function setStatus(msg, type) {
        statusMessage = msg;
        statusType = type;
        statusTimer.restart();
    }

    // Process to list commands
    Process {
        id: listProcess
        running: false
        property string pendingOutput: ""
        property string targetDeviceId: ""

        stdout: SplitParser {
            onRead: line => {
                listProcess.pendingOutput += line + "\n";
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (targetDeviceId !== "" && (!root.activeDevice || root.activeDevice.id !== targetDeviceId)) return;
            root.isLoading = false;
            if (exitCode === 0) {
                root.commandList = root.parseCommandsOutput(listProcess.pendingOutput);
            } else {
                root.commandList = [];
            }
        }
    }

    // Process to execute a command
    Process {
        id: executeProcess
        running: false
        property string currentKey: ""
        property string currentName: ""
        property string targetDeviceId: ""

        onExited: (exitCode, exitStatus) => {
            if (targetDeviceId !== "" && (!root.activeDevice || root.activeDevice.id !== targetDeviceId)) return;
            var cmdName = executeProcess.currentName || executeProcess.currentKey;
            root.executingKey = "";
            if (exitCode === 0) {
                root.setStatus("Executed '" + cmdName + "' successfully", "success");
            } else {
                root.setStatus("Failed to execute '" + cmdName + "' (exit code " + exitCode + ")", "error");
            }
        }
    }

    // Fetch commands for active device
    function fetchCommands() {
        if (!isDeviceReachable || !activeDevice || !activeDevice.id) {
            commandList = [];
            isLoading = false;
            return;
        }

        listProcess.running = false;
        listProcess.pendingOutput = "";
        listProcess.targetDeviceId = activeDevice.id;
        listProcess.command = ["kdeconnect-cli", "-d", activeDevice.id, "--list-commands"];
        isLoading = true;
        listProcess.running = true;
    }

    // Execute remote command
    function runCommand(key, name) {
        if (!isDeviceReachable || executingKey !== "") return;
        if (!activeDevice || !activeDevice.id || !key) return;

        executingKey = key;
        executeProcess.currentKey = key;
        executeProcess.currentName = name;
        executeProcess.targetDeviceId = activeDevice.id;
        setStatus("Executing '" + name + "'...", "info");

        executeProcess.running = false;
        executeProcess.command = ["kdeconnect-cli", "-d", activeDevice.id, "--execute-command", key];
        executeProcess.running = true;
    }

    // Output parser helper for list-commands
    function parseCommandsOutput(text) {
        if (!text || typeof text !== "string" || text.trim() === "") {
            return [];
        }
        var trimmed = text.trim();
        if (trimmed.indexOf("No commands") !== -1 || trimmed.indexOf("error:") !== -1 || trimmed.indexOf("Device unreachable") !== -1) {
            return [];
        }

        var result = [];

        // Try JSON parsing
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
                // Not valid JSON, continue to line parsing
            }
        }

        // Line parsing
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

    // Helper for command icon selection
    function getCommandIcon(key, name) {
        var str = (key + " " + name).toLowerCase();
        if (str.indexOf("lock") !== -1) return "🔒";
        if (str.indexOf("suspend") !== -1 || str.indexOf("sleep") !== -1) return "💻";
        if (str.indexOf("play") !== -1 || str.indexOf("pause") !== -1 || str.indexOf("media") !== -1) return "⏯️";
        if (str.indexOf("volume") !== -1 || str.indexOf("sound") !== -1 || str.indexOf("mute") !== -1) return "🔊";
        if (str.indexOf("bright") !== -1) return "☀️";
        if (str.indexOf("reboot") !== -1 || str.indexOf("restart") !== -1) return "🔄";
        if (str.indexOf("shutdown") !== -1 || str.indexOf("power") !== -1) return "⚡";
        return "⚡";
    }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10

        // Section Title & Refresh Button Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Remote Commands"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: Theme.textSecondary
                Layout.fillWidth: true
            }

            // Refresh Commands Button
            Rectangle {
                visible: root.isDeviceReachable
                implicitWidth: 22
                implicitHeight: 22
                radius: Theme.radiusSm
                color: refreshCmdMouse.containsMouse ? Theme.bgSurfaceHover : Theme.bgSurface
                border.color: Theme.borderSubtle

                Text {
                    anchors.centerIn: parent
                    text: root.isLoading ? "⏳" : "🔄"
                    font.pixelSize: 10
                }

                MouseArea {
                    id: refreshCmdMouse
                    anchors.fill: parent
                    hoverEnabled: !root.isLoading
                    enabled: !root.isLoading
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: root.fetchCommands()
                }
            }
        }

        // State 1: Disconnected / Unreachable Device State Banner
        Rectangle {
            visible: !root.isDeviceReachable
            Layout.fillWidth: true
            implicitHeight: offlineLayout.implicitHeight + 16
            radius: Theme.radiusSm
            color: Qt.rgba(0.96, 0.62, 0.04, 0.1)
            border.color: Theme.accentWarning
            border.width: 1

            RowLayout {
                id: offlineLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "⚠️"
                    font.pixelSize: 14
                }

                Text {
                    Layout.fillWidth: true
                    text: "Device is offline. Connect to Wi-Fi to execute remote commands."
                    font.pixelSize: 11
                    color: Theme.accentWarning
                    wrapMode: Text.WordWrap
                }
            }
        }

        // State 2: Fetching / Loading Commands State Banner
        Rectangle {
            visible: root.isDeviceReachable && root.isLoading
            Layout.fillWidth: true
            implicitHeight: loadingLayout.implicitHeight + 16
            radius: Theme.radiusSm
            color: Theme.bgSurface
            border.color: Theme.borderSubtle
            border.width: 1

            RowLayout {
                id: loadingLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "⏳"
                    font.pixelSize: 14
                }

                Text {
                    Layout.fillWidth: true
                    text: "Fetching configured remote commands..."
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }
            }
        }

        // State 3: Reachable Device but Zero Commands Configured Empty State Banner
        Rectangle {
            visible: root.isDeviceReachable && !root.isLoading && root.commandList.length === 0
            Layout.fillWidth: true
            implicitHeight: emptyCmdLayout.implicitHeight + 18
            radius: Theme.radiusSm
            color: Theme.bgSurface
            border.color: Theme.borderSubtle
            border.width: 1

            ColumnLayout {
                id: emptyCmdLayout
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                RowLayout {
                    spacing: 6

                    Text {
                        text: "⚡"
                        font.pixelSize: 13
                    }

                    Text {
                        text: "No Remote Commands Configured"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Add commands in the KDE Connect app on your mobile device to run them from OmaConnect."
                    font.pixelSize: 11
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                }
            }
        }

        // State 4: Reachable Device with Remote Commands Chips
        Flow {
            visible: root.isDeviceReachable && !root.isLoading && root.commandList.length > 0
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: root.commandList

                Rectangle {
                    id: chip
                    implicitWidth: chipRow.implicitWidth + 20
                    implicitHeight: 36
                    radius: Theme.radiusSm
                    color: {
                        if (root.executingKey === modelData.key) return Qt.rgba(0.23, 0.51, 0.96, 0.25);
                        if (chipMouse.containsMouse && root.executingKey === "") return Theme.bgSurfaceHover;
                        return Theme.bgSurface;
                    }
                    border.color: {
                        if (root.executingKey === modelData.key) return Theme.accentPrimary;
                        if (chipMouse.containsMouse && root.executingKey === "") return Theme.borderActive;
                        return Theme.borderSubtle;
                    }
                    border.width: (root.executingKey === modelData.key || chipMouse.containsMouse) ? 1.5 : 1
                    opacity: root.executingKey !== "" && root.executingKey !== modelData.key ? 0.5 : 1.0

                    Behavior on color {
                        ColorAnimation { duration: Theme.animDurationNormal }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: Theme.animDurationNormal }
                    }

                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: root.executingKey === modelData.key ? "⏳" : root.getCommandIcon(modelData.key, modelData.name)
                            font.pixelSize: 12
                        }

                        Text {
                            text: modelData.name
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent
                        hoverEnabled: root.executingKey === ""
                        enabled: root.executingKey === ""
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: root.runCommand(modelData.key, modelData.name)
                    }
                }
            }
        }

        // Inline Status Feedback Banner
        Rectangle {
            visible: root.statusMessage !== ""
            Layout.fillWidth: true
            implicitHeight: statusMsgLayout.implicitHeight + 14
            radius: Theme.radiusSm
            color: {
                if (root.statusType === "success") return Qt.rgba(0.06, 0.73, 0.51, 0.15);
                if (root.statusType === "error") return Qt.rgba(0.94, 0.38, 0.38, 0.15);
                return Qt.rgba(0.23, 0.51, 0.96, 0.15);
            }
            border.color: {
                if (root.statusType === "success") return Theme.accentSuccess;
                if (root.statusType === "error") return Theme.accentDanger;
                return Theme.accentPrimary;
            }
            border.width: 1

            RowLayout {
                id: statusMsgLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: {
                        if (root.statusType === "success") return "✅";
                        if (root.statusType === "error") return "❌";
                        return "ℹ️";
                    }
                    font.pixelSize: 12
                }

                Text {
                    Layout.fillWidth: true
                    text: root.statusMessage
                    font.pixelSize: 12
                    color: {
                        if (root.statusType === "success") return Theme.accentSuccess;
                        if (root.statusType === "error") return Theme.accentDanger;
                        return Theme.textPrimary;
                    }
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
