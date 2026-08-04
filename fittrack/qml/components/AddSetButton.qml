import QtQuick
import QtQuick.Controls
import "../theme" as Design

Button {
    implicitHeight: Design.WorkoutTheme.inputHeight
    text: qsTr("+ 添加一组")
    contentItem: Label {
        text: parent.text
        color: Design.WorkoutTheme.secondaryText
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: Design.WorkoutTheme.controlRadius
        color: parent.down ? Design.WorkoutTheme.primarySoft
                           : Design.WorkoutTheme.secondaryFill
    }
}
