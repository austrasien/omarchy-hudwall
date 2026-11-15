import QtQuick

// The two rings around the globe: the year (a tick a day, brighter with
// more focus) and today's 24 hours, cut by application, with the running
// session as an arc and a dot at the current time.
HiCanvas {
  id: rings

  required property var pal
  property var year: []           // [{ date, focus }]
  property var timeline: null     // stats:timeline of today
  property var appColors: ({})    // app -> color
  property var session: null      // Prometheus session, or null
  property int dayStartHour: 5
  property int minute: 0          // ticks once a minute, to move "now"

  readonly property real cx: width / 2
  readonly property real cy: height / 2

  onYearChanged: requestPaint()
  onTimelineChanged: requestPaint()
  onAppColorsChanged: requestPaint()
  onSessionChanged: requestPaint()
  onMinuteChanged: requestPaint()

  function seg(ctx, r1, r2, a0, a1) {
    ctx.beginPath()
    ctx.arc(cx, cy, r2, a0, a1, false)
    ctx.arc(cx, cy, r1, a1, a0, true)
    ctx.closePath()
    ctx.fill()
  }
  // Angle of a time of day (0 h at the top, clockwise).
  function hourAngle(h) { return h / 24 * 2 * Math.PI - Math.PI / 2 }

  function draw(ctx) {
    var P = pal
    var now = new Date()

    // ---- year: a tick per day of the calendar year
    var y0 = new Date(now.getFullYear(), 0, 1)
    var daysInYear = (new Date(now.getFullYear() + 1, 0, 1) - y0) / 86400000
    var today = Math.floor((now - y0) / 86400000)
    var focusByDay = {}
    var maxF = 3600
    for (var i = 0; i < year.length; i++) {
      focusByDay[year[i].date] = year[i].focus
      maxF = Math.max(maxF, year[i].focus)
    }
    for (var d = 0; d < daysInYear; d++) {
      var date = new Date(y0.getTime() + d * 86400000 + 12 * 3600000)
      var key = date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" + String(date.getDate()).padStart(2, "0")
      var a0 = d / daysInYear * 2 * Math.PI - Math.PI / 2
      var a1 = a0 + 2 * Math.PI / daysInYear * 0.7
      var f = focusByDay[key] || 0
      if (d === today) ctx.fillStyle = "white"
      else if (d > today) ctx.fillStyle = P.css(P.fg, 0.07)
      else ctx.fillStyle = P.css(P.acc, f > 0 ? 0.25 + 0.75 * f / maxF : 0.1)
      seg(ctx, 224, 236, a0, a1)
    }
    ctx.fillStyle = P.css(P.mut, 1)
    ctx.font = "8px monospace"
    ctx.textAlign = "center"
    var months = "JFMAMJJASOND"
    for (var m = 0; m < 12; m++) {
      var am = m / 12 * 2 * Math.PI - Math.PI / 2
      ctx.fillText(months.charAt(m), cx + 248 * Math.cos(am), cy + 248 * Math.sin(am) + 3)
    }

    // ---- 24 h dial, coloured by app
    var span = 2 * Math.PI / 24
    ctx.fillStyle = P.css(P.fg, 0.06)
    for (var h = 0; h < 24; h++) seg(ctx, 200, 212, hourAngle(h) + 0.015, hourAngle(h + 1) - 0.015)
    if (timeline && timeline.segments) {
      for (i = 0; i < timeline.segments.length; i++) {
        var s = timeline.segments[i]
        var t0 = new Date(s.start), t1 = new Date(s.end)
        var h0 = t0.getHours() + t0.getMinutes() / 60 + t0.getSeconds() / 3600
        var h1 = t1.getHours() + t1.getMinutes() / 60 + t1.getSeconds() / 3600
        if (h1 < h0) h1 = 24
        ctx.fillStyle = P.css(appColors[s.app] || P.mut, 0.85)
        seg(ctx, 200, 212, hourAngle(h0), hourAngle(h1))
      }
    }
    ctx.fillStyle = P.css(P.dim, 1)
    for (h = 0; h < 24; h += 6) {
      var ah = hourAngle(h)
      ctx.fillText(String(h).padStart(2, "0"), cx + 190 * Math.cos(ah), cy + 190 * Math.sin(ah) + 3)
    }

    // ---- now, and the running session as an arc
    var hn = now.getHours() + now.getMinutes() / 60
    var an = hourAngle(hn)
    if (session && session.startedAt) {
      var st = new Date(session.startedAt)
      var hs = st.getHours() + st.getMinutes() / 60
      ctx.strokeStyle = session.pauseStartedAt ? P.css(P.dim, 1) : "white"
      ctx.lineWidth = 1.5
      ctx.beginPath(); ctx.arc(cx, cy, 195, hourAngle(hs), an, false); ctx.stroke()
    }
    ctx.fillStyle = "white"
    ctx.beginPath(); ctx.arc(cx + 206 * Math.cos(an), cy + 206 * Math.sin(an), 4, 0, 2 * Math.PI); ctx.fill()
  }
}
