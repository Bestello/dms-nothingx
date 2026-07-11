import QtQuick
import qs.Common
import qs.Widgets
import "../components"

/*
 * DualConnectionPage.qml
 *
 * Page for toggling dual connection and managing connected devices.
 */
Item {
    id: root

    property var controller: null
    property var window: null

    width: parent ? parent.width : 440
    height: parent ? parent.height : 850

    Component.onCompleted: {
        if (controller) controller.fetchDevices();
    }

    Item {
        id: dcHeader
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
            id: backIconDc
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
            text: "Dual connection"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: backIconDc.right
            anchors.leftMargin: Theme.spacingM
        }
    }

    Flickable {
        anchors.top: dcHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingL
        contentHeight: dcCol.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: dcCol
            width: parent.width
            spacing: Theme.spacingL

            StyledRect {
                width: parent.width
                height: 60
                radius: Theme.cornerRadius * 2
                color: Theme.surfaceContainerHighest
                border.width: 1
                border.color: Theme.outlineVariant
                Row {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    StyledText {
                        text: "Dual connection"
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 40
                    }
                    DankIcon {
                        name: (controller && controller.dualConnectionEnabled) ? "toggle_on" : "toggle_off"
                        color: (controller && controller.dualConnectionEnabled) ? Theme.primary : Theme.surfaceVariantText
                        size: 28
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!controller) return;
                        var newState = !controller.dualConnectionEnabled;
                        controller.updateState("dualConnectionEnabled", newState);
                        if (window) window.dualConnectionEnabled = newState;
                        
                        if (window && typeof window.startFakeLoading === 'function') {
                            window.startFakeLoading("Rebooting headset...", 15000);
                        }
                        controller.sendCommand("dual_connect", "set", newState ? "on" : "off", "", "Dual Connection");
                        
                        // Wait for reboot then fetch devices
                        var timer = Qt.createQmlObject('import QtQuick; Timer { interval: 15000; repeat: false; onTriggered: { controller.fetchDevices(); this.destroy(); } }', root, "dcTimer");
                        timer.start();
                    }
                }
            }

            StyledText {
                text: {
                    var activeCount = 0;
                    if (controller && controller.connectedDevices) {
                        activeCount = controller.connectedDevices.filter(function(d) { return d.status === 'Active'; }).length;
                    }
                    return "My devices (" + activeCount + "/2)";
                }
                font.weight: Font.Bold
                color: Theme.surfaceText
                visible: controller && controller.dualConnectionEnabled
            }

            StyledRect {
                width: parent.width
                height: childrenRect.height
                radius: Theme.cornerRadius * 2
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Theme.outlineVariant
                visible: controller && controller.dualConnectionEnabled

                Column {
                    width: parent.width

                    Repeater {
                        model: controller ? controller.connectedDevices : []
                        delegate: Column {
                            width: parent.width

                            Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"
                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.spacingM
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 40
                                        StyledText {
                                            text: modelData.name
                                            color: Theme.surfaceText
                                            font.pixelSize: Theme.fontSizeMedium
                                        }
                                        StyledText {
                                            text: modelData.status
                                            color: Theme.surfaceVariantText
                                            font.pixelSize: Theme.fontSizeSmall
                                        }
                                    }
                                    DankIcon {
                                        name: modelData.status === 'Active' ? "check_box" : "check_box_outline_blank"
                                        color: modelData.status === 'Active' ? Theme.surfaceText : Theme.surfaceVariantText
                                        size: 24
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!controller) return;
                                        var currentlyActive = controller.connectedDevices.filter(function(d) { return d.status === 'Active'; }).length;
                                        if (modelData.status === 'Saved' && currentlyActive >= 2) {
                                            return; // Max devices reached
                                        }
                                        
                                        var action = modelData.status === 'Active' ? "disconnect" : "connect";
                                        if (window && typeof window.startFakeLoading === 'function') {
                                            window.startFakeLoading(modelData.status === 'Active' ? "Disconnecting..." : "Connecting...", 2000);
                                        }
                                        
                                        controller.sendCommand("devices", action, modelData.mac, "", action + " device");

                                        // Refresh devices list
                                        var timer = Qt.createQmlObject('import QtQuick; Timer { interval: 2000; repeat: false; onTriggered: { controller.fetchDevices(); this.destroy(); } }', root, "devRefreshTimer");
                                        timer.start();
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.outlineVariant
                                visible: index < (controller ? controller.connectedDevices.length - 1 : 0)
                            }
                        }
                    }
                }
            }
        }
    }
}
