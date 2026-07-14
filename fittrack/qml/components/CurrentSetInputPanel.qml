import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

ColumnLayout {
    id: root

    property var exercise: null
    property var setData: null
    property int exerciseIndex: -1
    property int setIndex: -1
    property bool allExercisesComplete: false
    property int exerciseCount: 0
    property bool submitting: false
    property real viewportWidth: width

    readonly property bool currentIsBodyweight: exercise
            && exercise.loadMode === "Bodyweight"
    readonly property bool pureBodyweight: currentIsBodyweight
            && bodyweightMode.currentIndex === 0

    signal targetRepsRequested(string exerciseId, var setData)
    signal timerRequested()
    signal completeRequested(real weightKg, int reps, bool toFailure, string loadType)
    signal advanceRequested()
    signal finishRequested()

    function loadInputs() {
        if (!root.exercise || !root.setData) {
            setWeight.text = ""
            setReps.text = ""
            setFailure.checked = false
            bodyweightMode.currentIndex = 0
            return
        }

        const hasWeight = root.setData.weightKg !== undefined
                && root.setData.weightKg !== null
                && Number.isFinite(Number(root.setData.weightKg))
        setWeight.text = hasWeight ? String(Number(root.setData.weightKg)) : ""
        setReps.text = ""
        setFailure.checked = false
        bodyweightMode.currentIndex = root.setData.bodyweightLoadType === "Added" ? 1
                : root.setData.bodyweightLoadType === "Assisted" ? 2 : 0
    }

    spacing: Design.Spacing.sm

    RowLayout {
        Layout.fillWidth: true
        spacing: Design.Spacing.sm

        ItemDelegate {
            objectName: "currentSetTargetButton"
            Layout.fillWidth: true
            implicitHeight: Design.Theme.touchTarget
            leftPadding: 0
            rightPadding: 0
            enabled: root.setData !== null
            Accessible.name: root.setData
                             ? qsTr("当前第 %1 组，目标 %2 次，双击修改")
                               .arg(root.setData.number)
                               .arg(root.setData.targetReps !== null
                                    ? root.setData.targetReps : qsTr("未设置"))
                             : qsTr("当前动作已完成")
            onClicked: {
                if (root.exercise && root.setData)
                    root.targetRepsRequested(String(root.exercise.id), root.setData)
            }
            background: Item { }
            contentItem: RowLayout {
                spacing: Design.Spacing.sm
                Label {
                    text: root.setData
                          ? qsTr("第 %1 组").arg(root.setData.number)
                          : (root.allExercisesComplete
                             ? qsTr("训练已完成") : qsTr("动作已完成"))
                    color: Design.Theme.textPrimary
                    font.pixelSize: Design.Typography.body
                    font.weight: Font.DemiBold
                }
                Label {
                    visible: root.setData !== null
                    Layout.fillWidth: true
                    text: root.setData && root.setData.targetReps !== null
                          ? qsTr("目标 %1 次 · 点按修改").arg(root.setData.targetReps)
                          : qsTr("设置目标次数")
                    color: Design.Theme.textTertiary
                    font.pixelSize: Design.Typography.caption
                    elide: Text.ElideRight
                }
            }
        }

        AppButton {
            objectName: "openRestTimerButton"
            Layout.preferredWidth: 72
            variant: "secondary"
            flatSecondary: true
            cornerRadius: 14
            text: qsTr("计时")
            onClicked: root.timerRequested()
        }

        CheckBox {
            id: setFailure
            visible: root.setData !== null
            implicitWidth: 72
            implicitHeight: Design.Theme.touchTarget
            text: qsTr("力竭")
        }
    }

    RowLayout {
        visible: root.setData !== null
        Layout.fillWidth: true
        spacing: Design.Spacing.sm

        Label {
            Layout.preferredWidth: 32
            text: qsTr("组")
            color: Design.Theme.textTertiary
            font.pixelSize: Design.Typography.caption
            horizontalAlignment: Text.AlignHCenter
        }
        Label {
            Layout.fillWidth: true
            text: qsTr("重量")
            color: Design.Theme.textTertiary
            font.pixelSize: Design.Typography.caption
        }
        Label {
            Layout.fillWidth: true
            text: qsTr("次数")
            color: Design.Theme.textTertiary
            font.pixelSize: Design.Typography.caption
        }
        Label {
            Layout.preferredWidth: 24
            text: qsTr("状态")
            color: Design.Theme.textTertiary
            font.pixelSize: Design.Typography.caption
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Rectangle {
        visible: root.setData !== null
        Layout.fillWidth: true
        implicitHeight: Math.max(60, currentInputRow.implicitHeight + Design.Spacing.sm)
        radius: 12
        color: Design.Theme.selection

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: 2
            color: Design.Theme.accent
        }

        RowLayout {
            id: currentInputRow
            anchors.fill: parent
            anchors.leftMargin: Design.Spacing.sm
            anchors.rightMargin: Design.Spacing.sm
            spacing: Design.Spacing.sm

            Label {
                Layout.preferredWidth: 24
                text: root.setData ? String(root.setData.number) : ""
                color: Design.Theme.accent
                font.pixelSize: Design.Typography.body
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }

            NumberField {
                id: setWeight
                objectName: "setWeightField"
                Layout.fillWidth: true
                Layout.minimumWidth: 88
                accessibleName: qsTr("实际重量")
                subtleBorder: true
                cornerRadius: 12
                fillColor: Design.Theme.field
                placeholderText: root.pureBodyweight ? qsTr("自重") : qsTr("0")
                unit: root.pureBodyweight ? "" : "kg"
                decimals: 2
                enabled: !root.pureBodyweight
            }

            NumberField {
                id: setReps
                objectName: "setRepsField"
                Layout.fillWidth: true
                Layout.minimumWidth: 72
                accessibleName: qsTr("实际次数")
                subtleBorder: true
                cornerRadius: 12
                fillColor: Design.Theme.field
                placeholderText: root.setData && root.setData.targetReps !== null
                                 ? String(root.setData.targetReps) : qsTr("次数")
                decimals: 0
                keyboardHints: Qt.ImhDigitsOnly
                onAccepted: completeSetButton.clicked()
            }

            Label {
                Layout.preferredWidth: 24
                text: "•"
                color: Design.Theme.accent
                font.pixelSize: Design.Typography.sectionTitle
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    ComboBox {
        id: bodyweightMode
        objectName: "bodyweightModeSelector"
        visible: root.setData !== null && root.currentIsBodyweight
        Layout.fillWidth: true
        implicitHeight: Design.Theme.controlHeight
        textRole: "label"
        model: [
            {"label": qsTr("纯自重，只记录次数"), "value": "Bodyweight"},
            {"label": qsTr("附加负重"), "value": "Added"},
            {"label": qsTr("辅助重量"), "value": "Assisted"}
        ]
        Accessible.name: qsTr("自重动作负荷方式")
        onCurrentIndexChanged: {
            if (currentIndex === 0)
                setWeight.text = ""
        }
    }

    AppButton {
        id: completeSetButton
        objectName: "completeSetButton"
        visible: root.setData !== null
        Layout.fillWidth: true
        cornerRadius: 14
        primaryColor: Design.Theme.accent
        primaryPressedColor: Design.Theme.accentPressed
        primaryTextColor: Design.Theme.accentForeground
        text: root.submitting
              ? qsTr("正在保存…")
              : (root.setData ? qsTr("完成第 %1 组").arg(root.setData.number)
                              : qsTr("完成本组"))
        Accessible.name: qsTr("完成本组")
        enabled: !root.submitting
                 && Number.isFinite(setReps.numericValue)
                 && (root.pureBodyweight || Number.isFinite(setWeight.numericValue))
        onClicked: {
            if (!enabled || root.exerciseIndex < 0 || root.setIndex < 0)
                return
            const loadType = root.currentIsBodyweight
                    ? bodyweightMode.model[bodyweightMode.currentIndex].value
                    : "Bodyweight"
            root.completeRequested(root.pureBodyweight ? 0 : setWeight.numericValue,
                                   setReps.numericValue, setFailure.checked, loadType)
        }
    }

    AppButton {
        visible: root.setData === null && root.exerciseCount > 0
        Layout.fillWidth: true
        text: root.allExercisesComplete ? qsTr("完成本次训练") : qsTr("进入下一个动作")
        onClicked: {
            if (root.allExercisesComplete)
                root.finishRequested()
            else
                root.advanceRequested()
        }
    }
}
