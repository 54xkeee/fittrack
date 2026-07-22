import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Control {
    id: root

    property var items: []
    property int currentIndex: 0
    signal destinationRequested(int index)

    implicitHeight: visible
                    ? Math.max(80, Design.Typography.bodyCompact + Design.Typography.meta
                               + Design.Theme.space12) + SafeArea.margins.bottom
                    : 0
    padding: 0
    Accessible.role: Accessible.PageTabList

    background: Rectangle {
        color: Design.Theme.surfaceContainerLowest
        border.width: 1
        border.color: Design.Theme.outlineVariant
    }

    contentItem: RowLayout {
        spacing: Design.Theme.space4

        Repeater {
            model: root.items
            delegate: Button {
                id: navigationButton
                required property var modelData
                required property int index

                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: Design.Theme.touchTarget
                padding: 0
                flat: true
                Accessible.name: modelData.label
                Accessible.role: Accessible.PageTab
                Accessible.selected: root.currentIndex === index
                Accessible.onPressAction: root.destinationRequested(index)
                onClicked: root.destinationRequested(index)

                contentItem: ColumnLayout {
                    spacing: 0
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 32
                        Rectangle {
                            anchors.centerIn: parent
                            width: 64
                            height: 32
                            radius: Design.Theme.radiusPill
                            color: root.currentIndex === navigationButton.index
                                   ? Design.Theme.primaryContainer : "transparent"
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            name: navigationButton.modelData.icon
                            width: 20
                            height: 20
                            color: root.currentIndex === navigationButton.index
                                   ? Design.Theme.primaryContainerText
                                   : Design.Theme.textSecondary
                        }
                    }
                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: navigationButton.modelData.label
                        color: root.currentIndex === navigationButton.index
                               ? Design.Theme.primary : Design.Theme.textSecondary
                        font.pixelSize: Design.Typography.meta
                        font.weight: root.currentIndex === navigationButton.index
                                     ? Font.DemiBold : Font.Normal
                    }
                }

                background: Rectangle {
                    radius: Design.Theme.radiusSmall
                    color: "transparent"
                    border.width: navigationButton.activeFocus ? 1 : 0
                    border.color: Design.Theme.primary
                }
            }
        }
    }
}
