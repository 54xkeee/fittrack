pragma Singleton

import QtQuick
import "." as Tokens

QtObject {
    readonly property color background: Tokens.Theme.pageBackground
    readonly property color card: Tokens.Theme.surfacePrimary
    readonly property color text: Tokens.Theme.textPrimary
    readonly property color textSecondary: Tokens.Theme.textSecondary
    readonly property color textMuted: Tokens.Theme.textTertiary
    readonly property color divider: Tokens.Theme.borderDefault
    readonly property color primary: Tokens.Theme.primary
    readonly property color primaryPressed: Tokens.Theme.primaryPressed
    readonly property color primarySoft: Tokens.Theme.primarySoft
    readonly property color inputBorder: Tokens.Theme.borderDefault
    readonly property color success: Tokens.Theme.success
    readonly property color successBackground: Tokens.Theme.successSoft
    readonly property color input: Tokens.Theme.surfaceSecondary
    readonly property color secondaryFill: Tokens.Theme.surfaceSecondary
    readonly property color secondaryText: Tokens.Theme.textSecondary
    readonly property color rowDivider: Tokens.Theme.borderSubtle
    readonly property color danger: Tokens.Theme.error

    // Training-specific dimensions reference the shared foundation rather
    // than defining a second token system.
    readonly property int space4: Tokens.Theme.space4
    readonly property int space8: Tokens.Theme.space8
    readonly property int space12: Tokens.Theme.space12
    readonly property int space16: Tokens.Theme.space16
    readonly property int space24: Tokens.Theme.space24
    readonly property int space32: Tokens.Theme.space32
    readonly property int pagePadding: Tokens.Theme.space16
    readonly property int cardPadding: Tokens.Theme.space16
    readonly property int cardRadius: Tokens.Theme.radiusCard
    readonly property int controlRadius: Tokens.Theme.radiusInput
    readonly property int rowHeight: Tokens.Theme.touchTarget
    readonly property int inputHeight: Tokens.Theme.heightDefault
    readonly property int iconTarget: 44
    readonly property int tableColumnSpacing: 8
    readonly property int setColumnWidth: 36
    readonly property int weightColumnWidth: 72
    readonly property int repsColumnWidth: 64
    readonly property int statusColumnWidth: 44

    readonly property int typePageTitle: Tokens.Typography.title
    readonly property int typeExerciseTitle: Tokens.Typography.exerciseTitle
    readonly property int typeStatistic: Tokens.Typography.body
    readonly property int typeSetValue: Tokens.Typography.setValue
    readonly property int typeBody: Tokens.Typography.bodySmall
    readonly property int typeMeta: Tokens.Typography.meta
    readonly property int typeTableHeader: Tokens.Typography.tableLabel
}
