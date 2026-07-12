import QtQuick
import qs.Common
import qs.Widgets
import "../components"

/*
 * DeviceSettingsPage.qml
 *
 * Page for toggling LDAC, In-Ear Detection, and navigating to Find My Earbuds.
 */
Item {
    id: root

    property var controller: null
    property var window: null

    width: parent ? parent.width : 440
    height: parent ? parent.height : 850

    Item {
        id: dsHeader
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
            id: backIconDs
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
            text: "Device settings"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: backIconDs.right
            anchors.leftMargin: Theme.spacingM
        }
    }

    Column {
        anchors.top: dsHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        // Notice we didn't extract ActionToggle yet because 
        // the original has an extra icon on the left.
        // We will adapt ActionToggle or keep it custom for now.
        // For simplicity and reusing ActionToggle, let's use it and optionally add an icon later, 
        // but here we keep the original layout slightly cleaned up.
        
        StyledRect {
            visible: controller ? (controller.capabilities["ldac"] === true) : false
            width: parent.width
            height: 60
            radius: Theme.cornerRadius * 2
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outlineVariant
            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                DankIcon { name: "high_quality"; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter; size: 24 }
                StyledText {
                    text: "Lossless codec (LDAC)"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                }
                DankIcon {
                    name: (window.ldacEnabled || (controller && controller.ldacEnabled)) ? "toggle_on" : "toggle_off"
                    color: (window.ldacEnabled || (controller && controller.ldacEnabled)) ? Theme.primary : Theme.surfaceVariantText
                    size: 28
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    // Update state properly
                    // We assume ldacEnabled is in controller for now, if not we keep window proxy
                    var newState = !window.ldacEnabled;
                    if (controller) {
                        controller.updateState("ldacEnabled", newState);
                        controller.sendCommand("ldac", "set", newState ? "on" : "off", "", "LDAC Codec");
                        window.ldacEnabled = newState; // Temporary fallback sync
                    }
                }
            }
        }

        StyledRect {
            visible: controller ? (controller.capabilities["in_ear_detection"] === true) : false
            width: parent.width
            height: 60
            radius: Theme.cornerRadius * 2
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outlineVariant
            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                DankIcon { name: "sensors"; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter; size: 24 }
                StyledText {
                    text: "In-ear detection"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                }
                DankIcon {
                    name: (controller && controller.inEarDetection) ? "toggle_on" : "toggle_off"
                    color: (controller && controller.inEarDetection) ? Theme.primary : Theme.surfaceVariantText
                    size: 28
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var newState = !controller.inEarDetection;
                    controller.updateState("inEarDetection", newState);
                    controller.sendCommand("in_ear", "set", newState ? "on" : "off", "", "In-ear detection");
                }
            }
        }

        StyledRect {
            visible: controller ? (controller.capabilities["find_my"] === true) : false
            width: parent.width
            height: 60
            radius: Theme.cornerRadius * 2
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outlineVariant
            Row {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM
                DankIcon { name: "location_on"; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter; size: 24 }
                StyledText {
                    text: "Find my earbuds"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 90
                }
                DankIcon {
                    name: "chevron_right"
                    color: Theme.surfaceVariantText
                    size: 28
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: window.pushPage(window.findMyPageComp)
            }
        }
    }
}
