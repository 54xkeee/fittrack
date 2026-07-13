import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

Rectangle {
    id: page

    signal startSucceeded()
    signal cancelled()

    function draftById(draftId) {
        const items = workoutController.preparation.exercises || []
        for (let i = 0; i < items.length; ++i) {
            if (items[i].draftId === draftId)
                return items[i]
        }
        return ({})
    }

    function requestCancel() {
        cancelPreparationConfirm.open()
    }

    function cardioSummary(cardio) {
        if (!cardio || !cardio.type)
            return ""
        if (cardio.type === "TreadmillIncline")
            return qsTr("训练后：跑步机爬坡 %1 分钟 · 坡度 %2 · %3 km/h")
                    .arg(Math.round(Number(cardio.durationSeconds || 0) / 60))
                    .arg(cardio.incline).arg(cardio.speedKmh)
        return qsTr("训练后：爬楼机 %1 分钟%2")
                .arg(Math.round(Number(cardio.durationSeconds || 0) / 60))
                .arg(cardio.machineLevel !== null && cardio.machineLevel !== undefined
                     ? qsTr(" · 等级 %1").arg(cardio.machineLevel) : "")
    }

    objectName: "workoutPreparationPage"
    color: Design.Theme.background

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Design.Theme.space16
        anchors.rightMargin: Design.Theme.space16
        anchors.topMargin: Design.Theme.space8
        anchors.bottomMargin: Design.Theme.space8
        spacing: Design.Theme.space12

        RowLayout {
            Layout.fillWidth: true
            IconButton {
                glyph: "‹"
                accessibleName: qsTr("取消训练准备")
                onClicked: page.requestCancel()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space4
                Label {
                    Layout.fillWidth: true
                    text: workoutController.preparation.name || qsTr("训练准备")
                    color: Design.Theme.backgroundText
                    font.pixelSize: Design.Theme.typeTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("%1 个动作 · 修改只影响本次训练")
                          .arg((workoutController.preparation.exercises || []).length)
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeCaption
                    elide: Text.ElideRight
                }
            }
            AppButton {
                text: qsTr("保存计划")
                variant: "secondary"
                enabled: (workoutController.preparation.exercises || []).length > 0
                onClicked: {
                    savedPlanName.text = (workoutController.preparation.sourcePlanName || "")
                            + qsTr(" 个人版")
                    savedDayName.text = workoutController.preparation.name || ""
                    savePreparationDialog.open()
                }
            }
        }

        AppCard {
            Layout.fillWidth: true
            visible: workoutController.gyms.length > 0
            padding: Design.Theme.space12
            RowLayout {
                anchors.fill: parent
                Label {
                    text: qsTr("健身房")
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeLabel
                }
                ComboBox {
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                    model: workoutController.gyms
                    textRole: "name"
                    currentIndex: {
                        for (let i = 0; i < workoutController.gyms.length; ++i) {
                            if (workoutController.gyms[i].id === workoutController.selectedGymId)
                                return i
                        }
                        return -1
                    }
                    displayText: currentIndex >= 0 ? currentText : qsTr("未选择")
                    Accessible.name: qsTr("训练健身房")
                    onActivated: workoutController.selectGym(workoutController.gyms[currentIndex].id)
                }
            }
        }

        InlineFeedback {
            Layout.fillWidth: true
            visible: page.cardioSummary(workoutController.preparation.cardio).length > 0
            tone: "info"
            message: page.cardioSummary(workoutController.preparation.cardio)
        }

        ScrollView {
            id: draftScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: draftScroll.availableWidth
                spacing: Design.Theme.space12

                Repeater {
                    model: workoutController.preparation.exercises || []
                    delegate: AppCard {
                        id: draftCard
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        padding: Design.Theme.space12

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: Design.Theme.space8
                            RowLayout {
                                Layout.fillWidth: true
                                Label {
                                    text: draftCard.index + 1
                                    color: Design.Theme.primary
                                    font.pixelSize: Design.Theme.typeLabel
                                    font.weight: Font.Bold
                                }
                                AppButton {
                                    objectName: "preparedExercisePreviewButton"
                                    Layout.fillWidth: true
                                    text: draftCard.modelData.name
                                    variant: "secondary"
                                    Accessible.description: qsTr("预览动作做法")
                                    onClicked: exerciseDetail.openExercise(
                                                   exerciseModel.exerciseById(
                                                       draftCard.modelData.exerciseId))
                                }
                                Label {
                                    visible: Boolean(draftCard.modelData.modified)
                                    text: qsTr("已修改")
                                    color: Design.Theme.warning
                                    font.pixelSize: Design.Theme.typeCaption
                                }
                            }
                            Label {
                                Layout.fillWidth: true
                                text: qsTr("%1 组 · %2 次 · 休息 %3 秒")
                                      .arg(draftCard.modelData.sets)
                                      .arg(draftCard.modelData.reps)
                                      .arg(draftCard.modelData.restSeconds)
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeLabel
                                wrapMode: Text.WordWrap
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: width < 340 ? 2 : 4
                                columnSpacing: Design.Theme.space8
                                rowSpacing: Design.Theme.space8
                                AppButton {
                                    objectName: "preparedExerciseParametersButton"
                                    Layout.fillWidth: true
                                    text: qsTr("参数")
                                    variant: "secondary"
                                    onClicked: parameterSheet.openExercise(draftCard.modelData)
                                }
                                AppButton {
                                    Layout.fillWidth: true
                                    text: qsTr("上移")
                                    variant: "secondary"
                                    enabled: draftCard.index > 0
                                    onClicked: workoutController.movePreparedExercise(
                                                   draftCard.modelData.draftId, draftCard.index - 1)
                                }
                                AppButton {
                                    Layout.fillWidth: true
                                    text: qsTr("下移")
                                    variant: "secondary"
                                    enabled: draftCard.index + 1
                                             < workoutController.preparation.exercises.length
                                    onClicked: workoutController.movePreparedExercise(
                                                   draftCard.modelData.draftId, draftCard.index + 1)
                                }
                                AppButton {
                                    Layout.fillWidth: true
                                    text: qsTr("替换")
                                    variant: "secondary"
                                    onClicked: {
                                        picker.targetDraftId = draftCard.modelData.draftId
                                        picker.openPicker("replace")
                                    }
                                }
                            }
                        }
                    }
                }

                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("添加动作")
                    variant: "secondary"
                    onClicked: {
                        picker.targetDraftId = ""
                        picker.openPicker("add")
                    }
                }

                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("调整动作顺序")
                    variant: "secondary"
                    enabled: (workoutController.preparation.exercises || []).length > 1
                    onClicked: preparationOrderSheet.openExercises(
                                   workoutController.preparation.exercises,
                                   "draftId", "")
                }

                Label {
                    Layout.fillWidth: true
                    visible: (workoutController.preparation.exercises || []).length === 0
                    text: qsTr("训练准备还是空的，请先添加动作。")
                    color: Design.Theme.surfaceMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        AppButton {
            objectName: "commitPreparationButton"
            Layout.fillWidth: true
            text: qsTr("开始本次训练")
            enabled: (workoutController.preparation.exercises || []).length > 0
            onClicked: {
                if (workoutController.commitPreparation())
                    page.startSucceeded()
                else
                    startError.message = workoutController.errorMessage
            }
        }
        InlineFeedback {
            id: startError
            Layout.fillWidth: true
            visible: message.length > 0
            tone: "error"
            message: ""
        }
    }

    ExerciseDetailSheet {
        id: exerciseDetail
        objectName: "preparationExerciseDetailSheet"
    }

    ExerciseOrderSheet {
        id: preparationOrderSheet
        objectName: "preparationExerciseOrderSheet"
        onSaveRequested: orderedIds => {
            if (workoutController.reorderPreparedExercises(orderedIds))
                close()
            else
                showError(workoutController.errorMessage)
        }
    }

    ExerciseParameterSheet {
        id: parameterSheet
        objectName: "preparationExerciseParameterSheet"
        onSaveRequested: (draftExerciseId, sets, reps, restSeconds) => {
            if (workoutController.updatePreparedExercise(
                        draftExerciseId, sets, reps, restSeconds))
                close()
            else
                showError(workoutController.errorMessage)
        }
        onRestoreRequested: draftExerciseId => {
            if (workoutController.restorePreparedExerciseDefaults(draftExerciseId)) {
                parameterSheet.syncExercise(page.draftById(draftExerciseId))
            } else {
                showError(workoutController.errorMessage)
            }
        }
    }

    ExercisePickerSheet {
        id: picker
        property string targetDraftId: ""
        exerciseModel: planExerciseModel
        onPreviewRequested: exerciseId => exerciseDetail.openExercise(
                                planExerciseModel.exerciseById(exerciseId))
        onExerciseSelected: exerciseId => {
            const succeeded = mode === "replace"
                    ? workoutController.replacePreparedExercise(targetDraftId, exerciseId)
                    : workoutController.addPreparedExercise(exerciseId)
            if (succeeded)
                close()
        }
    }

    AppDialog {
        id: savePreparationDialog
        objectName: "savePreparationDialog"
        title: qsTr("保存到个人计划")
        primaryText: qsTr("保存个人计划")
        primaryEnabled: savedPlanName.text.trim().length > 0
                        && savedDayName.text.trim().length > 0
        autoAccept: false
        onPrimaryRequested: {
            if (workoutController.savePreparationAsPlan(
                        savedPlanName.text, savedDayName.text))
                accept()
            else
                showError(workoutController.errorMessage)
        }
        contentItem: ColumnLayout {
            spacing: Design.Theme.space8
            TextField {
                id: savedPlanName
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                placeholderText: qsTr("计划名称")
                Accessible.name: qsTr("计划名称")
            }
            TextField {
                id: savedDayName
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                placeholderText: qsTr("训练日名称")
                Accessible.name: qsTr("训练日名称")
            }
        }
    }

    ConfirmDialog {
        id: cancelPreparationConfirm
        objectName: "cancelPreparationConfirmDialog"
        title: qsTr("取消训练准备？")
        message: qsTr("本次调整尚未开始训练，取消后不会写入训练记录。")
        confirmText: qsTr("取消准备")
        destructive: true
        onAccepted: {
            workoutController.cancelPreparation()
            page.cancelled()
        }
    }
}
