import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AppCard {
    id: card
    property string label: ""
    property string value: "--"
    property string footnote: ""
    property color accentColor: "#C5FF4A"

    padding: 16

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Label {
            text: card.label
            color: "#A8AAA9"
            font.pixelSize: 13
        }

        Label {
            text: card.value
            color: "#F3F0EF"
            font.pixelSize: 23
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            visible: text.length > 0
            text: card.footnote
            color: card.accentColor
            font.pixelSize: 11
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
