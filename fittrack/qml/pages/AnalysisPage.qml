import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Page {
    id: page
    implicitWidth: 0
    background: Rectangle { color: "#0F0F0F" }

    function withAll(items, label) {
        let result = [{"id":"", "name":label}]
        for (let i = 0; i < items.length; ++i) result.push(items[i])
        return result
    }

    function sourceIndex(items, id) {
        for (let i = 0; i < items.length; ++i) if (items[i].id === id) return i
        return -1
    }

    header: ToolBar {
        Label { anchors.centerIn: parent; text: qsTr("数据分析"); font.pixelSize: 18; font.bold: true }
    }

    ScrollView {
        id: analysisScroll
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
            width: analysisScroll.availableWidth
            spacing: 12
            Item { Layout.preferredHeight: 4 }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                Button { Layout.fillWidth: true; text: qsTr("7天"); highlighted: analyticsDashboard.periodDays === 7; onClicked: analyticsDashboard.setPeriodDays(7) }
                Button { Layout.fillWidth: true; text: qsTr("30天"); highlighted: analyticsDashboard.periodDays === 30; onClicked: analyticsDashboard.setPeriodDays(30) }
                Button { Layout.fillWidth: true; text: qsTr("全部"); highlighted: analyticsDashboard.periodDays === -1; onClicked: analyticsDashboard.setPeriodDays(-1) }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                columns: 2
                StatCard { Layout.fillWidth: true; label: qsTr("训练次数"); value: String(analyticsDashboard.overview.workoutCount || 0) }
                StatCard { Layout.fillWidth: true; label: qsTr("正式组"); value: String(analyticsDashboard.overview.setCount || 0) }
                StatCard { Layout.fillWidth: true; label: qsTr("总容量"); value: Number(analyticsDashboard.overview.totalVolume || 0).toFixed(0) + " kg" }
                StatCard { Layout.fillWidth: true; label: qsTr("训练时长"); value: Math.round(Number(analyticsDashboard.overview.durationSeconds || 0) / 60) + qsTr("分") }
                StatCard { Layout.fillWidth: true; label: qsTr("有氧次数"); value: String(analyticsDashboard.overview.cardioCount || 0) }
                StatCard { Layout.fillWidth: true; label: qsTr("有氧时长"); value: Math.round(Number(analyticsDashboard.overview.cardioDurationSeconds || 0) / 60) + qsTr("分") }
            }

            MuscleBars { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; title: qsTr("主要刺激组数"); items: analyticsDashboard.primaryMuscles }
            MuscleBars { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; title: qsTr("次要参与组数"); items: analyticsDashboard.secondaryMuscles }

            Label { Layout.leftMargin: 18; text: qsTr("单动作趋势"); font.pixelSize: 20; font.bold: true }
            ComboBox {
                Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14
                model: analyticsDashboard.exercises; textRole: "name"
                currentIndex: sourceIndex(analyticsDashboard.exercises, analyticsDashboard.selectedExerciseId)
                onActivated: analyticsDashboard.selectExercise(analyticsDashboard.exercises[currentIndex].id)
            }
            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14
                ComboBox {
                    Layout.fillWidth: true
                    model: withAll(analyticsDashboard.gyms, qsTr("全部健身房")); textRole: "name"
                    currentIndex: analyticsDashboard.gymFilterId.length === 0
                                  ? 0 : sourceIndex(analyticsDashboard.gyms, analyticsDashboard.gymFilterId) + 1
                    onActivated: analyticsDashboard.setGymFilter(model[currentIndex].id)
                }
                ComboBox {
                    Layout.fillWidth: true
                    model: withAll(analyticsDashboard.equipment, qsTr("全部器械")); textRole: "name"
                    currentIndex: analyticsDashboard.equipmentFilterId.length === 0
                                  ? 0 : sourceIndex(analyticsDashboard.equipment, analyticsDashboard.equipmentFilterId) + 1
                    onActivated: analyticsDashboard.setEquipmentFilter(model[currentIndex].id)
                }
            }

            Label {
                visible: analyticsDashboard.trend.length === 0
                Layout.fillWidth: true
                text: qsTr("当前条件下暂无动作记录")
                horizontalAlignment: Text.AlignHCenter
                color: "#AEB7B1"
            }
            TrendChart { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; title: qsTr("最高重量"); points: analyticsDashboard.trend; metric: "highestWeight" }
            TrendChart { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; title: qsTr("估算 1RM"); points: analyticsDashboard.trend; metric: "oneRepMax" }
            TrendChart { Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; title: qsTr("训练容量"); points: analyticsDashboard.trend; metric: "volume" }
            Item { Layout.preferredHeight: 20 }
        }
    }
}
