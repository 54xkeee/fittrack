import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import "../theme" as Design

Control {
    id: root
    property string progressText: ""
    signal backRequested()
    signal timerRequested()
    signal finishRequested()

    implicitHeight: 72
    padding: Design.WorkoutTheme.space12

    background: Item {
        RectangularShadow {
            anchors.fill: topBarSurface
            offset: Qt.vector2d(0, Design.Theme.elevation1Offset)
            color: Design.Theme.elevation1Shadow
            blur: Design.Theme.elevation1Blur
            radius: topBarSurface.radius
            cached: true
        }
        Rectangle {
            id: topBarSurface
            anchors.fill: parent
            radius: Design.WorkoutTheme.cardRadius
            color: Design.Theme.surfaceContainerHigh
        }
    }

    contentItem: RowLayout {
        spacing: Design.WorkoutTheme.space8

        IconButton {
            iconName: "back"
            accessibleName: qsTr("返回")
            onClicked: root.backRequested()
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

        IconButton {
            iconName: "history"
            accessibleName: qsTr("休息计时")
            onClicked: root.timerRequested()
        }

        Button {
            Layout.preferredWidth: 68
            Layout.preferredHeight: 44
            text: qsTr("完成")
            onClicked: root.finishRequested()
            contentItem: Label {
                text: parent.text
                color: Design.WorkoutTheme.primaryForeground
                font.pixelSize: Design.Theme.typeLabel
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
}
