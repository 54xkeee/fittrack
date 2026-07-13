import QtQuick
import QtQuick.Controls
import "../theme" as Design

Button {
    id: root

    property url source
    property string glyph: ""
    property string accessibleName: ""
    property bool destructive: false
    property bool selected: false

    implicitWidth: Design.Theme.touchTarget
    implicitHeight: Design.Theme.touchTarget
    padding: Design.Theme.space12

    Accessible.name: accessibleName.length > 0 ? accessibleName : glyph

    contentItem: Item {
        implicitWidth: 24
        implicitHeight: 24

        Image {
            anchors.centerIn: parent
            width: 24
            height: 24
            visible: String(root.source).length > 0
            source: root.source
            sourceSize.width: 24
            sourceSize.height: 24
            fillMode: Image.PreserveAspectFit
        }

        Label {
            anchors.centerIn: parent
            visible: String(root.source).length === 0
            text: root.glyph
            color: root.destructive ? Design.Theme.error :
                   (root.selected ? Design.Theme.primaryForeground : Design.Theme.surfaceText)
            font.pixelSize: Design.Theme.typeTitle
            font.weight: Font.DemiBold
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

