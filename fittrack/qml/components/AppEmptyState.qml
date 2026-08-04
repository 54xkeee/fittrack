import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

AppCard {
    id: root

    property string iconName: "info"
    property string title: ""
    property string message: ""
    property string actionText: ""
    signal actionRequested()

    padding: Design.Theme.space24

    ColumnLayout {
        anchors.fill: parent
        spacing: Design.Theme.space8

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            radius: 24
            color: Design.Theme.primarySoft

            AppIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                name: root.iconName
                color: Design.Theme.primary
            }
        }

        Label {
            Layout.fillWidth: true
            text: root.title
            color: Design.Theme.textPrimary
            font.pixelSize: Design.Theme.typeLabel
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Label {
            visible: root.message.length > 0
            Layout.fillWidth: true
            text: root.message
            color: Design.Theme.textSecondary
            font.pixelSize: Design.Theme.typeBody
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        AppButton {
            visible: root.actionText.length > 0
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Design.Theme.space4
            text: root.actionText
            onClicked: root.actionRequested()
        }
    }
}
