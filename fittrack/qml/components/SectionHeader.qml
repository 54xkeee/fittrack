import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root
    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""

    spacing: 4

    Label {
        visible: root.eyebrow.length > 0
        text: root.eyebrow
        color: "#C5FF4A"
        font.pixelSize: 12
        font.bold: true
    }

    Label {
        text: root.title
        color: "#F3F0EF"
        font.pixelSize: 25
        font.bold: true
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    Label {
        visible: root.subtitle.length > 0
        text: root.subtitle
        color: "#A8AAA9"
        font.pixelSize: 13
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
}
