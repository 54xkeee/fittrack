import QtQuick 6.9
import QtQuick.Controls
import "../theme" as Design

Page {
    id: root

    leftPadding: Design.Theme.space16 + SafeArea.margins.left
    rightPadding: Design.Theme.space16 + SafeArea.margins.right
    topPadding: Design.Theme.space16 + SafeArea.margins.top
    bottomPadding: Design.Theme.space16 + SafeArea.margins.bottom

    background: Rectangle {
        color: Design.Theme.background
    }
}
