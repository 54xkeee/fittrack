import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AppCard {
    id: root
    property var points: []
    property string metric: "highestWeight"
    property string title: ""
    property string suffix: " kg"
    property int selectedIndex: -1

    padding: 14
    implicitHeight: 220

    function valueAt(index) {
        return Number(points[index][metric] || 0)
    }

    function selectedText() {
        if (selectedIndex < 0 || selectedIndex >= points.length)
            return points.length === 0 ? qsTr("暂无数据") : qsTr("触摸图表查看数值")
        const point = points[selectedIndex]
        const date = new Date(point.date)
        const dateText = isNaN(date.getTime()) ? point.date : Qt.formatDate(date, "MM-dd")
        let extra = metric === "highestWeight"
                ? qsTr(" × %1次 · %2组").arg(point.highestReps).arg(point.highestSetCount) : ""
        return dateText + "　" + valueAt(selectedIndex).toFixed(1) + suffix + extra
    }

    onPointsChanged: {
        selectedIndex = -1
        chart.requestPaint()
    }
    onMetricChanged: chart.requestPaint()

    ColumnLayout {
        anchors.fill: parent
        Label { text: root.title; font.bold: true; font.pixelSize: 16 }
        Label { text: root.selectedText(); color: root.selectedIndex >= 0 ? "#8BD450" : "#AEB7B1" }
        Canvas {
            id: chart
            Layout.fillWidth: true
            Layout.fillHeight: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const left = 12, right = width - 12, top = 12, bottom = height - 22
                ctx.strokeStyle = "#39433E"
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(left, bottom)
                ctx.lineTo(right, bottom)
                ctx.stroke()
                if (!root.points || root.points.length === 0)
                    return
                let maximum = 0
                for (let i = 0; i < root.points.length; ++i)
                    maximum = Math.max(maximum, root.valueAt(i))
                maximum = Math.max(maximum, 1)
                function x(i) { return root.points.length === 1 ? (left + right) / 2 : left + (right-left) * i / (root.points.length-1) }
                function y(i) { return bottom - (bottom-top) * root.valueAt(i) / maximum }
                ctx.strokeStyle = "#8BD450"
                ctx.lineWidth = 3
                ctx.beginPath()
                for (let i = 0; i < root.points.length; ++i) {
                    if (i === 0) ctx.moveTo(x(i), y(i)); else ctx.lineTo(x(i), y(i))
                }
                ctx.stroke()
                for (let i = 0; i < root.points.length; ++i) {
                    ctx.fillStyle = i === root.selectedIndex ? "#FFFFFF" : "#8BD450"
                    ctx.beginPath()
                    ctx.arc(x(i), y(i), i === root.selectedIndex ? 6 : 4, 0, Math.PI * 2)
                    ctx.fill()
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: function(mouse) { selectPoint(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) selectPoint(mouse.x) }
                function selectPoint(pointerX) {
                    if (!root.points || root.points.length === 0) return
                    const ratio = Math.max(0, Math.min(1, (pointerX - 12) / Math.max(1, width - 24)))
                    root.selectedIndex = Math.round(ratio * (root.points.length - 1))
                    chart.requestPaint()
                }
            }
        }
    }
}
