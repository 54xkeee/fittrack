pragma Singleton

import QtQuick

QtObject {
    property real fontScale: 1.0

    readonly property int caption: Math.round(13 * fontScale)
    readonly property int label: Math.round(14 * fontScale)
    readonly property int body: Math.round(15 * fontScale)
    readonly property int exerciseTitle: Math.round(18 * fontScale)
    readonly property int sectionTitle: Math.round(20 * fontScale)
    readonly property int pageTitle: Math.round(28 * fontScale)
    readonly property int trainingNumber: Math.round(32 * fontScale)
}
