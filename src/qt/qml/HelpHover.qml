/*
    A help icon which when hovered gives a popup with information
*/
import QtQuick 2.15
import MMPTheme 1.0
MouseArea {
    id: helpHoverMouseArea
    property alias text: popup.infoText
    property alias imageSource: helpIcon.source
    property alias popupWidth: popup.width
    property alias verticalPadding: popup.verticalPadding
    property alias horiontalPadding: popup.horizontalPadding
    property alias topPadding: popup.topPadding
    property alias bottomPadding: popup.bottomPadding
    property int iconSize: 15
    width: iconSize
    height: iconSize
    implicitWidth: helpIcon.implicitWidth
    implicitHeight: helpIcon.implicitHeight
    hoverEnabled: true

    Image {
        id: helpIcon
        anchors.fill: parent
        source: "resources/icons/generic/ic_help.svg"
        sourceSize: Qt.size(iconSize, iconSize)
        fillMode: Image.Pad
    }

    InfoPopup {
        id: popup
        visible: helpHoverMouseArea.containsMouse
        y: helpIcon.height + 5
        x: -width/2+helpIcon.width/2
    }

}
