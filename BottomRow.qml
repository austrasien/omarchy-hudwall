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
    tip: "Two races since the start of the day: time in focus sessions, and agent tokens. Today against the record (best focus day; for tokens, the recent day with the most) and yesterday at the same time. Click a legend entry to hide a curve; peaks labelled. Click the panel: Stats tab."
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

    Legend {
      id: ghostLegend
      pal: row.pal
      width: parent.width
      items: [
        { key: "today", name: "today", color: row.pal.series(0) },
        { key: "best", name: "record", color: row.pal.series(1) },
        { key: "yest", name: "yesterday", color: row.pal.series(2) }
      ]
    }
    // Focus.
    HText { y: 16; text: "FOCUS · " + row.hm((ghost.today.length ? ghost.today[ghost.today.length - 1] : 0) * 3600); color: row.pal.mut; font.pixelSize: 9; font.letterSpacing: 1.2 }
    Item {
      y: 28; width: parent.width; height: 40
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: row.pal.alpha(row.pal.fg, 0.08) }
      Spark {
        visible: ghostLegend.on("best")
        anchors.fill: parent; fill: false
        id: gBest; values: ghost.best; max: ghost.topV; color: row.pal.series(1); lineWidth: 1; peaks: 1
        format: function(v) { return row.hm(v * 3600) }
      }
      Spark {
        visible: ghostLegend.on("yest")
        width: parent.width * (ghost.yest.length - 1) / 72; height: parent.height; fill: false
        id: gYest; avoid: gBest.visible ? gBest.callouts : []; values: ghost.yest; max: ghost.topV; color: row.pal.series(2); lineWidth: 1; peaks: 1
        format: function(v) { return row.hm(v * 3600) }
      }
      Spark {
        visible: ghostLegend.on("today")
        width: parent.width * Math.max(1, ghost.today.length - 1) / 72; height: parent.height
        avoid: (gBest.visible ? gBest.callouts : []).concat(gYest.visible ? gYest.callouts : []); values: ghost.today; max: ghost.topV; color: row.pal.series(0); lineWidth: 1.6; peaks: 3
        format: function(v) { return row.hm(v * 3600) }
      }
    }
    // Agents.
    HText { y: 76; text: "AGENTS · " + row.tokens(ghost.tToday.length ? ghost.tToday[ghost.tToday.length - 1] : 0) + " tokens"; color: row.pal.mut; font.pixelSize: 9; font.letterSpacing: 1.2 }
    Item {
      y: 88; width: parent.width; height: parent.height - 88
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: row.pal.alpha(row.pal.fg, 0.08) }
      Spark {
        visible: ghostLegend.on("best")
        anchors.fill: parent; fill: false
        id: tokBest; values: ghost.tBest; max: ghost.tTop; color: row.pal.series(1); lineWidth: 1; peaks: 1
        format: function(v) { return row.tokens(v) }
      }
      Spark {
        visible: ghostLegend.on("yest")
        width: parent.width * Math.max(1, ghost.tYest.length - 1) / 24; height: parent.height; fill: false
        id: tokYest; avoid: tokBest.visible ? tokBest.callouts : []; values: ghost.tYest; max: ghost.tTop; color: row.pal.series(2); lineWidth: 1; peaks: 1
        format: function(v) { return row.tokens(v) }
      }
      Spark {
        visible: ghostLegend.on("today")
        width: parent.width * Math.max(1, ghost.tToday.length - 1) / 24; height: parent.height
        avoid: (tokBest.visible ? tokBest.callouts : []).concat(tokYest.visible ? tokYest.callouts : []); values: ghost.tToday; max: ghost.tTop; color: row.pal.series(0); lineWidth: 1.6; peaks: 3
        format: function(v) { return row.tokens(v) }
      }
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
    tip: "Caffeine estimated in your body (mg) and the best time for the next cup. Curve: today, dashed = forecast, vertical line = best time, dotted = the 'another cup is worth it' level. Bottom: agent tokens, focus and tasks on days with coffee against days without (over the days compared), and the tokens that come with each cup. Hover: have a coffee now, or log one drunk earlier (type its time, HH:mm)."
    tipAbove: true
    tab: "stats"
    readonly property var cd: row.prom.coffeeDay
    readonly property var now: row.p && row.p.coffee ? row.p.coffee : (cd ? cd.coffee : null)
    note: now ? now.cupsToday + (now.cupsToday === 1 ? " cup" : " cups") : ""

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
          width: parent.width - mgText.width - 6
          text: "mg · " + (coffee.now && coffee.now.ideal && coffee.now.ideal.at ? "next best at " + row.clock(coffee.now.ideal.at) : (coffee.now && coffee.now.ideal ? coffee.now.ideal.reason : ""))
          color: row.pal.mut; font.pixelSize: 9
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
        var nowX = X(cdata.now)
        ctx.strokeStyle = row.pal.css(row.pal.alpha(row.pal.fg, 0.3)); ctx.beginPath(); ctx.moveTo(nowX, 0); ctx.lineTo(nowX, height - 10); ctx.stroke()
        var ideal = cdata.coffee && cdata.coffee.ideal ? cdata.coffee.ideal.at : null
        if (ideal) { ctx.strokeStyle = row.pal.css(row.pal.series(1)); ctx.beginPath(); ctx.moveTo(X(ideal), 4); ctx.lineTo(X(ideal), height - 10); ctx.stroke() }
        ctx.fillStyle = row.pal.css(row.pal.dim); ctx.font = "8px sans-serif"
        var cups = cdata.cups || []
        for (i = 0; i < cups.length; i++) ctx.fillText("☕", X(cups[i].at || cups[i]) - 4, height)
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
    tip: "Left, this week day by day: time at the desk (tracked activity) and time in focus sessions, as bars and figures in the legend's colours. Right, on the same weekday rows: time in focus sessions by hour of the day, added up over the last 8 weeks (darker = more; scale bottom right). Click a legend entry to hide it; click the panel: Stats tab."
    tipAbove: true
    tab: "stats"
    readonly property var days: row.prom.week ? row.prom.week.days || [] : []
    readonly property real focusTotal: days.reduce(function(a, d) { return a + (d.focusSeconds || 0) }, 0)
    note: Math.floor(focusTotal / 3600) + " h " + String(Math.floor(focusTotal % 3600 / 60)).padStart(2, "0")

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
    // Left: this week; right: the last weeks, each with its own heading.
    Legend {
      id: weekLegend
      pal: weekPanel.pal
      width: grid.leftW
      spacing: 6
      size: 9
      items: [
        { key: "tracked", name: "at desk", color: row.pal.series(3) },
        { key: "focus", name: "in session", color: row.pal.series(0) }
      ]
    }
    HText {
      x: grid.gridX
      text: "8 WEEKS"
      color: row.pal.mut; font.pixelSize: 9; font.letterSpacing: 1
    }
    // Seven rows shared by the days (left) and the weekday x hour grid of
    // the last weeks (right), so both read along the same line.
    Item {
      id: grid
      y: 16
      width: parent.width; height: parent.height - 16 - 10
      readonly property real rowH: height / 7
      readonly property real leftW: 138
      readonly property real gridX: leftW + 10
      readonly property real cellW: (width - gridX) / 24

      Repeater {
        model: weekPanel.days
        Item {
          id: dayRow
          required property var modelData
          required property int index
          readonly property bool today: modelData.date === (row.prom.p ? row.prom.p.todayDate : "")
          y: index * grid.rowH; width: grid.leftW; height: grid.rowH
          HText {
            width: 10; anchors.verticalCenter: parent.verticalCenter
            text: "SMTWTFS".charAt(new Date(dayRow.modelData.date + "T12:00:00").getDay())
            color: dayRow.today ? row.pal.fg : row.pal.mut
            font.pixelSize: 9; font.weight: dayRow.today ? Font.DemiBold : Font.Normal
          }
          Item {
            x: 12; width: parent.width - 12 - 56; height: Math.max(3, grid.rowH - 5)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors.fill: parent; color: row.pal.alpha(row.pal.fg, 0.04) }
            Rectangle {
              visible: weekLegend.on("tracked")
              width: parent.width * Math.min(1, (dayRow.modelData.trackedSeconds || 0) / weekPanel.span); height: parent.height
              color: row.pal.alpha(row.pal.series(3), 0.55)
            }
            Rectangle {
              visible: weekLegend.on("focus")
              width: parent.width * Math.min(1, (dayRow.modelData.focusSeconds || 0) / weekPanel.span); height: parent.height * 0.55
              anchors.verticalCenter: parent.verticalCenter
              color: row.pal.series(0)
            }
          }
          // The two figures, in their legend's colours: at the desk, in session.
          Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            visible: !dayRow.modelData.future
            HText {
              width: 28; horizontalAlignment: Text.AlignRight
              visible: weekLegend.on("tracked")
              text: weekPanel.hm2(dayRow.modelData.trackedSeconds)
              color: row.pal.series(3); font.pixelSize: 9
            }
            HText {
              width: 26; horizontalAlignment: Text.AlignRight
              visible: weekLegend.on("focus")
              text: weekPanel.hm2(dayRow.modelData.focusSeconds)
              color: row.pal.series(0); font.pixelSize: 9
            }
          }
        }
      }
      // Focus by weekday x hour, last weeks.
      Repeater {
        model: weekPanel.heat.length * 24
        Rectangle {
          required property int index
          readonly property int r: Math.floor(index / 24)
          readonly property int c: index % 24
          readonly property real v: weekPanel.heat[r] ? weekPanel.heat[r][c] || 0 : 0
          x: grid.gridX + c * grid.cellW + 0.5; y: r * grid.rowH + 1
          width: grid.cellW - 1; height: grid.rowH - 2
          color: v > 0 && weekLegend.on("focus") ? row.pal.series(0) : row.pal.alpha(row.pal.fg, 0.04)
          opacity: v > 0 && weekLegend.on("focus") ? 0.2 + 0.8 * v / weekPanel.heatMax : 1
        }
      }
    }
    // The grid's scale, bottom right.
    Row {
      anchors.right: parent.right; y: 1
      spacing: 2
      Repeater {
        model: 5
        Rectangle {
          required property int index
          anchors.verticalCenter: parent.verticalCenter
          width: 6; height: 6
          color: index === 0 ? row.pal.alpha(row.pal.fg, 0.06) : row.pal.series(0)
          opacity: index === 0 ? 1 : 0.2 + 0.2 * index
        }
      }
      HText { text: Math.round(weekPanel.heatMax / 60) + " h"; color: row.pal.mut; font.pixelSize: 9 }
    }
    // Hours under the grid.
    Repeater {
      model: [0, 6, 12, 18]
      HText {
        required property var modelData
        x: grid.gridX + modelData * grid.cellW
        anchors.bottom: parent.bottom; anchors.bottomMargin: -2
        text: modelData + "h"; color: row.pal.mut; font.pixelSize: 9
      }
    }
  }
}
