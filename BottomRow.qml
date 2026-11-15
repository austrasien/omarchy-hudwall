import QtQuick
import QtQuick.Shapes

// Bottom row: ghost race, focus quality, caffeine, network, battery.
Item {
  id: row

  required property var pal
  required property var sys
  required property var prom
  property real pixelScale: 1

  width: 1232
  height: 176
  readonly property real weekW: 300
  readonly property real pw: (width - weekW - 5 * 8) / 5
  readonly property real weekX: 2 * (pw + 8)
  function px(i) { return i < 2 ? i * (pw + 8) : weekX + weekW + 8 + (i - 2) * (pw + 8) }

  readonly property var p: prom.p

  function hm(sec) {
    var s = Math.max(0, Math.round(sec || 0))
    return Math.floor(s / 3600) + " h " + String(Math.floor(s % 3600 / 60)).padStart(2, "0")
  }
  function clock(ms) {
    var d = new Date(ms)
    return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0")
  }

  // Focus seconds accumulated from the day's start, at each of `n` steps.
  function cumulative(tl, n, untilFrac) {
    if (!tl || !tl.sessions) return []
    var from = tl.fromMs, span = 18 * 3600000
    var out = []
    for (var i = 0; i <= n; i++) {
      var t = from + span * i / n
      if (untilFrac !== undefined && i / n > untilFrac) break
      var s = 0
      for (var k = 0; k < tl.sessions.length; k++) {
        var x = tl.sessions[k]
        if (x.start < t) s += Math.min(t, x.end) - x.start
      }
      out.push(s / 3600000)
    }
    return out
  }

  // ---------------------------------------------------------- ghost race
  HPanel {
    id: ghost
    pal: row.pal
    width: row.pw; height: 176
    label: "Ghost race"
    tip: "Focus time accumulated since the start of the day: today (orange) against your best day (cyan) and yesterday at the same time (grey). Click: Stats tab."
    tipAbove: true
    note: "vs record"
    tab: "stats"

    readonly property real nowFrac: row.prom.timeline ? Math.min(1, (Date.now() - row.prom.timeline.fromMs) / (18 * 3600000)) : 0
    readonly property var today: row.cumulative(row.prom.timeline, 72, nowFrac)
    readonly property var best: row.cumulative(row.prom.bestDay, 72)
    readonly property var yest: row.cumulative(row.prom.yesterday, 72, nowFrac)
    readonly property real topV: Math.max(4, best.length ? best[best.length - 1] : 0, today.length ? today[today.length - 1] : 0) * 1.1

    Item {
      width: parent.width; height: 104
      Repeater {
        model: 9
        Rectangle {
          required property int index
          x: parent.width * index / 9; width: 1; height: parent.height
          color: row.pal.alpha(row.pal.fg, 0.05)
        }
      }
      Spark {
        anchors.fill: parent; fill: false
        values: ghost.best; max: ghost.topV; color: row.pal.cyan; lineWidth: 1
        opacity: 0.8
      }
      Spark {
        width: parent.width * (ghost.yest.length - 1) / 72; height: parent.height; fill: false
        values: ghost.yest; max: ghost.topV; color: row.pal.mut; lineWidth: 1
      }
      Spark {
        width: parent.width * Math.max(1, ghost.today.length - 1) / 72; height: parent.height
        values: ghost.today; max: ghost.topV; color: row.pal.acc; lineWidth: 1.8
      }
    }
    HText {
      y: 110; width: parent.width
      readonly property real t: ghost.today.length ? ghost.today[ghost.today.length - 1] : 0
      readonly property real b: ghost.best.length ? ghost.best[Math.min(ghost.best.length - 1, ghost.today.length - 1)] || 0 : 0
      readonly property real y2: ghost.yest.length ? ghost.yest[ghost.yest.length - 1] : 0
      text: "today " + row.hm(t * 3600) + " · " + (t >= b ? "+" : "−") + row.hm(Math.abs(t - b) * 3600) + " vs record · "
        + (t >= y2 ? "+" : "−") + row.hm(Math.abs(t - y2) * 3600) + " vs yesterday"
      color: row.pal.dim; font.pixelSize: 8
    }
  }

  // ------------------------------------------------------- focus quality
  HPanel {
    id: quality
    pal: row.pal
    x: row.px(1); width: row.pw; height: 176
    label: "Focus quality"
    tip: "Share of today's tracked computer time spent in a focus session, window switches per hour, number of 2 h+ sessions and median session length. Graph: focus per hour today. Click: Stats tab."
    tipAbove: true
    note: "today"
    tab: "stats"

    readonly property var ins: row.prom.insights ? row.prom.insights.today : null
    readonly property real share: ins && ins.trackedSeconds > 0 ? ins.focusSeconds / ins.trackedSeconds : 0
    readonly property var sw: row.prom.summary && row.prom.summary.switchesPerHour !== null && row.prom.summary.switchesPerHour !== undefined
      ? row.prom.summary.switchesPerHour : (row.prom.extra ? row.prom.extra.focus.switchesPerHour : null)

    Row {
      spacing: 6
      HText { text: Math.round(quality.share * 100); color: row.pal.fg; font.pixelSize: 22; font.weight: Font.DemiBold }
      HText { anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: "% of tracked time in session"; color: row.pal.mut; font.pixelSize: 9 }
    }
    HText {
      y: 32; width: parent.width
      text: "flow " + (quality.sw !== null ? Math.round(quality.sw) : "–") + " switches/h · 2 h+ sessions "
        + (row.prom.summary ? row.prom.summary.deepSessions : 0) + " · median " + (row.prom.extra ? row.prom.extra.focus.medianMinutes : "–") + " min"
      color: row.pal.dim; font.pixelSize: 9
    }
    Spark {
      y: 52; width: parent.width; height: 70
      values: row.prom.coffeeDay ? row.prom.coffeeDay.hours.map(function(h) { return h.focus || 0 }) : []
      max: 3600; color: row.pal.acc2
    }
  }

  // ------------------------------------------------------------ caffeine
  HPanel {
    id: coffee
    pal: row.pal
    x: row.px(2); width: row.pw; height: 176
    label: "Caffeine"
    tip: "Caffeine estimated in your body (mg) and the best time for the next cup. Curve: today, dashed = forecast, cyan line = best time, dotted = the 'another cup is worth it' level. Bottom: average change on days with coffee. Hover the panel to log a cup or undo."
    tipAbove: true
    tab: "stats"
    readonly property var cd: row.prom.coffeeDay
    readonly property var now: row.p && row.p.coffee ? row.p.coffee : (cd ? cd.coffee : null)
    note: now ? now.cupsToday + (now.cupsToday === 1 ? " cup" : " cups") : ""

    HoverHandler { id: coffeeHover }

    Item {
      width: parent.width; height: 28
      Row {
        visible: !coffeeHover.hovered
        spacing: 6
        HText { text: coffee.now ? Math.round(coffee.now.inBody || 0) : "–"; color: row.pal.fg; font.pixelSize: 22; font.weight: Font.DemiBold }
        HText {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 4
          width: 170
          text: "mg · " + (coffee.now && coffee.now.ideal && coffee.now.ideal.at ? "next best at " + row.clock(coffee.now.ideal.at) : (coffee.now && coffee.now.ideal ? coffee.now.ideal.reason : ""))
          color: row.pal.mut; font.pixelSize: 9
        }
      }
      Row {
        visible: coffeeHover.hovered
        spacing: 6
        HButton { pal: row.pal; text: "☕ +1 cup"; onClicked: row.prom.act("coffee:add", []) }
        HButton { pal: row.pal; tone: "g"; text: "undo"; visible: coffee.now && coffee.now.canUndo; onClicked: row.prom.act("coffee:undo", []) }
      }
    }
    HiCanvas {
      id: curve
      y: 34; width: parent.width; height: 80
      pixelScale: row.pixelScale
      property var cdata: coffee.cd
      onCdataChanged: requestPaint()
      function draw(ctx) {
        if (!cdata || !cdata.caffeine || !cdata.caffeine.length) return
        var c = cdata.caffeine
        var t0 = cdata.fromMs, t1 = cdata.toMs
        var maxMg = Math.max(cdata.lowMg * 2.5, 1)
        for (var i = 0; i < c.length; i++) maxMg = Math.max(maxMg, c[i].mg * 1.1)
        function X(t) { return (t - t0) / (t1 - t0) * width }
        function Y(mg) { return height - 10 - mg / maxMg * (height - 16) }
        ctx.setLineDash([2, 3]); ctx.strokeStyle = row.pal.css(row.pal.mut); ctx.lineWidth = 1
        ctx.beginPath(); ctx.moveTo(0, Y(cdata.lowMg)); ctx.lineTo(width, Y(cdata.lowMg)); ctx.stroke()
        ctx.setLineDash([])
        ctx.strokeStyle = row.pal.css(row.pal.acc); ctx.lineWidth = 1.5
        ctx.beginPath()
        var started = false
        for (i = 0; i < c.length; i++) {
          if (c[i].future) break
          started ? ctx.lineTo(X(c[i].at), Y(c[i].mg)) : ctx.moveTo(X(c[i].at), Y(c[i].mg)); started = true
        }
        ctx.stroke()
        ctx.setLineDash([3, 3]); ctx.globalAlpha = 0.6; ctx.beginPath(); started = false
        for (i = 0; i < c.length; i++) {
          if (!c[i].future) continue
          started ? ctx.lineTo(X(c[i].at), Y(c[i].mg)) : ctx.moveTo(X(c[i].at), Y(c[i].mg)); started = true
        }
        ctx.stroke(); ctx.setLineDash([]); ctx.globalAlpha = 1
        var nowX = X(cdata.now)
        ctx.strokeStyle = row.pal.css(row.pal.alpha(row.pal.fg, 0.3)); ctx.beginPath(); ctx.moveTo(nowX, 0); ctx.lineTo(nowX, height - 10); ctx.stroke()
        var ideal = cdata.coffee && cdata.coffee.ideal ? cdata.coffee.ideal.at : null
        if (ideal) { ctx.strokeStyle = row.pal.css(row.pal.cyan); ctx.beginPath(); ctx.moveTo(X(ideal), 4); ctx.lineTo(X(ideal), height - 10); ctx.stroke() }
        ctx.fillStyle = row.pal.css(row.pal.dim); ctx.font = "8px sans-serif"
        var cups = cdata.cups || []
        for (i = 0; i < cups.length; i++) ctx.fillText("☕", X(cups[i].at || cups[i]) - 4, height)
      }
    }
    HText {
      anchors.bottom: parent.bottom
      width: parent.width
      readonly property var cmp: row.prom.coffeeStats && row.prom.coffeeStats.compare ? row.prom.coffeeStats.compare : null
      function pct(k) {
        if (!cmp || !cmp[k] || !cmp[k].without) return "–"
        var v = Math.round((cmp[k].with / cmp[k].without - 1) * 100)
        return (v >= 0 ? "+" : "") + v + " %"
      }
      text: "with coffee: " + pct("focus") + " focus · " + pct("tasks") + " tasks · " + pct("tokens") + " tokens"
      color: row.pal.dim; font.pixelSize: 8
    }
  }

  // ------------------------------------------------------------- network
  HPanel {
    pal: row.pal
    x: row.px(3); width: row.pw; height: 176
    label: "Network"
    tip: "Download (orange) and upload (cyan) rate of the active connection over the last 80 s; Wi-Fi network and band; Tailscale relay and peers with ping latency."
    tipAbove: true
    note: (row.sys.net.ssid || row.sys.net.iface || "") + (row.sys.net.mhz ? " · " + (row.sys.net.mhz > 5900 ? "6" : row.sys.net.mhz > 4000 ? "5" : "2,4") + " GHz" : "")

    Row {
      spacing: 14
      HText { text: "↓ " + row.sys.rate(row.sys.net.down); color: row.pal.acc; font.pixelSize: 10 }
      HText { text: "↑ " + row.sys.rate(row.sys.net.up); color: row.pal.cyan; font.pixelSize: 10 }
    }
    Item {
      y: 20; width: parent.width; height: 62
      readonly property real topV: Math.max(50000, Math.max.apply(null, row.sys.downHist.concat(row.sys.upHist, [1])))
      Spark { anchors.fill: parent; values: row.sys.downHist; max: parent.topV; color: row.pal.acc }
      Spark { anchors.fill: parent; values: row.sys.upHist; max: parent.topV; color: row.pal.cyan; fill: false; lineWidth: 1 }
    }
    Column {
      y: 88; width: parent.width
      spacing: 2
      HText {
        text: "TAILSCALE " + (row.sys.tail.up ? "· relay " + (row.sys.tail.relay || "–") : "· stopped")
        color: row.pal.mut; font.pixelSize: 8; font.letterSpacing: 1
      }
      Flow {
        width: parent.width
        spacing: 10
        Repeater {
          model: (row.sys.tail.peers || []).slice(0, 4)
          HText {
            required property var modelData
            text: (modelData.online ? "● " : "○ ") + modelData.name + (modelData.ms !== undefined && modelData.ms !== null ? " " + modelData.ms + " ms" : "")
            color: modelData.online ? row.pal.fg : row.pal.mut
            font.pixelSize: 9
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- battery
  HPanel {
    id: batt
    pal: row.pal
    x: row.px(4); width: row.pw; height: 176
    label: "Battery"
    tip: "Current power draw (W) and charge level; time to empty or full. Graph: charge (orange) and draw (pink) over the last 24 h, from UPower."
    tipAbove: true
    readonly property var b: row.sys.bat
    note: b.left ? (b.status === "Charging" ? "full in " : "") + row.hm(b.left) + (b.status === "Charging" ? "" : " left") : (b.status === "Full" ? "full" : b.ac ? "on AC" : "")

    Row {
      width: parent.width
      spacing: 6
      HText { text: batt.b.watts !== undefined ? batt.b.watts.toFixed(1) : "–"; color: row.pal.fg; font.pixelSize: 22; font.weight: Font.DemiBold }
      HText { anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: "W · " + (batt.b.pct !== undefined ? batt.b.pct + " %" : "") + (batt.b.status === "Charging" ? " · charging" : ""); color: row.pal.mut; font.pixelSize: 9 }
    }
    // The day: charge (bright), draw in watts (faint).
    Item {
      y: 36; width: parent.width; height: 84
      readonly property real t1: Date.now() / 1000
      readonly property real t0: t1 - 86400
      function series(list, max) {
        var out = []
        var l = list || []
        if (l.length < 2) return out
        var n = 96
        var j = 0
        for (var i = 0; i < n; i++) {
          var t = t0 + 86400 * i / (n - 1)
          while (j < l.length - 1 && l[j + 1][0] <= t) j++
          out.push(l[j][0] <= t ? l[j][1] / max : 0)
        }
        return out
      }
      Spark { anchors.fill: parent; values: parent.series(row.sys.batDay.rate, 40); color: row.pal.mag; fill: false; lineWidth: 1; opacity: 0.6 }
      Spark { anchors.fill: parent; values: parent.series(row.sys.batDay.charge, 100); color: row.pal.acc }
    }
    HText { anchors.bottom: parent.bottom; text: "24 h · charge ━  watts ━"; color: row.pal.mut; font.pixelSize: 8 }
  }

  // ------------------------------------------------------- week of focus
  HPanel {
    id: weekPanel
    pal: row.pal
    x: row.weekX; width: row.weekW; height: 176
    label: "Week · focus"
    tip: "This week, day by day: focus time (bright) over tracked computer time (faint). Grid: focus by weekday × hour over the last 8 weeks. Click: Stats tab."
    tipAbove: true
    tab: "stats"
    readonly property var days: row.prom.week ? row.prom.week.days || [] : []
    readonly property real focusTotal: days.reduce(function(a, d) { return a + (d.focusSeconds || 0) }, 0)
    note: Math.floor(focusTotal / 3600) + " h " + String(Math.floor(focusTotal % 3600 / 60)).padStart(2, "0")

    Row {
      spacing: 12
      // Mon–Sun: tracked time faint, focus bright.
      Column {
        width: 100
        spacing: 3
        Repeater {
          model: weekPanel.days
          Row {
            required property var modelData
            spacing: 4
            readonly property real span: 10 * 3600
            HText {
              width: 8
              text: "SMTWTFS".charAt(new Date(modelData.date + "T12:00:00").getDay())
              color: modelData.date === (row.prom.p ? row.prom.p.todayDate : "") ? row.pal.fg : row.pal.mut
              font.pixelSize: 8
            }
            Item {
              width: 84; height: 9
              Rectangle { width: Math.min(84, 84 * (modelData.trackedSeconds || 0) / parent.parent.span); height: 9; color: row.pal.alpha(row.pal.fg, 0.07) }
              Rectangle { width: Math.min(84, 84 * (modelData.focusSeconds || 0) / parent.parent.span); height: 9; color: row.pal.acc; opacity: 0.85 }
            }
          }
        }
      }
      // Weekday × hour over the last weeks.
      Column {
        spacing: 3
        readonly property var minutes: row.prom.extra && row.prom.extra.heatmap ? row.prom.extra.heatmap.minutes : []
        readonly property real maxM: {
          var m = 1
          for (var r = 0; r < minutes.length; r++) for (var c = 0; c < minutes[r].length; c++) m = Math.max(m, minutes[r][c])
          return m
        }
        Repeater {
          model: parent.minutes
          Row {
            required property var modelData
            spacing: 1.2
            Repeater {
              model: modelData
              Rectangle {
                required property var modelData
                width: 6.6; height: 9
                color: modelData > 0 ? row.pal.acc : row.pal.alpha(row.pal.fg, 0.05)
                opacity: modelData > 0 ? 0.15 + 0.85 * modelData / parent.parent.parent.maxM : 1
              }
            }
          }
        }
      }
    }
  }
}
