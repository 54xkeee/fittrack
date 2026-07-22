import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page
    implicitWidth: 0

    Component.onCompleted: analyticsDashboard.ensureLoaded()

    property string selectedMetric: "highestWeight"
    property bool filtersExpanded: false
    property bool showSecondaryMuscles: false

    readonly property bool hasStrengthData: Number(analyticsDashboard.overview.workoutCount || 0) > 0
    readonly property bool hasCardioData: Number(analyticsDashboard.overview.cardioCount || 0) > 0
    readonly property bool hasAnyData: hasStrengthData || hasCardioData

    function withAll(items, label) {
        let result = [{"id": "", "name": label}]
        for (let i = 0; i < items.length; ++i)
            result.push(items[i])
        return result
    }

    function sourceIndex(items, id) {
        for (let i = 0; i < items.length; ++i) {
            if (items[i].id === id)
                return i
        }
        return -1
    }

    function minutes(seconds) {
        return Math.round(Number(seconds || 0) / 60)
    }

    function compactVolume(value) {
        const amount = Number(value || 0)
        if (amount >= 10000)
            return (amount / 10000).toFixed(1) + qsTr(" 万kg")
        if (amount >= 1000)
            return (amount / 1000).toFixed(1) + qsTr(" 吨")
        return amount.toFixed(0) + " kg"
    }

    function metricTitle() {
        if (selectedMetric === "oneRepMax")
            return qsTr("估算 1RM 趋势")
        if (selectedMetric === "volume")
            return qsTr("单次训练容量趋势")
        return qsTr("最高重量趋势")
    }

    component SegmentButton: Button {
        id: segment
        property bool selected: false

        Layout.fillWidth: true
        implicitHeight: Design.Theme.touchTarget
        padding: 0
        font.pixelSize: Design.Theme.typeLabel
        font.weight: selected ? Font.DemiBold : Font.Normal
        Accessible.name: text

        contentItem: Label {
            text: segment.text
            color: segment.selected ? Design.Theme.primary : Design.Theme.textSecondary
            font: segment.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        background: Rectangle {
            radius: Design.Theme.radiusSmall
            color: segment.selected
                   ? Design.Theme.primarySoft
                   : (segment.down ? Design.Theme.surfacePressed : "transparent")
            border.width: segment.activeFocus || !segment.selected ? 1 : 0
            border.color: segment.activeFocus ? Design.Theme.primary
                                              : Design.Theme.borderDefault
        }
    }

    component SummaryTile: Rectangle {
        id: tile
        property string label: ""
        property string value: "--"
        property string detail: ""

        Layout.fillWidth: true
        Layout.preferredHeight: 94
        radius: Design.Theme.radiusSelection
        color: Design.Theme.surface
        border.width: 1
        border.color: Design.Theme.outlineVariant

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Design.Theme.space12
            spacing: Design.Theme.space4

            Label {
                text: tile.label
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
            }
            Label {
                Layout.fillWidth: true
                text: tile.value
                color: Design.Theme.surfaceText
                font.pixelSize: Design.Theme.typeTitle
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
            }
            Label {
                visible: tile.detail.length > 0
                Layout.fillWidth: true
                text: tile.detail
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
                elide: Text.ElideRight
            }
        }
    }

    ScrollView {
        id: analysisScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: analysisScroll.availableWidth
            spacing: Design.Theme.space16

            SectionHeader {
                Layout.fillWidth: true
                title: qsTr("训练趋势")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                SegmentButton {
                    text: qsTr("7 天")
                    selected: analyticsDashboard.periodDays === 7
                    onClicked: analyticsDashboard.setPeriodDays(7)
                }
                SegmentButton {
                    text: qsTr("30 天")
                    selected: analyticsDashboard.periodDays === 30
                    onClicked: analyticsDashboard.setPeriodDays(30)
                }
                SegmentButton {
                    text: qsTr("全部")
                    selected: analyticsDashboard.periodDays === -1
                    onClicked: analyticsDashboard.setPeriodDays(-1)
                }
            }

            AppEmptyState {
                visible: !page.hasAnyData
                Layout.fillWidth: true
                iconName: "analysis"
                title: qsTr("还没有可分析的数据")
                message: qsTr("完成一次力量训练或有氧记录后，这里会显示真实趋势。")
            }

            GridLayout {
                visible: page.hasAnyData
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Design.Theme.space8
                rowSpacing: Design.Theme.space8

                SummaryTile {
                    label: qsTr("力量训练")
                    value: String(analyticsDashboard.overview.workoutCount || 0) + qsTr(" 次")
                    detail: String(analyticsDashboard.overview.setCount || 0) + qsTr(" 个正式组")
                }
                SummaryTile {
                    label: qsTr("力量时长")
                    value: page.minutes(analyticsDashboard.overview.durationSeconds) + qsTr(" 分")
                }
                SummaryTile {
                    label: qsTr("训练容量")
                    value: page.compactVolume(analyticsDashboard.overview.totalVolume)
                }
                SummaryTile {
                    label: qsTr("有氧训练")
                    value: page.minutes(analyticsDashboard.overview.cardioDurationSeconds) + qsTr(" 分")
                    detail: String(analyticsDashboard.overview.cardioCount || 0) + qsTr(" 次记录")
                }
            }

            AppCard {
                visible: page.hasStrengthData
                Layout.fillWidth: true
                padding: Design.Theme.space16
                variant: "outlined"

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Design.Theme.space12

                    Label {
                        text: qsTr("本期力量表现")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Design.Theme.space16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Design.Theme.space4
                            Label {
                                text: Number(analyticsDashboard.overview.highestWeight || 0).toFixed(1) + " kg"
                                color: Design.Theme.primary
                                font.pixelSize: Design.Theme.typeTitle
                                font.weight: Font.Bold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: (analyticsDashboard.overview.highestExercise || qsTr("最高重量"))
                                      + qsTr(" · %1 次 · %2 组")
                                        .arg(analyticsDashboard.overview.highestReps || 0)
                                        .arg(analyticsDashboard.overview.highestSetCount || 0)
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeCaption
                                elide: Text.ElideRight
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: 48
                            color: Design.Theme.outline
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Design.Theme.space4
                            Label {
                                text: Number(analyticsDashboard.overview.bestOneRepMax || 0).toFixed(1) + " kg"
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeTitle
                                font.weight: Font.Bold
                            }
                            Label {
                                Layout.fillWidth: true
                                text: qsTr("最佳估算 1RM · ")
                                      + (analyticsDashboard.overview.bestOneRepMaxExercise || qsTr("暂无动作"))
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeCaption
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: page.hasStrengthData
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("肌群分布")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    Label {
                        text: qsTr("按已完成组统计")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space8
                    SegmentButton {
                        text: qsTr("主要刺激")
                        selected: !page.showSecondaryMuscles
                        onClicked: page.showSecondaryMuscles = false
                    }
                    SegmentButton {
                        text: qsTr("次要参与")
                        selected: page.showSecondaryMuscles
                        onClicked: page.showSecondaryMuscles = true
                    }
                }
                MuscleBars {
                    Layout.fillWidth: true
                    title: page.showSecondaryMuscles ? qsTr("次要参与组数") : qsTr("主要刺激组数")
                    items: page.showSecondaryMuscles
                           ? analyticsDashboard.secondaryMuscles
                           : analyticsDashboard.primaryMuscles
                }
            }

            ColumnLayout {
                visible: page.hasStrengthData
                Layout.fillWidth: true
                spacing: Design.Theme.space12

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("单动作趋势")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                    }
                    AppButton {
                        id: filterToggle
                        text: page.filtersExpanded ? qsTr("收起筛选") : qsTr("器械筛选")
                        variant: "text"
                        onClicked: page.filtersExpanded = !page.filtersExpanded
                    }
                }

                AppComboBox {
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                    model: analyticsDashboard.exercises
                    textRole: "name"
                    currentIndex: page.sourceIndex(analyticsDashboard.exercises,
                                                   analyticsDashboard.selectedExerciseId)
                    Accessible.name: qsTr("选择分析动作")
                    onActivated: analyticsDashboard.selectExercise(analyticsDashboard.exercises[currentIndex].id)
                }

                ColumnLayout {
                    visible: page.filtersExpanded
                    Layout.fillWidth: true
                    spacing: Design.Theme.space8

                    AppComboBox {
                        Layout.fillWidth: true
                        implicitHeight: Design.Theme.controlHeight
                        model: page.withAll(analyticsDashboard.gyms, qsTr("全部健身房"))
                        textRole: "name"
                        currentIndex: analyticsDashboard.gymFilterId.length === 0
                                      ? 0
                                      : page.sourceIndex(analyticsDashboard.gyms,
                                                         analyticsDashboard.gymFilterId) + 1
                        Accessible.name: qsTr("筛选健身房")
                        onActivated: analyticsDashboard.setGymFilter(model[currentIndex].id)
                    }
                    AppComboBox {
                        Layout.fillWidth: true
                        implicitHeight: Design.Theme.controlHeight
                        model: page.withAll(analyticsDashboard.equipment, qsTr("全部器械"))
                        textRole: "name"
                        currentIndex: analyticsDashboard.equipmentFilterId.length === 0
                                      ? 0
                                      : page.sourceIndex(analyticsDashboard.equipment,
                                                         analyticsDashboard.equipmentFilterId) + 1
                        Accessible.name: qsTr("筛选具体器械")
                        onActivated: analyticsDashboard.setEquipmentFilter(model[currentIndex].id)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space8
                    SegmentButton {
                        text: qsTr("最高重量")
                        selected: page.selectedMetric === "highestWeight"
                        onClicked: page.selectedMetric = "highestWeight"
                    }
                    SegmentButton {
                        text: qsTr("估算 1RM")
                        selected: page.selectedMetric === "oneRepMax"
                        onClicked: page.selectedMetric = "oneRepMax"
                    }
                    SegmentButton {
                        text: qsTr("训练容量")
                        selected: page.selectedMetric === "volume"
                        onClicked: page.selectedMetric = "volume"
                    }
                }

                TrendChart {
                    visible: analyticsDashboard.trend.length > 0
                    Layout.fillWidth: true
                    title: page.metricTitle()
                    points: analyticsDashboard.trend
                    metric: page.selectedMetric
                }

                AppCard {
                    visible: analyticsDashboard.trend.length === 0
                    Layout.fillWidth: true
                    padding: Design.Theme.space24

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space8
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("当前条件下暂无趋势")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeBody
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("更换动作或清除器械筛选后再试。至少完成一次该动作才会生成图表。")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: Design.Theme.space8 }
        }
    }
}
