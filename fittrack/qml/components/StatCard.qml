import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppCard {
    id: card
    property string label: ""
    property string value: "--"
    property string footnote: ""
    property color accentColor: Design.Theme.primary

    padding: Design.Theme.space16

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.Theme.space4

        Label {
            text: card.label
            color: Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeCaption
        }

        Label {
            text: card.value
            color: Design.Theme.surfaceText
            font.pixelSize: Design.Theme.typeMetric
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Label {
            visible: text.length > 0
            text: card.footnote
            color: card.accentColor
            font.pixelSize: Design.Theme.typeCaption
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
