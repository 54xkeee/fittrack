import QtQuick
import QtQuick.Layouts
import "../theme" as Design

Rectangle {
    id: root
    default property alias contentData: content.data
    property bool active: false

    implicitHeight: content.implicitHeight + Design.WorkoutTheme.cardPadding * 2
    radius: Design.WorkoutTheme.cardRadius
    color: Design.WorkoutTheme.card
    border.width: 1
    border.color: Design.WorkoutTheme.divider
    activeFocusOnTab: true

    // Active state is a small positional cue, not an editor-like blue frame.
    Rectangle {
        visible: root.active
        width: 3
        height: 32
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: Design.WorkoutTheme.primary
        radius: 2
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Design.WorkoutTheme.cardPadding
        spacing: Design.WorkoutTheme.space8
    }
}
