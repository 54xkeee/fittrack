import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Page {
    id: page
    implicitWidth: 0
    background: Rectangle { color: "#0F0F0F" }

    function openCardio() { tabs.currentIndex = 2 }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: "#0F0F0F"

            RowLayout {
                id: tabs
                objectName: "insightsTabs"
                property int currentIndex: 0
                property var items: [qsTr("趋势"), qsTr("历史"), qsTr("有氧"), qsTr("管理")]

                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 10
                anchors.bottomMargin: 8
                spacing: 6

                Repeater {
                    model: tabs.items
                    delegate: Rectangle {
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: tabs.currentIndex === index ? "#C5FF4A" : "#1A1A1A"
                        border.width: tabs.currentIndex === index ? 0 : 1
                        border.color: "#2B2D2D"

                        Label {
                            anchors.centerIn: parent
                            text: modelData
                            color: tabs.currentIndex === index ? "#121212" : "#DADADA"
                            font.pixelSize: 13
                            font.bold: tabs.currentIndex === index
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: tabs.currentIndex = index
                        }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            currentIndex: tabs.currentIndex
            AnalysisPage { Layout.fillWidth: true; Layout.fillHeight: true }
            HistoryPage { Layout.fillWidth: true; Layout.fillHeight: true }
            CardioPage { Layout.fillWidth: true; Layout.fillHeight: true }
            ManagementPage { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }
}
