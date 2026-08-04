pragma Singleton

import QtQuick

QtObject {
    property real fontScale: 1.0

    readonly property int caption: Math.round(12 * fontScale)
    readonly property int label: Math.round(14 * fontScale)
    readonly property int body: Math.round(14 * fontScale)
    readonly property int exerciseTitle: Math.round(17 * fontScale)
    readonly property int sectionTitle: Math.round(18 * fontScale)
    readonly property int pageTitle: Math.round(24 * fontScale)
    readonly property int trainingNumber: Math.round(28 * fontScale)
}
