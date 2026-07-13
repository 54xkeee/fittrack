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

    implicitHeight: Math.max(72,
                             Design.Theme.typeCaption + Design.Theme.typeTitle
                             + Design.Theme.space24)
    padding: Design.Theme.space12
    Accessible.name: qsTr("%1，剩余%2").arg(label).arg(timeText)

    background: Rectangle {
        radius: Design.Theme.radiusMedium
        color: Design.Theme.surfaceElevated
        border.width: 1
        border.color: root.paused ? Design.Theme.warning : Design.Theme.outline
    }

    contentItem: RowLayout {
        spacing: Design.Theme.space12

        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true

            Label {
                text: root.paused ? qsTr("已暂停") : root.label
                color: root.paused ? Design.Theme.warning : Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeCaption
            }

            Label {
                text: root.timeText
                color: Design.Theme.surfaceText
                font.pixelSize: Design.Theme.typeTitle
                font.weight: Font.DemiBold
                font.family: "monospace"
            }
        }

        AppButton {
            text: root.paused ? qsTr("继续") : qsTr("暂停")
            variant: "secondary"
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
            glyph: "×"
            destructive: true
            accessibleName: qsTr("结束计时")
            onClicked: root.stopRequested()
        }
    }
}
