import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppDialog {
    id: root

    property var sessions: []
    property string selectedSessionId: ""
    signal recoveryRequested(string keepSessionId, bool discardOthers)

    objectName: "workoutRecoveryDialog"
    title: qsTr("恢复未完成训练")
    primaryText: qsTr("保存其他记录并继续所选")
    secondaryText: qsTr("取消")
    primaryEnabled: selectedSessionId.length > 0
    autoAccept: false
    onPrimaryRequested: root.recoveryRequested(root.selectedSessionId, false)
    onClosed: selectedSessionId = ""

    function startedText(value) {
        const date = new Date(value)
        return isNaN(date.getTime()) ? qsTr("时间未知")
                                      : Qt.formatDateTime(date, qsTr("M月d日 HH:mm"))
    }

    contentItem: ScrollView {
        id: recoveryScroll
        implicitHeight: Math.min(360, recoveryContent.implicitHeight)
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: recoveryContent
            width: recoveryScroll.availableWidth
            spacing: Design.Theme.space12

            Label {
                Layout.fillWidth: true
                text: qsTr("检测到多条进行中的训练。请选择一条继续；默认会保留其他训练，并将其保存为已结束。")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
                wrapMode: Text.WordWrap
                Accessible.name: text
            }

            Repeater {
                model: root.sessions
                delegate: AppButton {
                    id: sessionChoice
                    required property var modelData
                    Layout.fillWidth: true
                    text: (root.selectedSessionId === modelData.id ? qsTr("已选择 · ") : "")
                          + modelData.name
                    variant: root.selectedSessionId === modelData.id ? "primary" : "secondary"
                    Accessible.description: qsTr("开始于 %1，%2 个动作，已完成 %3 组")
                                            .arg(root.startedText(modelData.startedAt))
                                            .arg(modelData.exerciseCount)
                                            .arg(modelData.completedSetCount)
                    onClicked: root.selectedSessionId = modelData.id
                }
            }

            Label {
                Layout.fillWidth: true
                visible: root.selectedSessionId.length > 0
                text: {
                    for (let i = 0; i < root.sessions.length; ++i) {
                        if (root.sessions[i].id === root.selectedSessionId)
                            return qsTr("将继续：%1").arg(root.sessions[i].name)
                    }
                    return ""
                }
                color: Design.Theme.primaryContainerText
                font.pixelSize: Design.Theme.typeLabel
                wrapMode: Text.WordWrap
                Accessible.name: text
            }

            AppButton {
                Layout.fillWidth: true
                enabled: root.selectedSessionId.length > 0
                text: qsTr("删除其他记录并继续所选")
                variant: "destructive"
                onClicked: discardOthersConfirm.open()
            }

            ConfirmDialog {
                id: discardOthersConfirm
                objectName: "discardOtherWorkoutsConfirmDialog"
                title: qsTr("删除其他训练记录？")
                message: qsTr("除所选训练外，其他进行中训练及其组记录都会被永久删除。")
                confirmText: qsTr("删除并继续")
                destructive: true
                onAccepted: root.recoveryRequested(root.selectedSessionId, true)
            }
        }
    }
}
