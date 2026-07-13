pragma Singleton

import QtQuick

QtObject {
    // Semantic colours. Components consume roles instead of raw colour values.
    readonly property color background: "#0F0F0F"
    readonly property color surface: "#1A1A1A"
    readonly property color surfaceElevated: "#222424"
    readonly property color surfacePressed: "#2B2D2D"
    readonly property color backgroundText: "#F3F0EF"
    readonly property color surfaceText: "#F3F0EF"
    readonly property color surfaceMuted: "#A8AAA9"
    readonly property color outline: "#3A3C3C"
    readonly property color outlineStrong: "#555858"

    readonly property color primary: "#C5FF4A"
    readonly property color primaryPressed: "#A8DD35"
    readonly property color primaryForeground: "#121212"
    readonly property color primaryContainer: "#34451A"
    readonly property color primaryContainerText: "#E2FFAA"

    readonly property color success: "#61D98B"
    readonly property color successContainer: "#173723"
    readonly property color successContainerText: "#A9F5C3"
    readonly property color warning: "#FFB74D"
    readonly property color warningContainer: "#432F14"
    readonly property color warningContainerText: "#FFD89E"
    readonly property color error: "#FF6B6B"
    readonly property color errorPressed: "#E45454"
    readonly property color errorContainer: "#481E1E"
    readonly property color errorForeground: "#121212"
    readonly property color errorContainerText: "#FFC1C1"
    readonly property color info: "#8EC7FF"
    readonly property color infoContainer: "#18334A"
    readonly property color infoContent: "#C6E3FF"
    readonly property color scrim: "#B3000000"

    readonly property real disabledOpacity: 0.42

    // Four-point spacing rhythm.
    readonly property int space4: 4
    readonly property int space8: 8
    readonly property int space12: 12
    readonly property int space16: 16
    readonly property int space24: 24

    // All interactive controls remain at least 48 logical pixels high.
    readonly property int controlHeight: 52
    readonly property int touchTarget: 48

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 16

    // Compact mobile type scale: caption, label, body, title, display.
    readonly property int typeCaption: 12
    readonly property int typeLabel: 14
    readonly property int typeBody: 16
    readonly property int typeTitle: 20
    readonly property int typeDisplay: 28

    property bool reducedMotion: false
    readonly property int motionFast: reducedMotion ? 0 : 100
    readonly property int motionStandard: reducedMotion ? 0 : 180
    readonly property int motionSlow: reducedMotion ? 0 : 280
}
