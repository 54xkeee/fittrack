import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppBottomSheet {
    id: root

    property var equipmentModel: []
    property bool canCreate: false
    property string targetExerciseId: ""
    property string selectedEquipmentId: ""

    signal saveRequested(string exerciseId, string equipmentId)
    signal createRequested()

    function choices() {
        let result = [{"id": "", "displayName": qsTr("不指定器械")}]
        for (let index = 0; index < root.equipmentModel.length; ++index) {
            result.push(root.equipmentModel[index])
        }
        return result
    }

    function openForExercise(exerciseId, equipmentId) {
        targetExerciseId = exerciseId
        selectedEquipmentId = String(equipmentId || "")
        open()
    }

    objectName: "equipmentChoiceDialog"
    title: qsTr("本次使用器械")
    primaryText: qsTr("保存器械")
    autoAccept: false
    onPrimaryRequested: {
        root.saveRequested(root.targetExerciseId, root.selectedEquipmentId)
    }

    ColumnLayout {
        width: parent.width
        spacing: Design.Theme.space12

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Design.Theme.space8
            columnSpacing: Design.Theme.space8

            Repeater {
                model: root.choices()

                delegate: ItemDelegate {
                    id: equipmentOption
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    leftPadding: Design.Theme.space12
                    rightPadding: Design.Theme.space12
                    topPadding: Design.Theme.space12
                    bottomPadding: Design.Theme.space12
                    highlighted: root.selectedEquipmentId === String(modelData.id || "")
                    Accessible.name: modelData.displayName
                    Accessible.description: highlighted ? qsTr("已选择") : qsTr("未选择")
                    onClicked: root.selectedEquipmentId = String(modelData.id || "")

                    contentItem: Label {
                        text: equipmentOption.modelData.displayName
                        color: equipmentOption.highlighted
                               ? Design.Theme.primaryContainerText : Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeLabel
                        font.weight: equipmentOption.highlighted ? Font.DemiBold : Font.Normal
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignTop
                    }

                    background: Rectangle {
                        radius: Design.Theme.radiusSelection
                        color: equipmentOption.highlighted
                               ? Design.Theme.primaryContainer
                               : (equipmentOption.down
                                  ? Design.Theme.surfacePressed : Design.Theme.surface)
                        border.width: 1
                        border.color: equipmentOption.highlighted
                                      ? Design.Theme.primary : Design.Theme.outlineVariant
                    }
                }
            }
        }

        AppButton {
            Layout.fillWidth: true
            variant: "secondary"
            text: qsTr("新建器械")
            enabled: root.canCreate
            onClicked: root.createRequested()
        }
    }
}
