import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string name: ""
    property color color: "white"
    property real strokeWidth: 1.8
    readonly property real drawingScale: Math.max(
                                             0, Math.min(width, height) / 24)

    implicitWidth: 24
    implicitHeight: 24
    Accessible.ignored: true

    readonly property string pathData: {
        switch (name) {
        case "home": return "M3 11L12 3L21 11 M5 10V21H19V10 M9 21V15H15V21"
        case "plan": return "M5 4H19V21H5Z M8 2V6 M16 2V6 M5 9H19 M8 13H11 M13 13H16 M8 17H11"
        case "training": return "M12 3A9 9 0 1 0 12 21A9 9 0 1 0 12 3 M12 8V16 M8 12H16"
        case "library": return "M3 9V15 M6 7V17 M9 10H15 M18 7V17 M21 9V15"
        case "analysis": return "M4 19V14 M10 19V10 M16 19V6 M3 21H21 M5 10L10 6L14 9L20 3"
        case "add": return "M12 5V19 M5 12H19"
        case "close": return "M6 6L18 18 M18 6L6 18"
        case "back": return "M15 5L8 12L15 19"
        case "forward": return "M9 5L16 12L9 19"
        case "more": return "M5 12H5.01 M12 12H12.01 M19 12H19.01"
        case "edit": return "M4 20L8.5 19L19 8.5L15.5 5L5 15.5Z M13.5 7L17 10.5"
        case "up": return "M5 15L12 8L19 15"
        case "down": return "M5 9L12 16L19 9"
        case "reorder": return "M8 8L12 4L16 8 M12 4V20 M8 16L12 20L16 16"
        case "image": return "M3 5H21V19H3Z M3 16L8 11L12 15L15 12L21 18 M16 9H16.01"
        case "favorite": return "M12 3L14.8 8.7L21 9.6L16.5 14L17.6 20.2L12 17.3L6.4 20.2L7.5 14L3 9.6L9.2 8.7Z"
        case "search": return "M10.5 4A6.5 6.5 0 1 0 10.5 17A6.5 6.5 0 1 0 10.5 4 M15.5 15.5L21 21"
        case "history": return "M12 4A8 8 0 1 0 12 20A8 8 0 1 0 12 4 M12 8V12L15 14"
        case "info": return "M12 10V17 M12 7H12.01 M12 3A9 9 0 1 0 12 21A9 9 0 1 0 12 3"
        case "success": return "M4 12L9 17L20 6"
        case "warning": return "M12 3L22 20H2Z M12 9V14 M12 17H12.01"
        default: return ""
        }
    }

    Shape {
        anchors.centerIn: parent
        width: 24
        height: 24
        visible: root.pathData.length > 0
        transform: Scale {
            origin.x: 12
            origin.y: 12
            xScale: root.drawingScale
            yScale: root.drawingScale
        }

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg { path: root.pathData }
        }
    }
}
