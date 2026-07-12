import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Frame {
    id: card
    property string label: ""
    property string value: "--"
    property string footnote: ""

    padding: 16

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Label {
            text: card.label
            color: "#AEB7B1"
            font.pixelSize: 13
        }

        Label {
            text: card.value
            font.pixelSize: 23
            font.bold: true
        }

        Label {
            visible: text.length > 0
            text: card.footnote
            color: "#7E8982"
            font.pixelSize: 11
        }
    }
}
