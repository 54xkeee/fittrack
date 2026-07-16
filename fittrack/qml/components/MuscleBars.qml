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
                        id: valueBar
                        width: parent.width * Number(modelData.sets) / root.maximum()
                        height: parent.height
                        radius: 6
                        color: Design.Theme.primary
                        transform: Scale {
                            id: valueScale
                            origin.x: 0
                            origin.y: valueBar.height / 2
                            xScale: 0
                            yScale: 1

                            Behavior on xScale {
                                NumberAnimation {
                                    duration: Design.Theme.motionSlow
                                    easing.type: Design.Theme.easingEnter
                                }
                            }
                        }
                        Component.onCompleted: valueScale.xScale = 1
                    }
                }
                Label { text: modelData.sets + qsTr("组"); Layout.preferredWidth: 36 }
            }
        }
    }
}
