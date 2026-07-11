import QtQuick
import QtQuick.Window
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Services
import Quickshell
import Quickshell.Io

// No directory imports, using Loader with source path

Window {
    id: appWindow
    width: 440
    height: 850
    title: "CMF Settings"
    color: Theme.surface
    flags: Qt.Window | Qt.FramelessWindowHint

    // Properties expected by Quickshell/DMS
    property string pluginDir: ""

    // Core Logic Controller
    property var controller: null

    // Fallback sync properties for pages
    property bool ldacEnabled: controller ? controller.ldacEnabled : false
    property bool inEarDetection: controller ? controller.inEarDetection : true
    property string eqPreset: controller ? controller.eqPreset : "balanced"
    property int customEqBass: 0
    property int customEqMid: 0
    property int customEqTreble: 0
    property bool showUltraBassSlider: false
    property int ultraBassLevel: 3
    property bool isLoading: false
    property string loadingText: ""
    property bool dualConnectionEnabled: controller ? controller.dualConnectionEnabled : false

    // Component Definitions for Pages
    property Component dashboardPageComp: dashboardPageCompDef
    property Component deviceSettingsPageComp: deviceSettingsPageCompDef
    property Component eqPageComp: eqPageCompDef
    property Component controlsPageComp: controlsPageCompDef
    property Component dualConnectionPageComp: dualConnectionPageCompDef
    property Component findMyPageComp: findMyPageCompDef

    Component {
        id: dashboardPageCompDef
        Loader {
            Component.onCompleted: setSource("qml/pages/DashboardPage.qml", {
                "window": appWindow,
                "controller": appWindow.controller
            })
        }
    }
    Component {
        id: deviceSettingsPageCompDef
        Loader {
            Component.onCompleted: setSource("qml/pages/DeviceSettingsPage.qml", {
                "window": appWindow,
                "controller": appWindow.controller
            })
        }
    }
    Component {
        id: eqPageCompDef
        Loader {
            Component.onCompleted: setSource("qml/pages/EqualizerPage.qml", {
                "window": appWindow,
                "controller": appWindow.controller
            })
        }
    }
    Component {
        id: controlsPageCompDef
        Loader {
            Component.onCompleted: setSource("qml/pages/GesturesPage.qml", {
                "window": appWindow,
                "controller": appWindow.controller
            })
        }
    }
    Component {
        id: dualConnectionPageCompDef
        Loader {
            Component.onCompleted: setSource("qml/pages/DualConnectionPage.qml", {
                "window": appWindow,
                "controller": appWindow.controller
            })
        }
    }
    Component {
        id: findMyPageCompDef
        Loader {
            Component.onCompleted: setSource("qml/pages/FindMyPage.qml", {
                "window": appWindow,
                "controller": appWindow.controller
            })
        }
    }

    function pushPage(pageComponent) {
        stackView.push(pageComponent);
    }

    function popPage() {
        stackView.pop();
    }

    function startFakeLoading(customText, customDuration) {
        appWindow.loadingText = customText || "";
        fakeLoadTimer.interval = customDuration || 1500;
        appWindow.isLoading = true;
        fakeLoadTimer.start();
    }

    Timer {
        id: fakeLoadTimer
        interval: 1500
        repeat: false
        onTriggered: {
            appWindow.isLoading = false;
            appWindow.loadingText = "";
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: dashboardPageComp

        // Slide transitions
        pushEnter: Transition {
            NumberAnimation {
                property: "x"
                from: stackView.width
                to: 0
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        pushExit: Transition {
            NumberAnimation {
                property: "x"
                from: 0
                to: -stackView.width
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        popEnter: Transition {
            NumberAnimation {
                property: "x"
                from: -stackView.width
                to: 0
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
        popExit: Transition {
            NumberAnimation {
                property: "x"
                from: 0
                to: stackView.width
                duration: 250
                easing.type: Easing.OutCubic
            }
        }
    }

    // Global Overlays

    // Ultra Bass Overlay
    Rectangle {
        id: ultraBassOverlay
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 250
        color: Theme.surfaceContainerHighest
        radius: Theme.cornerRadius * 3
        visible: appWindow.showUltraBassSlider
        z: 9998
        MouseArea {
            anchors.fill: parent
        } // Block clicks
        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingXL
            Row {
                width: parent.width
                Item {
                    width: 24
                    height: 24
                } // Spacer
                StyledText {
                    text: "Ultra bass"
                    font.weight: Font.Bold
                    font.pixelSize: Theme.fontSizeLarge
                    color: Theme.surfaceText
                    width: parent.width - 48
                    horizontalAlignment: Text.AlignHCenter
                }
                DankIcon {
                    name: "close"
                    size: 24
                    color: Theme.surfaceText
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appWindow.showUltraBassSlider = false
                    }
                }
            }
            Slider {
                id: ubSlider
                width: parent.width - 40
                anchors.horizontalCenter: parent.horizontalCenter
                from: 1
                to: 5
                stepSize: 1
                snapMode: Slider.SnapAlways
                value: appWindow.ultraBassLevel
                onValueChanged: {
                    appWindow.ultraBassLevel = value;
                    if (controller) {
                        controller.updateState("ultraBassLevel", value);
                        controller.sendCommand("ultra_bass", "set", value, "", "Ultra Bass");
                    }
                }
                background: Rectangle {
                    x: 0
                    y: (parent.height - height) / 2
                    width: parent.width
                    height: 24
                    radius: 12
                    color: Theme.surfaceContainerHighest
                    Repeater {
                        model: 5
                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: Theme.surfaceText
                            opacity: 0.3
                            anchors.verticalCenter: parent.verticalCenter
                            x: (index / 4.0) * (parent.width - 6) + 1
                        }
                    }
                    Rectangle {
                        width: parent.width * ubSlider.visualPosition
                        height: parent.height
                        radius: 12
                        color: Theme.primary
                    }
                }
                handle: Rectangle {
                    x: ubSlider.leftPadding + ubSlider.visualPosition * (ubSlider.availableWidth - width)
                    y: ubSlider.topPadding + ubSlider.availableHeight / 2 - height / 2
                    width: 6
                    height: 32
                    radius: 3
                    color: Theme.primary
                }
            }
            StyledText {
                text: "Level " + appWindow.ultraBassLevel
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // Loading Overlay
    Rectangle {
        id: loadingOverlay
        anchors.fill: parent
        color: "#99000000"
        z: 9999
        visible: appWindow.isLoading
        MouseArea {
            anchors.fill: parent
        }
        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingL
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.spacingM
                Repeater {
                    model: 3
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: Theme.primary
                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: appWindow.isLoading
                            PauseAnimation {
                                duration: index * 150
                            }
                            NumberAnimation {
                                from: 1.0
                                to: 1.5
                                duration: 300
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                from: 1.5
                                to: 1.0
                                duration: 300
                                easing.type: Easing.InQuad
                            }
                            PauseAnimation {
                                duration: (2 - index) * 150 + 150
                            }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: appWindow.isLoading
                            PauseAnimation {
                                duration: index * 150
                            }
                            NumberAnimation {
                                from: 0.3
                                to: 1.0
                                duration: 300
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                from: 1.0
                                to: 0.3
                                duration: 300
                                easing.type: Easing.InQuad
                            }
                            PauseAnimation {
                                duration: (2 - index) * 150 + 150
                            }
                        }
                    }
                }
            }
            StyledText {
                text: appWindow.loadingText
                visible: appWindow.loadingText !== ""
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
