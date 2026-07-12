import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AppCard {
    id: root
    property string title: ""
    property var items: []
    padding: 14

    function maximum() {
        let value = 1
        for (let i = 0; i < items.length; ++i) value = Math.max(value, Number(items[i].sets))
        return value
    }

    ColumnLayout {
        anchors.fill: parent
        Label { text: root.title; font.bold: true; font.pixelSize: 16 }
        Label { visible: root.items.length === 0; text: qsTr("暂无数据"); color: "#AEB7B1" }
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
                    color: "#27302C"
                    Rectangle {
                        width: parent.width * Number(modelData.sets) / root.maximum()
                        height: parent.height
                        radius: 6
                        color: "#8BD450"
                    }
                }
                Label { text: modelData.sets + qsTr("组"); Layout.preferredWidth: 36 }
            }
        }
    }
}
