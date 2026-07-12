import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page

    Dialog {
        id: detailDialog
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
            }
        }
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

        TextField {
            Layout.fillWidth: true
            placeholderText: qsTr("搜索动作、英文名或别名")
            onTextChanged: exerciseModel.searchText = text
        }

        ComboBox {
            Layout.fillWidth: true
            model: [qsTr("全部部位"), qsTr("胸部"), qsTr("背部"), qsTr("肩部"), qsTr("手臂"), qsTr("臀腿")]
            onActivated: exerciseModel.bodyPart = currentIndex === 0 ? "" : currentText
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

                width: exerciseList.width
                padding: 14
                TapHandler {
                    onTapped: {
                        detailDialog.exerciseName = name
                        detailDialog.introduction = introduction
                        detailDialog.steps = steps
                        detailDialog.cautions = cautions
                        detailDialog.primaryMuscles = primaryMuscles
                        detailDialog.secondaryMuscles = secondaryMuscles
                        detailDialog.mediaUrl = mediaUrl
                        detailDialog.mediaLicense = mediaLicense
                        detailDialog.mediaSourceUrl = mediaSourceUrl
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
