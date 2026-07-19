import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

ColumnLayout {
    id: root

    property var exercise: null
    property var setData: null
    property int exerciseIndex: -1
    property int setIndex: -1
    property bool allExercisesComplete: false
    property int exerciseCount: 0
    property bool submitting: false
    property real viewportWidth: width
    property bool firstDraftCaptured: false
    property real firstDraftWeight: NaN
    property real firstDraftReps: NaN

    readonly property bool currentIsBodyweight: exercise
            && exercise.loadMode === "Bodyweight"
    readonly property bool pureBodyweight: currentIsBodyweight
            && bodyweightMode.currentIndex === 0

    signal completeRequested(real weightKg, int reps, bool toFailure, string loadType)
    signal editSetRequested(var setData)
    signal weightAdjusted(int setIndex, real weightKg)

    function firstSetDefaults() {
        if (!root.exercise || !root.exercise.sets || root.exercise.sets.length === 0)
            return {"weightKg": null, "reps": null}
        const first = root.exercise.sets[0]
        const sourceReps = Boolean(first.completed) ? first.actualReps : first.targetReps
        const useDraft = root.setIndex === 0 && root.firstDraftCaptured
        const storedWeight = first.weightKg === null || first.weightKg === undefined
                ? NaN : Number(first.weightKg)
        const storedReps = sourceReps === null || sourceReps === undefined
                ? NaN : Number(sourceReps)
        const draftWeight = useDraft ? root.firstDraftWeight : storedWeight
        const draftReps = useDraft ? root.firstDraftReps : storedReps
        return {
            "weightKg": Number.isFinite(draftWeight) ? draftWeight : null,
            "reps": Number.isFinite(draftReps) ? draftReps : null
        }
    }

    function initialWeightText(setItem) {
        if (!setItem || setItem.weightKg === undefined || setItem.weightKg === null
                || !Number.isFinite(Number(setItem.weightKg)))
            return ""
        return String(Number(setItem.weightKg))
    }

    function initialRepsText(setItem) {
        if (!setItem || setItem.targetReps === undefined || setItem.targetReps === null
                || !Number.isFinite(Number(setItem.targetReps)))
            return ""
        return String(Number(setItem.targetReps))
    }

    function previousSetText(index) {
        if (!root.exercise || !root.exercise.previousSets
                || index < 0 || index >= root.exercise.previousSets.length)
            return qsTr("—")
        const previous = root.exercise.previousSets[index]
        return Number(previous.weightKg) + " × " + previous.reps
    }

    onSetDataChanged: {
        if (!root.setData)
            return
        bodyweightMode.currentIndex = root.setData.bodyweightLoadType === "Added" ? 1
                : root.setData.bodyweightLoadType === "Assisted" ? 2 : 0
    }

    spacing: 0

    SetTableHeader {
        Layout.fillWidth: true
    }

    Repeater {
        id: setRows
        model: root.exercise ? root.exercise.sets : []

        delegate: WorkoutSetRow {
            id: setRow
            required property var modelData
            required property int index
            readonly property string rowState: Boolean(modelData.completed)
                    ? "completed" : (index === root.setIndex ? "active" : "pending")

            Layout.fillWidth: true
            objectName: rowState === "active" ? "activeWorkoutSetRow" : ""
            state: rowState
            setNumber: modelData.number
            previousText: root.previousSetText(index)
            repsText: modelData.completed
                      ? String(modelData.actualReps) + (modelData.toFailure ? "*" : "")
                      : (modelData.targetReps === undefined || modelData.targetReps === null
                         ? qsTr("—") : String(modelData.targetReps))
            weightInputText: root.initialWeightText(modelData)
            repsInputText: rowState === "active"
                           ? root.initialRepsText(modelData) : ""
            weightPlaceholder: rowState === "active" ? "0" : qsTr("—")
            repsPlaceholder: modelData.targetReps === undefined
                             || modelData.targetReps === null
                             ? qsTr("次数") : String(modelData.targetReps)
            pureBodyweight: root.pureBodyweight
            submitting: root.submitting
            onDraftChanged: (weightKg, reps) => {
                if (index !== 0)
                    return
                root.firstDraftCaptured = true
                root.firstDraftWeight = weightKg
                root.firstDraftReps = reps
            }
            onWeightAdjusted: weightKg => root.weightAdjusted(index, weightKg)
            onCompleteRequested: (weightKg, reps) => {
                const loadType = root.currentIsBodyweight
                        ? bodyweightMode.model[bodyweightMode.currentIndex].value
                        : "Bodyweight"
                root.completeRequested(weightKg, reps, false, loadType)
            }
            onEditRequested: root.editSetRequested(modelData)
        }
    }

    AppComboBox {
        id: bodyweightMode
        objectName: "bodyweightModeSelector"
        visible: root.setData !== null && root.currentIsBodyweight
        Layout.fillWidth: true
        Layout.topMargin: Design.WorkoutTheme.space8
        implicitHeight: Design.Theme.controlHeight
        textRole: "label"
        model: [
            {"label": qsTr("纯自重，只记录次数"), "value": "Bodyweight"},
            {"label": qsTr("附加负重"), "value": "Added"},
            {"label": qsTr("辅助重量"), "value": "Assisted"}
        ]
        Accessible.name: qsTr("自重动作负荷方式")
        onCurrentIndexChanged: {
            if (currentIndex !== 0)
                return
            const row = setRows.itemAt(root.setIndex)
            if (row)
                row.weightInputText = ""
        }
    }
}
