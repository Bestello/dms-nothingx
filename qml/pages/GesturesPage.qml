import QtQuick
import qs.Common
import qs.Widgets

/*
 * GesturesPage.qml
 *
 * Page for configuring earbud touch controls.
 */
Item {
    id: root

    property var controller: null
    property var window: null

    width: parent ? parent.width : 440
    height: parent ? parent.height : 850

    Item {
        id: controlsHeader
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
            id: backIconControls
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
            text: "Controls"
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Bold
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: backIconControls.right
            anchors.leftMargin: Theme.spacingM
        }
    }

    Column {
        anchors.top: controlsHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.spacingL
        spacing: Theme.spacingM

        StyledRect {
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
                StyledText {
                    text: "Left earbud"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                }
                DankIcon {
                    name: "chevron_right"
                    color: Theme.surfaceVariantText
                    size: 24
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        StyledRect {
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
                StyledText {
                    text: "Right earbud"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 40
                }
                DankIcon {
                    name: "chevron_right"
                    color: Theme.surfaceVariantText
                    size: 24
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
