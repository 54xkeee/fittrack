import QtQuick 6.9
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Page {
    id: page
    implicitWidth: 0
    background: Rectangle { color: Design.Theme.background }

    signal workoutSummaryDone()
    signal feedbackRequested(string message)
    property int initialTab: 0
    readonly property var loadedHistory: historyLoader.item

    Component.onCompleted: ensureTab(tabs.currentIndex)

    function ensureTab(index) {
        if (index === 0)
            analysisLoader.active = true
        else if (index === 1)
            historyLoader.active = true
        else if (index === 2) {
            cardioController.ensureLoaded()
            cardioLoader.active = true
        }
        else if (index === 3)
            managementLoader.active = true
    }

    function openCardio() {
        ensureTab(2)
        tabs.currentIndex = 2
    }
    function openWorkoutSummary(sessionId) {
        ensureTab(1)
        tabs.currentIndex = 1
        return loadedHistory && loadedHistory.openCompletion(sessionId)
    }
    function handleBack() {
        if (tabs.currentIndex === 1 && loadedHistory
                && loadedHistory.handleBack())
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
            Layout.preferredHeight: 56 + SafeArea.margins.top
            color: Design.Theme.background

            RowLayout {
                id: tabs
                objectName: "insightsTabs"
                property int currentIndex: page.initialTab
                property var items: [qsTr("趋势"), qsTr("历史"), qsTr("有氧"), qsTr("管理")]
                onCurrentIndexChanged: page.ensureTab(currentIndex)

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
                        Accessible.role: Accessible.PageTab
                        Accessible.selected: tabs.currentIndex === index
                        Accessible.description: tabs.currentIndex === index
                                                ? qsTr("当前页面") : qsTr("切换页面")
                        onClicked: tabs.currentIndex = index

                        contentItem: Label {
                            text: tabButton.modelData
                            color: tabs.currentIndex === tabButton.index
                                   ? Design.Theme.primary
                                   : Design.Theme.textSecondary
                            font.pixelSize: Design.Theme.typeLabel
                            font.weight: tabs.currentIndex === tabButton.index
                                         ? Font.DemiBold : Font.Normal
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        background: Rectangle {
                            radius: Design.Theme.radiusInput
                            color: tabs.currentIndex === tabButton.index
                                   ? Design.Theme.primarySoft
                                   : (tabButton.down ? Design.Theme.surfacePressed : "transparent")
                            border.width: tabButton.activeFocus ? 1 : 0
                            border.color: Design.Theme.primary
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Design.Theme.divider
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.minimumHeight: 0
            currentIndex: tabs.currentIndex

            Loader {
                id: analysisLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                active: false
                sourceComponent: Component { AnalysisPage {} }
            }
            Loader {
                id: historyLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                active: false
                sourceComponent: Component {
                    HistoryPage {
                        onCompletionDismissed: {
                            cardioController.clearPendingSession()
                            page.workoutSummaryDone()
                        }
                        onAddCardioRequested: page.openCardio()
                    }
                }
            }
            Loader {
                id: cardioLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                active: false
                sourceComponent: Component {
                    CardioPage {
                        onFeedbackRequested: message => page.feedbackRequested(message)
                    }
                }
            }
            Loader {
                id: managementLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.minimumHeight: 0
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                active: false
                sourceComponent: Component {
                    ManagementPage {
                        onFeedbackRequested: message => page.feedbackRequested(message)
                    }
                }
            }
        }
    }
}
