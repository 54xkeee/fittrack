import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"

ApplicationWindow {
    id: window
    width: 420
    height: 880
    minimumWidth: 360
    minimumHeight: 640
    visible: true
    title: qsTr("训迹 FitTrack")
    color: "#101314"
    font.family: Qt.platform.os === "windows" ? "Microsoft YaHei UI" : ""

    Material.theme: Material.Dark
    Material.accent: "#8BD450"
    Material.primary: "#171C19"

    StackLayout {
        objectName: "mainStack"
        anchors.fill: parent
        anchors.bottomMargin: navigation.height
        currentIndex: navigation.currentIndex

        HomePage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            onStartTrainingRequested: {
                if (!workoutController.active)
                    workoutController.startSuggestedDay()
                navigation.currentIndex = 2
            }
            onShowAnalysisRequested: navigation.currentIndex = 4
        }

        PlanPage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            onTrainingRequested: navigation.currentIndex = 2
        }

        TrainingPage { Layout.fillWidth: true; Layout.fillHeight: true }

        ExerciseLibraryPage { Layout.fillWidth: true; Layout.fillHeight: true }

        InsightsPage { Layout.fillWidth: true; Layout.fillHeight: true }
    }

    footer: TabBar {
        id: navigation
        objectName: "navigation"
        currentIndex: 0
        width: parent.width

        TabButton { width: navigation.width / 5; text: qsTr("首页") }
        TabButton { width: navigation.width / 5; text: qsTr("计划") }
        TabButton { width: navigation.width / 5; text: qsTr("训练") }
        TabButton { width: navigation.width / 5; text: qsTr("动作") }
        TabButton { width: navigation.width / 5; text: qsTr("分析") }
    }
}
