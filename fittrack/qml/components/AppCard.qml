import QtQuick
import QtQuick.Controls

Frame {
    id: root
    padding: 14
    implicitWidth: Math.max(48, maxChildImplicitWidth() + leftPadding + rightPadding)
    implicitHeight: Math.max(48, maxChildImplicitHeight() + topPadding + bottomPadding)

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
        color: "#1A1A1A"
        radius: 8
        border.width: 1
        border.color: "#2B2D2D"
    }
}
