import QtQuick
import QtQuick.Shapes

// A sparkline: `values` between 0 and 1 (or scaled by `max`), drawn left to
// right with an optional faint fill underneath.
//
// Peaks: the `peaks` highest local maxima get a callout with their value
// (`format(v)`), the same model as austraz.power's chart: local maxima only,
// sorted by height, a candidate dropped when it would sit on another callout
// or repeat a value within 12 %. Set `peaks: 0` for none.
Shape {
  id: spark

  property var values: []
  property real max: 1
  property color color: "white"
  property bool fill: true
  property real lineWidth: 1.2
  property int peaks: 5
  property var format: function(v) { return String(Math.round(v)) }
  property real calloutSize: 9
  // Callouts of other sparks drawn over the same area, to keep clear of.
  property var avoid: []
  // How far above the chart a label may go (a negative y: room kept free
  // over the chart for its labels).
  property real labelTop: 0
  // A label's width, guessed from its text (the font is monospace).
  function labelW(v) { return format(v).length * calloutSize * 0.62 + 4 }
  // Values at the middle of n slots (bars) rather than spread edge to edge.
  property bool centered: false

  readonly property var points: {
    var v = values || []
    var n = v.length
    var out = []
    if (n < 2) return out
    var m = max > 0 ? max : 1
    for (var i = 0; i < n; i++) {
      var y = height - 1 - Math.max(0, Math.min(1, (v[i] || 0) / m)) * (height - 2)
      out.push(Qt.point(centered ? (i + 0.5) / n * width : i / (n - 1) * width, y))
    }
    return out
  }

  readonly property var callouts: {
    var v = values || [], pts = points
    if (peaks <= 0 || pts.length < 3 || !(height > 4)) return []
    var m = max > 0 ? max : 1
    var floorY = height - 1
    var minLift = Math.max(3, (height - 2) * 0.10)
    var found = []
    function keep(i) {
      var val = v[i] || 0
      if (val < m * 0.06) return
      if (floorY - pts[i].y < minLift) return
      found.push({ x: pts[i].x, y: pts[i].y, v: val, w: labelW(val) })
    }
    for (var i = 1; i < pts.length - 1; i++)
      if ((v[i] || 0) > (v[i - 1] || 0) && (v[i] || 0) >= (v[i + 1] || 0)) keep(i)
    var last = pts.length - 1
    if ((v[last] || 0) > (v[last - 1] || 0)) keep(last)
    found.sort(function(a, b) { return a.y - b.y })
    var kept = []
    var others = avoid || []
    // Where the label ends up: pushed down inside the chart near its top.
    var top = calloutSize + 2 + labelTop
    function ly(p) { return Math.max(p.y, top) }
    // Where a label's centre ends up: kept inside the chart's width.
    function lx(p) { var w = p.w || 30; return Math.max(w / 2, Math.min(width - w / 2, p.x)) }
    function apart(p, q) { return Math.abs(lx(p) - lx(q)) >= ((p.w || 30) + (q.w || 30)) / 2 }
    for (var k = 0; k < found.length && kept.length < peaks; k++) {
      var c = found[k], clash = false
      for (var a = 0; a < others.length; a++)
        if (!apart(c, others[a]) && Math.abs(ly(c) - ly(others[a])) < calloutSize + 3) { clash = true; break }
      if (clash) continue
      for (var j = 0; j < kept.length; j++) {
        var o = kept[j]
        if (!apart(c, o) && Math.abs(ly(c) - ly(o)) < calloutSize + 3) { clash = true; break }
        if (Math.abs(c.v - o.v) <= o.v * 0.12) { clash = true; break }
      }
      if (!clash) kept.push(c)
    }
    return kept
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
    strokeColor: spark.lineWidth > 0 ? spark.color : "transparent"
    strokeWidth: spark.lineWidth > 0 ? spark.lineWidth : -1
    fillColor: "transparent"
    joinStyle: ShapePath.RoundJoin
    PathPolyline { path: spark.points }
  }

  Repeater {
    model: spark.callouts
    HText {
      required property var modelData
      text: spark.format(modelData.v)
      color: spark.color
      font.pixelSize: spark.calloutSize
      font.weight: Font.DemiBold
      style: Text.Outline
      styleColor: Qt.rgba(0, 0, 0, 0.55)
      x: Math.max(0, Math.min(spark.width - width, modelData.x - width / 2))
      // Inside the chart: above it sits a heading or a legend.
      y: Math.max(spark.labelTop, modelData.y - height - 1)
    }
  }
}
