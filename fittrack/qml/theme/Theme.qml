pragma Singleton

import QtQuick

QtObject {
    // Global product palette. Legacy role aliases remain so existing pages can
    // migrate without duplicating colours or changing business bindings.
    readonly property color pageBackground: "#F6F8FB"
    readonly property color surfacePrimary: "#FFFFFF"
    readonly property color surfaceSecondary: "#F5F7FA"
    readonly property color surfaceElevated: "#FFFFFF"
    readonly property color textPrimary: "#182230"
    readonly property color textSecondary: "#667085"
    readonly property color textTertiary: "#98A2B3"
    readonly property color textDisabled: "#B8C0CC"
    readonly property color borderDefault: "#E1E6ED"
    readonly property color borderSubtle: "#EDF0F4"
    readonly property color divider: "#E7EBF0"
    readonly property color shadowAmbient: "#0A172033"
    readonly property int shadowOffsetY: 2

    readonly property color primary: "#1677FF"
    readonly property color primaryHover: "#0F6FE8"
    readonly property color primaryPressed: "#095FC9"
    readonly property color primaryForeground: "#FFFFFF"
    readonly property color primarySoft: "#EDF5FF"

    readonly property color success: "#34A853"
    readonly property color successSoft: "#ECF9EE"
    readonly property color warning: "#F5A623"
    readonly property color warningSoft: "#FFF6E5"
    readonly property color error: "#EF476F"
    readonly property color errorPressed: "#D93D63"
    readonly property color errorSoft: "#FFF0F3"
    readonly property color info: primary
    readonly property color infoSoft: primarySoft
    readonly property color scrim: "#6B0F172A"

    // Compatibility roles consumed by pages that are being migrated.
    readonly property color background: pageBackground
    readonly property color surface: surfacePrimary
    readonly property color surfacePressed: borderSubtle
    readonly property color mediaBackdrop: surfaceSecondary
    readonly property color backgroundText: textPrimary
    readonly property color surfaceText: textPrimary
    readonly property color surfaceMuted: textSecondary
    readonly property color outlineSubtle: borderDefault
    readonly property color outline: borderDefault
    readonly property color outlineStrong: textTertiary
    readonly property color primaryContainer: primarySoft
    readonly property color primaryContainerText: primary
    readonly property color successContainer: successSoft
    readonly property color successContainerText: "#257A3D"
    readonly property color warningContainer: warningSoft
    readonly property color warningContainerText: "#8A5A00"
    readonly property color errorContainer: errorSoft
    readonly property color errorForeground: "#FFFFFF"
    readonly property color errorContainerText: "#B4234D"
    readonly property color infoContainer: infoSoft
    readonly property color infoContent: primary
    readonly property color canvas: pageBackground
    readonly property color panel: surfacePrimary
    readonly property color field: surfaceSecondary
    readonly property color accent: primary
    readonly property color accentPressed: primaryPressed
    readonly property color accentForeground: primaryForeground
    readonly property color selection: primarySoft
    readonly property color danger: error

    readonly property real disabledOpacity: 0.48

    readonly property int space2: 2
    readonly property int space4: 4
    readonly property int space8: 8
    readonly property int space12: 12
    readonly property int space16: 16
    readonly property int space20: 20
    readonly property int space24: 24
    readonly property int space32: 32

    property real fontScale: 1.0

    readonly property int heightSmall: 32
    readonly property int heightDefault: 40
    readonly property int heightLarge: 44
    readonly property int heightPrimary: 48
    readonly property int controlHeight: Math.max(heightPrimary, typeLabel + 24)
    readonly property int touchTarget: 48
    readonly property int contentMaxWidth: 760

    readonly property int radiusSmall: 6
    readonly property int radiusInput: 8
    readonly property int radiusButton: 10
    readonly property int radiusMedium: 12
    readonly property int radiusCard: 12
    readonly property int radiusLarge: 16
    readonly property int radiusPill: 999

    readonly property int typeCaption: Math.round(12 * fontScale)
    readonly property int typeLabel: Math.round(14 * fontScale)
    readonly property int typeBody: Math.round(14 * fontScale)
    readonly property int typeTitle: Math.round(20 * fontScale)
    readonly property int typeDisplay: Math.round(24 * fontScale)
    readonly property int typeMetric: Math.round(22 * fontScale)

    property bool reducedMotion: Preferences.reducedMotion
    readonly property int motionFast: reducedMotion ? 0 : 120
    readonly property int motionStandard: reducedMotion ? 0 : 200
    readonly property int motionSlow: reducedMotion ? 0 : 260
    readonly property int easingEnter: Easing.OutCubic
    readonly property int easingExit: Easing.InCubic
}
