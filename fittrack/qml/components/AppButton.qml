import QtQuick
import QtQuick.Controls
import "../theme" as Design

Button {
    id: root

    // Material variants: primary, tonal, secondary (outlined), text and destructive.
    property string variant: "primary"
    property bool flatSecondary: false
    property int cornerRadius: Design.Theme.radiusButton
    property color primaryColor: Design.Theme.primary
    property color primaryPressedColor: Design.Theme.primaryPressed
    property color primaryTextColor: Design.Theme.primaryForeground

    readonly property bool isPrimary: variant === "primary"
    readonly property bool isDestructive: variant === "destructive"
    readonly property bool isTonal: variant === "tonal"
    readonly property bool isText: variant === "text"

    implicitWidth: Math.max(96, contentItem.implicitWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(Design.Theme.heightPrimary, Design.Theme.controlHeight)
    leftPadding: Design.Theme.space16
    rightPadding: Design.Theme.space16
    spacing: Design.Theme.space8
    font.pixelSize: Design.Theme.typeLabel
    font.weight: Font.DemiBold
    scale: down && enabled ? 0.97 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Design.Theme.motionFast
            easing.type: Design.Theme.easingEnter
        }
    }

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
            if (root.isTonal)
                return Design.Theme.onSecondaryContainer
            if (root.isText)
                return Design.Theme.primary
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
                return root.down ? root.primaryPressedColor
                                 : (root.hovered ? Design.Theme.primaryHover : root.primaryColor)
            if (root.isDestructive)
                return root.down ? Design.Theme.errorPressed : Design.Theme.error
            if (root.isTonal)
                return Design.Theme.secondaryContainer
            if (root.isText)
                return root.down ? Design.Theme.primarySoft : "transparent"
            return root.down ? Design.Theme.surfacePressed : "transparent"
        }
        border.width: root.activeFocus
                      || (!root.isPrimary && !root.isDestructive && !root.isTonal
                          && !root.isText && !root.flatSecondary) ? 1 : 0
        border.color: root.activeFocus
                      ? (root.isPrimary || root.isDestructive
                         ? Design.Theme.primaryForeground : Design.Theme.primary)
                      : Design.Theme.outline
        opacity: root.enabled ? 1 : Design.Theme.disabledOpacity

        Behavior on color {
            ColorAnimation { duration: Design.Theme.motionFast }
        }
    }
}
