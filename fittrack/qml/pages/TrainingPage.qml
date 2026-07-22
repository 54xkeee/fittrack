import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page
    objectName: "trainingPage"

    leftPadding: (workoutController.active ? Design.WorkoutTheme.space16
                                           : Design.Theme.space12) + SafeArea.margins.left
    rightPadding: (workoutController.active ? Design.WorkoutTheme.space16
                                            : Design.Theme.space12) + SafeArea.margins.right
    topPadding: (workoutController.active ? Design.WorkoutTheme.space8
                                          : Design.Theme.space12) + SafeArea.margins.top

    Material.theme: Design.Theme.isDark ? Material.Dark : Material.Light
    background: Rectangle {
        color: workoutController.active ? Design.WorkoutTheme.background
                                        : Design.Theme.canvas
    }

    implicitWidth: 0
    implicitHeight: 0
    signal planStartRequested(string dayId)
    signal freeStartRequested(string name)
    signal currentPlanSaved()
    property string selectedExerciseId: ""
    property bool submittingSet: false
    property int sessionElapsedSeconds: 0
    readonly property var trainingExerciseModel: exerciseModel
    readonly property real inputMethodOverlap: {
        const keyboard = Qt.inputMethod.keyboardRectangle
        if (!Qt.inputMethod.visible || keyboard.height <= 0)
            return 0
        const coordinateScale = Qt.platform.os === "android"
                ? Math.max(1, Screen.devicePixelRatio) : 1
        const keyboardTop = keyboard.y / coordinateScale
        const pageBottom = page.mapToItem(null, 0, page.height).y
        return Math.max(0, Math.min(page.height, pageBottom - keyboardTop))
    }

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

    function completedExerciseVolume(exercise) {
        if (!exercise || !exercise.sets)
            return 0
        let volume = 0
        for (let index = 0; index < exercise.sets.length; ++index) {
            const set = exercise.sets[index]
            if (!set.completed || (exercise.loadMode === "Bodyweight"
                                   && set.bodyweightLoadType !== "Added"))
                continue
            volume += Number(set.weightKg || 0) * Number(set.actualReps || 0)
                    * (Boolean(set.bothSides) ? 2 : 1)
        }
        return volume
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
    }

    function gymIndex(gymId) {
        for (let i = 0; i < workoutController.gyms.length; ++i) {
            if (workoutController.gyms[i].id === gymId)
                return i
        }
        return -1
    }

    function openEquipmentChoice(exerciseId) {
        const index = exerciseIndexById(exerciseId)
        if (index < 0)
            return
        equipmentChoiceDialog.openForExercise(
                    exerciseId, String(workoutController.exercises[index].equipmentId || ""))
    }

    function previousText(sets) {
        if (!sets || sets.length === 0)
            return qsTr("暂无同器械历史")
        const values = []
        for (let i = 0; i < sets.length; ++i)
            values.push(Number(sets[i].weightKg) + " kg × " + sets[i].reps)
        return qsTr("上次：") + values.join("  ·  ")
    }

    function previousSetText(setIndex) {
        if (!currentExercise || !currentExercise.previousSets
                || setIndex < 0 || setIndex >= currentExercise.previousSets.length)
            return qsTr("—")
        const previous = currentExercise.previousSets[setIndex]
        return Number(previous.weightKg) + " × " + previous.reps
    }

    function completedSessionSets() {
        let count = 0
        const exercises = workoutController.exercises || []
        for (let exerciseIndex = 0; exerciseIndex < exercises.length; ++exerciseIndex)
            count += completedSetCount(exercises[exerciseIndex])
        return count
    }

    function completedSessionVolume() {
        let volume = 0
        const exercises = workoutController.exercises || []
        for (let exerciseIndex = 0; exerciseIndex < exercises.length; ++exerciseIndex) {
            const exercise = exercises[exerciseIndex]
            const sets = exercise.sets || []
            for (let setIndex = 0; setIndex < sets.length; ++setIndex) {
                const set = sets[setIndex]
                if (!set.completed || (exercise.loadMode === "Bodyweight"
                                       && set.bodyweightLoadType !== "Added"))
                    continue
                const sideFactor = Boolean(set.bothSides) ? 2 : 1
                volume += Number(set.weightKg || 0) * Number(set.actualReps || 0)
                        * sideFactor
            }
        }
        return volume
    }

    function compactVolume(value) {
        const volume = Number(value || 0)
        return volume >= 1000 ? (volume / 1000).toFixed(1) + qsTr(" t")
                              : Math.round(volume) + qsTr(" kg")
    }

    function sessionDurationText() {
        const seconds = Math.max(0, sessionElapsedSeconds)
        const hours = Math.floor(seconds / 3600)
        const minutes = Math.floor((seconds % 3600) / 60)
        const remainder = seconds % 60
        return hours > 0
                ? qsTr("%1时%2分").arg(hours).arg(minutes)
                : String(minutes).padStart(2, "0") + ":"
                  + String(remainder).padStart(2, "0")
    }

    function ensureSetRowVisible(rowItem) {
        if (!rowItem || !rowItem.visible || !trainingScroll.contentItem)
            return
        const flickable = trainingScroll.contentItem
        const mapped = rowItem.mapToItem(flickable, 0, 0)
        const currentY = Number(flickable.contentY || 0)
        const rowTop = mapped.y + currentY
        const rowBottom = rowTop + rowItem.height
        const viewportTop = currentY + Design.WorkoutTheme.space16
        const viewportBottom = currentY + flickable.height
                - Design.WorkoutTheme.space16
        let targetY = currentY
        if (rowTop < viewportTop)
            targetY = rowTop - Design.WorkoutTheme.space16
        else if (rowBottom > viewportBottom)
            targetY = rowBottom - flickable.height
                    + Design.WorkoutTheme.space16
        const maximumY = Math.max(0, Number(flickable.contentHeight || 0)
                                     - flickable.height)
        flickable.contentY = Math.max(0, Math.min(maximumY, targetY))
    }

    function findDescendantByObjectName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        const items = item.children || []
        for (let index = 0; index < items.length; ++index) {
            const match = findDescendantByObjectName(items[index], name)
            if (match)
                return match
        }
        return null
    }

    function ensureCurrentSetVisible() {
        ensureSetRowVisible(findDescendantByObjectName(
                                trainingScroll.contentItem,
                                "activeWorkoutSetRow"))
    }

    Timer {
        interval: 1000
        repeat: true
        running: workoutController.active
        onTriggered: page.sessionElapsedSeconds += 1
    }

    function compactSessionName(name) {
        const value = String(name || qsTr("训练"))
        const fullWidthSeparator = value.indexOf("｜")
        if (fullWidthSeparator > 0)
            return value.slice(0, fullWidthSeparator).trim()
        const separator = value.indexOf("|")
        return separator > 0 ? value.slice(0, separator).trim() : value
    }

    readonly property int currentExerciseIndex: exerciseIndexById(selectedExerciseId)
    readonly property var currentExercise: currentExerciseIndex >= 0
            ? workoutController.exercises[currentExerciseIndex] : null
    readonly property int currentSetIndex: firstIncompleteSetIndex(currentExercise)
    readonly property var currentSet: currentExercise && currentSetIndex >= 0
            ? currentExercise.sets[currentSetIndex] : null
    readonly property var currentExerciseDetail: currentExercise
            ? exerciseModel.exerciseById(currentExercise.exerciseId) : ({})
    readonly property var currentExerciseMedia: currentExerciseDetail.mediaItems
            && currentExerciseDetail.mediaItems.length > 0
            ? currentExerciseDetail.mediaItems[0] : ({})
    readonly property bool currentIsBodyweight: currentExercise
            && currentExercise.loadMode === "Bodyweight"
    // Keep the workout flow visible without turning every exercise into a
    // second editor.  The preview intentionally points at the next exercise
    // that still has work to do, while the current card remains in place.
    function nextPreviewExerciseId() {
        const items = workoutController.exercises || []
        if (currentExerciseIndex < 0 || items.length < 2)
            return ""
        for (let offset = 1; offset < items.length; ++offset) {
            const index = (currentExerciseIndex + offset) % items.length
            if (firstIncompleteSetIndex(items[index]) >= 0)
                return String(items[index].id || "")
        }
        return ""
    }

    readonly property string nextPreviewId: nextPreviewExerciseId()
    readonly property int nextPreviewIndex: exerciseIndexById(nextPreviewId)
    readonly property var nextPreviewExercise: nextPreviewIndex >= 0
            ? workoutController.exercises[nextPreviewIndex] : null
    readonly property var nextPreviewDetail: nextPreviewExercise
            ? exerciseModel.exerciseById(nextPreviewExercise.exerciseId) : ({})
    readonly property var nextPreviewMedia: nextPreviewDetail.mediaItems
            && nextPreviewDetail.mediaItems.length > 0
            ? nextPreviewDetail.mediaItems[0] : ({})
    readonly property bool allExercisesComplete: workoutController.active
            && workoutController.exercises.length > 0
            && nextIncompleteExerciseId(-1).length === 0

    Component.onCompleted: {
        exerciseModel.ensureLoaded()
        planExerciseModel.ensureLoaded()
        ensureExerciseSelection()
    }

    Connections {
        target: workoutController

        function onExercisesChanged() {
            page.submittingSet = false
            page.ensureExerciseSelection()
        }

        function onSessionChanged() {
            if (!workoutController.active)
                page.sessionElapsedSeconds = 0
            page.ensureExerciseSelection()
        }

        function onSetCompleted(restSeconds) {
            page.Accessible.announce(
                        restSeconds > 0
                        ? qsTr("本组已保存，已开始 %1 秒休息计时").arg(restSeconds)
                        : qsTr("本组已保存"),
                        Accessible.Polite)
            // Do not advance the visual focus automatically.  The current
            // exercise stays on screen so the user can review it; the compact
            // next-exercise preview below is updated by the model signal and
            // can be opened explicitly.
            if (restSeconds > 0)
                restTimer.start(restSeconds)
            Qt.callLater(page.ensureCurrentSetVisible)
        }
    }

    Connections {
        target: restTimer

        function onFinished() {
            page.Accessible.announce(qsTr("休息计时结束"), Accessible.Assertive)
        }
    }

    AppBottomSheet {
        id: sessionMenu
        objectName: "sessionActionsDialog"
        title: qsTr("训练操作")
        primaryText: qsTr("关闭")
        primaryVariant: "secondary"
        secondaryVisible: false
        initialFocusItem: addExerciseAction

        ColumnLayout {
            width: parent.width
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

    AppBottomSheet {
        id: exerciseActions
        objectName: "exerciseActionsDialog"
        property string targetExerciseId: ""
        title: qsTr("动作操作")
        primaryText: qsTr("关闭")
        primaryVariant: "secondary"
        secondaryVisible: false
        initialFocusItem: configureExerciseAction

        ColumnLayout {
            width: parent.width
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
                        page.openEquipmentChoice(exerciseActions.targetExerciseId)
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

    ExercisePickerSheet {
        id: exercisePicker
        objectName: "exercisePickerDialog"
        exerciseModel: page.trainingExerciseModel
        property string replaceExerciseId: ""
        property string oldBodyPart: ""
        property string oldMovement: ""
        property string oldEquipment: ""
        property bool oldFavoritesOnly: false

        function openForExercise(exerciseId) {
            replaceExerciseId = exerciseId
            oldBodyPart = page.trainingExerciseModel.bodyPart
            oldMovement = page.trainingExerciseModel.movementFilter
            oldEquipment = page.trainingExerciseModel.equipmentFilter
            oldFavoritesOnly = page.trainingExerciseModel.favoritesOnly
            page.trainingExerciseModel.bodyPart = ""
            page.trainingExerciseModel.movementFilter = ""
            page.trainingExerciseModel.equipmentFilter = ""
            page.trainingExerciseModel.favoritesOnly = false
            openPicker(replaceExerciseId.length > 0 ? "replace" : "add")
        }

        onDismissed: {
            page.trainingExerciseModel.bodyPart = oldBodyPart
            page.trainingExerciseModel.movementFilter = oldMovement
            page.trainingExerciseModel.equipmentFilter = oldEquipment
            page.trainingExerciseModel.favoritesOnly = oldFavoritesOnly
        }
        onPreviewRequested: exerciseId => sharedExerciseDetail.openExercise(
                                page.trainingExerciseModel.exerciseById(exerciseId))
        onExerciseSelected: exerciseId => {
            let success = false
            if (replaceExerciseId.length > 0) {
                const index = page.exerciseIndexById(replaceExerciseId)
                success = index >= 0 && workoutController.replaceExercise(index, exerciseId)
            } else {
                const exercise = page.trainingExerciseModel.exerciseById(exerciseId)
                success = workoutController.addExercise(
                            exerciseId,
                            Number(exercise.recommendedSets || 1),
                            String(exercise.recommendedReps || "8-12"))
            }
            if (success)
                close()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("动作更新失败，请重试。"))
        }
    }

    AppBottomSheet {
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
                close()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("训练组设置失败，请重试。"))
        }

        ScrollView {
            id: configureScroll
            width: parent.width
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

    AppBottomSheet {
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
                close()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("训练组修改失败，请重试。"))
        }

        ScrollView {
            id: editSetScroll
            width: parent.width
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
                AppComboBox {
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
                AppCheckBox {
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

    AppBottomSheet {
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
                close()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("目标次数保存失败，请重试。"))
        }

        title: qsTr("修改本组目标次数")
        primaryText: qsTr("保存目标")
        autoAccept: false
        initialFocusItem: targetRepsValue
        onPrimaryRequested: submit()

        ColumnLayout {
            width: parent.width
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

    AppBottomSheet {
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
                close()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("追加组保存失败，请重试。"))
        }

        ColumnLayout {
            width: parent.width
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
            AppCheckBox {
                id: appendFailure
                objectName: "appendSetFailureCheckBox"
                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                text: qsTr("追加组力竭")
            }
        }
    }

    EquipmentChoiceDialog {
        id: equipmentChoiceDialog
        objectName: "equipmentChoiceDialog"
        equipmentModel: workoutController.equipment
        canCreate: workoutController.selectedGymId.length > 0
        onSaveRequested: (exerciseId, equipmentId) => {
            const index = page.exerciseIndexById(exerciseId)
            const succeeded = index >= 0
                    && workoutController.setExerciseEquipment(index, equipmentId)
            if (succeeded)
                close()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("器械选择保存失败，请重试。"))
        }
        onCreateRequested: {
            equipmentName.text = ""
            equipmentCode.text = ""
            equipmentNotes.text = ""
            equipmentDialog.open()
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

    AppBottomSheet {
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

        title: qsTr("动作备注")
        primaryText: qsTr("保存备注")
        autoAccept: false
        initialFocusItem: exerciseNotes
        onPrimaryRequested: {
            const index = page.exerciseIndexById(targetExerciseId)
            const succeeded = index >= 0
                    && workoutController.setExerciseNotes(index, exerciseNotes.text)
            if (succeeded)
                close()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("动作备注保存失败，请重试。"))
        }
        TextArea {
            id: exerciseNotes
            width: parent.width
            implicitHeight: 112
            wrapMode: TextEdit.Wrap
            placeholderText: qsTr("器械档位或本次感受，可选")
            Accessible.name: qsTr("动作备注")
        }
    }

    AppBottomSheet {
        id: sessionNotesDialog
        objectName: "sessionNotesDialog"
        title: qsTr("训练备注")
        primaryText: qsTr("保存备注")
        autoAccept: false
        initialFocusItem: sessionNotes
        onPrimaryRequested: {
            if (workoutController.setSessionNotes(sessionNotes.text))
                close()
            else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("训练备注保存失败，请重试。"))
        }
        TextArea {
            id: sessionNotes
            width: parent.width
            implicitHeight: 112
            wrapMode: TextEdit.Wrap
            placeholderText: qsTr("本次训练备注，可选")
            Accessible.name: qsTr("训练备注")
        }
    }

    AppBottomSheet {
        id: savePlanDialog
        objectName: "savePlanDialog"
        title: qsTr("保存为个人计划")
        primaryText: qsTr("保存计划")
        primaryEnabled: savedPlanName.text.trim().length > 0
                        && savedDayName.text.trim().length > 0
        autoAccept: false
        initialFocusItem: savedPlanName
        onPrimaryRequested: {
            if (workoutController.saveCurrentAsPlan(
                        savedPlanName.text, savedDayName.text, savedSectionName.text)) {
                close()
                page.currentPlanSaved()
            } else
                showError(workoutController.errorMessage.length > 0
                          ? workoutController.errorMessage
                          : qsTr("个人计划保存失败，请重试。"))
        }
        ScrollView {
            id: savePlanFormScroll
            width: parent.width
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
            spacing: Design.Theme.space24

            WorkoutTopBar {
                visible: workoutController.active
                Layout.fillWidth: true
                progressText: qsTr("%1 · 第%2/%3个动作")
                              .arg(page.compactSessionName(workoutController.sessionName))
                              .arg(Math.max(0, page.currentExerciseIndex + 1))
                              .arg(workoutController.exercises.length)
                onBackRequested: sessionMenu.open()
                onTimerRequested: trainingRestTimer.open()
                onFinishRequested: {
                    if (page.allExercisesComplete)
                        workoutController.finishWorkout()
                    else
                        finishWorkoutConfirm.open()
                }
            }

            WorkoutSummaryBar {
                visible: workoutController.active
                Layout.fillWidth: true
                durationText: page.sessionDurationText()
                volumeText: page.compactVolume(page.completedSessionVolume())
                completedSets: page.completedSessionSets()
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

                        AppComboBox {
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
                                required property int index
                                Layout.fillWidth: true
                                variant: index === 0 ? "primary" : "secondary"
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
                spacing: Design.WorkoutTheme.space16

                InlineFeedback {
                    visible: workoutController.exercises.length === 0
                    Layout.fillWidth: true
                    tone: "info"
                    message: qsTr("还没有动作。先从动作库添加一个动作，再开始记录。")
                    actionText: qsTr("添加动作")
                    onActionTriggered: exercisePicker.openForExercise("")
                }

                // Keep one complete editor in the visual focus.  Other exercises are
                // intentionally represented by a single hand-off preview below instead
                // of a second set table.
                ExerciseCard {
                    id: currentExerciseCard
                    objectName: page.currentExerciseIndex >= 0
                               ? "trainingExerciseRow_" + page.currentExerciseIndex : ""
                    visible: page.currentExercise !== null
                    Layout.fillWidth: true
                    property var modelData: page.currentExercise
                    property int index: page.currentExerciseIndex
                    readonly property bool selected: true
                    readonly property var exerciseDetail: page.currentExerciseDetail
                    readonly property var exerciseMedia: page.currentExerciseMedia

                    active: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData
                                      ? qsTr("%1，已完成 %2 / %3 组")
                                        .arg(modelData.name)
                                        .arg(page.completedSetCount(modelData))
                                        .arg(modelData.sets.length)
                                      : ""

                    ExerciseHeader {
                        Layout.fillWidth: true
                        exerciseName: currentExerciseCard.modelData
                                      ? currentExerciseCard.modelData.name : ""
                        imageSource: currentExerciseCard.exerciseMedia.url || ""
                        setCount: currentExerciseCard.modelData
                                  ? currentExerciseCard.modelData.sets.length : 0
                        repsText: currentExerciseCard.modelData
                                  && currentExerciseCard.modelData.recommendedReps
                                  ? qsTr("%1次").arg(
                                        currentExerciseCard.modelData.recommendedReps)
                                  : qsTr("自定次数")
                        restSeconds: currentExerciseCard.modelData
                                     ? currentExerciseCard.modelData.restSeconds : 0
                        current: true
                        previewObjectName: "currentExercisePreviewButton"
                        onPreviewRequested: sharedExerciseDetail.openExercise(
                                                currentExerciseCard.exerciseDetail)
                        onOptionsRequested: {
                            if (!currentExerciseCard.modelData)
                                return
                            exerciseActions.targetExerciseId = currentExerciseCard.modelData.id
                            exerciseActions.open()
                        }
                    }

                    Label {
                        visible: currentExerciseCard.modelData
                                 && String(currentExerciseCard.modelData.notes || "").length > 0
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        text: currentExerciseCard.modelData
                              ? currentExerciseCard.modelData.notes || "" : ""
                        color: Design.WorkoutTheme.textSecondary
                        font.pixelSize: Design.WorkoutTheme.typeBody
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    RestTimerRow {
                        visible: currentExerciseCard.modelData !== null
                        Layout.fillWidth: true
                        Layout.topMargin: currentExerciseCard.modelData
                                          && String(currentExerciseCard.modelData.notes || "").length > 0
                                          ? 6 : 4
                        timerState: restTimer.state
                        remainingSeconds: restTimer.remainingSeconds
                        defaultSeconds: currentExerciseCard.modelData
                                        ? currentExerciseCard.modelData.restSeconds : 0
                        onConfigureRequested: trainingRestTimer.open()
                        onPauseRequested: restTimer.pause()
                        onResumeRequested: restTimer.resume()
                        onStopRequested: restTimer.reset()
                    }

                    Rectangle {
                        visible: currentExerciseCard.modelData !== null
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        implicitHeight: 1
                        color: Design.WorkoutTheme.divider
                    }

                    CurrentSetInputPanel {
                        id: cardSetInput
                        visible: currentExerciseCard.modelData !== null
                        Layout.fillWidth: true
                        exercise: currentExerciseCard.modelData
                        setData: page.currentSet
                        exerciseIndex: currentExerciseCard.index
                        setIndex: page.currentSetIndex
                        allExercisesComplete: page.allExercisesComplete
                        exerciseCount: workoutController.exercises.length
                        submitting: page.submittingSet
                        viewportWidth: page.width
                        onEditSetRequested: setData => editSetDialog.openForSet(
                                                    currentExerciseCard.modelData.id,
                                                    setData,
                                                    currentExerciseCard.modelData.loadMode)
                        onWeightAdjusted: (setIndex, weightKg) => {
                            if (!workoutController.setSetWeight(
                                        currentExerciseCard.index, setIndex, weightKg)) {
                                showError(workoutController.errorMessage.length > 0
                                          ? workoutController.errorMessage
                                          : qsTr("重量更新失败，请重试。"))
                            }
                        }
                        onCompleteRequested: (weightKg, reps, toFailure, loadType) => {
                            page.submittingSet = true
                            const success = workoutController.completeSet(
                                              currentExerciseCard.index,
                                              page.currentSetIndex,
                                              weightKg,
                                              reps,
                                              toFailure,
                                              loadType)
                            if (!success)
                                page.submittingSet = false
                        }
                    }

                    AddSetButton {
                        visible: currentExerciseCard.modelData !== null
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        onClicked: {
                            const defaults = cardSetInput.firstSetDefaults()
                            if (!workoutController.addSetFromFirstSet(
                                        currentExerciseCard.index,
                                        defaults.weightKg,
                                        defaults.reps)) {
                                showError(workoutController.errorMessage.length > 0
                                          ? workoutController.errorMessage
                                          : qsTr("添加训练组失败，请重试。"))
                            }
                        }
                    }
                }

                NextExercisePreview {
                    id: nextExercisePreview
                    objectName: page.nextPreviewIndex >= 0
                               ? "trainingExerciseRow_" + page.nextPreviewIndex : ""
                    visible: page.nextPreviewExercise !== null
                    Layout.fillWidth: true
                    exerciseName: page.nextPreviewExercise
                                  ? page.nextPreviewExercise.name : ""
                    imageSource: page.nextPreviewMedia.url || ""
                    setCount: page.nextPreviewExercise
                              ? page.nextPreviewExercise.sets.length : 0
                    repsText: page.nextPreviewExercise
                              && page.nextPreviewExercise.recommendedReps
                              ? qsTr("%1次").arg(page.nextPreviewExercise.recommendedReps)
                              : qsTr("自定次数")
                    restSeconds: page.nextPreviewExercise
                                 ? page.nextPreviewExercise.restSeconds : 0
                    completedSets: page.nextPreviewExercise
                                   ? page.completedSetCount(page.nextPreviewExercise) : 0
                    previewObjectName: page.nextPreviewIndex >= 0
                                       ? "trainingExercisePreviewButton_"
                                         + page.nextPreviewIndex : ""
                    onPreviewRequested: {
                        if (page.nextPreviewId.length > 0)
                            page.selectExercise(page.nextPreviewId)
                    }
                }

                AddSetButton {
                    Layout.fillWidth: true
                    text: qsTr("+ 添加动作")
                    onClicked: exercisePicker.openForExercise("")
                }
            }

            Item { Layout.preferredHeight: Design.Theme.space8 }
        }
    }

    TrainingRestTimer {
        id: trainingRestTimer
        x: -10000
        y: -10000
        timerState: restTimer.state
        remainingSeconds: restTimer.remainingSeconds
        backgroundAlertState: restTimer.backgroundAlertState
        onStartRequested: seconds => restTimer.start(seconds)
        onPauseRequested: restTimer.pause()
        onResumeRequested: restTimer.resume()
        onStopRequested: restTimer.reset()
        onPermissionRequested: restTimer.requestBackgroundAlertPermission()
        onSettingsRequested: restTimer.openBackgroundAlertSettings()
    }
}
