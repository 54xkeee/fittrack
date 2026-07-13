import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppCard {
    id: root
    property string title: ""
    property var items: []
    padding: Design.Theme.space16

    function maximum() {
        let value = 1
        for (let i = 0; i < items.length; ++i) value = Math.max(value, Number(items[i].sets))
        return value
    }

    ColumnLayout {
        anchors.fill: parent
        Label {
            text: root.title
            color: Design.Theme.surfaceText
            font.weight: Font.DemiBold
            font.pixelSize: Design.Theme.typeBody
        }
        Label {
            visible: root.items.length === 0
            text: qsTr("暂无数据")
            color: Design.Theme.surfaceMuted
        }
        Repeater {
            model: root.items
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Label { text: modelData.name; Layout.preferredWidth: 88; elide: Text.ElideRight }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12
                    radius: 6
                    color: Design.Theme.surfaceElevated
                    Rectangle {
                        width: parent.width * Number(modelData.sets) / root.maximum()
                        height: parent.height
                        radius: 6
                        color: Design.Theme.primary
                    }
                }
                Label { text: modelData.sets + qsTr("组"); Layout.preferredWidth: 36 }
            }
        }
    }
}
