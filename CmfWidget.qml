import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "qml/components"
import "qml/core"

PluginComponent {
    id: root
    layerNamespacePlugin: "cmf-controller"

    // --- PERSISTENT STATE ---
    property string macAddress: pluginData.macAddress ?? ""
    property string deviceName: pluginData.deviceName ?? "CMF_Buds_Pro_2"
    property string deviceColor: pluginData.deviceColor ?? "orange"
    property string currentMode: pluginData.currentMode ?? "off"
    property string ancSubMode: pluginData.ancSubMode ?? "adaptive"
    property string eqPreset: pluginData.eqPreset ?? "balanced"
    property bool spatialAudio: pluginData.spatialAudio ?? false
    property bool gamingMode: pluginData.gamingMode ?? false
    property bool inEarDetection: pluginData.inEarDetection ?? true
    property bool ultraBass: pluginData.ultraBass ?? false
    property int ultraBassLevel: pluginData.ultraBassLevel ?? 3
    property bool dualConnectionEnabled: pluginData.dualConnectionEnabled ?? false
    property bool ldacEnabled: pluginData.ldacEnabled ?? false

    readonly property string displayDeviceName: deviceName.replace(/_/g, " ")
    readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace("file://", "")

    // --- CORE LOGIC CONTROLLER ---
    DeviceController {
        id: controller
        pluginDir: root.pluginDir
        macAddress: root.macAddress
        pluginService: root.pluginService
        pluginId: root.pluginId
        deviceName: root.deviceName
        deviceColor: root.deviceColor
        // Forward states to controller for easy access in pages
        property bool spatialAudio: root.spatialAudio
        property bool ultraBass: root.ultraBass
        property int ultraBassLevel: root.ultraBassLevel
        property string eqPreset: root.eqPreset
        property string currentMode: root.currentMode
        property string ancSubMode: root.ancSubMode
        property bool inEarDetection: root.inEarDetection
        property bool gamingMode: root.gamingMode
        property bool dualConnectionEnabled: root.dualConnectionEnabled
        property bool ldacEnabled: root.ldacEnabled

        onStateUpdated: function (key, value) {
            if (typeof root[key] !== "undefined") {
                root[key] = value;
            }
        }
    }

    // Asset paths for UI
    property string leftBudImg: pluginDir + "/assets/" + deviceName + "_" + deviceColor + "/left_bud.png"
    property string rightBudImg: pluginDir + "/assets/" + deviceName + "_" + deviceColor + "/right_bud.png"
    property string caseImg: pluginDir + "/assets/" + deviceName + "_" + deviceColor + "/case.png"

    property var advancedWindow: null

    function openAdvancedSettings() {
        if (advancedWindow !== null) {
            advancedWindow.requestActivate();
            return;
        }
        var component = Qt.createComponent(Qt.resolvedUrl("CmfAppWindow.qml"));
        if (component.status === Component.Ready) {
            advancedWindow = component.createObject(root, {
                "pluginDir": root.pluginDir,
                "controller": controller
            });
            advancedWindow.show();
            advancedWindow.onClosing.connect(function () {
                advancedWindow.destroy();
                advancedWindow = null;
            });
        } else {
            console.error("Error loading window: " + component.errorString());
            ToastService.showError("Error", "Could not load Advanced Settings");
        }
    }

    function getEqName(preset) {
        if (preset === "dirac")
            return "Dirac";
        if (preset === "pop")
            return "PoP";
        if (preset === "rock")
            return "Rock";
        if (preset === "electronic")
            return "Electronic";
        if (preset === "enhanced_vocals")
            return "Enhanced Vocals";
        if (preset === "classical")
            return "Classical";
        if (preset === "custom")
            return "Custom";
        return "Default";
    }

    // ==========================================
    // UI LAYOUT
    // ==========================================

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "earbuds_2"
                size: Theme.iconSize - 5
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: {
                    if (!controller.isConnected || (controller.batteryL === 0 && controller.batteryR === 0))
                        return "Buds";
                    if (controller.batteryL > 0 && controller.batteryR > 0)
                        return "L " + controller.batteryL + "% • R " + controller.batteryR + "%";
                    if (controller.batteryL > 0)
                        return "L " + controller.batteryL + "%";
                    return "R " + controller.batteryR + "%";
                }
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon {
                name: "earbuds_2"
                size: Theme.iconSize
                color: Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: (controller.isConnected && (controller.batteryL > 0 || controller.batteryR > 0)) ? Math.max(controller.batteryL, controller.batteryR) + "%" : "Buds"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 420
    popoutHeight: 700
    popoutContent: Component {
        PopoutComponent {
            id: popoutColumn
            headerText: root.displayDeviceName
            detailsText: controller.isConnected ? "Device Controls" : "Disconnected"
            showCloseButton: true

            onVisibleChanged: {
                if (visible && controller.isConnected) {
                    controller.fetchBattery();
                    controller.startSettingsRefresh();
                }
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

                        // 1. HERO BATTERY DISPLAY
                        Row {
                            spacing: Theme.spacingXL
                            anchors.horizontalCenter: parent.horizontalCenter

                            // Left Bud Column
                            Column {
                                spacing: Theme.spacingM
                                opacity: (controller.isConnected && controller.batteryL > 0) ? 1.0 : 0.3
                                Image {
                                    source: "file://" + root.leftBudImg
                                    width: 70
                                    height: 140
                                    fillMode: Image.PreserveAspectFit
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    asynchronous: true
                                }
                                Column {
                                    spacing: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    StyledText {
                                        text: "L"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    StyledText {
                                        text: (controller.isConnected && controller.batteryL > 0) ? controller.batteryL + "%" : "--"
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Bold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            // Case Column
                            Column {
                                spacing: Theme.spacingM
                                opacity: (controller.isConnected && controller.batteryC > 0) ? 1.0 : 0.3
                                Item {
                                    width: 30
                                    height: 140
                                }
                                Column {
                                    spacing: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    StyledText {
                                        text: "Case"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    StyledText {
                                        text: (controller.isConnected && controller.batteryC > 0) ? controller.batteryC + "%" : "--"
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Bold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }

                            // Right Bud Column
                            Column {
                                spacing: Theme.spacingM
                                opacity: (controller.isConnected && controller.batteryR > 0) ? 1.0 : 0.3
                                Image {
                                    source: "file://" + root.rightBudImg
                                    width: 70
                                    height: 140
                                    fillMode: Image.PreserveAspectFit
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    asynchronous: true
                                }
                                Column {
                                    spacing: 2
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    StyledText {
                                        text: "R"
                                        color: Theme.surfaceVariantText
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.Bold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    StyledText {
                                        text: (controller.isConnected && controller.batteryR > 0) ? controller.batteryR + "%" : "--"
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Bold
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }
                            }
                        }

                        // 2. NOISE CANCELLATION CARD
                        StyledRect {
                            width: parent.width
                            height: root.currentMode === "anc" ? 180 : 130
                            radius: Theme.cornerRadius * 2
                            color: Theme.surfaceContainerHigh
                            border.width: 1
                            border.color: Theme.surfaceContainerHighest
                            opacity: controller.isConnected ? 1.0 : 0.5

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
                                                width: 50
                                                height: 50
                                                radius: 25
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.currentMode === "anc" ? Theme.primary : Theme.surfaceContainerHighest
                                                DankIcon {
                                                    name: "noise_control_on"
                                                    size: Theme.iconSize
                                                    color: root.currentMode === "anc" ? Theme.surfaceContainer : Theme.surfaceText
                                                    anchors.centerIn: parent
                                                }
                                            }
                                            StyledText {
                                                text: "Noise cancellation"
                                                color: Theme.surfaceText
                                                font.pixelSize: 10
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: controller.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                controller.updateState("currentMode", "anc");
                                                controller.sendCommand("anc", "set", root.ancSubMode, "", "ANC: " + root.ancSubMode);
                                            }
                                        }
                                    }
                                    // Transparency Button
                                    Item {
                                        width: (parent.width - (Theme.spacingS * 2)) / 3
                                        height: 70
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingS
                                            Rectangle {
                                                width: 50
                                                height: 50
                                                radius: 25
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.currentMode === "transparency" ? Theme.primary : Theme.surfaceContainerHighest
                                                DankIcon {
                                                    name: "hearing"
                                                    size: Theme.iconSize
                                                    color: root.currentMode === "transparency" ? Theme.surfaceContainer : Theme.surfaceText
                                                    anchors.centerIn: parent
                                                }
                                            }
                                            StyledText {
                                                text: "Transparency"
                                                color: Theme.surfaceText
                                                font.pixelSize: 10
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: controller.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                controller.updateState("currentMode", "transparency");
                                                controller.sendCommand("anc", "set", "transparency", "", "Transparency");
                                            }
                                        }
                                    }
                                    // Off Button
                                    Item {
                                        width: (parent.width - (Theme.spacingS * 2)) / 3
                                        height: 70
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: Theme.spacingS
                                            Rectangle {
                                                width: 50
                                                height: 50
                                                radius: 25
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                color: root.currentMode === "off" ? Theme.primary : Theme.surfaceContainerHighest
                                                DankIcon {
                                                    name: "noise_control_off"
                                                    size: Theme.iconSize
                                                    color: root.currentMode === "off" ? Theme.surfaceContainer : Theme.surfaceText
                                                    anchors.centerIn: parent
                                                }
                                            }
                                            StyledText {
                                                text: "Off"
                                                color: Theme.surfaceText
                                                font.pixelSize: 10
                                                anchors.horizontalCenter: parent.horizontalCenter
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: controller.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor
                                            onClicked: {
                                                controller.updateState("currentMode", "off");
                                                controller.sendCommand("anc", "set", "off", "", "ANC Off");
                                            }
                                        }
                                    }
                                }
                                Row {
                                    width: parent.width
                                    visible: root.currentMode === "anc"
                                    spacing: Theme.spacingXS
                                    Repeater {
                                        model: [
                                            {
                                                id: "low",
                                                name: "Low"
                                            },
                                            {
                                                id: "mid",
                                                name: "Mid"
                                            },
                                            {
                                                id: "high",
                                                name: "High"
                                            },
                                            {
                                                id: "adaptive",
                                                name: "Adaptive"
                                            }
                                        ]
                                        delegate: Item {
                                            width: (parent.width - (Theme.spacingXS * 3)) / 4
                                            height: 25
                                            Column {
                                                anchors.fill: parent
                                                spacing: 6
                                                Rectangle {
                                                    width: parent.width - 4
                                                    height: 3
                                                    radius: 1.5
                                                    color: root.ancSubMode === modelData.id ? Theme.primary : Theme.surfaceContainerHighest
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                                StyledText {
                                                    text: modelData.name
                                                    color: root.ancSubMode === modelData.id ? Theme.primary : Theme.surfaceVariantText
                                                    font.pixelSize: 11
                                                    font.weight: root.ancSubMode === modelData.id ? Font.Bold : Font.Normal
                                                    anchors.horizontalCenter: parent.horizontalCenter
                                                }
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: controller.isConnected ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: {
                                                    controller.updateState("ancSubMode", modelData.id);
                                                    controller.sendCommand("anc", "set", modelData.id, "", "ANC: " + modelData.name);
                                                }
                                            }
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
                            opacity: controller.isConnected ? 1.0 : 0.5

                            FeatureCard {
                                width: (parent.width - Theme.spacingM) / 2
                                title: "Spatial audio"
                                subtitle: root.spatialAudio ? "On" : "Off"
                                iconName: root.spatialAudio ? "spatial_audio" : "spatial_audio_off"
                                iconColor: root.spatialAudio ? Theme.primary : Theme.surfaceVariantText
                                isActive: controller.isConnected
                                onClicked: {
                                    var newState = !root.spatialAudio;
                                    controller.updateState("spatialAudio", newState);
                                    controller.sendCommand("spatial_audio", "set", newState ? "on" : "off", "", "Spatial Audio");
                                }
                            }

                            FeatureCard {
                                width: (parent.width - Theme.spacingM) / 2
                                title: "Ultra bass"
                                subtitle: root.ultraBass ? "On" : "Off"
                                iconName: root.ultraBass ? "toggle_on" : "toggle_off"
                                iconColor: root.ultraBass ? Theme.primary : Theme.surfaceVariantText
                                isActive: controller.isConnected
                                onClicked: {
                                    var newState = !root.ultraBass;
                                    controller.updateState("ultraBass", newState);
                                    controller.sendCommand("ultra_bass", "set", newState ? "3" : "off", "", "Ultra Bass");
                                }
                            }

                            FeatureCard {
                                width: (parent.width - Theme.spacingM) / 2
                                title: "Equaliser"
                                subtitle: root.getEqName(root.eqPreset)
                                iconName: "graphic_eq"
                                iconColor: Theme.primary
                                isActive: controller.isConnected
                                onClicked: {
                                    var presets = ["dirac", "pop", "rock", "electronic", "enhanced_vocals", "classical", "custom"];
                                    var nextIdx = (presets.indexOf(root.eqPreset) + 1) % presets.length;
                                    var newEq = presets[nextIdx];
                                    controller.updateState("eqPreset", newEq);
                                    controller.sendCommand("eq", "set", newEq, "", "EQ: " + root.getEqName(newEq));
                                }
                            }

                            FeatureCard {
                                width: (parent.width - Theme.spacingM) / 2
                                title: "More settings"
                                subtitle: "Advanced"
                                iconName: "settings"
                                iconColor: Theme.primary
                                isActive: true
                                onClicked: {
                                    root.openAdvancedSettings();
                                    popoutColumn.closePopout();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
