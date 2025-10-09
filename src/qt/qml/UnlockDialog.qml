import QtQuick
import QtQuick.Controls
import MMPTheme 1.0

Dialog {
    id: unlockDialog
    title: "Unlock Wallet"
    modal: true
    width: 300
    height: 140
    anchors.centerIn: parent
    
    onOpened: {
        passwordField.forceActiveFocus()
    }
    onAccepted: {
       _walletModel.unlockWallet(passwordField.text)
    }
    onRejected: {
        _walletModel.cancelUnlock()
    }
    onClosed: {
        passwordField.text = ""
    }

    background: Rectangle {
        id: background
        anchors.fill: parent
        color: MMPTheme.backgroundColor
        radius: 4
    }

    header: Label {
        text: unlockDialog.title
        font.bold: true
        padding: 15
        width: parent.width
        height: 40
        color: MMPTheme.textColor
        background: Rectangle {
            color: MMPTheme.headerColor
            anchors.fill: parent
            radius: 4
        }
    }

    contentItem: Rectangle {
        anchors.margins: 10
        color: MMPTheme.bodyColor
        radius: 4
        anchors {
            top: unlockDialog.header.bottom
            bottom: unlockDialog.footer.top
            left: parent.left
            right: parent.right
            margins: 10
        }
        Text {
            id: passphraseLabel
            text: qsTr("Enter passphrase")
            color: MMPTheme.textColor
            anchors {
                left: parent.left
                leftMargin: 10
                verticalCenter: parent.verticalCenter
            }
        }

        TextField {
            id: passwordField
            echoMode: TextInput.Password
            Keys.onReturnPressed: unlockDialog.accept()
            anchors {
                left: passphraseLabel.right
                leftMargin: 20
                verticalCenter: passphraseLabel.verticalCenter
                right: parent.right
                rightMargin: 20
            }
        }
    }

    footer: DialogButtonBox {
        width: parent.width
        onAccepted: unlockDialog.accept()
        onRejected: unlockDialog.reject()
        Button {
            text: qsTr("OK")
            DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
        }
        Button {
            text: qsTr("Cancel")
            DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
        }

        background: Rectangle {
            anchors.fill: parent
            color: MMPTheme.ternaryBodyColor
            radius: 4
        }
    }
}