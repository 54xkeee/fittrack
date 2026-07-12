import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Page {
    id: page
    implicitWidth: 0
    background: Rectangle { color: "#0F0F0F" }

    property var sevenDay: {
        cardioController.records
        return cardioController.overview(7)
    }
    property var thirtyDay: {
        cardioController.records
        return cardioController.overview(30)
    }
    property var durationTrend: {
        let result = []
        for (let i = cardioController.records.length - 1; i >= 0; --i) {
            const item = cardioController.records[i]
            result.push({"date": item.performedAt, "durationMinutes": item.durationMinutes})
        }
        return result
    }
    property var heartRateTrend: {
        let result = []
        for (let i = cardioController.records.length - 1; i >= 0; --i) {
            const item = cardioController.records[i]
            if (item.averageHeartRate !== null && Number(item.averageHeartRate) > 0)
                result.push({"date": item.performedAt, "averageHeartRate": item.averageHeartRate})
        }
        return result
    }

    function optionalNumber(text) { return text.trim().length ? Number(text) : -1 }
    function optionalInt(text) { return text.trim().length ? Number(text) : -1 }

    Dialog {
        id: treadmillDialog
        anchors.centerIn: parent
        width: Math.min(page.width - 24, 430)
        title: qsTr("记录跑步机爬坡")
        standardButtons: Dialog.Save | Dialog.Cancel
        onOpened: {
            treadmillDuration.value = 30
            treadmillIncline.text = "9"
            treadmillSpeed.text = "5"
            treadmillDistance.text = ""
            treadmillHeart.text = ""
            treadmillNotes.text = ""
        }
        onAccepted: cardioController.addTreadmill(
            treadmillDuration.value, Number(treadmillIncline.text), Number(treadmillSpeed.text),
            page.optionalNumber(treadmillDistance.text), page.optionalInt(treadmillHeart.text),
            treadmillNotes.text)
        ColumnLayout {
            anchors.fill: parent
            RowLayout {
                Label { text: qsTr("时长（分钟）") }
                SpinBox { id: treadmillDuration; from: 1; to: 600; editable: true }
            }
            RowLayout {
                TextField { id: treadmillIncline; Layout.fillWidth: true; placeholderText: qsTr("坡度"); inputMethodHints: Qt.ImhFormattedNumbersOnly }
                TextField { id: treadmillSpeed; Layout.fillWidth: true; placeholderText: qsTr("速度 km/h"); inputMethodHints: Qt.ImhFormattedNumbersOnly }
            }
            RowLayout {
                TextField { id: treadmillDistance; Layout.fillWidth: true; placeholderText: qsTr("距离 km（选填）"); inputMethodHints: Qt.ImhFormattedNumbersOnly }
                TextField { id: treadmillHeart; Layout.fillWidth: true; placeholderText: qsTr("平均心率（选填）"); inputMethodHints: Qt.ImhDigitsOnly }
            }
            TextArea { id: treadmillNotes; Layout.fillWidth: true; placeholderText: qsTr("备注（选填）"); wrapMode: TextEdit.Wrap }
        }
    }

    Dialog {
        id: stairDialog
        anchors.centerIn: parent
        width: Math.min(page.width - 24, 430)
        title: qsTr("记录爬楼机")
        standardButtons: Dialog.Save | Dialog.Cancel
        onOpened: {
            stairDuration.value = 20
            stairLevel.text = ""
            stairFloors.text = ""
            stairSteps.text = ""
            stairHeart.text = ""
            stairNotes.text = ""
        }
        onAccepted: cardioController.addStairClimber(
            stairDuration.value, page.optionalNumber(stairLevel.text), page.optionalInt(stairFloors.text),
            page.optionalInt(stairSteps.text), page.optionalInt(stairHeart.text), stairNotes.text)
        ColumnLayout {
            anchors.fill: parent
            RowLayout {
                Label { text: qsTr("时长（分钟）") }
                SpinBox { id: stairDuration; from: 1; to: 600; editable: true }
            }
            RowLayout {
                TextField { id: stairLevel; Layout.fillWidth: true; placeholderText: qsTr("机器等级（选填）"); inputMethodHints: Qt.ImhFormattedNumbersOnly }
                TextField { id: stairFloors; Layout.fillWidth: true; placeholderText: qsTr("层数（选填）"); inputMethodHints: Qt.ImhDigitsOnly }
            }
            RowLayout {
                TextField { id: stairSteps; Layout.fillWidth: true; placeholderText: qsTr("步数（选填）"); inputMethodHints: Qt.ImhDigitsOnly }
                TextField { id: stairHeart; Layout.fillWidth: true; placeholderText: qsTr("平均心率（选填）"); inputMethodHints: Qt.ImhDigitsOnly }
            }
            TextArea { id: stairNotes; Layout.fillWidth: true; placeholderText: qsTr("备注（选填）"); wrapMode: TextEdit.Wrap }
        }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: page.width
            spacing: 12

            Item { Layout.preferredHeight: 14 }

            SectionHeader {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                eyebrow: qsTr("CARDIO")
                title: qsTr("有氧记录")
                subtitle: qsTr("爬坡机默认 9 / 5 / 30，爬楼机按等级和层数记录。")
            }

            AppCard {
                visible: cardioController.pendingSessionId.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                RowLayout {
                    anchors.fill: parent
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: qsTr("下一条有氧将关联到刚完成的力量训练")
                        color: "#F3F0EF"
                    }
                    ActionPill { text: qsTr("取消"); onClicked: cardioController.clearPendingSession() }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 10
                ActionPill { Layout.fillWidth: true; text: qsTr("跑步机爬坡"); accent: true; onClicked: treadmillDialog.open() }
                ActionPill { Layout.fillWidth: true; text: qsTr("爬楼机"); onClicked: stairDialog.open() }
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
                    label: qsTr("近7天")
                    value: qsTr("%1次").arg(page.sevenDay.count || 0)
                    footnote: qsTr("%1分钟").arg(page.sevenDay.durationMinutes || 0)
                }
                StatCard {
                    Layout.fillWidth: true
                    label: qsTr("近30天")
                    value: qsTr("%1次").arg(page.thirtyDay.count || 0)
                    footnote: qsTr("%1分钟").arg(page.thirtyDay.durationMinutes || 0)
                    accentColor: "#FFB74D"
                }
            }

            TrendChart {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                visible: page.durationTrend.length > 0
                title: qsTr("单次有氧时长")
                points: page.durationTrend
                metric: "durationMinutes"
                suffix: qsTr(" 分")
            }

            TrendChart {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                visible: page.heartRateTrend.length > 0
                title: qsTr("平均心率趋势")
                points: page.heartRateTrend
                metric: "averageHeartRate"
                suffix: " bpm"
            }

            Label {
                Layout.leftMargin: 16
                text: qsTr("历史记录")
                color: "#F3F0EF"
                font.pixelSize: 18
                font.bold: true
            }

            Label {
                visible: cardioController.records.length === 0
                Layout.leftMargin: 16
                text: qsTr("暂无有氧记录")
                color: "#A8AAA9"
            }

            Repeater {
                model: cardioController.records
                delegate: AppCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Label {
                                text: modelData.type === "TreadmillIncline" ? qsTr("跑步机爬坡") : qsTr("爬楼机")
                                color: "#F3F0EF"
                                font.bold: true
                                font.pixelSize: 17
                            }
                            Label {
                                color: "#A8AAA9"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                text: modelData.type === "TreadmillIncline"
                                      ? qsTr("%1分钟 · 坡度%2 · %3 km/h").arg(modelData.durationMinutes).arg(modelData.incline).arg(modelData.speedKmh)
                                      : qsTr("%1分钟%2%3").arg(modelData.durationMinutes)
                                          .arg(modelData.machineLevel === null ? "" : qsTr(" · 等级%1").arg(modelData.machineLevel))
                                          .arg(modelData.floors === null ? "" : qsTr(" · %1层").arg(modelData.floors))
                            }
                            Label {
                                visible: modelData.sessionName.length > 0
                                text: qsTr("关联：%1").arg(modelData.sessionName)
                                color: "#C5FF4A"
                            }
                        }

                        ToolButton {
                            text: qsTr("删除")
                            onClicked: cardioController.removeRecord(modelData.id)
                        }
                    }
                }
            }

            Label {
                visible: cardioController.errorMessage.length > 0
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.fillWidth: true
                color: "#FF8A80"
                text: cardioController.errorMessage
                wrapMode: Text.WordWrap
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
