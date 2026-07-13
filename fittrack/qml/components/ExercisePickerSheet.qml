import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Dialog {
    id: root

    property var exerciseModel
    property string mode: "add"
    signal previewRequested(string exerciseId)
    signal exerciseSelected(string exerciseId)

    function openPicker(pickerMode) {
        mode = pickerMode || "add"
        open()
    }

    objectName: "sharedExercisePickerSheet"
    parent: Overlay.overlay
    width: Math.min(440, Overlay.overlay ? Overlay.overlay.width - Design.Theme.space16 : 440)
    height: Math.min(720, Overlay.overlay ? Overlay.overlay.height - Design.Theme.space16 : 720)
    anchors.centerIn: Overlay.overlay
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
            Layout.margins: Design.Theme.space12
            Label {
                Layout.fillWidth: true
                text: root.mode === "replace" ? qsTr("替换动作") : qsTr("添加动作")
                color: Design.Theme.surfaceText
                font.pixelSize: Design.Theme.typeTitle
                font.weight: Font.DemiBold
            }
            IconButton {
                glyph: "×"
                accessibleName: qsTr("关闭动作选择")
                onClicked: root.close()
            }
        }
        TextField {
            id: pickerSearch
            Layout.fillWidth: true
            Layout.leftMargin: Design.Theme.space16
            Layout.rightMargin: Design.Theme.space16
            Layout.bottomMargin: Design.Theme.space12
            implicitHeight: Design.Theme.controlHeight
            placeholderText: qsTr("搜索动作")
            Accessible.name: qsTr("搜索动作")
            onTextChanged: if (root.exerciseModel) root.exerciseModel.searchText = text
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Design.Theme.outline }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: root.exerciseModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: exerciseOption
                required property string exerciseId
                required property string name
                required property string bodyPart
                required property int recommendedSets
                required property string recommendedReps
                width: ListView.view.width
                height: Math.max(72, optionLayout.implicitHeight + Design.Theme.space16)

                RowLayout {
                    id: optionLayout
                    anchors.fill: parent
                    anchors.leftMargin: Design.Theme.space16
                    anchors.rightMargin: Design.Theme.space8
                    spacing: Design.Theme.space8
                    AppButton {
                        Layout.fillWidth: true
                        variant: "secondary"
                        text: exerciseOption.name
                        Accessible.description: qsTr("%1，推荐 %2 组 %3 次，点击预览")
                                                .arg(exerciseOption.bodyPart)
                                                .arg(exerciseOption.recommendedSets)
                                                .arg(exerciseOption.recommendedReps)
                        onClicked: root.previewRequested(exerciseOption.exerciseId)
                    }
                    AppButton {
                        Layout.preferredWidth: 88
                        text: root.mode === "replace" ? qsTr("替换") : qsTr("添加")
                        Accessible.description: exerciseOption.name
                        onClicked: root.exerciseSelected(exerciseOption.exerciseId)
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: parent.count === 0
                text: qsTr("没有匹配的动作")
                color: Design.Theme.surfaceMuted
            }
        }
    }

    onClosed: {
        pickerSearch.text = ""
        if (root.exerciseModel) root.exerciseModel.searchText = ""
    }
}
