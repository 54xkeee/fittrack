import QtQuick
import QtQuick.Layouts
import "../theme" as Design

Item {
    id: root
    default property alias contentData: content.data
    property bool active: false

    implicitHeight: content.implicitHeight + Design.WorkoutTheme.cardPadding * 2
    activeFocusOnTab: true

    Rectangle {
        id: cardSurface
        anchors.fill: parent
        radius: Design.WorkoutTheme.cardRadius
        color: Design.Theme.surfaceContainerLowest
        border.width: 1
        border.color: Design.Theme.outlineVariant
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Design.WorkoutTheme.cardPadding
        spacing: Design.WorkoutTheme.space8
    }
}
