import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page
    implicitWidth: 0
    leftPadding: SafeArea.margins.left
    rightPadding: SafeArea.margins.right
    topPadding: SafeArea.margins.top
    bottomPadding: SafeArea.margins.bottom

    Component.onCompleted: cardioController.ensureLoaded()

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
        const count = Math.min(cardioController.records.length, 30)
        for (let i = count - 1; i >= 0; --i) {
            const item = cardioController.records[i]
            result.push({"date": item.performedAt, "durationMinutes": item.durationMinutes})
        }
        return result
    }
    property var heartRateTrend: {
        let result = []
        const count = Math.min(cardioController.records.length, 30)
        for (let i = count - 1; i >= 0; --i) {
            const item = cardioController.records[i]
            if (item.averageHeartRate !== null && Number(item.averageHeartRate) > 0)
                result.push({"date": item.performedAt, "averageHeartRate": item.averageHeartRate})
        }
        return result
    }

    function optionalNumber(field) { return field.text.trim().length ? field.numericValue : -1 }
    function optionalInt(field) { return field.text.trim().length ? Math.round(field.numericValue) : -1 }

    ConfirmDialog {
        id: deleteRecordDialog
        property string recordId: ""
        title: qsTr("删除这条有氧记录？")
        message: qsTr("时长、设备参数和关联信息都会被永久删除。")
        confirmText: qsTr("删除记录")
        destructive: true
        onAccepted: cardioController.removeRecord(recordId)
    }

    Dialog {
        id: treadmillDialog
        property string formError: ""

        function submit() {
            formError = ""
            treadmillIncline.errorText = ""
            treadmillSpeed.errorText = ""
            treadmillDistance.errorText = ""
            treadmillHeart.errorText = ""

            if (!treadmillIncline.text.trim().length || !treadmillIncline.acceptableInput) {
                treadmillIncline.errorText = qsTr("请输入 0–30 之间的坡度")
            }
            if (!treadmillSpeed.text.trim().length || !treadmillSpeed.acceptableInput) {
                treadmillSpeed.errorText = qsTr("请输入大于 0、且不超过 30 km/h 的速度")
            }
            if (treadmillDistance.text.trim().length && !treadmillDistance.acceptableInput) {
                treadmillDistance.errorText = qsTr("距离必须大于 0、且不超过 1000 km")
            }
            if (treadmillHeart.text.trim().length && !treadmillHeart.acceptableInput) {
                treadmillHeart.errorText = qsTr("平均心率应为 30–250 bpm")
            }
            if (treadmillIncline.errorText.length || treadmillSpeed.errorText.length
                    || treadmillDistance.errorText.length || treadmillHeart.errorText.length) {
                formError = qsTr("请检查标出的有氧参数")
                return
            }

            const saved = cardioController.addTreadmill(
                treadmillDuration.value, treadmillIncline.numericValue, treadmillSpeed.numericValue,
                page.optionalNumber(treadmillDistance), page.optionalInt(treadmillHeart),
                treadmillNotes.text)
            if (!saved) {
                formError = cardioController.errorMessage.length
                    ? cardioController.errorMessage : qsTr("保存失败，请重试")
                return
            }
            treadmillIncline.text = ""
            treadmillSpeed.text = ""
            treadmillDistance.text = ""
            treadmillHeart.text = ""
            treadmillNotes.text = ""
            close()
        }

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(Overlay.overlay.width - Design.Theme.space16 * 2, 430)
        title: qsTr("记录跑步机爬坡")
        onOpened: {
            const target = cardioController.pendingTarget || {}
            const hasTarget = target.type === "TreadmillIncline"
            formError = ""
            treadmillDuration.value = hasTarget ? Number(target.durationMinutes) : 30
            treadmillIncline.text = hasTarget && target.incline !== null
                    ? String(target.incline) : "9"
            treadmillIncline.errorText = ""
            treadmillSpeed.text = hasTarget && target.speedKmh !== null
                    ? String(target.speedKmh) : "5"
            treadmillSpeed.errorText = ""
            treadmillDistance.text = ""
            treadmillDistance.errorText = ""
            treadmillHeart.text = ""
            treadmillHeart.errorText = ""
            treadmillNotes.text = hasTarget ? String(target.notes || "") : ""
        }
        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12
            RowLayout {
                Label { text: qsTr("时长（分钟）") }
                SpinBox { id: treadmillDuration; from: 1; to: 600; editable: true }
            }
            RowLayout {
                NumberField {
                    id: treadmillIncline
                    Layout.fillWidth: true
                    label: qsTr("坡度")
                    placeholderText: qsTr("例如 9")
                    from: 0
                    to: 30
                    decimals: 1
                }
                NumberField {
                    id: treadmillSpeed
                    Layout.fillWidth: true
                    label: qsTr("速度")
                    placeholderText: qsTr("例如 5")
                    unit: "km/h"
                    from: 0.1
                    to: 30
                    decimals: 1
                }
            }
            RowLayout {
                NumberField {
                    id: treadmillDistance
                    Layout.fillWidth: true
                    label: qsTr("距离（选填）")
                    unit: "km"
                    from: 0.01
                    to: 1000
                    decimals: 2
                }
                NumberField {
                    id: treadmillHeart
                    Layout.fillWidth: true
                    label: qsTr("平均心率（选填）")
                    unit: "bpm"
                    from: 30
                    to: 250
                    decimals: 0
                    keyboardHints: Qt.ImhDigitsOnly
                }
            }
            TextArea { id: treadmillNotes; Layout.fillWidth: true; placeholderText: qsTr("备注（选填）"); wrapMode: TextEdit.Wrap }
            InlineFeedback {
                visible: treadmillDialog.formError.length > 0
                Layout.fillWidth: true
                tone: "error"
                message: treadmillDialog.formError
            }
        }
        footer: Item {
            implicitHeight: Design.Theme.controlHeight + Design.Theme.space16
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space16
                anchors.rightMargin: Design.Theme.space16
                anchors.bottomMargin: Design.Theme.space8
                spacing: Design.Theme.space8
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("取消")
                    variant: "secondary"
                    onClicked: treadmillDialog.reject()
                }
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("保存")
                    onClicked: treadmillDialog.submit()
                }
            }
        }
    }

    Dialog {
        id: stairDialog
        property string formError: ""

        function submit() {
            formError = ""
            stairLevel.errorText = ""
            stairFloors.errorText = ""
            stairSteps.errorText = ""
            stairHeart.errorText = ""

            if (stairLevel.text.trim().length && !stairLevel.acceptableInput)
                stairLevel.errorText = qsTr("机器等级应为 1–100")
            if (stairFloors.text.trim().length && !stairFloors.acceptableInput)
                stairFloors.errorText = qsTr("层数应为 1–10000")
            if (stairSteps.text.trim().length && !stairSteps.acceptableInput)
                stairSteps.errorText = qsTr("步数应为 1–100000")
            if (stairHeart.text.trim().length && !stairHeart.acceptableInput)
                stairHeart.errorText = qsTr("平均心率应为 30–250 bpm")
            if (stairLevel.errorText.length || stairFloors.errorText.length
                    || stairSteps.errorText.length || stairHeart.errorText.length) {
                formError = qsTr("请检查标出的有氧参数")
                return
            }

            const saved = cardioController.addStairClimber(
                stairDuration.value, page.optionalNumber(stairLevel), page.optionalInt(stairFloors),
                page.optionalInt(stairSteps), page.optionalInt(stairHeart), stairNotes.text)
            if (!saved) {
                formError = cardioController.errorMessage.length
                    ? cardioController.errorMessage : qsTr("保存失败，请重试")
                return
            }
            stairLevel.text = ""
            stairFloors.text = ""
            stairSteps.text = ""
            stairHeart.text = ""
            stairNotes.text = ""
            close()
        }

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(Overlay.overlay.width - Design.Theme.space16 * 2, 430)
        title: qsTr("记录爬楼机")
        onOpened: {
            const target = cardioController.pendingTarget || {}
            const hasTarget = target.type === "StairClimber"
            formError = ""
            stairDuration.value = hasTarget ? Number(target.durationMinutes) : 20
            stairLevel.text = hasTarget && target.machineLevel !== null
                    ? String(target.machineLevel) : ""
            stairLevel.errorText = ""
            stairFloors.text = ""
            stairFloors.errorText = ""
            stairSteps.text = ""
            stairSteps.errorText = ""
            stairHeart.text = ""
            stairHeart.errorText = ""
            stairNotes.text = hasTarget ? String(target.notes || "") : ""
        }
        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12
            RowLayout {
                Label { text: qsTr("时长（分钟）") }
                SpinBox { id: stairDuration; from: 1; to: 600; editable: true }
            }
            RowLayout {
                NumberField {
                    id: stairLevel
                    Layout.fillWidth: true
                    label: qsTr("机器等级（选填）")
                    from: 1
                    to: 100
                    decimals: 0
                    keyboardHints: Qt.ImhDigitsOnly
                }
                NumberField {
                    id: stairFloors
                    Layout.fillWidth: true
                    label: qsTr("层数（选填）")
                    from: 1
                    to: 10000
                    decimals: 0
                    keyboardHints: Qt.ImhDigitsOnly
                }
            }
            RowLayout {
                NumberField {
                    id: stairSteps
                    Layout.fillWidth: true
                    label: qsTr("步数（选填）")
                    from: 1
                    to: 100000
                    decimals: 0
                    keyboardHints: Qt.ImhDigitsOnly
                }
                NumberField {
                    id: stairHeart
                    Layout.fillWidth: true
                    label: qsTr("平均心率（选填）")
                    unit: "bpm"
                    from: 30
                    to: 250
                    decimals: 0
                    keyboardHints: Qt.ImhDigitsOnly
                }
            }
            TextArea { id: stairNotes; Layout.fillWidth: true; placeholderText: qsTr("备注（选填）"); wrapMode: TextEdit.Wrap }
            InlineFeedback {
                visible: stairDialog.formError.length > 0
                Layout.fillWidth: true
                tone: "error"
                message: stairDialog.formError
            }
        }
        footer: Item {
            implicitHeight: Design.Theme.controlHeight + Design.Theme.space16
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space16
                anchors.rightMargin: Design.Theme.space16
                anchors.bottomMargin: Design.Theme.space8
                spacing: Design.Theme.space8
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("取消")
                    variant: "secondary"
                    onClicked: stairDialog.reject()
                }
                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("保存")
                    onClicked: stairDialog.submit()
                }
            }
        }
    }

    ScrollView {
        id: cardioScroll
        anchors.fill: parent
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: cardioScroll.availableWidth
            spacing: Design.Theme.space12

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
                        color: Design.Theme.surfaceText
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
                visible: cardioController.records.length > 0
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
                    accentColor: Design.Theme.warning
                }
            }

            TrendChart {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                visible: page.durationTrend.length > 0
                title: qsTr("最近 30 次有氧时长")
                points: page.durationTrend
                metric: "durationMinutes"
                suffix: qsTr(" 分")
            }

            TrendChart {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                visible: page.heartRateTrend.length > 0
                title: qsTr("最近 30 次平均心率")
                points: page.heartRateTrend
                metric: "averageHeartRate"
                suffix: " bpm"
            }

            Label {
                Layout.leftMargin: 16
                text: qsTr("历史记录")
                color: Design.Theme.backgroundText
                font.pixelSize: Design.Theme.typeBody
                font.weight: Font.DemiBold
            }

            AppCard {
                visible: cardioController.records.length === 0
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                padding: Design.Theme.space24

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Design.Theme.space8
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: "↗"
                        color: Design.Theme.primary
                        font.pixelSize: Design.Theme.typeDisplay
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("还没有有氧记录")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("选择跑步机爬坡或爬楼机，第一条记录会立即出现在这里。")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeLabel
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
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
                                color: Design.Theme.surfaceText
                                font.weight: Font.DemiBold
                                font.pixelSize: Design.Theme.typeBody
                            }
                            Label {
                                color: Design.Theme.surfaceMuted
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
                                color: Design.Theme.primary
                            }
                        }

                        IconButton {
                            glyph: "×"
                            destructive: true
                            accessibleName: qsTr("删除这条有氧记录")
                            onClicked: {
                                deleteRecordDialog.recordId = modelData.id
                                deleteRecordDialog.open()
                            }
                        }
                    }
                }
            }

            ActionPill {
                objectName: "cardioLoadMoreButton"
                visible: cardioController.hasMore
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                text: qsTr("加载更多记录")
                onClicked: cardioController.loadMore()
            }

            InlineFeedback {
                visible: cardioController.errorMessage.length > 0
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.fillWidth: true
                tone: "error"
                message: cardioController.errorMessage
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
