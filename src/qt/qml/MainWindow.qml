/*
    The primary window of the wallet containg the various views and a menu to select from them
*/
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import MMPTheme 1.0
ApplicationWindow {
    id: window
    height: minimumHeight
    minimumHeight: 640
    minimumWidth: 720
    visible: true
    title: qsTr("Gridcoin Wallet")
    opacity: 1

    Behavior on opacity {
        NumberAnimation { duration: 1000 }
    }



    TabMenu{
        id: menu
        width: 90
        onMenuButtonClicked: loader.source=identification
        anchors{
            top: parent.top
            bottom: statusBar.top
            left: parent.left
        }
    }

    Loader {
        id: loader
        source: "OverviewResearcherView.qml"
        anchors {
            top: parent.top
            bottom: statusBar.top
            right: parent.right
            left: menu.right
        }
    }
    StatusFooter {
        id: statusBar
        height: 24
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
    }
}
