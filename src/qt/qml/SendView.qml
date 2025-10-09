/*
    A view allowing for the sending of funds
*/
import QtQuick
import QtQuick.Controls
import Qt.labs.platform // For MessageDialog. Can be removed Qt 6.3+
import MMPTheme 1.0

Rectangle {
    id: main
    color: MMPTheme.backgroundColor

    Connections {
        target: _sendCoinsController
        function onCoinsSentOrFailed(message) {
            coinsResultDialog.text = message
            coinsResultDialog.open()
        }
    }

    MessageDialog { 
        id: coinsResultDialog
        buttons: MessageDialog.Ok
    }

    Rectangle {
        id: header
        color: MMPTheme.headerColor
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
            text: qsTr("Send Funds")
            font.weight: Font.DemiBold
            font.pixelSize: 22
            color: MMPTheme.textColor
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: 22
            }
        }
        Column {
            id: balColumn
            anchors {
                verticalCenter: parent.verticalCenter
                right: parent.right
                rightMargin: 20

            }
            Text {
                id: balanceValue
                text: _walletModel.balance.toLocaleString(Qt.locale(), 'f', 2)
                color: MMPTheme.highlightColor
                font.pixelSize: 18
                font.weight: Font.Medium
                horizontalAlignment: Text.AllignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                id: balanceLabel
                text: qsTr("Available")
                color: MMPTheme.textColor
                horizontalAlignment: Text.AllignHCenter
                font.pixelSize: 10
                font.weight: Font.Light
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
    ScrollView {
        //id: scrollView
        clip: true
        contentHeight: outputColumn.implicitHeight + 10
        contentWidth: availableWidth
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: bottomControls.top
            bottomMargin: 10
            topMargin: 10
        }
        Column {
            id: outputColumn
            spacing: 10
            anchors {
                fill: parent
                leftMargin: 10
                rightMargin: 10
            }

            ListView {
                id: outputList
                spacing: 10
                interactive: false
                model: _sendCoinsController.recipients
                height: 170*count+(count-1)*spacing
                width: parent.width
                delegate: Rectangle {
                    id: delegateRect
                    property int fieldHeight: clipboardButton.height
                    color: MMPTheme.bodyColor
                    width: ListView.view.width
                    height: 170
                    radius: 4

                    Item {
                        id: rightLabelAnchor
                        height: parent.height
                        anchors {
                            left: parent.left
                            leftMargin: Math.max(recipientLabel.width, messageLabel.width, labelLabel.width)+20
                            top: parent.top
                        }
                    }
                    Text {
                        id: recipientLabel
                        text: qsTr("Recipient")+ ":"
                        color: MMPTheme.textColor
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                        anchors {
                            right: rightLabelAnchor.right
                            top: parent.top
                            topMargin: 20
                        }
                    }
                    Button {
                        id: clipboardButton
                        icon.source: MMPTheme.themeSelect("qrc:/icons/buttons/ic_btn_paste_light.svg","qrc:/icons/buttons/ic_btn_paste_dark.svg")
                        anchors {
                            verticalCenter: recipientLabel.verticalCenter
                            right: parent.right
                            rightMargin: 20
                        }
                    }
                    Button {
                        id: dropdownButton
                        icon.source: MMPTheme.themeSelect("qrc:/icons/buttons/ic_btn_open_menu_light.svg","qrc:/icons/buttons/ic_btn_open_menu_dark.svg")
                        anchors {
                            verticalCenter: recipientLabel.verticalCenter
                            right: clipboardButton.left
                            rightMargin: 5
                        }
                    }
                    TextField {
                        id: recipientField
                        height: fieldHeight
                        text: modelData.recipient
                        placeholderText: "Gridcoin Address (eg. bc3NA8e8E3EoTL1qhRmeprbjWcmuoZ26A2)"
                        onEditingFinished: _sendCoinsController.updateRecipient(index, {"recipient": text})
                        anchors {
                            verticalCenter: recipientLabel.verticalCenter
                            left: recipientLabel.right
                            leftMargin: 10
                            right: dropdownButton.left
                            rightMargin: 5
                        }
                    }
                    Text {
                        id: messageLabel
                        text: qsTr("Message") + ":"
                        color: MMPTheme.textColor
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                        anchors {
                            right: rightLabelAnchor.right
                            top: recipientLabel.bottom
                            topMargin: 20
                        }
                    }
                    Button {
                        id: attachFileButton
                        icon.source: MMPTheme.themeSelect("qrc:/icons/buttons/ic_btn_attach_light.svg","qrc:/icons/buttons/ic_btn_attach_dark.svg")
                        anchors {
                            verticalCenter: messageLabel.verticalCenter
                            right: parent.right
                            rightMargin: 20
                        }
                    }
                    TextField {
                        id: messageTextField
                        height: fieldHeight
                        text: modelData.message
                        onEditingFinished: _sendCoinsController.updateRecipient(index, {"message": text})
                        anchors {
                            verticalCenter: messageLabel.verticalCenter
                            left: messageLabel.right
                            leftMargin: 10
                            right: attachFileButton.left
                            rightMargin: 5
                        }
                    }
                    Text {
                        id: labelLabel
                        text: qsTr("Label") + ":"
                        color: MMPTheme.textColor
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignRight
                        anchors {
                            right: rightLabelAnchor.right
                            top: messageLabel.bottom
                            topMargin: 20
                        }
                    }
                    TextField {
                        id:labelTextField
                        height: fieldHeight
                        placeholderText: qsTr("Add a label to save it to Favourites")
                        text: modelData.label
                        onEditingFinished: _sendCoinsController.updateRecipient(index, {"label": text})
                        anchors {
                            left: labelLabel.right
                            leftMargin: 10
                            right: amountLabel.left
                            rightMargin: 20
                            verticalCenter: labelLabel.verticalCenter
                        }
                    }
                    Text {
                        id: grcText
                        text: qsTr("GRC")
                        verticalAlignment: Text.AlignVCenter
                        color: MMPTheme.textColor
                        font.pixelSize: 13
                        anchors {
                            verticalCenter: labelLabel.verticalCenter
                            right: parent.right
                            rightMargin: 20
                        }
                    }
                    TextField {
                        id: transactionAmountEdit
                        text: modelData.amount
                        width: 160
                        onEditingFinished: _sendCoinsController.updateRecipient(index, {"amount": text})
                        anchors {
                            verticalCenter: labelLabel.verticalCenter
                            right: grcText.left
                            rightMargin: 5
                        }
                        validator: DoubleValidator {
                            bottom: 0
                            top:  _walletModel.balance  // Note we aren't using this for anything
                            decimals: 8
                            notation: DoubleValidator.StandardNotation
                            locale: "en_US" // Force dot as decimal separator
                        }
                    }
                    Text {
                        id: amountLabel
                        text: qsTr("Amount")+ ":"
                        color: MMPTheme.textColor
                        font.pixelSize: 13
                        anchors {
                            right: transactionAmountEdit.left
                            rightMargin: 5
                            verticalCenter: labelLabel.verticalCenter
                        }
                    }

                    Item {
                        // id: delegatebottomControls
                        anchors {
                            bottom: parent.bottom
                            right: parent.right
                            left: parent.left
                            top: amountLabel.bottom
                            topMargin: 20
                        }
                        //Two rects needed to round the corner on bottom but not top
                        Rectangle {
                            id: controlTopRect
                            color: MMPTheme.ternaryBodyColor
                            height: parent.height-controlBottomRect.radius
                            anchors {
                                top: parent.top
                                right: parent.right
                                left: parent.left
                            }
                        }
                        Rectangle {
                            id: controlBottomRect
                            color: MMPTheme.ternaryBodyColor
                            radius: delegateRect.radius
                            height: 2*radius
                            anchors {
                                verticalCenter: controlTopRect.bottom
                                left: parent.left
                                right: parent.right
                            }
                        }

                        Button {
                            id: removeButton
                            icon.source: MMPTheme.themeSelect("qrc:/icons/buttons/ic_btn_remove_light.svg","qrc:/icons/buttons/ic_btn_remove_dark.svg")
                            text: qsTr("Remove")
                            onPressed: _sendCoinsController.removeRecipient(index)
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                leftMargin: 20
                            }
                        }
                    }
                }
            }

            Button {
                id: newOutputButton
                icon.source: MMPTheme.themeSelect("qrc:/icons/buttons/ic_btn_add_light.svg", "qrc:/icons/buttons/ic_btn_add_dark.svg")
                text: qsTr("New Recipient")
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: _sendCoinsController.addRecipient()
            }
        }
    }
    

    MessageDialog { 
        id: messageDialog
        title: qsTr("Are you sure?")
        text: qsTr("Are you sure you want to send this transaction?")
        buttons: MessageDialog.Ok | MessageDialog.Cancel
        onOkClicked: _sendCoinsController.sendCoins()
    }

    Rectangle {
        id: bottomControls
        color: MMPTheme.ternaryBodyColor
        height: 50
        radius: 4
        anchors {
            bottom: parent.bottom
            right: parent.right
            left: parent.left
            margins: 10
        }
        Button {
            id: removeAllButton
            icon.source: MMPTheme.themeSelect("qrc:/icons/buttons/ic_btn_remove_light.svg","qrc:/icons/buttons/ic_btn_remove_dark.svg")
            text: qsTr("Remove All")
            onClicked: _sendCoinsController.clearRecipients()
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: 20
            }
        }
        Button {
            id: advancedCoinControlButton
            icon.source: MMPTheme.themeSelect("qrc:/icons/buttons/ic_btn_sign_light.svg","qrc:/icons/buttons/ic_btn_sign_dark.svg")
            text: qsTr("Advanced Coin Control")
            anchors {
                verticalCenter: parent.verticalCenter
                left: removeAllButton.right
                leftMargin: 20
            }
        }

        Button {
            id: sendButton
            icon.source: MMPTheme.themeSelect("qrc:/icons/buttons/ic_btn_send_light.svg","qrc:/icons/buttons/ic_btn_send_dark.svg")
            text: qsTr("Send")
            onClicked: messageDialog.open()
            anchors {
                verticalCenter: parent.verticalCenter
                right: parent.right
                rightMargin: 20
            }
        }
    }

}
