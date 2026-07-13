import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Control {
    id: root

    // Supported states: current, completed and upcoming.
    property string rowState: "upcoming"
    property int setNumber: 1
    property alias weightText: weightField.text
    property alias repsText: repsField.text
    property string targetText: ""
    property bool failure: false

    readonly property bool isCurrent: rowState === "current"
    readonly property bool isCompleted: rowState === "completed"

    signal completeRequested(string weight, string reps)
    signal editRequested()

    implicitHeight: isCurrent ? 68 : 56
    padding: Design.Theme.space8
    Accessible.name: isCompleted
                     ? qsTr("第%1组，已完成，%2千克，%3次").arg(setNumber).arg(weightText).arg(repsText)
                     : qsTr("第%1组，%2").arg(setNumber).arg(isCurrent ? qsTr("当前") : qsTr("未开始"))

    background: Rectangle {
        radius: Design.Theme.radiusMedium
        color: root.isCurrent ? Design.Theme.surfaceElevated : "transparent"
        border.width: root.isCurrent ? 1 : 0
        border.color: Design.Theme.primary
    }

    contentItem: RowLayout {
        spacing: Design.Theme.space8

        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32

            AppIcon {
                anchors.centerIn: parent
                visible: root.isCompleted
                name: "success"
                color: Design.Theme.success
            }

            Label {
                anchors.centerIn: parent
                visible: !root.isCompleted
                text: String(root.setNumber)
                color: root.isCurrent ? Design.Theme.primary : Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeBody
                font.weight: Font.DemiBold
            }
        }

        NumberField {
            id: weightField
            visible: root.isCurrent
            placeholderText: qsTr("重量")
            unit: qsTr("kg")
            decimals: 1
            Layout.fillWidth: true
            Layout.minimumWidth: 88
        }

        NumberField {
            id: repsField
            visible: root.isCurrent
            placeholderText: qsTr("次数")
            unit: qsTr("次")
            decimals: 0
            Layout.fillWidth: true
            Layout.minimumWidth: 72
        }

        Label {
            visible: !root.isCurrent
            text: root.isCompleted
                  ? qsTr("%1 kg × %2次%3").arg(root.weightText).arg(root.repsText)
                    .arg(root.failure ? qsTr(" · 力竭") : "")
                  : (root.targetText.length > 0 ? root.targetText : qsTr("待训练"))
            color: root.isCompleted ? Design.Theme.surfaceText : Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeBody
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        AppButton {
            visible: root.isCurrent
            text: qsTr("完成")
            enabled: weightField.text.length > 0 && repsField.text.length > 0 &&
                     weightField.acceptableInput && repsField.acceptableInput
            Layout.preferredWidth: 72
            onClicked: root.completeRequested(weightField.text, repsField.text)
        }

        AppButton {
            visible: root.isCompleted
            text: qsTr("编辑")
            variant: "secondary"
            Layout.preferredWidth: 68
            onClicked: root.editRequested()
        }
    }
}
