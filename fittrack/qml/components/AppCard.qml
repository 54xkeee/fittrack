import QtQuick
import QtQuick.Controls
import "../theme" as Design

Frame {
    id: root
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

    background: Rectangle {
        color: Design.Theme.surface
        radius: Design.Theme.radiusCard
        border.width: 1
        border.color: Design.Theme.borderDefault
    }
}
