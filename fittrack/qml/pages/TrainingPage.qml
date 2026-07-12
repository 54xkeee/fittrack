import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page

    function twoDigits(value) {
        return value < 10 ? "0" + value : value
    }

    function timerText(seconds) {
        return twoDigits(Math.floor(seconds / 60)) + ":" + twoDigits(seconds % 60)
    }

    function gymIndex(gymId) {
        for (let i = 0; i < workoutController.gyms.length; ++i) {
            if (workoutController.gyms[i].id === gymId)
                return i
        }
        return -1
    }

    function equipmentIndex(equipmentId) {
        for (let i = 0; i < workoutController.equipment.length; ++i) {
            if (workoutController.equipment[i].id === equipmentId)
                return i
        }
        return -1
    }

    function previousText(sets) {
        if (!sets || sets.length === 0)
            return qsTr("暂无同器械历史")
        let values = []
        for (let i = 0; i < sets.length; ++i)
            values.push(Number(sets[i].weightKg) + " kg × " + sets[i].reps)
        return qsTr("上次：") + values.join("　")
    }

    Connections {
        target: workoutController
        function onSetCompleted(restSeconds) {
            if (restSeconds > 0)
                restTimer.start(restSeconds)
        }
    }

    header: ToolBar {
        Label {
            anchors.centerIn: parent
            text: workoutController.active ? workoutController.sessionName : qsTr("训练")
            font.pixelSize: 18
            font.bold: true
        }
    }

    Dialog {
        id: exercisePicker
        property int replaceIndex: -1
        anchors.centerIn: parent
        width: Math.min(page.width - 28, 520)
        height: Math.min(page.height - 60, 680)
        modal: true
        title: replaceIndex >= 0 ? qsTr("替换动作") : qsTr("添加动作")
        standardButtons: Dialog.Close
        onClosed: exerciseModel.searchText = ""

        ColumnLayout {
            anchors.fill: parent

            TextField {
                Layout.fillWidth: true
                placeholderText: qsTr("搜索动作")
                onTextChanged: exerciseModel.searchText = text
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: exerciseModel

                delegate: ItemDelegate {
                    required property string exerciseId
                    required property string name
                    required property string bodyPart
                    required property int recommendedSets
                    required property string recommendedReps

                    width: ListView.view.width
                    text: name + "  ·  " + bodyPart
                    onClicked: {
                        if (exercisePicker.replaceIndex >= 0)
                            workoutController.replaceExercise(exercisePicker.replaceIndex, exerciseId)
                        else
                            workoutController.addExercise(exerciseId, recommendedSets, recommendedReps)
                        exercisePicker.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: appendSetDialog
        property int exerciseIndex: -1
        property int setIndex: -1
        anchors.centerIn: parent
        width: Math.min(page.width - 28, 420)
        modal: true
        title: qsTr("添加短休追加组")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: workoutController.addAppendSet(
            exerciseIndex, setIndex, Number(appendWeight.text), Number(appendReps.text), appendRest.value,
            appendFailure.checked)

        ColumnLayout {
            anchors.fill: parent
            Label { text: qsTr("完成短休追加后填写实际数据。") ; color: "#AEB7B1" }
            TextField {
                id: appendWeight
                Layout.fillWidth: true
                placeholderText: qsTr("重量 kg（自重可填 0）")
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                validator: DoubleValidator { bottom: 0; decimals: 2 }
            }
            TextField {
                id: appendReps
                Layout.fillWidth: true
                placeholderText: qsTr("实际次数")
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 0; top: 999 }
            }
            RowLayout {
                Label { text: qsTr("短休秒数") }
                SpinBox { id: appendRest; from: 0; to: 300; value: 5; editable: true }
                CheckBox { id: appendFailure; text: qsTr("力竭") }
            }
        }
    }

    Dialog {
        id: gymDialog
        anchors.centerIn: parent
        width: Math.min(page.width - 28, 420)
        modal: true
        title: qsTr("新建健身房")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: workoutController.addGym(gymName.text)

        TextField {
            id: gymName
            anchors.fill: parent
            placeholderText: qsTr("例如：学校健身房")
        }
    }

    Dialog {
        id: equipmentDialog
        anchors.centerIn: parent
        width: Math.min(page.width - 28, 420)
        modal: true
        title: qsTr("新建具体器械")
        standardButtons: Dialog.Ok | Dialog.Cancel
        onAccepted: workoutController.addEquipment(
            equipmentName.text, equipmentCode.text, equipmentNotes.text)

        ColumnLayout {
            anchors.fill: parent
            TextField { id: equipmentName; Layout.fillWidth: true; placeholderText: qsTr("器械名称") }
            TextField { id: equipmentCode; Layout.fillWidth: true; placeholderText: qsTr("编号，例如 1号") }
            TextField { id: equipmentNotes; Layout.fillWidth: true; placeholderText: qsTr("座椅档位、把手等，可选") }
        }
    }

    Dialog {
        id: savePlanDialog
        anchors.centerIn: parent
        width: Math.min(page.width - 28, 420)
        modal: true
        title: qsTr("保存为个人计划")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: workoutController.saveCurrentAsPlan(
            savedPlanName.text, savedDayName.text, savedSectionName.text)

        ColumnLayout {
            anchors.fill: parent
            TextField { id: savedPlanName; Layout.fillWidth: true; placeholderText: qsTr("计划名称") }
            TextField { id: savedDayName; Layout.fillWidth: true; placeholderText: qsTr("训练日名称，例如 Push A") }
            TextField { id: savedSectionName; Layout.fillWidth: true; placeholderText: qsTr("动作分组名称，可选") }
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 14

            Item { Layout.preferredHeight: 2 }

            Frame {
                visible: !workoutController.active
                         && workoutHistory.selectedSession.id !== undefined
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                padding: 18

                ColumnLayout {
                    anchors.fill: parent
                    Label { text: qsTr("训练已保存"); color: "#8BD450"; font.bold: true }
                    Label {
                        text: workoutHistory.selectedSession.name || ""
                        font.pixelSize: 20
                        font.bold: true
                    }
                    Label {
                        text: qsTr("%1 个动作 · %2 个正式组 · %3 kg")
                            .arg(workoutHistory.selectedSession.exerciseCount || 0)
                            .arg(workoutHistory.selectedSession.setCount || 0)
                            .arg(Number(workoutHistory.selectedSession.totalVolume || 0).toFixed(1))
                        color: "#AEB7B1"
                    }
                    Label {
                        text: workoutHistory.selectedSession.highestWeight > 0
                              ? qsTr("最高表现：%1 %2 kg × %3 · %4组")
                                  .arg(workoutHistory.selectedSession.highestWeightExercise)
                                  .arg(workoutHistory.selectedSession.highestWeight)
                                  .arg(workoutHistory.selectedSession.highestWeightReps)
                                  .arg(workoutHistory.selectedSession.highestWeightSetCount)
                              : qsTr("本次没有可计算的负重表现")
                    }
                }
            }

            Frame {
                visible: !workoutController.active
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                padding: 18

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Label { text: qsTr("开始训练"); font.pixelSize: 20; font.bold: true }
                    Label {
                        text: qsTr("选择谭成义三分化训练日，或从空白自由训练开始。")
                        color: "#AEB7B1"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        ComboBox {
                            Layout.fillWidth: true
                            model: workoutController.gyms
                            textRole: "name"
                            currentIndex: gymIndex(workoutController.selectedGymId)
                            displayText: currentIndex >= 0 ? currentText : qsTr("未选择健身房")
                            onActivated: workoutController.selectGym(workoutController.gyms[currentIndex].id)
                        }
                        Button {
                            text: qsTr("新建")
                            onClicked: {
                                gymName.text = ""
                                gymDialog.open()
                            }
                        }
                    }

                    RowLayout {
                        visible: workoutController.hasUnfinished
                        Layout.fillWidth: true
                        Button {
                            Layout.fillWidth: true
                            text: qsTr("继续未完成训练")
                            highlighted: true
                            onClicked: workoutController.resumeUnfinished()
                        }
                        Button {
                            text: qsTr("保存并结束")
                            onClicked: workoutController.finishUnfinished()
                        }
                        Button {
                            text: qsTr("删除")
                            onClicked: workoutController.discardUnfinished()
                        }
                    }

                    Repeater {
                        model: workoutController.planDays
                        delegate: Button {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.planName + "\n" + modelData.name
                            onClicked: workoutController.startPlanDay(modelData.dayId)
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        text: qsTr("自由训练")
                        onClicked: workoutController.startFreeWorkout("")
                    }
                }
            }

            Frame {
                visible: workoutController.active
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                padding: 16

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: qsTr("休息倒计时"); color: "#AEB7B1" }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: timerText(restTimer.remainingSeconds)
                            font.pixelSize: 34
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button { Layout.fillWidth: true; text: qsTr("2分钟"); onClicked: restTimer.start(120) }
                        Button { Layout.fillWidth: true; text: qsTr("3分钟"); onClicked: restTimer.start(180) }
                        Button { Layout.fillWidth: true; text: qsTr("5分钟"); onClicked: restTimer.start(300) }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        SpinBox { id: minutes; from: 0; to: 59; value: 2; editable: true }
                        Label { text: qsTr("分") }
                        SpinBox { id: seconds; from: 0; to: 59; value: 0; editable: true }
                        Label { text: qsTr("秒") }
                        Button {
                            Layout.fillWidth: true
                            text: qsTr("开始")
                            onClicked: restTimer.start(minutes.value * 60 + seconds.value)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            Layout.fillWidth: true
                            text: restTimer.state === 2 ? qsTr("继续") : qsTr("暂停")
                            enabled: restTimer.state === 1 || restTimer.state === 2
                            onClicked: restTimer.state === 2 ? restTimer.resume() : restTimer.pause()
                        }
                        Button { Layout.fillWidth: true; text: qsTr("重置"); onClicked: restTimer.reset() }
                        Button { Layout.fillWidth: true; text: qsTr("结束"); onClicked: restTimer.finishEarly() }
                    }
                }
            }

            Label {
                visible: workoutController.active && workoutController.exercises.length === 0
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                text: qsTr("还没有动作，请从动作库添加。")
                color: "#AEB7B1"
                horizontalAlignment: Text.AlignHCenter
            }

            Repeater {
                model: workoutController.exercises

                delegate: Frame {
                    id: exerciseCard
                    required property var modelData
                    required property int index
                    property int exerciseIndex: index
                    Drag.active: cardDrag.active
                    Drag.source: exerciseCard
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2
                    z: Drag.active ? 10 : 0

                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    padding: 16

                    DropArea {
                        anchors.fill: parent
                        onDropped: function(drop) {
                            if (drop.source && drop.source !== exerciseCard)
                                workoutController.moveExercise(drop.source.exerciseIndex, exerciseIndex)
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 9

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pixelSize: 19
                                font.bold: true
                            }
                            ToolButton {
                                text: "↕"
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("按住拖动排序")
                                DragHandler {
                                    id: cardDrag
                                    target: exerciseCard
                                }
                            }
                            ToolButton {
                                text: "↑"
                                enabled: exerciseIndex > 0
                                onClicked: workoutController.moveExercise(exerciseIndex, exerciseIndex - 1)
                            }
                            ToolButton {
                                text: "↓"
                                enabled: exerciseIndex + 1 < workoutController.exercises.length
                                onClicked: workoutController.moveExercise(exerciseIndex, exerciseIndex + 1)
                            }
                            ToolButton {
                                text: qsTr("替换")
                                onClicked: {
                                    exercisePicker.replaceIndex = exerciseIndex
                                    exercisePicker.open()
                                }
                            }
                            ToolButton {
                                text: qsTr("删除")
                                onClicked: workoutController.removeExercise(exerciseIndex)
                            }
                        }
                        Label {
                            Layout.fillWidth: true
                            text: qsTr("建议次数：") + modelData.recommendedReps
                                  + qsTr("　间歇：") + modelData.restSeconds + qsTr("秒")
                            color: "#AEB7B1"
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            ComboBox {
                                Layout.fillWidth: true
                                model: workoutController.equipment
                                textRole: "displayName"
                                currentIndex: equipmentIndex(modelData.equipmentId)
                                displayText: currentIndex >= 0 ? currentText : qsTr("未指定具体器械")
                                onActivated: workoutController.setExerciseEquipment(
                                    exerciseIndex, workoutController.equipment[currentIndex].id)
                            }
                            Button {
                                text: qsTr("不指定")
                                enabled: modelData.equipmentId !== undefined && modelData.equipmentId !== null
                                onClicked: workoutController.setExerciseEquipment(exerciseIndex, "")
                            }
                            Button {
                                text: qsTr("新建器械")
                                enabled: workoutController.selectedGymId.length > 0
                                onClicked: {
                                    equipmentName.text = ""
                                    equipmentCode.text = ""
                                    equipmentNotes.text = ""
                                    equipmentDialog.open()
                                }
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: previousText(modelData.previousSets)
                            color: modelData.previousSets.length > 0 ? "#8BD450" : "#7E8982"
                            wrapMode: Text.WordWrap
                        }
                        Label {
                            visible: modelData.notes.length > 0
                            Layout.fillWidth: true
                            text: modelData.notes
                            color: "#C7CFCA"
                            wrapMode: Text.WordWrap
                        }
                        TextField {
                            Layout.fillWidth: true
                            placeholderText: qsTr("动作备注，例如座椅档位或身体感受")
                            text: modelData.notes
                            onActiveFocusChanged: {
                                if (!activeFocus && text !== modelData.notes)
                                    workoutController.setExerciseNotes(exerciseIndex, text)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Label { text: qsTr("快速生成") ; color: "#AEB7B1" }
                            TextField {
                                id: quickWeight
                                Layout.fillWidth: true
                                placeholderText: qsTr("kg")
                                inputMethodHints: Qt.ImhFormattedNumbersOnly
                                validator: DoubleValidator { bottom: 0; decimals: 2 }
                            }
                            TextField {
                                id: quickReps
                                Layout.fillWidth: true
                                placeholderText: qsTr("次数")
                                inputMethodHints: Qt.ImhDigitsOnly
                                validator: IntValidator { bottom: 0; top: 999 }
                            }
                            SpinBox { id: quickSets; from: 1; to: 20; value: modelData.sets.length }
                            Button {
                                text: qsTr("应用")
                                enabled: quickReps.text.length > 0
                                onClicked: workoutController.configureExercise(
                                    exerciseIndex,
                                    quickWeight.text.length > 0 ? Number(quickWeight.text) : 0,
                                    Number(quickReps.text),
                                    quickSets.value)
                            }
                        }

                        Repeater {
                            model: modelData.sets

                            delegate: ColumnLayout {
                                required property var modelData
                                required property int index
                                property int setIndex: index
                                Layout.fillWidth: true
                                spacing: 3

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 7

                                    Label {
                                        text: qsTr("第%1组").arg(modelData.number)
                                        Layout.preferredWidth: 48
                                        color: modelData.completed ? "#8BD450" : "white"
                                    }
                                    TextField {
                                        id: weightInput
                                        Layout.fillWidth: true
                                        property bool bodyweightExercise: exerciseCard.modelData.loadMode === "Bodyweight"
                                        placeholderText: bodyweightExercise && bodyweightMode.currentIndex === 0
                                                         ? qsTr("纯自重")
                                                         : bodyweightExercise && bodyweightMode.currentIndex === 2
                                                           ? qsTr("辅助kg") : qsTr("kg")
                                        text: modelData.weightKg !== undefined && modelData.weightKg !== null
                                              ? Number(modelData.weightKg).toString() : ""
                                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                                        validator: DoubleValidator { bottom: 0; decimals: 2 }
                                        enabled: !modelData.completed
                                                 && (!bodyweightExercise || bodyweightMode.currentIndex > 0)
                                    }
                                    TextField {
                                        id: repsInput
                                        Layout.fillWidth: true
                                        placeholderText: modelData.targetReps ? String(modelData.targetReps) : qsTr("次数")
                                        text: modelData.completed && modelData.actualReps !== null
                                              ? String(modelData.actualReps) : ""
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        validator: IntValidator { bottom: 0; top: 999 }
                                        enabled: !modelData.completed
                                    }
                                    CheckBox {
                                        id: failureInput
                                        text: qsTr("力竭")
                                        checked: modelData.toFailure
                                        enabled: !modelData.completed
                                    }
                                    ComboBox {
                                        id: bodyweightMode
                                        visible: exerciseCard.modelData.loadMode === "Bodyweight"
                                        model: [
                                            {"label": qsTr("自重"), "value": "Bodyweight"},
                                            {"label": qsTr("附加"), "value": "Added"},
                                            {"label": qsTr("辅助"), "value": "Assisted"}
                                        ]
                                        textRole: "label"
                                        currentIndex: modelData.bodyweightLoadType === "Added" ? 1
                                                      : modelData.bodyweightLoadType === "Assisted" ? 2 : 0
                                        enabled: !modelData.completed
                                    }
                                    Button {
                                        text: modelData.completed ? qsTr("已完成") : qsTr("完成")
                                        enabled: !modelData.completed && repsInput.text.length > 0
                                        onClicked: workoutController.completeSet(
                                            exerciseIndex,
                                            setIndex,
                                            weightInput.text.length > 0 ? Number(weightInput.text) : 0,
                                            Number(repsInput.text),
                                            failureInput.checked,
                                            bodyweightMode.visible
                                                ? bodyweightMode.model[bodyweightMode.currentIndex].value
                                                : "Bodyweight")
                                    }
                                    Button {
                                        visible: modelData.completed
                                        text: qsTr("追加")
                                        onClicked: {
                                            appendSetDialog.exerciseIndex = exerciseIndex
                                            appendSetDialog.setIndex = setIndex
                                            appendWeight.text = modelData.weightKg !== undefined
                                                    ? String(modelData.weightKg) : ""
                                            appendReps.text = ""
                                            appendRest.value = 5
                                            appendFailure.checked = false
                                            appendSetDialog.open()
                                        }
                                    }
                                }

                                Repeater {
                                    model: modelData.appendSets
                                    delegate: Label {
                                        required property var modelData
                                        Layout.leftMargin: 56
                                        text: qsTr("追加：%1 kg × %2，短休 %3 秒%4")
                                            .arg(modelData.weightKg)
                                            .arg(modelData.reps)
                                            .arg(modelData.restSeconds)
                                            .arg(modelData.toFailure ? qsTr("，力竭") : "")
                                        color: "#AEB7B1"
                                    }
                                }

                                TextField {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 56
                                    placeholderText: qsTr("本组备注，可选")
                                    text: modelData.notes
                                    onActiveFocusChanged: {
                                        if (!activeFocus && text !== modelData.notes)
                                            workoutController.setSetNotes(exerciseIndex, setIndex, text)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                visible: workoutController.active
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14

                Button {
                    Layout.fillWidth: true
                    text: qsTr("添加动作")
                    onClicked: {
                        exercisePicker.replaceIndex = -1
                        exercisePicker.open()
                    }
                }
                Button {
                    Layout.fillWidth: true
                    text: qsTr("完成训练")
                    highlighted: true
                    onClicked: workoutController.finishWorkout()
                }
                Button {
                    text: qsTr("存为计划")
                    onClicked: {
                        savedPlanName.text = workoutController.sessionName
                        savedDayName.text = workoutController.sessionName
                        savedSectionName.text = ""
                        savePlanDialog.open()
                    }
                }
                Button {
                    text: qsTr("放弃")
                    onClicked: workoutController.discardWorkout()
                }
            }

            TextArea {
                visible: workoutController.active
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                placeholderText: qsTr("本次训练备注，可选")
                text: workoutController.sessionNotes
                wrapMode: TextEdit.Wrap
                onActiveFocusChanged: {
                    if (!activeFocus && text !== workoutController.sessionNotes)
                        workoutController.setSessionNotes(text)
                }
            }

            Label {
                visible: workoutController.errorMessage.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 18
                Layout.rightMargin: 18
                text: workoutController.errorMessage
                color: "#FF8A80"
                wrapMode: Text.WordWrap
            }

            Item { Layout.preferredHeight: 18 }
        }
    }
}
