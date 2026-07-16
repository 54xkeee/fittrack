import QtQuick
import QtQuick.Controls
import "../theme" as Design

Switch {
    id: root

    implicitWidth: 52
    implicitHeight: Design.Theme.touchTarget

    indicator: Rectangle {
        x: root.leftPadding
        y: (root.height - height) / 2
        width: 48
        height: 28
        radius: 14
        color: root.checked ? Design.Theme.primary : Design.Theme.borderDefault
        border.width: root.activeFocus ? 2 : 0
        border.color: Design.Theme.primary

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            radius: 11
            color: Design.Theme.surfacePrimary
            border.width: 1
            border.color: Design.Theme.borderSubtle

            Behavior on x {
                NumberAnimation {
                    duration: Design.Theme.motionFast
                    easing.type: Design.Theme.easingEnter
                }
            }
        }
    }
}
