import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppDialog {
    id: root

    property var exercise: ({})
    signal saveRequested(string draftExerciseId, int sets, string reps, int restSeconds)
    signal restoreRequested(string draftExerciseId)

    function syncExercise(data) {
        exercise = data || ({})
        setsInput.value = Number(exercise.sets || 1)
        repsInput.text = String(exercise.reps || "")
        restInput.value = Number(exercise.restSeconds || 0)
    }

    function openExercise(data) {
        syncExercise(data)
        open()
    }

    objectName: "exerciseParameterSheet"
    title: qsTr("调整训练组 · %1").arg(exercise.name || "")
    primaryText: qsTr("保存")
    secondaryText: qsTr("取消")
    primaryEnabled: repsInput.text.trim().length > 0
    autoAccept: false
    onPrimaryRequested: root.saveRequested(
                            String(exercise.draftId || exercise.id || ""),
                            setsInput.value, repsInput.text.trim(), restInput.value)

    contentItem: ColumnLayout {
        spacing: Design.Theme.space12

        Label { text: qsTr("正式组数"); color: Design.Theme.surfaceMuted }
        SpinBox {
            id: setsInput
            objectName: "parameterSetsInput"
            from: 1
            to: 20
            editable: true
            Layout.fillWidth: true
            implicitHeight: Design.Theme.controlHeight
            Accessible.name: qsTr("正式组数")
        }
        Label { text: qsTr("目标次数、范围或逐组序列"); color: Design.Theme.surfaceMuted }
        TextField {
            id: repsInput
            objectName: "parameterRepsInput"
            Layout.fillWidth: true
            implicitHeight: Design.Theme.controlHeight
            placeholderText: qsTr("例如 8-12 或 12,10,8")
            Accessible.name: qsTr("目标次数")
        }
        Label { text: qsTr("组间休息（秒）"); color: Design.Theme.surfaceMuted }
        SpinBox {
            id: restInput
            objectName: "parameterRestInput"
            from: 0
            to: 600
            stepSize: 15
            editable: true
            Layout.fillWidth: true
            implicitHeight: Design.Theme.controlHeight
            Accessible.name: qsTr("组间休息秒数")
        }
        AppButton {
            Layout.fillWidth: true
            text: qsTr("恢复进入准备时的默认值")
            variant: "secondary"
            enabled: Boolean(root.exercise.modified)
            onClicked: root.restoreRequested(String(root.exercise.draftId || root.exercise.id || ""))
        }
    }
}
