/*
    Footer for the MainWindow showing wallet status information
*/
import QtQuick 2.15
import MMPTheme 1.0
Rectangle {
    id: footer
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0; color: MMPTheme.themeSelect("#f2f2f2", "#171717")}
        GradientStop { position: 1; color: MMPTheme.themeSelect("#d4d4d4", "#171717")}
    }
    Rectangle {
        id: topBorderRect
        height: 1
        color: MMPTheme.themeSelect("#e7e7e7","#19222a")
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
    }

    Text {
        id: clientMessage
        text: qsTr("Client Message: Stake Weight 3982689")
        color: MMPTheme.themeSelect("#54575d","#b7b7b7")
        font.pixelSize: 10
        clip: true
        anchors {
            left: parent.left
            right: iconsRow.left
            verticalCenter: parent.verticalCenter
            leftMargin: 5
        }
    }
    Row {
        id: iconsRow
        layoutDirection: Qt.RightToLeft
        spacing: 8
        property int iconSize: 15
        anchors {
            right: parent.right
            rightMargin: spacing
            verticalCenter: parent.verticalCenter
        }

        HelpHover {
            id: lockIcon
            imageSource: MMPTheme.themeSelect("resources/icons/statusbar/lock/ic_unlocked_staking_light.svg","resources/icons/statusbar/lock/ic_unlocked_staking_dark.svg")
            iconSize: iconsRow.iconSize
            text: "The wallet is unlocked for staking"
        }
        HelpHover {
            id: connectionStrengthIcon
            imageSource: MMPTheme.themeSelect("resources/icons/statusbar/connection/ic_connection_normal_light.svg","resources/icons/statusbar/connection/ic_connection_normal_dark.svg")
            iconSize: iconsRow.iconSize
            text: "Connection is strong"
        }
        HelpHover {
            id: stakingIcon
            imageSource: MMPTheme.themeSelect("resources/icons/statusbar/staking/ic_staking_yes_light.svg","resources/icons/statusbar/staking/ic_staking_yes_dark.svg")
            iconSize: iconsRow.iconSize
            text: "Currently staking"
        }
        HelpHover {
            id: networkIcon
            imageSource: "resources/icons/statusbar/network/ic_syncing_uptodate.svg"
            iconSize: iconsRow.iconSize
            text: "Network is connected"
        }
        HelpHover {
            id: beaconIcon
            imageSource: MMPTheme.themeSelect("resources/icons/statusbar/beacon/ic_beacon_online_light.svg","resources/icons/statusbar/beacon/ic_beacon_online_dark.svg")
            iconSize: iconsRow.iconSize
            text: "Beacon is lit"
        }
    }
}
