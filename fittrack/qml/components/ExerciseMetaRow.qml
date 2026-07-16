import QtQuick
import QtQuick.Controls
import "../theme" as Design

Label {
    property int setCount: 0
    property string repsText: ""
    property int restSeconds: 0
    text: qsTr("%1组 · %2 · 休息%3秒").arg(setCount).arg(repsText).arg(restSeconds)
    color: Design.WorkoutTheme.textSecondary
    font.pixelSize: Design.WorkoutTheme.typeMeta
    elide: Text.ElideRight
}
