import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page
    objectName: "trainingPage"

    implicitWidth: 0
    implicitHeight: 0
    signal planStartRequested(string dayId)
    signal freeStartRequested(string name)
    property string selectedExerciseId: ""
    property bool submittingSet: false

    ExerciseDetailSheet {
        id: sharedExerciseDetail
        objectName: "trainingExerciseDetailSheet"
    }

    ExerciseOrderSheet {
        id: workoutOrderSheet
        objectName: "workoutExerciseOrderSheet"
        onSaveRequested: orderedIds => {
            if (workoutController.reorderExercises(orderedIds))
                close()
            else
                showError(workoutController.errorMessage)
        }
    }

    function exerciseIndexById(exerciseId) {
        for (let i = 0; i < workoutController.exercises.length; ++i) {
            if (workoutController.exercises[i].id === exerciseId)
                return i
        }
        return -1
    }

    function setIndexById(exerciseIndex, setId) {
        if (exerciseIndex < 0 || exerciseIndex >= workoutController.exercises.length)
            return -1
        const sets = workoutController.exercises[exerciseIndex].sets
        for (let i = 0; i < sets.length; ++i) {
            if (sets[i].id === setId)
                return i
        }
        return -1
    }

    function firstIncompleteSetIndex(exercise) {
        if (!exercise || !exercise.sets)
            return -1
        for (let i = 0; i < exercise.sets.length; ++i) {
            if (!exercise.sets[i].completed)
                return i
        }
        return -1
    }

    function completedSetCount(exercise) {
        if (!exercise || !exercise.sets)
            return 0
        let count = 0
        for (let i = 0; i < exercise.sets.length; ++i) {
            if (exercise.sets[i].completed)
                ++count
        }
        return count
    }

    function nextIncompleteExerciseId(afterIndex) {
        const items = workoutController.exercises
        if (items.length === 0)
            return ""
        for (let offset = 1; offset <= items.length; ++offset) {
            const index = (Math.max(-1, afterIndex) + offset) % items.length
            if (firstIncompleteSetIndex(items[index]) >= 0)
                return items[index].id
        }
        return ""
    }

    function ensureExerciseSelection() {
        if (!workoutController.active || workoutController.exercises.length === 0) {
            selectedExerciseId = ""
            return
        }
        if (exerciseIndexById(selectedExerciseId) >= 0)
            return
        const firstPending = nextIncompleteExerciseId(-1)
        selectedExerciseId = firstPending.length > 0
                ? firstPending : workoutController.exercises[0].id
    }

    function selectExercise(exerciseId) {
        selectedExerciseId = exerciseId
        Qt.callLater(loadCurrentSetInputs)
    }

    function loadCurrentSetInputs() {
        const exercise = currentExercise
        const setData = currentSet
        if (!exercise || !setData) {
            setWeight.text = ""
            setReps.text = ""
            setFailure.checked = false
            bodyweightMode.currentIndex = 0
            return
        }
        const hasWeight = setData.weightKg !== undefined && setData.weightKg !== null
                && Number.isFinite(Number(setData.weightKg))
        setWeight.text = hasWeight ? String(Number(setData.weightKg)) : ""
        setReps.text = ""
        setFailure.checked = false
        bodyweightMode.currentIndex = setData.bodyweightLoadType === "Added" ? 1
                : setData.bodyweightLoadType === "Assisted" ? 2 : 0
    }

    function gymIndex(gymId) {
        for (let i = 0; i < workoutController.gyms.length; ++i) {
            if (workoutController.gyms[i].id === gymId)
                return i
        }
        return -1
    }

    function equipmentIndex(equipmentId) {
        for (let i = 0; i < workoutController.equipment.length; ++i) {
            if (workoutController.equipment[i].id === equipmentId)
                return i
        }
        return -1
    }

    function previousText(sets) {
        if (!sets || sets.length === 0)
            return qsTr("暂无同器械历史")
        const values = []
        for (let i = 0; i < sets.length; ++i)
            values.push(Number(sets[i].weightKg) + " kg × " + sets[i].reps)
        return qsTr("上次：") + values.join("  ·  ")
    }

    readonly property int currentExerciseIndex: exerciseIndexById(selectedExerciseId)
    readonly property var currentExercise: currentExerciseIndex >= 0
            ? workoutController.exercises[currentExerciseIndex] : null
    readonly property int currentSetIndex: firstIncompleteSetIndex(currentExercise)
    readonly property var currentSet: currentExercise && currentSetIndex >= 0
            ? currentExercise.sets[currentSetIndex] : null
    readonly property bool currentIsBodyweight: currentExercise
            && currentExercise.loadMode === "Bodyweight"
    readonly property bool pureBodyweight: currentIsBodyweight
            && bodyweightMode.currentIndex === 0
    readonly property bool allExercisesComplete: workoutController.active
            && workoutController.exercises.length > 0
            && nextIncompleteExerciseId(-1).length === 0

    Component.onCompleted: {
        exerciseModel.ensureLoaded()
        planExerciseModel.ensureLoaded()
        ensureExerciseSelection()
        Qt.callLater(loadCurrentSetInputs)
    }

    Connections {
        target: workoutController

        function onExercisesChanged() {
            page.submittingSet = false
            page.ensureExerciseSelection()
            Qt.callLater(page.loadCurrentSetInputs)
        }

        function onSessionChanged() {
            page.ensureExerciseSelection()
            Qt.callLater(page.loadCurrentSetInputs)
        }

        function onSetCompleted(restSeconds) {
            page.Accessible.announce(
                        restSeconds > 0
                        ? qsTr("本组已保存，已开始 %1 秒休息计时").arg(restSeconds)
                        : qsTr("本组已保存"),
                        Accessible.Polite)
            const completedExerciseIndex = page.exerciseIndexById(page.selectedExerciseId)
            if (completedExerciseIndex >= 0
                    && page.firstIncompleteSetIndex(workoutController.exercises[completedExerciseIndex]) < 0) {
                const nextId = page.nextIncompleteExerciseId(completedExerciseIndex)
                if (nextId.length > 0)
                    page.selectedExerciseId = nextId
            }
            Qt.callLater(page.loadCurrentSetInputs)
            if (restSeconds > 0)
                restTimer.start(restSeconds)
        }
    }

    Connections {
        target: restTimer

        function onFinished() {
            page.Accessible.announce(qsTr("休息计时结束"), Accessible.Assertive)
        }
    }

    AppDialog {
        id: sessionMenu
        objectName: "sessionActionsDialog"
        title: qsTr("训练操作")
        primaryText: qsTr("关闭")
        primaryVariant: "secondary"
        secondaryVisible: false
        initialFocusItem: addExerciseAction

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space8

            AppButton {
                id: addExerciseAction
                Layout.fillWidth: true
                text: qsTr("添加动作")
                variant: "secondary"
                onClicked: {
                    sessionMenu.close()
                    Qt.callLater(function() { exercisePicker.openForExercise("") })
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("调整动作顺序")
                variant: "secondary"
                enabled: workoutController.exercises.length > 1
                onClicked: {
                    sessionMenu.close()
                    Qt.callLater(function() {
                        workoutOrderSheet.openExercises(
                                    workoutController.exercises, "id", "")
                    })
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("保存为个人计划")
                variant: "secondary"
                onClicked: {
                    sessionMenu.close()
                    Qt.callLater(function() {
                        savedPlanName.text = workoutController.sessionName
                        savedDayName.text = workoutController.sessionName
                        savedSectionName.text = ""
                        savePlanDialog.open()
                    })
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("训练备注")
                variant: "secondary"
                onClicked: {
                    sessionMenu.close()
                    Qt.callLater(function() {
                        sessionNotes.text = workoutController.sessionNotes
                        sessionNotesDialog.open()
                    })
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("放弃本次训练")
                variant: "destructive"
                onClicked: {
                    sessionMenu.close()
                    Qt.callLater(function() { discardWorkoutConfirm.open() })
                }
            }
        }
    }

    AppDialog {
        id: exerciseActions
        objectName: "exerciseActionsDialog"
        property string targetExerciseId: ""
        title: qsTr("动作操作")
        primaryText: qsTr("关闭")
        primaryVariant: "secondary"
        secondaryVisible: false
        initialFocusItem: configureExerciseAction

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space8

            AppButton {
                id: configureExerciseAction
                Layout.fillWidth: true
                text: qsTr("设置组数与目标次数")
                variant: "secondary"
                onClicked: {
                    exerciseActions.close()
                    Qt.callLater(function() {
                        configureDialog.openForExercise(exerciseActions.targetExerciseId)
                    })
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("选择具体器械")
                variant: "secondary"
                onClicked: {
                    exerciseActions.close()
                    Qt.callLater(function() {
                        equipmentChoiceDialog.openForExercise(exerciseActions.targetExerciseId)
                    })
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("动作备注")
                variant: "secondary"
                onClicked: {
                    exerciseActions.close()
                    Qt.callLater(function() {
                        exerciseNotesDialog.openForExercise(exerciseActions.targetExerciseId)
                    })
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("替换动作")
                variant: "secondary"
                onClicked: {
                    exerciseActions.close()
                    Qt.callLater(function() {
                        exercisePicker.openForExercise(exerciseActions.targetExerciseId)
                    })
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("上移")
                    variant: "secondary"
                    enabled: page.exerciseIndexById(exerciseActions.targetExerciseId) > 0
                    onClicked: {
                        const index = page.exerciseIndexById(exerciseActions.targetExerciseId)
                        exerciseActions.close()
                        workoutController.moveExercise(index, index - 1)
                    }
                }
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("下移")
                    variant: "secondary"
                    enabled: {
                        const index = page.exerciseIndexById(exerciseActions.targetExerciseId)
                        return index >= 0 && index + 1 < workoutController.exercises.length
                    }
                    onClicked: {
                        const index = page.exerciseIndexById(exerciseActions.targetExerciseId)
                        exerciseActions.close()
                        workoutController.moveExercise(index, index + 1)
                    }
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("删除动作")
                variant: "destructive"
                onClicked: {
                    removeExerciseConfirm.targetExerciseId = exerciseActions.targetExerciseId
                    exerciseActions.close()
                    Qt.callLater(function() { removeExerciseConfirm.open() })
                }
            }
        }
    }

    AppDialog {
        id: exercisePicker
        objectName: "exercisePickerDialog"
        property string replaceExerciseId: ""
        property string oldSearch: ""
        property string oldBodyPart: ""
        property string oldMovement: ""
        property string oldEquipment: ""
        property bool oldFavoritesOnly: false

        function openForExercise(exerciseId) {
            replaceExerciseId = exerciseId
            oldSearch = exerciseModel.searchText
            oldBodyPart = exerciseModel.bodyPart
            oldMovement = exerciseModel.movementFilter
            oldEquipment = exerciseModel.equipmentFilter
            oldFavoritesOnly = exerciseModel.favoritesOnly
            exerciseModel.searchText = ""
            exerciseModel.bodyPart = ""
            exerciseModel.movementFilter = ""
            exerciseModel.equipmentFilter = ""
            exerciseModel.favoritesOnly = false
            open()
        }

        width: Math.min(520, safeAvailableWidth)
        height: Math.min(680, safeAvailableHeight)
        title: replaceExerciseId.length > 0 ? qsTr("替换动作") : qsTr("添加动作")
        primaryText: qsTr("关闭")
        primaryVariant: "secondary"
        secondaryVisible: false
        initialFocusItem: exerciseSearch

        onClosed: {
            exerciseModel.searchText = oldSearch
            exerciseModel.bodyPart = oldBodyPart
            exerciseModel.movementFilter = oldMovement
            exerciseModel.equipmentFilter = oldEquipment
            exerciseModel.favoritesOnly = oldFavoritesOnly
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space8

            TextField {
                id: exerciseSearch
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                placeholderText: qsTr("搜索动作")
                Accessible.name: qsTr("搜索动作")
                onTextChanged: exerciseModel.searchText = text
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Design.Theme.space4
                model: exerciseModel

                delegate: ItemDelegate {
                    required property string exerciseId
                    required property string name
                    required property string bodyPart
                    required property int recommendedSets
                    required property string recommendedReps

                    width: ListView.view.width
                    implicitHeight: 56
                    rightPadding: 64
                    text: name + "  ·  " + bodyPart
                    Accessible.name: qsTr("选择%1，%2").arg(name).arg(bodyPart)
                    onClicked: {
                        let success = false
                        if (exercisePicker.replaceExerciseId.length > 0) {
                            const index = page.exerciseIndexById(exercisePicker.replaceExerciseId)
                            success = index >= 0 && workoutController.replaceExercise(index, exerciseId)
                        } else {
                            success = workoutController.addExercise(
                                        exerciseId, recommendedSets, recommendedReps)
                        }
                        if (success)
                            exercisePicker.close()
                        else
                            exercisePicker.showError(
                                        workoutController.errorMessage.length > 0
                                        ? workoutController.errorMessage
                                        : qsTr("动作更新失败，请重试。"))
                    }
                    IconButton {
                        anchors.right: parent.right
                        anchors.rightMargin: Design.Theme.space8
                        anchors.verticalCenter: parent.verticalCenter
                        iconName: "forward"
                        accessibleName: qsTr("预览 %1").arg(name)
                        onClicked: sharedExerciseDetail.openExercise(
                                       exerciseModel.exerciseById(exerciseId))
                    }
                }
            }
        }
    }

    AppDialog {
        id: configureDialog
        objectName: "configureExerciseDialog"
        property string targetExerciseId: ""
        property var defaultParameters: ({})

        function openForExercise(exerciseId) {
            targetExerciseId = exerciseId
            const index = page.exerciseIndexById(exerciseId)
            if (index < 0)
                return
            const exercise = workoutController.exercises[index]
            defaultParameters = exerciseModel.exerciseById(exercise.exerciseId)
            quickWeight.text = ""
            const targets = []
            for (let setIndex = 0; setIndex < exercise.sets.length; ++setIndex) {
                if (exercise.sets[setIndex].targetReps !== null
                        && exercise.sets[setIndex].targetReps !== undefined)
                    targets.push(String(exercise.sets[setIndex].targetReps))
            }
            quickReps.text = targets.length > 0 ? targets.join(",")
                                                : String(exercise.recommendedReps || "")
            quickSets.value = Math.max(1, exercise.sets.length)
            quickRest.value = Number(exercise.restSeconds || 0)
            open()
        }

        width: Math.min(380, safeAvailableWidth)
        title: qsTr("设置训练组")
        primaryText: qsTr("应用设置")
        autoAccept: false
        initialFocusItem: quickWeight.editorItem
        onPrimaryRequested: {
            const index = page.exerciseIndexById(targetExerciseId)
            const succeeded = index >= 0 && workoutController.configureExerciseParameters(
                                  index,
                                  Number.isFinite(quickWeight.numericValue) ? quickWeight.numericValue : 0,
                                  quickReps.text,
                                  quickSets.value,
                                  quickRest.value)
            if (succeeded)
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("训练组设置失败，请重试。"))
        }

        ScrollView {
            id: configureScroll
            anchors.fill: parent
            implicitHeight: Math.min(configureForm.implicitHeight,
                                     Overlay.overlay ? Overlay.overlay.height * 0.5 : 400)
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: configureForm
                width: configureScroll.availableWidth
                spacing: Design.Theme.space12

                Label {
                    text: qsTr("重量 × 次数 × 组数，一次生成后仍可逐组修改。")
                    color: Design.Theme.surfaceMuted
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                NumberField { id: quickWeight; Layout.fillWidth: true; label: qsTr("重量"); unit: "kg"; decimals: 2 }
                TextField {
                    id: quickReps
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                    placeholderText: qsTr("目标次数，例如 8-12 或 12,10,8")
                    Accessible.name: qsTr("目标次数")
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("组数"); color: Design.Theme.surfaceMuted }
                    Item { Layout.fillWidth: true }
                    SpinBox {
                        id: quickSets
                        from: 1
                        to: 20
                        value: 3
                        editable: true
                        implicitHeight: Design.Theme.controlHeight
                        Accessible.name: qsTr("组数")
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("休息秒数"); color: Design.Theme.surfaceMuted }
                    Item { Layout.fillWidth: true }
                    SpinBox {
                        id: quickRest
                        from: 0
                        to: 600
                        stepSize: 15
                        editable: true
                        implicitHeight: Design.Theme.controlHeight
                        Accessible.name: qsTr("休息秒数")
                    }
                }
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("恢复动作推荐值")
                    variant: "secondary"
                    onClicked: {
                        quickSets.value = Math.max(1, Number(configureDialog.defaultParameters.recommendedSets || 1))
                        quickReps.text = String(configureDialog.defaultParameters.recommendedReps || "8-12")
                        quickRest.value = Number(configureDialog.defaultParameters.restSeconds || 0)
                    }
                }
            }
        }
    }

    AppDialog {
        id: editSetDialog
        objectName: "editCompletedSetDialog"
        property string targetExerciseId: ""
        property string targetSetId: ""

        function openForSet(exerciseId, setData, loadMode) {
            targetExerciseId = exerciseId
            targetSetId = setData.id
            editWeight.text = setData.weightKg !== null && setData.weightKg !== undefined
                    ? String(Number(setData.weightKg)) : ""
            editReps.text = setData.actualReps !== null && setData.actualReps !== undefined
                    ? String(setData.actualReps) : ""
            editTargetReps.text = setData.targetReps !== null && setData.targetReps !== undefined
                    ? String(setData.targetReps) : ""
            editFailure.checked = setData.toFailure
            editNotes.text = String(setData.notes || "")
            editBodyweightMode.visible = loadMode === "Bodyweight"
            editBodyweightMode.currentIndex = setData.bodyweightLoadType === "Added" ? 1
                    : setData.bodyweightLoadType === "Assisted" ? 2 : 0
            open()
        }

        width: Math.min(380, safeAvailableWidth)
        title: qsTr("修正已完成组")
        primaryText: qsTr("保存修改")
        autoAccept: false
        initialFocusItem: editWeight.editorItem
        onPrimaryRequested: {
            const exerciseIndex = page.exerciseIndexById(targetExerciseId)
            const setIndex = page.setIndexById(exerciseIndex, targetSetId)
            let succeeded = false
            if (exerciseIndex >= 0 && setIndex >= 0) {
                succeeded = workoutController.updateCompletedSet(
                                exerciseIndex,
                                setIndex,
                                Number.isFinite(editWeight.numericValue) ? editWeight.numericValue : 0,
                                Number.isFinite(editReps.numericValue) ? editReps.numericValue : 0,
                                editFailure.checked,
                                editBodyweightMode.visible
                                    ? editBodyweightMode.model[editBodyweightMode.currentIndex].value
                                    : "Bodyweight")
                if (succeeded && editTargetReps.text.trim().length)
                    succeeded = workoutController.setTargetReps(
                                exerciseIndex, setIndex, editTargetReps.numericValue)
                if (succeeded)
                    succeeded = workoutController.setSetNotes(exerciseIndex, setIndex, editNotes.text)
            }
            if (succeeded)
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("训练组修改失败，请重试。"))
        }

        ScrollView {
            id: editSetScroll
            anchors.fill: parent
            implicitHeight: Math.min(editSetForm.implicitHeight,
                                     Overlay.overlay ? Overlay.overlay.height * 0.55 : 440)
            clip: true
            contentWidth: availableWidth

            ColumnLayout {
                id: editSetForm
                width: editSetScroll.availableWidth
                spacing: Design.Theme.space12
                NumberField { id: editWeight; Layout.fillWidth: true; label: qsTr("实际重量"); unit: "kg"; decimals: 2 }
                NumberField { id: editReps; Layout.fillWidth: true; label: qsTr("实际次数"); decimals: 0; keyboardHints: Qt.ImhDigitsOnly }
                NumberField {
                    id: editTargetReps
                    Layout.fillWidth: true
                    label: qsTr("目标次数（选填）")
                    from: 1
                    to: 999
                    decimals: 0
                    keyboardHints: Qt.ImhDigitsOnly
                }
                ComboBox {
                    id: editBodyweightMode
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("自重负荷方式")
                    textRole: "label"
                    model: [
                        {"label": qsTr("纯自重"), "value": "Bodyweight"},
                        {"label": qsTr("附加负重"), "value": "Added"},
                        {"label": qsTr("辅助重量"), "value": "Assisted"}
                    ]
                }
                CheckBox {
                    id: editFailure
                    objectName: "editSetFailureCheckBox"
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                    text: qsTr("本组力竭")
                }
                TextArea {
                    id: editNotes
                    Layout.fillWidth: true
                    Layout.preferredHeight: 84
                    placeholderText: qsTr("本组备注（可选）")
                    Accessible.name: qsTr("本组备注")
                    wrapMode: TextEdit.Wrap
                    color: Design.Theme.surfaceText
                    background: Rectangle {
                        color: Design.Theme.surfaceElevated
                        radius: Design.Theme.radiusSmall
                        border.width: editNotes.activeFocus ? 2 : 1
                        border.color: editNotes.activeFocus
                                      ? Design.Theme.primary : Design.Theme.outline
                    }
                }
            }
        }
    }

    AppDialog {
        id: targetRepsDialog
        objectName: "targetRepsDialog"
        property string targetExerciseId: ""
        property string targetSetId: ""

        function openForSet(exerciseId, setData) {
            targetExerciseId = exerciseId
            targetSetId = setData.id
            targetRepsValue.value = setData.targetReps !== null && setData.targetReps !== undefined
                    ? Number(setData.targetReps) : 1
            open()
        }

        function submit() {
            const exerciseIndex = page.exerciseIndexById(targetExerciseId)
            const setIndex = page.setIndexById(exerciseIndex, targetSetId)
            const succeeded = exerciseIndex >= 0 && setIndex >= 0
                    && workoutController.setTargetReps(
                        exerciseIndex, setIndex, targetRepsValue.value)
            if (succeeded)
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("目标次数保存失败，请重试。"))
        }

        width: Math.min(340, safeAvailableWidth)
        title: qsTr("修改本组目标次数")
        primaryText: qsTr("保存目标")
        autoAccept: false
        initialFocusItem: targetRepsValue
        onPrimaryRequested: submit()

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12
            Label {
                Layout.fillWidth: true
                text: qsTr("只调整本组目标，不会生成重量或次数建议。")
                color: Design.Theme.surfaceMuted
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("目标次数"); color: Design.Theme.surfaceText; Layout.fillWidth: true }
                SpinBox {
                    id: targetRepsValue
                    from: 1
                    to: 999
                    editable: true
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("本组目标次数")
                }
            }
        }
    }

    AppDialog {
        id: appendSetDialog
        objectName: "appendSetDialog"
        property string targetExerciseId: ""
        property string targetSetId: ""

        function openForSet(exerciseId, setData) {
            targetExerciseId = exerciseId
            targetSetId = setData.id
            appendWeight.text = setData.weightKg !== null && setData.weightKg !== undefined
                    ? String(Number(setData.weightKg)) : ""
            appendReps.text = ""
            appendRest.value = 5
            appendFailure.checked = false
            open()
        }

        width: Math.min(380, safeAvailableWidth)
        title: qsTr("添加短休追加组")
        primaryText: qsTr("添加追加组")
        autoAccept: false
        initialFocusItem: appendWeight.editorItem
        onPrimaryRequested: {
            const exerciseIndex = page.exerciseIndexById(targetExerciseId)
            const setIndex = page.setIndexById(exerciseIndex, targetSetId)
            const succeeded = exerciseIndex >= 0 && setIndex >= 0
                    && workoutController.addAppendSet(
                        exerciseIndex,
                        setIndex,
                        Number.isFinite(appendWeight.numericValue) ? appendWeight.numericValue : 0,
                        Number.isFinite(appendReps.numericValue) ? appendReps.numericValue : 0,
                        appendRest.value,
                        appendFailure.checked)
            if (succeeded)
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("追加组保存失败，请重试。"))
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12
            NumberField { id: appendWeight; Layout.fillWidth: true; label: qsTr("追加重量"); unit: "kg"; decimals: 2 }
            NumberField { id: appendReps; Layout.fillWidth: true; label: qsTr("追加次数"); decimals: 0; keyboardHints: Qt.ImhDigitsOnly }
            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("短休秒数"); color: Design.Theme.surfaceMuted }
                Item { Layout.fillWidth: true }
                SpinBox {
                    id: appendRest
                    from: 0
                    to: 300
                    value: 5
                    editable: true
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("短休秒数")
                }
            }
            CheckBox {
                id: appendFailure
                objectName: "appendSetFailureCheckBox"
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                text: qsTr("追加组力竭")
            }
        }
    }

    AppDialog {
        id: timerDialog
        objectName: "restTimerDialog"
        width: Math.min(380, safeAvailableWidth)
        title: qsTr("休息计时")
        primaryText: qsTr("关闭")
        primaryVariant: "secondary"
        secondaryVisible: false
        initialFocusItem: timerMinutes

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12
            GridLayout {
                id: timerPresetGrid
                Layout.fillWidth: true
                columns: Design.Theme.fontScale >= 1.3 ? 2 : 3
                columnSpacing: Design.Theme.space8
                rowSpacing: Design.Theme.space8
                AppButton {
                    objectName: "twoMinuteTimerButton"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("2 分钟")
                    onClicked: {
                        restTimer.start(120)
                        timerDialog.close()
                    }
                }
                AppButton {
                    objectName: "threeMinuteTimerButton"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("3 分钟")
                    onClicked: {
                        restTimer.start(180)
                        timerDialog.close()
                    }
                }
                AppButton {
                    objectName: "fiveMinuteTimerButton"
                    Layout.fillWidth: true
                    Layout.columnSpan: timerPresetGrid.columns === 2 ? 2 : 1
                    Layout.minimumWidth: 0
                    text: qsTr("5 分钟")
                    onClicked: {
                        restTimer.start(300)
                        timerDialog.close()
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                text: qsTr("自定义时长")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space4
                    Label {
                        text: qsTr("分钟")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                    }
                    SpinBox {
                        id: timerMinutes
                        Layout.fillWidth: true
                        from: 0
                        to: 59
                        value: 2
                        editable: true
                        implicitHeight: Design.Theme.controlHeight
                        Accessible.name: qsTr("自定义分钟")
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space4
                    Label {
                        text: qsTr("秒数")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                    }
                    SpinBox {
                        id: timerSeconds
                        Layout.fillWidth: true
                        from: 0
                        to: 59
                        value: 0
                        editable: true
                        implicitHeight: Design.Theme.controlHeight
                        Accessible.name: qsTr("自定义秒数")
                    }
                }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("开始计时")
                enabled: timerMinutes.value > 0 || timerSeconds.value > 0
                onClicked: {
                    restTimer.start(timerMinutes.value * 60 + timerSeconds.value)
                    timerDialog.close()
                }
            }
        }
    }

    AppDialog {
        id: equipmentChoiceDialog
        objectName: "equipmentChoiceDialog"
        property string targetExerciseId: ""

        function openForExercise(exerciseId) {
            targetExerciseId = exerciseId
            const index = page.exerciseIndexById(exerciseId)
            if (index < 0)
                return
            const exercise = workoutController.exercises[index]
            equipmentChoice.currentIndex = page.equipmentIndex(exercise.equipmentId)
            open()
        }

        width: Math.min(400, safeAvailableWidth)
        title: qsTr("本次使用器械")
        primaryText: qsTr("保存器械")
        autoAccept: false
        initialFocusItem: equipmentChoice
        onPrimaryRequested: {
            const index = page.exerciseIndexById(targetExerciseId)
            let succeeded = false
            if (index >= 0) {
                const equipmentId = equipmentChoice.currentIndex >= 0
                        ? workoutController.equipment[equipmentChoice.currentIndex].id : ""
                succeeded = workoutController.setExerciseEquipment(index, equipmentId)
            }
            if (succeeded)
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("器械选择保存失败，请重试。"))
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12
            ComboBox {
                id: equipmentChoice
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                model: workoutController.equipment
                textRole: "displayName"
                displayText: currentIndex >= 0 ? currentText : qsTr("不指定具体器械")
                Accessible.name: qsTr("本次使用器械")
            }
            AppButton {
                Layout.fillWidth: true
                variant: "secondary"
                text: qsTr("新建器械")
                enabled: workoutController.selectedGymId.length > 0
                onClicked: {
                    equipmentName.text = ""
                    equipmentCode.text = ""
                    equipmentNotes.text = ""
                    equipmentDialog.open()
                }
            }
        }
    }

    AppDialog {
        id: gymDialog
        objectName: "createGymDialog"
        width: Math.min(380, safeAvailableWidth)
        title: qsTr("新建健身房")
        primaryText: qsTr("创建健身房")
        primaryEnabled: gymName.text.trim().length > 0
        autoAccept: false
        initialFocusItem: gymName
        onPrimaryRequested: {
            if (workoutController.addGym(gymName.text))
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("健身房创建失败，请重试。"))
        }
        TextField {
            id: gymName
            anchors.fill: parent
            placeholderText: qsTr("例如：学校健身房")
            implicitHeight: Design.Theme.controlHeight
            Accessible.name: qsTr("健身房名称")
        }
    }

    AppDialog {
        id: equipmentDialog
        objectName: "createEquipmentDialog"
        width: Math.min(400, safeAvailableWidth)
        title: qsTr("新建具体器械")
        primaryText: qsTr("创建器械")
        primaryEnabled: equipmentName.text.trim().length > 0
        autoAccept: false
        initialFocusItem: equipmentName
        onPrimaryRequested: {
            if (workoutController.addEquipment(
                        equipmentName.text, equipmentCode.text, equipmentNotes.text))
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("器械创建失败，请重试。"))
        }
        ScrollView {
            id: equipmentFormScroll
            anchors.fill: parent
            implicitHeight: Math.min(equipmentForm.implicitHeight,
                                     Overlay.overlay ? Overlay.overlay.height * 0.45 : 360)
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: equipmentForm
                width: equipmentFormScroll.availableWidth
                spacing: Design.Theme.space8
                TextField {
                    id: equipmentName
                    Layout.fillWidth: true
                    placeholderText: qsTr("器械名称")
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("器械名称")
                }
                TextField {
                    id: equipmentCode
                    Layout.fillWidth: true
                    placeholderText: qsTr("编号，例如 1 号")
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("器械编号")
                }
                TextField {
                    id: equipmentNotes
                    Layout.fillWidth: true
                    placeholderText: qsTr("座椅档位、把手等，可选")
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("器械备注")
                }
            }
        }
    }

    AppDialog {
        id: exerciseNotesDialog
        objectName: "exerciseNotesDialog"
        property string targetExerciseId: ""

        function openForExercise(exerciseId) {
            targetExerciseId = exerciseId
            const index = page.exerciseIndexById(exerciseId)
            if (index < 0)
                return
            exerciseNotes.text = workoutController.exercises[index].notes
            open()
        }

        width: Math.min(400, safeAvailableWidth)
        title: qsTr("动作备注")
        primaryText: qsTr("保存备注")
        autoAccept: false
        initialFocusItem: exerciseNotes
        onPrimaryRequested: {
            const index = page.exerciseIndexById(targetExerciseId)
            const succeeded = index >= 0
                    && workoutController.setExerciseNotes(index, exerciseNotes.text)
            if (succeeded)
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("动作备注保存失败，请重试。"))
        }
        TextArea {
            id: exerciseNotes
            anchors.fill: parent
            implicitHeight: 112
            wrapMode: TextEdit.Wrap
            placeholderText: qsTr("器械档位或本次感受，可选")
            Accessible.name: qsTr("动作备注")
        }
    }

    AppDialog {
        id: sessionNotesDialog
        objectName: "sessionNotesDialog"
        width: Math.min(400, safeAvailableWidth)
        title: qsTr("训练备注")
        primaryText: qsTr("保存备注")
        autoAccept: false
        initialFocusItem: sessionNotes
        onPrimaryRequested: {
            if (workoutController.setSessionNotes(sessionNotes.text))
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("训练备注保存失败，请重试。"))
        }
        TextArea {
            id: sessionNotes
            anchors.fill: parent
            implicitHeight: 112
            wrapMode: TextEdit.Wrap
            placeholderText: qsTr("本次训练备注，可选")
            Accessible.name: qsTr("训练备注")
        }
    }

    AppDialog {
        id: savePlanDialog
        objectName: "savePlanDialog"
        width: Math.min(400, safeAvailableWidth)
        title: qsTr("保存为个人计划")
        primaryText: qsTr("保存计划")
        primaryEnabled: savedPlanName.text.trim().length > 0
                        && savedDayName.text.trim().length > 0
        autoAccept: false
        initialFocusItem: savedPlanName
        onPrimaryRequested: {
            if (workoutController.saveCurrentAsPlan(
                        savedPlanName.text, savedDayName.text, savedSectionName.text))
                accept()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("个人计划保存失败，请重试。"))
        }
        ScrollView {
            id: savePlanFormScroll
            anchors.fill: parent
            implicitHeight: Math.min(savePlanForm.implicitHeight,
                                     Overlay.overlay ? Overlay.overlay.height * 0.45 : 360)
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: savePlanForm
                width: savePlanFormScroll.availableWidth
                spacing: Design.Theme.space8
                TextField {
                    id: savedPlanName
                    Layout.fillWidth: true
                    placeholderText: qsTr("计划名称")
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("计划名称")
                }
                TextField {
                    id: savedDayName
                    Layout.fillWidth: true
                    placeholderText: qsTr("训练日名称，例如 Push A")
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("训练日名称")
                }
                TextField {
                    id: savedSectionName
                    Layout.fillWidth: true
                    placeholderText: qsTr("动作分组名称，可选")
                    implicitHeight: Design.Theme.controlHeight
                    Accessible.name: qsTr("动作分组名称")
                }
            }
        }
    }

    ConfirmDialog {
        id: discardWorkoutConfirm
        objectName: "discardWorkoutConfirmDialog"
        title: qsTr("放弃本次训练？")
        message: qsTr("本次训练和已经填写的组记录都会被删除，此操作无法撤销。")
        confirmText: qsTr("放弃训练")
        destructive: true
        onAccepted: workoutController.discardWorkout()
    }

    ConfirmDialog {
        id: discardUnfinishedConfirm
        objectName: "discardUnfinishedConfirmDialog"
        title: qsTr("删除未完成训练？")
        message: qsTr("已经保存的组记录也会一并删除。")
        confirmText: qsTr("删除")
        destructive: true
        onAccepted: workoutController.discardUnfinished()
    }

    ConfirmDialog {
        id: removeExerciseConfirm
        objectName: "removeExerciseConfirmDialog"
        property string targetExerciseId: ""
        title: qsTr("删除这个动作？")
        message: qsTr("只有尚未完成任何组的动作可以删除。")
        confirmText: qsTr("删除动作")
        destructive: true
        onAccepted: {
            const index = page.exerciseIndexById(targetExerciseId)
            if (index >= 0)
                workoutController.removeExercise(index)
        }
    }

    ConfirmDialog {
        id: finishWorkoutConfirm
        objectName: "finishWorkoutConfirmDialog"
        title: qsTr("提前结束训练？")
        message: qsTr("仍有未完成的组。已完成的数据会保留，未完成组不会计入统计。")
        confirmText: qsTr("保存并结束")
        onAccepted: workoutController.finishWorkout()
    }

    contentItem: ScrollView {
        id: trainingScroll
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: trainingScroll.availableWidth
            spacing: Design.Theme.space12

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Label {
                        objectName: "trainingSessionTitle"
                        text: workoutController.active ? workoutController.sessionName : qsTr("训练")
                        color: Design.Theme.backgroundText
                        font.pixelSize: Design.Theme.typeTitle
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        wrapMode: Text.WordWrap
                    }
                    Label {
                        visible: workoutController.active
                        text: page.currentExerciseIndex >= 0
                                ? qsTr("第 %1 / %2 个动作")
                                    .arg(page.currentExerciseIndex + 1)
                                    .arg(workoutController.exercises.length)
                                : qsTr("准备开始")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                    }
                }

                IconButton {
                    visible: workoutController.active
                    iconName: "more"
                    accessibleName: qsTr("训练更多操作")
                    onClicked: sessionMenu.open()
                }
            }

            InlineFeedback {
                visible: workoutController.errorMessage.length > 0
                Layout.fillWidth: true
                tone: "error"
                message: workoutController.errorMessage
            }

            ColumnLayout {
                visible: !workoutController.active
                Layout.fillWidth: true
                spacing: Design.Theme.space12

                AppCard {
                    visible: workoutController.hasUnfinished
                    Layout.fillWidth: true
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space8
                        Label {
                            text: qsTr("继续上次训练")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeTitle
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: qsTr("已完成的数据仍保存在本机，可以从断点继续。")
                            color: Design.Theme.surfaceMuted
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        AppButton {
                            Layout.fillWidth: true
                            text: qsTr("继续训练")
                            onClicked: workoutController.resumeUnfinished()
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            AppButton {
                                Layout.fillWidth: true
                                variant: "secondary"
                                text: qsTr("保存并结束")
                                onClicked: workoutController.finishUnfinished()
                            }
                            AppButton {
                                Layout.fillWidth: true
                                variant: "destructive"
                                text: qsTr("删除")
                                onClicked: discardUnfinishedConfirm.open()
                            }
                        }
                    }
                }

                AppCard {
                    Layout.fillWidth: true
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space12
                        Label {
                            text: qsTr("选择训练入口")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeTitle
                            font.weight: Font.DemiBold
                        }
                        Label {
                            text: qsTr("使用内置三分化，或从空白自由训练开始。重量和次数始终由你填写。")
                            color: Design.Theme.surfaceMuted
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        ComboBox {
                            Layout.fillWidth: true
                            implicitHeight: Design.Theme.controlHeight
                            model: workoutController.gyms
                            textRole: "name"
                            currentIndex: page.gymIndex(workoutController.selectedGymId)
                            displayText: currentIndex >= 0 ? currentText : qsTr("未选择健身房")
                            onActivated: workoutController.selectGym(
                                             workoutController.gyms[currentIndex].id)
                        }
                        AppButton {
                            Layout.fillWidth: true
                            variant: "secondary"
                            text: qsTr("新建健身房")
                            onClicked: {
                                gymName.text = ""
                                gymDialog.open()
                            }
                        }

                        Repeater {
                            model: workoutController.planDays
                            delegate: AppButton {
                                required property var modelData
                                Layout.fillWidth: true
                                text: modelData.planName + " · " + modelData.name
                                onClicked: page.planStartRequested(modelData.dayId)
                            }
                        }

                        AppButton {
                            Layout.fillWidth: true
                            variant: "secondary"
                            text: qsTr("自由训练")
                            onClicked: page.freeStartRequested("")
                        }
                    }
                }
            }

            ColumnLayout {
                visible: workoutController.active
                Layout.fillWidth: true
                spacing: Design.Theme.space12

                AppCard {
                    visible: page.currentExercise !== null
                    Layout.fillWidth: true
                    padding: Design.Theme.space16

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space8

                        RowLayout {
                            Layout.fillWidth: true
                            Button {
                                objectName: "currentExercisePreviewButton"
                                Layout.fillWidth: true
                                implicitHeight: Design.Theme.controlHeight
                                flat: true
                                padding: 0
                                text: page.currentExercise ? page.currentExercise.name : ""
                                Accessible.name: page.currentExercise
                                                 ? qsTr("查看%1动作做法").arg(
                                                       page.currentExercise.name)
                                                 : qsTr("查看当前动作做法")
                                Accessible.description: qsTr("查看动作做法")
                                onClicked: if (page.currentExercise)
                                               sharedExerciseDetail.openExercise(
                                                   exerciseModel.exerciseById(
                                                       page.currentExercise.exerciseId))
                                contentItem: Label {
                                    text: parent.text
                                    color: Design.Theme.surfaceText
                                    font.pixelSize: Design.Theme.typeTitle
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                            }
                            Rectangle {
                                implicitWidth: currentBadge.implicitWidth + Design.Theme.space16
                                implicitHeight: 28
                                radius: 14
                                color: Design.Theme.primaryContainer
                                Label {
                                    id: currentBadge
                                    anchors.centerIn: parent
                                    text: qsTr("当前")
                                    color: Design.Theme.primaryContainerText
                                    font.pixelSize: Design.Theme.typeCaption
                                    font.weight: Font.DemiBold
                                }
                            }
                            IconButton {
                                iconName: "more"
                                accessibleName: page.currentExercise
                                                ? qsTr("%1更多操作").arg(page.currentExercise.name)
                                                : qsTr("当前动作更多操作")
                                onClicked: {
                                    exerciseActions.targetExerciseId = page.selectedExerciseId
                                    exerciseActions.open()
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: page.currentExercise
                                  ? qsTr("建议 %1 · 休息 %2 秒")
                                    .arg(page.currentExercise.recommendedReps)
                                    .arg(page.currentExercise.restSeconds)
                                  : ""
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: page.currentExercise ? page.previousText(page.currentExercise.previousSets) : ""
                            color: page.currentExercise && page.currentExercise.previousSets.length > 0
                                   ? Design.Theme.primaryContainerText : Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Design.Theme.space8
                            Label {
                                Layout.fillWidth: true
                                text: page.currentExercise && page.currentExercise.equipmentName.length > 0
                                      ? qsTr("器械：") + page.currentExercise.equipmentName
                                      : qsTr("未指定具体器械")
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeLabel
                                elide: Text.ElideRight
                            }
                            AppButton {
                                Layout.preferredWidth: 88
                                variant: "secondary"
                                text: qsTr("选择")
                                onClicked: equipmentChoiceDialog.openForExercise(page.selectedExerciseId)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Design.Theme.outline
                        }

                        Label {
                            Layout.fillWidth: true
                            text: page.currentSetIndex >= 0
                                  ? qsTr("已完成 %1 / %2 组")
                                    .arg(page.completedSetCount(page.currentExercise))
                                    .arg(page.currentExercise.sets.length)
                                  : qsTr("本动作已完成")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                        }

                        Repeater {
                            model: page.currentExercise ? page.currentExercise.sets : []
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                visible: modelData.completed
                                Layout.fillWidth: true
                                Layout.preferredHeight: visible ? implicitHeight : 0
                                implicitHeight: completedSetRow.implicitHeight
                                                + Design.Theme.space12
                                                + (appendSetColumn.visible
                                                   ? appendSetColumn.implicitHeight + Design.Theme.space4 : 0)
                                radius: Design.Theme.radiusSmall
                                color: Design.Theme.surfaceElevated

                                RowLayout {
                                    id: completedSetRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.topMargin: Design.Theme.space4
                                    anchors.leftMargin: Design.Theme.space12
                                    anchors.rightMargin: Design.Theme.space8
                                    spacing: Design.Theme.space8

                                    Label {
                                        text: qsTr("第 %1 组").arg(modelData.number)
                                        color: Design.Theme.success
                                        font.pixelSize: Design.Theme.typeLabel
                                        font.weight: Font.DemiBold
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        text: {
                                            const loadText = page.currentIsBodyweight
                                                    && modelData.bodyweightLoadType === "Bodyweight"
                                                    ? qsTr("自重") : Number(modelData.weightKg) + " kg"
                                            return loadText + " × " + modelData.actualReps
                                                    + (modelData.toFailure ? qsTr(" · 力竭") : "")
                                        }
                                        color: Design.Theme.surfaceText
                                        font.pixelSize: Design.Theme.typeBody
                                        elide: Text.ElideRight
                                    }
                                    IconButton {
                                        iconName: "add"
                                        accessibleName: qsTr("第 %1 组，添加短休追加组")
                                                        .arg(modelData.number)
                                        onClicked: appendSetDialog.openForSet(
                                                       page.selectedExerciseId, modelData)
                                    }
                                    IconButton {
                                        iconName: "edit"
                                        accessibleName: qsTr("第 %1 组，修正已完成数据")
                                                        .arg(modelData.number)
                                        onClicked: editSetDialog.openForSet(
                                                       page.selectedExerciseId,
                                                       modelData,
                                                       page.currentExercise.loadMode)
                                    }
                                }

                                ColumnLayout {
                                    id: appendSetColumn
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: completedSetRow.bottom
                                    anchors.leftMargin: Design.Theme.space12
                                    anchors.rightMargin: Design.Theme.space12
                                    visible: String(modelData.notes || "").length > 0
                                             || modelData.appendSets.length > 0

                                    Label {
                                        visible: String(modelData.notes || "").length > 0
                                        Layout.fillWidth: true
                                        text: qsTr("备注：%1").arg(modelData.notes)
                                        color: Design.Theme.surfaceMuted
                                        font.pixelSize: Design.Theme.typeCaption
                                        wrapMode: Text.WordWrap
                                    }

                                    Repeater {
                                        model: modelData.appendSets
                                        delegate: Label {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            text: qsTr("追加 %1 kg × %2 · 短休 %3 秒%4")
                                                .arg(modelData.weightKg)
                                                .arg(modelData.reps)
                                                .arg(modelData.restSeconds)
                                                .arg(modelData.toFailure ? qsTr(" · 力竭") : "")
                                            color: Design.Theme.surfaceMuted
                                            font.pixelSize: Design.Theme.typeCaption
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                InlineFeedback {
                    visible: workoutController.exercises.length === 0
                    Layout.fillWidth: true
                    tone: "info"
                    message: qsTr("还没有动作。先从动作库添加一个动作，再开始记录。")
                    actionText: qsTr("添加动作")
                    onActionTriggered: exercisePicker.openForExercise("")
                }

                Label {
                    visible: workoutController.exercises.length > 1
                    text: qsTr("动作顺序")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeBody
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: workoutController.exercises
                    delegate: Rectangle {
                        id: exerciseRow
                        objectName: "trainingExerciseRow_" + index
                        required property var modelData
                        required property int index
                        property int exerciseIndex: index

                        visible: workoutController.exercises.length > 1
                        Layout.fillWidth: true
                        implicitHeight: Math.max(
                                            72,
                                            trainingExerciseRowLayout.implicitHeight
                                            + Design.Theme.space8)
                        radius: Design.Theme.radiusSmall
                        color: page.selectedExerciseId === modelData.id
                               ? Design.Theme.primaryContainer : Design.Theme.surface
                        border.width: activeFocus ? 2 : 1
                        border.color: activeFocus || page.selectedExerciseId === modelData.id
                                      ? Design.Theme.primary : Design.Theme.outline
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("%1，已完成 %2 / %3 组")
                                         .arg(modelData.name)
                                         .arg(page.completedSetCount(modelData))
                                         .arg(modelData.sets.length)
                        Accessible.description: page.selectedExerciseId === modelData.id
                                                ? qsTr("当前动作") : qsTr("双击切换到该动作")
                        Accessible.selected: page.selectedExerciseId === modelData.id
                        Accessible.onPressAction: page.selectExercise(modelData.id)
                        RowLayout {
                            id: trainingExerciseRowLayout
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Design.Theme.space12
                            anchors.rightMargin: Design.Theme.space4
                            spacing: Design.Theme.space8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Button {
                                    id: trainingExercisePreview
                                    objectName: "trainingExercisePreviewButton_" + exerciseRow.index
                                    Layout.fillWidth: true
                                    implicitHeight: Math.max(
                                                        Design.Theme.touchTarget,
                                                        trainingExerciseName.implicitHeight
                                                        + Design.Theme.space8)
                                    flat: true
                                    padding: 0
                                    text: modelData.name
                                    Accessible.name: qsTr("查看%1动作做法").arg(modelData.name)
                                    Accessible.description: qsTr("查看动作做法")
                                    onClicked: sharedExerciseDetail.openExercise(
                                                   exerciseModel.exerciseById(modelData.exerciseId))
                                    contentItem: Label {
                                        id: trainingExerciseName
                                        text: trainingExercisePreview.text
                                        color: Design.Theme.surfaceText
                                        font.pixelSize: Design.Theme.typeBody
                                        font.weight: Font.DemiBold
                                        wrapMode: Text.WordWrap
                                    }
                                    background: Rectangle {
                                        color: "transparent"
                                        radius: Design.Theme.radiusSmall
                                        border.width: trainingExercisePreview.activeFocus ? 2 : 0
                                        border.color: Design.Theme.primary
                                    }
                                }
                                Label {
                                    text: qsTr("%1 / %2 组")
                                        .arg(page.completedSetCount(modelData))
                                        .arg(modelData.sets.length)
                                    color: page.completedSetCount(modelData) === modelData.sets.length
                                           ? Design.Theme.success : Design.Theme.surfaceMuted
                                    font.pixelSize: Design.Theme.typeCaption
                                }
                            }
                            IconButton {
                                iconName: "more"
                                accessibleName: qsTr("%1更多操作").arg(modelData.name)
                                onClicked: {
                                    page.selectExercise(modelData.id)
                                    exerciseActions.targetExerciseId = modelData.id
                                    exerciseActions.open()
                                }
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.LeftButton
                            onTapped: page.selectExercise(exerciseRow.modelData.id)
                        }
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                                    || event.key === Qt.Key_Space) {
                                page.selectExercise(exerciseRow.modelData.id)
                                event.accepted = true
                            }
                        }
                    }
                }

                AppButton {
                    Layout.fillWidth: true
                    variant: "secondary"
                    text: qsTr("添加动作")
                    onClicked: exercisePicker.openForExercise("")
                }

                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("完成本次训练")
                    enabled: workoutController.exercises.length > 0
                    onClicked: {
                        if (page.allExercisesComplete)
                            workoutController.finishWorkout()
                        else
                            finishWorkoutConfirm.open()
                    }
                }
            }

            Item { Layout.preferredHeight: Design.Theme.space8 }
        }
    }

    footer: Rectangle {
        visible: workoutController.active
        implicitHeight: visible ? inputFooterColumn.implicitHeight + Design.Theme.space16 : 0
        color: Design.Theme.background
        border.width: visible ? 1 : 0
        border.color: Design.Theme.outline

        ColumnLayout {
            id: inputFooterColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Design.Theme.space8
            spacing: Design.Theme.space8

            RestTimerBar {
                visible: restTimer.state === 1 || restTimer.state === 2
                Layout.fillWidth: true
                remainingSeconds: restTimer.remainingSeconds
                paused: restTimer.state === 2
                onPauseRequested: restTimer.pause()
                onResumeRequested: restTimer.resume()
                onStopRequested: restTimer.reset()
            }

            InlineFeedback {
                visible: restTimer.state === 3
                Layout.fillWidth: true
                tone: "success"
                message: qsTr("休息结束，可以开始下一组。")
                actionText: qsTr("知道了")
                onActionTriggered: restTimer.reset()
            }

            GridLayout {
                id: currentSetActions
                Layout.fillWidth: true
                columns: page.width < 400 || Design.Theme.fontScale >= 1.2 ? 2 : 4
                rowSpacing: Design.Theme.space8
                columnSpacing: Design.Theme.space8
                ItemDelegate {
                    objectName: "currentSetTargetButton"
                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    implicitHeight: Math.max(Design.Theme.controlHeight,
                                             Design.Theme.typeBody + Design.Theme.typeCaption
                                             + Design.Theme.space4)
                    leftPadding: 0
                    rightPadding: Design.Theme.space8
                    enabled: page.currentSet !== null
                    Accessible.name: page.currentSet
                                     ? qsTr("当前第 %1 组，目标 %2 次，双击修改")
                                       .arg(page.currentSet.number)
                                       .arg(page.currentSet.targetReps !== null
                                            ? page.currentSet.targetReps : qsTr("未设置"))
                                     : qsTr("当前动作已完成")
                    onClicked: targetRepsDialog.openForSet(page.currentExercise.id, page.currentSet)
                    background: Item { }
                    contentItem: ColumnLayout {
                        spacing: 0
                        Label {
                            text: page.currentSet
                                  ? qsTr("当前 · 第 %1 组").arg(page.currentSet.number)
                                  : (page.allExercisesComplete ? qsTr("训练记录已完成") : qsTr("当前动作已完成"))
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeBody
                            font.weight: Font.DemiBold
                        }
                        Label {
                            visible: page.currentSet !== null
                            text: page.currentSet && page.currentSet.targetReps !== null
                                  ? qsTr("目标 %1 次 · 点击修改").arg(page.currentSet.targetReps)
                                  : qsTr("设置本组目标次数")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                        }
                    }
                }
                AppButton {
                    objectName: "openRestTimerButton"
                    Layout.fillWidth: true
                    Layout.columnSpan: setFailure.visible ? 1 : 2
                    variant: "secondary"
                    text: qsTr("计时")
                    onClicked: timerDialog.open()
                }
                CheckBox {
                    id: setFailure
                    visible: page.currentSet !== null
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                    text: qsTr("力竭")
                }
            }

            RowLayout {
                visible: page.currentSet !== null
                Layout.fillWidth: true
                spacing: Design.Theme.space8
                NumberField {
                    id: setWeight
                    objectName: "setWeightField"
                    Layout.fillWidth: true
                    label: page.pureBodyweight ? qsTr("负重") : qsTr("实际重量")
                    placeholderText: page.pureBodyweight ? qsTr("纯自重") : qsTr("0")
                    unit: page.pureBodyweight ? "" : "kg"
                    decimals: 2
                    enabled: !page.pureBodyweight
                }
                NumberField {
                    id: setReps
                    objectName: "setRepsField"
                    Layout.fillWidth: true
                    label: qsTr("实际次数")
                    placeholderText: page.currentSet && page.currentSet.targetReps !== null
                                     ? String(page.currentSet.targetReps) : qsTr("次数")
                    decimals: 0
                    keyboardHints: Qt.ImhDigitsOnly
                    onAccepted: completeSetButton.clicked()
                }
            }

            ComboBox {
                id: bodyweightMode
                objectName: "bodyweightModeSelector"
                visible: page.currentSet !== null && page.currentIsBodyweight
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                textRole: "label"
                model: [
                    {"label": qsTr("纯自重，只记录次数"), "value": "Bodyweight"},
                    {"label": qsTr("附加负重"), "value": "Added"},
                    {"label": qsTr("辅助重量"), "value": "Assisted"}
                ]
                Accessible.name: qsTr("自重动作负荷方式")
                onCurrentIndexChanged: {
                    if (currentIndex === 0)
                        setWeight.text = ""
                }
            }

            AppButton {
                id: completeSetButton
                objectName: "completeSetButton"
                visible: page.currentSet !== null
                Layout.fillWidth: true
                text: page.submittingSet ? qsTr("正在保存…") : qsTr("完成本组")
                enabled: !page.submittingSet
                         && Number.isFinite(setReps.numericValue)
                         && (page.pureBodyweight || Number.isFinite(setWeight.numericValue))
                onClicked: {
                    if (!enabled || page.currentExerciseIndex < 0 || page.currentSetIndex < 0)
                        return
                    page.submittingSet = true
                    const loadType = page.currentIsBodyweight
                            ? bodyweightMode.model[bodyweightMode.currentIndex].value : "Bodyweight"
                    const success = workoutController.completeSet(
                                page.currentExerciseIndex,
                                page.currentSetIndex,
                                page.pureBodyweight ? 0 : setWeight.numericValue,
                                setReps.numericValue,
                                setFailure.checked,
                                loadType)
                    if (!success)
                        page.submittingSet = false
                }
            }

            AppButton {
                visible: page.currentSet === null && workoutController.exercises.length > 0
                Layout.fillWidth: true
                text: page.allExercisesComplete ? qsTr("完成本次训练") : qsTr("进入下一个动作")
                onClicked: {
                    if (page.allExercisesComplete) {
                        workoutController.finishWorkout()
                    } else {
                        const nextId = page.nextIncompleteExerciseId(page.currentExerciseIndex)
                        if (nextId.length > 0)
                            page.selectExercise(nextId)
                    }
                }
            }
        }
    }
}
