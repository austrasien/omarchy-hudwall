import QtQuick

// The season as a constellation behind the globe: a star for each day of
// the running quarter with focus (bigger with more), always at the same
// place for the same date, and a line between days that follow each other.
HiCanvas {
  id: sky

  required property var pal
  property var year: []           // [{ date, focus }]
  property var season: null       // { start, end }
  property real cx: width / 2
  property real cy: height / 2
  property real inner: 272        // keep clear of the globe and its rings

  onYearChanged: requestPaint()
  onSeasonChanged: requestPaint()

  // A stable pseudo-random number from a string.
  function hash(str, salt) {
    var h = 2166136261 ^ salt
    for (var i = 0; i < str.length; i++) {
      h ^= str.charCodeAt(i)
      h = Math.imul(h, 16777619)
    }
    return ((h >>> 0) % 100000) / 100000
  }

  function draw(ctx) {
    if (!year || !year.length) return
    var start = season ? season.start : null
    var end = season ? season.end : null
    var days = year.filter(function(d) {
      return d.focus > 0 && (!start || (d.date >= start && d.date <= end))
    })
    days.sort(function(a, b) { return a.date < b.date ? -1 : 1 })
    var maxF = 1
    days.forEach(function(d) { maxF = Math.max(maxF, d.focus) })
    var pts = days.map(function(d) {
      var a = hash(d.date, 7) * 2 * Math.PI
      var r = inner + hash(d.date, 13) * (Math.min(width, height) / 2 - inner - 4)
      return { x: cx + r * Math.cos(a) * 0.9, y: cy + r * Math.sin(a), s: 0.8 + 2.2 * d.focus / maxF, date: d.date }
    })
    ctx.strokeStyle = pal.css(pal.cyan, 0.13)
    ctx.lineWidth = 0.7
    for (var i = 1; i < pts.length; i++) {
      var prev = new Date(pts[i - 1].date + "T12:00:00"), cur = new Date(pts[i].date + "T12:00:00")
      if (cur - prev <= 86400000 * 1.5) {
        ctx.beginPath(); ctx.moveTo(pts[i - 1].x, pts[i - 1].y); ctx.lineTo(pts[i].x, pts[i].y); ctx.stroke()
      }
    }
    for (i = 0; i < pts.length; i++) {
      ctx.fillStyle = pal.css(i % 3 ? pal.acc : pal.cyan, 0.55)
      ctx.beginPath(); ctx.arc(pts[i].x, pts[i].y, pts[i].s, 0, 2 * Math.PI); ctx.fill()
    }
  }
}
