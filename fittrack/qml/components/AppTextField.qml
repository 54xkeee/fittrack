import QtQuick
import QtQuick.Controls
import "../theme" as Design

TextField {
    id: root

    implicitHeight: Design.Theme.controlHeight
    color: Design.Theme.onSurface
    placeholderTextColor: Design.Theme.onSurfaceVariant
    font.pixelSize: Design.Typography.body
    leftPadding: Design.Theme.space12
    rightPadding: Design.Theme.space12
    selectByMouse: true

    background: Rectangle {
        radius: Design.Theme.radiusInput
        color: Design.Theme.surfaceContainerLowest
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? Design.Theme.primary : Design.Theme.outline
    }
}
