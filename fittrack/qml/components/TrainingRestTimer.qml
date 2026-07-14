import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Item {
    id: root

    property int timerState: 0
    property int remainingSeconds: 0
    property int backgroundAlertState: 0

    signal startRequested(int seconds)
    signal pauseRequested()
    signal resumeRequested()
    signal stopRequested()
    signal permissionRequested()
    signal settingsRequested()

    function open() {
        timerDialog.open()
    }

    implicitWidth: timerContent.implicitWidth
    implicitHeight: timerContent.implicitHeight
    visible: timerState === 1 || timerState === 2 || timerState === 3

    AppDialog {
        id: timerDialog
        objectName: "restTimerDialog"
        width: Math.min(380, safeAvailableWidth)
        title: qsTr("休息计时")
        primaryText: qsTr("关闭")
        primaryVariant: "secondary"
        secondaryVisible: false
        initialFocusItem: timerMinutes

        ColumnLayout {
            anchors.fill: parent
            spacing: Design.Theme.space12

            GridLayout {
                id: timerPresetGrid
                Layout.fillWidth: true
                columns: Design.Theme.fontScale >= 1.3 ? 2 : 3
                columnSpacing: Design.Theme.space8
                rowSpacing: Design.Theme.space8

                AppButton {
                    objectName: "twoMinuteTimerButton"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("2 分钟")
                    onClicked: {
                        root.startRequested(120)
                        timerDialog.close()
                    }
                }
                AppButton {
                    objectName: "threeMinuteTimerButton"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: qsTr("3 分钟")
                    onClicked: {
                        root.startRequested(180)
                        timerDialog.close()
                    }
                }
                AppButton {
                    objectName: "fiveMinuteTimerButton"
                    Layout.fillWidth: true
                    Layout.columnSpan: timerPresetGrid.columns === 2 ? 2 : 1
                    Layout.minimumWidth: 0
                    text: qsTr("5 分钟")
                    onClicked: {
                        root.startRequested(300)
                        timerDialog.close()
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("自定义时长")
                color: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeLabel
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Design.Theme.space8

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space4
                    Label {
                        text: qsTr("分钟")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                    }
                    SpinBox {
                        id: timerMinutes
                        Layout.fillWidth: true
                        from: 0
                        to: 59
                        value: 2
                        editable: true
                        implicitHeight: Design.Theme.controlHeight
                        Accessible.name: qsTr("自定义分钟")
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Design.Theme.space4
                    Label {
                        text: qsTr("秒数")
                        color: Design.Theme.surfaceMuted
                        font.pixelSize: Design.Theme.typeCaption
                    }
                    SpinBox {
                        id: timerSeconds
                        Layout.fillWidth: true
                        from: 0
                        to: 59
                        value: 0
                        editable: true
                        implicitHeight: Design.Theme.controlHeight
                        Accessible.name: qsTr("自定义秒数")
                    }
                }
            }

            AppButton {
                Layout.fillWidth: true
                text: qsTr("开始计时")
                enabled: timerMinutes.value > 0 || timerSeconds.value > 0
                onClicked: {
                    root.startRequested(timerMinutes.value * 60 + timerSeconds.value)
                    timerDialog.close()
                }
            }
        }
    }

    ColumnLayout {
        id: timerContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Design.Theme.space8

        RestTimerBar {
            visible: root.timerState === 1 || root.timerState === 2
            Layout.fillWidth: true
            remainingSeconds: root.remainingSeconds
            paused: root.timerState === 2
            onPauseRequested: root.pauseRequested()
            onResumeRequested: root.resumeRequested()
            onStopRequested: root.stopRequested()
        }

        InlineFeedback {
            objectName: "backgroundAlertFeedback"
            visible: (root.timerState === 1 || root.timerState === 2)
                     && (root.backgroundAlertState === 2
                         || root.backgroundAlertState === 3
                         || root.backgroundAlertState === 4)
            Layout.fillWidth: true
            tone: "warning"
            message: root.backgroundAlertState === 2
                     ? qsTr("计时已开始。开启通知后，切到后台也能收到休息结束提醒。")
                     : root.backgroundAlertState === 3
                       ? qsTr("计时会在应用内继续；通知已关闭，离开应用后可能收不到休息结束提醒。")
                       : qsTr("计时会在应用内继续；后台计时服务未能启动，离开应用后可能收不到休息结束提醒。")
            actionText: root.backgroundAlertState === 2
                        ? qsTr("开启后台提醒")
                        : root.backgroundAlertState === 3 ? qsTr("系统设置") : ""
            onActionTriggered: {
                if (root.backgroundAlertState === 2)
                    root.permissionRequested()
                else if (root.backgroundAlertState === 3)
                    root.settingsRequested()
            }
        }

        InlineFeedback {
            visible: root.timerState === 3
            Layout.fillWidth: true
            tone: "success"
            message: qsTr("休息结束，可以开始下一组。")
            actionText: qsTr("知道了")
            onActionTriggered: root.stopRequested()
        }
    }
}
