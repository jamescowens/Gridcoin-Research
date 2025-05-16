/*
    Provides an image which can be given different colours programmatically with tintColor
*/
import QtQuick 2.15
import QtGraphicalEffects 1.15
Item {
    property alias tintColor: img.overlayColor
    property alias source: img.source
    implicitHeight: img.implicitHeight
    implicitWidth: img.implicitWidth
    Image {
        id: img
        property color overlayColor: "transparent"
        anchors.fill: parent
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(width,height)
        layer {
            enabled: true
            effect: ColorOverlay {
                id: overlay
                color: img.overlayColor
            }
        }
    }

}
