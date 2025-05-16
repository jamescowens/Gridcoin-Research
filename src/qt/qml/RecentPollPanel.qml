/*
    Panel in overview view showing a few recent polls.
*/
import QtQuick 2.15
import MMPTheme 1.0
Rectangle {
    id: latestPollsPanel
    property int sideBodyMargin: 20
    color: MMPTheme.bodyColor
    radius: 4

    PanelTitle {
        id: latestPollTitle
        text: "Latest Polls"
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: topBodyMargin
            leftMargin: sideBodyMargin
            rightMargin: sideBodyMargin
        }
    }

    ListView {
        id: recentPollList
        anchors {
            top: latestPollTitle.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: topBodyMargin
            leftMargin: sideBodyMargin
            rightMargin: sideBodyMargin
            bottomMargin: bottomBodyMargin
        }
        clip: true
        spacing: 5
        interactive: false

        model: ListModel {
            //Placeholder data
            ListElement {
                title: "Constant Block Reward (CBR) Proposal and Poll"
                expires: 2607057017
                //Add more later
            }
            ListElement {
                title: "Do you approve of the redesigned Gridcoin Logo?"
                expires: 0
            }
            ListElement {
                title: "What is your favourite comunications platform"
                expires: 0
            }
            ListElement {
                title: "Should Sourcefinder be removed from the whitelist due to no avaialable work units?"
                expires: 1607057017
            }
            ListElement {
                title: "Whitelist Poll: Should we remove Lieden Classical from the whitelist due to not accepting new users"
                expires: 1607057017
            }
            ListElement {
                title: "Should we give ZigzagoonBalloon all of our Gridcoin?"
                expires: 1607057017
            }
            ListElement {
                title: "Is this new GUI the prettiest GUI you have ever seen?"
                expires: 1607057017
            }
        }

        delegate: Item {
            id: pollWrapper
            property bool current: new Date(expires*1000) > MMPTheme.currentTime
            height: pollItemTitle.height
            Circle {
                id: pollItemCircle
                radius: 2
                color: current ? MMPTheme.textColor : "transparent"
                border.color: current ? MMPTheme.textColor : MMPTheme.lightTextColor
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                id: pollItemTitle
                text: title
                color: pollItemCircle.border.color
                font.weight: current ? Font.Medium : Font.Normal
                font.pixelSize: 12
                anchors.left: pollItemCircle.right
                anchors.verticalCenter: pollItemCircle.verticalCenter
                anchors.leftMargin: 4
            }
        }
    }
}
