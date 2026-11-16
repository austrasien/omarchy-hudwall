import QtQuick

// The outline of a league's insignia, as Prometheus' LeagueGem draws it:
// a circle, then polygons of 3 to 6 sides, then stars of 4 to 8 points.
QtObject {
  property int league: 0
  readonly property int sides: league === 0 ? 0 : league <= 4 ? league + 2 : 0
  readonly property int points: league >= 5 ? league - 1 : 0

  // The corners (a circle: 24 points round it).
  function vertices(r, cx, cy) {
    var out = []
    if (points > 0) {
      var inner = r * (points === 4 ? 0.38 : 0.46)
      for (var k = 0; k < points * 2; k++) {
        var b = -Math.PI / 2 + k * Math.PI / points
        var rr = k % 2 === 0 ? r : inner
        out.push(Qt.point(cx + rr * Math.cos(b), cy + rr * Math.sin(b)))
      }
    } else if (sides === 0) {
      for (var c = 0; c < 24; c++) {
        var t = c * 2 * Math.PI / 24
        out.push(Qt.point(cx + r * Math.cos(t), cy + r * Math.sin(t)))
      }
    } else {
      for (var i = 0; i < sides; i++) {
        var a = -Math.PI / 2 + (sides % 2 === 0 ? Math.PI / sides : 0) + i * 2 * Math.PI / sides
        out.push(Qt.point(cx + r * Math.cos(a), cy + r * Math.sin(a)))
      }
    }
    return out
  }
  function outline(ctx, r, cx, cy) {
    ctx.beginPath()
    if (sides === 0 && points === 0) { ctx.arc(cx, cy, r, 0, 2 * Math.PI); return }
    var v = vertices(r, cx, cy)
    for (var i = 0; i < v.length; i++) if (i === 0) ctx.moveTo(v[i].x, v[i].y); else ctx.lineTo(v[i].x, v[i].y)
    ctx.closePath()
  }
}
