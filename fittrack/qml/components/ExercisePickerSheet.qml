import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppBottomSheet {
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
    title: mode === "replace" ? qsTr("替换动作") : qsTr("添加动作")
    primaryText: qsTr("关闭")
    primaryVariant: "secondary"
    secondaryVisible: false
    initialFocusItem: pickerSearch

    ColumnLayout {
        width: parent.width
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
            Layout.preferredHeight: Math.min(480, Math.max(240, count * 72))
            model: root.exerciseModel
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0

            delegate: ItemDelegate {
                id: exerciseOption
                required property string exerciseId
                required property string name
                required property string bodyPart
                required property int recommendedSets
                required property string recommendedReps
                width: ListView.view.width
                implicitHeight: 76
                leftPadding: Design.Theme.space12
                rightPadding: Design.Theme.space8
                topPadding: Design.Theme.space8
                bottomPadding: Design.Theme.space8
                Accessible.name: exerciseOption.name
                Accessible.description: qsTr("%1，推荐 %2 组 %3 次，点击预览")
                                        .arg(exerciseOption.bodyPart)
                                        .arg(exerciseOption.recommendedSets)
                                        .arg(exerciseOption.recommendedReps)
                onClicked: root.previewRequested(exerciseOption.exerciseId)

                contentItem: RowLayout {
                    id: optionLayout
                    spacing: Design.Theme.space12

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: Design.Theme.space4

                        Label {
                            Layout.fillWidth: true
                            text: exerciseOption.name
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeBody
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Label {
                            Layout.fillWidth: true
                            text: qsTr("%1 · %2组 · %3")
                                  .arg(exerciseOption.bodyPart)
                                  .arg(exerciseOption.recommendedSets)
                                  .arg(exerciseOption.recommendedReps)
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                            elide: Text.ElideRight
                        }
                    }

                    AppButton {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: Design.Theme.heightDefault
                        cornerRadius: Design.Theme.radiusInput
                        text: root.mode === "replace" ? qsTr("替换") : qsTr("添加")
                        Accessible.description: exerciseOption.name
                        onClicked: root.exerciseSelected(exerciseOption.exerciseId)
                    }
                }

                background: Item {
                    Rectangle {
                        anchors.fill: parent
                        color: exerciseOption.down ? Design.Theme.surfacePressed : "transparent"
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Design.Theme.outlineVariant
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
