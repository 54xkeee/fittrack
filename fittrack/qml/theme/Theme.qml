pragma Singleton

import QtQuick

QtObject {
    // Semantic colours. Components consume roles instead of raw colour values.
    readonly property color background: "#0F0F0F"
    readonly property color surface: "#1A1A1A"
    readonly property color surfaceElevated: "#222424"
    readonly property color surfacePressed: "#2B2D2D"
    readonly property color mediaBackdrop: "#F6F7F4"
    readonly property color backgroundText: "#F3F0EF"
    readonly property color surfaceText: "#F3F0EF"
    readonly property color surfaceMuted: "#A8AAA9"
    readonly property color outlineSubtle: "#3A3C3C"
    readonly property color outline: "#6B6F6F"
    readonly property color outlineStrong: "#858A89"

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

    // New design-system roles. Pages opt in as they are migrated.
    readonly property color canvas: "#0C0E0F"
    readonly property color panel: "#151819"
    readonly property color field: "#1B1F20"
    readonly property color divider: "#292D2F"
    readonly property color textPrimary: "#F3F5F6"
    readonly property color textSecondary: "#A5AAAE"
    readonly property color textTertiary: "#73797D"
    readonly property color accent: "#B8FF3D"
    readonly property color accentPressed: "#9DE032"
    readonly property color accentForeground: "#121212"
    readonly property color selection: "#25350F"
    readonly property color danger: "#FF6468"

    readonly property real disabledOpacity: 0.42

    // Four-point spacing rhythm.
    readonly property int space4: Spacing.xs
    readonly property int space8: Spacing.sm
    readonly property int space12: Spacing.md
    readonly property int space16: Spacing.lg
    readonly property int space20: Spacing.page
    readonly property int space24: Spacing.section

    // Android fontScale is applied at the token level so every page scales together.
    property real fontScale: 1.0

    // All interactive controls remain at least 48 logical pixels high.
    readonly property int controlHeight: Math.max(52, typeLabel + 24)
    readonly property int touchTarget: 48

    readonly property int radiusSmall: 8
    readonly property int radiusMedium: 12
    readonly property int radiusLarge: 16

    // Compact mobile type scale: caption, label, body, title, display.
    readonly property int typeCaption: Math.round(12 * fontScale)
    readonly property int typeLabel: Math.round(14 * fontScale)
    readonly property int typeBody: Math.round(16 * fontScale)
    readonly property int typeTitle: Math.round(20 * fontScale)
    readonly property int typeDisplay: Math.round(28 * fontScale)

    property bool reducedMotion: false
    readonly property int motionFast: reducedMotion ? 0 : 100
    readonly property int motionStandard: reducedMotion ? 0 : 180
    readonly property int motionSlow: reducedMotion ? 0 : 280
}
