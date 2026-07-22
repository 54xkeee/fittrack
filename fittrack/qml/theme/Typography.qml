pragma Singleton

import QtQuick

QtObject {
    property real fontScale: 1.0

    // The only typography scale. Names describe hierarchy, not a page.
    readonly property int meta: Math.round(12 * fontScale)
    readonly property int tableLabel: Math.round(11 * fontScale)
    readonly property int label: Math.round(14 * fontScale)
    readonly property int bodySmall: Math.round(13 * fontScale)
    readonly property int bodyCompact: Math.round(14 * fontScale)
    readonly property int body: Math.round(16 * fontScale)
    readonly property int setValue: Math.round(15 * fontScale)
    readonly property int sectionTitle: Math.round(18 * fontScale)
    readonly property int exerciseTitle: Math.round(17 * fontScale)
    readonly property int title: Math.round(20 * fontScale)
    readonly property int pageTitle: Math.round(24 * fontScale)
    readonly property int metricValue: Math.round(22 * fontScale)
    readonly property int trainingNumber: Math.round(28 * fontScale)

    // Transitional aliases keep existing page geometry stable while each
    // surface moves to the semantic roles above.
    readonly property int caption: meta
}
