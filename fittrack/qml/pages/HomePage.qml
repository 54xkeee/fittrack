import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

ScrollView {
    signal startTrainingRequested()
    signal showAnalysisRequested()

    function highestText() {
        const value = analyticsDashboard.sevenDayOverview
        return Number(value.highestWeight || 0) > 0
                ? value.highestExercise + " " + value.highestWeight + "kg×" + value.highestReps
                : qsTr("暂无")
    }

    clip: true

    ColumnLayout {
        width: parent.width
        spacing: 16

        Item { Layout.preferredHeight: 8 }

        Label {
            Layout.leftMargin: 20
            text: qsTr("训迹 FitTrack")
            font.pixelSize: 28
            font.bold: true
        }

        Label {
            Layout.leftMargin: 20
            text: qsTr("记录每一组，看见长期进步")
            color: "#AEB7B1"
        }

        Frame {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            padding: 20

            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                Label { text: qsTr("下一训练日"); color: "#AEB7B1" }
                Label { text: qsTr("谭成义三分化"); font.pixelSize: 21; font.bold: true }
                Label {
                    text: workoutController.suggestedDay.name || qsTr("暂无可用训练日")
                    color: "#AEB7B1"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Button {
                    Layout.fillWidth: true
                    text: workoutController.active ? qsTr("继续训练") : qsTr("开始训练")
                    enabled: workoutController.active || workoutController.suggestedDay.dayId !== undefined
                    onClicked: startTrainingRequested()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 12

            StatCard {
                Layout.fillWidth: true
                label: qsTr("近7天训练")
                value: String(analyticsDashboard.sevenDayOverview.workoutCount || 0)
                footnote: qsTr("%1 个正式组").arg(analyticsDashboard.sevenDayOverview.setCount || 0)
            }
            StatCard { Layout.fillWidth: true; label: qsTr("最高表现"); value: highestText() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            spacing: 12

            StatCard {
                Layout.fillWidth: true
                label: qsTr("估算1RM")
                value: Number(analyticsDashboard.sevenDayOverview.bestOneRepMax || 0) > 0
                       ? Number(analyticsDashboard.sevenDayOverview.bestOneRepMax).toFixed(1) + " kg"
                       : qsTr("暂无")
                footnote: analyticsDashboard.sevenDayOverview.bestOneRepMaxExercise || ""
            }
            StatCard {
                Layout.fillWidth: true
                label: qsTr("训练容量")
                value: Number(analyticsDashboard.sevenDayOverview.totalVolume || 0).toFixed(0) + " kg"
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            text: analyticsDashboard.sevenDayOverview.workoutCount > 0
                  ? qsTr("更多趋势请查看分析页") : qsTr("完成训练后生成趋势")
            flat: true
            enabled: analyticsDashboard.sevenDayOverview.workoutCount > 0
            onClicked: showAnalysisRequested()
        }

        Item { Layout.preferredHeight: 20 }
    }
}
