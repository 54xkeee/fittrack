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
    title: qsTr("训迹")
    color: Design.Theme.background
    property real fontScale: 1.0
    property bool reducedMotion: Design.Preferences.reducedMotion
    Material.theme: Design.Theme.isDark ? Material.Dark : Material.Light
    Material.accent: Design.Theme.primary
    Material.primary: Design.Theme.surface
    property var pendingWorkoutRequest: ({})
    property int pendingInsightsTab: 0
    property int preparationSourceIndex: 0
    property int workoutSourceIndex: 0
    property string pendingCompletionSessionId: ""
    property string databaseRecoveryBackupPath: ""
    readonly property var loadedInsights: insightsLoader.item
    readonly property var feedbackHost: taskFeedbackHost
    readonly property var overlayHost: globalOverlayHost
    readonly property bool useReactTraining: reactTrainingEnabled
                                              && workoutController.active

    Component.onCompleted: {
        if (databaseRecoveryBackupPath.length > 0)
            Qt.callLater(databaseRecoveryDialog.open)
    }

    function ensureMainPage(index, insightsTab) {
        if (index === 1)
            planLoader.active = true
        else if (index === 2)
            trainingLoader.active = true
        else if (index === 3)
            exerciseLibraryLoader.active = true
        else if (index === 4) {
            if (!insightsLoader.active)
                pendingInsightsTab = insightsTab === undefined ? 0 : insightsTab
            insightsLoader.active = true
        }
    }

    Binding {
        target: Design.Theme
        property: "fontScale"
        value: Math.max(0.85, Math.min(2.0, window.fontScale))
    }

    Binding {
        target: Design.Typography
        property: "fontScale"
        value: Math.max(0.85, Math.min(2.0, window.fontScale))
    }

    Binding {
        target: Design.Theme
        property: "reducedMotion"
        value: window.reducedMotion
    }

    function presentWorkoutCompletion(sessionId) {
        pendingCompletionSessionId = String(sessionId || "")
        workoutCompletionLoader.active = true
        if (workoutCompletionLoader.completionPage)
            workoutCompletionLoader.openPendingCompletion()
    }

    OverlayHost {
        id: globalOverlayHost
    }

    TaskFeedbackHost {
        id: taskFeedbackHost
    }

    function handleBack() {
        if (workoutCompletionLoader.active && workoutCompletionLoader.completionPage)
            return workoutCompletionLoader.completionPage.handleBack()
        if (workoutController.preparing) {
            preparationPage.requestCancel()
            return true
        }
        if (navigation.currentIndex === 4 && loadedInsights
                && loadedInsights.handleBack())
            return true
        if (navigation.currentIndex === 0)
            return false
        navigation.currentIndex = 0
        mainStack.forceActiveFocus()
        return true
    }

    function handleBackEvent(event) {
        if (event.key === Qt.Key_Back && handleBack())
            event.accepted = true
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
        if (status === "prepared") {
            exerciseModel.ensureLoaded()
            planExerciseModel.ensureLoaded()
            return
        }
        handleStartResult(result)
    }

    function requestPlanDay(dayId, sourceIndex) {
        preparationSourceIndex = sourceIndex === undefined
                ? navigation.currentIndex : sourceIndex
        handlePreparationResult(workoutController.requestPreparePlanDay(dayId))
    }

    function requestFreeWorkout(name, sourceIndex) {
        preparationSourceIndex = sourceIndex === undefined
                ? navigation.currentIndex : sourceIndex
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
        preparationSourceIndex = navigation.currentIndex
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
        Keys.onReleased: event => window.handleBackEvent(event)

        HomePage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            onStartTrainingRequested: window.requestSuggestedOrContinue()
            onShowAnalysisRequested: navigation.currentIndex = 4
        }

        Loader {
            id: planLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            Layout.preferredWidth: 0
            Layout.preferredHeight: 0
            active: false
            sourceComponent: Component {
                PlanPage {
                    onTrainingRequested: dayId => window.requestPlanDay(dayId, 1)
                }
            }
        }

        Loader {
            id: trainingLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            Layout.preferredWidth: 0
            Layout.preferredHeight: 0
            active: false
            sourceComponent: window.useReactTraining
                             ? reactTrainingPageComponent
                             : nativeTrainingPageComponent
        }

        Component {
            id: nativeTrainingPageComponent
            TrainingPage {
                onPlanStartRequested: dayId => window.requestPlanDay(dayId, 2)
                onFreeStartRequested: name => window.requestFreeWorkout(name, 2)
                onCurrentPlanSaved: window.feedbackHost.show(qsTr("已保存为个人计划"))
            }
        }

        Component {
            id: reactTrainingPageComponent
            ReactTrainingPage { }
        }

        Loader {
            id: exerciseLibraryLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            Layout.preferredWidth: 0
            Layout.preferredHeight: 0
            active: false
            sourceComponent: Component {
                ExerciseLibraryPage {
                    onFeedbackRequested: message => window.feedbackHost.show(message)
                }
            }
        }

        Loader {
            id: insightsLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            Layout.preferredWidth: 0
            Layout.preferredHeight: 0
            active: false
            sourceComponent: Component {
                InsightsPage {
                    initialTab: window.pendingInsightsTab
                    onWorkoutSummaryDone: navigation.currentIndex = window.workoutSourceIndex
                    onFeedbackRequested: message => window.feedbackHost.show(message)
                }
            }
        }
    }

    Connections {
        target: workoutController
        function onWorkoutFinished(sessionId) {
            cardioController.setPendingSession(sessionId)
            workoutHistory.reload()
            window.presentWorkoutCompletion(sessionId)
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
        id: databaseRecoveryDialog
        objectName: "databaseRecoveryDialog"
        title: qsTr("数据库已安全恢复")
        primaryText: qsTr("知道了")
        secondaryVisible: false

        contentItem: Label {
            text: qsTr("检测到原数据库损坏。为避免覆盖数据，原文件已保留在：\n%1\n\nFitTrack 已创建全新数据库。若有 JSON 备份，可在“管理—备份与恢复”中导入。")
                  .arg(window.databaseRecoveryBackupPath)
            color: Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeBody
            wrapMode: Text.Wrap
            Accessible.name: text
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
        Keys.priority: Keys.AfterItem
        Keys.onReleased: event => window.handleBackEvent(event)
        onStartSucceeded: {
            window.workoutSourceIndex = window.preparationSourceIndex
            navigation.currentIndex = 2
        }
        onCancelled: navigation.currentIndex = window.preparationSourceIndex
        onPlanSaved: window.feedbackHost.show(qsTr("已保存为个人计划"))
    }

    Loader {
        id: workoutCompletionLoader
        anchors.fill: parent
        z: 1001
        active: false
        readonly property var completionPage: item
        function openPendingCompletion() {
            if (completionPage && window.pendingCompletionSessionId.length > 0) {
                completionPage.openCompletion(window.pendingCompletionSessionId)
                window.pendingCompletionSessionId = ""
            }
        }
        onLoaded: openPendingCompletion()
        sourceComponent: Component {
            HistoryPage {
                standaloneCompletion: true
                onCompletionDismissed: {
                    workoutCompletionLoader.active = false
                    cardioController.clearPendingSession()
                    navigation.currentIndex = window.workoutSourceIndex
                }
                onAddCardioRequested: {
                    workoutCompletionLoader.active = false
                    window.ensureMainPage(4, 1)
                    navigation.currentIndex = 4
                    const insights = window.loadedInsights
                    if (insights)
                        insights.openCardio()
                }
            }
        }
    }

    footer: AppNavigationBar {
        id: navigation
        objectName: "navigation"
        visible: !workoutController.preparing && !workoutController.active
                 && !Qt.inputMethod["visible"]
        currentIndex: 0
        items: [
            {"label": qsTr("首页"), "icon": "home"},
            {"label": qsTr("计划"), "icon": "plan"},
            {"label": qsTr("训练"), "icon": "training"},
            {"label": qsTr("动作"), "icon": "library"},
            {"label": qsTr("分析"), "icon": "analysis"}
        ]
        Keys.priority: Keys.AfterItem
        Keys.onReleased: event => window.handleBackEvent(event)
        onCurrentIndexChanged: window.ensureMainPage(currentIndex)
        onDestinationRequested: index => {
            currentIndex = index
            mainStack.forceActiveFocus()
        }
    }
}
