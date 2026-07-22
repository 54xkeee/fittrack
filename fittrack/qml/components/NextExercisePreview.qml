import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

// Compact hand-off to one upcoming exercise. The current exercise remains the
// only place where sets can be entered or completed.
Rectangle {
    id: root

    property string exerciseName: ""
    property url imageSource
    property int setCount: 0
    property string repsText: ""
    property int restSeconds: 0
    property int completedSets: 0
    property string previewObjectName: ""

    signal previewRequested()

    implicitHeight: 82
    radius: Design.WorkoutTheme.cardRadius
    color: previewButton.down ? Design.Theme.surfaceContainerHigh
                              : Design.Theme.surfaceContainerLow
    border.width: root.activeFocus ? 2 : 0
    border.color: root.activeFocus ? Design.WorkoutTheme.primary
                                   : Design.WorkoutTheme.divider
    activeFocusOnTab: visible && enabled
    Accessible.role: Accessible.Button
    Accessible.name: qsTr("接下来：%1").arg(root.exerciseName)

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                || event.key === Qt.Key_Space) {
            root.previewRequested()
            event.accepted = true
        }
    }

    Behavior on border.color {
        ColorAnimation { duration: 120 }
    }

    Button {
        id: previewButton
        objectName: root.previewObjectName
        anchors.fill: parent
        flat: true
        padding: 0
        activeFocusOnTab: false
        Accessible.ignored: true
        onClicked: root.previewRequested()

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Design.WorkoutTheme.space12
            anchors.rightMargin: Design.WorkoutTheme.space8
            spacing: Design.WorkoutTheme.space12

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 8
                color: Design.WorkoutTheme.input
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root.imageSource
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 2

                Label {
                    Layout.fillWidth: true
                    text: qsTr("接下来")
                    color: Design.WorkoutTheme.primary
                    font.pixelSize: Design.WorkoutTheme.typeMeta
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    text: root.exerciseName
                    color: Design.WorkoutTheme.text
                    font.pixelSize: Design.WorkoutTheme.typeExerciseTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Label {
                    Layout.fillWidth: true
                    text: qsTr("%1组 · %2 · 休息%3秒")
                          .arg(root.setCount)
                          .arg(root.repsText || qsTr("自定次数"))
                          .arg(root.restSeconds)
                    color: Design.WorkoutTheme.textSecondary
                    font.pixelSize: Design.WorkoutTheme.typeMeta
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Design.WorkoutTheme.space4

                Label {
                    visible: root.completedSets > 0
                    text: qsTr("%1/%2").arg(root.completedSets).arg(root.setCount)
                    color: Design.WorkoutTheme.textMuted
                    font.pixelSize: Design.WorkoutTheme.typeMeta
                }

                Label {
                    text: qsTr("查看")
                    color: Design.WorkoutTheme.primary
                    font.pixelSize: Design.WorkoutTheme.typeMeta
                    font.weight: Font.Medium
                }

                AppIcon {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    name: "forward"
                    color: Design.WorkoutTheme.primary
                    strokeWidth: 1.8
                }
            }
        }

        background: Item { }
    }
}
