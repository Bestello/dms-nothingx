import QtQuick
import qs.Common
import qs.Widgets

/*
 * FindMyPage.qml
 *
 * Page to ring the left and right earbuds to help locate them.
 */
Item {
    id: root

    property var controller: null
    property var window: null

    width: parent ? parent.width : 440
    height: parent ? parent.height : 850

    Item {
        id: fmHeader
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
            id: backIconFm
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
            text: "Find my earbuds"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: backIconFm.right
            anchors.leftMargin: Theme.spacingM
        }
    }

    Column {
        anchors.top: fmHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingXL

        StyledText {
            text: "Click the play button for the earbud you wish to locate. This will trigger a sound."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeMedium
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Item {
            width: parent.width
            height: 250

            Row {
                anchors.centerIn: parent
                spacing: 40

                // Left Bud
                Column {
                    spacing: Theme.spacingL
                    property bool isRinging: false
                    Image {
                        source: "file://" + controller.leftBudImg
                        width: 120
                        height: 180
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: parent.isRinging ? Theme.surfaceContainerHighest : "#d93025"
                        anchors.horizontalCenter: parent.horizontalCenter
                        DankIcon {
                            name: parent.isRinging ? "stop" : "play_arrow"
                            color: parent.isRinging ? Theme.surfaceText : "white"
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                parent.parent.isRinging = !parent.parent.isRinging;
                                if (window && typeof window.startFakeLoading === 'function') {
                                    window.startFakeLoading();
                                }
                                controller.sendCommand("find_my", "set", parent.parent.isRinging ? "on" : "off", "L", parent.parent.isRinging ? "Ringing Left Earbud" : "Stopped Left Earbud");
                            }
                        }
                    }
                }

                // Right Bud
                Column {
                    spacing: Theme.spacingL
                    property bool isRinging: false
                    Image {
                        source: "file://" + controller.rightBudImg
                        width: 120
                        height: 180
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: parent.isRinging ? Theme.surfaceContainerHighest : "#d93025"
                        anchors.horizontalCenter: parent.horizontalCenter
                        DankIcon {
                            name: parent.isRinging ? "stop" : "play_arrow"
                            color: parent.isRinging ? Theme.surfaceText : "white"
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                parent.parent.isRinging = !parent.parent.isRinging;
                                if (window && typeof window.startFakeLoading === 'function') {
                                    window.startFakeLoading();
                                }
                                controller.sendCommand("find_my", "set", parent.parent.isRinging ? "on" : "off", "R", parent.parent.isRinging ? "Ringing Right Earbud" : "Stopped Right Earbud");
                            }
                        }
                    }
                }
            }
        }

        Item {
            width: 1
            height: 50
        } // Spacer

        StyledText {
            text: "Make sure your earbuds are not in use before you continue. Activating this feature with earbuds in-ear may cause hearing damage."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width
        }
    }
}
