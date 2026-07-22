import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppBottomSheet {
    id: root

    signal saveRequested(string planName, string dayName, string sectionName)

    function openWithDefaults(sessionName) {
        const value = String(sessionName || "")
        planName.text = value
        dayName.text = value
        sectionName.text = ""
        open()
    }

    title: qsTr("保存为个人计划")
    primaryText: qsTr("保存计划")
    primaryEnabled: planName.text.trim().length > 0
                    && dayName.text.trim().length > 0
    autoAccept: false
    initialFocusItem: planName
    onPrimaryRequested: saveRequested(planName.text, dayName.text, sectionName.text)

    ScrollView {
        id: formScroll
        width: parent.width
        implicitHeight: Math.min(form.implicitHeight,
                                 Overlay.overlay ? Overlay.overlay.height * 0.45 : 360)
        clip: true
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

        ColumnLayout {
            id: form
            width: formScroll.availableWidth
            spacing: Design.Theme.space8

            AppTextField {
                id: planName
                Layout.fillWidth: true
                placeholderText: qsTr("计划名称")
                Accessible.name: qsTr("计划名称")
            }
            AppTextField {
                id: dayName
                Layout.fillWidth: true
                placeholderText: qsTr("训练日名称，例如 Push A")
                Accessible.name: qsTr("训练日名称")
            }
            AppTextField {
                id: sectionName
                Layout.fillWidth: true
                placeholderText: qsTr("动作分组名称，可选")
                Accessible.name: qsTr("动作分组名称")
            }
        }
    }
}
