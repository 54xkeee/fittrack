import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

RowLayout {
    implicitHeight: 28
    spacing: Design.WorkoutTheme.tableColumnSpacing
    Repeater {
        model: [
            {"text": qsTr("组"), "width": Design.WorkoutTheme.setColumnWidth},
            {"text": qsTr("上次记录"), "width": -1},
            {"text": qsTr("kg"), "width": Design.WorkoutTheme.weightColumnWidth},
            {"text": qsTr("次数"), "width": Design.WorkoutTheme.repsColumnWidth},
            {"text": qsTr("状态"), "width": Design.WorkoutTheme.statusColumnWidth}
        ]
        delegate: Label {
            required property var modelData
            Layout.preferredWidth: modelData.width > 0 ? modelData.width : -1
            Layout.fillWidth: modelData.width < 0
            text: modelData.text
            color: Design.WorkoutTheme.textMuted
            font.pixelSize: Design.WorkoutTheme.typeTableHeader
            font.weight: Font.Medium
            horizontalAlignment: modelData.width > 0 ? Text.AlignHCenter : Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
        }
    }
}
