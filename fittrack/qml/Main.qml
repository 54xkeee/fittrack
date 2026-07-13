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
    font.family: Qt.application.font.family
    Material.theme: Material.Dark
    Material.accent: Design.Theme.primary
    Material.primary: Design.Theme.surface

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
            {"label": qsTr("首页"), "glyph": "⌂"},
            {"label": qsTr("计划"), "glyph": "▣"},
            {"label": qsTr("训练"), "glyph": "+"},
            {"label": qsTr("动作"), "glyph": "◎"},
            {"label": qsTr("分析"), "glyph": "↗"}
        ]

        implicitHeight: 68 + SafeArea.margins.bottom
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

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    implicitHeight: Design.Theme.touchTarget
                    padding: 0
                    flat: true
                    Accessible.name: modelData.label
                    onClicked: navigation.currentIndex = index

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
