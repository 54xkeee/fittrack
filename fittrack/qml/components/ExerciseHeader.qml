import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

RowLayout {
    id: root
    property string exerciseName: ""
    property url imageSource
    property string previewObjectName: ""
    property int setCount: 0
    property string repsText: ""
    property int restSeconds: 0
    property bool current: false
    signal previewRequested()
    signal optionsRequested()

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

    Button {
        objectName: root.previewObjectName
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: 48
        flat: true
        padding: 0
        Accessible.name: qsTr("查看%1动作做法").arg(root.exerciseName)
        onClicked: root.previewRequested()
        contentItem: ColumnLayout {
            spacing: Design.WorkoutTheme.space4
            Label {
                Layout.fillWidth: true
                text: root.exerciseName
                color: root.current ? Design.WorkoutTheme.primary
                                    : Design.WorkoutTheme.text
                font.pixelSize: Design.WorkoutTheme.typeExerciseTitle
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            ExerciseMetaRow {
                Layout.fillWidth: true
                setCount: root.setCount
                repsText: root.repsText
                restSeconds: root.restSeconds
            }
        }
        background: Item { }
    }

    Button {
        Layout.preferredWidth: Design.WorkoutTheme.iconTarget
        Layout.preferredHeight: Design.WorkoutTheme.iconTarget
        flat: true
        Accessible.name: qsTr("%1更多操作").arg(root.exerciseName)
        onClicked: root.optionsRequested()
        contentItem: AppIcon { name: "more"; color: Design.WorkoutTheme.textSecondary }
        background: Item { }
    }
}
