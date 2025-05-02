/*
    Splash Screem shown on startup allowing for the wallet to load
*/
import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls.Basic 2.15 as Basic
import MMPTheme 1.0

Window {
    id: splashScreen
    width: 400
    height: 200
    flags: Qt.SplashScreen | Qt.FramelessWindowHint
    visible: true
    color: "transparent"
    signal loaded
    property int currentBlocksLoaded: 0
    property int totalBlocks: 2000000

    Connections {
        target: _messageBrige
        function onNewInitMessage(message) {
             console.log("QML received message:", message)
        }
    }

    Rectangle {
        id: background
        anchors.fill: parent
        border.color: "transparent"
        radius: 4
        gradient: Gradient {
            orientation: MMPTheme.isLightTheme ? Gradient.Vertical : Gradient.Horizontal
            GradientStop { position: 0; color: MMPTheme.themeSelect(MMPTheme.cWhite, "#465360") }
            GradientStop { position: 1; color: MMPTheme.themeSelect(MMPTheme.cLilyWhite, "#2c3540") }
        }
    }

    Timer {
        id: blockLoadingTimer
        interval: 10
        running: true
        repeat: true
        onTriggered: {
            currentBlocksLoaded += 2000
            if (blockProgressBar.value>= 1) {
                running=false
                opacityAnimation.start()
            }
        }
    }
    function closeSplashScreen() {
        loaded()
        splashScreen.close()
    }
    NumberAnimation {
        id: opacityAnimation
        target: splashScreen
        properties: "opacity"
        duration: 1000
        from: 1
        to: 0
        running: false
        onFinished: closeSplashScreen()
    }
    Basic.ProgressBar {
        id: blockProgressBar
        value: currentBlocksLoaded/totalBlocks
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        background: Item{}
        contentItem: Item {
            implicitWidth: 200
            implicitHeight: 4
            Rectangle {
                id: mainBarRect
                width: blockProgressBar.visualPosition * parent.width
                height: 2
                color: MMPTheme.highlightColor
            }
            Rectangle {
                width: blockProgressBar.visualPosition * parent.width
                height: parent.height
                color: MMPTheme.highlightColor
                radius: 4
            }
            Rectangle {
                width: 4
                height: parent.height
                anchors.right: mainBarRect.right
                color: MMPTheme.highlightColor
                visible: blockProgressBar.value<0.99
            }
        }
    }
    Image {
        id: logo
        source: "qrc:/images/gridcoin"
        sourceSize: Qt.size(80, 80)
        anchors {
            top: parent.top
            horizontalCenter: parent.horizontalCenter
            topMargin: 20
        }
    }
    Text {
        id: gridcoinText
        text: qsTr("Gridcoin")
        color: MMPTheme.themeSelect("#4e2fad", MMPTheme.cWhite)
        font.pixelSize: 34
        font.weight: Font.Bold
        font.family: "Montserrat"
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: logo.bottom
            topMargin: 5
        }
    }
    Text {
        id: subTitleText
        text: qsTr("Rewarding Volunteer Distributed Computing")
        color: MMPTheme.themeSelect("#7787a3", MMPTheme.cWhite)
        font.weight: Font.DemiBold
        font.family: "Montserrat"
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: gridcoinText.bottom
            topMargin: 5
        }
    }
    Text {
        id: blocksLoadedText
        text: qsTr("%L1/%L2 Blocks Loaded").arg(currentBlocksLoaded).arg(totalBlocks)
        color: MMPTheme.themeSelect(MMPTheme.cOxfordBlue, "#6a7994")
        font.pixelSize: 10
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: blockProgressBar.top
            bottomMargin: 5
        }
    }
}
