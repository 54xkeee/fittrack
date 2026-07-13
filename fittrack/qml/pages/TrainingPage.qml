import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page

    implicitWidth: 0
    property string selectedExerciseId: ""
    property bool submittingSet: false

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

    Menu {
        id: sessionMenu

        MenuItem {
            text: qsTr("添加动作")
            onTriggered: exercisePicker.openForExercise("")
        }
        MenuItem {
            text: qsTr("保存为个人计划")
            onTriggered: {
                savedPlanName.text = workoutController.sessionName
                savedDayName.text = workoutController.sessionName
                savedSectionName.text = ""
                savePlanDialog.open()
            }
        }
        MenuItem {
            text: qsTr("训练备注")
            onTriggered: {
                sessionNotes.text = workoutController.sessionNotes
                sessionNotesDialog.open()
            }
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("放弃本次训练")
            onTriggered: discardWorkoutConfirm.open()
        }
    }

    Menu {
        id: exerciseActions
        property string targetExerciseId: ""

        MenuItem {
            text: qsTr("设置组数与目标次数")
            onTriggered: configureDialog.openForExercise(exerciseActions.targetExerciseId)
        }
        MenuItem {
            text: qsTr("选择具体器械")
            onTriggered: equipmentChoiceDialog.openForExercise(exerciseActions.targetExerciseId)
        }
        MenuItem {
            text: qsTr("动作备注")
            onTriggered: exerciseNotesDialog.openForExercise(exerciseActions.targetExerciseId)
        }
        MenuItem {
            text: qsTr("替换动作")
            onTriggered: exercisePicker.openForExercise(exerciseActions.targetExerciseId)
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("上移")
            enabled: page.exerciseIndexById(exerciseActions.targetExerciseId) > 0
            onTriggered: {
                const index = page.exerciseIndexById(exerciseActions.targetExerciseId)
                workoutController.moveExercise(index, index - 1)
            }
        }
        MenuItem {
            text: qsTr("下移")
            enabled: {
                const index = page.exerciseIndexById(exerciseActions.targetExerciseId)
                return index >= 0 && index + 1 < workoutController.exercises.length
            }
            onTriggered: {
                const index = page.exerciseIndexById(exerciseActions.targetExerciseId)
                workoutController.moveExercise(index, index + 1)
            }
        }
        MenuSeparator {}
        MenuItem {
            text: qsTr("删除动作")
            onTriggered: {
                removeExerciseConfirm.targetExerciseId = exerciseActions.targetExerciseId
                removeExerciseConfirm.open()
            }
        }
    }

    Dialog {
        id: exercisePicker
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

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(520, Overlay.overlay.width - Design.Theme.space16 * 2)
        height: Math.min(680, Overlay.overlay.height - Design.Theme.space24 * 2)
        modal: true
        title: replaceExerciseId.length > 0 ? qsTr("替换动作") : qsTr("添加动作")
        standardButtons: Dialog.Close

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
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                placeholderText: qsTr("搜索动作")
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
                    text: name + "  ·  " + bodyPart
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
                    }
                }
            }
        }
    }

    Dialog {
        id: configureDialog
        property string targetExerciseId: ""

        function openForExercise(exerciseId) {
            targetExerciseId = exerciseId
            const index = page.exerciseIndexById(exerciseId)
            if (index < 0)
                return
            const exercise = workoutController.exercises[index]
            quickWeight.text = ""
            quickReps.text = exercise.sets.length > 0 && exercise.sets[0].targetReps !== null
                    ? String(exercise.sets[0].targetReps) : ""
            quickSets.value = Math.max(1, exercise.sets.length)
            open()
        }

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("设置训练组")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            const index = page.exerciseIndexById(targetExerciseId)
            if (index >= 0)
                workoutController.configureExercise(
                            index,
                            Number.isFinite(quickWeight.numericValue) ? quickWeight.numericValue : 0,
                            Number.isFinite(quickReps.numericValue) ? quickReps.numericValue : 0,
                            quickSets.value)
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12

            Label {
                text: qsTr("重量 × 次数 × 组数，一次生成后仍可逐组修改。")
                color: Design.Theme.surfaceMuted
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            NumberField { id: quickWeight; Layout.fillWidth: true; label: qsTr("重量"); unit: "kg"; decimals: 2 }
            NumberField { id: quickReps; Layout.fillWidth: true; label: qsTr("目标次数"); decimals: 0; keyboardHints: Qt.ImhDigitsOnly }
            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("组数"); color: Design.Theme.surfaceMuted }
                Item { Layout.fillWidth: true }
                SpinBox { id: quickSets; from: 1; to: 20; value: 3; editable: true }
            }
        }
    }

    Dialog {
        id: editSetDialog
        property string targetExerciseId: ""
        property string targetSetId: ""

        function openForSet(exerciseId, setData, loadMode) {
            targetExerciseId = exerciseId
            targetSetId = setData.id
            editWeight.text = setData.weightKg !== null && setData.weightKg !== undefined
                    ? String(Number(setData.weightKg)) : ""
            editReps.text = setData.actualReps !== null && setData.actualReps !== undefined
                    ? String(setData.actualReps) : ""
            editFailure.checked = setData.toFailure
            editBodyweightMode.visible = loadMode === "Bodyweight"
            editBodyweightMode.currentIndex = setData.bodyweightLoadType === "Added" ? 1
                    : setData.bodyweightLoadType === "Assisted" ? 2 : 0
            open()
        }

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("修正已完成组")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: {
            const exerciseIndex = page.exerciseIndexById(targetExerciseId)
            const setIndex = page.setIndexById(exerciseIndex, targetSetId)
            if (exerciseIndex >= 0 && setIndex >= 0) {
                workoutController.updateCompletedSet(
                            exerciseIndex,
                            setIndex,
                            Number.isFinite(editWeight.numericValue) ? editWeight.numericValue : 0,
                            Number.isFinite(editReps.numericValue) ? editReps.numericValue : 0,
                            editFailure.checked,
                            editBodyweightMode.visible
                                ? editBodyweightMode.model[editBodyweightMode.currentIndex].value
                                : "Bodyweight")
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12
            NumberField { id: editWeight; Layout.fillWidth: true; label: qsTr("实际重量"); unit: "kg"; decimals: 2 }
            NumberField { id: editReps; Layout.fillWidth: true; label: qsTr("实际次数"); decimals: 0; keyboardHints: Qt.ImhDigitsOnly }
            ComboBox {
                id: editBodyweightMode
                Layout.fillWidth: true
                textRole: "label"
                model: [
                    {"label": qsTr("纯自重"), "value": "Bodyweight"},
                    {"label": qsTr("附加负重"), "value": "Added"},
                    {"label": qsTr("辅助重量"), "value": "Assisted"}
                ]
            }
            CheckBox { id: editFailure; text: qsTr("本组力竭") }
        }
    }

    Dialog {
        id: appendSetDialog
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

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("添加短休追加组")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            const exerciseIndex = page.exerciseIndexById(targetExerciseId)
            const setIndex = page.setIndexById(exerciseIndex, targetSetId)
            if (exerciseIndex >= 0 && setIndex >= 0) {
                workoutController.addAppendSet(
                            exerciseIndex,
                            setIndex,
                            Number.isFinite(appendWeight.numericValue) ? appendWeight.numericValue : 0,
                            Number.isFinite(appendReps.numericValue) ? appendReps.numericValue : 0,
                            appendRest.value,
                            appendFailure.checked)
            }
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
                SpinBox { id: appendRest; from: 0; to: 300; value: 5; editable: true }
            }
            CheckBox { id: appendFailure; text: qsTr("追加组力竭") }
        }
    }

    Dialog {
        id: timerDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("休息计时")
        standardButtons: Dialog.Close

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12
            RowLayout {
                Layout.fillWidth: true
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("2 分钟")
                    onClicked: {
                        restTimer.start(120)
                        timerDialog.close()
                    }
                }
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("3 分钟")
                    onClicked: {
                        restTimer.start(180)
                        timerDialog.close()
                    }
                }
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("5 分钟")
                    onClicked: {
                        restTimer.start(300)
                        timerDialog.close()
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: qsTr("自定义") }
                SpinBox { id: timerMinutes; from: 0; to: 59; value: 2; editable: true }
                Label { text: qsTr("分") }
                SpinBox { id: timerSeconds; from: 0; to: 59; value: 0; editable: true }
                Label { text: qsTr("秒") }
            }
            AppButton {
                Layout.fillWidth: true
                text: qsTr("开始计时")
                onClicked: {
                    restTimer.start(timerMinutes.value * 60 + timerSeconds.value)
                    timerDialog.close()
                }
            }
        }
    }

    Dialog {
        id: equipmentChoiceDialog
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

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(400, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("本次使用器械")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: {
            const index = page.exerciseIndexById(targetExerciseId)
            if (index >= 0) {
                const equipmentId = equipmentChoice.currentIndex >= 0
                        ? workoutController.equipment[equipmentChoice.currentIndex].id : ""
                workoutController.setExerciseEquipment(index, equipmentId)
            }
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

    Dialog {
        id: gymDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(380, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("新建健身房")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: workoutController.addGym(gymName.text)
        TextField {
            id: gymName
            anchors.fill: parent
            placeholderText: qsTr("例如：学校健身房")
        }
    }

    Dialog {
        id: equipmentDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(400, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("新建具体器械")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: workoutController.addEquipment(
                        equipmentName.text, equipmentCode.text, equipmentNotes.text)
        ColumnLayout {
            anchors.fill: parent
            TextField {
                id: equipmentName
                Layout.fillWidth: true
                placeholderText: qsTr("器械名称")
            }
            TextField {
                id: equipmentCode
                Layout.fillWidth: true
                placeholderText: qsTr("编号，例如 1 号")
            }
            TextField {
                id: equipmentNotes
                Layout.fillWidth: true
                placeholderText: qsTr("座椅档位、把手等，可选")
            }
        }
    }

    Dialog {
        id: exerciseNotesDialog
        property string targetExerciseId: ""

        function openForExercise(exerciseId) {
            targetExerciseId = exerciseId
            const index = page.exerciseIndexById(exerciseId)
            if (index < 0)
                return
            exerciseNotes.text = workoutController.exercises[index].notes
            open()
        }

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(400, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("动作备注")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: {
            const index = page.exerciseIndexById(targetExerciseId)
            if (index >= 0)
                workoutController.setExerciseNotes(index, exerciseNotes.text)
        }
        TextArea {
            id: exerciseNotes
            anchors.fill: parent
            wrapMode: TextEdit.Wrap
            placeholderText: qsTr("器械档位或本次感受，可选")
        }
    }

    Dialog {
        id: sessionNotesDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(400, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("训练备注")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: workoutController.setSessionNotes(sessionNotes.text)
        TextArea {
            id: sessionNotes
            anchors.fill: parent
            wrapMode: TextEdit.Wrap
            placeholderText: qsTr("本次训练备注，可选")
        }
    }

    Dialog {
        id: savePlanDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(400, Overlay.overlay.width - Design.Theme.space16 * 2)
        modal: true
        title: qsTr("保存为个人计划")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: workoutController.saveCurrentAsPlan(
                        savedPlanName.text, savedDayName.text, savedSectionName.text)
        ColumnLayout {
            anchors.fill: parent
            TextField {
                id: savedPlanName
                Layout.fillWidth: true
                placeholderText: qsTr("计划名称")
            }
            TextField {
                id: savedDayName
                Layout.fillWidth: true
                placeholderText: qsTr("训练日名称，例如 Push A")
            }
            TextField {
                id: savedSectionName
                Layout.fillWidth: true
                placeholderText: qsTr("动作分组名称，可选")
            }
        }
    }

    ConfirmDialog {
        id: discardWorkoutConfirm
        title: qsTr("放弃本次训练？")
        message: qsTr("本次训练和已经填写的组记录都会被删除，此操作无法撤销。")
        confirmText: qsTr("放弃训练")
        destructive: true
        onAccepted: workoutController.discardWorkout()
    }

    ConfirmDialog {
        id: discardUnfinishedConfirm
        title: qsTr("删除未完成训练？")
        message: qsTr("已经保存的组记录也会一并删除。")
        confirmText: qsTr("删除")
        destructive: true
        onAccepted: workoutController.discardUnfinished()
    }

    ConfirmDialog {
        id: removeExerciseConfirm
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
                        text: workoutController.active ? workoutController.sessionName : qsTr("训练")
                        color: Design.Theme.backgroundText
                        font.pixelSize: Design.Theme.typeTitle
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
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
                    glyph: "⋯"
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
                                onClicked: workoutController.startPlanDay(modelData.dayId)
                            }
                        }

                        AppButton {
                            Layout.fillWidth: true
                            variant: "secondary"
                            text: qsTr("自由训练")
                            onClicked: workoutController.startFreeWorkout("")
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
                            Label {
                                Layout.fillWidth: true
                                text: page.currentExercise ? page.currentExercise.name : ""
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeTitle
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
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
                                glyph: "⋯"
                                accessibleName: qsTr("当前动作更多操作")
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
                                        glyph: "＋"
                                        accessibleName: qsTr("添加短休追加组")
                                        onClicked: appendSetDialog.openForSet(
                                                       page.selectedExerciseId, modelData)
                                    }
                                    IconButton {
                                        glyph: "✎"
                                        accessibleName: qsTr("修正本组")
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
                                    visible: modelData.appendSets.length > 0
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
                        required property var modelData
                        required property int index
                        property int exerciseIndex: index

                        visible: workoutController.exercises.length > 1
                        Layout.fillWidth: true
                        implicitHeight: 60
                        radius: Design.Theme.radiusSmall
                        color: page.selectedExerciseId === modelData.id
                               ? Design.Theme.primaryContainer : Design.Theme.surface
                        border.width: 1
                        border.color: page.selectedExerciseId === modelData.id
                                      ? Design.Theme.primary : Design.Theme.outline
                        Drag.active: exerciseDrag.active
                        Drag.source: exerciseRow
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2
                        z: Drag.active ? 10 : 0

                        DropArea {
                            anchors.fill: parent
                            onDropped: function(drop) {
                                if (drop.source && drop.source !== exerciseRow)
                                    workoutController.moveExercise(
                                                drop.source.exerciseIndex, exerciseRow.exerciseIndex)
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Design.Theme.space12
                            anchors.rightMargin: Design.Theme.space4
                            spacing: Design.Theme.space8

                            IconButton {
                                glyph: "↕"
                                accessibleName: qsTr("拖动调整动作顺序")
                                DragHandler { id: exerciseDrag; target: exerciseRow }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Design.Theme.surfaceText
                                    font.pixelSize: Design.Theme.typeBody
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
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
                                glyph: "⋯"
                                accessibleName: qsTr("动作更多操作")
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

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8
                ColumnLayout {
                    Layout.fillWidth: true
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
                              ? qsTr("目标 %1 次").arg(page.currentSet.targetReps) : qsTr("填写实际次数")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                    }
                }
                AppButton {
                    Layout.preferredWidth: 82
                    variant: "secondary"
                    text: qsTr("计时")
                    onClicked: timerDialog.open()
                }
                CheckBox {
                    id: setFailure
                    visible: page.currentSet !== null
                    text: qsTr("力竭")
                }
            }

            RowLayout {
                visible: page.currentSet !== null
                Layout.fillWidth: true
                spacing: Design.Theme.space8
                NumberField {
                    id: setWeight
                    Layout.fillWidth: true
                    label: page.pureBodyweight ? qsTr("负重") : qsTr("实际重量")
                    placeholderText: page.pureBodyweight ? qsTr("纯自重") : qsTr("0")
                    unit: page.pureBodyweight ? "" : "kg"
                    decimals: 2
                    enabled: !page.pureBodyweight
                }
                NumberField {
                    id: setReps
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
                visible: page.currentSet !== null && page.currentIsBodyweight
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                textRole: "label"
                model: [
                    {"label": qsTr("纯自重，只记录次数"), "value": "Bodyweight"},
                    {"label": qsTr("附加负重"), "value": "Added"},
                    {"label": qsTr("辅助重量"), "value": "Assisted"}
                ]
                onCurrentIndexChanged: {
                    if (currentIndex === 0)
                        setWeight.text = ""
                }
            }

            AppButton {
                id: completeSetButton
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
