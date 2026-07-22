pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppBottomSheet {
    id: root

    property var draftItems: []
    property string idKey: "id"
    property string contextId: ""
    property int dragFromIndex: -1
    property int dragToIndex: -1
    signal saveRequested(var orderedIds)

    function openExercises(items, key, targetId) {
        const copy = []
        for (let i = 0; i < (items || []).length; ++i)
            copy.push(items[i])
        draftItems = copy
        idKey = key || "id"
        contextId = targetId || ""
        dragFromIndex = -1
        dragToIndex = -1
        open()
    }

    function orderedIds() {
        const ids = []
        for (let i = 0; i < draftItems.length; ++i)
            ids.push(String(draftItems[i][idKey] || ""))
        return ids
    }

    function moveDraft(fromIndex, toIndex) {
        if (fromIndex < 0 || fromIndex >= draftItems.length
                || toIndex < 0 || toIndex >= draftItems.length
                || fromIndex === toIndex)
            return
        const copy = draftItems.slice()
        const moved = copy.splice(fromIndex, 1)[0]
        copy.splice(toIndex, 0, moved)
        draftItems = copy
    }

    function beginDrag(index) {
        dragFromIndex = index
        dragToIndex = index
    }

    function updateDrag(deltaY, rowHeight) {
        if (dragFromIndex < 0 || rowHeight <= 0)
            return
        dragToIndex = Math.max(0, Math.min(draftItems.length - 1,
                                           dragFromIndex + Math.round(deltaY / rowHeight)))
    }

    function finishDrag() {
        const fromIndex = dragFromIndex
        const toIndex = dragToIndex
        dragFromIndex = -1
        dragToIndex = -1
        moveDraft(fromIndex, toIndex)
    }

    objectName: "exerciseOrderSheet"
    title: qsTr("调整动作顺序")
    primaryText: qsTr("保存顺序")
    secondaryText: qsTr("取消")
    primaryEnabled: draftItems.length > 1
    autoAccept: false
    onPrimaryRequested: root.saveRequested(root.orderedIds())

    ColumnLayout {
        width: parent.width
        implicitHeight: instruction.implicitHeight
                        + Math.min(480, root.draftItems.length * 124)
                        + spacing
        spacing: Design.Theme.space12

        Label {
            id: instruction
            Layout.fillWidth: true
            text: qsTr("拖动手柄调整；也可以使用上移、下移。取消不会保存更改。")
            color: Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeLabel
            wrapMode: Text.WordWrap
        }

        ListView {
            id: orderList
            objectName: "exerciseOrderList"
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(480, root.draftItems.length * 124)
            model: root.draftItems
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: Design.Theme.space8

            delegate: Rectangle {
                id: orderRow
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Math.max(64, rowLayout.implicitHeight + Design.Theme.space16)
                radius: Design.Theme.radiusSmall
                color: root.dragToIndex === index && root.dragFromIndex !== index
                       ? Design.Theme.primaryContainer : Design.Theme.surfaceElevated
                border.width: root.dragToIndex === index && root.dragFromIndex !== index ? 2 : 1
                border.color: root.dragToIndex === index && root.dragFromIndex !== index
                              ? Design.Theme.primary : Design.Theme.outline

                RowLayout {
                    id: rowLayout
                    anchors.fill: parent
                    anchors.leftMargin: Design.Theme.space8
                    anchors.rightMargin: Design.Theme.space8
                    spacing: Design.Theme.space8

                    Rectangle {
                        objectName: "exerciseOrderDragHandle_" + orderRow.index
                        Layout.minimumWidth: Design.Theme.touchTarget
                        Layout.minimumHeight: Design.Theme.touchTarget
                        Layout.preferredWidth: Design.Theme.touchTarget
                        Layout.preferredHeight: Design.Theme.touchTarget
                        radius: Design.Theme.radiusSmall
                        color: reorderDrag.active ? Design.Theme.primaryContainer
                                                  : Design.Theme.surface
                        border.width: 1
                        border.color: reorderDrag.active ? Design.Theme.primary
                                                         : Design.Theme.outline
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("拖动%1调整顺序").arg(orderRow.modelData.name)

                        AppIcon {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            name: "reorder"
                            color: Design.Theme.surfaceText
                        }

                        DragHandler {
                            id: reorderDrag
                            target: null
                            onActiveChanged: {
                                if (active)
                                    root.beginDrag(orderRow.index)
                                else
                                    root.finishDrag()
                            }
                            onTranslationChanged: {
                                if (active)
                                    root.updateDrag(translation.y, orderRow.height + orderList.spacing)
                            }
                        }
                    }

                    Label {
                        text: orderRow.index + 1
                        color: Design.Theme.primary
                        font.pixelSize: Design.Theme.typeLabel
                        font.weight: Font.Bold
                    }

                    Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: orderRow.modelData.name || qsTr("未命名动作")
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeBody
                        elide: Text.ElideRight
                    }

                    ColumnLayout {
                        spacing: Design.Theme.space4
                        IconButton {
                            Layout.minimumWidth: Design.Theme.touchTarget
                            Layout.minimumHeight: Design.Theme.touchTarget
                            iconName: "up"
                            accessibleName: qsTr("上移%1").arg(orderRow.modelData.name)
                            enabled: orderRow.index > 0
                            onClicked: root.moveDraft(orderRow.index, orderRow.index - 1)
                        }
                        IconButton {
                            Layout.minimumWidth: Design.Theme.touchTarget
                            Layout.minimumHeight: Design.Theme.touchTarget
                            iconName: "down"
                            accessibleName: qsTr("下移%1").arg(orderRow.modelData.name)
                            enabled: orderRow.index + 1 < root.draftItems.length
                            onClicked: root.moveDraft(orderRow.index, orderRow.index + 1)
                        }
                    }
                }
            }
        }
    }
}
