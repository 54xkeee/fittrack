import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "pages"
import "components"

ApplicationWindow {
    id: window
    width: 420
    height: 880
    minimumWidth: 360
    minimumHeight: 640
    visible: true
    title: qsTr("训迹 FitTrack")
    color: "#0F0F0F"
    Material.theme: Material.Dark
    Material.accent: "#C5FF4A"
    Material.primary: "#1A1A1A"

    StackLayout {
        objectName: "mainStack"
        anchors.fill: parent
        anchors.topMargin: 0
        currentIndex: navigation.currentIndex

        HomePage {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
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
            Layout.minimumWidth: 0
            onTrainingRequested: navigation.currentIndex = 2
        }

        TrainingPage { Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0 }

        ExerciseLibraryPage { Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumWidth: 0 }

        InsightsPage {
            id: insightsPage
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
        }
    }

    Connections {
        target: workoutController
        function onWorkoutFinished(sessionId) {
            cardioController.setPendingSession(sessionId)
            insightsPage.openCardio()
            navigation.currentIndex = 4
        }
    }

    footer: Rectangle {
        id: navigation
        objectName: "navigation"
        property int currentIndex: 0
        property var items: [
            {"label": qsTr("首页")},
            {"label": qsTr("计划")},
            {"label": qsTr("训练")},
            {"label": qsTr("动作")},
            {"label": qsTr("分析")}
        ]

        height: 72
        color: "#121212"
        border.width: 1
        border.color: "#242626"
        width: parent.width

        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            Repeater {
                model: navigation.items
                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: navigation.currentIndex === index ? "#C5FF4A" : "transparent"
                    border.width: navigation.currentIndex === index ? 0 : 1
                    border.color: "#2B2D2D"

                    Label {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: navigation.currentIndex === index ? "#121212" : "#DADADA"
                        font.pixelSize: 13
                        font.bold: navigation.currentIndex === index
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: navigation.currentIndex = index
                    }
                }
            }
        }
    }
}
