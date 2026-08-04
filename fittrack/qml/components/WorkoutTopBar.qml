import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

RowLayout {
    id: root
    property string progressText: ""
    signal backRequested()
    signal timerRequested()
    signal finishRequested()

    spacing: Design.WorkoutTheme.space8

    Button {
        Layout.preferredWidth: Design.WorkoutTheme.iconTarget
        Layout.preferredHeight: Design.WorkoutTheme.iconTarget
        flat: true
        Accessible.name: qsTr("返回")
        onClicked: root.backRequested()
        contentItem: AppIcon { name: "back"; color: Design.WorkoutTheme.text }
        background: Item { }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Label {
            objectName: "trainingSessionTitle"
            text: qsTr("记录训练")
            color: Design.WorkoutTheme.text
            font.pixelSize: Design.WorkoutTheme.typePageTitle
            font.weight: Font.DemiBold
        }
        Label {
            Layout.fillWidth: true
            text: root.progressText
            color: Design.WorkoutTheme.textSecondary
            font.pixelSize: Design.WorkoutTheme.typeMeta
            elide: Text.ElideRight
        }
    }

    Button {
        Layout.preferredWidth: Design.WorkoutTheme.iconTarget
        Layout.preferredHeight: Design.WorkoutTheme.iconTarget
        flat: true
        Accessible.name: qsTr("休息计时")
        onClicked: root.timerRequested()
        contentItem: AppIcon { name: "history"; color: Design.WorkoutTheme.textSecondary }
        background: Item { }
    }

    Button {
        Layout.preferredWidth: 68
        Layout.preferredHeight: 44
        text: qsTr("完成")
        onClicked: root.finishRequested()
        contentItem: Label {
            text: parent.text
            color: "white"
            font.pixelSize: 14
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: Design.WorkoutTheme.controlRadius
            color: parent.down ? Design.WorkoutTheme.primaryPressed
                               : Design.WorkoutTheme.primary
        }
    }
}
