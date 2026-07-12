import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    implicitWidth: 0
    signal trainingRequested()

    Dialog {
        id: textDialog
        property string mode: "createPlan"
        property string targetId: ""
        anchors.centerIn: parent
        width: Math.min(page.width - 28, 420)
        title: mode === "createPlan" ? qsTr("新建计划")
             : mode === "renamePlan" ? qsTr("重命名计划")
             : mode === "addDay" ? qsTr("添加训练日") : qsTr("重命名训练日")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            if (mode === "createPlan") planManagement.createPlan(valueInput.text)
            else if (mode === "renamePlan") planManagement.renamePlan(targetId, valueInput.text)
            else if (mode === "addDay") planManagement.addDay(targetId, valueInput.text)
            else planManagement.renameDay(targetId, valueInput.text)
        }
        TextField { id: valueInput; anchors.fill: parent; placeholderText: qsTr("请输入名称") }
    }

    Dialog {
        id: deleteDialog
        property string kind: "plan"
        property string targetId: ""
        anchors.centerIn: parent
        title: qsTr("确认删除")
        standardButtons: Dialog.Yes | Dialog.No
        Label { text: deleteDialog.kind === "plan" ? qsTr("删除该计划及全部训练日？") : qsTr("删除该训练日？") }
        onAccepted: deleteDialog.kind === "plan"
                    ? planManagement.deletePlan(targetId) : planManagement.deleteDay(targetId)
    }

    Dialog {
        id: actionPicker
        property string dayId: ""
        anchors.centerIn: parent
        width: Math.min(page.width - 20, 520)
        height: Math.min(page.height - 40, 700)
        title: qsTr("添加动作")
        standardButtons: Dialog.Close
        onClosed: planExerciseModel.searchText = ""
        ColumnLayout {
            anchors.fill: parent
            TextField {
                Layout.fillWidth: true
                placeholderText: qsTr("搜索动作")
                onTextChanged: planExerciseModel.searchText = text
            }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: planExerciseModel
                clip: true
                delegate: ItemDelegate {
                    required property string exerciseId
                    required property string name
                    required property string bodyPart
                    width: ListView.view.width
                    text: name + " · " + bodyPart
                    onClicked: {
                        planManagement.addExercise(actionPicker.dayId, exerciseId)
                        actionPicker.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: actionEditor
        property string planExerciseId: ""
        anchors.centerIn: parent
        width: Math.min(page.width - 28, 420)
        title: qsTr("调整动作参数")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: planManagement.updateExercise(
            planExerciseId, editSets.value, editReps.text, editRest.value)
        ColumnLayout {
            anchors.fill: parent
            RowLayout {
                Label { text: qsTr("组数") }
                SpinBox { id: editSets; from: 1; to: 20 }
            }
            TextField { id: editReps; Layout.fillWidth: true; placeholderText: qsTr("次数或范围") }
            RowLayout {
                Label { text: qsTr("间歇秒数") }
                SpinBox { id: editRest; from: 0; to: 600; editable: true }
            }
        }
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            Label { text: qsTr("训练计划"); font.pixelSize: 18; font.bold: true; Layout.fillWidth: true }
            Button {
                text: qsTr("新建")
                onClicked: {
                    textDialog.mode = "createPlan"
                    textDialog.targetId = ""
                    valueInput.text = ""
                    textDialog.open()
                }
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            width: page.width
            spacing: 12
            Item { Layout.preferredHeight: 2 }

            Label {
                Layout.leftMargin: 16
                text: qsTr("系统模板与个人计划")
                color: "#AEB7B1"
            }
            Repeater {
                model: planManagement.plans
                delegate: ItemDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    text: (modelData.isSystem ? qsTr("系统 · ") : qsTr("个人 · ")) + modelData.name
                          + "\n" + qsTr("%1 个训练日 · %2 个动作")
                              .arg(modelData.dayCount).arg(modelData.exerciseCount)
                    highlighted: planManagement.selectedPlan.id === modelData.id
                    onClicked: planManagement.selectPlan(modelData.id)
                }
            }

            Frame {
                visible: planManagement.selectedPlan.id !== undefined
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                padding: 16
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: planManagement.selectedPlan.name || ""
                            font.pixelSize: 21
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Label {
                            text: planManagement.selectedPlan.isSystem ? qsTr("只读原版") : qsTr("个人计划")
                            color: "#8BD450"
                        }
                    }
                    RowLayout {
                        visible: !planManagement.selectedPlan.isReadOnly
                        Button {
                            text: qsTr("重命名")
                            onClicked: {
                                textDialog.mode = "renamePlan"
                                textDialog.targetId = planManagement.selectedPlan.id
                                valueInput.text = planManagement.selectedPlan.name
                                textDialog.open()
                            }
                        }
                        Button {
                            text: qsTr("添加训练日")
                            onClicked: {
                                textDialog.mode = "addDay"
                                textDialog.targetId = planManagement.selectedPlan.id
                                valueInput.text = ""
                                textDialog.open()
                            }
                        }
                        Button {
                            text: qsTr("删除计划")
                            onClicked: {
                                deleteDialog.kind = "plan"
                                deleteDialog.targetId = planManagement.selectedPlan.id
                                deleteDialog.open()
                            }
                        }
                    }

                    Repeater {
                        model: planManagement.selectedPlan.days || []
                        delegate: Frame {
                            id: dayCard
                            required property var modelData
                            Layout.fillWidth: true
                            padding: 12
                            ColumnLayout {
                                anchors.fill: parent
                                RowLayout {
                                    Layout.fillWidth: true
                                    Label {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: modelData.name
                                        font.bold: true
                                        font.pixelSize: 17
                                        elide: Text.ElideRight
                                    }
                                    Button {
                                        text: qsTr("开始")
                                        onClicked: {
                                            if (workoutController.startPlanDay(modelData.id)) page.trainingRequested()
                                        }
                                    }
                                    ToolButton {
                                        visible: !planManagement.selectedPlan.isReadOnly
                                        text: qsTr("+动作")
                                        onClicked: {
                                            actionPicker.dayId = modelData.id
                                            actionPicker.open()
                                        }
                                    }
                                    ToolButton {
                                        visible: !planManagement.selectedPlan.isReadOnly
                                        text: qsTr("改名")
                                        onClicked: {
                                            textDialog.mode = "renameDay"
                                            textDialog.targetId = modelData.id
                                            valueInput.text = modelData.name
                                            textDialog.open()
                                        }
                                    }
                                    ToolButton {
                                        visible: !planManagement.selectedPlan.isReadOnly
                                        text: qsTr("删除")
                                        onClicked: {
                                            deleteDialog.kind = "day"
                                            deleteDialog.targetId = modelData.id
                                            deleteDialog.open()
                                        }
                                    }
                                }
                                Label {
                                    visible: modelData.exercises.length === 0
                                    text: qsTr("空训练日：从自由训练保存含动作的模板")
                                    color: "#7E8982"
                                }
                                Repeater {
                                    model: modelData.exercises
                                    delegate: RowLayout {
                                        required property var modelData
                                        required property int index
                                        Layout.fillWidth: true
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.name + "　" + modelData.sets + qsTr("组 · ")
                                                  + modelData.reps + qsTr(" · 休息%1秒").arg(modelData.restSeconds)
                                            color: "#C7CFCA"
                                            wrapMode: Text.WordWrap
                                        }
                                        ToolButton {
                                            visible: !planManagement.selectedPlan.isReadOnly
                                            text: "↑"
                                            enabled: index > 0
                                            onClicked: planManagement.moveExercise(dayCard.modelData.id, index, index - 1)
                                        }
                                        ToolButton {
                                            visible: !planManagement.selectedPlan.isReadOnly
                                            text: "↓"
                                            enabled: index + 1 < dayCard.modelData.exercises.length
                                            onClicked: planManagement.moveExercise(dayCard.modelData.id, index, index + 1)
                                        }
                                        ToolButton {
                                            visible: !planManagement.selectedPlan.isReadOnly
                                            text: qsTr("编辑")
                                            onClicked: {
                                                actionEditor.planExerciseId = modelData.id
                                                editSets.value = modelData.sets
                                                editReps.text = modelData.reps
                                                editRest.value = modelData.restSeconds
                                                actionEditor.open()
                                            }
                                        }
                                        ToolButton {
                                            visible: !planManagement.selectedPlan.isReadOnly
                                            text: qsTr("删除")
                                            onClicked: planManagement.removeExercise(modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Label {
                visible: planManagement.errorMessage.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: planManagement.errorMessage
                color: "#FF8A80"
                wrapMode: Text.WordWrap
            }
            Item { Layout.preferredHeight: 20 }
        }
    }
}
