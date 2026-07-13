import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppDialog {
    id: root

    property var conflict: ({})
    signal continueRequested()
    signal switchRequested(bool discardCurrent)

    objectName: "workoutStartConflictDialog"
    title: qsTr("已有训练正在进行")
    primaryText: qsTr("继续当前训练")
    secondaryText: qsTr("取消")
    autoAccept: false
    onPrimaryRequested: root.continueRequested()

    contentItem: ColumnLayout {
        spacing: Design.Theme.space12

        Label {
            Layout.fillWidth: true
            text: qsTr("当前：%1").arg(root.conflict.currentSessionName || qsTr("未命名训练"))
            color: Design.Theme.surfaceText
            font.pixelSize: Design.Theme.typeBody
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            Accessible.name: text
        }

        Label {
            Layout.fillWidth: true
            text: qsTr("准备开始：%1").arg(root.conflict.requestedName || qsTr("新训练"))
            color: Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeLabel
            wrapMode: Text.WordWrap
            Accessible.name: text
        }

        AppButton {
            Layout.fillWidth: true
            text: qsTr("保存并结束当前，再开始")
            variant: "secondary"
            onClicked: root.switchRequested(false)
        }

        AppButton {
            Layout.fillWidth: true
            text: qsTr("放弃当前训练，再开始")
            variant: "destructive"
            onClicked: discardConfirm.open()
        }

        ConfirmDialog {
            id: discardConfirm
            objectName: "discardCurrentWorkoutConfirmDialog"
            title: qsTr("放弃当前训练？")
            message: qsTr("当前训练及已记录内容会被删除，此操作无法撤销。")
            confirmText: qsTr("放弃并开始新训练")
            destructive: true
            onAccepted: root.switchRequested(true)
        }
    }
}
