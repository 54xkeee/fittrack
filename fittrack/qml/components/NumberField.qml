import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme" as Design

Control {
    id: root

    property alias text: editor.text
    property alias placeholderText: editor.placeholderText
    property string label: ""
    property string unit: ""
    property string errorText: ""
    property real from: 0
    property real to: 9999
    property int decimals: 1
    property bool readOnly: false
    property int keyboardHints: Qt.ImhFormattedNumbersOnly

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
            color: Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeLabel
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Design.Theme.controlHeight
            radius: Design.Theme.radiusSmall
            color: Design.Theme.surfaceElevated
            border.width: editor.activeFocus || root.errorText.length > 0 ? 2 : 1
            border.color: root.errorText.length > 0 ? Design.Theme.error :
                          (editor.activeFocus ? Design.Theme.primary : Design.Theme.outline)

            TextField {
                id: editor
                anchors.fill: parent
                anchors.rightMargin: unitLabel.visible ? unitLabel.implicitWidth + Design.Theme.space16 : 0
                enabled: root.enabled
                readOnly: root.readOnly
                inputMethodHints: root.keyboardHints
                selectByMouse: true
                verticalAlignment: TextInput.AlignVCenter
                color: Design.Theme.surfaceText
                placeholderTextColor: Design.Theme.surfaceMuted
                font.pixelSize: Design.Theme.typeBody
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
                Accessible.name: root.label.length > 0 ? root.label : root.placeholderText
                Accessible.description: root.errorText
                onAccepted: root.accepted()
            }

            Label {
                id: unitLabel
                anchors.right: parent.right
                anchors.rightMargin: Design.Theme.space12
                anchors.verticalCenter: parent.verticalCenter
                visible: root.unit.length > 0
                text: root.unit
                color: Design.Theme.surfaceMuted
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

