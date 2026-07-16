import QtQuick
import QtQuick.Controls
import "../theme" as Design

ComboBox {
    id: root

    implicitHeight: Design.Theme.touchTarget
    leftPadding: Design.Theme.space12
    rightPadding: Design.Theme.space32
    font.pixelSize: Design.Theme.typeLabel

    contentItem: Label {
        leftPadding: 0
        rightPadding: 0
        text: root.displayText
        color: root.enabled ? Design.Theme.textPrimary : Design.Theme.textDisabled
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: AppIcon {
        x: root.width - width - Design.Theme.space12
        y: (root.height - height) / 2
        width: 18
        height: 18
        name: "down"
        color: root.enabled ? Design.Theme.textSecondary : Design.Theme.textDisabled
    }

    background: Rectangle {
        radius: Design.Theme.radiusInput
        color: root.down ? Design.Theme.surfaceSecondary : Design.Theme.surfacePrimary
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Design.Theme.primary : Design.Theme.borderDefault
    }
}
