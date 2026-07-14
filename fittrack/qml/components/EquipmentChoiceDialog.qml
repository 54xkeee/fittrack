import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppDialog {
    id: root

    property var equipmentModel: []
    property bool canCreate: false
    property string targetExerciseId: ""

    signal saveRequested(string exerciseId, string equipmentId)
    signal createRequested()

    function equipmentIndex(equipmentId) {
        for (let index = 0; index < root.equipmentModel.length; ++index) {
            if (root.equipmentModel[index].id === equipmentId)
                return index
        }
        return -1
    }

    function openForExercise(exerciseId, equipmentId) {
        targetExerciseId = exerciseId
        equipmentChoice.currentIndex = equipmentIndex(equipmentId)
        open()
    }

    objectName: "equipmentChoiceDialog"
    width: Math.min(400, safeAvailableWidth)
    title: qsTr("本次使用器械")
    primaryText: qsTr("保存器械")
    autoAccept: false
    initialFocusItem: equipmentChoice
    onPrimaryRequested: {
        const equipmentId = equipmentChoice.currentIndex >= 0
                ? root.equipmentModel[equipmentChoice.currentIndex].id : ""
        root.saveRequested(root.targetExerciseId, equipmentId)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.Theme.space12

        ComboBox {
            id: equipmentChoice
            Layout.fillWidth: true
            implicitHeight: Design.Theme.controlHeight
            model: root.equipmentModel
            textRole: "displayName"
            displayText: currentIndex >= 0 ? currentText : qsTr("不指定具体器械")
            Accessible.name: qsTr("本次使用器械")
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
