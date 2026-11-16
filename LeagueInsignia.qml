import QtQuick

// A league's insignia, in Prometheus' shapes (LeagueGem: Bronze a circle,
// Silver a triangle, Gold a square, Sapphire a pentagon, Ruby a hexagon, then
// stars of four to eight points), given a material: the three metals shaded
// like a struck coin, the gems cut in facets. Now and then a glint crosses it.
Canvas {
  id: ins

  property int league: 0
  property color color: "#cd7f32"
  property bool animate: true

  readonly property bool metal: league <= 2
  property real glint: -1

  ShapeOf { id: shape; league: ins.league }

  onLeagueChanged: requestPaint()
  onColorChanged: requestPaint()
  onGlintChanged: requestPaint()
  onWidthChanged: requestPaint()
  Component.onCompleted: requestPaint()

  SequentialAnimation {
    running: ins.animate && ins.visible
    loops: Animation.Infinite
    PauseAnimation { duration: 7000 }
    NumberAnimation { target: ins; property: "glint"; from: 0; to: 1; duration: 1100; easing.type: Easing.InOutQuad }
    ScriptAction { script: ins.glint = -1 }
  }

  function css(c, k) {
    var r = Math.max(0, Math.min(255, Math.round(c.r * 255 * k)))
    var g = Math.max(0, Math.min(255, Math.round(c.g * 255 * k)))
    var b = Math.max(0, Math.min(255, Math.round(c.b * 255 * k)))
    return "rgb(" + r + "," + g + "," + b + ")"
  }

  onPaint: {
    // The shape helper may not be ready on the first paint at load.
    if (typeof shape.vertices !== "function") { Qt.callLater(requestPaint); return }
    var ctx = getContext("2d")
    ctx.reset()
    var cx = width / 2, cy = height / 2
    var r = (Math.min(width, height) / 2 - 1.5) * (shape.sides === 3 ? 1.08 : 1)
    if (shape.sides === 3) cy += r * 0.12
    var pts = shape.vertices(r, cx, cy)

    ctx.save()
    shape.outline(ctx, r, cx, cy)
    ctx.clip()
    if (metal) {
      // A struck coin: light from the top left, a darker rim, a raised face.
      var g = ctx.createRadialGradient(cx - r * 0.35, cy - r * 0.4, r * 0.1, cx, cy, r * 1.05)
      g.addColorStop(0, css(color, 1.9))
      g.addColorStop(0.45, css(color, 1.1))
      g.addColorStop(1, css(color, 0.45))
      ctx.fillStyle = g
      ctx.fillRect(0, 0, width, height)
      ctx.lineWidth = Math.max(1, r * 0.12)
      ctx.strokeStyle = css(color, 0.55)
      shape.outline(ctx, r * 0.78, cx, cy)
      ctx.stroke()
      ctx.lineWidth = 1
      ctx.strokeStyle = "rgba(255,255,255,0.35)"
      shape.outline(ctx, r * 0.72, cx - 0.5, cy - 0.5)
      ctx.stroke()
    } else {
      // A cut stone: one facet per edge from a small table in the middle,
      // lit from the top left.
      ctx.fillStyle = css(color, 0.8)
      ctx.fillRect(0, 0, width, height)
      var n = pts.length
      for (var i = 0; i < n; i++) {
        var a = pts[i], b = pts[(i + 1) % n]
        var mx = (a.x + b.x) / 2 - cx, my = (a.y + b.y) / 2 - cy
        var lit = (-mx - my) / (Math.sqrt(mx * mx + my * my) || 1)   // -1.4 .. 1.4
        ctx.beginPath()
        ctx.moveTo(cx + (a.x - cx) * 0.35, cy + (a.y - cy) * 0.35)
        ctx.lineTo(a.x, a.y); ctx.lineTo(b.x, b.y)
        ctx.lineTo(cx + (b.x - cx) * 0.35, cy + (b.y - cy) * 0.35)
        ctx.closePath()
        ctx.fillStyle = css(color, 1 + 0.45 * lit)
        ctx.fill()
        ctx.strokeStyle = "rgba(255,255,255,0.25)"; ctx.lineWidth = 0.8
        ctx.stroke()
      }
      // The table.
      ctx.beginPath()
      for (var j = 0; j < n; j++) {
        var p = pts[j]
        var tx = cx + (p.x - cx) * 0.35, ty = cy + (p.y - cy) * 0.35
        if (j === 0) ctx.moveTo(tx, ty); else ctx.lineTo(tx, ty)
      }
      ctx.closePath()
      var t = ctx.createLinearGradient(cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3)
      t.addColorStop(0, css(color, 1.9)); t.addColorStop(1, css(color, 1.1))
      ctx.fillStyle = t
      ctx.fill()
    }
    // The glint.
    if (glint >= 0) {
      var x0 = -width + width * 2 * glint
      var gl = ctx.createLinearGradient(x0, 0, x0 + width * 0.7, height * 0.7)
      gl.addColorStop(0, "rgba(255,255,255,0)")
      gl.addColorStop(0.5, "rgba(255,255,255,0.8)")
      gl.addColorStop(1, "rgba(255,255,255,0)")
      ctx.fillStyle = gl
      ctx.fillRect(0, 0, width, height)
    }
    ctx.restore()
    // Edge.
    shape.outline(ctx, r, cx, cy)
    ctx.lineWidth = 1
    ctx.strokeStyle = css(color, 1.6)
    ctx.stroke()
  }
}
