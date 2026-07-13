import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Control {
    id: root

    // Supported tones: info, success, warning and error.
    property string tone: "info"
    property string message: ""
    property string actionText: ""

    signal actionTriggered()

    readonly property color toneColor: tone === "success" ? Design.Theme.success :
                                                tone === "warning" ? Design.Theme.warning :
                                                tone === "error" ? Design.Theme.error : Design.Theme.info
    readonly property color containerColor: tone === "success" ? Design.Theme.successContainer :
                                                     tone === "warning" ? Design.Theme.warningContainer :
                                                     tone === "error" ? Design.Theme.errorContainer : Design.Theme.infoContainer
    readonly property color contentColor: tone === "success" ? Design.Theme.successContainerText :
                                                   tone === "warning" ? Design.Theme.warningContainerText :
                                                   tone === "error" ? Design.Theme.errorContainerText : Design.Theme.infoContent
    readonly property string statusGlyph: tone === "success" ? "✓" :
                                                   tone === "warning" ? "!" :
                                                   tone === "error" ? "×" : "i"

    implicitHeight: Math.max(Design.Theme.controlHeight,
                             contentItem.implicitHeight + topPadding + bottomPadding)
    padding: Design.Theme.space12
    Accessible.name: message

    background: Rectangle {
        radius: Design.Theme.radiusSmall
        color: root.containerColor
        border.width: 1
        border.color: root.toneColor
    }

    contentItem: ColumnLayout {
        spacing: Design.Theme.space12

        RowLayout {
            spacing: Design.Theme.space12
            Layout.fillWidth: true

            Label {
                text: root.statusGlyph
                color: root.toneColor
                font.pixelSize: Design.Theme.typeBody
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: 20
                Layout.alignment: Qt.AlignTop
            }

            Label {
                text: root.message
                color: root.contentColor
                font.pixelSize: Design.Theme.typeLabel
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }

        AppButton {
            visible: root.actionText.length > 0
            text: root.actionText
            variant: "secondary"
            Layout.fillWidth: true
            onClicked: root.actionTriggered()
        }
    }
}
