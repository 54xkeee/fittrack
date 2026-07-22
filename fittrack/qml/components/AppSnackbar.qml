import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Popup {
    id: root

    property string message: ""
    property string actionText: ""
    property int duration: 4000
    signal actionTriggered()

    parent: Overlay.overlay
    modal: false
    focus: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    width: Math.min(560, (Overlay.overlay ? Overlay.overlay.width : 560) - Design.Theme.space16 * 2)
    x: Overlay.overlay ? (Overlay.overlay.width - width) / 2 : 0
    y: Overlay.overlay ? Overlay.overlay.height - height - Design.Theme.space16 - SafeArea.margins.bottom : 0
    padding: 0

    implicitHeight: snackbarRow.implicitHeight + Design.Theme.space8 * 2
    height: implicitHeight

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Design.Theme.motionFast }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; to: 0; duration: Design.Theme.motionFast }
    }

    background: Rectangle {
        color: Design.Theme.onSurface
        radius: Design.Theme.radiusMedium
        Accessible.role: Accessible.AlertMessage
        Accessible.name: root.message
    }

    contentItem: RowLayout {
        id: snackbarRow
        spacing: Design.Theme.space8

        Label {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.message
            color: Design.Theme.surfaceContainerLowest
            font.pixelSize: Design.Typography.bodyCompact
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }

        Button {
            id: actionButton
            visible: root.actionText.length > 0
            text: root.actionText
            font.pixelSize: Design.Typography.label
            font.weight: Font.DemiBold
            padding: Design.Theme.space8
            Accessible.name: text
            onClicked: root.actionTriggered()

            contentItem: Label {
                text: actionButton.text
                color: Design.Theme.primaryContainer
                font: actionButton.font
            }
            background: Rectangle {
                radius: Design.Theme.radiusPill
                color: actionButton.down ? Design.Theme.onSurfaceVariant : "transparent"
            }
        }

        IconButton {
            iconName: "close"
            accessibleName: qsTr("关闭提示")
            onClicked: root.close()
        }
    }

    Timer {
        id: dismissTimer
        interval: root.duration
        repeat: false
        onTriggered: root.close()
    }

    onOpened: {
        if (duration > 0)
            dismissTimer.restart()
        Qt.callLater(function() {
            root.Accessible.announce(root.message, Accessible.Polite)
        })
    }
    onClosed: dismissTimer.stop()
}
