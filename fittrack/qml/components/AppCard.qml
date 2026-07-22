import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../theme" as Design

Frame {
    id: root
    // Filled cards group dense content. Outlined and elevated cards are opt-in
    // so hierarchy comes from structure rather than repeated decoration.
    property string variant: "filled"
    property int elevation: variant === "elevated" ? 1 : 0
    padding: Design.Theme.space16
    implicitWidth: Math.max(Design.Theme.touchTarget, maxChildImplicitWidth() + leftPadding + rightPadding)
    implicitHeight: Math.max(Design.Theme.touchTarget, maxChildImplicitHeight() + topPadding + bottomPadding)

    function maxChildImplicitWidth() {
        let value = 0
        for (let i = 0; i < contentItem.children.length; ++i)
            value = Math.max(value, contentItem.children[i].implicitWidth || 0)
        return value
    }

    function maxChildImplicitHeight() {
        let value = 0
        for (let i = 0; i < contentItem.children.length; ++i)
            value = Math.max(value, contentItem.children[i].implicitHeight || 0)
        return value
    }

    background: Item {
        readonly property bool elevated: root.variant === "elevated"
        readonly property bool outlined: root.variant === "outlined"
        readonly property bool tonal: root.variant === "tonal"
        RectangularShadow {
            anchors.fill: surface
            visible: root.elevation > 0
            offset: Qt.vector2d(0, root.elevation > 1
                                   ? Design.Theme.elevation2Offset
                                   : Design.Theme.elevation1Offset)
            color: root.elevation > 1
                   ? Design.Theme.elevation2Shadow : Design.Theme.elevation1Shadow
            blur: root.elevation > 1
                  ? Design.Theme.elevation2Blur : Design.Theme.elevation1Blur
            radius: surface.radius
            spread: 0
            cached: true
        }

        Rectangle {
            id: surface
            anchors.fill: parent
            color: parent.tonal ? Design.Theme.primaryContainer
                                : (parent.elevated
                                   ? (root.elevation > 1
                                      ? Design.Theme.surfaceContainerHigh
                                      : Design.Theme.surfaceContainerLow)
                                   : (parent.outlined ? Design.Theme.surface
                                                      : Design.Theme.surfaceContainer))
            radius: Design.Theme.radiusCard
            border.width: parent.outlined ? 1 : 0
            border.color: Design.Theme.outlineVariant
        }
    }
}
