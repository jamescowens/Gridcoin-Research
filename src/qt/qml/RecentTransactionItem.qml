/*
    Item used in overview view to show recent transactions alongside an icon
    Each state represents a different transaction type
*/
import QtQuick 2.15
import QtQml 2.15
import MMPTheme 1.0
Item {
    id: main
    property real amount: 2.0
    property date transactionDate: new Date()
    property string account
    height: 42  //Chosen to have a fit of 7 transactions on the page
    width: parent.width
    states: [
        State {
            name: "manualRewardClaim"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_mrc.svg"
            }
        }

        ,State {
            name: "incomingTransaction"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_green.svg"
            }
        },
        State {
            name: "sentTransaction"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_red.svg"
            }
        },
        State {
            name: "proofOfResearch"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_purple.svg"
            }
        },
        State {
            name: "proofOfResearchSideStakeReceive"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_purple.svg"
            }
        },
        State {
            name: "proofOfResearchSideStakeSend"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_red.svg"
            }
        },
        State {
            name: "proofOfStake"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_yellow.svg"
            }
        },
        State {
            name: "proofOfStakeSideStakeReceive"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_yellow_purple.svg"
            }
        },
        State {
            name: "orphaned"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/generic/ic_negative.svg"
            }
        },
        State {
            name: "superblock"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/superblock.svg"
            }
        },
        State {
            name: "beaconAdvertisement"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/beacon_grey.svg"
                //source: "resources/Icons/Status Bar/Beacon/ic_beacon_online_light.svg" //Generic beacon icon, doesn't seem designed for large scale
            }
            PropertyChanges {
                target: amountLabel
                color: "#9ca2af"
            }
        },
        State {
            name: "vote"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/voting.svg"
            }
        },
        State {
            name: "message"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/message.svg"
            }
        },
        State {
            name: "inOut"
            PropertyChanges {
                target: transactionIcon
                source: "resources/icons/events/ic_event_green_red.svg"
            }
        }
    ]

    Image {
        id: transactionIcon
        height: 30
        width: 30
        source: "resources/icons/events/ic_event_purple.svg"
        sourceSize: Qt.size(width, height)
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
        }
    }
    Column {
        id: transactionInfoColumn
        anchors {
            verticalCenter: parent.verticalCenter
            left: transactionIcon.right
            right: parent.right
            leftMargin: 10
        }
        Item {
            id: transactionInfoTopRow
            width: parent.width
            height: amountLabel.implicitHeight
            anchors {
                left: parent.left
                right: parent.right
            }

            Text {
                id: amountLabel
                text: amount.toLocaleString(Qt.locale(), 'f', 8)
                clip: true
                color: amount >= 0 ? MMPTheme.cDullLime : MMPTheme.cCarminePink
                anchors {
                    left: parent.left
                    right: dateLabel.left
                }
            }
            Text {
                id: dateLabel
                horizontalAlignment: Text.AlignRight
                text: transactionDate.toLocaleDateString(Qt.locale(), Locale.ShortFormat) +" "+ transactionDate.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)
                font.weight: Font.Light
                font.pointSize: 10
                color: MMPTheme.lightTextColor
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: parent.right
                }
            }
        }
        Text {
            id: addressLabel
            width: parent.width
            text: account
            font.pixelSize: 11
            color: MMPTheme.lightTextColor
            elide: Text.ElideRight
        }
    }

}
