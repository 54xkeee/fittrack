import QtQuick
import QtQuick.Controls

Control {
    id: root

    property Item topBar: null
    property Item bottomBar: null
    default property alias content: contentContainer.data

    function placeChrome() {
        if (topBar)
            topBar.parent = topBarContainer
        if (bottomBar)
            bottomBar.parent = bottomBarContainer
    }

    onTopBarChanged: placeChrome()
    onBottomBarChanged: placeChrome()
    Component.onCompleted: placeChrome()

    padding: 0
    background: null
    contentItem: Item {
        Item {
            id: topBarContainer
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.topBar && root.topBar.visible ? root.topBar.implicitHeight : 0
        }
        Item {
            id: bottomBarContainer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.bottomBar && root.bottomBar.visible ? root.bottomBar.implicitHeight : 0
        }
        Item {
            id: contentContainer
            anchors.top: topBarContainer.bottom
            anchors.bottom: bottomBarContainer.top
            anchors.left: parent.left
            anchors.right: parent.right
        }
    }
}
