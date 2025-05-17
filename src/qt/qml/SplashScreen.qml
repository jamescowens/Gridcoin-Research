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

    signal splashClosing

    Connections {
        target: _initModel
        function onHideSplashScreen() { fadeOut.start() }
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

    function closeSplashScreen() {
        splashClosing()
        splashScreen.close()
    }
    NumberAnimation {
        id: fadeOut
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
        value: _initModel.total === 0 ? 0 : _initModel.loaded / _initModel.total
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
        source: "qrc:/icons/logos/ic_logo_app_gradient_white.svg"
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
        text: _initModel.message
        color: MMPTheme.themeSelect(MMPTheme.cOxfordBlue, "#6a7994")
        font.pixelSize: 10
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: blockProgressBar.top
            bottomMargin: 5
        }
    }
}
