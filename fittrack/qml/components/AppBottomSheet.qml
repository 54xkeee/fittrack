import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Popup {
    id: root

    property string title: ""
    property string supportingText: ""
    property bool showDragHandle: true
    default property alias sheetContent: body.data

    parent: Overlay.overlay
    modal: true
    focus: true
    width: Math.min(640, Overlay.overlay ? Overlay.overlay.width : 640)
    x: Overlay.overlay ? (Overlay.overlay.width - width) / 2 : 0
    y: Overlay.overlay ? Overlay.overlay.height - height : 0
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    implicitHeight: Math.min(Overlay.overlay
                             ? Overlay.overlay.height - SafeArea.margins.top - Design.Theme.space16
                             : sheetColumn.implicitHeight,
                             sheetColumn.implicitHeight)
    height: implicitHeight

    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "y"; from: Overlay.overlay ? Overlay.overlay.height : 0; duration: Design.Theme.motionStandard; easing.type: Design.Theme.easingEnter }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Design.Theme.motionFast }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "y"; to: Overlay.overlay ? Overlay.overlay.height : 0; duration: Design.Theme.motionFast; easing.type: Design.Theme.easingExit }
            NumberAnimation { property: "opacity"; to: 0; duration: Design.Theme.motionFast }
        }
    }
    Overlay.modal: Rectangle { color: Design.Theme.scrim }

    background: Rectangle {
        color: Design.Theme.surfaceContainerLowest
        radius: Design.Theme.radiusLarge
        topLeftRadius: Design.Theme.radiusLarge
        topRightRadius: Design.Theme.radiusLarge
        Accessible.role: Accessible.Dialog
        Accessible.name: root.title
    }

    contentItem: ColumnLayout {
        id: sheetColumn
        width: root.width
        spacing: 0

        Rectangle {
            visible: root.showDragHandle
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Design.Theme.space12
            Layout.bottomMargin: Design.Theme.space8
            implicitWidth: 32
            implicitHeight: 4
            radius: Design.Theme.radiusPill
            color: Design.Theme.outlineVariant
            Accessible.ignored: true
        }

        ColumnLayout {
            visible: root.title.length > 0 || root.supportingText.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Design.Theme.space24
            Layout.rightMargin: Design.Theme.space24
            Layout.bottomMargin: Design.Theme.space16
            spacing: Design.Theme.space4

            Label {
                visible: root.title.length > 0
                Layout.fillWidth: true
                text: root.title
                color: Design.Theme.onSurface
                font.pixelSize: Design.Typography.title
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }

            Label {
                visible: root.supportingText.length > 0
                Layout.fillWidth: true
                text: root.supportingText
                color: Design.Theme.onSurfaceVariant
                font.pixelSize: Design.Typography.bodyCompact
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: body
            Layout.fillWidth: true
            Layout.leftMargin: Design.Theme.space24
            Layout.rightMargin: Design.Theme.space24
            Layout.bottomMargin: Design.Theme.space24 + SafeArea.margins.bottom
            implicitHeight: childrenRect.height
        }
    }
}
