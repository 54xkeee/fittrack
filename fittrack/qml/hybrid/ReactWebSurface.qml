import QtQuick 6.9
import QtWebChannel
import QtWebEngine

WebEngineView {
    id: root
    objectName: "reactTrainingWebView"
    url: "qrc:/web/index.html"
    backgroundColor: "#F5F7FB"

    webChannel: WebChannel {
        registeredObjects: [workoutController, restTimer]
    }

    settings.localContentCanAccessFileUrls: true
    settings.localContentCanAccessRemoteUrls: false
}
