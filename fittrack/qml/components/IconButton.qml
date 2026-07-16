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
    scale: down && enabled ? 0.94 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Design.Theme.motionFast
            easing.type: Design.Theme.easingEnter
        }
    }

    Accessible.name: accessibleName

    contentItem: Item {
        implicitWidth: 24
        implicitHeight: 24

        AppIcon {
            anchors.centerIn: parent
            name: root.iconName
            color: root.destructive ? Design.Theme.error :
                   (root.selected ? Design.Theme.primary : Design.Theme.textSecondary)
        }
    }

    background: Rectangle {
        radius: Design.Theme.radiusInput
        color: root.selected ? Design.Theme.primarySoft :
               (root.down ? Design.Theme.surfacePressed : "transparent")
        border.width: root.activeFocus ? 1 : 0
        border.color: Design.Theme.primary
        opacity: root.enabled ? 1 : Design.Theme.disabledOpacity

        Behavior on color {
            ColorAnimation { duration: Design.Theme.motionFast }
        }
    }
}
