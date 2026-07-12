import QtQuick
import QtQuick.Controls

Button {
    id: root
    property bool accent: false

    implicitHeight: 48
    font.pixelSize: 14
    font.bold: true
    leftPadding: 16
    rightPadding: 16

    contentItem: Label {
        text: root.text
        color: root.accent ? "#121212" : "#F3F0EF"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font: root.font
    }

    background: Rectangle {
        radius: 8
        color: root.accent ? "#C5FF4A" : (root.down ? "#303232" : "#222424")
        border.width: root.accent ? 0 : 1
        border.color: "#3A3C3C"
    }
}
