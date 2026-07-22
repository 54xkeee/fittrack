import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Rectangle {
    id: root
    property string durationText: "00:00"
    property string volumeText: "0 kg"
    property int completedSets: 0

    implicitHeight: 66
    radius: Design.WorkoutTheme.cardRadius
    color: Design.Theme.surfaceContainerLow
    border.width: 0

    RowLayout {
        anchors.fill: parent
        anchors.margins: Design.WorkoutTheme.cardPadding
        spacing: Design.WorkoutTheme.space12

        Repeater {
            model: [
                {"label": qsTr("训练时间"), "value": root.durationText},
                {"label": qsTr("总容量"), "value": root.volumeText},
                {"label": qsTr("已完成组数"), "value": qsTr("%1 组").arg(root.completedSets)}
            ]
            delegate: RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: Design.WorkoutTheme.space12
                Rectangle {
                    visible: index > 0
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    color: Design.WorkoutTheme.divider
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label {
                        text: modelData.label
                        color: Design.WorkoutTheme.textMuted
                        font.pixelSize: Design.WorkoutTheme.typeMeta
                    }
                    Label {
                        text: modelData.value
                        color: Design.WorkoutTheme.text
                        font.pixelSize: Design.WorkoutTheme.typeStatistic
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
