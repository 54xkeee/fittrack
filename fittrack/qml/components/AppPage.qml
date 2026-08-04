import QtQuick 6.9
import QtQuick.Controls
import "../theme" as Design

Page {
    id: root

    readonly property real responsiveGutter: Math.max(
                                                Design.Theme.space16,
                                                (width - Design.Theme.contentMaxWidth) / 2)
    leftPadding: responsiveGutter + SafeArea.margins.left
    rightPadding: responsiveGutter + SafeArea.margins.right
    topPadding: Design.Theme.space16 + SafeArea.margins.top
    bottomPadding: Design.Theme.space16 + SafeArea.margins.bottom

    background: Rectangle {
        color: Design.Theme.background
    }
}
