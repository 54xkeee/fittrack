import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import "../theme" as Design

AppCard {
    id: root
    property var points: []
    property string metric: "highestWeight"
    property string title: ""
    property string suffix: " kg"
    property int selectedIndex: -1

    padding: Design.Theme.space16
    implicitHeight: 220

    function pointCount() {
        return points ? points.length : 0
    }

    function valueAt(index) {
        if (!points || index < 0 || index >= points.length)
            return 0
        const value = Number(points[index][metric] || 0)
        return isFinite(value) ? value : 0
    }

    function dateText(point) {
        const date = new Date(point.date)
        return isNaN(date.getTime())
                ? String(point.date || "")
                : Qt.locale().toString(date, Locale.ShortFormat)
    }

    function pointText(index) {
        if (!points || index < 0 || index >= points.length)
            return ""
        const point = points[index]
        let extra = metric === "highestWeight"
                ? qsTr(" × %1次 · %2组").arg(point.highestReps).arg(point.highestSetCount) : ""
        return dateText(point) + "　" + valueAt(index).toFixed(1) + suffix + extra
    }

    function trendSummary() {
        if (pointCount() === 0)
            return qsTr("暂无趋势点")
        const summary = []
        for (let i = 0; i < points.length; ++i)
            summary.push(pointText(i))
        return summary.join(qsTr("；"))
    }

    function selectedText() {
        if (selectedIndex < 0 || selectedIndex >= pointCount())
            return pointCount() === 0
                    ? qsTr("暂无数据")
                    : qsTr("触摸图表或使用左右方向键查看数值")
        return pointText(selectedIndex)
    }

    function accessibleDescription() {
        if (pointCount() === 0)
            return qsTr("暂无数据。")
        const current = selectedIndex >= 0 && selectedIndex < pointCount()
                ? qsTr("当前选中：%1。").arg(pointText(selectedIndex))
                : qsTr("尚未选择趋势点。")
        return current
                + qsTr("全部趋势点：%1。").arg(trendSummary())
                + qsTr("使用左右方向键选择上一个或下一个点。")
    }

    function selectPoint(index) {
        if (pointCount() === 0)
            return
        selectedIndex = Math.max(0, Math.min(pointCount() - 1, index))
        chart.requestPaint()
    }

    function selectPreviousPoint() {
        if (pointCount() === 0)
            return
        selectPoint(selectedIndex < 0 ? pointCount() - 1 : selectedIndex - 1)
    }

    function selectNextPoint() {
        if (pointCount() === 0)
            return
        selectPoint(selectedIndex < 0 ? 0 : selectedIndex + 1)
    }

    onPointsChanged: {
        selectedIndex = -1
        chart.requestPaint()
    }
    onMetricChanged: chart.requestPaint()

    ColumnLayout {
        anchors.fill: parent
        Label {
            text: root.title
            color: Design.Theme.surfaceText
            font.weight: Font.DemiBold
            font.pixelSize: Design.Theme.typeBody
        }
        Label {
            text: root.selectedText()
            color: root.selectedIndex >= 0 ? Design.Theme.primary : Design.Theme.surfaceMuted
            font.pixelSize: Design.Theme.typeLabel
        }
        Canvas {
            id: chart
            Layout.fillWidth: true
            Layout.fillHeight: true
            activeFocusOnTab: true

            Accessible.role: Accessible.Chart
            Accessible.name: root.title.length > 0 ? root.title : qsTr("趋势图")
            Accessible.description: root.accessibleDescription()
            Accessible.focusable: true
            Accessible.focused: activeFocus
            Accessible.onIncreaseAction: root.selectNextPoint()
            Accessible.onDecreaseAction: root.selectPreviousPoint()

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Left) {
                    root.selectPreviousPoint()
                } else if (event.key === Qt.Key_Right) {
                    root.selectNextPoint()
                } else if (event.key === Qt.Key_Home) {
                    root.selectPoint(0)
                } else if (event.key === Qt.Key_End) {
                    root.selectPoint(root.pointCount() - 1)
                } else {
                    return
                }
                event.accepted = true
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                const left = 12, right = width - 12, top = 12, bottom = height - 22
                ctx.strokeStyle = Design.Theme.outline
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
                ctx.strokeStyle = Design.Theme.primary
                ctx.lineWidth = 3
                ctx.beginPath()
                for (let i = 0; i < root.points.length; ++i) {
                    if (i === 0) ctx.moveTo(x(i), y(i)); else ctx.lineTo(x(i), y(i))
                }
                ctx.stroke()
                for (let i = 0; i < root.points.length; ++i) {
                    ctx.fillStyle = i === root.selectedIndex
                            ? Design.Theme.surfaceText : Design.Theme.primary
                    ctx.beginPath()
                    ctx.arc(x(i), y(i), i === root.selectedIndex ? 6 : 4, 0, Math.PI * 2)
                    ctx.fill()
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: Design.Theme.primary
                border.width: 2
                radius: Design.Theme.radiusSmall
                visible: chart.activeFocus
                z: 2
                Accessible.ignored: true
            }

            MouseArea {
                anchors.fill: parent
                onPressed: function(mouse) { selectPoint(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) selectPoint(mouse.x) }
                function selectPoint(pointerX) {
                    if (!root.points || root.points.length === 0) return
                    const ratio = Math.max(0, Math.min(1, (pointerX - 12) / Math.max(1, width - 24)))
                    root.selectPoint(Math.round(ratio * (root.points.length - 1)))
                }
            }
        }
    }
}
