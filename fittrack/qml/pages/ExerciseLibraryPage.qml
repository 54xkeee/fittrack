import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    implicitWidth: 0

    Dialog {
        id: detailDialog
        property string exerciseId: ""
        property bool isSystem: true
        property bool isFavorite: false
        property string exerciseName: ""
        property string introduction: ""
        property var steps: []
        property var cautions: []
        property var primaryMuscles: []
        property var secondaryMuscles: []
        property string mediaUrl: ""
        property string mediaLicense: ""
        property string mediaSourceUrl: ""
        property string recommendation: ""
        property string movement: ""
        property string equipmentText: ""
        property int recommendedSets: 3
        property string recommendedReps: "8-12"
        property int restSeconds: 90

        anchors.centerIn: parent
        width: Math.min(page.width - 20, 600)
        height: Math.min(page.height - 30, 780)
        modal: true
        title: exerciseName
        standardButtons: Dialog.Close

        ScrollView {
            anchors.fill: parent
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: 10
                Rectangle {
                    visible: detailDialog.mediaUrl.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 220 : 0
                    color: "#F1F3F2"
                    radius: 8
                    Image {
                        anchors.fill: parent
                        anchors.margins: 8
                        source: detailDialog.mediaUrl
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }
                Label {
                    visible: detailDialog.mediaUrl.length === 0
                    text: qsTr("暂无许可明确的本地图片")
                    color: "#7E8982"
                }
                Label { Layout.fillWidth: true; text: detailDialog.introduction; wrapMode: Text.WordWrap }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("主要肌群：") + detailDialog.primaryMuscles.join("、")
                    color: "#8BD450"
                    wrapMode: Text.WordWrap
                }
                Label {
                    Layout.fillWidth: true
                    text: qsTr("次要肌群：") + detailDialog.secondaryMuscles.join("、")
                    color: "#AEB7B1"
                    wrapMode: Text.WordWrap
                }
                Label { text: qsTr("动作步骤"); font.bold: true; font.pixelSize: 17 }
                Repeater {
                    model: detailDialog.steps
                    delegate: Label {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        text: (index + 1) + ". " + modelData
                        wrapMode: Text.WordWrap
                    }
                }
                Label { text: qsTr("注意点"); font.bold: true; font.pixelSize: 17 }
                Repeater {
                    model: detailDialog.cautions
                    delegate: Label {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "• " + modelData
                        wrapMode: Text.WordWrap
                    }
                }
                Label { Layout.fillWidth: true; text: detailDialog.recommendation; color: "#AEB7B1"; wrapMode: Text.WordWrap }
                Button {
                    visible: detailDialog.mediaSourceUrl.length > 0
                    text: qsTr("查看图片来源与许可 · ") + detailDialog.mediaLicense
                    onClicked: Qt.openUrlExternally(detailDialog.mediaSourceUrl)
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        Layout.fillWidth: true
                        text: detailDialog.isFavorite ? qsTr("★ 已收藏") : qsTr("☆ 收藏")
                        onClicked: {
                            exerciseModel.toggleFavorite(detailDialog.exerciseId)
                            detailDialog.isFavorite = !detailDialog.isFavorite
                        }
                    }
                    Button {
                        visible: !detailDialog.isSystem
                        text: qsTr("编辑")
                        onClicked: {
                            customDialog.editingId = detailDialog.exerciseId
                            customName.text = detailDialog.exerciseName
                            customBodyPart.text = detailDialog.primaryMuscles.length > 0
                                    ? detailDialog.primaryMuscles[0] : ""
                            customMovement.text = detailDialog.movement
                            customEquipment.text = detailDialog.equipmentText
                            customIntro.text = detailDialog.introduction
                            customSets.value = detailDialog.recommendedSets
                            customReps.text = detailDialog.recommendedReps
                            customRest.value = detailDialog.restSeconds
                            customDialog.open()
                            detailDialog.close()
                        }
                    }
                    Button {
                        visible: !detailDialog.isSystem
                        text: qsTr("删除")
                        onClicked: {
                            exerciseModel.deleteCustomExercise(detailDialog.exerciseId)
                            detailDialog.close()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: customDialog
        property string editingId: ""
        anchors.centerIn: parent
        width: Math.min(page.width - 20, 520)
        height: Math.min(page.height - 40, 700)
        title: editingId.length > 0 ? qsTr("编辑自定义动作") : qsTr("新建自定义动作")
        standardButtons: Dialog.Save | Dialog.Cancel
        onAccepted: {
            if (editingId.length > 0) {
                exerciseModel.updateCustomExercise(editingId, customName.text, customBodyPart.text,
                    customMovement.text, customEquipment.text, customIntro.text,
                    customSets.value, customReps.text, customRest.value)
            } else {
                exerciseModel.createCustomExercise(customName.text, customBodyPart.text,
                    customMovement.text, customEquipment.text, customIntro.text,
                    customSets.value, customReps.text, customRest.value)
            }
        }
        ScrollView {
            anchors.fill: parent
            ColumnLayout {
                width: parent.width
                TextField { id: customName; Layout.fillWidth: true; placeholderText: qsTr("动作名称（必填）") }
                TextField { id: customBodyPart; Layout.fillWidth: true; placeholderText: qsTr("主要肌群，例如上胸（必填）") }
                TextField { id: customMovement; Layout.fillWidth: true; placeholderText: qsTr("动作模式，例如水平推（必填）") }
                TextField { id: customEquipment; Layout.fillWidth: true; placeholderText: qsTr("器械，例如固定器械") }
                TextArea { id: customIntro; Layout.fillWidth: true; placeholderText: qsTr("动作简介，可选"); wrapMode: TextEdit.Wrap }
                RowLayout {
                    Label { text: qsTr("组数") }
                    SpinBox { id: customSets; from: 1; to: 20; value: 3 }
                    TextField { id: customReps; Layout.fillWidth: true; placeholderText: qsTr("次数，如8-12") }
                }
                RowLayout {
                    Label { text: qsTr("间歇秒数") }
                    SpinBox { id: customRest; from: 0; to: 600; value: 90; editable: true }
                }
            }
        }
    }

    Dialog {
        id: restoreDialog
        anchors.centerIn: parent
        title: qsTr("恢复系统动作")
        standardButtons: Dialog.Yes | Dialog.No
        Label { text: qsTr("恢复32个系统动作的默认资料？不会删除自定义动作和历史。") ; wrapMode: Text.WordWrap }
        onAccepted: exerciseModel.restoreSystemExercises()
    }

    header: ToolBar {
        Label {
            anchors.centerIn: parent
            text: qsTr("动作资料库")
            font.pixelSize: 18
            font.bold: true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            TextField {
                Layout.fillWidth: true
                placeholderText: qsTr("搜索动作、英文名或别名")
                onTextChanged: exerciseModel.searchText = text
            }
            Button {
                text: qsTr("新建")
                onClicked: {
                    customDialog.editingId = ""
                    customName.text = ""
                    customBodyPart.text = ""
                    customMovement.text = ""
                    customEquipment.text = ""
                    customIntro.text = ""
                    customSets.value = 3
                    customReps.text = "8-12"
                    customRest.value = 90
                    customDialog.open()
                }
            }
            ToolButton { text: qsTr("恢复"); onClicked: restoreDialog.open() }
        }

        RowLayout {
            Layout.fillWidth: true
            ComboBox {
                Layout.fillWidth: true
                model: [qsTr("全部部位"), qsTr("胸部"), qsTr("背部"), qsTr("肩部"), qsTr("手臂"), qsTr("臀腿")]
                onActivated: exerciseModel.bodyPart = currentIndex === 0 ? "" : currentText
            }
            ComboBox {
                Layout.fillWidth: true
                model: [qsTr("全部模式"), qsTr("水平推"), qsTr("水平拉"), qsTr("垂直拉"), qsTr("蹲"), qsTr("髋铰链")]
                onActivated: exerciseModel.movementFilter = currentIndex === 0 ? "" : currentText
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ComboBox {
                Layout.fillWidth: true
                model: [qsTr("全部器械"), qsTr("杠铃"), qsTr("哑铃"), qsTr("钢线"), qsTr("固定器械"), qsTr("自重")]
                onActivated: exerciseModel.equipmentFilter = currentIndex === 0 ? "" : currentText
            }
            CheckBox {
                text: qsTr("只看收藏")
                checked: exerciseModel.favoritesOnly
                onToggled: exerciseModel.favoritesOnly = checked
            }
        }

        Label {
            text: qsTr("共 %1 个动作").arg(exerciseList.count)
            color: "#AEB7B1"
        }

        ListView {
            id: exerciseList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: exerciseModel

            delegate: Frame {
                required property string name
                required property string bodyPart
                required property string movement
                required property int recommendedSets
                required property string recommendedReps
                required property int restSeconds
                required property string introduction
                required property var steps
                required property var cautions
                required property var primaryMuscles
                required property var secondaryMuscles
                required property string mediaUrl
                required property string mediaLicense
                required property string mediaSourceUrl
                required property string exerciseId
                required property bool isSystem
                required property bool isFavorite
                required property string equipmentText

                width: exerciseList.width
                padding: 14
                TapHandler {
                    onTapped: {
                        detailDialog.exerciseName = name
                        detailDialog.exerciseId = exerciseId
                        detailDialog.isSystem = isSystem
                        detailDialog.isFavorite = isFavorite
                        detailDialog.introduction = introduction
                        detailDialog.steps = steps
                        detailDialog.cautions = cautions
                        detailDialog.primaryMuscles = primaryMuscles
                        detailDialog.secondaryMuscles = secondaryMuscles
                        detailDialog.mediaUrl = mediaUrl
                        detailDialog.mediaLicense = mediaLicense
                        detailDialog.mediaSourceUrl = mediaSourceUrl
                        detailDialog.movement = movement
                        detailDialog.equipmentText = equipmentText
                        detailDialog.recommendedSets = recommendedSets
                        detailDialog.recommendedReps = recommendedReps
                        detailDialog.restSeconds = restSeconds
                        detailDialog.recommendation = qsTr("建议 %1组 · %2 · 休息%3秒")
                            .arg(recommendedSets).arg(recommendedReps).arg(restSeconds)
                        detailDialog.open()
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 5

                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: name; font.pixelSize: 17; font.bold: true; Layout.fillWidth: true }
                        Label { text: bodyPart; color: "#8BD450" }
                    }
                    Label { text: movement; color: "#AEB7B1" }
                    Label {
                        text: qsTr("建议 %1组 · %2 · 休息%3秒")
                            .arg(recommendedSets).arg(recommendedReps).arg(restSeconds)
                        color: "#7E8982"
                        font.pixelSize: 12
                    }
                }
            }

            Label {
                anchors.centerIn: parent
                visible: exerciseList.count === 0
                text: qsTr("没有匹配的动作")
                color: "#7E8982"
            }
        }
    }
}
