import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppDialog {
    id: root

    property var exerciseModel
    property string mode: "add"
    property string previousSearchText: ""
    signal previewRequested(string exerciseId)
    signal exerciseSelected(string exerciseId)
    signal dismissed()

    function openPicker(pickerMode) {
        mode = pickerMode || "add"
        errorText = ""
        previousSearchText = exerciseModel ? exerciseModel.searchText : ""
        pickerSearch.text = ""
        open()
        Qt.callLater(function() { pickerSearch.forceActiveFocus() })
    }

    objectName: "sharedExercisePickerSheet"
    width: Math.min(520, safeAvailableWidth)
    height: Math.min(680, safeAvailableHeight)
    title: mode === "replace" ? qsTr("替换动作") : qsTr("添加动作")
    primaryText: qsTr("关闭")
    primaryVariant: "secondary"
    secondaryVisible: false
    initialFocusItem: pickerSearch

    contentItem: ColumnLayout {
        spacing: Design.Theme.space8
        TextField {
            id: pickerSearch
            Layout.fillWidth: true
            implicitHeight: Design.Theme.controlHeight
            placeholderText: qsTr("搜索动作")
            Accessible.name: qsTr("搜索动作")
            onTextChanged: if (root.exerciseModel) root.exerciseModel.searchText = text
        }
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
        errorText = ""
        pickerSearch.text = ""
        if (root.exerciseModel) root.exerciseModel.searchText = previousSearchText
        dismissed()
    }
}
