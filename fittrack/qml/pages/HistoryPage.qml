import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page

    function dateText(value) {
        const date = new Date(value)
        return isNaN(date.getTime()) ? value : Qt.formatDateTime(date, "yyyy-MM-dd hh:mm")
    }

    function muscleText(items) {
        if (!items || items.length === 0)
            return qsTr("暂无")
        let values = []
        for (let i = 0; i < items.length; ++i)
            values.push(items[i].name + " " + items[i].sets + qsTr("组"))
        return values.join("　")
    }

    header: ToolBar {
        Label {
            anchors.centerIn: parent
            text: qsTr("训练历史")
            font.pixelSize: 18
            font.bold: true
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 12

            Item { Layout.preferredHeight: 4 }

            Label {
                visible: workoutHistory.sessions.length === 0
                Layout.fillWidth: true
                text: qsTr("完成一次训练后，这里会显示历史记录。")
                horizontalAlignment: Text.AlignHCenter
                color: "#AEB7B1"
            }

            Repeater {
                model: workoutHistory.sessions
                delegate: ItemDelegate {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    text: modelData.name + "\n" + dateText(modelData.endedAt)
                          + "　" + modelData.exerciseCount + qsTr("个动作")
                          + "　" + modelData.setCount + qsTr("组")
                    onClicked: workoutHistory.selectSession(modelData.id)
                }
            }

            Frame {
                visible: workoutHistory.selectedSession.id !== undefined
                Layout.fillWidth: true
                Layout.leftMargin: 14
                Layout.rightMargin: 14
                padding: 18

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 9

                    Label {
                        text: workoutHistory.selectedSession.name || ""
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Label {
                        text: (workoutHistory.selectedSession.gymName || qsTr("未指定场地"))
                              + "　" + (workoutHistory.selectedSession.duration || "")
                        color: "#AEB7B1"
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8

                        Label { text: qsTr("正式组：%1").arg(workoutHistory.selectedSession.setCount || 0) }
                        Label { text: qsTr("总容量：%1 kg").arg(Number(workoutHistory.selectedSession.totalVolume || 0).toFixed(1)) }
                        Label {
                            text: workoutHistory.selectedSession.highestWeight > 0
                                  ? qsTr("最高：%1 %2 kg × %3 · %4组")
                                      .arg(workoutHistory.selectedSession.highestWeightExercise)
                                      .arg(workoutHistory.selectedSession.highestWeight)
                                      .arg(workoutHistory.selectedSession.highestWeightReps)
                                      .arg(workoutHistory.selectedSession.highestWeightSetCount)
                                  : qsTr("最高重量：暂无")
                        }
                        Label {
                            text: workoutHistory.selectedSession.bestOneRepMax > 0
                                  ? qsTr("e1RM：%1 kg").arg(Number(workoutHistory.selectedSession.bestOneRepMax).toFixed(1))
                                  : qsTr("e1RM：暂无")
                        }
                    }

                    Label {
                        visible: (workoutHistory.selectedSession.notes || "").length > 0
                        Layout.fillWidth: true
                        text: qsTr("训练备注：") + workoutHistory.selectedSession.notes
                        wrapMode: Text.WordWrap
                        color: "#C7CFCA"
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("主要刺激：") + muscleText(workoutHistory.selectedSession.primaryMuscles)
                        wrapMode: Text.WordWrap
                        color: "#C7CFCA"
                    }
                    Label {
                        Layout.fillWidth: true
                        text: qsTr("次要参与：") + muscleText(workoutHistory.selectedSession.secondaryMuscles)
                        wrapMode: Text.WordWrap
                        color: "#AEB7B1"
                    }

                    Repeater {
                        model: workoutHistory.selectedSession.exercises || []
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 3

                            Label {
                                text: modelData.name + (modelData.equipmentName ? " · " + modelData.equipmentName : "")
                                font.bold: true
                            }
                            Label {
                                text: qsTr("容量 %1 kg").arg(Number(modelData.volume).toFixed(1))
                                color: "#AEB7B1"
                            }
                            Repeater {
                                model: modelData.sets
                                delegate: Label {
                                    required property var modelData
                                    text: Number(modelData.weightKg) + " kg × " + modelData.reps
                                          + (modelData.toFailure ? qsTr(" · 力竭") : "")
                                    color: "#C7CFCA"
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
