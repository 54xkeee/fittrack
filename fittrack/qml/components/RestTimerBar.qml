import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Control {
    id: root

    property int remainingSeconds: 0
    property bool paused: false
    property string label: qsTr("组间休息")
    property bool allowStop: true

    readonly property string timeText: {
        const seconds = Math.max(0, remainingSeconds)
        const minutesPart = Math.floor(seconds / 60)
        const secondsPart = seconds % 60
        return String(minutesPart).padStart(2, "0") + ":" + String(secondsPart).padStart(2, "0")
    }

    signal pauseRequested()
    signal resumeRequested()
    signal stopRequested()

    implicitHeight: 56
    padding: Design.Theme.space8
    Accessible.name: qsTr("%1，剩余%2").arg(label).arg(timeText)

    background: Rectangle {
        radius: Design.Theme.radiusSmall
        color: Design.Theme.field
        border.width: root.activeFocus ? 1 : 0
        border.color: Design.Theme.accent
    }

    contentItem: RowLayout {
        spacing: Design.Theme.space8

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Label {
                text: root.paused ? qsTr("已暂停") : root.label
                color: root.paused ? Design.Theme.warning : Design.Theme.textTertiary
                font.pixelSize: Design.Theme.typeCaption
            }

            Label {
                text: root.timeText
                color: Design.Theme.textPrimary
                font.pixelSize: Design.Typography.exerciseTitle
                font.weight: Font.DemiBold
                font.family: "monospace"
            }
        }

        AppButton {
            text: root.paused ? qsTr("继续") : qsTr("暂停")
            variant: "secondary"
            flatSecondary: true
            cornerRadius: 14
            Layout.preferredWidth: 76
            onClicked: {
                if (root.paused)
                    root.resumeRequested()
                else
                    root.pauseRequested()
            }
        }

        IconButton {
            visible: root.allowStop
            iconName: "close"
            destructive: true
            accessibleName: qsTr("结束计时")
            onClicked: root.stopRequested()
        }
    }
}
