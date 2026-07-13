import QtQuick
import QtQuick.Controls
import "../theme" as Design

AppDialog {
    id: root

    property string message: ""
    property string confirmText: qsTr("确认")
    property string cancelText: qsTr("取消")
    property bool destructive: false

    width: Math.min(360, safeAvailableWidth)
    primaryText: root.confirmText
    secondaryText: root.cancelText
    primaryVariant: root.destructive ? "destructive" : "primary"
    preferSecondaryFocus: true

    contentItem: Label {
        text: root.message
        color: Design.Theme.surfaceMuted
        font.pixelSize: Design.Theme.typeBody
        lineHeight: 1.4
        wrapMode: Text.WordWrap
        Accessible.name: root.message
    }
}
