import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: root

    // --- Public Properties ---
    property var activeDevice: null
    property var actionRunner: null

    // --- Device Status Helper ---
    readonly property bool isDeviceReachable: activeDevice !== null && activeDevice !== undefined && activeDevice.reachable === true && activeDevice.paired === true

    // --- Action States ---
    property bool isRinging: false
    property bool ringInProgress: false
    property bool pingInProgress: false
    property bool showPingInput: false
    property string pingText: "Ping from OmaConnect!"

    // --- Clipboard Action States ---
    property bool shareInProgress: false
    property bool showClipboardInput: false
    property string clipboardText: ""
    property bool pasteInProgress: false
    property string accumulatedPasteText: ""

    // --- Visual Feedback States ---
    property string actionStatusMessage: ""
    property string actionStatusType: "" // "success", "error", "info", ""

    implicitWidth: parent ? parent.width : 320
    implicitHeight: mainColumn.implicitHeight

    // Reset action states when active device changes
    onActiveDeviceChanged: {
        isRinging = false;
        ringInProgress = false;
        pingInProgress = false;
        showPingInput = false;
        shareInProgress = false;
        showClipboardInput = false;
        clipboardText = "";
        pasteInProgress = false;
        accumulatedPasteText = "";
        actionStatusMessage = "";
        actionStatusType = "";
        if (pasteProcess.running) pasteProcess.running = false;
    }

    onIsDeviceReachableChanged: {
        if (!isDeviceReachable) {
            isRinging = false;
            ringInProgress = false;
            pingInProgress = false;
            shareInProgress = false;
            pasteInProgress = false;
            if (pasteProcess.running) pasteProcess.running = false;
            setStatus("⚠️ Device unreachable. Actions disabled.", "error");
        }
    }

    // Auto-clear success/info status messages after 5s
    Timer {
        id: statusTimer
        interval: 5000
        repeat: false
        onTriggered: {
            if (root.actionStatusType !== "error") {
                root.actionStatusMessage = "";
                root.actionStatusType = "";
            }
        }
    }

    function setStatus(msg, type) {
        actionStatusMessage = msg;
        actionStatusType = type;
        statusTimer.restart();
    }

    Connections {
        target: root.actionRunner
        function onStatusMessageChanged() {
            root.ringInProgress = false;
            root.pingInProgress = false;
            root.shareInProgress = false;
            root.fileInProgress = false;
            if (root.actionRunner && root.actionRunner.statusMessage)
                root.setStatus(root.actionRunner.statusMessage,
                    root.actionRunner.lastActionError ? "error" : "success");
        }
    }

    // --- Clipboard read process ---
    Process {
        id: pasteProcess
        command: ["bash", "-c", "which wl-paste >/dev/null 2>&1 || exit 127; wl-paste --no-newline 2>/dev/null || wl-paste 2>/dev/null"]
        running: false

        stdout: SplitParser {
            onRead: line => {
                // SplitParser removes line separators; restore them so multiline
                // clipboard content is not silently concatenated.
                root.accumulatedPasteText += line + "\n";
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.pasteInProgress = false;
            if (exitCode === 127) {
                root.setStatus("⚠️ wl-clipboard tool (wl-paste) is not installed.", "error");
            } else if (exitCode === 0) {
                var text = root.accumulatedPasteText;
                if (text && text.trim().length > 0) {
                    root.clipboardText = text;
                    root.setStatus("📋 Pasted from Wayland clipboard (" + text.trim().length + " chars)", "success");
                } else {
                    root.setStatus("⚠️ Clipboard is empty or contains non-text content.", "error");
                }
            } else {
                root.setStatus("⚠️ Failed to read Wayland clipboard (exit code " + exitCode + ")", "error");
            }
        }
    }

    // --- Actions ---
    function triggerRing() {
        if (!isDeviceReachable || ringInProgress) return;
        if (!activeDevice || !activeDevice.id) return;
        ringInProgress = true;
        setStatus("Sending ring request...", "info");
        if (root.actionRunner) root.actionRunner.ringDevice(activeDevice.id);
    }

    function triggerPing(customMessage) {
        if (!isDeviceReachable || pingInProgress) return;
        if (!activeDevice || !activeDevice.id) return;

        var msg = (customMessage && customMessage.trim().length > 0) ? customMessage.trim() : pingText;
        pingInProgress = true;
        setStatus("Sending ping to device...", "info");
        if (root.actionRunner) root.actionRunner.pingDevice(activeDevice.id, msg);
    }

    function pasteClipboard() {
        if (pasteInProgress) return;
        accumulatedPasteText = "";
        pasteInProgress = true;
        setStatus("Reading Wayland clipboard...", "info");
        pasteProcess.running = true;
    }

    function triggerShareText(customText) {
        if (!isDeviceReachable) {
            setStatus("⚠️ Cannot send: Device is offline or unreachable.", "error");
            return;
        }
        if (shareInProgress) return;
        if (!activeDevice || !activeDevice.id) return;

        var text = (customText !== undefined && customText !== null) ? customText : clipboardText;
        if (!text || text.trim().length === 0) {
            setStatus("⚠️ Please enter text or paste clipboard content first.", "error");
            return;
        }

        shareInProgress = true;
        setStatus("Sending text to device...", "info");
        if (root.actionRunner) root.actionRunner.shareText(activeDevice.id, text);
    }

    property bool fileInProgress: false

    function triggerFileShare() {
        if (!isDeviceReachable || fileInProgress || !activeDevice || !activeDevice.id) return;

        fileInProgress = true;
        setStatus("Choose a file to share...", "info");
        if (root.actionRunner) root.actionRunner.sendFile(activeDevice.id);
    }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10

        // Section Title
        Text {
            text: "Quick Actions"
            font.pixelSize: 12
            font.weight: Font.Bold
            color: Theme.textSecondary
            Layout.fillWidth: true
        }

        // Action Buttons Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // --- Button 1: Ring Phone ---
            Rectangle {
                id: ringButton
                Layout.fillWidth: true
                implicitHeight: 60
                radius: Theme.radiusSm
                opacity: root.isDeviceReachable ? 1.0 : 0.55
                activeFocusOnTab: root.isDeviceReachable && !root.ringInProgress
                focus: true
                color: {
                    if (root.ringInProgress) return Qt.rgba(0.96, 0.62, 0.04, 0.25);
                    if (root.isRinging) return Qt.rgba(0.96, 0.62, 0.04, 0.2);
                    if ((ringMouse.containsMouse || ringButton.activeFocus) && root.isDeviceReachable) return Theme.bgSurfaceHover;
                    return Theme.bgSurface;
                }
                border.color: {
                    if (ringButton.activeFocus) return Theme.borderActive;
                    if (root.isRinging || root.ringInProgress) return Theme.accentWarning;
                    if (ringMouse.containsMouse && root.isDeviceReachable) return Theme.borderActive;
                    return Theme.borderSubtle;
                }
                border.width: (ringButton.activeFocus || root.isRinging || root.ringInProgress) ? 2 : 1

                Keys.onReturnPressed: {
                    if (root.isDeviceReachable && !root.ringInProgress) root.triggerRing();
                }
                Keys.onSpacePressed: {
                    if (root.isDeviceReachable && !root.ringInProgress) root.triggerRing();
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.animDurationNormal }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Theme.animDurationNormal }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    // Icon Container
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: root.isRinging ? Qt.rgba(0.96, 0.62, 0.04, 0.3) : Qt.rgba(0.96, 0.62, 0.04, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: root.ringInProgress ? "⏳" : (root.isRinging ? "🔊" : "🔔")
                            font.pixelSize: 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Ring Phone"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: root.isDeviceReachable ? Theme.textPrimary : Theme.textMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            text: {
                                if (root.ringInProgress) return "Triggering...";
                                if (root.isRinging) return "Active";
                                if (!root.isDeviceReachable) return "Unreachable";
                                return "Find Phone";
                            }
                            font.pixelSize: 10
                            color: (root.isRinging || root.ringInProgress) ? Theme.accentWarning : Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: ringMouse
                    anchors.fill: parent
                    hoverEnabled: root.isDeviceReachable && !root.ringInProgress
                    enabled: root.isDeviceReachable && !root.ringInProgress
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: root.triggerRing()
                }
            }

            // --- Button 2: Send Ping ---
            Rectangle {
                id: pingButton
                Layout.fillWidth: true
                implicitHeight: 60
                radius: Theme.radiusSm
                opacity: root.isDeviceReachable ? 1.0 : 0.55
                activeFocusOnTab: root.isDeviceReachable && !root.pingInProgress
                focus: true
                color: {
                    if (root.pingInProgress) return Qt.rgba(0.23, 0.51, 0.96, 0.25);
                    if (root.showPingInput) return Qt.rgba(0.23, 0.51, 0.96, 0.15);
                    if ((pingMouse.containsMouse || pingButton.activeFocus) && root.isDeviceReachable) return Theme.bgSurfaceHover;
                    return Theme.bgSurface;
                }
                border.color: {
                    if (pingButton.activeFocus) return Theme.borderActive;
                    if (root.showPingInput || root.pingInProgress) return Theme.accentPrimary;
                    if (pingMouse.containsMouse && root.isDeviceReachable) return Theme.borderActive;
                    return Theme.borderSubtle;
                }
                border.width: (pingButton.activeFocus || root.showPingInput || root.pingInProgress) ? 2 : 1

                Keys.onReturnPressed: {
                    if (root.isDeviceReachable && !root.pingInProgress) {
                        root.showPingInput = !root.showPingInput;
                        if (root.showPingInput) root.showClipboardInput = false;
                    }
                }
                Keys.onSpacePressed: {
                    if (root.isDeviceReachable && !root.pingInProgress) {
                        root.showPingInput = !root.showPingInput;
                        if (root.showPingInput) root.showClipboardInput = false;
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.animDurationNormal }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Theme.animDurationNormal }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    // Icon Container
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: root.showPingInput ? Qt.rgba(0.23, 0.51, 0.96, 0.3) : Qt.rgba(0.23, 0.51, 0.96, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: root.pingInProgress ? "⏳" : "📡"
                            font.pixelSize: 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Send Ping"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: root.isDeviceReachable ? Theme.textPrimary : Theme.textMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            text: {
                                if (root.pingInProgress) return "Sending...";
                                if (root.showPingInput) return "Compose";
                                if (!root.isDeviceReachable) return "Unreachable";
                                return "Notification";
                            }
                            font.pixelSize: 10
                            color: (root.showPingInput || root.pingInProgress) ? Theme.accentPrimary : Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: pingMouse
                    anchors.fill: parent
                    hoverEnabled: root.isDeviceReachable && !root.pingInProgress
                    enabled: root.isDeviceReachable && !root.pingInProgress
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        root.showPingInput = !root.showPingInput;
                        if (root.showPingInput) {
                            root.showClipboardInput = false;
                        }
                    }
                }
            }

            // --- Button 3: Send Clipboard / Link ---
            Rectangle {
                id: clipButton
                Layout.fillWidth: true
                implicitHeight: 60
                radius: Theme.radiusSm
                opacity: root.isDeviceReachable ? 1.0 : 0.55
                activeFocusOnTab: root.isDeviceReachable && !root.shareInProgress
                focus: true
                color: {
                    if (root.shareInProgress || root.pasteInProgress) return Qt.rgba(0.06, 0.73, 0.51, 0.25);
                    if (root.showClipboardInput) return Qt.rgba(0.06, 0.73, 0.51, 0.15);
                    if ((clipMouse.containsMouse || clipButton.activeFocus) && root.isDeviceReachable) return Theme.bgSurfaceHover;
                    return Theme.bgSurface;
                }
                border.color: {
                    if (clipButton.activeFocus) return Theme.borderActive;
                    if (root.showClipboardInput || root.shareInProgress || root.pasteInProgress) return Theme.accentSuccess;
                    if (clipMouse.containsMouse && root.isDeviceReachable) return Theme.borderActive;
                    return Theme.borderSubtle;
                }
                border.width: (clipButton.activeFocus || root.showClipboardInput || root.shareInProgress || root.pasteInProgress) ? 2 : 1

                Keys.onReturnPressed: {
                    if (root.isDeviceReachable && !root.shareInProgress) {
                        root.showClipboardInput = !root.showClipboardInput;
                        if (root.showClipboardInput) root.showPingInput = false;
                    }
                }
                Keys.onSpacePressed: {
                    if (root.isDeviceReachable && !root.shareInProgress) {
                        root.showClipboardInput = !root.showClipboardInput;
                        if (root.showClipboardInput) root.showPingInput = false;
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: Theme.animDurationNormal }
                }
                Behavior on border.color {
                    ColorAnimation { duration: Theme.animDurationNormal }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 6

                    // Icon Container
                    Rectangle {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: Theme.radiusSm
                        color: root.showClipboardInput ? Qt.rgba(0.06, 0.73, 0.51, 0.3) : Qt.rgba(0.06, 0.73, 0.51, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: (root.shareInProgress || root.pasteInProgress) ? "⏳" : "📋"
                            font.pixelSize: 16
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Send Clip"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            color: root.isDeviceReachable ? Theme.textPrimary : Theme.textMuted
                            elide: Text.ElideRight
                        }

                        Text {
                            text: {
                                if (root.shareInProgress) return "Sending...";
                                if (root.pasteInProgress) return "Pasting...";
                                if (root.showClipboardInput) return "Compose";
                                if (!root.isDeviceReachable) return "Unreachable";
                                return "Text / Link";
                            }
                            font.pixelSize: 10
                            color: (root.showClipboardInput || root.shareInProgress) ? Theme.accentSuccess : Theme.textSecondary
                            elide: Text.ElideRight
                        }
                    }
                }

                MouseArea {
                    id: clipMouse
                    anchors.fill: parent
                    hoverEnabled: root.isDeviceReachable && !root.shareInProgress
                    enabled: root.isDeviceReachable && !root.shareInProgress
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                    onClicked: {
                        root.showClipboardInput = !root.showClipboardInput;
                        if (root.showClipboardInput) {
                            root.showPingInput = false;
                        }
                    }
                }
            }
        }

        Rectangle {
            id: fileButton
            Layout.fillWidth: true
            implicitHeight: 36
            radius: Theme.radiusSm
            opacity: root.isDeviceReachable ? 1.0 : 0.55
            activeFocusOnTab: root.isDeviceReachable && !root.fileInProgress
            focus: true
            color: (fileMouse.containsMouse || fileButton.activeFocus) && root.isDeviceReachable ? Theme.bgSurfaceHover : Theme.bgSurface
            border.color: fileButton.activeFocus ? Theme.borderActive : Theme.borderSubtle
            border.width: fileButton.activeFocus ? 2 : 1

            Keys.onReturnPressed: {
                if (root.isDeviceReachable && !root.fileInProgress) root.triggerFileShare();
            }
            Keys.onSpacePressed: {
                if (root.isDeviceReachable && !root.fileInProgress) root.triggerFileShare();
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                Text { text: root.fileInProgress ? "⏳" : "📁"; font.pixelSize: 13 }
                Text {
                    text: root.fileInProgress ? "Choosing / Sending..." : "Send File"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: root.isDeviceReachable ? Theme.textPrimary : Theme.textMuted
                }
            }

            MouseArea {
                id: fileMouse
                anchors.fill: parent
                enabled: root.isDeviceReachable && !root.fileInProgress
                hoverEnabled: enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                onClicked: root.triggerFileShare()
            }
        }

        // --- Ping Compose Message Panel ---
        Rectangle {
            visible: root.showPingInput && root.isDeviceReachable
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Theme.radiusSm
            color: Theme.bgSurface
            border.color: Theme.borderActive
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: Theme.radiusSm
                    color: Theme.bgBase
                    border.color: inputField.activeFocus ? Theme.accentPrimary : Theme.borderSubtle

                    TextInput {
                        id: inputField
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        anchors.topMargin: 7
                        anchors.bottomMargin: 7
                        text: root.pingText
                        color: Theme.textPrimary
                        font.pixelSize: 12
                        selectByMouse: true

                        onAccepted: {
                            root.triggerPing(inputField.text);
                        }
                    }
                }

                // Send Button
                Rectangle {
                    id: sendPingBtn
                    implicitWidth: 64
                    implicitHeight: 32
                    radius: Theme.radiusSm
                    activeFocusOnTab: !root.pingInProgress
                    focus: true
                    color: {
                        if (root.pingInProgress) return Theme.textMuted;
                        if (sendMouse.containsMouse || sendPingBtn.activeFocus) return Qt.darker(Theme.accentPrimary, 1.15);
                        return Theme.accentPrimary;
                    }
                    border.color: sendPingBtn.activeFocus ? Theme.borderActive : "transparent"
                    border.width: sendPingBtn.activeFocus ? 2 : 0

                    Keys.onReturnPressed: {
                        if (!root.pingInProgress) root.triggerPing(inputField.text);
                    }
                    Keys.onSpacePressed: {
                        if (!root.pingInProgress) root.triggerPing(inputField.text);
                    }

                    Text {
                        anchors.centerIn: parent
                        text: root.pingInProgress ? "..." : "Send"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: sendMouse
                        anchors.fill: parent
                        hoverEnabled: !root.pingInProgress
                        enabled: !root.pingInProgress
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                        onClicked: root.triggerPing(inputField.text)
                    }
                }
            }
        }

        // --- Clipboard / Link Compose Panel ---
        Rectangle {
            visible: root.showClipboardInput && root.isDeviceReachable
            Layout.fillWidth: true
            implicitHeight: clipComposerColumn.implicitHeight + 16
            radius: Theme.radiusSm
            color: Theme.bgSurface
            border.color: Theme.borderActive
            border.width: 1

            ColumnLayout {
                id: clipComposerColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Header / Instruction label
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "📋 Send Text or Link"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Theme.textPrimary
                        Layout.fillWidth: true
                    }

                    // Quick Paste from Clipboard Button
                    Rectangle {
                        id: pasteClipBtn
                        implicitWidth: pasteRowLayout.implicitWidth + 12
                        implicitHeight: 26
                        radius: Theme.radiusSm
                        activeFocusOnTab: !root.pasteInProgress
                        focus: true
                        color: {
                            if (root.pasteInProgress) return Qt.rgba(0.23, 0.51, 0.96, 0.2);
                            if (pasteMouse.containsMouse || pasteClipBtn.activeFocus) return Theme.bgSurfaceHover;
                            return Qt.rgba(0.23, 0.51, 0.96, 0.12);
                        }
                        border.color: pasteClipBtn.activeFocus ? Theme.borderActive : Theme.accentPrimary
                        border.width: pasteClipBtn.activeFocus ? 2 : 1

                        Keys.onReturnPressed: {
                            if (!root.pasteInProgress) root.pasteClipboard();
                        }
                        Keys.onSpacePressed: {
                            if (!root.pasteInProgress) root.pasteClipboard();
                        }

                        RowLayout {
                            id: pasteRowLayout
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: root.pasteInProgress ? "⏳" : "📋"
                                font.pixelSize: 11
                            }
                            Text {
                                text: root.pasteInProgress ? "Pasting..." : "Paste Clipboard"
                                font.pixelSize: 11
                                font.bold: true
                                color: Theme.accentPrimary
                            }
                        }

                        MouseArea {
                            id: pasteMouse
                            anchors.fill: parent
                            hoverEnabled: !root.pasteInProgress
                            enabled: !root.pasteInProgress
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: root.pasteClipboard()
                        }
                    }
                }

                // Text Input Area
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 60
                    radius: Theme.radiusSm
                    color: Theme.bgBase
                    border.color: clipInputField.activeFocus ? Theme.accentSuccess : Theme.borderSubtle

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 6
                        contentWidth: clipInputField.width
                        contentHeight: clipInputField.height
                        clip: true

                        TextEdit {
                            id: clipInputField
                            width: parent.width
                            text: root.clipboardText
                            color: Theme.textPrimary
                            font.pixelSize: 12
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true

                            onTextChanged: {
                                root.clipboardText = text;
                            }
                        }
                    }

                    Text {
                        visible: clipInputField.text.length === 0
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 6
                        text: "Type custom text, URL (http/https), or click Paste Clipboard..."
                        font.pixelSize: 11
                        color: Theme.textMuted
                    }
                }

                // Bottom Action Row: Clear & Send Button
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        id: clearClipBtn
                        implicitWidth: 54
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        activeFocusOnTab: clipInputField.text.length > 0
                        focus: true
                        color: (clearClipMouse.containsMouse || clearClipBtn.activeFocus) ? Theme.bgSurfaceHover : Theme.bgSurface
                        border.color: clearClipBtn.activeFocus ? Theme.borderActive : Theme.borderSubtle
                        border.width: clearClipBtn.activeFocus ? 2 : 1
                        visible: clipInputField.text.length > 0

                        Keys.onReturnPressed: {
                            clipInputField.text = "";
                            root.clipboardText = "";
                        }
                        Keys.onSpacePressed: {
                            clipInputField.text = "";
                            root.clipboardText = "";
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "Clear"
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }

                        MouseArea {
                            id: clearClipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                clipInputField.text = "";
                                root.clipboardText = "";
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Send Button
                    Rectangle {
                        id: sendClipBtn
                        implicitWidth: 80
                        implicitHeight: 28
                        radius: Theme.radiusSm
                        activeFocusOnTab: root.isDeviceReachable && !root.shareInProgress
                        focus: true
                        color: {
                            if (root.shareInProgress) return Theme.textMuted;
                            if (!root.isDeviceReachable) return Theme.textMuted;
                            if (sendClipMouse.containsMouse || sendClipBtn.activeFocus) return Qt.darker(Theme.accentSuccess, 1.15);
                            return Theme.accentSuccess;
                        }
                        border.color: sendClipBtn.activeFocus ? Theme.borderActive : "transparent"
                        border.width: sendClipBtn.activeFocus ? 2 : 0

                        Keys.onReturnPressed: {
                            if (root.isDeviceReachable && !root.shareInProgress) root.triggerShareText(clipInputField.text);
                        }
                        Keys.onSpacePressed: {
                            if (root.isDeviceReachable && !root.shareInProgress) root.triggerShareText(clipInputField.text);
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                text: root.shareInProgress ? "⏳" : "🚀"
                                font.pixelSize: 11
                            }
                            Text {
                                text: root.shareInProgress ? "Sending..." : "Send"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            id: sendClipMouse
                            anchors.fill: parent
                            hoverEnabled: root.isDeviceReachable && !root.shareInProgress
                            enabled: root.isDeviceReachable && !root.shareInProgress
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            onClicked: root.triggerShareText(clipInputField.text)
                        }
                    }
                }
            }
        }

        // --- Inline Status / Error Visual Feedback Banner ---
        Rectangle {
            visible: root.actionStatusMessage !== ""
            Layout.fillWidth: true
            implicitHeight: statusLayout.implicitHeight + 14
            radius: Theme.radiusSm
            color: {
                if (root.actionStatusType === "success") return Qt.rgba(0.06, 0.73, 0.51, 0.15);
                if (root.actionStatusType === "error") return Qt.rgba(0.94, 0.38, 0.38, 0.15);
                return Qt.rgba(0.23, 0.51, 0.96, 0.15);
            }
            border.color: {
                if (root.actionStatusType === "success") return Theme.accentSuccess;
                if (root.actionStatusType === "error") return Theme.accentDanger;
                return Theme.accentPrimary;
            }
            border.width: 1

            RowLayout {
                id: statusLayout
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Text {
                    text: {
                        if (root.actionStatusType === "success") return "✅";
                        if (root.actionStatusType === "error") return "❌";
                        return "ℹ️";
                    }
                    font.pixelSize: 12
                }

                Text {
                    Layout.fillWidth: true
                    text: root.actionStatusMessage
                    font.pixelSize: 12
                    color: {
                        if (root.actionStatusType === "success") return Theme.accentSuccess;
                        if (root.actionStatusType === "error") return Theme.accentDanger;
                        return Theme.textPrimary;
                    }
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
