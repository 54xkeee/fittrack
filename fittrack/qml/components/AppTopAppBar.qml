import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import "../theme" as Design

Control {
    id: root

    property string title: ""
    property string titleObjectName: ""
    property string supportingText: ""
    property string leadingIcon: ""
    property string leadingAccessibleName: ""
    property Component trailingContent: null
    property bool elevated: false
    signal leadingTriggered()

    implicitHeight: Math.max(64, titleColumn.implicitHeight + Design.Theme.space16 * 2)
    padding: Design.Theme.space16

    background: Item {
        RectangularShadow {
            anchors.fill: topBarSurface
            visible: root.elevated
            offset: Qt.vector2d(0, Design.Theme.elevation1Offset)
            color: Design.Theme.elevation1Shadow
            blur: Design.Theme.elevation1Blur
            radius: 0
            cached: true
        }
        Rectangle {
            id: topBarSurface
            anchors.fill: parent
            color: root.elevated ? Design.Theme.surfaceContainerLow : Design.Theme.surface
        }
    }

    contentItem: RowLayout {
        spacing: Design.Theme.space12

        IconButton {
            visible: root.leadingIcon.length > 0
            iconName: root.leadingIcon
            accessibleName: root.leadingAccessibleName
            onClicked: root.leadingTriggered()
        }

        ColumnLayout {
            id: titleColumn
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 0

            Label {
                objectName: root.titleObjectName
                Layout.fillWidth: true
                text: root.title
                color: Design.Theme.surfaceText
                font.pixelSize: Design.Typography.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                visible: root.supportingText.length > 0
                Layout.fillWidth: true
                text: root.supportingText
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Typography.meta
                elide: Text.ElideRight
            }
        }

        Loader {
            active: root.trailingContent !== null
            sourceComponent: root.trailingContent
        }
    }
}
