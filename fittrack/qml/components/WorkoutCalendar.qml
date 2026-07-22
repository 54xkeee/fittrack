import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Item {
    id: root

    property var monthData: ({})
    property string selectedDate: ""
    property var selectedSession: ({})

    signal previousMonthRequested()
    signal nextMonthRequested()
    signal todayRequested()
    signal dateRequested(string date)
    signal openSessionRequested(string sessionId)

    function dateLabel(value) {
        const parts = String(value || "").split("-")
        return parts.length === 3
                ? qsTr("%1月%2日").arg(Number(parts[1])).arg(Number(parts[2]))
                : qsTr("训练详情")
    }

    function sessionExercises() {
        const exercises = selectedSession && selectedSession.exercises
                ? selectedSession.exercises : []
        return exercises.slice(0, 2)
    }

    implicitHeight: content.implicitHeight

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Design.Theme.space12

        RowLayout {
            Layout.fillWidth: true
            spacing: Design.Theme.space4

            IconButton {
                iconName: "back"
                accessibleName: qsTr("上一个月")
                implicitWidth: 32
                implicitHeight: 32
                onClicked: root.previousMonthRequested()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Label {
                    Layout.fillWidth: true
                    text: root.monthData.title || qsTr("训练日历")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeTitle
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }

                Label {
                    Layout.fillWidth: true
                    text: qsTr("本月训练 %1 天 · 连续 %2 天")
                          .arg(root.monthData.trainingDays || 0)
                          .arg(root.monthData.longestStreak || 0)
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeCaption
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            IconButton {
                iconName: "forward"
                accessibleName: qsTr("下一个月")
                implicitWidth: 32
                implicitHeight: 32
                onClicked: root.nextMonthRequested()
            }

            AppButton {
                text: qsTr("回到今天")
                variant: "secondary"
                flatSecondary: true
                implicitWidth: 72
                implicitHeight: 32
                onClicked: root.todayRequested()
            }
        }

        AppCard {
            Layout.fillWidth: true
            padding: Design.Theme.space16

            ColumnLayout {
                anchors.fill: parent
                spacing: Design.Theme.space8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space4

                    Repeater {
                        model: [qsTr("一"), qsTr("二"), qsTr("三"), qsTr("四"),
                                qsTr("五"), qsTr("六"), qsTr("日")]
                        delegate: Label {
                            required property string modelData
                            Layout.fillWidth: true
                            text: modelData
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 4
                    rowSpacing: 6

                    Repeater {
                        model: root.monthData.cells || []
                        delegate: Button {
                            id: dayButton
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.max(36, Math.min(44, (root.width - 32 - 24) / 7))
                            Layout.minimumHeight: Math.max(36, Math.min(44, (root.width - 32 - 24) / 7))
                            enabled: Boolean(modelData.currentMonth)
                            flat: true
                            padding: 0
                            Accessible.name: modelData.currentMonth
                                             ? qsTr("%1，%2").arg(modelData.day)
                                               .arg(modelData.sessionCount > 0
                                                    ? qsTr("已训练") : qsTr("未训练"))
                                             : qsTr("空白日期")
                            onClicked: root.dateRequested(modelData.date)

                            contentItem: Label {
                                text: dayButton.modelData.currentMonth
                                      ? String(dayButton.modelData.day) : ""
                                color: dayButton.modelData.intensity > 0
                                       ? Design.Theme.primaryForeground
                                       : Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeLabel
                                font.weight: dayButton.modelData.date === root.selectedDate
                                             ? Font.DemiBold : Font.Normal
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                radius: 7
                                color: !dayButton.modelData.currentMonth
                                       ? "transparent"
                                       : dayButton.modelData.intensity === 2
                                         ? Design.Theme.success
                                         : dayButton.modelData.intensity === 1
                                           ? Design.Theme.successSoft : Design.Theme.surfaceContainerLowest
                                border.width: dayButton.modelData.date === root.selectedDate ? 2 : 1
                                border.color: dayButton.modelData.date === root.selectedDate
                                              ? Design.Theme.primary
                                              : dayButton.modelData.intensity > 0
                                                ? "transparent" : Design.Theme.borderSubtle
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: Design.Theme.divider
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space12

                    Repeater {
                        model: [
                            {label: qsTr("未训练"), color: Design.Theme.surfaceContainerLowest},
                            {label: qsTr("已训练"), color: Design.Theme.successSoft},
                            {label: qsTr("高训练量"), color: Design.Theme.success}
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            spacing: 4
                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: modelData.color
                                border.width: modelData.label === qsTr("未训练") ? 1 : 0
                                border.color: Design.Theme.borderDefault
                            }
                            Label {
                                text: modelData.label
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeCaption
                            }
                        }
                    }
                }
            }
        }

        AppCard {
            Layout.fillWidth: true
            visible: root.selectedDate.length > 0 && root.selectedSession
                     && String(root.selectedSession.id || "").length > 0
            padding: Design.Theme.space16

            ColumnLayout {
                anchors.fill: parent
                spacing: Design.Theme.space8

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Label {
                            text: qsTr("%1 · %2").arg(root.dateLabel(root.selectedDate))
                                  .arg(root.selectedSession.name || qsTr("训练"))
                            color: Design.Theme.surfaceText
                            font.pixelSize: Design.Theme.typeBody
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Label {
                            text: root.selectedSession.endedAt
                                  ? qsTr("完成于 %1").arg(Qt.formatTime(
                                      new Date(root.selectedSession.endedAt), "HH:mm")) : ""
                            color: Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeCaption
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 26
                        radius: 5
                        color: Design.Theme.successSoft
                        Label {
                            anchors.centerIn: parent
                            text: qsTr("力量")
                            color: Design.Theme.successContainerText
                            font.pixelSize: Design.Theme.typeCaption
                            font.weight: Font.DemiBold
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: [
                            {value: root.selectedSession.durationMinutes || 0, label: qsTr("分钟")},
                            {value: Number(root.selectedSession.totalVolume || 0).toFixed(0), label: qsTr("kg")},
                            {value: root.selectedSession.setCount || 0, label: qsTr("组")},
                            {value: root.selectedSession.exerciseCount || 0, label: qsTr("个PR")}
                        ]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 0
                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 36
                                color: Design.Theme.divider
                                visible: index > 0
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: Design.Theme.surfaceText
                                    font.pixelSize: Design.Theme.typeBody
                                    font.weight: Font.DemiBold
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: Design.Theme.surfaceMuted
                                    font.pixelSize: Design.Theme.typeCaption
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }
                    }
                }

                Repeater {
                    model: root.sessionExercises()
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Design.Theme.space8
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 4
                            color: Design.Theme.primarySoft
                            Label {
                                anchors.centerIn: parent
                                text: "↗"
                                color: Design.Theme.primary
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Label {
                                Layout.fillWidth: true
                                text: modelData.name || qsTr("训练动作")
                                color: Design.Theme.surfaceText
                                font.pixelSize: Design.Theme.typeLabel
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Label {
                                text: qsTr("%1组 · 最高%2kg")
                                      .arg((modelData.sets || []).length)
                                      .arg(Number(modelData.highestWeight || modelData.volume || 0).toFixed(0))
                                color: Design.Theme.surfaceMuted
                                font.pixelSize: Design.Theme.typeCaption
                            }
                        }
                    }
                }

                AppButton {
                    Layout.fillWidth: true
                    text: qsTr("查看完整训练记录 →")
                    variant: "secondary"
                    flatSecondary: true
                    implicitHeight: 36
                    onClicked: root.openSessionRequested(String(root.selectedSession.id))
                }
            }
        }

        AppCard {
            Layout.fillWidth: true
            visible: root.selectedDate.length > 0 && (!root.selectedSession
                     || String(root.selectedSession.id || "").length === 0)
            implicitHeight: 76
            Label {
                anchors.centerIn: parent
                text: qsTr("%1没有训练记录").arg(root.dateLabel(root.selectedDate))
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
            }
        }
    }
}

