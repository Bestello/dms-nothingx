import QtQuick
import qs.Common
import qs.Widgets
import "../components"

/*
 * DashboardPage.qml
 *
 * The main dashboard page displaying earbuds battery, ANC controls,
 * and quick feature toggles in a grid.
 */
Item {
    id: root

    // Reference to the main window/controller for state access
    property var controller: null
    property var window: null

    width: parent ? parent.width : 440
    height: parent ? parent.height : 850

    // Header
    Item {
        id: headerRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingL
        height: 40

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.spacingL
            onPressed: window.startSystemMove()
        }

        StyledText {
            text: "Device Controls"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
        }

        DankIcon {
            name: "close"
            size: 24
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: window.close()
            }
        }
    }

    Flickable {
        anchors.top: headerRow.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        contentHeight: mainCol.height + Theme.spacingXL
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: mainCol
            width: parent.width
            spacing: Theme.spacingL
            opacity: controller.isConnected ? 1.0 : 0.4
            enabled: controller.isConnected

            // 1. HERO IMAGE & BATTERY
            Column {
                width: parent.width
                spacing: Theme.spacingM

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    // L Image
                    Item {
                        width: 70; height: 130
                        opacity: (controller.isConnected && controller.batteryL > 0) ? 1.0 : 0.3
                        Image {
                            anchors.fill: parent
                            source: "file://" + controller.leftBudImg
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                    // Case Placeholder
                    Item {
                        width: 40; height: 130
                    }
                    // R Image
                    Item {
                        width: 70; height: 130
                        opacity: (controller.isConnected && controller.batteryR > 0) ? 1.0 : 0.3
                        Image {
                            anchors.fill: parent
                            source: "file://" + controller.rightBudImg
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                    }
                }

                StyledText {
                    text: controller.deviceName.replace(/_/g, " ")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    // L Text
                    Column {
                        width: 70
                        spacing: Theme.spacingXS
                        StyledText { text: "L"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                        StyledText { text: (controller.isConnected && controller.batteryL > 0) ? controller.batteryL + "%" : "--"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                    // Case Text
                    Column {
                        width: 40
                        spacing: Theme.spacingXS
                        StyledText { text: "Case"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                        StyledText { text: (controller.isConnected && controller.batteryC > 0) ? controller.batteryC + "%" : "--"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                    // R Text
                    Column {
                        width: 70
                        spacing: Theme.spacingXS
                        StyledText { text: "R"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                        StyledText { text: (controller.isConnected && controller.batteryR > 0) ? controller.batteryR + "%" : "--"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            // 2. ANC CARD
            StyledRect {
                width: parent.width - (Theme.spacingL * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                height: controller.currentMode === "anc" ? 190 : 140
                radius: Theme.cornerRadius * 2
                color: Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.outlineVariant

                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    StyledText {
                        text: "Noise cancellation"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 40

                        // ANC
                        Column {
                            spacing: Theme.spacingS
                            Rectangle {
                                width: 60; height: 60; radius: 30
                                color: controller.currentMode === "anc" ? Theme.primary : Theme.surfaceContainerHigh
                                DankIcon { name: "noise_control_on"; size: Theme.iconSizeLarge; color: controller.currentMode === "anc" ? Theme.surface : Theme.surfaceText; anchors.centerIn: parent }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        controller.updateState("currentMode", "anc");
                                        controller.sendCommand("anc", "set", controller.ancSubMode, "", "ANC: On");
                                    }
                                }
                            }
                            StyledText { text: "Noise cancel"; color: Theme.surfaceVariantText; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                        }

                        // Transparency
                        Column {
                            spacing: Theme.spacingS
                            Rectangle {
                                width: 60; height: 60; radius: 30
                                color: controller.currentMode === "transparency" ? Theme.primary : Theme.surfaceContainerHigh
                                DankIcon { name: "hearing"; size: Theme.iconSizeLarge; color: controller.currentMode === "transparency" ? Theme.surface : Theme.surfaceText; anchors.centerIn: parent }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        controller.updateState("currentMode", "transparency");
                                        controller.sendCommand("anc", "set", "transparency", "", "Transparency");
                                    }
                                }
                            }
                            StyledText { text: "Transparency"; color: Theme.surfaceVariantText; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                        }

                        // Off
                        Column {
                            spacing: Theme.spacingS
                            Rectangle {
                                width: 60; height: 60; radius: 30
                                color: controller.currentMode === "off" ? Theme.primary : Theme.surfaceContainerHigh
                                DankIcon { name: "noise_control_off"; size: Theme.iconSizeLarge; color: controller.currentMode === "off" ? Theme.surface : Theme.surfaceText; anchors.centerIn: parent }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        controller.updateState("currentMode", "off");
                                        controller.sendCommand("anc", "set", "off", "", "ANC Off");
                                    }
                                }
                            }
                            StyledText { text: "Off"; color: Theme.surfaceVariantText; font.pixelSize: 11; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }

                    // ANC SUBMODES
                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS
                        visible: controller.currentMode === "anc"
                        opacity: controller.currentMode === "anc" ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }

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
                                    anchors.fill: parent; spacing: 6
                                    Rectangle { width: parent.width - 4; height: 3; radius: 1.5; color: controller.ancSubMode === modelData.id ? Theme.primary : Theme.surfaceContainerHighest; anchors.horizontalCenter: parent.horizontalCenter }
                                    StyledText { text: modelData.name; color: controller.ancSubMode === modelData.id ? Theme.primary : Theme.surfaceVariantText; font.pixelSize: 11; font.weight: controller.ancSubMode === modelData.id ? Font.Bold : Font.Normal; anchors.horizontalCenter: parent.horizontalCenter }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
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

            // 3. FEATURES GRID
            Grid {
                width: parent.width - (Theme.spacingL * 2)
                anchors.horizontalCenter: parent.horizontalCenter
                columns: 2
                spacing: Theme.spacingM

                FeatureCard {
                    width: (parent.width - Theme.spacingM) / 2
                    title: "Spatial audio"
                    subtitle: controller.spatialAudio ? "On" : "Off"
                    iconName: controller.spatialAudio ? "spatial_audio" : "spatial_audio_off"
                    iconColor: controller.spatialAudio ? Theme.primary : Theme.surfaceVariantText
                    onClicked: {
                        controller.updateState("spatialAudio", !controller.spatialAudio);
                        controller.sendCommand("spatial_audio", "set", controller.spatialAudio ? "on" : "off", "", "Spatial Audio");
                    }
                }

                // Custom Ultra Bass Card
                StyledRect {
                    id: ubCard
                    width: (parent.width - Theme.spacingM) / 2
                    height: 110
                    radius: Theme.cornerRadius * 2
                    color: ubMouseArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                    border.width: 1
                    border.color: Theme.surfaceContainerHighest

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: 2
                        
                        StyledText { text: "Ultra bass"; color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall; font.weight: Font.Bold }
                        StyledText { text: controller.ultraBass ? "On" : "Off"; color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        
                        Item { width: 1; height: 8 }
                        
                        // Level Indicator (5 dots)
                        Row {
                            spacing: 4
                            visible: controller.ultraBass
                            Repeater {
                                model: 5
                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: index < controller.ultraBassLevel ? Theme.primary : Theme.surfaceContainerHighest
                                }
                            }
                        }
                    }

                    // Toggle Button
                    DankIcon {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.spacingS
                        name: controller.ultraBass ? "toggle_on" : "toggle_off"
                        size: 32
                        color: controller.ultraBass ? Theme.primary : Theme.surfaceVariantText
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -10
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                controller.updateState("ultraBass", !controller.ultraBass);
                                controller.sendCommand("ultra_bass", "set", controller.ultraBass ? controller.ultraBassLevel : "off", "", "Ultra Bass");
                            }
                        }
                    }

                    MouseArea {
                        id: ubMouseArea
                        anchors.fill: parent
                        anchors.rightMargin: 40 // keep right side for toggle
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.showUltraBassSlider = true
                    }
                }

                FeatureCard {
                    width: (parent.width - Theme.spacingM) / 2
                    title: "Equaliser"
                    subtitle: {
                        var n = controller.eqPreset;
                        if (n === "dirac") return "Dirac";
                        if (n === "pop") return "PoP";
                        if (n === "rock") return "Rock";
                        if (n === "electronic") return "Electronic";
                        if (n === "enhanced_vocals") return "Enhanced Vocals";
                        if (n === "classical") return "Classical";
                        if (n === "custom") return "Custom";
                        return "Default";
                    }
                    iconName: "graphic_eq"
                    onClicked: window.pushPage(window.eqPageComp)
                }

                /* FeatureCard {
                    width: (parent.width - Theme.spacingM) / 2
                    title: "Controls"
                    subtitle: "Customised"
                    iconName: "settings"
                    onClicked: window.pushPage(window.controlsPageComp)
                } */

                FeatureCard {
                    width: (parent.width - Theme.spacingM) / 2
                    title: "Low lag mode"
                    subtitle: controller.gamingMode ? "On" : "Off"
                    iconName: controller.gamingMode ? "toggle_on" : "toggle_off"
                    iconColor: controller.gamingMode ? Theme.primary : Theme.surfaceVariantText
                    onClicked: {
                        controller.updateState("gamingMode", !controller.gamingMode);
                        controller.sendCommand("low_latency", "set", controller.gamingMode ? "on" : "off", "", "Low lag mode");
                    }
                }

                /* FeatureCard {
                    width: (parent.width - Theme.spacingM) / 2
                    title: "Dual connection"
                    subtitle: controller.dualConnectionEnabled ? "On" : "Off"
                    iconName: "devices"
                    onClicked: window.pushPage(window.dualConnectionPageComp)
                } */

                FeatureCard {
                    width: (parent.width - Theme.spacingM) / 2
                    title: "Device settings"
                    subtitle: ""
                    iconName: "settings"
                    onClicked: window.pushPage(window.deviceSettingsPageComp)
                }
            }
        }
    }
}
