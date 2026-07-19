import QtQuick 6.9
import QtQuick.Controls
import "../components"
import "../theme" as Design

AppPage {
    id: root
    objectName: "reactTrainingPage"

    background: Rectangle { color: Design.Theme.canvas }
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    Loader {
        anchors.fill: parent
        source: reactTrainingEnabled ? "qrc:/hybrid/ReactWebSurface.qml" : ""
    }

    AppEmptyState {
        anchors.centerIn: parent
        width: Math.min(parent.width - Design.Theme.space32, 360)
        visible: !reactTrainingEnabled
        title: qsTr("React 训练页面尚未启用")
        message: qsTr("安装 Qt WebEngine 与 Qt WebChannel 后，使用 FITTRACK_ENABLE_REACT_WEBENGINE 构建即可启用。")
    }
}
