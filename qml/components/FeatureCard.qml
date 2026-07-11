import QtQuick
import qs.Common
import qs.Widgets

/*
 * FeatureCard.qml
 *
 * A reusable square/rectangular card component used in feature grids
 * (e.g., Spatial Audio, Ultra Bass, Equaliser).
 * It abstracts away the layout and hover states to reduce duplication.
 */
StyledRect {
    id: root

    // Public properties
    property string title: ""
    property string subtitle: ""
    property string iconName: ""
    property color iconColor: Theme.primary
    property bool isActive: true
    
    // Signals
    signal clicked()

    height: 110
    radius: Theme.cornerRadius * 2
    color: mouseArea.containsMouse && isActive ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
    border.width: 1
    border.color: Theme.surfaceContainerHighest

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: 2
        
        StyledText { 
            text: root.title
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold 
        }
        StyledText { 
            text: root.subtitle
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall 
        }
        
        Item { width: 1; height: Theme.spacingS }
        
        DankIcon { 
            name: root.iconName
            size: Theme.iconSize * 1.5
            color: root.iconColor
            anchors.horizontalCenter: parent.horizontalCenter 
        }
    }

    MouseArea { 
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.isActive
        cursorShape: root.isActive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.isActive) {
                root.clicked();
            }
        }
    }
}
