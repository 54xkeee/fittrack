import QtQuick
import QtQuick.Controls
import "../theme" as Design

Frame {
    id: root
    // Filled cards group dense content. Outlined and elevated cards are opt-in
    // so hierarchy comes from structure rather than repeated decoration.
    property string variant: "filled"
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
        Rectangle {
            x: 0
            y: Design.Theme.shadowOffsetY
            width: parent.width
            height: parent.height
            radius: Design.Theme.radiusCard
            color: parent.elevated ? Design.Theme.shadowAmbient : "transparent"
        }

        Rectangle {
            anchors.fill: parent
            color: parent.tonal ? Design.Theme.primaryContainer
                                : (parent.outlined ? Design.Theme.surface
                                                   : Design.Theme.surfaceContainer)
            radius: Design.Theme.radiusCard
            border.width: parent.outlined ? 1 : 0
            border.color: Design.Theme.outlineVariant
        }
    }
}
