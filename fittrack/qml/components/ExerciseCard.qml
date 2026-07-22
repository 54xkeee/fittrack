import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../theme" as Design

Item {
    id: root
    default property alias contentData: content.data
    property bool active: false

    implicitHeight: content.implicitHeight + Design.WorkoutTheme.cardPadding * 2
    activeFocusOnTab: true

    RectangularShadow {
        anchors.fill: cardSurface
        visible: root.active
        offset: Qt.vector2d(0, Design.Theme.elevation2Offset)
        color: Design.Theme.elevation2Shadow
        blur: Design.Theme.elevation2Blur
        radius: cardSurface.radius
        cached: true
    }

    Rectangle {
        id: cardSurface
        anchors.fill: parent
        radius: Design.WorkoutTheme.cardRadius
        color: root.active ? Design.Theme.surfaceContainerHigh
                           : Design.WorkoutTheme.card
        border.width: root.active ? 0 : 1
        border.color: Design.WorkoutTheme.divider
    }

    Rectangle {
        visible: root.active
        width: 4
        height: 48
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: Design.WorkoutTheme.primary
        radius: 2
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Design.WorkoutTheme.cardPadding
        spacing: Design.WorkoutTheme.space8
    }
}
