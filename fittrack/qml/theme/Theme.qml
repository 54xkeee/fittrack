pragma Singleton

import QtQuick
import "." as Tokens

QtObject {
    // Material 3 semantic roles. The current blue brand remains the only
    // interactive accent; cool neutral surfaces carry the dense training UI.
    readonly property bool isDark: Qt.styleHints.colorScheme === Qt.Dark
    readonly property color primary: isDark ? "#A8C7FA" : "#0B57D0"
    readonly property color onPrimary: isDark ? "#062E6F" : "#FFFFFF"
    readonly property color primaryContainer: isDark ? "#0842A0" : "#D3E3FD"
    readonly property color onPrimaryContainer: isDark ? "#D3E3FD" : "#041E49"
    readonly property color secondary: isDark ? "#BBC7DB" : "#535F70"
    readonly property color onSecondary: isDark ? "#253140" : "#FFFFFF"
    readonly property color secondaryContainer: isDark ? "#3B4858" : "#D7E3F7"
    readonly property color onSecondaryContainer: isDark ? "#D7E3F7" : "#101C2B"
    readonly property color tertiary: isDark ? "#D9B9FF" : "#6A4F90"
    readonly property color onTertiary: isDark ? "#3B1E63" : "#FFFFFF"
    readonly property color tertiaryContainer: isDark ? "#52367A" : "#EBDDFF"
    readonly property color onTertiaryContainer: isDark ? "#EBDDFF" : "#251343"
    readonly property color error: isDark ? "#FFB4AB" : "#BA1A1A"
    readonly property color onError: isDark ? "#690005" : "#FFFFFF"
    readonly property color errorContainer: isDark ? "#93000A" : "#FFDAD6"
    readonly property color onErrorContainer: isDark ? "#FFDAD6" : "#410002"

    readonly property color surface: isDark ? "#111318" : "#F8F9FC"
    readonly property color surfaceContainerLowest: isDark ? "#0C0E12" : "#FFFFFF"
    readonly property color surfaceContainerLow: isDark ? "#191C20" : "#F2F4F8"
    readonly property color surfaceContainer: isDark ? "#1D2024" : "#ECEFF4"
    readonly property color surfaceContainerHigh: isDark ? "#282A2F" : "#E6E9EF"
    readonly property color onSurface: isDark ? "#E2E2E9" : "#1A1C20"
    readonly property color onSurfaceVariant: isDark ? "#C4C7CF" : "#44474E"
    readonly property color outline: isDark ? "#8E9099" : "#74777F"
    readonly property color outlineVariant: isDark ? "#44474E" : "#C4C7CF"
    readonly property color scrim: "#52000000"

    readonly property color primaryHover: isDark ? "#C2D7FF" : "#0842A0"
    readonly property color primaryPressed: isDark ? "#7BAAF7" : "#062F6F"
    readonly property color primaryForeground: onPrimary
    readonly property color primarySoft: primaryContainer
    readonly property color success: isDark ? "#82D99A" : "#146C2E"
    readonly property color successSoft: isDark ? "#005321" : "#C4EED0"
    readonly property color warning: isDark ? "#FFB95F" : "#805500"
    readonly property color warningSoft: isDark ? "#633E00" : "#FFDEA6"
    readonly property color errorPressed: isDark ? "#FF897D" : "#8F1013"
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
    readonly property color textTertiary: isDark ? "#AEB0B8" : "#74777F"
    readonly property color textDisabled: isDark ? "#777982" : "#A7A9B1"
    readonly property color borderDefault: outlineVariant
    readonly property color borderSubtle: isDark ? "#303238" : "#E2E5EB"
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
    readonly property color successContainerText: isDark ? "#A1F4B5" : "#257A3D"
    readonly property color warningContainer: warningSoft
    readonly property color warningContainerText: isDark ? "#FFDEA6" : "#8A5A00"
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
