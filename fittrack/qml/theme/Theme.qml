pragma Singleton

import QtQuick
import "." as Tokens

QtObject {
    // Material 3 semantic roles. The current blue brand remains the only
    // interactive accent; cool neutral surfaces carry the dense training UI.
    readonly property color primary: "#0B57D0"
    readonly property color onPrimary: "#FFFFFF"
    readonly property color primaryContainer: "#D3E3FD"
    readonly property color onPrimaryContainer: "#041E49"
    readonly property color secondary: "#535F70"
    readonly property color onSecondary: "#FFFFFF"
    readonly property color secondaryContainer: "#D7E3F7"
    readonly property color onSecondaryContainer: "#101C2B"
    readonly property color tertiary: "#6A4F90"
    readonly property color onTertiary: "#FFFFFF"
    readonly property color tertiaryContainer: "#EBDDFF"
    readonly property color onTertiaryContainer: "#251343"
    readonly property color error: "#BA1A1A"
    readonly property color onError: "#FFFFFF"
    readonly property color errorContainer: "#FFDAD6"
    readonly property color onErrorContainer: "#410002"

    readonly property color surface: "#F8F9FC"
    readonly property color surfaceContainerLowest: "#FFFFFF"
    readonly property color surfaceContainerLow: "#F2F4F8"
    readonly property color surfaceContainer: "#ECEFF4"
    readonly property color surfaceContainerHigh: "#E6E9EF"
    readonly property color onSurface: "#1A1C20"
    readonly property color onSurfaceVariant: "#44474E"
    readonly property color outline: "#74777F"
    readonly property color outlineVariant: "#C4C7CF"
    readonly property color scrim: "#52000000"

    readonly property color primaryHover: "#0842A0"
    readonly property color primaryPressed: "#062F6F"
    readonly property color primaryForeground: onPrimary
    readonly property color primarySoft: primaryContainer
    readonly property color success: "#146C2E"
    readonly property color successSoft: "#C4EED0"
    readonly property color warning: "#805500"
    readonly property color warningSoft: "#FFDEA6"
    readonly property color errorPressed: "#8F1013"
    readonly property color errorSoft: errorContainer
    readonly property color info: tertiary
    readonly property color infoSoft: tertiaryContainer

    // Compatibility roles consumed by pages that are being migrated.
    readonly property color pageBackground: surface
    readonly property color surfacePrimary: surfaceContainerLowest
    readonly property color surfaceSecondary: surfaceContainerLow
    readonly property color surfaceElevated: surfaceContainerHigh
    readonly property color textPrimary: onSurface
    readonly property color textSecondary: onSurfaceVariant
    readonly property color textTertiary: "#74777F"
    readonly property color textDisabled: "#A7A9B1"
    readonly property color borderDefault: outlineVariant
    readonly property color borderSubtle: "#E2E5EB"
    readonly property color divider: outlineVariant
    readonly property color shadowAmbient: "#14000000"
    readonly property int shadowOffsetY: 1

    readonly property color background: pageBackground
    readonly property color surfacePressed: borderSubtle
    readonly property color mediaBackdrop: surfaceSecondary
    readonly property color backgroundText: textPrimary
    readonly property color surfaceText: textPrimary
    readonly property color surfaceMuted: textSecondary
    readonly property color outlineSubtle: borderDefault
    readonly property color outlineStrong: textTertiary
    readonly property color primaryContainerText: onPrimaryContainer
    readonly property color successContainer: successSoft
    readonly property color successContainerText: "#257A3D"
    readonly property color warningContainer: warningSoft
    readonly property color warningContainerText: "#8A5A00"
    readonly property color errorForeground: onError
    readonly property color errorContainerText: onErrorContainer
    readonly property color infoContainer: infoSoft
    readonly property color infoContent: onTertiaryContainer
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

    readonly property int radiusSmall: 8
    readonly property int radiusInput: 12
    readonly property int radiusButton: 12
    readonly property int radiusMedium: 16
    readonly property int radiusCard: 16
    readonly property int radiusLarge: 28
    readonly property int radiusPill: 999

    // Compatibility aliases. Typography.qml owns all font-size calculations.
    readonly property int typeCaption: Tokens.Typography.meta
    readonly property int typeLabel: Tokens.Typography.label
    readonly property int typeBody: Tokens.Typography.bodyCompact
    readonly property int typeTitle: Tokens.Typography.title
    readonly property int typeDisplay: Tokens.Typography.pageTitle
    readonly property int typeMetric: Tokens.Typography.metricValue

    property bool reducedMotion: Preferences.reducedMotion
    readonly property int motionFast: reducedMotion ? 0 : 120
    readonly property int motionStandard: reducedMotion ? 0 : 200
    readonly property int motionSlow: reducedMotion ? 0 : 260
    readonly property int easingEnter: Easing.OutCubic
    readonly property int easingExit: Easing.InCubic
}
