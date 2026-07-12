import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

ScrollView {
    id: page
    implicitWidth: 0
    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    signal startTrainingRequested()
    signal showAnalysisRequested()

    function highestText() {
        const value = analyticsDashboard.sevenDayOverview
        return Number(value.highestWeight || 0) > 0
                ? value.highestExercise + " " + value.highestWeight + "kg × " + value.highestReps
                : qsTr("暂无")
    }

    function oneRepMaxText() {
        const value = Number(analyticsDashboard.sevenDayOverview.bestOneRepMax || 0)
        return value > 0 ? value.toFixed(1) + " kg" : qsTr("暂无")
    }

    clip: true
    background: Rectangle { color: "#0F0F0F" }

    ColumnLayout {
        width: page.availableWidth
        spacing: 14

        Item { Layout.preferredHeight: 18 }

        SectionHeader {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            eyebrow: qsTr("FITTRACK")
            title: qsTr("训迹")
            subtitle: qsTr("记录每一组，看见长期进步")
        }

        AppCard {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            padding: 18

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Label { text: qsTr("下一训练日"); color: "#A8AAA9"; font.pixelSize: 12 }
                        Label {
                            text: workoutController.suggestedDay.name || qsTr("暂无可用训练日")
                            color: "#F3F0EF"
                            font.pixelSize: 22
                            font.bold: true
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            text: qsTr("谭成义三分化")
                            color: "#FFB74D"
                            font.pixelSize: 12
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: 8
                        color: "#C5FF4A"
                        Label {
                            anchors.centerIn: parent
                            text: workoutController.active ? qsTr("续") : qsTr("练")
                            color: "#121212"
                            font.pixelSize: 22
                            font.bold: true
                        }
                    }
                }

                ActionPill {
                    Layout.fillWidth: true
                    text: workoutController.active ? qsTr("继续训练") : qsTr("开始训练")
                    accent: true
                    enabled: workoutController.active || workoutController.suggestedDay.dayId !== undefined
                    onClicked: page.startTrainingRequested()
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 16
            Layout.rightMargin: 16
            columns: 2
            rowSpacing: 10
            columnSpacing: 10

            StatCard {
                Layout.fillWidth: true
                label: qsTr("近7天训练")
                value: String(analyticsDashboard.sevenDayOverview.workoutCount || 0)
                footnote: qsTr("%1 个正式组").arg(analyticsDashboard.sevenDayOverview.setCount || 0)
            }
            StatCard {
                Layout.fillWidth: true
                label: qsTr("最高表现")
                value: highestText()
                accentColor: "#FFB74D"
            }
            StatCard {
                Layout.fillWidth: true
                label: qsTr("估算1RM")
                value: oneRepMaxText()
                footnote: analyticsDashboard.sevenDayOverview.bestOneRepMaxExercise || ""
            }
            StatCard {
                Layout.fillWidth: true
                label: qsTr("训练容量")
                value: Number(analyticsDashboard.sevenDayOverview.totalVolume || 0).toFixed(0) + " kg"
            }
            StatCard {
                Layout.fillWidth: true
                label: qsTr("有氧时长")
                value: Math.round(Number(analyticsDashboard.sevenDayOverview.cardioDurationSeconds || 0) / 60) + qsTr("分")
                footnote: qsTr("跑步机 / 爬楼机")
                accentColor: "#FFB74D"
            }
            AppCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 108
                padding: 16
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8
                    Label { text: qsTr("趋势"); color: "#A8AAA9"; font.pixelSize: 13 }
                    Label {
                        Layout.fillWidth: true
                        text: analyticsDashboard.sevenDayOverview.workoutCount > 0
                              ? qsTr("查看分析")
                              : qsTr("暂无数据")
                        color: "#F3F0EF"
                        font.pixelSize: 21
                        font.bold: true
                    }
                    Label {
                        text: qsTr("7天 / 30天 / 全部")
                        color: "#C5FF4A"
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: analyticsDashboard.sevenDayOverview.workoutCount > 0
                    onClicked: page.showAnalysisRequested()
                }
            }
        }

        Item { Layout.preferredHeight: 22 }
    }
}
