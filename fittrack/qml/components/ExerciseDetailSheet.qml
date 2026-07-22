import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppBottomSheet {
    id: root

    property var exercise: ({})
    property int mediaIndex: 0
    readonly property var mediaItems: exercise.mediaItems || []
    readonly property var currentMedia: mediaItems.length > mediaIndex
                                        ? mediaItems[mediaIndex] : ({})

    function openExercise(data) {
        exercise = data || ({})
        mediaIndex = 0
        open()
    }

    function muscleSummary() {
        const parts = []
        const muscles = root.exercise.primaryMuscles || []
        for (let i = 0; i < muscles.length; ++i)
            parts.push(String(muscles[i]))
        const equipment = String(root.exercise.equipmentText || "")
        if (equipment.length > 0)
            parts.push(equipment)
        return parts.join(qsTr(" · "))
    }

    objectName: "sharedExerciseDetailSheet"
    title: exercise.name || qsTr("动作详情")
    titleObjectName: "sharedExerciseDetailTitle"
    primaryText: qsTr("关闭")
    secondaryVisible: false

    ScrollView {
        id: detailScroll
        objectName: "sharedExerciseDetailScroll"
        width: parent.width
        implicitHeight: Math.min(560, detailColumn.implicitHeight)
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: detailColumn
            width: detailScroll.availableWidth
            spacing: Design.Theme.space16

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(width * 0.72, 320)
                color: Design.Theme.mediaBackdrop

                Image {
                    objectName: "sharedExerciseDetailImage"
                    anchors.fill: parent
                    source: root.currentMedia.url || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: 720
                    sourceSize.height: 540
                    Accessible.role: Accessible.Graphic
                    Accessible.name: qsTr("%1动作图 %2/%3")
                                     .arg(root.exercise.name || "")
                                     .arg(root.mediaIndex + 1)
                                     .arg(Math.max(1, root.mediaItems.length))
                }

                Label {
                    anchors.centerIn: parent
                    visible: root.mediaItems.length === 0
                    text: qsTr("暂无动作图片")
                    color: Design.Theme.outline
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Design.Theme.space8
                    visible: root.mediaItems.length > 1
                    IconButton {
                        iconName: "back"
                        accessibleName: qsTr("上一张动作图")
                        enabled: root.mediaIndex > 0
                        onClicked: root.mediaIndex--
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: qsTr("%1 / %2").arg(root.mediaIndex + 1)
                                             .arg(root.mediaItems.length)
                        color: Design.Theme.primaryForeground
                        font.pixelSize: Design.Theme.typeLabel
                        padding: Design.Theme.space8
                        background: Rectangle { color: Design.Theme.primary; radius: 8 }
                    }
                    Item { Layout.fillWidth: true }
                    IconButton {
                        iconName: "forward"
                        accessibleName: qsTr("下一张动作图")
                        enabled: root.mediaIndex + 1 < root.mediaItems.length
                        onClicked: root.mediaIndex++
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Design.Theme.space16
                Layout.rightMargin: Design.Theme.space16
                spacing: Design.Theme.space12

                Label {
                    Layout.fillWidth: true
                    text: root.muscleSummary()
                    color: Design.Theme.primary
                    font.pixelSize: Design.Theme.typeLabel
                    wrapMode: Text.WordWrap
                }
                Label {
                    Layout.fillWidth: true
                    visible: String(root.exercise.introduction || "").length > 0
                    text: root.exercise.introduction || ""
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeBody
                    wrapMode: Text.WordWrap
                    lineHeight: 1.35
                }

                Label {
                    visible: (root.exercise.techniquePoints || []).length > 0
                    text: qsTr("动作要点")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeBody
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: root.exercise.techniquePoints || []
                    delegate: Label {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "• " + modelData
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                    }
                }

                Label {
                    visible: (root.exercise.steps || []).length > 0
                    text: qsTr("完成步骤")
                    color: Design.Theme.surfaceText
                    font.pixelSize: Design.Theme.typeBody
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: root.exercise.steps || []
                    delegate: Label {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        text: qsTr("%1. %2").arg(index + 1).arg(modelData)
                        color: Design.Theme.surfaceText
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                    }
                }

                Label {
                    visible: (root.exercise.cautions || []).length > 0
                    text: qsTr("注意事项")
                    color: Design.Theme.warning
                    font.pixelSize: Design.Theme.typeBody
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: root.exercise.cautions || []
                    delegate: Label {
                        required property var modelData
                        Layout.fillWidth: true
                        text: "• " + modelData
                        color: Design.Theme.warningContainerText
                        font.pixelSize: Design.Theme.typeLabel
                        wrapMode: Text.WordWrap
                    }
                }

                Label {
                    objectName: "sharedExerciseMediaCredit"
                    Layout.fillWidth: true
                    visible: String(root.currentMedia.source || "").length > 0
                    text: qsTr("图片来源：%1 · %2")
                          .arg(root.currentMedia.source || "")
                          .arg(root.currentMedia.license || qsTr("来源已记录"))
                    color: Design.Theme.surfaceMuted
                    font.pixelSize: Design.Theme.typeCaption
                    wrapMode: Text.WordWrap
                    bottomPadding: Design.Theme.space16
                    Accessible.name: qsTr("图片来源")
                    Accessible.description: text
                }
            }
        }
    }
}
