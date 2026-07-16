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

    readonly property int space4: 4
    readonly property int space8: 8
    readonly property int space12: 12
    readonly property int space16: 16
    readonly property int space24: 24
    readonly property int space32: 32
    readonly property int pagePadding: 16
    readonly property int cardPadding: 16
    readonly property int cardRadius: 12
    readonly property int controlRadius: 8
    readonly property int rowHeight: 48
    readonly property int inputHeight: 40
    readonly property int iconTarget: 44
    readonly property int tableColumnSpacing: 8
    readonly property int setColumnWidth: 36
    readonly property int weightColumnWidth: 72
    readonly property int repsColumnWidth: 64
    readonly property int statusColumnWidth: 44

    readonly property int typePageTitle: 20
    readonly property int typeExerciseTitle: 17
    readonly property int typeStatistic: 16
    readonly property int typeSetValue: 15
    readonly property int typeBody: 13
    readonly property int typeMeta: 12
    readonly property int typeTableHeader: 11
}
