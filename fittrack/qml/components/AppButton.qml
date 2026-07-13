import QtQuick
import QtQuick.Controls
import "../theme" as Design

Button {
    id: root

    // Supported variants: primary, secondary and destructive.
    property string variant: "primary"

    readonly property bool isPrimary: variant === "primary"
    readonly property bool isDestructive: variant === "destructive"

    implicitWidth: Math.max(96, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Design.Theme.controlHeight
    leftPadding: Design.Theme.space16
    rightPadding: Design.Theme.space16
    spacing: Design.Theme.space8
    font.pixelSize: Design.Theme.typeLabel
    font.weight: Font.DemiBold

    Accessible.name: text

    contentItem: Label {
        text: root.text
        color: {
            if (!root.enabled)
                return Design.Theme.surfaceMuted
            if (root.isPrimary)
                return Design.Theme.primaryForeground
            if (root.isDestructive)
                return Design.Theme.errorForeground
            return Design.Theme.surfaceText
        }
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: Design.Theme.radiusSmall
        color: {
            if (!root.enabled)
                return Design.Theme.surfaceElevated
            if (root.isPrimary)
                return root.down ? Design.Theme.primaryPressed : Design.Theme.primary
            if (root.isDestructive)
                return root.down ? Design.Theme.errorPressed : Design.Theme.error
            return root.down ? Design.Theme.surfacePressed : Design.Theme.surfaceElevated
        }
        border.width: root.activeFocus || (!root.isPrimary && !root.isDestructive) ? 1 : 0
        border.color: root.activeFocus ? Design.Theme.primary : Design.Theme.outline
        opacity: root.enabled ? 1 : Design.Theme.disabledOpacity

        Behavior on color {
            ColorAnimation { duration: Design.Theme.motionFast }
        }
    }
}

