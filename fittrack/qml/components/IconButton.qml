import QtQuick
import QtQuick.Controls
import "../theme" as Design

Button {
    id: root

    property string iconName: ""
    property string accessibleName: ""
    property bool destructive: false
    property bool selected: false

    implicitWidth: Design.Theme.touchTarget
    implicitHeight: Design.Theme.touchTarget
    padding: Design.Theme.space12

    Accessible.name: accessibleName

    contentItem: Item {
        implicitWidth: 24
        implicitHeight: 24

        AppIcon {
            anchors.centerIn: parent
            name: root.iconName
            color: root.destructive ? Design.Theme.error :
                   (root.selected ? Design.Theme.primaryForeground : Design.Theme.surfaceText)
        }
    }

    background: Rectangle {
        radius: Design.Theme.radiusSmall
        color: root.selected ? Design.Theme.primary :
               (root.down ? Design.Theme.surfacePressed : "transparent")
        border.width: root.activeFocus ? 1 : 0
        border.color: Design.Theme.primary
        opacity: root.enabled ? 1 : Design.Theme.disabledOpacity

        Behavior on color {
            ColorAnimation { duration: Design.Theme.motionFast }
        }
    }
}
