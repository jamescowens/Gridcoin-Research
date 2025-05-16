/*
    A view allowing for the sending of funds
*/
import QtQuick 2.15
import QtQuick.Controls 2.15
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
            property real balValue: 54069.27
            anchors {
                verticalCenter: parent.verticalCenter
                right: parent.right
                rightMargin: 20

            }
            Text {
                id: balanceValue
                text: balColumn.balValue.toLocaleString(Qt.locale(), 'f', 2)
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
    }
    ListModel {
        id: outputModel
        ListElement {
            recipient: ""
            message: ""
            label: ""
            amount: 0
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
            bottom: parent.bottom
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
                model: outputModel
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
                        icon.source: MMPTheme.themeSelect("resources/icons/buttons/ic_btn_paste_light.svg","resources/icons/buttons/ic_btn_paste_dark.svg")
                        anchors {
                            verticalCenter: recipientLabel.verticalCenter
                            right: parent.right
                            rightMargin: 20
                        }
                    }
                    Button {
                        id: dropdownButton
                        icon.source: MMPTheme.themeSelect("resources/icons/buttons/ic_btn_open_menu_light.svg","resources/icons/buttons/ic_btn_open_menu_dark.svg")
                        anchors {
                            verticalCenter: recipientLabel.verticalCenter
                            right: clipboardButton.left
                            rightMargin: 5
                        }
                    }
                    TextField {
                        id: recipientField
                        height: fieldHeight
                        text: recipient
                        placeholderText: "Gridcoin Address (eg. SBPvphumk9BmzdLqCBy4b7U62tj39iynLo)"
                        onTextChanged: outputModel.setProperty(index, "recipient", text)
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
                        icon.source: MMPTheme.themeSelect("resources/icons/buttons/ic_btn_attach_light.svg","resources/icons/buttons/ic_btn_attach_dark.svg")
                        anchors {
                            verticalCenter: messageLabel.verticalCenter
                            right: parent.right
                            rightMargin: 20
                        }
                    }
                    TextField {
                        id: messageTextField
                        height: fieldHeight
                        onTextChanged: outputModel.setProperty(index, "message", text)
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
                        onTextChanged: outputModel.setProperty(index, "label", text)
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
                    SpinBox {
                        id: transactionAmountSpinBox
                        property real balance: 3.2
                        property int decimals: 8
                        property real factor: Math.pow(10, decimals)
                        width: 160
                        focusPolicy: Qt.StrongFocus
                        editable: true
                        from: 0
                        to: balance * factor
                        stepSize: factor
                        onValueChanged: outputModel.setProperty(index, "amount", value)
                        anchors {
                            verticalCenter: labelLabel.verticalCenter
                            right: grcText.left
                            rightMargin: 5
                        }
                        validator: DoubleValidator {
                            bottom: Math.min(transactionAmountSpinBox.from, transactionAmountSpinBox.to)
                            top:  Math.max(transactionAmountSpinBox.from, transactionAmountSpinBox.to)
                            decimals: 8
                        }
                        textFromValue: function(value, locale) {
                            return Number(value / factor).toLocaleString(locale, 'f', transactionAmountSpinBox.decimals)
                        }
                        valueFromText: function(text, locale) {
                            return Number.fromLocaleString(locale, text) * factor
                        }
                    }
                    Text {
                        id: amountLabel
                        text: qsTr("Amount")+ ":"
                        color: MMPTheme.textColor
                        font.pixelSize: 13
                        anchors {
                            right: transactionAmountSpinBox.left
                            rightMargin: 5
                            verticalCenter: labelLabel.verticalCenter
                        }
                    }

                    Item {
                        id: bottomControls
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
                            color: MMPTheme.themeSelect(MMPTheme.cFrostWhite, "#161b24")
                            height: parent.height-controlBottomRect.radius
                            anchors {
                                top: parent.top
                                right: parent.right
                                left: parent.left
                            }
                        }
                        Rectangle {
                            id: controlBottomRect
                            color: MMPTheme.themeSelect(MMPTheme.cFrostWhite, "#161b24")
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
                            icon.source: MMPTheme.themeSelect("resources/icons/buttons/ic_btn_remove_light.svg","resources/icons/buttons/ic_btn_remove_dark.svg")
                            text: qsTr("Remove")
                            onPressed: outputModel.remove(index)
                            anchors {
                                verticalCenter: parent.verticalCenter
                                left: parent.left
                                leftMargin: 20
                            }
                        }
                        Button {
                            id: sendButton
                            icon.source: MMPTheme.themeSelect("resources/icons/buttons/ic_btn_send_light.svg","resources/icons/buttons/ic_btn_send_dark.svg")
                            text: qsTr("Send")
                            //onPressed: sendTransaction(recipient, message, label, amount)
                            anchors {
                                verticalCenter: parent.verticalCenter
                                right: parent.right
                                rightMargin: 20
                            }
                        }
                    }
                }
            }

            Button {
                id: newOutputButton
                icon.source: MMPTheme.themeSelect("resources/icons/buttons/ic_btn_add_light.svg", "resources/icons/buttons/ic_btn_add_dark.svg")
                text: qsTr("New Recipient")
                anchors.horizontalCenter: parent.horizontalCenter
                onPressed: outputModel.append({"recipient":"","message":"","label":""})
            }
        }
    }
}
