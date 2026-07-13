import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "pages"
import "components"
import "theme" as Design

ApplicationWindow {
    id: window
    width: 420
    height: 880
    minimumWidth: 360
    minimumHeight: 640
    visible: true
    title: qsTr("训迹 FitTrack")
    color: Design.Theme.background
    property real fontScale: 1.0
    Material.theme: Material.Dark
    Material.accent: Design.Theme.primary
    Material.primary: Design.Theme.surface
    property var pendingWorkoutRequest: ({})

    Binding {
        target: Design.Theme
        property: "fontScale"
        value: Math.max(0.85, Math.min(2.0, window.fontScale))
    }

    function handleBack() {
        if (workoutController.preparing) {
            preparationPage.requestCancel()
            return true
        }
        if (navigation.currentIndex === 4 && insightsPage.handleBack())
            return true
        if (navigation.currentIndex === 0)
            return false
        navigation.currentIndex = 0
        mainStack.forceActiveFocus()
        return true
    }

    function showStartError(message) {
        startErrorDialog.message = String(message || qsTr("无法开始训练，请重试"))
        startErrorDialog.open()
        workoutController.dismissError()
    }

    function handleStartResult(result) {
        const status = String(result.status || "error")
        if (status === "started") {
            navigation.currentIndex = 2
            return
        }
        if (status === "conflict") {
            pendingWorkoutRequest = result
            workoutStartConflictDialog.conflict = result
            workoutStartConflictDialog.open()
            return
        }
        if (status === "recoveryRequired") {
            workoutRecoveryDialog.open()
            return
        }
        showStartError(result.message)
    }

    function handlePreparationResult(result) {
        const status = String(result.status || "error")
        if (status === "prepared")
            return
        handleStartResult(result)
    }

    function requestPlanDay(dayId) {
        handlePreparationResult(workoutController.requestPreparePlanDay(dayId))
    }

    function requestFreeWorkout(name) {
        handlePreparationResult(workoutController.requestPrepareFreeWorkout(name || ""))
    }

    function requestSuggestedOrContinue() {
        if (workoutController.active || workoutController.hasUnfinished) {
            if (workoutController.sessionState === "RecoveryRequired")
                workoutRecoveryDialog.open()
            else if (workoutController.continueExistingWorkout())
                navigation.currentIndex = 2
            else
                showStartError(workoutController.errorMessage)
            return
        }
        handlePreparationResult(workoutController.requestPrepareSuggestedDay())
    }

    function switchPendingWorkout(discardCurrent) {
        const request = pendingWorkoutRequest || ({})
        if (Boolean(request.prepareAfterResolve)) {
            if (!workoutController.resolveCurrentWorkout(discardCurrent)) {
                workoutStartConflictDialog.showError(workoutController.errorMessage)
                return
            }
            workoutStartConflictDialog.close()
            pendingWorkoutRequest = ({})
            const result = request.requestedKind === "plan"
                    ? workoutController.requestPreparePlanDay(request.requestedTargetId)
                    : workoutController.requestPrepareFreeWorkout(request.requestedName || "")
            handlePreparationResult(result)
            return
        }
        const succeeded = request.requestedKind === "plan"
                ? workoutController.switchToPlanDay(request.requestedTargetId, discardCurrent)
                : workoutController.switchToFreeWorkout(request.requestedName || "", discardCurrent)
        if (!succeeded) {
            workoutStartConflictDialog.showError(workoutController.errorMessage)
            return
        }
        workoutStartConflictDialog.close()
        pendingWorkoutRequest = ({})
        navigation.currentIndex = 2
    }

    StackLayout {
        id: mainStack
        objectName: "mainStack"
        anchors.fill: parent
        anchors.topMargin: 0
        currentIndex: navigation.currentIndex
        focus: true
        Keys.priority: Keys.AfterItem
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Back && window.handleBack())
                event.accepted = true
        }

        HomePage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            onStartTrainingRequested: window.requestSuggestedOrContinue()
            onShowAnalysisRequested: navigation.currentIndex = 4
        }

        PlanPage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            onTrainingRequested: dayId => window.requestPlanDay(dayId)
        }

        TrainingPage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            onPlanStartRequested: dayId => window.requestPlanDay(dayId)
            onFreeStartRequested: name => window.requestFreeWorkout(name)
        }

        ExerciseLibraryPage { Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0 }

        InsightsPage {
            id: insightsPage
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            onWorkoutSummaryDone: navigation.currentIndex = 0
        }
    }

    Connections {
        target: workoutController
        function onWorkoutFinished(sessionId) {
            cardioController.setPendingSession(sessionId)
            workoutHistory.reload()
            navigation.currentIndex = 4
            if (!insightsPage.openWorkoutSummary(sessionId))
                insightsPage.openCardio()
        }
    }

    WorkoutStartConflictDialog {
        id: workoutStartConflictDialog
        onContinueRequested: {
            if (!workoutController.continueExistingWorkout()) {
                showError(workoutController.errorMessage)
                return
            }
            close()
            window.pendingWorkoutRequest = ({})
            navigation.currentIndex = 2
        }
        onSwitchRequested: discardCurrent => window.switchPendingWorkout(discardCurrent)
        onRejected: window.pendingWorkoutRequest = ({})
    }

    WorkoutRecoveryDialog {
        id: workoutRecoveryDialog
        sessions: workoutController.activeSessions
        onRecoveryRequested: (keepSessionId, discardOthers) => {
            if (!workoutController.recoverActiveSessions(keepSessionId, discardOthers)) {
                showError(workoutController.errorMessage)
                return
            }
            close()
            workoutHistory.reload()
            analyticsDashboard.reload()
            navigation.currentIndex = 2
        }
    }

    AppDialog {
        id: startErrorDialog
        objectName: "workoutStartErrorDialog"
        property string message: ""
        title: qsTr("无法开始训练")
        primaryText: qsTr("知道了")
        secondaryVisible: false

        contentItem: Label {
            text: startErrorDialog.message
            color: Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeBody
            wrapMode: Text.WordWrap
            Accessible.name: text
        }
    }

    WorkoutPreparationPage {
        id: preparationPage
        anchors.fill: parent
        visible: workoutController.preparing
        z: 1000
        onStartSucceeded: navigation.currentIndex = 2
        onCancelled: navigation.currentIndex = 0
    }

    footer: Rectangle {
        id: navigation
        objectName: "navigation"
        property int currentIndex: 0
        property var items: [
            {"label": qsTr("首页"), "glyph": "⌂"},
            {"label": qsTr("计划"), "glyph": "▣"},
            {"label": qsTr("训练"), "glyph": "+"},
            {"label": qsTr("动作"), "glyph": "◎"},
            {"label": qsTr("分析"), "glyph": "↗"}
        ]

        implicitHeight: Math.max(68,
                                 Design.Theme.typeBody + Design.Theme.typeCaption
                                 + Design.Theme.space12) + SafeArea.margins.bottom
        color: Design.Theme.surface
        border.width: 1
        border.color: Design.Theme.outline

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Design.Theme.space8 + SafeArea.margins.left
            anchors.rightMargin: Design.Theme.space8 + SafeArea.margins.right
            anchors.topMargin: Design.Theme.space4
            anchors.bottomMargin: Design.Theme.space4 + SafeArea.margins.bottom
            spacing: Design.Theme.space4

            Repeater {
                model: navigation.items
                delegate: Button {
                    id: navigationButton
                    required property var modelData
                    required property int index

                    function activate() {
                        navigation.currentIndex = index
                        mainStack.forceActiveFocus()
                    }

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: Design.Theme.touchTarget
                    padding: 0
                    flat: true
                    Accessible.name: modelData.label
                    Accessible.role: Accessible.PageTab
                    Accessible.selected: navigation.currentIndex === index
                    Accessible.onPressAction: activate()
                    onClicked: activate()

                    contentItem: ColumnLayout {
                        spacing: 0
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: navigationButton.modelData.glyph
                            color: navigation.currentIndex === navigationButton.index
                                   ? Design.Theme.primary : Design.Theme.surfaceMuted
                            font.pixelSize: navigationButton.index === 2
                                            ? Design.Theme.typeTitle : Design.Theme.typeBody
                            font.weight: Font.DemiBold
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: navigationButton.modelData.label
                            color: navigation.currentIndex === navigationButton.index
                                   ? Design.Theme.primary : Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                            font.weight: navigation.currentIndex === navigationButton.index
                                         ? Font.DemiBold : Font.Normal
                        }
                    }

                    background: Rectangle {
                        radius: Design.Theme.radiusSmall
                        color: navigation.currentIndex === navigationButton.index
                               ? Design.Theme.primaryContainer : "transparent"
                        border.width: navigationButton.activeFocus ? 1 : 0
                        border.color: Design.Theme.primary
                    }
                }
            }
        }
    }
}
