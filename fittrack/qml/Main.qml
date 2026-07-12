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

    Material.theme: Material.Dark
    Material.accent: "#8BD450"
    Material.primary: "#171C19"

    StackLayout {
        anchors.fill: parent
        anchors.bottomMargin: navigation.height
        currentIndex: navigation.currentIndex

        HomePage {
            onStartTrainingRequested: {
                if (!workoutController.active)
                    workoutController.startSuggestedDay()
                navigation.currentIndex = 1
            }
            onShowAnalysisRequested: navigation.currentIndex = 4
        }

        TrainingPage {}

        ExerciseLibraryPage {}

        HistoryPage {}

        AnalysisPage {}
    }

    footer: TabBar {
        id: navigation
        currentIndex: 0

        TabButton { text: qsTr("首页") }
        TabButton { text: qsTr("训练") }
        TabButton { text: qsTr("动作") }
        TabButton { text: qsTr("历史") }
        TabButton { text: qsTr("分析") }
    }
}
