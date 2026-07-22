import QtQuick
import QtQuick.Controls
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
    signal leadingTriggered()

    implicitHeight: Math.max(64, titleColumn.implicitHeight + Design.Theme.space16 * 2)
    padding: Design.Theme.space16

    background: Rectangle { color: Design.Theme.surface }

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
                color: Design.Theme.onSurface
                font.pixelSize: Design.Typography.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Label {
                visible: root.supportingText.length > 0
                Layout.fillWidth: true
                text: root.supportingText
                color: Design.Theme.onSurfaceVariant
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
