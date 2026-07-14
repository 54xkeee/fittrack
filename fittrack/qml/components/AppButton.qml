import QtQuick
import QtQuick.Controls
import "../theme" as Design

Button {
    id: root

    // Supported variants: primary, secondary and destructive.
    property string variant: "primary"
    property bool flatSecondary: false
    property int cornerRadius: Design.Theme.radiusSmall
    property color primaryColor: Design.Theme.primary
    property color primaryPressedColor: Design.Theme.primaryPressed
    property color primaryTextColor: Design.Theme.primaryForeground

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
                return root.primaryTextColor
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
        radius: root.cornerRadius
        color: {
            if (!root.enabled)
                return Design.Theme.surfaceElevated
            if (root.isPrimary)
                return root.down ? root.primaryPressedColor : root.primaryColor
            if (root.isDestructive)
                return root.down ? Design.Theme.errorPressed : Design.Theme.error
            return root.down ? Design.Theme.surfacePressed : Design.Theme.surfaceElevated
        }
        border.width: root.activeFocus
                      || (!root.isPrimary && !root.isDestructive && !root.flatSecondary) ? 1 : 0
        border.color: root.activeFocus
                      ? (root.isPrimary || root.isDestructive
                         ? Design.Theme.surfaceText : Design.Theme.primary)
                      : Design.Theme.outline
        opacity: root.enabled ? 1 : Design.Theme.disabledOpacity

        Behavior on color {
            ColorAnimation { duration: Design.Theme.motionFast }
        }
    }
}
