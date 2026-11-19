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
  // The coffee time field takes the keyboard while it is open.
  readonly property bool wantsKeyboard: coffee.logging

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
  // Two races since the start of the day, on the same legend: time in focus
  // sessions, and agent tokens; today against the record and yesterday.
  function tokenRun(day, untilNow) {
    if (!day || !day.hours) return []
    var out = [0], acc = 0
    var last = untilNow ? Math.min(day.hours.length, Math.floor((Date.now() - day.fromMs) / 3600000) + 1) : day.hours.length
    for (var i = 0; i < last; i++) { acc += day.hours[i].tokens || 0; out.push(acc / 1e6) }
    return out
  }
  function tokens(m) { return m >= 1000 ? (m / 1000).toFixed(1) + " G" : m >= 10 ? Math.round(m) + " M" : m.toFixed(1) + " M" }

  HPanel {
    id: ghost
    pal: row.pal
    width: row.pw; height: 176
    label: "Ghost race"
    tip: "Two races since the start of the day: time in focus sessions, and agent tokens. Your bar runs towards the checkered line, the record day's total; the ghost is the record day at this same hour, the diamond yesterday at this hour (their figures under the track). Beside your figure: how far ahead (▲) or behind (▼) the ghost. Pace: where today ends if the rest brings what the record's day did from this hour; ★ record! once past the line. Click: Stats tab."
    tipAbove: true
    note: "vs record"
    tab: "stats"

    readonly property real nowFrac: row.prom.timeline ? Math.min(1, (Date.now() - row.prom.timeline.fromMs) / (18 * 3600000)) : 0
    readonly property var today: row.cumulative(row.prom.timeline, 72, nowFrac)
    readonly property var best: row.cumulative(row.prom.bestDay, 72)
    readonly property var yest: row.cumulative(row.prom.yesterday, 72, nowFrac)
    readonly property real topV: Math.max(4, best.length ? best[best.length - 1] : 0, today.length ? today[today.length - 1] : 0) * 1.15

    readonly property var tToday: row.tokenRun(row.prom.coffeeDay, true)
    readonly property var tBest: row.tokenRun(row.prom.hoursBest, false)
    readonly property var tYest: row.tokenRun(row.prom.hoursYesterday, true)
    readonly property real tTop: Math.max(1, Math.max.apply(null, tToday.concat(tBest, tYest, [0]))) * 1.15

    function at(a, i) { return a.length ? a[Math.max(0, Math.min(a.length - 1, i))] : 0 }
    GhostLane {
      width: parent.width
      pal: row.pal
      label: "FOCUS"
      nowV: ghost.at(ghost.today, ghost.today.length - 1)
      ghostV: ghost.at(ghost.best, ghost.today.length - 1)
      yestV: ghost.at(ghost.yest, ghost.today.length - 1)
      finishV: ghost.at(ghost.best, ghost.best.length - 1)
      format: function(v) { return row.hm(v * 3600) }
      animate: row.prom.active
    }
    GhostLane {
      y: 70; width: parent.width
      pal: row.pal
      label: "AGENTS"
      nowV: ghost.at(ghost.tToday, ghost.tToday.length - 1)
      ghostV: ghost.at(ghost.tBest, ghost.tToday.length - 1)
      yestV: ghost.at(ghost.tYest, ghost.tYest.length - 1)
      finishV: ghost.at(ghost.tBest, ghost.tBest.length - 1)
      format: function(v) { return row.tokens(v) }
      animate: row.prom.active
    }
  }

  // ------------------------------------------------------- focus quality
  // How focused the day is (share in session, window switches), and what
  // the day was spent on, hour by hour, stacked by app.
  HPanel {
    id: quality
    pal: row.pal
    x: row.px(1); width: row.pw; height: 176
    label: "Focus quality"
    tip: "Top: share of today's tracked computer time spent in a focus session, and window switches per hour. Bars: today's activity hour by hour, stacked by app (the top four, then the rest); click a legend entry to hide an app; peaks = active minutes. Click the panel: Stats tab."
    tipAbove: true
    note: "today"
    tab: "stats"

    readonly property var ins: row.prom.insights ? row.prom.insights.today : null
    readonly property real share: ins && ins.trackedSeconds > 0 ? ins.focusSeconds / ins.trackedSeconds : 0
    readonly property var sw: row.prom.summary && row.prom.summary.switchesPerHour !== null && row.prom.summary.switchesPerHour !== undefined
      ? row.prom.summary.switchesPerHour : (row.prom.extra ? row.prom.extra.focus.switchesPerHour : null)

    readonly property var tl: row.prom.timeline
    // Seconds per app in each hour since the day start.
    readonly property var perHour: {
      var out = []
      if (!tl || !tl.segments) return out
      var from = tl.fromMs
      var n = Math.min(24, Math.floor((Date.now() - from) / 3600000) + 1)
      for (var h = 0; h < n; h++) out.push({})
      for (var i = 0; i < tl.segments.length; i++) {
        var g = tl.segments[i]
        var a = g.start, b = g.end
        while (a < b) {
          var k = Math.floor((a - from) / 3600000)
          var cut = Math.min(b, from + (k + 1) * 3600000)
          if (k >= 0 && k < n) out[k][g.app] = (out[k][g.app] || 0) + (cut - a) / 1000
          a = cut
        }
      }
      return out
    }
    readonly property var topApps: {
      var tot = {}
      for (var h = 0; h < perHour.length; h++) for (var k in perHour[h]) tot[k] = (tot[k] || 0) + perHour[h][k]
      var l = Object.keys(tot)
      l.sort(function(a, b) { return tot[b] - tot[a] })
      return l.slice(0, 4)
    }
    readonly property var groups: topApps.map(function(a, i) { return { key: a, name: a, color: row.pal.series(i) } })
      .concat([{ key: "~other", name: "other", color: row.pal.alpha(row.pal.fg, 0.3) }])
    function groupSecs(hour, key) {
      if (key !== "~other") return hour[key] || 0
      var s = 0
      for (var k in hour) if (topApps.indexOf(k) < 0) s += hour[k]
      return s
    }
    readonly property var totals: perHour.map(function(hr) {
      var s = 0
      for (var i = 0; i < quality.groups.length; i++) if (actLegend.on(quality.groups[i].key)) s += quality.groupSecs(hr, quality.groups[i].key)
      return s
    })

    Row {
      width: parent.width
      spacing: 6
      HText { id: shareText; text: Math.round(quality.share * 100); color: row.pal.fg; font.pixelSize: 20; font.weight: Font.DemiBold }
      HText {
        width: parent.width - shareText.width - 6
        anchors.bottom: parent.bottom; anchors.bottomMargin: 3
        text: "% in session · " + (quality.sw !== null ? Math.round(quality.sw) : "–") + " switches/h"
        color: row.pal.mut; font.pixelSize: 9
      }
    }
    Legend {
      id: actLegend
      y: 30
      pal: row.pal
      width: parent.width
      spacing: 6
      size: 9
      items: quality.groups.map(function(g) { return { key: g.key, name: g.name.length > 12 ? g.name.slice(0, 11) + "…" : g.name, color: g.color } })
    }
    Item {
      id: act
      anchors.bottom: parent.bottom
      // Below the legend (one or two lines), with room for the peak labels.
      width: parent.width; height: parent.height - (actLegend.y + actLegend.height + 4)
      readonly property real bw: width / 24
      Rectangle { anchors.bottom: parent.bottom; anchors.bottomMargin: 8; width: parent.width; height: 1; color: row.pal.alpha(row.pal.fg, 0.1) }
      Repeater {
        model: quality.perHour
        Item {
          id: hr
          required property var modelData
          required property int index
          x: index * act.bw + 0.5; width: act.bw - 1; height: act.height - 8
          Column {
            anchors.bottom: parent.bottom
            width: parent.width
            Repeater {
              model: quality.groups.slice().reverse()
              Rectangle {
                required property var modelData
                width: hr.width
                height: actLegend.on(modelData.key) ? (hr.height - 12) * quality.groupSecs(hr.modelData, modelData.key) / 3600 : 0
                color: modelData.color
              }
            }
          }
        }
      }
      Spark {
        // 12 px kept free over the bars for the peak labels.
        y: 12; width: parent.width * quality.perHour.length / 24; height: parent.height - 8 - 12
        labelTop: -12
        centered: true; fill: false; lineWidth: 0
        values: quality.totals; max: 3600; color: row.pal.fg
        format: function(v) { return Math.round(v / 60) + "m" }
      }
      Repeater {
        model: [0, 6, 12, 18]
        HText {
          required property var modelData
          x: modelData * act.bw
          anchors.bottom: parent.bottom; anchors.bottomMargin: -2
          text: {
            var d = new Date((quality.tl ? quality.tl.fromMs : 0) + modelData * 3600000)
            return d.getHours() + "h"
          }
          color: row.pal.mut; font.pixelSize: 9
        }
      }
    }
  }

  // ------------------------------------------------------------ caffeine
  HPanel {
    id: coffee
    pal: row.pal
    x: row.px(2); width: row.pw; height: 176
    label: "Caffeine"
    tip: "Caffeine estimated in your body (mg) and whether you can have another cup: GO (now is good), WAIT hh:mm (caffeine still high: from then), NO MORE (it will not fall in time), STOP (past the cutoff, 8 h before your bedtime), OVER (a cup after the cutoff: by how much), LIMIT (400 mg a day). Under it: the cutoff and the time left before it. On the curve, the red zone is after the cutoff. Curve: today, dashed = forecast, vertical line = best time, dotted = the 'another cup is worth it' level. Bottom: agent tokens, focus and tasks on days with coffee against days without (over the days compared), and the tokens that come with each cup. Hover: have a coffee now, or log one drunk earlier (type its time, HH:mm)."
    tipAbove: true
    tab: "stats"
    readonly property var cd: row.prom.coffeeDay
    readonly property var now: row.p && row.p.coffee ? row.p.coffee : (cd ? cd.coffee : null)
    note: now ? now.cupsToday + (now.cupsToday === 1 ? " cup" : " cups") : ""

    // The verdict: can I have another cup? Prometheus' rule: none in the
    // 8 hours before bed (the cutoff), caffeine back under the "worth it"
    // level first, 400 mg a day at most.
    property real clockNow: Date.now()
    Timer { interval: 30000; repeat: true; running: coffee.visible; onTriggered: coffee.clockNow = Date.now() }
    readonly property real bedMs: {
      if (!cd || !now) return 0
      var b = new Date(cd.fromMs); b.setHours(now.bedtimeHour || 0, 0, 0, 0)
      var ms = b.getTime()
      return ms > cd.fromMs ? ms : ms + 86400000
    }
    readonly property real cutoffMs: bedMs ? bedMs - 8 * 3600000 : 0
    readonly property real lastAt: now && now.lastAt ? now.lastAt : 0
    readonly property var verdict: {
      if (!now || !cutoffMs) return null
      var t = clockNow, left = cutoffMs - t
      var cut = "cutoff " + row.clock(cutoffMs)
      function span(ms) { var m = Math.round(ms / 60000); return m >= 60 ? row.hm(ms / 1000) : m + " min" }
      var mg = cd ? cd.mgPerCup || 95 : 95
      if (lastAt > cutoffMs && lastAt >= cd.fromMs)
        return { k: "OVER", c: row.pal.red, d: "last cup " + span(lastAt - cutoffMs) + " past " + row.clock(cutoffMs) }
      if (t >= cutoffMs) return { k: "STOP", c: row.pal.red, d: cut + " passed" }
      if ((now.cupsToday + 1) * mg > (cd ? cd.limitMg || 400 : 400))
        return { k: "LIMIT", c: row.pal.red, d: (cd ? cd.limitMg || 400 : 400) + " mg a day reached" }
      var ideal = now.ideal ? now.ideal.at : null
      if (!ideal) return { k: "NO MORE", c: row.pal.red, d: "won't drop before " + row.clock(cutoffMs) }
      if (ideal <= t + 60000) return { k: "☕ GO", c: row.pal.series(1), d: cut + " · " + span(left) + " left" }
      return { k: "WAIT " + row.clock(ideal), c: row.pal.series(2), d: cut + " · " + span(left) + " left" }
    }

    // Logging a past cup: a time field, open until done or Escape.
    property bool logging: false
    readonly property bool showButtons: coffee.hovered || logging
    function logAt(text) {
      var m = text.trim().match(/^(\d{1,2})(?:[:h.]?(\d{2}))?$/)
      if (!m || +m[1] > 23 || +(m[2] || 0) > 59) { timeField.color = row.pal.red; return }
      var at = new Date()
      at.setHours(+m[1], +(m[2] || 0), 0, 0)
      if (at.getTime() > Date.now()) at.setDate(at.getDate() - 1)
      row.prom.act("coffee:addAt", [at.getTime()])
      logging = false
    }

    Item {
      width: parent.width; height: 28
      Row {
        visible: !coffee.showButtons
        width: parent.width
        spacing: 6
        HText { id: mgText; text: coffee.now ? Math.round(coffee.now.inBody || 0) : "–"; color: row.pal.fg; font.pixelSize: 22; font.weight: Font.DemiBold }
        HText {
          anchors.bottom: parent.bottom; anchors.bottomMargin: 4
          text: "mg"
          color: row.pal.mut; font.pixelSize: 9
        }
      }
      // The verdict, right: a chip (go, wait, no) and the cutoff with the
      // time left before it, or how far past it the last cup was.
      Column {
        visible: !coffee.showButtons && !!coffee.verdict
        anchors.right: parent.right
        spacing: 2
        Rectangle {
          anchors.right: parent.right
          width: verdictText.implicitWidth + 12; height: verdictText.implicitHeight + 3; radius: 2
          color: coffee.verdict ? row.pal.alpha(coffee.verdict.c, 0.16) : "transparent"
          border.color: coffee.verdict ? row.pal.alpha(coffee.verdict.c, 0.7) : "transparent"
          HText {
            id: verdictText
            anchors.centerIn: parent
            text: coffee.verdict ? coffee.verdict.k : ""
            color: coffee.verdict ? coffee.verdict.c : row.pal.fg
            font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1
          }
        }
        HText {
          anchors.right: parent.right
          text: coffee.verdict ? coffee.verdict.d : ""
          color: coffee.verdict && coffee.verdict.k.indexOf("OVER") === 0 ? row.pal.red : row.pal.dim
          font.pixelSize: 9
        }
      }
      Row {
        visible: coffee.showButtons && !coffee.logging
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        HButton { pal: row.pal; text: "☕ now"; size: 7; onClicked: row.prom.act("coffee:add", []) }
        HButton { pal: row.pal; tone: "g"; text: "log earlier"; size: 7; onClicked: { coffee.logging = true; timeField.text = ""; timeField.color = row.pal.fg; timeField.forceActiveFocus() } }
        HButton { pal: row.pal; tone: "g"; text: "↶ undo"; size: 7; visible: !!(coffee.now && coffee.now.canUndo); onClicked: row.prom.act("coffee:undo", []) }
      }
      Row {
        visible: coffee.logging
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        HText { anchors.verticalCenter: parent.verticalCenter; text: "cup at"; color: row.pal.dim; font.pixelSize: 9 }
        Rectangle {
          width: 56; height: 20
          color: row.pal.alpha(row.pal.fg, 0.06)
          border.width: 1; border.color: row.pal.alpha(row.pal.acc, 0.5)
          TextInput {
            id: timeField
            anchors.fill: parent; anchors.margins: 4
            verticalAlignment: TextInput.AlignVCenter
            color: row.pal.fg
            font.family: "monospace"; font.pixelSize: 10
            maximumLength: 5
            HText { visible: !parent.text; text: "HH:mm"; color: row.pal.mut; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
            onAccepted: coffee.logAt(text)
            Keys.onEscapePressed: coffee.logging = false
            onActiveFocusChanged: if (!activeFocus) coffee.logging = false
          }
        }
        HButton { pal: row.pal; text: "log"; size: 8; onClicked: coffee.logAt(timeField.text) }
      }
    }
    HiCanvas {
      id: curve
      y: 32; width: parent.width; height: 40
      pixelScale: row.pixelScale
      property var cdata: coffee.cd
      onCdataChanged: requestPaint()
      property real cut: coffee.cutoffMs
      onCutChanged: requestPaint()
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
        ctx.strokeStyle = row.pal.css(row.pal.series(0)); ctx.lineWidth = 1.5
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
        // After the cutoff (8 h before bed): a red zone up to bedtime, the line.
        if (coffee.cutoffMs) {
          var cx = X(coffee.cutoffMs), bx = Math.min(width, X(coffee.bedMs))
          ctx.fillStyle = row.pal.css(row.pal.alpha(row.pal.red, 0.10)); ctx.fillRect(cx, 0, Math.max(0, bx - cx), height - 10)
          ctx.setLineDash([3, 2]); ctx.strokeStyle = row.pal.css(row.pal.alpha(row.pal.red, 0.8)); ctx.lineWidth = 1
          ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx, height - 10); ctx.stroke(); ctx.setLineDash([])
        }
        var nowX = X(cdata.now)
        ctx.strokeStyle = row.pal.css(row.pal.alpha(row.pal.fg, 0.3)); ctx.beginPath(); ctx.moveTo(nowX, 0); ctx.lineTo(nowX, height - 10); ctx.stroke()
        var ideal = cdata.coffee && cdata.coffee.ideal ? cdata.coffee.ideal.at : null
        if (ideal) { ctx.strokeStyle = row.pal.css(row.pal.series(1)); ctx.beginPath(); ctx.moveTo(X(ideal), 4); ctx.lineTo(X(ideal), height - 10); ctx.stroke() }
        ctx.font = "8px sans-serif"
        var cups = cdata.cups || []
        for (i = 0; i < cups.length; i++) {
          var at = cups[i].at || cups[i]
          ctx.fillStyle = row.pal.css(coffee.cutoffMs && at > coffee.cutoffMs ? row.pal.red : row.pal.dim)
          ctx.fillText("☕", X(at) - 4, height)
        }
      }
    }
    // What coffee does: the average day with a cup against one without,
    // and the tokens that come with each cup.
    Column {
      id: effect
      anchors.bottom: parent.bottom
      width: parent.width
      spacing: 2
      readonly property var st: row.prom.coffeeStats
      readonly property var cmp: st && st.compare ? st.compare : null
      function pct(k) {
        if (!cmp || !cmp[k] || !cmp[k].without) return "–"
        var v = Math.round((cmp[k].with / cmp[k].without - 1) * 100)
        return (v >= 0 ? "+" : "") + v + "%"
      }
      HText { text: "WITH COFFEE · " + (effect.st ? effect.st.daysCompared : "–") + " DAYS"; color: row.pal.mut; font.pixelSize: 9; font.letterSpacing: 1.2 }
      Flow {
        width: parent.width
        spacing: 8
        Repeater {
          model: [
            { k: "tokens", n: "tokens", c: row.pal.series(1) },
            { k: "focus", n: "focus", c: row.pal.series(0) },
            { k: "tasks", n: "tasks", c: row.pal.series(2) }
          ]
          Row {
            required property var modelData
            spacing: 3
            HText { text: effect.pct(modelData.k); color: modelData.c; font.pixelSize: 10; font.weight: Font.DemiBold }
            HText { anchors.bottom: parent.bottom; anchors.bottomMargin: 1; text: modelData.n; color: row.pal.dim; font.pixelSize: 9 }
          }
        }
      }
      HText {
        visible: !!(effect.st && effect.st.tokensPerCup)
        text: effect.st && effect.st.tokensPerCup ? "≈ " + row.tokens(effect.st.tokensPerCup / 1e6) + " tokens per cup" : ""
        color: row.pal.dim; font.pixelSize: 9
      }
    }
  }

  // ------------------------------------------------------------- network
  HPanel {
    pal: row.pal
    x: row.px(3); width: row.pw; height: 176
    label: "Network"
    action: ["omarchy.network", "toggle"]
    actionLabel: "network"
    tip: "Download and upload rate of the active connection over the last 80 s (click a legend entry to hide it; peaks labelled); Wi-Fi network and band; Tailscale relay and peers with ping latency. Click the panel: your network menu."
    tipAbove: true
    note: (row.sys.net.ssid || row.sys.net.iface || "") + (row.sys.net.mhz ? " · " + (row.sys.net.mhz > 5900 ? "6" : row.sys.net.mhz > 4000 ? "5" : "2,4") + " GHz" : "")

    Legend {
      id: netLegend
      pal: row.pal
      width: parent.width
      size: 9
      items: [
        { key: "down", name: "↓", color: row.pal.series(0), value: row.sys.bits(row.sys.net.down) },
        { key: "up", name: "↑", color: row.pal.series(1), value: row.sys.bits(row.sys.net.up) }
      ]
    }
    // The rates fill the room between the legend and Tailscale.
    Item {
      y: 24; width: parent.width; height: tailCol.y - 6 - y
      readonly property real topV: Math.max(50000, Math.max.apply(null,
        (netLegend.on("down") ? row.sys.downHist : []).concat(netLegend.on("up") ? row.sys.upHist : [], [1])) * 1.1)
      Spark { id: netDown; visible: netLegend.on("down"); anchors.fill: parent; values: row.sys.downHist; max: parent.topV; color: row.pal.series(0); peaks: 3; format: function(v) { return row.sys.bits(v) } }
      Spark { visible: netLegend.on("up"); anchors.fill: parent; avoid: netDown.visible ? netDown.callouts : []; values: row.sys.upHist; max: parent.topV; color: row.pal.series(1); peaks: 2; fill: false; lineWidth: 1; format: function(v) { return row.sys.bits(v) } }
    }
    Column {
      id: tailCol
      anchors.bottom: parent.bottom; width: parent.width
      spacing: 2
      HText {
        text: "TAILSCALE " + (row.sys.tail.up ? "· relay " + (row.sys.tail.relay || "–") : "· stopped")
        color: row.pal.mut; font.pixelSize: 9; font.letterSpacing: 1
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
    action: ["austraz.power", "toggle"]
    actionLabel: "battery"
    tip: "Current power draw (W) and charge level; time to empty or full. Graph: charge and draw over the last 24 h, from UPower (click a legend entry to hide it; peaks labelled). Click the panel: your battery menu."
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
      Spark { id: battWatts; visible: battLegend.on("watts"); anchors.fill: parent; values: parent.series(row.sys.batDay.rate, 40); color: row.pal.series(1); peaks: 3; fill: false; lineWidth: 1; format: function(v) { return (v * 40).toFixed(1) + " W" } }
      Spark { visible: battLegend.on("charge"); anchors.fill: parent; avoid: battWatts.visible ? battWatts.callouts : []; values: parent.series(row.sys.batDay.charge, 100); color: row.pal.series(0); peaks: 2; format: function(v) { return Math.round(v * 100) + "%" } }
    }
    Legend {
      id: battLegend
      anchors.bottom: parent.bottom
      pal: row.pal
      width: parent.width
      items: [
        { key: "charge", name: "charge", color: row.pal.series(0) },
        { key: "watts", name: "watts · 24 h", color: row.pal.series(1) }
      ]
    }
  }

  // ------------------------------------------------------- week of focus
  HPanel {
    id: weekPanel
    pal: row.pal
    x: row.weekX; width: row.weekW; height: 176
    label: "Week · focus"
    tip: "This week on one grid, weekday by hour of the day. Pale blocks: the usual, your sessions at that weekday and hour over the last 8 weeks (deeper = more); hours to come show only that. Days still to come this week show last week's same day instead, faded: its totals in italics, its sessions as hollow blocks, its desk time dimmed. Bright blocks rising with the minutes: this week's time in session; the line underneath: time at the desk. Right: each day's totals (at desk, in session). Today's row is lit, the vertical line is now. Header: the week in session and its share of the desk time. Click a legend entry to hide it; click the panel: Stats tab."
    tipAbove: true
    tab: "stats"
    readonly property var days: row.prom.week ? row.prom.week.days || [] : []
    readonly property real focusTotal: days.reduce(function(a, d) { return a + (d.focusSeconds || 0) }, 0)
    readonly property real deskTotal: days.reduce(function(a, d) { return a + (d.trackedSeconds || 0) }, 0)
    // The week so far: in session, and its share of the time at the desk.
    note: Math.floor(focusTotal / 3600) + " h " + String(Math.floor(focusTotal % 3600 / 60)).padStart(2, "0")
      + (deskTotal > 0 ? " · " + Math.round(focusTotal / deskTotal * 100) + " % of desk" : "")
    readonly property int nowDay: new Date().getDay()
    readonly property int nowHour: new Date().getHours()


    readonly property var heat: row.prom.extra && row.prom.extra.heatmap ? row.prom.extra.heatmap.minutes : []
    readonly property real heatMax: {
      var m = 1
      for (var r = 0; r < heat.length; r++) for (var c = 0; c < heat[r].length; c++) m = Math.max(m, heat[r][c])
      return m
    }
    readonly property real span: Math.max(3600, days.reduce(function(a, d) { return Math.max(a, d.trackedSeconds || 0) }, 0))

    function hm2(s) {
      var h = Math.floor((s || 0) / 3600), m = Math.floor((s || 0) % 3600 / 60)
      return h > 0 ? h + "h" + String(m).padStart(2, "0") : m + "m"
    }
    // One grid, weekday x hour of the day. Pale: the usual (the last 8
    // weeks' sessions at that weekday and hour); over it, this week as it
    // went: the time in session (a block rising with the minutes) and at the
    // desk (a line underneath). Hours to come only show the usual: what the
    // day tends to hold. Right: the day's totals.
    Legend {
      id: weekLegend
      pal: weekPanel.pal
      width: parent.width
      spacing: 10
      size: 9
      items: [
        { key: "focus", name: "in session", color: row.pal.series(0) },
        { key: "tracked", name: "at desk", color: row.pal.series(3) },
        { key: "usual", name: "usual (8 weeks)", color: row.pal.alpha(row.pal.series(0), 0.35) }
      ]
    }
    Item {
      id: grid
      y: 18
      width: parent.width; height: parent.height - 18 - 11
      readonly property real rowH: height / 7
      readonly property real figW: 62
      readonly property real cellsX: 14
      readonly property real cellW: (width - cellsX - figW - 4) / 24
      readonly property real nowX: cellsX + (weekPanel.nowHour + new Date().getMinutes() / 60) * cellW

      // Today's row, lit.
      Rectangle {
        y: weekPanel.nowDay * grid.rowH; width: parent.width; height: grid.rowH
        radius: 2
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0; color: row.pal.alpha(row.pal.acc, 0.14) }
          GradientStop { position: 1; color: row.pal.alpha(row.pal.acc, 0.05) }
        }
      }

      Repeater {
        model: weekPanel.days
        Item {
          id: dayRow
          required property var modelData
          required property int index
          readonly property int wd: new Date(modelData.date + "T12:00:00").getDay()
          readonly property bool today: modelData.date === (row.prom.p ? row.prom.p.todayDate : "")
          // A day still to come shows last week's same day, faded.
          readonly property var lw: modelData.future ? row.prom.lastWeekFor(modelData) : null
          readonly property var shownDay: lw || modelData
          readonly property var hours: today ? row.prom.todayHours : row.prom.weekHours[shownDay.date] || null
          readonly property var usual: weekPanel.heat[wd] || []
          y: wd * grid.rowH; width: grid.width; height: grid.rowH

          HText {
            x: 2; width: 10; anchors.verticalCenter: parent.verticalCenter
            text: "SMTWTFS".charAt(dayRow.wd)
            color: dayRow.today ? row.pal.acc : row.pal.mut
            font.pixelSize: 9; font.weight: dayRow.today ? Font.Bold : Font.Normal
          }
          Repeater {
            model: 24
            Item {
              id: cell
              required property int index
              readonly property real u: dayRow.usual[index] || 0
              readonly property real f: dayRow.hours ? dayRow.hours.f[index] : 0
              readonly property real d: dayRow.hours ? dayRow.hours.d[index] : 0
              readonly property bool past: !dayRow.modelData.future && (!dayRow.today || index <= weekPanel.nowHour)
              readonly property bool lastWeek: !!dayRow.lw
              x: grid.cellsX + index * grid.cellW; width: grid.cellW; height: grid.rowH
              // The usual, pale (a dot when nothing usually happens).
              Rectangle {
                visible: cell.u > 0 && weekLegend.on("usual")
                anchors.fill: parent; anchors.margins: 1
                radius: 1.5
                color: row.pal.series(0)
                opacity: 0.06 + 0.30 * cell.u / weekPanel.heatMax
              }
              Rectangle {
                visible: cell.u === 0 || !weekLegend.on("usual")
                anchors.centerIn: parent
                width: 2; height: 2; radius: 1
                color: row.pal.alpha(row.pal.fg, 0.12)
              }
              // This week: in session, rising with the minutes.
              Rectangle {
                visible: (cell.past || cell.lastWeek) && cell.f >= 1 && weekLegend.on("focus")
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                x: 1; width: parent.width - 2
                height: Math.max(2, (parent.height - 4) * Math.min(1, cell.f / 60))
                radius: 1.5
                // Last week's: hollow.
                color: cell.lastWeek ? "transparent" : row.pal.series(0)
                border.width: cell.lastWeek ? 1 : 0
                border.color: row.pal.alpha(row.pal.series(0), 0.6)
              }
              // At the desk: a line underneath, brighter with the minutes.
              Rectangle {
                visible: (cell.past || cell.lastWeek) && cell.d >= 1 && weekLegend.on("tracked")
                anchors.bottom: parent.bottom
                x: 0.5; width: parent.width - 1; height: 1.5
                color: row.pal.series(3)
                opacity: (cell.lastWeek ? 0.35 : 1) * (0.3 + 0.7 * Math.min(1, cell.d / 60))
              }
            }
          }
          // The day's totals: at the desk, in session.
          // (A day to come: last week's, faded and in italics.)
          Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            visible: !dayRow.modelData.future || !!dayRow.lw
            opacity: dayRow.lw ? 0.5 : 1
            HText {
              width: 32; horizontalAlignment: Text.AlignRight
              visible: weekLegend.on("tracked")
              text: weekPanel.hm2(dayRow.shownDay.trackedSeconds)
              color: row.pal.alpha(row.pal.series(3), 0.8); font.pixelSize: 9
              font.italic: !!dayRow.lw
            }
            HText {
              width: 30; horizontalAlignment: Text.AlignRight
              visible: weekLegend.on("focus")
              text: (dayRow.shownDay.focusSeconds || 0) >= 60 ? weekPanel.hm2(dayRow.shownDay.focusSeconds) : "–"
              color: (dayRow.shownDay.focusSeconds || 0) >= 60 ? row.pal.series(0) : row.pal.mut
              font.pixelSize: 9; font.weight: Font.DemiBold
              font.italic: !!dayRow.lw
            }
          }
        }
      }
      // Now: a thin line down the current hour.
      Rectangle {
        x: grid.nowX; y: -2; width: 1; height: parent.height + 4
        color: row.pal.acc; opacity: 0.7
      }
    }
    // Hours under the grid.
    Repeater {
      model: [0, 6, 12, 18]
      HText {
        required property var modelData
        x: grid.cellsX + modelData * grid.cellW
        anchors.bottom: parent.bottom; anchors.bottomMargin: -2
        text: modelData + "h"; color: row.pal.mut; font.pixelSize: 9
      }
    }
  }
}
