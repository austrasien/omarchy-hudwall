import QtQuick
import QtQuick.Shapes

// A sparkline: `values` between 0 and 1 (or scaled by `max`), drawn left to
// right with an optional faint fill underneath.
Shape {
  id: spark

  property var values: []
  property real max: 1
  property color color: "white"
  property bool fill: true
  property real lineWidth: 1.2

  readonly property var points: {
    var v = values || []
    var n = v.length
    var out = []
    if (n < 2) return out
    var m = max > 0 ? max : 1
    for (var i = 0; i < n; i++) {
      var y = height - 1 - Math.max(0, Math.min(1, (v[i] || 0) / m)) * (height - 2)
      out.push(Qt.point(i / (n - 1) * width, y))
    }
    return out
  }

  ShapePath {
    strokeWidth: -1
    fillColor: spark.fill && spark.points.length ? Qt.rgba(spark.color.r, spark.color.g, spark.color.b, 0.12) : "transparent"
    startX: 0; startY: spark.height
    PathPolyline { path: spark.points }
    PathLine { x: spark.width; y: spark.height }
    PathLine { x: 0; y: spark.height }
  }
  ShapePath {
    strokeColor: spark.color
    strokeWidth: spark.lineWidth
    fillColor: "transparent"
    joinStyle: ShapePath.RoundJoin
    PathPolyline { path: spark.points }
  }
}
