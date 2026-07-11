import QtQuick
import qs.Common
import qs.Widgets

/*
 * ActionToggle.qml
 *
 * A reusable component for boolean settings (e.g., In-Ear Detection, Gaming Mode).
 * Displays a title, description, and an icon-based toggle switch.
 */
Item {
    id: root

    property string title: ""
    property string description: ""
    property bool checked: false
    property bool isActive: true
    
    signal toggled()

    width: parent.width
    height: Math.max(textCol.height, 40) // Ensure enough height for text or toggle

    Row {
        anchors.fill: parent
        spacing: Theme.spacingM

        Column {
            id: textCol
            width: parent.width - 50 - Theme.spacingM
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            StyledText { 
                text: root.title
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold 
            }
            StyledText { 
                text: root.description
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                width: parent.width 
            }
        }

        Item {
            width: 50
            height: 40
            anchors.verticalCenter: parent.verticalCenter
            
            DankIcon {
                anchors.centerIn: parent
                name: root.checked ? "toggle_on" : "toggle_off"
                color: root.checked ? Theme.primary : Theme.surfaceVariantText
                size: 40
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: root.isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (root.isActive) {
                        root.toggled();
                    }
                }
            }
        }
    }
}
