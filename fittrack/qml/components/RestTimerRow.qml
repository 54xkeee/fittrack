import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

RowLayout {
    id: root

    property int timerState: 0
    property int remainingSeconds: 0
    property int defaultSeconds: 120

    signal configureRequested()
    signal pauseRequested()
    signal resumeRequested()
    signal stopRequested()

    function clockText(seconds) {
        const value = Math.max(0, Number(seconds || 0))
        return Math.floor(value / 60) + ":" + String(value % 60).padStart(2, "0")
    }

    implicitHeight: 44
    spacing: Design.WorkoutTheme.space8

    AppIcon {
        name: "history"
        color: Design.WorkoutTheme.primary
    }

    Button {
        objectName: "openRestTimerButton"
        Layout.fillWidth: true
        Layout.preferredHeight: Design.WorkoutTheme.iconTarget
        flat: true
        padding: 0
        Accessible.name: qsTr("休息计时")
        onClicked: root.configureRequested()
        contentItem: RowLayout {
            spacing: 6
            Label {
                text: root.timerState === 1 || root.timerState === 2
                      ? qsTr("休息计时") : qsTr("休息时间")
                color: Design.WorkoutTheme.textSecondary
                font.pixelSize: Design.WorkoutTheme.typeBody
            }
            Label {
                text: root.clockText(root.timerState === 1 || root.timerState === 2
                                     ? root.remainingSeconds : root.defaultSeconds)
                color: Design.WorkoutTheme.primary
                font.pixelSize: Design.WorkoutTheme.typeBody
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
        background: Item { }
    }

    Button {
        visible: root.timerState === 1 || root.timerState === 2
        Layout.preferredWidth: 54
        Layout.preferredHeight: Design.WorkoutTheme.iconTarget
        text: root.timerState === 2 ? qsTr("继续") : qsTr("暂停")
        onClicked: root.timerState === 2 ? root.resumeRequested() : root.pauseRequested()
        contentItem: Label {
            text: parent.text
            color: Design.WorkoutTheme.secondaryText
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: parent.down ? Design.WorkoutTheme.divider
                               : Design.WorkoutTheme.secondaryFill
        }
    }

    Button {
        visible: root.timerState === 1 || root.timerState === 2
        Layout.preferredWidth: 52
        Layout.preferredHeight: Design.WorkoutTheme.iconTarget
        flat: true
        text: qsTr("跳过")
        onClicked: root.stopRequested()
        contentItem: Label {
            text: parent.text
            color: Design.WorkoutTheme.primary
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Item { }
    }
}
