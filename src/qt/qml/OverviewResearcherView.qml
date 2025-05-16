/*
    Overview view for wallets in researcher mode.
*/
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Controls.Material 2.15
import MMPTheme 1.0
Rectangle {
    id: main
    color: MMPTheme.backgroundColor
    Rectangle {
        id: header
        color: MMPTheme.themeSelect(MMPTheme.cWhite, MMPTheme.cSpaceBlack)
        height: 70
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        Rectangle {
            id: bottomBorder
            height: 1
            color: MMPTheme.themeSelect("transparent", MMPTheme.cBlack)
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
        }

        Text {
            id: titleText
            text: qsTr("Account Overview")
            font.weight: Font.DemiBold
            font.pixelSize: 22
            color: MMPTheme.textColor
            anchors {
                top: parent.top
                left: parent.left
                topMargin: 12
                leftMargin: 22
            }
        }
        MouseArea {
            id: cpidButton
            width: cpidText.width + cpidBorder.width + cpidText.anchors.leftMargin
            height: cpidBorder.height
            onClicked: {
                //TextEdit workaround without using C++, should probably be changed in the future
                cpidCopier.selectAll()
                cpidCopier.copy()
            }

            anchors {
                top: titleText.bottom
                left: parent.left
                topMargin: 2
                leftMargin: 22
            }

            Rectangle {
                id: cpidBorder
                border.color: MMPTheme.textColor
                radius: 10
                color: "transparent"
                width: cpidTitleText.implicitWidth + 20
                height: cpidTitleText.implicitHeight + 4
                anchors {
                    top: parent.top
                    left: parent.left
                }
                Text {
                    id: cpidTitleText
                    text: qsTr("CPID")
                    color: MMPTheme.textColor
                    font.weight: Font.Light
                    anchors.centerIn: parent
                }
            }
            ToolTip {
                x: parent.width/2-width/2
                y: 20
                visible: cpidButton.pressed || visible   //Stay visible until timeout
                timeout: 1000
                contentItem: Text {
                    id: cpidCopiedText
                    text: qsTr("CPID copied")
                    color: MMPTheme.textColor
                    font.weight: Font.Light
                }
                background: Rectangle {
                    id: cpidCopiedBackground
                    color: MMPTheme.bodyColor
                    radius: 8
                    height: cpidCopiedText.implicitHeight+10
                    width: cpidCopiedText.implicitWidth+10
                    border.color: MMPTheme.borderColor
                    anchors.verticalCenter: cpidCopiedText.verticalCenter
                    anchors.horizontalCenter: cpidCopiedText.horizontalCenter
                }
            }

            Text {
                id: cpidText
                color: MMPTheme.textColor
                text: "8fbacfac0e9ed5531a31644db4d3d992"
                clip: true
                font.pixelSize: 10
                font.weight: Font.Light
                anchors {
                    left: cpidBorder.right
                    //right: parent.right
                    verticalCenter: cpidBorder.verticalCenter
                    leftMargin: 3
                }
                TextEdit{
                    id: cpidCopier
                    text: cpidText.text
                    visible: false
                }
            }
        }
        Row {
            id: headerStats
            spacing: 10
            layoutDirection: Qt.RightToLeft
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                rightMargin: 20

            }
            Column {
                id: bal
                property real balValue: 54069.27
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    id: balanceValue
                    text: bal.balValue.toLocaleString(Qt.locale(), 'f', 2)
                    color: MMPTheme.highlightColor
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AllignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    id: balanceLabel
                    text: qsTr("Your Balance")
                    color: MMPTheme.textColor
                    horizontalAlignment: Text.AllignHCenter
                    font.pixelSize: 10
                    font.weight: Font.Light
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            Rectangle {
                id: separator
                color: MMPTheme.separatorColor
                width: 1
                height: parent.height-30
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                id: magnitude
                property real mag: 610.00
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    id: magValue
                    text: magnitude.mag.toLocaleString(Qt.locale(), 'f', 2)
                    color: MMPTheme.highlightColor
                    font.pixelSize: 18
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AllignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    id: magLabel
                    text: qsTr("Magnitude")
                    color: MMPTheme.textColor
                    horizontalAlignment: Text.AllignHCenter
                    font.pixelSize: 10
                    font.weight: Font.Light
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

    }
    property int panelSpacing: 10
    property int panelRadius: 4
    property int sideBodyMargin: 20
    property int topBodyMargin: 10
    property int bottomBodyMargin: 10

    Rectangle {
        id: walletDetailsPanel
        color: MMPTheme.bodyColor
        radius: panelRadius
        height: walletDetailsTitle.height+walletDetailsTitle.anchors.topMargin+
                dataTitlesColumn.height+dataTitlesColumn.anchors.topMargin+
                balanceTitlesColumn.height+balanceTitlesColumn.anchors.topMargin+
                walletDetailsSeparator.height+walletDetailsSeparator.anchors.topMargin+
                bottomBodyMargin+topBodyMargin  //Technically wrong but works. topBodyMargin included twice, first from walletDetailsTitle.topMargin

        anchors {
            top: header.bottom
            left: parent.left
            right: parent.horizontalCenter
            leftMargin: panelSpacing
            topMargin: panelSpacing
            rightMargin: panelSpacing/2
        }
        PanelTitle {
            id: walletDetailsTitle
            text: "Wallet Details"
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: topBodyMargin
                leftMargin: sideBodyMargin
                rightMargin: sideBodyMargin
            }

            HelpHover{
                id: questionMarkMouseOver
                popupWidth: 300
                verticalPadding: 20
                horiontalPadding: sideBodyMargin
                text:
                    "
                        <html>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Status") + ":</b></font> " +
                        qsTr("Current wallet status") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Projects")+ ":</b></font> " +
                        qsTr("Your current projects") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Est. RR/day")+ ":</b></font> " +
                        qsTr("Estimated research earnings per day") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Est. Staking Frequency")+ ":</b></font> " +
                        qsTr("Estimated frequency of staking") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Available") + ":</b></font> " +
                        qsTr("Balance available for spending") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Stake") + ":</b></font> " +
                        qsTr("Balance that is currently staked") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Unconfirmed") + ":</b></font> " +
                        qsTr("Coins that have been received but not yet confirmed") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Total") + ":</b></font> " +
                        qsTr("Your total coins") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Research Rewards") + ":</b></font> " +
                        qsTr("Earnt research rewards. Stake or make a manual reward claim in the receive view to receive them") + "
                        </html>
                    "

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

            }
        }

        Column {
            id:dataTitlesColumn
            height: statusLabel.height+projectLabel.height+estRRLabel.height+estTTSLabel.height
            spacing: 4
            anchors {
                left: parent.left
                top: walletDetailsTitle.bottom
                topMargin: 10
                leftMargin: sideBodyMargin
            }
            Text {
                id: statusLabel
                color: MMPTheme.textColor
                font.pixelSize: 12
                text: qsTr("Status")+":"
            }
            Text {
                id: projectLabel
                color: MMPTheme.textColor
                text: qsTr("Projects")+":"
            }
            Text {
                id: estRRLabel
                color: MMPTheme.textColor
                text: qsTr("Est. RR/day")+":"
            }
            Text {
                id: estTTSLabel
                color: MMPTheme.textColor
                text: qsTr("Est. Staking Frequency")+":"
            }
        }
        Column {
            id: dataValuesColumn
            property string status: qsTr("BOINC Mining")
            property string projects: "lhc@home"
            property real rr: 442.71
            property real tts: 1.14
            spacing: 4
            clip: true
            anchors {
                left: dataTitlesColumn.right
                top: walletDetailsTitle.bottom
                topMargin: 10
                right: parent.right
                rightMargin: sideBodyMargin
            }
            Text {
                id: statusValue
                text: dataValuesColumn.status
                color: MMPTheme.highlightColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }
            Text {
                id: projectValue
                text: dataValuesColumn.projects
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }
            Text {
                id: estRRValue
                text: dataValuesColumn.rr.toLocaleString(Qt.locale(), 'f', 2)
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }
            Text {
                id: estTTSValue
                text: dataValuesColumn.tts.toLocaleString(Qt.locale(), 'f', 1) + qsTr(" days")
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }
        }
        Rectangle {
            id: walletDetailsSeparator
            height: 1
            width: parent.width-40
            color: MMPTheme.separatorColor
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: dataTitlesColumn.bottom
                topMargin: 20
            }
        }

        Column {
            id:balanceTitlesColumn
            spacing: 4
            height: availableLabel.height+stakeLabel.height+unconfirmedLabel.height+totalLabel.height
            anchors {
                left: parent.left
                top: walletDetailsSeparator.bottom
                topMargin: 10
                leftMargin: sideBodyMargin
            }
            Text {
                id: availableLabel
                color: MMPTheme.textColor
                text: qsTr("Available")+":"
            }
            Text {
                id: stakeLabel
                color: MMPTheme.textColor
                text: qsTr("Stake")+":"
            }
            Text {
                id: unconfirmedLabel
                color: MMPTheme.textColor
                text: qsTr("Unconfirmed")+":"
            }
            Text {
                id: totalLabel
                color: MMPTheme.textColor
                font.weight: Font.DemiBold
                text: qsTr("Total")+":"
            }
        }
        Column {
            id: balanceValuesColumn
            property real available: 47197.34593948
            property real stake: 6871.92793688
            property real unconfirmed: 17.02145689
            property real total: available+stake+unconfirmed
            spacing: 4
            clip: true
            anchors {
                left: balanceTitlesColumn.right
                top: walletDetailsSeparator.bottom
                topMargin: 10
                leftMargin: 0
                right: parent.right
                rightMargin: sideBodyMargin
            }
            Text {
                id: availableValue
                text: balanceValuesColumn.available.toLocaleString(Qt.locale(), 'f', 8) + qsTr(" GRC")
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }



            Text {
                id: stakeValue
                text: balanceValuesColumn.stake.toLocaleString(Qt.locale(), 'f', 8) + qsTr(" GRC")
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }


            Text {
                id: unconfirmedValue
                text: balanceValuesColumn.unconfirmed.toLocaleString(Qt.locale(), 'f', 8) + qsTr(" GRC")
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }

            Text {
                id: totalValue
                text: balanceValuesColumn.total.toLocaleString(Qt.locale(), 'f', 8) + qsTr(" GRC")
                color: MMPTheme.lightTextColor
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }
        }
    }

    Rectangle {
        id:networkStatePanel
        color: MMPTheme.bodyColor
        radius: panelRadius
        height: networkStateTitle.implicitHeight+networkStateTitle.anchors.topMargin+
                networkTitlesColumn.height+networkTitlesColumn.anchors.topMargin+
                bottomBodyMargin+topBodyMargin
        anchors {
            top: walletDetailsPanel.bottom
            left: parent.left
            right: parent.horizontalCenter
            leftMargin: panelSpacing
            topMargin: panelSpacing
            rightMargin: panelSpacing/2
        }

        PanelTitle {
            id: networkStateTitle
            text: "Network State"
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: topBodyMargin
                leftMargin: sideBodyMargin
                rightMargin: sideBodyMargin
            }

            HelpHover{
                id: networkStateQuestionMarkMouseOver
                popupWidth: 300
                verticalPadding: 20
                horiontalPadding: sideBodyMargin
                text:
                    "
                        <html>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Blocks") + ":</b></font> " +
                        qsTr("The number of blocks your client currently has on the chain") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Difficulty")+ ":</b></font> " +
                        qsTr("Current network difficulty. A larger value corresponds to smaller odds of staking") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Net Weight")+ ":</b></font> " +
                        qsTr("Total number of coins on the entire network which are actively trying to stake") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Coin Weight")+ ":</b></font> " +
                        qsTr("Number of your coins which are actively trying to stake") + "<br><br>
                        <font color='"+MMPTheme.textColor+"'><b>" + qsTr("Magnitude") + ":</b></font> " +
                        qsTr("Relative measure of your mining contributions") + "
                        </html>
                    "

                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

            }
        }

        Column {
            id:networkTitlesColumn
            spacing: 4
            height: blocksLabel.implicitHeight+difficultyLabel.implicitHeight+netWeightLabel.implicitHeight+coinWeightLabel.implicitHeight
            anchors {
                left: parent.left
                top: networkStateTitle.bottom
                topMargin: topBodyMargin
                leftMargin: sideBodyMargin
            }
            Text {
                id: blocksLabel
                color: MMPTheme.textColor
                text: qsTr("Blocks")+":"
            }
            Text {
                id: difficultyLabel
                color: MMPTheme.textColor
                text: qsTr("Difficulty")+":"
            }
            Text {
                id: netWeightLabel
                color: MMPTheme.textColor
                text: qsTr("Net Weight")+":"
            }
            Text {
                id: coinWeightLabel
                color: MMPTheme.textColor
                text: qsTr("Coin Weight")+":"
            }
        }
        Column {
            id: networkValuesColumn
            property int blocks: 47197
            property real difficulty: 6871.92793688
            property real netWeight: 17.02145689
            property real coinWeight: 72283
            spacing: 5
            clip: true
            anchors {
                left: networkTitlesColumn.right
                top: networkStateTitle.bottom
                topMargin: 10
                leftMargin: 0
                right: parent.right
                rightMargin: sideBodyMargin
            }
            Text {
                id: blockValue
                text: networkValuesColumn.blocks
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }

            Text {
                id: difficultyValue
                text: networkValuesColumn.difficulty.toLocaleString(Qt.locale(), 'f', 3)
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }

            Text {
                id: netWeightValue
                text: networkValuesColumn.netWeight.toLocaleString(Qt.locale(), 'f', 8)
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }

            Text {
                id: coinWeightValue
                text: networkValuesColumn.coinWeight.toLocaleString(Qt.locale(), 'f', 3)
                color: MMPTheme.lightTextColor
                horizontalAlignment: Text.AlignRight
                anchors.right: parent.right
            }
        }
    }

    Rectangle {
        id: recentTransactionsPanel
        color: MMPTheme.bodyColor
        radius: panelRadius
        height: networkStatePanel.height+walletDetailsPanel.height+panelSpacing
        anchors {
            top: header.bottom
            right: parent.right
            left: parent.horizontalCenter
            topMargin: panelSpacing
            rightMargin: panelSpacing
            leftMargin: panelSpacing/2 
        }
        PanelTitle {
            id: recentTransactionsTitle
            text: "Recent Transactions"
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
            id: recentTransactionList
            contentWidth: width
            clip: true
            anchors {
                top: recentTransactionsTitle.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: topBodyMargin
                leftMargin: sideBodyMargin
                rightMargin: sideBodyMargin
                bottomMargin: bottomBodyMargin
            }

            model: ListModel {
                ListElement {
                    transactionType: "manualRewardClaim"
                    transactionAmount: 592.2
                    transactionTimestamp: "2017-09-17 15:52:06"
                    transactionAccount: "Main Wallet"
                }
                ListElement {
                    transactionType: "incomingTransaction"
                    transactionAmount: 17.0214
                    transactionTimestamp: "2013-09-17 15:56:06"
                    transactionAccount: "Main Wallet"
                }
                ListElement {
                    transactionType: "incomingTransaction"
                    transactionAmount: 34928.123
                    transactionTimestamp: "2013-09-17 10:56:06"
                    transactionAccount: "Not Main Wallet"
                }
                ListElement {
                    transactionType: "sentTransaction"
                    transactionAmount: -17.0214
                    transactionTimestamp: "2013-09-17 10:56:06"
                    transactionAccount: "Second Address"
                }
                ListElement {
                    transactionType: "proofOfStake"
                    transactionAmount: 10.0
                    transactionTimestamp: "2013-09-17 10:56:06"
                    transactionAccount: "Main Wallet"
                }
                ListElement {
                    transactionType: "proofOfResearch"
                    transactionAmount: 666.123
                    transactionTimestamp: "2013-09-17 10:56:06"
                    transactionAccount: "Main Wallet"
                }
                ListElement {
                    transactionType: "inOut"
                    transactionAmount: 12.123
                    transactionTimestamp: "2013-09-17 10:56:06"
                    transactionAccount: "This is just a string"
                }
                ListElement {
                    transactionType: "incomingTransaction"
                    transactionAmount: 420.69
                    transactionTimestamp: "2013-09-17 07:56:06"
                    transactionAccount: "SBPvphumk9BmzdLqCBy4b7U62tj39iynLo"
                }
                ListElement {
                    transactionType: "beaconAdvertisement"
                    transactionAmount: -0.5
                    transactionTimestamp: "2013-09-17 02:56:06"
                    transactionAccount: "SBPvphumk9BmzdLqCBy4b7U62tj39iynLo"
                }
            }
            delegate: RecentTransactionItem {
                amount: transactionAmount
                state: transactionType
                account: transactionAccount
                transactionDate: Date.fromLocaleString(Qt.locale(),  transactionTimestamp, "yyyy-MM-dd hh:mm:ss")
            }
            ScrollIndicator.vertical: ScrollIndicator {
                parent: recentTransactionList.parent
                anchors {
                    left: recentTransactionList.right
                    leftMargin: 5
                    top: recentTransactionList.top
                    bottom: recentTransactionList.bottom
                }
            }

        }
    }
    RecentPollPanel {
        id: latestPollsPanel
        radius: panelRadius
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: recentTransactionsPanel.bottom
            leftMargin: panelSpacing
            rightMargin: panelSpacing
            bottomMargin: panelSpacing
            topMargin: panelSpacing
        }

    }
}
