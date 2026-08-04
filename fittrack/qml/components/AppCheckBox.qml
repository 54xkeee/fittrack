import QtQuick
import QtQuick.Controls
import "../theme" as Design

CheckBox {
    id: root

    implicitHeight: Design.Theme.touchTarget
    spacing: Design.Theme.space12
    font.pixelSize: Design.Theme.typeLabel

    indicator: Rectangle {
        x: 0
        y: (root.height - height) / 2
        width: 22
        height: 22
        radius: Design.Theme.radiusSmall
        color: root.checked ? Design.Theme.primary : Design.Theme.surfacePrimary
        border.width: root.activeFocus ? 2 : 1
        border.color: root.checked || root.activeFocus
                      ? Design.Theme.primary : Design.Theme.borderDefault

        AppIcon {
            anchors.centerIn: parent
            width: 16
            height: 16
            visible: root.checked
            name: "success"
            color: Design.Theme.primaryForeground
        }
    }

    contentItem: Label {
        leftPadding: root.indicator.width + root.spacing
        text: root.text
        color: root.enabled ? Design.Theme.textPrimary : Design.Theme.textDisabled
        font: root.font
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
    }
}
