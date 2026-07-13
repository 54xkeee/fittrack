import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme" as Design

AppPage {
    id: page

    implicitWidth: 0
    signal trainingRequested()

    readonly property bool hasSelectedPlan: planManagement.selectedPlan.id !== undefined
                                             && String(planManagement.selectedPlan.id).length > 0
    readonly property bool selectedPlanReadOnly: hasSelectedPlan
                                                   && Boolean(planManagement.selectedPlan.isReadOnly)

    function openTextDialog(mode, targetId, currentValue) {
        textDialog.mode = mode
        textDialog.targetId = targetId || ""
        valueInput.text = currentValue || ""
        textDialog.open()
    }

    function submitTextDialog() {
        const value = valueInput.text
        let succeeded = false
        if (textDialog.mode === "createPlan")
            succeeded = planManagement.createPlan(value)
        else if (textDialog.mode === "copyPlan")
            succeeded = planManagement.copyPlan(textDialog.targetId, value)
        else if (textDialog.mode === "renamePlan")
            succeeded = planManagement.renamePlan(textDialog.targetId, value)
        else if (textDialog.mode === "addDay")
            succeeded = planManagement.addDay(textDialog.targetId, value)
        else
            succeeded = planManagement.renameDay(textDialog.targetId, value)

        if (succeeded)
            textDialog.close()
    }

    function requestDelete(kind, targetId, displayName) {
        deleteDialog.kind = kind
        deleteDialog.targetId = targetId
        deleteDialog.displayName = displayName || ""
        deleteDialog.open()
    }

    Dialog {
        id: textDialog

        property string mode: "createPlan"
        property string targetId: ""

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(392, Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 * 2 : 392)
        modal: true
        focus: true
        padding: Design.Theme.space24
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        title: mode === "createPlan" ? qsTr("新建计划")
             : mode === "copyPlan" ? qsTr("复制为个人版")
             : mode === "renamePlan" ? qsTr("重命名计划")
             : mode === "addDay" ? qsTr("添加训练日") : qsTr("重命名训练日")

        Overlay.modal: Rectangle { color: Design.Theme.scrim }

        background: Rectangle {
            color: Design.Theme.surface
            radius: Design.Theme.radiusLarge
            border.width: 1
            border.color: Design.Theme.outline
        }

        header: Label {
            text: textDialog.title
            color: Design.Theme.surfaceText
            font.pixelSize: Design.Theme.typeTitle
            font.weight: Font.DemiBold
            leftPadding: Design.Theme.space24
            rightPadding: Design.Theme.space24
            topPadding: Design.Theme.space24
        }

        contentItem: ColumnLayout {
            spacing: Design.Theme.space12

            Label {
                visible: textDialog.mode === "copyPlan"
                text: qsTr("系统原版保持不变。新副本会完整保留训练日、动作顺序与训练参数。")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            TextField {
                id: valueInput

                Layout.fillWidth: true
                implicitHeight: Design.Theme.controlHeight
                placeholderText: qsTr("请输入名称")
                color: Design.Theme.surfaceText
                font.pixelSize: Design.Theme.typeBody
                selectByMouse: true
                onAccepted: page.submitTextDialog()
                background: Rectangle {
                    color: Design.Theme.surfaceElevated
                    radius: Design.Theme.radiusSmall
                    border.width: valueInput.activeFocus ? 2 : 1
                    border.color: valueInput.activeFocus ? Design.Theme.primary : Design.Theme.outline
                }
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
                    onClicked: textDialog.close()
                }

                AppButton {
                    text: textDialog.mode === "copyPlan" ? qsTr("复制计划") : qsTr("保存")
                    Layout.fillWidth: true
                    enabled: valueInput.text.trim().length > 0
                    onClicked: page.submitTextDialog()
                }
            }
        }

        onOpened: {
            valueInput.forceActiveFocus()
            valueInput.selectAll()
        }
    }

    ConfirmDialog {
        id: deleteDialog

        property string kind: "plan"
        property string targetId: ""
        property string displayName: ""

        title: kind === "plan" ? qsTr("删除个人计划？")
             : kind === "day" ? qsTr("删除训练日？") : qsTr("删除动作？")
        message: kind === "plan"
                 ? qsTr("“%1”及其中全部训练日都会被删除，历史训练记录不受影响。").arg(displayName)
                 : kind === "day"
                   ? qsTr("“%1”及其中全部动作都会从该计划移除。").arg(displayName)
                   : qsTr("“%1”会从当前训练日移除。").arg(displayName)
        confirmText: qsTr("删除")
        cancelText: qsTr("取消")
        destructive: true
        onAccepted: {
            if (kind === "plan")
                planManagement.deletePlan(targetId)
            else if (kind === "day")
                planManagement.deleteDay(targetId)
            else
                planManagement.removeExercise(targetId)
        }
    }

    Dialog {
        id: actionPicker

        property string dayId: ""

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(440, Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 * 2 : 440)
        height: Math.min(680, Overlay.overlay ? Overlay.overlay.height - Design.Theme.space24 * 2 : 680)
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape

        Overlay.modal: Rectangle { color: Design.Theme.scrim }

        background: Rectangle {
            color: Design.Theme.surface
            radius: Design.Theme.radiusLarge
            border.width: 1
            border.color: Design.Theme.outline
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Design.Theme.space16
                Layout.rightMargin: Design.Theme.space8
                Layout.topMargin: Design.Theme.space12
                Layout.bottomMargin: Design.Theme.space8
                spacing: Design.Theme.space8

                Label {
                    text: qsTr("添加动作")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeTitle
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                IconButton {
                    glyph: "×"
                    accessibleName: qsTr("关闭动作选择")
                    onClicked: actionPicker.close()
                }
            }

            TextField {
                id: exerciseSearch

                Layout.fillWidth: true
                Layout.leftMargin: Design.Theme.space16
                Layout.rightMargin: Design.Theme.space16
                Layout.bottomMargin: Design.Theme.space12
                implicitHeight: Design.Theme.controlHeight
                placeholderText: qsTr("搜索动作或部位")
                color: Design.Theme.surfaceText
                font.pixelSize: Design.Theme.typeBody
                onTextChanged: planExerciseModel.searchText = text
                background: Rectangle {
                    color: Design.Theme.surfaceElevated
                    radius: Design.Theme.radiusSmall
                    border.width: exerciseSearch.activeFocus ? 2 : 1
                    border.color: exerciseSearch.activeFocus ? Design.Theme.primary : Design.Theme.outline
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Design.Theme.outline
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: planExerciseModel
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: ItemDelegate {
                    required property string exerciseId
                    required property string name
                    required property string bodyPart

                    width: ListView.view.width
                    implicitHeight: 60
                    leftPadding: Design.Theme.space16
                    rightPadding: Design.Theme.space16
                    onClicked: {
                        if (planManagement.addExercise(actionPicker.dayId, exerciseId))
                            actionPicker.close()
                    }
                    contentItem: RowLayout {
                        spacing: Design.Theme.space12

                        ColumnLayout {
                            spacing: Design.Theme.space4
                            Layout.fillWidth: true

                            Label {
                                text: name
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeBody
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Label {
                                text: bodyPart
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeCaption
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Label {
                            text: "+"
                            color: Design.Theme.primary
                            font.pixelSize: Design.Theme.typeTitle
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Label {
                    anchors.centerIn: parent
                    visible: parent.count === 0
                    text: qsTr("没有匹配的动作")
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeLabel
                }
            }
        }

        onClosed: {
            exerciseSearch.text = ""
            planExerciseModel.searchText = ""
        }
    }

    Dialog {
        id: actionEditor

        property string planExerciseId: ""

        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        width: Math.min(392, Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 * 2 : 392)
        modal: true
        focus: true
        padding: Design.Theme.space24
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        Overlay.modal: Rectangle { color: Design.Theme.scrim }

        background: Rectangle {
            color: Design.Theme.surface
            radius: Design.Theme.radiusLarge
            border.width: 1
            border.color: Design.Theme.outline
        }

        header: Label {
            text: qsTr("调整动作参数")
            color: Design.Theme.surfaceText
            font.pixelSize: Design.Theme.typeTitle
            font.weight: Font.DemiBold
            leftPadding: Design.Theme.space24
            rightPadding: Design.Theme.space24
            topPadding: Design.Theme.space24
        }

        contentItem: ColumnLayout {
            spacing: Design.Theme.space16

            ColumnLayout {
                spacing: Design.Theme.space8
                Label { text: qsTr("组数"); color: Design.Theme.surfaceMuted }
                SpinBox {
                    id: editSets
                    from: 1
                    to: 20
                    editable: true
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                }
            }

            ColumnLayout {
                spacing: Design.Theme.space8
                Label { text: qsTr("目标次数或范围"); color: Design.Theme.surfaceMuted }
                TextField {
                    id: editReps
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                    placeholderText: qsTr("例如 8–12")
                    color: Design.Theme.surfaceText
                    background: Rectangle {
                        color: Design.Theme.surfaceElevated
                        radius: Design.Theme.radiusSmall
                        border.width: editReps.activeFocus ? 2 : 1
                        border.color: editReps.activeFocus ? Design.Theme.primary : Design.Theme.outline
                    }
                }
            }

            ColumnLayout {
                spacing: Design.Theme.space8
                Label { text: qsTr("推荐间歇（秒）"); color: Design.Theme.surfaceMuted }
                SpinBox {
                    id: editRest
                    from: 0
                    to: 600
                    editable: true
                    stepSize: 15
                    Layout.fillWidth: true
                    implicitHeight: Design.Theme.controlHeight
                }
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
                    onClicked: actionEditor.close()
                }

                AppButton {
                    text: qsTr("保存参数")
                    Layout.fillWidth: true
                    enabled: editReps.text.trim().length > 0
                    onClicked: {
                        if (planManagement.updateExercise(actionEditor.planExerciseId,
                                                          editSets.value,
                                                          editReps.text,
                                                          editRest.value))
                            actionEditor.close()
                    }
                }
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            width: parent.width
            spacing: Design.Theme.space16

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space12

                ColumnLayout {
                    spacing: Design.Theme.space4
                    Layout.fillWidth: true

                    Label {
                        text: qsTr("训练计划")
                        color: Design.Theme.backgroundText
                        font.pixelSize: Design.Theme.typeDisplay
                        font.weight: Font.Bold
                    }

                    Label {
                        text: qsTr("选择模板，复制后按你的器械和顺序调整")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }

                IconButton {
                    glyph: "+"
                    accessibleName: qsTr("新建个人计划")
                    selected: true
                    onClicked: page.openTextDialog("createPlan", "", "")
                }
            }

            Label {
                text: qsTr("选择计划")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                Repeater {
                    model: planManagement.plans

                    delegate: ItemDelegate {
                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: 72
                        leftPadding: Design.Theme.space16
                        rightPadding: Design.Theme.space12
                        highlighted: page.hasSelectedPlan && planManagement.selectedPlan.id === modelData.id
                        onClicked: planManagement.selectPlan(modelData.id)

                        background: Rectangle {
                            color: highlighted ? Design.Theme.primaryContainer : Design.Theme.surface
                            radius: Design.Theme.radiusMedium
                            border.width: highlighted ? 2 : 1
                            border.color: highlighted ? Design.Theme.primary : Design.Theme.outline
                        }

                        contentItem: RowLayout {
                            spacing: Design.Theme.space12

                            ColumnLayout {
                                spacing: Design.Theme.space4
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: Design.Theme.space8
                                    Layout.fillWidth: true

                                    Label {
                                        text: modelData.name
                                        color: Design.Theme.surfaceText
                                        font.pixelSize: Design.Theme.typeBody
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Label {
                                        text: modelData.isSystem ? qsTr("系统原版") : qsTr("个人")
                                        color: modelData.isSystem ? Design.Theme.infoContent
                                                                  : Design.Theme.primaryContainerText
                                        font.pixelSize: Design.Theme.typeCaption
                                        font.weight: Font.DemiBold
                                        leftPadding: Design.Theme.space8
                                        rightPadding: Design.Theme.space8
                                        topPadding: Design.Theme.space4
                                        bottomPadding: Design.Theme.space4
                                        background: Rectangle {
                                            color: modelData.isSystem ? Design.Theme.infoContainer
                                                                      : Design.Theme.primaryContainer
                                            radius: Design.Theme.radiusSmall
                                        }
                                    }
                                }

                                Label {
                                    text: qsTr("%1 个训练日 · %2 个动作")
                                          .arg(modelData.dayCount).arg(modelData.exerciseCount)
                                    color: Design.Theme.surfaceMuted
                                    font.pixelSize: Design.Theme.typeCaption
                                }
                            }

                            Label {
                                text: "›"
                                color: highlighted ? Design.Theme.primary : Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeTitle
                            }
                        }
                    }
                }

                Rectangle {
                    visible: planManagement.plans.length === 0
                    Layout.fillWidth: true
                    implicitHeight: 96
                    color: Design.Theme.surface
                    radius: Design.Theme.radiusMedium
                    border.width: 1
                    border.color: Design.Theme.outline

                    Column {
                        anchors.centerIn: parent
                        spacing: Design.Theme.space4
                        Label { text: qsTr("还没有训练计划"); color: Design.Theme.surfaceText; font.weight: Font.DemiBold }
                        Label { text: qsTr("点击右上角 + 创建个人计划"); color: Design.Theme.surfaceMuted }
                    }
                }
            }

            Rectangle {
                visible: page.hasSelectedPlan
                Layout.fillWidth: true
                implicitHeight: selectedPlanHeader.implicitHeight + Design.Theme.space24 * 2
                color: Design.Theme.surface
                radius: Design.Theme.radiusLarge
                border.width: 1
                border.color: page.selectedPlanReadOnly ? Design.Theme.info : Design.Theme.outline

                ColumnLayout {
                    id: selectedPlanHeader

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Design.Theme.space24
                    spacing: Design.Theme.space12

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Design.Theme.space8

                        ColumnLayout {
                            spacing: Design.Theme.space4
                            Layout.fillWidth: true

                            Label {
                                text: planManagement.selectedPlan.name || ""
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeTitle
                                font.weight: Font.Bold
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Label {
                                text: page.selectedPlanReadOnly ? qsTr("只读系统原版") : qsTr("可编辑个人计划")
                                color: page.selectedPlanReadOnly ? Design.Theme.info : Design.Theme.primary
                                font.pixelSize: Design.Theme.typeCaption
                                font.weight: Font.DemiBold
                            }
                        }

                        IconButton {
                            visible: !page.selectedPlanReadOnly
                            glyph: "⋮"
                            accessibleName: qsTr("计划更多操作")
                            onClicked: planMenu.popup()
                        }

                        Menu {
                            id: planMenu
                            MenuItem {
                                text: qsTr("重命名计划")
                                onTriggered: page.openTextDialog("renamePlan",
                                                                 planManagement.selectedPlan.id,
                                                                 planManagement.selectedPlan.name)
                            }
                            MenuSeparator { }
                            MenuItem {
                                text: qsTr("删除计划")
                                onTriggered: page.requestDelete("plan",
                                                               planManagement.selectedPlan.id,
                                                               planManagement.selectedPlan.name)
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: page.selectedPlanReadOnly
                              ? qsTr("原版内容始终保留且不能直接修改。复制为个人版后，才能添加、删除或调整动作顺序。")
                              : qsTr("这是你的独立副本。修改只影响该计划，不会覆盖系统原版或既往训练记录。")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeLabel
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                    }

                    AppButton {
                        Layout.fillWidth: true
                        text: page.selectedPlanReadOnly ? qsTr("复制为个人版") : qsTr("添加训练日")
                        onClicked: {
                            if (page.selectedPlanReadOnly)
                                page.openTextDialog("copyPlan",
                                                    planManagement.selectedPlan.id,
                                                    planManagement.selectedPlan.name + qsTr("个人版"))
                            else
                                page.openTextDialog("addDay", planManagement.selectedPlan.id, "")
                        }
                    }
                }
            }

            RowLayout {
                visible: page.hasSelectedPlan
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                Label {
                    text: qsTr("训练日")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeTitle
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Label {
                    text: qsTr("%1 天").arg((planManagement.selectedPlan.days || []).length)
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeLabel
                }
            }

            ColumnLayout {
                visible: page.hasSelectedPlan
                Layout.fillWidth: true
                spacing: Design.Theme.space12

                Repeater {
                    model: planManagement.selectedPlan.days || []

                    delegate: Rectangle {
                        id: dayCard

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: dayContent.implicitHeight + Design.Theme.space16 * 2
                        color: Design.Theme.surface
                        radius: Design.Theme.radiusLarge
                        border.width: 1
                        border.color: Design.Theme.outline

                        ColumnLayout {
                            id: dayContent

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Design.Theme.space16
                            spacing: Design.Theme.space12

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Design.Theme.space8

                                ColumnLayout {
                                    spacing: Design.Theme.space4
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0

                                    Label {
                                        text: dayCard.modelData.name
                                        color: Design.Theme.surfaceText
                                        font.pixelSize: Design.Theme.typeBody
                                        font.weight: Font.Bold
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Label {
                                        text: qsTr("%1 个动作").arg(dayCard.modelData.exercises.length)
                                        color: Design.Theme.surfaceMuted
                                        font.pixelSize: Design.Theme.typeCaption
                                    }
                                }

                                AppButton {
                                    text: qsTr("开始")
                                    Layout.preferredWidth: 96
                                    onClicked: {
                                        if (workoutController.startPlanDay(dayCard.modelData.id))
                                            page.trainingRequested()
                                    }
                                }

                                IconButton {
                                    visible: !page.selectedPlanReadOnly
                                    glyph: "⋮"
                                    accessibleName: qsTr("训练日更多操作")
                                    onClicked: dayMenu.popup()
                                }

                                Menu {
                                    id: dayMenu
                                    MenuItem {
                                        text: qsTr("添加动作")
                                        onTriggered: {
                                            actionPicker.dayId = dayCard.modelData.id
                                            actionPicker.open()
                                        }
                                    }
                                    MenuItem {
                                        text: qsTr("重命名训练日")
                                        onTriggered: page.openTextDialog("renameDay",
                                                                         dayCard.modelData.id,
                                                                         dayCard.modelData.name)
                                    }
                                    MenuSeparator { }
                                    MenuItem {
                                        text: qsTr("删除训练日")
                                        onTriggered: page.requestDelete("day",
                                                                       dayCard.modelData.id,
                                                                       dayCard.modelData.name)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: Design.Theme.outline
                            }

                            Label {
                                visible: dayCard.modelData.exercises.length === 0
                                Layout.fillWidth: true
                                text: page.selectedPlanReadOnly
                                      ? qsTr("这个训练日暂未配置动作")
                                      : qsTr("还没有动作。通过右上角更多菜单添加。")
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeLabel
                                wrapMode: Text.WordWrap
                                topPadding: Design.Theme.space8
                                bottomPadding: Design.Theme.space8
                            }

                            Repeater {
                                model: dayCard.modelData.exercises

                                delegate: Rectangle {
                                    id: exerciseRow

                                    required property var modelData
                                    required property int index

                                    Layout.fillWidth: true
                                    implicitHeight: 68
                                    color: "transparent"

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: Design.Theme.space12

                                        Rectangle {
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            radius: 16
                                            color: Design.Theme.surfaceElevated
                                            border.width: 1
                                            border.color: Design.Theme.outline

                                            Label {
                                                anchors.centerIn: parent
                                                text: exerciseRow.index + 1
                                                color: Design.Theme.surfaceMuted
                                                font.pixelSize: Design.Theme.typeCaption
                                                font.weight: Font.DemiBold
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            spacing: Design.Theme.space4

                                            Label {
                                                text: exerciseRow.modelData.name
                                                color: Design.Theme.surfaceText
                                                font.pixelSize: Design.Theme.typeLabel
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Label {
                                                text: qsTr("%1 组 · %2 次 · 休息 %3 秒")
                                                      .arg(exerciseRow.modelData.sets)
                                                      .arg(exerciseRow.modelData.reps)
                                                      .arg(exerciseRow.modelData.restSeconds)
                                                color: Design.Theme.surfaceMuted
                                                font.pixelSize: Design.Theme.typeCaption
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        IconButton {
                                            visible: !page.selectedPlanReadOnly
                                            glyph: "⋮"
                                            accessibleName: qsTr("动作更多操作")
                                            onClicked: exerciseMenu.popup()
                                        }

                                        Menu {
                                            id: exerciseMenu
                                            MenuItem {
                                                text: qsTr("编辑参数")
                                                onTriggered: {
                                                    actionEditor.planExerciseId = exerciseRow.modelData.id
                                                    editSets.value = exerciseRow.modelData.sets
                                                    editReps.text = exerciseRow.modelData.reps
                                                    editRest.value = exerciseRow.modelData.restSeconds
                                                    actionEditor.open()
                                                }
                                            }
                                            MenuItem {
                                                text: qsTr("上移")
                                                enabled: exerciseRow.index > 0
                                                onTriggered: planManagement.moveExercise(dayCard.modelData.id,
                                                                                           exerciseRow.index,
                                                                                           exerciseRow.index - 1)
                                            }
                                            MenuItem {
                                                text: qsTr("下移")
                                                enabled: exerciseRow.index + 1 < dayCard.modelData.exercises.length
                                                onTriggered: planManagement.moveExercise(dayCard.modelData.id,
                                                                                           exerciseRow.index,
                                                                                           exerciseRow.index + 1)
                                            }
                                            MenuSeparator { }
                                            MenuItem {
                                                text: qsTr("删除动作")
                                                onTriggered: page.requestDelete("exercise",
                                                                               exerciseRow.modelData.id,
                                                                               exerciseRow.modelData.name)
                                            }
                                        }

                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.leftMargin: 44
                                        height: 1
                                        color: Design.Theme.outline
                                    }
                                }
                            }
                        }
                    }
                }
            }

            InlineFeedback {
                visible: planManagement.errorMessage.length > 0
                Layout.fillWidth: true
                tone: "error"
                message: planManagement.errorMessage
            }

            Item { Layout.preferredHeight: Design.Theme.space8 }
        }
    }
}
