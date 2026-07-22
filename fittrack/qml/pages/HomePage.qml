import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page

    signal startTrainingRequested()
    signal showAnalysisRequested()

    readonly property var overview: analyticsDashboard.sevenDayOverview || ({})
    readonly property bool hasWorkoutData: Number(overview.workoutCount || 0) > 0
    readonly property bool hasCardioData: Number(overview.cardioCount || 0) > 0
                                          || cardioController.records.length > 0
    readonly property var latestWorkout: workoutHistory.sessions.length > 0
                                          ? workoutHistory.sessions[0] : ({})
    readonly property var latestCardio: cardioController.records.length > 0
                                        ? cardioController.records[0] : ({})
    readonly property bool canStartWorkout: workoutController.active
                                             || workoutController.hasUnfinished
                                             || workoutController.suggestedDay.dayId !== undefined

    component MetricTile: Item {
        id: metric
        property string label: ""
        property string value: qsTr("-")
        property string detail: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 100
        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space4

            Label {
                text: metric.label
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
            }
            Label {
                Layout.fillWidth: true
                text: metric.value
                color: Design.Theme.surfaceText
                font.pixelSize: Design.Theme.typeTitle
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Label {
                Layout.fillWidth: true
                text: metric.detail
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
                elide: Text.ElideRight
            }
        }
    }

    component ActivityRow: Item {
        id: activity
        property string marker: ""
        property color markerBackground: Design.Theme.surfaceElevated
        property color markerForeground: Design.Theme.surfaceText
        property string title: ""
        property string detail: ""

        implicitHeight: Design.Theme.touchTarget

        RowLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: Design.Theme.radiusSmall
                color: activity.markerBackground

                Label {
                    anchors.centerIn: parent
                    text: activity.marker
                    color: activity.markerForeground
                    font.pixelSize: Design.Theme.typeLabel
                    font.weight: Font.Bold
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space4
                Label {
                    Layout.fillWidth: true
                    text: activity.title
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeLabel
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Label {
                    Layout.fillWidth: true
                    text: activity.detail
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeCaption
                    elide: Text.ElideRight
                }
            }
        }
    }

    function beginOrResumeWorkout() {
        page.startTrainingRequested()
    }

    function compactWeight(value) {
        const weight = Number(value || 0)
        if (weight <= 0)
            return qsTr("-")
        return weight.toFixed(weight % 1 === 0 ? 0 : 1) + qsTr(" kg")
    }

    function compactVolume(value) {
        const volume = Number(value || 0)
        if (volume <= 0)
            return qsTr("-")
        if (volume >= 1000)
            return (volume / 1000).toFixed(1) + qsTr(" t")
        return Math.round(volume) + qsTr(" kg")
    }

    function workoutDateText(value) {
        if (!value)
            return ""
        const date = new Date(value)
        return isNaN(date.getTime()) ? "" : Qt.formatDateTime(date, qsTr("M月d日"))
    }

    function cardioName(record) {
        if (record.type === "TreadmillIncline")
            return qsTr("跑步机爬坡")
        if (record.type === "StairClimber")
            return qsTr("爬楼机")
        return qsTr("有氧训练")
    }

    function cardioDetail(record) {
        const parts = []
        if (Number(record.durationMinutes || 0) > 0)
            parts.push(qsTr("%1 分钟").arg(record.durationMinutes))
        if (record.type === "TreadmillIncline") {
            if (Number(record.incline || 0) > 0)
                parts.push(qsTr("坡度 %1").arg(record.incline))
            if (Number(record.speedKmh || 0) > 0)
                parts.push(qsTr("%1 km/h").arg(record.speedKmh))
        } else if (record.type === "StairClimber"
                   && Number(record.machineLevel || 0) > 0) {
            parts.push(qsTr("等级 %1").arg(record.machineLevel))
        }
        return parts.join(qsTr(" · "))
    }

    ScrollView {
        id: scroller
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: homeContent
            width: scroller.availableWidth
            spacing: Design.Theme.space16
            opacity: 0
            transform: Translate {
                id: homeEntrance
                y: Design.Theme.space12
            }

            ParallelAnimation {
                running: true
                NumberAnimation {
                    target: homeContent
                    property: "opacity"
                    to: 1
                    duration: Design.Theme.motionSlow
                    easing.type: Design.Theme.easingEnter
                }
                NumberAnimation {
                    target: homeEntrance
                    property: "y"
                    to: 0
                    duration: Design.Theme.motionSlow
                    easing.type: Design.Theme.easingEnter
                }
            }

            AppCard {
                Layout.fillWidth: true
                padding: Design.Theme.space20
                variant: "elevated"
                elevation: 2

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Design.Theme.space16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Design.Theme.space4

                        Label {
                            text: workoutController.active || workoutController.hasUnfinished
                                  ? qsTr("继续上次") : qsTr("下一训练日")
                            color: workoutController.active || workoutController.hasUnfinished
                                   ? Design.Theme.warning : Design.Theme.primary
                            font.pixelSize: Design.Theme.typeCaption
                            font.weight: Font.DemiBold
                        }

                        Label {
                            Layout.fillWidth: true
                            text: workoutController.active
                                  ? (workoutController.sessionName || qsTr("进行中的训练"))
                                  : workoutController.hasUnfinished
                                    ? qsTr("未完成训练")
                                    : (workoutController.suggestedDay.name
                                       || qsTr("暂无可用训练日"))
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeTitle
                            font.weight: Font.Bold
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: workoutController.active
                                  ? qsTr("已完成的组均已自动保存")
                                  : workoutController.hasUnfinished
                                    ? qsTr("恢复进度，继续完成剩余动作")
                                    : qsTr("谭成义三分化 · 训练前可替换动作")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                            wrapMode: Text.WordWrap
                        }
                    }

                    AppButton {
                        Layout.fillWidth: true
                        text: workoutController.active || workoutController.hasUnfinished
                              ? qsTr("继续训练") : qsTr("开始训练")
                        enabled: page.canStartWorkout
                        onClicked: page.beginOrResumeWorkout()
                    }
                }
            }

            InlineFeedback {
                Layout.fillWidth: true
                visible: workoutController.errorMessage.length > 0
                tone: "error"
                message: workoutController.errorMessage
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: page.hasWorkoutData
                spacing: Design.Theme.space8

                Label {
                    text: qsTr("最近 7 天")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeBody
                    font.weight: Font.DemiBold
                }

                AppCard {
                    Layout.fillWidth: true
                    padding: Design.Theme.space12
                    RowLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space8

                        MetricTile {
                            label: qsTr("最高重量")
                            value: page.compactWeight(page.overview.highestWeight)
                            detail: Number(page.overview.highestWeight || 0) > 0
                                    ? qsTr("%1 × %2").arg(page.overview.highestExercise)
                                                      .arg(page.overview.highestReps)
                                    : qsTr("暂无负重数据")
                        }

                        MetricTile {
                            label: qsTr("最佳 e1RM")
                            value: page.compactWeight(page.overview.bestOneRepMax)
                            detail: page.overview.bestOneRepMaxExercise || qsTr("暂无估算数据")
                        }

                        MetricTile {
                            label: qsTr("训练容量")
                            value: page.compactVolume(page.overview.totalVolume)
                            detail: qsTr("%1 次 · %2 组")
                                    .arg(page.overview.workoutCount || 0)
                                    .arg(page.overview.setCount || 0)
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                Label {
                    text: qsTr("最近活动")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeBody
                    font.weight: Font.DemiBold
                }

                AppCard {
                    Layout.fillWidth: true
                    visible: page.hasWorkoutData || page.hasCardioData
                    padding: Design.Theme.space16
                    variant: "filled"

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space12

                        ActivityRow {
                            Layout.fillWidth: true
                            marker: qsTr("力")
                            markerBackground: Design.Theme.primaryContainer
                            markerForeground: Design.Theme.primaryContainerText
                            title: page.latestWorkout.name || qsTr("暂无力量训练")
                            detail: page.latestWorkout.id !== undefined
                                    ? qsTr("%1 · %2 个动作 · %3 组")
                                      .arg(page.workoutDateText(page.latestWorkout.endedAt))
                                      .arg(page.latestWorkout.exerciseCount || 0)
                                      .arg(page.latestWorkout.setCount || 0)
                                    : qsTr("完成一次力量训练后在这里查看")
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: Design.Theme.outlineVariant
                        }

                        ActivityRow {
                            Layout.fillWidth: true
                            marker: qsTr("氧")
                            markerBackground: Design.Theme.infoContainer
                            markerForeground: Design.Theme.infoContent
                            title: page.latestCardio.id !== undefined
                                   ? page.cardioName(page.latestCardio)
                                   : qsTr("暂无有氧记录")
                            detail: page.latestCardio.id !== undefined
                                    ? page.cardioDetail(page.latestCardio)
                                    : qsTr("有氧为选填，不影响力量训练流程")
                        }

                        AppButton {
                            Layout.fillWidth: true
                            text: qsTr("查看详细分析")
                            variant: "text"
                            onClicked: page.showAnalysisRequested()
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 236
                    visible: !page.hasWorkoutData && !page.hasCardioData

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: Design.Theme.space8

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 176
                            Layout.preferredHeight: 144

                            Rectangle {
                                anchors.centerIn: parent
                                width: 132
                                height: 132
                                radius: 66
                                color: Design.Theme.primaryContainer
                                opacity: 0.42
                            }

                            Image {
                                anchors.fill: parent
                                source: "qrc:/images/illustrations/empty-workout.png"
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                Accessible.role: Accessible.Graphic
                                Accessible.name: qsTr("开始记录训练进度的插画")
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("还没有训练记录")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeBody
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }

                    }
                }
            }

            Item { Layout.preferredHeight: Design.Theme.space8 }
        }
    }
}
