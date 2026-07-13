import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

ColumnLayout {
    id: root
    property string eyebrow: ""
    property string title: ""
    property string subtitle: ""

    spacing: Design.Theme.space4

    Label {
        visible: root.eyebrow.length > 0
        text: root.eyebrow
        color: Design.Theme.primary
        font.pixelSize: Design.Theme.typeCaption
        font.weight: Font.DemiBold
    }

    Label {
        text: root.title
        color: Design.Theme.backgroundText
        font.pixelSize: Design.Theme.typeDisplay
        font.weight: Font.Bold
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }

    Label {
        visible: root.subtitle.length > 0
        text: root.subtitle
        color: Design.Theme.surfaceMuted
        font.pixelSize: Design.Theme.typeLabel
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
    }
}
