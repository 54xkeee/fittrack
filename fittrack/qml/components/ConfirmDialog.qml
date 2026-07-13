import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Dialog {
    id: root

    property string message: ""
    property string confirmText: qsTr("确认")
    property string cancelText: qsTr("取消")
    property bool destructive: false

    parent: Overlay.overlay
    anchors.centerIn: Overlay.overlay
    width: Math.min(360, Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 * 2 : 360)
    modal: true
    focus: true
    padding: Design.Theme.space24
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    Overlay.modal: Rectangle {
        color: Design.Theme.scrim
    }

    background: Rectangle {
        color: Design.Theme.surface
        radius: Design.Theme.radiusLarge
        border.width: 1
        border.color: Design.Theme.outline
    }

    header: Label {
        text: root.title
        color: Design.Theme.surfaceText
        font.pixelSize: Design.Theme.typeTitle
        font.weight: Font.DemiBold
        leftPadding: Design.Theme.space24
        rightPadding: Design.Theme.space24
        topPadding: Design.Theme.space24
        wrapMode: Text.WordWrap
    }

    contentItem: Label {
        text: root.message
        color: Design.Theme.surfaceMuted
        font.pixelSize: Design.Theme.typeBody
        lineHeight: 1.4
        wrapMode: Text.WordWrap
        Accessible.name: root.title + ". " + root.message
    }

    footer: Item {
        implicitHeight: Design.Theme.controlHeight + Design.Theme.space24

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Design.Theme.space24
            anchors.rightMargin: Design.Theme.space24
            anchors.bottomMargin: Design.Theme.space24
            spacing: Design.Theme.space8

            AppButton {
                id: cancelButton
                text: root.cancelText
                variant: "secondary"
                Layout.fillWidth: true
                onClicked: root.reject()
            }

            AppButton {
                text: root.confirmText
                variant: root.destructive ? "destructive" : "primary"
                Layout.fillWidth: true
                onClicked: root.accept()
            }
        }
    }

    onOpened: cancelButton.forceActiveFocus()
}

