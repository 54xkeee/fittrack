import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page
    objectName: "historyPage"

    implicitWidth: 0
    property bool showDetails: false

    readonly property var selectedSession: workoutHistory.selectedSession || ({})
    readonly property bool hasSelectedSession: selectedSession.id !== undefined
                                                && String(selectedSession.id).length > 0

    function dateText(value) {
        const date = new Date(value)
        return isNaN(date.getTime()) ? String(value || "")
                                     : Qt.formatDateTime(date, "yyyy-MM-dd  hh:mm")
    }

    function muscleText(items) {
        if (!items || items.length === 0)
            return qsTr("暂无记录")

        let values = []
        for (let i = 0; i < items.length; ++i)
            values.push(items[i].name + " " + items[i].sets + qsTr("组"))
        return values.join("、")
    }

    function loadTypeIndex(value) {
        const normalized = String(value || "Bodyweight")
        for (let i = 0; i < editLoadType.model.length; ++i) {
            if (editLoadType.model[i].value === normalized)
                return i
        }
        return 0
    }

    function setLoadText(setData) {
        const weight = Number(setData.weightKg || 0)
        const type = String(setData.bodyweightLoadType || "Bodyweight")
        if (type === "Added")
            return qsTr("自重 + %1 kg").arg(weight)
        if (type === "Assisted")
            return qsTr("辅助 %1 kg").arg(weight)
        return weight > 0 ? qsTr("%1 kg").arg(weight) : qsTr("自重")
    }

    function appendSetText(items) {
        if (!items || items.length === 0)
            return ""

        let values = []
        for (let i = 0; i < items.length; ++i) {
            const item = items[i]
            values.push(qsTr("短休 %1 秒后 %2 kg × %3")
                        .arg(item.restSeconds).arg(Number(item.weightKg)).arg(item.reps))
        }
        return values.join("；")
    }

    function openSetEditor(setData) {
        editSetDialog.setId = String(setData.id || "")
        editWeight.text = String(Number(setData.weightKg || 0))
        editReps.text = String(Number(setData.reps || 0))
        editFailure.checked = Boolean(setData.toFailure)
        editLoadType.currentIndex = loadTypeIndex(setData.bodyweightLoadType)
        editSetDialog.open()
    }

    function openSession(sessionId) {
        if (workoutHistory.selectSession(sessionId))
            showDetails = true
    }

    function requestDeleteSelectedSession() {
        if (!hasSelectedSession)
            return
        deleteSessionDialog.sessionId = String(selectedSession.id)
        deleteSessionDialog.sessionName = String(selectedSession.name || qsTr("未命名训练"))
        deleteSessionDialog.open()
    }

    component MetricTile: Rectangle {
        id: metric

        property string label: ""
        property string value: ""
        property string detail: ""

        implicitHeight: 96
        radius: Design.Theme.radiusMedium
        color: Design.Theme.surface
        border.width: 1
        border.color: Design.Theme.outline

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Design.Theme.space12
            spacing: Design.Theme.space4

            Label {
                Layout.fillWidth: true
                text: metric.label
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
                elide: Text.ElideRight
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
                visible: metric.detail.length > 0
                text: metric.detail
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
                elide: Text.ElideRight
            }
        }
    }

    Dialog {
        id: editSetDialog

        property string setId: ""
        readonly property bool inputValid: setId.length > 0
                                                   && editWeight.text.trim().length > 0
                                                   && editReps.text.trim().length > 0
                                                   && editWeight.acceptableInput
                                                   && editReps.acceptableInput

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(392, Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 * 2 : 392)
        modal: true
        focus: true
        padding: Design.Theme.space24
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        title: qsTr("修正训练组")

        Overlay.modal: Rectangle { color: Design.Theme.scrim }

        background: Rectangle {
            color: Design.Theme.surface
            radius: Design.Theme.radiusLarge
            border.width: 1
            border.color: Design.Theme.outline
        }

        header: Label {
            text: editSetDialog.title
            color: Design.Theme.surfaceText
            font.pixelSize: Design.Theme.typeTitle
            font.weight: Font.DemiBold
            leftPadding: Design.Theme.space24
            rightPadding: Design.Theme.space24
            topPadding: Design.Theme.space24
        }

        contentItem: ColumnLayout {
            spacing: Design.Theme.space12

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                NumberField {
                    id: editWeight
                    Layout.fillWidth: true
                    label: qsTr("重量")
                    unit: "kg"
                    decimals: 2
                }

                NumberField {
                    id: editReps
                    Layout.fillWidth: true
                    label: qsTr("实际次数")
                    decimals: 0
                    keyboardHints: Qt.ImhDigitsOnly
                }
            }

            Label {
                text: qsTr("自重动作负荷方式")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
            }

            ComboBox {
                id: editLoadType

                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                textRole: "text"
                valueRole: "value"
                model: [
                    {"text": qsTr("纯自重 / 不适用"), "value": "Bodyweight"},
                    {"text": qsTr("自重 + 额外负重"), "value": "Added"},
                    {"text": qsTr("辅助重量"), "value": "Assisted"}
                ]
                Accessible.name: qsTr("自重动作负荷方式")
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("历史详情未提供动作负重模式；该选项直接修正已保存的自重负荷字段。")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
                wrapMode: Text.WordWrap
            }

            CheckBox {
                id: editFailure
                text: qsTr("本组力竭")
                Accessible.name: text
            }
        }

        footer: Item {
            implicitHeight: Design.Theme.controlHeight + Design.Theme.space24

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Design.Theme.space24
                anchors.rightMargin: Design.Theme.space24
                anchors.bottomMargin: Design.Theme.space24
                spacing: Design.Theme.space8

                AppButton {
                    text: qsTr("取消")
                    variant: "secondary"
                    Layout.fillWidth: true
                    onClicked: editSetDialog.close()
                }

                AppButton {
                    text: qsTr("保存修正")
                    Layout.fillWidth: true
                    enabled: editSetDialog.inputValid
                    onClicked: {
                        const loadType = editLoadType.currentIndex >= 0
                                ? editLoadType.model[editLoadType.currentIndex].value : "Bodyweight"
                        if (workoutHistory.updateCompletedSet(
                                editSetDialog.setId,
                                Number(editWeight.text.replace(",", ".")),
                                Number(editReps.text),
                                editFailure.checked,
                                loadType)) {
                            editSetDialog.close()
                        }
                    }
                }
            }
        }

        onOpened: editWeight.forceActiveFocus()
    }

    ConfirmDialog {
        id: deleteSessionDialog

        property string sessionId: ""
        property string sessionName: ""

        title: qsTr("删除这次训练？")
        message: qsTr("“%1”的动作、组记录和附加组都会被永久删除，此操作无法撤销。")
                 .arg(sessionName)
        confirmText: qsTr("删除训练")
        cancelText: qsTr("取消")
        destructive: true
        onAccepted: {
            if (workoutHistory.deleteSession(sessionId))
                page.showDetails = false
        }
    }

    Connections {
        target: workoutHistory

        function onSelectedSessionChanged() {
            if (!page.hasSelectedSession)
                page.showDetails = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.Theme.space12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Design.Theme.touchTarget
            spacing: Design.Theme.space8

            IconButton {
                visible: page.showDetails
                glyph: "‹"
                accessibleName: qsTr("返回训练历史")
                onClicked: page.showDetails = false
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Label {
                    Layout.fillWidth: true
                    text: page.showDetails ? qsTr("训练详情") : qsTr("训练历史")
                    color: Design.Theme.backgroundText
                    font.pixelSize: Design.Theme.typeTitle
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    visible: !page.showDetails
                    text: qsTr("共 %1 次已完成训练").arg(workoutHistory.sessions.length)
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeCaption
                }
            }
        }

        InlineFeedback {
            visible: workoutHistory.errorMessage.length > 0
            Layout.fillWidth: true
            tone: "error"
            message: workoutHistory.errorMessage
        }

        ScrollView {
            id: sessionListScroll

            visible: !page.showDetails
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: sessionListScroll.availableWidth
                spacing: Design.Theme.space8

                Item {
                    visible: workoutHistory.sessions.length === 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(360, sessionListScroll.availableHeight - Design.Theme.space24)

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - Design.Theme.space24 * 2, 300)
                        spacing: Design.Theme.space12

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 32
                            color: Design.Theme.surfaceElevated

                            Label {
                                anchors.centerIn: parent
                                text: "◷"
                                color: Design.Theme.primary
                                font.pixelSize: Design.Theme.typeDisplay
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("还没有训练历史")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeTitle
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("完成并保存一次训练后，这里会按时间展示记录。")
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Repeater {
                    model: workoutHistory.sessions

                    delegate: ItemDelegate {
                        id: sessionRow

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 84
                        leftPadding: Design.Theme.space16
                        rightPadding: Design.Theme.space12
                        topPadding: Design.Theme.space12
                        bottomPadding: Design.Theme.space12
                        Accessible.name: qsTr("查看 %1，%2").arg(modelData.name).arg(page.dateText(modelData.endedAt))
                        onClicked: page.openSession(modelData.id)

                        contentItem: RowLayout {
                            spacing: Design.Theme.space12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Design.Theme.space4

                                Label {
                                    Layout.fillWidth: true
                                    text: sessionRow.modelData.name || qsTr("未命名训练")
                                    color: Design.Theme.surfaceText
                                    font.pixelSize: Design.Theme.typeBody
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: page.dateText(sessionRow.modelData.endedAt)
                                          + "  ·  "
                                          + qsTr("%1 个动作  ·  %2 组")
                                            .arg(sessionRow.modelData.exerciseCount)
                                            .arg(sessionRow.modelData.setCount)
                                    color: Design.Theme.surfaceMuted
                                    font.pixelSize: Design.Theme.typeCaption
                                    elide: Text.ElideRight
                                }

                                Label {
                                    Layout.fillWidth: true
                                    visible: String(sessionRow.modelData.gymName || "").length > 0
                                    text: sessionRow.modelData.gymName
                                    color: Design.Theme.surfaceMuted
                                    font.pixelSize: Design.Theme.typeCaption
                                    elide: Text.ElideRight
                                }
                            }

                            Label {
                                text: "›"
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeTitle
                            }
                        }

                        background: Rectangle {
                            color: sessionRow.down ? Design.Theme.surfacePressed : Design.Theme.surface
                            radius: Design.Theme.radiusMedium
                            border.width: 1
                            border.color: Design.Theme.outline
                        }
                    }
                }

                Item { Layout.preferredHeight: Design.Theme.space8 }
            }
        }

        ScrollView {
            id: detailScroll

            visible: page.showDetails && page.hasSelectedSession
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: detailScroll.availableWidth
                spacing: Design.Theme.space12

                AppCard {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space8

                        Label {
                            Layout.fillWidth: true
                            text: page.selectedSession.name || qsTr("未命名训练")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeTitle
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.fillWidth: true
                            text: page.dateText(page.selectedSession.endedAt)
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.fillWidth: true
                            text: (page.selectedSession.gymName || qsTr("未指定场地"))
                                  + "  ·  " + (page.selectedSession.duration || qsTr("时长暂无"))
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            elide: Text.ElideRight
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    rowSpacing: Design.Theme.space8
                    columnSpacing: Design.Theme.space8

                    MetricTile {
                        Layout.fillWidth: true
                        label: qsTr("正式组")
                        value: String(page.selectedSession.setCount || 0)
                        detail: qsTr("%1 个动作").arg(page.selectedSession.exerciseCount || 0)
                    }

                    MetricTile {
                        Layout.fillWidth: true
                        label: qsTr("总容量")
                        value: qsTr("%1 kg").arg(Number(page.selectedSession.totalVolume || 0).toFixed(1))
                    }

                    MetricTile {
                        Layout.fillWidth: true
                        label: qsTr("最高重量")
                        value: Number(page.selectedSession.highestWeight || 0) > 0
                               ? qsTr("%1 kg × %2")
                                 .arg(page.selectedSession.highestWeight)
                                 .arg(page.selectedSession.highestWeightReps)
                               : qsTr("暂无")
                        detail: Number(page.selectedSession.highestWeight || 0) > 0
                                ? qsTr("%1 · %2 组")
                                  .arg(page.selectedSession.highestWeightExercise)
                                  .arg(page.selectedSession.highestWeightSetCount)
                                : ""
                    }

                    MetricTile {
                        Layout.fillWidth: true
                        label: qsTr("最佳 e1RM")
                        value: Number(page.selectedSession.bestOneRepMax || 0) > 0
                               ? qsTr("%1 kg").arg(Number(page.selectedSession.bestOneRepMax).toFixed(1))
                               : qsTr("暂无")
                        detail: Number(page.selectedSession.bestOneRepMax || 0) > 0
                                ? String(page.selectedSession.bestOneRepMaxExercise || "") : ""
                    }
                }

                AppCard {
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: Design.Theme.space8

                        Label {
                            text: qsTr("肌群统计")
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeBody
                            font.weight: Font.DemiBold
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("主要刺激：%1").arg(page.muscleText(page.selectedSession.primaryMuscles))
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeLabel
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("次要参与：%1").arg(page.muscleText(page.selectedSession.secondaryMuscles))
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            wrapMode: Text.WordWrap
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: String(page.selectedSession.notes || "").length > 0
                            text: qsTr("训练备注：%1").arg(page.selectedSession.notes)
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: qsTr("动作与训练组")
                    color: Design.Theme.backgroundText
                    font.pixelSize: Design.Theme.typeBody
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: page.selectedSession.exercises || []

                    delegate: AppCard {
                        id: exerciseCard

                        required property var modelData
                        property var exerciseData: modelData

                        Layout.fillWidth: true
                        padding: 0

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: Design.Theme.space16
                                Layout.rightMargin: Design.Theme.space16
                                Layout.topMargin: Design.Theme.space16
                                Layout.bottomMargin: Design.Theme.space12
                                spacing: Design.Theme.space4

                                Label {
                                    Layout.fillWidth: true
                                    text: exerciseCard.exerciseData.name
                                    color: Design.Theme.surfaceText
                                    font.pixelSize: Design.Theme.typeBody
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Label {
                                    Layout.fillWidth: true
                                    visible: String(exerciseCard.exerciseData.equipmentName || "").length > 0
                                    text: exerciseCard.exerciseData.equipmentName
                                    color: Design.Theme.surfaceMuted
                                    font.pixelSize: Design.Theme.typeCaption
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: qsTr("容量 %1 kg").arg(Number(exerciseCard.exerciseData.volume || 0).toFixed(1))
                                    color: Design.Theme.primary
                                    font.pixelSize: Design.Theme.typeLabel
                                    font.weight: Font.DemiBold
                                }

                                Label {
                                    Layout.fillWidth: true
                                    visible: String(exerciseCard.exerciseData.notes || "").length > 0
                                    text: exerciseCard.exerciseData.notes
                                    color: Design.Theme.surfaceMuted
                                    font.pixelSize: Design.Theme.typeCaption
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: Design.Theme.outline
                            }

                            Repeater {
                                model: exerciseCard.exerciseData.sets || []

                                delegate: ItemDelegate {
                                    id: setRow

                                    required property int index
                                    required property var modelData

                                    Layout.fillWidth: true
                                    implicitHeight: appendLabel.visible ? 76 : 56
                                    leftPadding: Design.Theme.space16
                                    rightPadding: Design.Theme.space8
                                    topPadding: Design.Theme.space8
                                    bottomPadding: Design.Theme.space8
                                    Accessible.name: qsTr("修正第 %1 组，%2，%3 次")
                                                     .arg(index + 1)
                                                     .arg(page.setLoadText(modelData))
                                                     .arg(modelData.reps)
                                    onClicked: page.openSetEditor(modelData)

                                    contentItem: RowLayout {
                                        spacing: Design.Theme.space8

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 16
                                            color: Design.Theme.surfaceElevated

                                            Label {
                                                anchors.centerIn: parent
                                                text: String(setRow.index + 1)
                                                color: Design.Theme.surfaceText
                                                font.pixelSize: Design.Theme.typeLabel
                                                font.weight: Font.DemiBold
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: Design.Theme.space4

                                            Label {
                                                Layout.fillWidth: true
                                                text: page.setLoadText(setRow.modelData)
                                                      + "  ×  " + setRow.modelData.reps
                                                      + (setRow.modelData.toFailure ? qsTr("  ·  力竭") : "")
                                                color: Design.Theme.surfaceText
                                                font.pixelSize: Design.Theme.typeLabel
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }

                                            Label {
                                                id: appendLabel
                                                Layout.fillWidth: true
                                                visible: String(text).length > 0
                                                text: page.appendSetText(setRow.modelData.appendSets)
                                                color: Design.Theme.surfaceMuted
                                                font.pixelSize: Design.Theme.typeCaption
                                                elide: Text.ElideRight
                                            }
                                        }

                                        IconButton {
                                            glyph: "✎"
                                            accessibleName: qsTr("修正第 %1 组").arg(setRow.index + 1)
                                            onClicked: page.openSetEditor(setRow.modelData)
                                        }
                                    }

                                    background: Rectangle {
                                        color: setRow.down ? Design.Theme.surfacePressed : "transparent"
                                    }
                                }
                            }
                        }
                    }
                }

                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("删除这次训练")
                    variant: "destructive"
                    onClicked: page.requestDeleteSelectedSession()
                }

                Item { Layout.preferredHeight: Design.Theme.space8 }
            }
        }
    }
}
