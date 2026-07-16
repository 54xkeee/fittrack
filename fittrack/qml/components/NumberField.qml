import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Control {
    id: root

    property alias text: editor.text
    property string placeholderText: ""
    property alias editorItem: editor
    property string label: ""
    property string accessibleName: ""
    property bool subtleBorder: false
    property int cornerRadius: Design.Theme.radiusSmall
    property color fillColor: Design.Theme.surfaceElevated
    property color textColor: Design.Theme.surfaceText
    property color mutedColor: Design.Theme.surfaceMuted
    property color outlineColor: Design.Theme.outline
    property color dividerColor: Design.Theme.divider
    property color focusColor: Design.Theme.primary
    property string unit: ""
    property string errorText: ""
    property real from: 0
    property real to: 9999
    property int decimals: 1
    property bool readOnly: false
    property int keyboardHints: Qt.ImhFormattedNumbersOnly
    property int fieldHeight: Design.Theme.controlHeight
    property int textPixelSize: Design.Theme.typeBody
    property var fontFeatures: ({})

    readonly property bool acceptableInput: editor.acceptableInput
    readonly property real numericValue: {
        const normalized = editor.text.replace(",", ".")
        return normalized.length > 0 ? Number(normalized) : NaN
    }

    signal accepted()

    implicitWidth: 132
    implicitHeight: fieldColumn.implicitHeight
    padding: 0

    contentItem: ColumnLayout {
        id: fieldColumn
        spacing: Design.Theme.space4

        Label {
            visible: root.label.length > 0
            text: root.label
            color: root.mutedColor
            font.pixelSize: Design.Theme.typeLabel
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: root.fieldHeight
            radius: root.cornerRadius
            color: root.fillColor
            border.width: editor.activeFocus || root.errorText.length > 0 ? 2 : 1
            border.color: root.errorText.length > 0 ? Design.Theme.error :
                          (editor.activeFocus ? root.focusColor
                                              : (root.subtleBorder
                                                 ? root.dividerColor
                                                 : root.outlineColor))

            TextField {
                id: editor
                anchors.fill: parent
                anchors.rightMargin: unitLabel.visible ? unitLabel.implicitWidth + Design.Theme.space16 : 0
                enabled: root.enabled
                readOnly: root.readOnly
                inputMethodHints: root.keyboardHints
                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter
                color: root.textColor
                font.pixelSize: root.textPixelSize
                font.features: root.fontFeatures
                leftPadding: Design.Theme.space12
                rightPadding: Design.Theme.space8
                background: null
                validator: DoubleValidator {
                    bottom: root.from
                    top: root.to
                    decimals: root.decimals
                    notation: DoubleValidator.StandardNotation
                    locale: Qt.locale().name
                }
                Accessible.name: root.accessibleName.length > 0
                                 ? root.accessibleName
                                 : (root.label.length > 0 ? root.label : root.placeholderText)
                Accessible.description: root.errorText
                onAccepted: root.accepted()
            }

            Label {
                anchors.left: parent.left
                anchors.leftMargin: Design.Theme.space12
                anchors.right: unitLabel.visible ? unitLabel.left : parent.right
                anchors.rightMargin: Design.Theme.space8
                anchors.verticalCenter: parent.verticalCenter
                visible: editor.text.length === 0 && !editor.activeFocus
                text: root.placeholderText
                color: root.mutedColor
                font.pixelSize: root.textPixelSize
                font.features: root.fontFeatures
                elide: Text.ElideRight
            }

            Label {
                id: unitLabel
                anchors.right: parent.right
                anchors.rightMargin: Design.Theme.space12
                anchors.verticalCenter: parent.verticalCenter
                visible: root.unit.length > 0
                text: root.unit
                color: root.mutedColor
                font.pixelSize: Design.Theme.typeLabel
            }
        }

        Label {
            visible: root.errorText.length > 0
            text: root.errorText
            color: Design.Theme.error
            font.pixelSize: Design.Theme.typeCaption
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
