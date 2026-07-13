import QtQuick
import QtQuick.Controls
import "../theme" as Design

Button {
    id: root
    property bool accent: false
    property bool destructive: false

    implicitHeight: Design.Theme.controlHeight
    font.pixelSize: Design.Theme.typeLabel
    font.weight: Font.DemiBold
    leftPadding: Design.Theme.space16
    rightPadding: Design.Theme.space16
    Accessible.name: text

    contentItem: Label {
        text: root.text
        color: root.destructive ? Design.Theme.errorForeground
                                : (root.accent ? Design.Theme.primaryForeground : Design.Theme.surfaceText)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font: root.font
    }

    background: Rectangle {
        radius: Design.Theme.radiusSmall
        color: root.destructive ? (root.down ? Design.Theme.errorPressed : Design.Theme.error)
                                : (root.accent ? (root.down ? Design.Theme.primaryPressed : Design.Theme.primary)
                                               : (root.down ? Design.Theme.surfacePressed : Design.Theme.surfaceElevated))
        border.width: root.activeFocus || (!root.accent && !root.destructive) ? 1 : 0
        border.color: root.activeFocus
                      ? (root.accent || root.destructive
                         ? Design.Theme.surfaceText : Design.Theme.primary)
                      : Design.Theme.outline
    }
}
