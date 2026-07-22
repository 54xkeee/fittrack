import QtQuick
import QtQuick.Controls

AppBottomSheet {
    id: root

    property string placeholderText: ""
    property string editorAccessibleName: title
    property alias text: noteEditor.text
    signal saveRequested(string value)

    function openWithText(value) {
        noteEditor.text = String(value || "")
        open()
    }

    primaryText: qsTr("保存备注")
    autoAccept: false
    initialFocusItem: noteEditor
    onPrimaryRequested: saveRequested(noteEditor.text)

    TextArea {
        id: noteEditor
        width: parent.width
        implicitHeight: 112
        wrapMode: TextEdit.Wrap
        placeholderText: root.placeholderText
        Accessible.name: root.editorAccessibleName
    }
}
