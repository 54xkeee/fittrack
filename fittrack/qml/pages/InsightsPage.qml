import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Page {
    id: page
    implicitWidth: 0
    background: Rectangle { color: Design.Theme.background }

    signal workoutSummaryDone()

    function openCardio() { tabs.currentIndex = 2 }
    function openWorkoutSummary(sessionId) {
        tabs.currentIndex = 1
        return historyPage.openCompletion(sessionId)
    }
    function handleBack() {
        if (tabs.currentIndex === 1 && historyPage.handleBack())
            return true
        if (tabs.currentIndex === 0)
            return false
        tabs.currentIndex = 0
        return true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64 + SafeArea.margins.top
            color: Design.Theme.background

            RowLayout {
                id: tabs
                objectName: "insightsTabs"
                property int currentIndex: 0
                property var items: [qsTr("趋势"), qsTr("历史"), qsTr("有氧"), qsTr("管理")]

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: Design.Theme.space16 + SafeArea.margins.left
                anchors.rightMargin: Design.Theme.space16 + SafeArea.margins.right
                anchors.topMargin: Design.Theme.space8 + SafeArea.margins.top
                anchors.bottomMargin: Design.Theme.space8
                spacing: Design.Theme.space4

                Repeater {
                    model: tabs.items

                    delegate: Button {
                        id: tabButton
                        required property string modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        implicitHeight: Design.Theme.touchTarget
                        padding: 0
                        flat: true
                        Accessible.name: modelData
                        Accessible.description: tabs.currentIndex === index
                                                ? qsTr("当前页面") : qsTr("切换页面")
                        onClicked: tabs.currentIndex = index

                        contentItem: Label {
                            text: tabButton.modelData
                            color: tabs.currentIndex === tabButton.index
                                   ? Design.Theme.primaryForeground
                                   : Design.Theme.surfaceMuted
                            font.pixelSize: Design.Theme.typeLabel
                            font.weight: tabs.currentIndex === tabButton.index
                                         ? Font.DemiBold : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            radius: Design.Theme.radiusSmall
                            color: tabs.currentIndex === tabButton.index
                                   ? Design.Theme.primary
                                   : (tabButton.down ? Design.Theme.surfacePressed : "transparent")
                            border.width: tabs.currentIndex === tabButton.index ? 0 : 1
                            border.color: Design.Theme.outline
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Design.Theme.outline
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            currentIndex: tabs.currentIndex

            AnalysisPage { Layout.fillWidth: true; Layout.fillHeight: true }
            HistoryPage {
                id: historyPage
                Layout.fillWidth: true
                Layout.fillHeight: true
                onCompletionDismissed: {
                    cardioController.clearPendingSession()
                    page.workoutSummaryDone()
                }
                onAddCardioRequested: page.openCardio()
            }
            CardioPage { Layout.fillWidth: true; Layout.fillHeight: true }
            ManagementPage { Layout.fillWidth: true; Layout.fillHeight: true }
        }
    }
}
