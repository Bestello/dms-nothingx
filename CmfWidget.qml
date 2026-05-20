import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    layerNamespacePlugin: "cmf-controller"
    
    // --- STATE VARIABLES ---
    property string macAddress: pluginData.macAddress ?? ""
    property string currentMode: pluginData.currentMode ?? "off"
    property string ancSubMode: pluginData.ancSubMode ?? "adaptive"
    property string eqPreset: pluginData.eqPreset ?? "balanced"
    property bool spatialAudio: pluginData.spatialAudio ?? false
    property bool gamingMode: pluginData.gamingMode ?? false
    property bool inEarDetection: pluginData.inEarDetection ?? true
    property bool ultraBass: pluginData.ultraBass ?? false

    property int batteryL: 0
    property int batteryR: 0
    property int batteryC: 0

    property bool isConnected: false

    // --- SETTINGS FETCH QUEUE ---
    // Used to query every device setting sequentially on connect
    property var settingsFetchQueue: []
    property int settingsFetchIndex: 0
    
    // Asset paths for UI and Notifications
    // Qt.resolvedUrl(".") returns the directory containing this QML file,
    // making all paths relative to the plugin folder regardless of install location.
    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")
    property string leftBudImg: pluginDir + "/assets/left_bud.png"
    property string rightBudImg: pluginDir + "/assets/right_bud.png"
    property string caseImg: pluginDir + "/assets/case.png"

    // Kick off a sequential fetch of all device settings
    function startSettingsRefresh() {
        root.settingsFetchQueue = ["anc_mode", "eq_mode", "spatial_audio", "latency", "in_ear", "getultra_bass"];
        root.settingsFetchIndex = 0;
        settingsFetchNextTimer.start();
    }

    // Run the next item in the settings fetch queue
    function fetchNextSetting() {
        if (!root.isConnected || root.macAddress === "") return;
        if (root.settingsFetchIndex >= root.settingsFetchQueue.length) return;
        if (settingsFetchProcess.running) {
            settingsFetchNextTimer.start(); // back off and retry
            return;
        }
        var setting = root.settingsFetchQueue[root.settingsFetchIndex];
        root.settingsFetchIndex++;
        settingsFetchProcess.currentSetting = setting;
        settingsFetchProcess.command = ["python3", root.pluginDir + "/cmf_controller.py", root.macAddress, setting];
        settingsFetchProcess.running = true;
    }

    // Apply a parsed JSON response from the device to the correct UI property.
    // IMPORTANT: Do NOT assign root.* directly — that breaks the QML binding to pluginData.
    // Only call pluginService.savePluginData() so pluginData stays live and the binding
    // re-evaluates naturally (same pattern as click handlers).
    function applySettingResponse(setting, jsonBuffer) {
        if (!pluginService) return;
        try {
            var jsonStart = jsonBuffer.indexOf("{");
            var jsonEnd   = jsonBuffer.lastIndexOf("}");
            if (jsonStart === -1 || jsonEnd === -1) return;
            var data = JSON.parse(jsonBuffer.substring(jsonStart, jsonEnd + 1));

            if (setting === "anc_mode" && data.anc_mode !== undefined) {
                var mode = data.anc_mode;
                if (mode === "off") {
                    pluginService.savePluginData(pluginId, "currentMode", "off");
                } else if (mode === "transparency") {
                    pluginService.savePluginData(pluginId, "currentMode", "transparency");
                } else {
                    // high / mid / low / adaptive
                    pluginService.savePluginData(pluginId, "currentMode", "anc");
                    pluginService.savePluginData(pluginId, "ancSubMode", mode);
                }

            } else if (setting === "eq_mode" && data.eq_preset !== undefined) {
                pluginService.savePluginData(pluginId, "eqPreset", data.eq_preset);

            } else if (setting === "spatial_audio" && data.spatial_audio !== undefined) {
                pluginService.savePluginData(pluginId, "spatialAudio", (data.spatial_audio !== "off"));

            } else if (setting === "latency" && data.low_latency !== undefined) {
                pluginService.savePluginData(pluginId, "gamingMode", data.low_latency);

            } else if (setting === "in_ear" && data.in_ear_detection !== undefined) {
                pluginService.savePluginData(pluginId, "inEarDetection", data.in_ear_detection);

            } else if (setting === "getultra_bass" && data.enhanced_bass !== undefined) {
                pluginService.savePluginData(pluginId, "ultraBass", data.enhanced_bass.enabled);
            }
        } catch(e) { }
    }

    function sendCommand(feature, value, friendlyName) {
        if (root.macAddress === "") {
            ToastService.showError("CMF Buds", "Please configure MAC in Settings");
            return;
        }
        if (!root.isConnected) {
            ToastService.showError("CMF Buds", "Earbuds are disconnected");
            return;
        }
        var script = root.pluginDir + "/cmf_controller.py";
        var cmd = "python3 " + script + " " + root.macAddress + " " + feature + " " + value + " >> /tmp/cmf_bash.log 2>&1";
        Quickshell.execDetached(["sh", "-c", cmd]);
        if (friendlyName !== "") {
            ToastService.showInfo("Buds", "Set: " + friendlyName);
        }
    }
    
    function getEqName(preset) {
        if (preset === "dirac") return "Dirac";
        if (preset === "pop") return "PoP";
        if (preset === "rock") return "Rock";
        if (preset === "electronic") return "Electronic";
        if (preset === "enhanced_vocals") return "Enhanced Vocals";
        if (preset === "classical") return "Classical";
        return "Default";
      }
    // ==========================================
    // BACKGROUND PROCESSES & NOTIFICATIONS
    // ==========================================
    Process {
        id: connectionCheckProcess
        onExited: function(code) {
            var connected = (code === 0);
            if (connected !== root.isConnected) {
                root.isConnected = connected;
                if (connected) {
                    // Refresh battery immediately
                    refreshDebounce.restart();
                    // Fetch all toggle/switch states from the device
                    root.startSettingsRefresh();
                    // --- NATIVE NOTIFICATION ---
                    Quickshell.execDetached([
                        "notify-send",
                        "-a", "CMF Audio",
                        "-i", root.rightBudImg,
                        "CMF Buds Pro 2",
                        "Connected and ready"
                    ]);
                } else {
                    root.batteryL = 0;
                    root.batteryR = 0;
                    root.batteryC = 0;
                }
            }
        }
    }

    // Generic process that sequentially fetches each device setting
    Process {
        id: settingsFetchProcess
        property string jsonBuffer: ""
        property string currentSetting: ""

        stdout: SplitParser {
            onRead: function(line) {
                settingsFetchProcess.jsonBuffer += line + "\n";
            }
        }

        onExited: function(code) {
            if (code === 0 && settingsFetchProcess.jsonBuffer.trim().length > 0) {
                root.applySettingResponse(
                    settingsFetchProcess.currentSetting,
                    settingsFetchProcess.jsonBuffer
                );
            }
            settingsFetchProcess.jsonBuffer = "";
            // Chain to the next setting after a short gap
            settingsFetchNextTimer.start();
        }
    }

    // Delay between consecutive setting fetches (gives RFCOMM time to close)
    Timer {
        id: settingsFetchNextTimer
        interval: 400
        repeat: false
        onTriggered: root.fetchNextSetting()
    }

    Timer {
        id: connCheckTimer
        interval: 5000 
        running: root.macAddress !== ""
        repeat: true
        onTriggered: {
            if (!connectionCheckProcess.running) {
                connectionCheckProcess.command = ["sh", "-c", "bluetoothctl info " + root.macAddress + " | grep -q 'Connected: yes'"];
                connectionCheckProcess.running = true;
            }
        }
    }

    Process {
        id: batteryProcess
        property string jsonBuffer: ""

        stdout: SplitParser {
            onRead: function(line) { 
                batteryProcess.jsonBuffer += line + "\n"; 
            }
        }
        
        onExited: function(code) {
            if (code === 0 && batteryProcess.jsonBuffer.trim().length > 0) {
                try {
                    var jsonStart = batteryProcess.jsonBuffer.indexOf("{");
                    var jsonEnd = batteryProcess.jsonBuffer.lastIndexOf("}");
                    if (jsonStart !== -1 && jsonEnd !== -1) {
                        var cleanJson = batteryProcess.jsonBuffer.substring(jsonStart, jsonEnd + 1);
                        var data = JSON.parse(cleanJson);
                        root.batteryL = (data.left && data.left.level !== null) ? data.left.level : 0;
                        root.batteryR = (data.right && data.right.level !== null) ? data.right.level : 0;
                        root.batteryC = (data.case && data.case.level !== null) ? data.case.level : 0;
                    }
                } catch(e) { }
            }
            batteryProcess.jsonBuffer = "";
        }
    }

    Timer {
        id: refreshDebounce
        interval: 500
        repeat: false
        onTriggered:{
            if (root.isConnected && root.macAddress !== "" && !batteryProcess.running) {
                var scriptPath = root.pluginDir + "/cmf_controller.py";
                batteryProcess.command = ["python3", scriptPath, root.macAddress, "battery"];
                batteryProcess.running = true;
            }
        }
    }

    Timer {
        id: mainBatteryTimer
        interval: 60000 
        running: root.isConnected && root.macAddress !== "" 
        repeat: true
        onTriggered: refreshDebounce.restart()
    }

    Component.onCompleted: {
        if (root.macAddress !== "") {
            connectionCheckProcess.command = ["sh", "-c", "bluetoothctl info " + root.macAddress + " | grep -q 'Connected: yes'"];
            connectionCheckProcess.running = true;
        }
    }

    // ==========================================
    // UI LAYOUT
    // ==========================================

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon { name: "headphones"; size: Theme.iconSize; color: Theme.primary; anchors.verticalCenter: parent.verticalCenter }
            StyledText { 
                text: (root.isConnected && (root.batteryL > 0 || root.batteryR > 0)) ? "L " + root.batteryL + "% • R " + root.batteryR + "%" : "Buds"
                font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter 
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon { name: "earbuds"; size: Theme.iconSize; color: Theme.primary; anchors.horizontalCenter: parent.horizontalCenter }
            StyledText { 
                text: (root.isConnected && (root.batteryL > 0 || root.batteryR > 0)) ? Math.max(root.batteryL, root.batteryR) + "%" : "Buds"
                font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText; anchors.horizontalCenter: parent.horizontalCenter 
            }
        }
    }

    popoutWidth: 420
    popoutHeight: 740
    //root.get_headphoneState();
    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn
            headerText: "CMF Buds Pro 2"
            detailsText: root.isConnected ? "Device Controls" : "Disconnected"
            showCloseButton: true

            Timer {
                interval: 5000 
                running: root.isConnected
                repeat: true
                onTriggered: refreshDebounce.restart()
            }

            Item {
                width: parent.width
                height: root.popoutHeight - popoutColumn.headerHeight - popoutColumn.detailsHeight - Theme.spacingXL

                Flickable {
                    anchors.fill: parent
                    contentHeight: mainContent.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: mainContent
                        width: parent.width
                        spacing: Theme.spacingL

                        // 1. HERO BATTERY DISPLAY (With Native Assets)
                        Row {
                            spacing: Theme.spacingXL
                            anchors.horizontalCenter: parent.horizontalCenter

                            // Left Bud Column
                            Column {
                                spacing: Theme.spacingM
                                opacity: (root.isConnected && root.batteryL > 0) ? 1.0 : 0.3
                                
                                Image {
                                    source: "file://" + root.leftBudImg
                                    width: 50
                                    height: 100
                                    fillMode: Image.PreserveAspectFit
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    asynchronous: true
                                }
                                Column {
                                    spacing: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    StyledText { text: "L"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                                    StyledText { text: (root.isConnected && root.batteryL > 0) ? root.batteryL + "%" : "--"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }

                            // Case Column
                            Column {
                                spacing: Theme.spacingM
                                opacity: (root.isConnected && root.batteryC > 0) ? 1.0 : 0.3
                                
                                // Placeholder space or generic icon since we don't have a case PNG
                                Image {
                                    source: "file://" + root.caseImg
                                    width: 70
                                    height: 100
                                    fillMode: Image.PreserveAspectFit
                                    anchors.horizontalCenter:parent.horizontalCenter
                                    asynchronous: true
                                }
                                Column {
                                    spacing: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    StyledText { text: "Case"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                                    StyledText { text: (root.isConnected && root.batteryC > 0) ? root.batteryC + "%" : "--"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }

                            // Right Bud Column
                            Column {
                                spacing: Theme.spacingM
                                opacity: (root.isConnected && root.batteryR > 0) ? 1.0 : 0.3
                                
                                Image {
                                    source: "file://" + root.rightBudImg
                                    width: 50
                                    height: 100
                                    fillMode: Image.PreserveAspectFit
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    asynchronous: true
                                }
                                Column {
                                    spacing: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    StyledText { text: "R"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                                    StyledText { text: (root.isConnected && root.batteryR > 0) ? root.batteryR + "%" : "--"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                            }
                        }

                        // 2. NOISE CANCELLATION CARD
                        StyledRect {
                            width: parent.width
                            height: root.currentMode === "anc" ? 180 : 130
                            radius: Theme.cornerRadius * 2
                            color: Theme.surfaceContainer
                            border.width: 1
                            border.color: Theme.surfaceContainerHighest
                            opacity: root.isConnected ? 1.0 : 0.5 

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingL

                                StyledText {
                                    text: "Noise cancellation"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    // ANC Button
                                    Item {
                                        width: (parent.width - (Theme.spacingS * 2)) / 3
                                        height: 70
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingS
                                            Rectangle {
                                                width: 50; height: 50; radius: 25; anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.currentMode === "anc" ? Theme.primary : Theme.surfaceContainerHighest
                                                DankIcon { name: "noise_control_on"; size: Theme.iconSize; color: root.currentMode === "anc" ? Theme.surfaceContainer : Theme.surfaceText; anchors.centerIn: parent }
                                            }
                                            StyledText { text: "Noise cancellation"; color: Theme.surfaceText; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { if (pluginService) pluginService.savePluginData(pluginId, "currentMode", "anc"); root.sendCommand("anc", root.ancSubMode, "ANC: " + root.ancSubMode); } }
                                    }

                                    // Transparency Button
                                    Item {
                                        width: (parent.width - (Theme.spacingS * 2)) / 3
                                        height: 70
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingS
                                            Rectangle {
                                                width: 50; height: 50; radius: 25; anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.currentMode === "transparency" ? Theme.primary : Theme.surfaceContainerHighest
                                                DankIcon { name: "hearing"; size: Theme.iconSize; color: root.currentMode === "transparency" ? Theme.surfaceContainer : Theme.surfaceText; anchors.centerIn: parent }
                                            }
                                            StyledText { text: "Transparency"; color: Theme.surfaceText; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { if (pluginService) pluginService.savePluginData(pluginId, "currentMode", "transparency"); root.sendCommand("anc", "transparency", "Transparency"); } }
                                    }

                                    // Off Button
                                    Item {
                                        width: (parent.width - (Theme.spacingS * 2)) / 3
                                        height: 70
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingS
                                            Rectangle {
                                                width: 50; height: 50; radius: 25; anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.currentMode === "off" ? Theme.primary : Theme.surfaceContainerHighest
                                                DankIcon { name: "noise_control_off"; size: Theme.iconSize; color: root.currentMode === "off" ? Theme.surfaceContainer : Theme.surfaceText; anchors.centerIn: parent }
                                            }
                                            StyledText { text: "Off"; color: Theme.surfaceText; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { if (pluginService) pluginService.savePluginData(pluginId, "currentMode", "off"); root.sendCommand("anc", "off", "ANC Off"); } }
                                    }
                                }

                                Row {
                                    width: parent.width
                                    visible: root.currentMode === "anc"
                                    spacing: Theme.spacingXS

                                    Repeater {
                                        model: [
                                            { id: "low", name: "Low" },
                                            { id: "mid", name: "Mid" },
                                            { id: "high", name: "High" },
                                            { id: "adaptive", name: "Adaptive" }
                                        ]
                                        delegate: Item {
                                            width: (parent.width - (Theme.spacingXS * 3)) / 4
                                            height: 25
                                            Column {
                                                anchors.fill: parent
                                                spacing: 6
                                                Rectangle { width: parent.width - 4; height: 3; radius: 1.5; color: root.ancSubMode === modelData.id ? Theme.primary : Theme.surfaceContainerHighest; anchors.horizontalCenter: parent.horizontalCenter }
                                                StyledText { text: modelData.name; color: root.ancSubMode === modelData.id ? Theme.primary : Theme.surfaceVariantText; font.pixelSize: 11; font.weight: root.ancSubMode === modelData.id ? Font.Bold : Font.Normal; anchors.horizontalCenter: parent.horizontalCenter }
                                            }
                                            MouseArea { anchors.fill: parent; cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { if (pluginService) pluginService.savePluginData(pluginId, "ancSubMode", modelData.id); root.sendCommand("anc", modelData.id, "ANC: " + modelData.name); } }
                                        }
                                    }
                                }
                            }
                        }

                        // 3. FEATURE GRID (2x2)
                        Grid {
                            width: parent.width
                            columns: 2
                            spacing: Theme.spacingM
                            opacity: root.isConnected ? 1.0 : 0.5 

                            // Spatial Audio Card
                            StyledRect {
                                width: (parent.width - Theme.spacingM) / 2
                                height: 110
                                radius: Theme.cornerRadius * 2
                                color: spatialMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                border.width: 1
                                border.color: Theme.surfaceContainerHighest
                                Column {
                                    anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: 2
                                    StyledText { text: "Spatial audio"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold }
                                    StyledText { text: root.spatialAudio ? "Fixed" : "Off"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                                    Item { width: 1; height: Theme.spacingS }
                                    DankIcon { name: "surround_sound"; size: Theme.iconSize * 1.5; color: root.spatialAudio ? Theme.primary : Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                MouseArea { id: spatialMouse; anchors.fill: parent; hoverEnabled: root.isConnected; cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { var newState = !root.spatialAudio; if (pluginService) pluginService.savePluginData(pluginId, "spatialAudio", newState); root.sendCommand("spatial_toggle", newState ? "on" : "off", "Spatial Audio"); } }
                            }

                            // Ultra Bass Card
                            StyledRect {
                                width: (parent.width - Theme.spacingM) / 2
                                height: 110
                                radius: Theme.cornerRadius * 2
                                color: bassMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                border.width: 1
                                border.color: Theme.surfaceContainerHighest
                                Column {
                                    anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: 2
                                    StyledText { text: "Ultra bass"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold }
                                    StyledText { text: root.ultraBass ? "On" : "Off"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                                    Item { width: 1; height: Theme.spacingS }
                                    DankIcon { name: root.ultraBass ? "toggle_on" : "toggle_off"; size: Theme.iconSize * 1.5; color: root.ultraBass ? Theme.primary : Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                MouseArea { id: bassMouse; anchors.fill: parent; hoverEnabled: root.isConnected; cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { var newState = !root.ultraBass; if (pluginService) pluginService.savePluginData(pluginId, "ultraBass", newState); root.sendCommand("ultra_bass_toggle", newState ? "3" : "off", "Ultra Bass"); } }
                            }

                            // Equaliser Card
                            StyledRect {
                                width: (parent.width - Theme.spacingM) / 2
                                height: 110
                                radius: Theme.cornerRadius * 2
                                color: eqMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                border.width: 1
                                border.color: Theme.surfaceContainerHighest
                                Column {
                                    anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: 2
                                    StyledText { text: "Equaliser"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold }
                                    StyledText { text: root.getEqName(root.eqPreset); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                                    Item { width: 1; height: Theme.spacingS }
                                    DankIcon { name: "graphic_eq"; size: Theme.iconSize * 1.5; color: Theme.primary; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                MouseArea { id: eqMouse; anchors.fill: parent; hoverEnabled: root.isConnected; cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { var presets = ["dirac", "pop", "rock", "electronic", "enhanced_vocals", "classical", "costom"]; var nextIdx = (presets.indexOf(root.eqPreset) + 1) % presets.length; var newEq = presets[nextIdx]; if (pluginService) pluginService.savePluginData(pluginId, "eqPreset", newEq); root.sendCommand("eq_set", newEq, "EQ: " + root.getEqName(newEq)); } }
                            }

                            // Low Lag Mode Card
                            StyledRect {
                                width: (parent.width - Theme.spacingM) / 2
                                height: 110
                                radius: Theme.cornerRadius * 2
                                color: gamingMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                                border.width: 1
                                border.color: Theme.surfaceContainerHighest
                                Column {
                                    anchors.fill: parent; anchors.margins: Theme.spacingM; spacing: 2
                                    StyledText { text: "Low lag mode"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold }
                                    StyledText { text: root.gamingMode ? "On" : "Off"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                                    Item { width: 1; height: Theme.spacingS }
                                    DankIcon { name: root.gamingMode ? "toggle_on" : "toggle_off"; size: Theme.iconSize * 1.5; color: root.gamingMode ? Theme.primary : Theme.surfaceVariantText; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                MouseArea { id: gamingMouse; anchors.fill: parent; hoverEnabled: root.isConnected; cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: { var newState = !root.gamingMode; if (pluginService) pluginService.savePluginData(pluginId, "gamingMode", newState); root.sendCommand("gaming_toggle", newState ? "on" : "off", "Gaming Mode"); } }
                            }
                        }

                        // 4. IN-EAR DETECTION
                        StyledRect {
                            width: parent.width
                            height: 65
                            radius: Theme.cornerRadius * 2
                            color: inEarMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
                            border.width: 1
                            border.color: Theme.surfaceContainerHighest
                            opacity: root.isConnected ? 1.0 : 0.5 

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM
                                
                                DankIcon { name: "sensors"; color: Theme.surfaceText; size: Theme.iconSize; anchors.verticalCenter: parent.verticalCenter }
                                StyledText {
                                    text: "In-ear detection"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    width: parent.width - (Theme.spacingM * 3) - Theme.iconSize - (Theme.iconSize * 1.5)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                DankIcon {
                                    name: root.inEarDetection ? "toggle_on" : "toggle_off"
                                    size: Theme.iconSize * 1.5
                                    color: root.inEarDetection ? Theme.primary : Theme.surfaceVariantText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            
                            MouseArea {
                                id: inEarMouse
                                anchors.fill: parent
                                hoverEnabled: root.isConnected
                                cursorShape: root.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    var newState = !root.inEarDetection;
                                    if (pluginService) pluginService.savePluginData(pluginId, "inEarDetection", newState);
                                    root.sendCommand("in_ear_toggle", newState ? "on" : "off", "In-ear detection");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
