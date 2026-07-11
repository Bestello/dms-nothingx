import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

/*
 * EqualizerPage.qml
 *
 * Page for setting EQ presets and custom EQ sliders.
 */
Item {
    id: root

    property var controller: null
    property var window: null

    width: parent ? parent.width : 440
    height: parent ? parent.height : 850

    property bool showCustomSliders: false

    Item {
        id: eqHeader
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

        DankIcon {
            id: backIconEq
            name: "arrow_back"
            color: Theme.surfaceText
            size: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            MouseArea {
                anchors.fill: parent
                anchors.margins: -10
                cursorShape: Qt.PointingHandCursor
                onClicked: window.popPage()
            }
        }

        StyledText {
            text: "Equaliser"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: backIconEq.right
            anchors.leftMargin: Theme.spacingM
        }
    }

    Column {
        anchors.top: eqHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingXL

        // Presets Grid
        Grid {
            width: parent.width
            columns: 2
            spacing: Theme.spacingM

            Repeater {
                model: [
                    { id: "dirac", name: "Dirac" },
                    { id: "pop", name: "PoP" },
                    { id: "rock", name: "Rock" },
                    { id: "classical", name: "Classical" },
                    { id: "electronic", name: "Electronic" },
                    { id: "enhanced_vocals", name: "Enhanced Vocals" }
                ]
                delegate: StyledRect {
                    width: (parent.width - Theme.spacingM) / 2
                    height: 60
                    radius: 30
                    color: (controller && controller.eqPreset === modelData.id) ? Theme.primary : Theme.surfaceContainer
                    border.width: (controller && controller.eqPreset === modelData.id) ? 0 : 1
                    border.color: Theme.outlineVariant

                    StyledText {
                        text: modelData.name
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: (controller && controller.eqPreset === modelData.id) ? Theme.surface : Theme.surfaceVariantText
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            controller.updateState("eqPreset", modelData.id);
                            controller.sendCommand("eq", "set", modelData.id, "", "EQ: " + modelData.name);
                            if (window) window.eqPreset = modelData.id;
                        }
                    }
                }
            }
        }

        // Custom Button
        StyledRect {
            width: parent.width
            height: 60
            radius: 30
            color: (controller && controller.eqPreset === "custom") ? Theme.primary : Theme.surfaceContainer
            border.width: (controller && controller.eqPreset === "custom") ? 0 : 1
            border.color: Theme.outlineVariant

            StyledText {
                text: "CUSTOM"
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                color: (controller && controller.eqPreset === "custom") ? Theme.surface : Theme.surfaceVariantText
                anchors.centerIn: parent
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    controller.updateState("eqPreset", "custom");
                    controller.sendCommand("eq", "set", "custom", "", "EQ: Custom");
                    if (window) window.eqPreset = "custom";
                }
            }
        }

        // Custom Sliders Inline
        Column {
            width: parent.width
            spacing: Theme.spacingL
            visible: controller && controller.eqPreset === "custom"

            StyledText {
                text: "Custom EQ Settings"
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.surfaceText
            }

            Row {
                width: parent.width
                spacing: (parent.width - (40 * 3)) / 2

                Repeater {
                    model: ["Bass", "Mid", "Treble"]
                    delegate: Column {
                        width: 40
                        spacing: Theme.spacingM
                        Slider {
                            id: eqSlider
                            orientation: Qt.Vertical
                            width: 40
                            height: 180
                            from: -6
                            to: 6
                            stepSize: 1
                            snapMode: Slider.SnapAlways
                            value: {
                                if (!window) return 0;
                                if (index === 0) return window.customEqBass;
                                if (index === 1) return window.customEqMid;
                                if (index === 2) return window.customEqTreble;
                                return 0;
                            }

                            background: Rectangle {
                                x: (parent.width - width) / 2
                                y: 0
                                width: 24
                                height: parent.height
                                radius: 12
                                color: Theme.surfaceContainerHighest

                                Repeater {
                                    model: 13 // -6 to 6
                                    Rectangle {
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: Theme.surfaceText
                                        opacity: 0.3
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: (index / 12.0) * (parent.height - 6) + 1
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: parent.height * (1.0 - eqSlider.visualPosition)
                                    y: parent.height * eqSlider.visualPosition
                                    radius: 12
                                    color: Theme.primary
                                }
                            }

                            handle: Rectangle {
                                x: eqSlider.leftPadding + eqSlider.availableWidth / 2 - width / 2
                                y: eqSlider.topPadding + eqSlider.visualPosition * (eqSlider.availableHeight - height)
                                width: 32
                                height: 6
                                radius: 3
                                color: Theme.primary
                            }

                            onValueChanged: {
                                if (!window || !controller) return;
                                if (index === 0) window.customEqBass = value;
                                else if (index === 1) window.customEqMid = value;
                                else if (index === 2) window.customEqTreble = value;

                                controller.sendCommand("custom_eq", "set", window.customEqBass + "," + window.customEqMid + "," + window.customEqTreble, "", "Custom EQ");
                            }
                        }
                        StyledText {
                            text: modelData
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }
}
