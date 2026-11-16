import QtQuick
import QtQuick.Shapes
import Quickshell

// Left column: league race, season, leaderboards, quests and achievements.
Item {
  id: col

  required property var pal
  required property var prom
  required property var sys
  readonly property var p: prom.p

  width: 330
  height: 712


  function fmtH(sec) {
    var s = Math.max(0, Math.round(sec || 0))
    var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
    return h > 0 ? h + " h " + String(m).padStart(2, "0") : m + " min"
  }
  function rarityColor(r) {
    return r === "legendary" ? pal.series(2) : r === "epic" ? pal.series(4) : r === "rare" ? pal.series(3) : pal.dim
  }

  // ------------------------------------------------------------- status
  BarIcons {
    pal: col.pal
    sys: col.sys
    width: col.width; height: 106
    tip: "The Omarchy bar's widgets, the bar itself being hidden: clock, weather, world clocks, volume, network, Bluetooth, Tailscale, NordVPN, battery, agents, Prometheus, screens, CamGuard, Flux, keyboard layout, then the system tray. Click a cell to open that widget's panel, beside this widget; tray icons: click, middle click, right click for their menu."
  }


  // ------------------------------------------------------------- league
  HPanel {
    id: leaguePanel
    pal: col.pal
    y: 116; width: col.width; height: 186
    label: "League"
    tip: "Weekly league race against 9 historical rivals. Axis: XP this week; dots = the other players in their zone's colour, the white marker = you; the promotion and safety lines are the XP needed to move up or stay. At week end the top ranks move up a league, the bottom ones down. Bars: your XP per day by source (click a legend entry to hide it). Hover the rival for their bio. Click the panel: Leagues tab."
    note: col.prom.league ? col.prom.league.daysLeft + " days left" : ""
    tab: "leagues"

    readonly property var lg: col.prom.league
    readonly property var players: lg && lg.players ? lg.players : []
    readonly property int myRank: lg ? lg.rank : 0
    readonly property var rival: {
      if (!players.length || !myRank) return null
      var want = myRank > 1 ? myRank - 1 : 2
      for (var i = 0; i < players.length; i++) if (players[i].rank === want) return players[i]
      return null
    }

    readonly property real promoXp: lg ? lg.xp + Math.max(0, lg.toPromotion || 0) : 0
    readonly property real safeXp: lg && lg.zone === "relegation" ? lg.xp + Math.max(0, lg.toSafety || 0) : 0
    function zoneColor(z) { return z === "promotion" ? col.pal.series(1) : z === "relegation" ? col.pal.series(4) : col.pal.dim }

    // Header: the gem, the league, where you stand and who to beat.
    Row {
      spacing: 12
      z: rivalArea.containsMouse ? 20 : 0
      Shape {
        width: 40; height: 44
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: -1
          fillGradient: LinearGradient {
            x1: 0; y1: 0; x2: 40; y2: 44
            GradientStop { position: 0; color: Qt.lighter(leaguePanel.lg ? leaguePanel.lg.color : col.pal.cyan, 1.6) }
            GradientStop { position: 0.5; color: leaguePanel.lg ? leaguePanel.lg.color : col.pal.cyan }
            GradientStop { position: 1; color: Qt.darker(leaguePanel.lg ? leaguePanel.lg.color : col.pal.cyan, 2) }
          }
          startX: 20; startY: 1
          PathLine { x: 38; y: 12 } PathLine { x: 38; y: 32 } PathLine { x: 20; y: 43 }
          PathLine { x: 2; y: 32 } PathLine { x: 2; y: 12 } PathLine { x: 20; y: 1 }
        }
        ShapePath {
          strokeWidth: -1
          fillColor: Qt.rgba(1, 1, 1, 0.25)
          startX: 20; startY: 1
          PathLine { x: 38; y: 12 } PathLine { x: 20; y: 22 } PathLine { x: 2; y: 12 } PathLine { x: 20; y: 1 }
        }
      }
      Column {
        spacing: 2
        anchors.verticalCenter: parent.verticalCenter
        Row {
          spacing: 8
          HText {
            text: leaguePanel.lg ? leaguePanel.lg.name.toUpperCase() : "—"
            color: leaguePanel.lg ? Qt.lighter(leaguePanel.lg.color, 1.3) : col.pal.dim
            font.pixelSize: 20; font.weight: Font.DemiBold; font.letterSpacing: 1
          }
          HText {
            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
            text: leaguePanel.lg ? (leaguePanel.lg.league + 1) + " / " + col.prom.leagues.length : ""
            color: col.pal.mut; font.pixelSize: 9
          }
        }
        Row {
          spacing: 10
          HText {
            text: leaguePanel.lg ? "rank " + leaguePanel.myRank + " / " + leaguePanel.players.length : ""
            color: leaguePanel.lg ? leaguePanel.zoneColor(leaguePanel.lg.zone) : col.pal.dim
            font.pixelSize: 9
          }
          Item {
            width: rivalText.implicitWidth; height: rivalText.implicitHeight
            HText {
              id: rivalText
              text: leaguePanel.rival ? (leaguePanel.myRank > 1 ? "rival · " : "chaser · ") + leaguePanel.rival.name : ""
              color: col.pal.fg; font.pixelSize: 9
            }
            Rectangle { anchors.top: rivalText.bottom; width: rivalText.width; height: 1; color: col.pal.alpha(col.pal.fg, 0.3) }
            MouseArea {
              id: rivalArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: col.prom.act("ui:event", ["bio"])
            }
            // The bio card, on hover.
            Rectangle {
              visible: rivalArea.containsMouse && leaguePanel.rival !== null
              z: 10
              y: rivalText.height + 6
              x: -120
              width: 290; height: bioCol.implicitHeight + 16
              color: col.pal.alpha(col.pal.bg, 0.96)
              border.color: col.pal.alpha(col.pal.fg, 0.3)
              Column {
                id: bioCol
                x: 10; y: 8; width: 270; spacing: 3
                HText {
                  width: parent.width
                  text: leaguePanel.rival ? leaguePanel.rival.name + " · " + (leaguePanel.rival.bio ? leaguePanel.rival.bio.life : "") : ""
                  color: col.pal.fg
                }
                HText {
                  width: parent.width; wrapMode: Text.WordWrap; elide: Text.ElideNone
                  text: leaguePanel.rival && leaguePanel.rival.bio ? leaguePanel.rival.bio.line : ""
                  color: col.pal.dim
                }
                HText { text: "click: read the bio"; color: col.pal.mut; font.pixelSize: 9 }
              }
            }
          }
        }
      }
    }

    // The week's race on an XP axis: the relegation and promotion lines,
    // every player as a dot in their zone's colour, you as the tall marker.
    Item {
      id: race
      y: 54; width: parent.width; height: 30
      readonly property real maxXp: {
        var m = Math.max(1, leaguePanel.promoXp)
        for (var i = 0; i < leaguePanel.players.length; i++) m = Math.max(m, leaguePanel.players[i].xp)
        return m * 1.06
      }
      function xAt(xp) { return width * xp / maxXp }
      readonly property real axisY: 18
      Rectangle { y: race.axisY; width: parent.width; height: 2; color: col.pal.alpha(col.pal.fg, 0.08) }
      // Zones: under the safety line, past the promotion line.
      Rectangle {
        visible: leaguePanel.safeXp > 0
        y: race.axisY; width: race.xAt(leaguePanel.safeXp); height: 2
        color: col.pal.alpha(col.pal.series(4), 0.6)
      }
      Rectangle {
        visible: leaguePanel.promoXp > 0
        x: race.xAt(leaguePanel.promoXp); y: race.axisY; width: race.width - x; height: 2
        color: col.pal.alpha(col.pal.series(1), 0.6)
      }
      Repeater {
        model: [
          { xp: leaguePanel.safeXp, t: "safe", c: col.pal.series(4) },
          { xp: leaguePanel.promoXp, t: "promotion", c: col.pal.series(1) }
        ]
        Item {
          required property var modelData
          visible: modelData.xp > 0
          x: race.xAt(modelData.xp)
          Rectangle { y: race.axisY - 5; width: 1; height: 12; color: modelData.c }
          HText {
            x: -width / 2; y: race.axisY + 6
            text: modelData.t; color: modelData.c; font.pixelSize: 7
          }
        }
      }
      Repeater {
        model: leaguePanel.players
        Item {
          required property var modelData
          x: race.xAt(modelData.xp)
          visible: !modelData.you
          Rectangle {
            x: -3; y: race.axisY - 2
            width: 6; height: 6; radius: 3
            color: leaguePanel.zoneColor(parent.modelData.zone)
            opacity: 0.85
          }
        }
      }
      // You.
      Item {
        visible: !!leaguePanel.lg
        x: race.xAt(leaguePanel.lg ? leaguePanel.lg.xp : 0)
        Rectangle { x: -1; y: 4; width: 2; height: race.axisY; color: col.pal.fg }
        Rectangle { x: -4; y: race.axisY - 3; width: 8; height: 8; radius: 4; color: col.pal.fg }
        HText {
          x: Math.max(-race.xAt(leaguePanel.lg ? leaguePanel.lg.xp : 0), -width / 2); y: -8
          text: "you " + (leaguePanel.lg ? leaguePanel.lg.xp : 0) + " XP"
          color: col.pal.fg; font.pixelSize: 8; font.weight: Font.DemiBold
        }
      }
    }
    HText {
      y: 90; width: parent.width
      text: !leaguePanel.lg ? "" : leaguePanel.lg.toPromotion > 0
        ? "+" + leaguePanel.lg.toPromotion + " XP to promotion" + (leaguePanel.lg.zone === "relegation" && leaguePanel.lg.toSafety > 0 ? " · +" + leaguePanel.lg.toSafety + " to be safe" : "")
        : "in the promotion zone"
      color: leaguePanel.lg && leaguePanel.lg.zone === "relegation" ? col.pal.series(4) : col.pal.dim
      font.pixelSize: 9
    }

    // XP of the week by source, a stacked bar a day.
    readonly property var sources: [
      { key: "focus", name: "focus", color: col.pal.series(0), v: function(d) { return d.focus || 0 } },
      { key: "tasks", name: "tasks", color: col.pal.series(1), v: function(d) { return d.tasks || 0 } },
      { key: "quests", name: "quests", color: col.pal.series(2), v: function(d) { return (d.quests || 0) + (d.challenges || 0) } },
      { key: "awards", name: "awards", color: col.pal.series(3), v: function(d) { return (d.medals || 0) + (d.achievements || 0) } },
      { key: "agents", name: "agents", color: col.pal.series(4), v: function(d) { return d.agents || 0 } }
    ]
    readonly property var xpDays: col.prom.extra ? col.prom.extra.xpSources : []
    function dayTotal(d) {
      var t = 0
      for (var i = 0; i < sources.length; i++) if (xpLegend.on(sources[i].key)) t += sources[i].v(d)
      return t
    }
    readonly property var totals: xpDays.map(function(d) { return leaguePanel.dayTotal(d) })
    readonly property real maxDay: Math.max(1, Math.max.apply(null, totals.concat([0])) * 1.25)
    Legend {
      id: xpLegend
      y: 106
      pal: col.pal
      width: parent.width
      spacing: 8
      items: leaguePanel.sources.map(function(s) { return { key: s.key, name: s.name, color: s.color } })
    }
    Item {
      id: xpBars
      anchors.bottom: parent.bottom
      width: parent.width; height: 24
      readonly property real slot: width / Math.max(1, leaguePanel.xpDays.length)
      Repeater {
        model: leaguePanel.xpDays
        Item {
          id: xday
          required property var modelData
          required property int index
          x: index * xpBars.slot; width: xpBars.slot; height: xpBars.height
          Rectangle { x: 3; anchors.bottom: parent.bottom; anchors.bottomMargin: 9; width: parent.width - 6; height: 1; color: col.pal.alpha(col.pal.fg, 0.1) }
          Column {
            x: 3; width: parent.width - 6
            anchors.bottom: parent.bottom; anchors.bottomMargin: 9
            Repeater {
              model: leaguePanel.sources.slice().reverse()
              Rectangle {
                required property var modelData
                width: xday.width - 6
                height: xpLegend.on(modelData.key) ? (xday.height - 9) * modelData.v(xday.modelData) / leaguePanel.maxDay : 0
                color: modelData.color
              }
            }
          }
          HText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: -2
            text: "SMTWTFS".charAt(new Date(xday.modelData.date + "T12:00:00").getDay())
            color: xday.modelData.date === (col.p ? col.p.todayDate : "") ? col.pal.fg : col.pal.mut
            font.pixelSize: 7
          }
        }
      }
      Spark {
        width: parent.width; height: parent.height - 9
        centered: true; fill: false; lineWidth: 0
        values: leaguePanel.totals; max: leaguePanel.maxDay; color: col.pal.fg
        format: function(v) { return Math.round(v) }
      }
    }
  }

  // ------------------------------------------------------------- season
  HPanel {
    id: seasonPanel
    pal: col.pal
    y: 312; width: col.width; height: 104
    readonly property var s: col.prom.season
    label: s ? "Season " + s.number + " · " + s.label : "Season"
    note: s ? Math.max(0, Math.ceil((new Date(s.end + "T23:59:59") - Date.now()) / 86400000)) + " days left" : ""
    tab: "seasons"
    tip: "The current season (a calendar quarter). Bar: season XP against its two goals, set from last season's XP; each goal reached adds a bar to the season medal. The A–F grade is given when the season ends. Click: Seasons tab."

    Row {
      spacing: 14
      // The season medal: ribbon and disc, bars for the goals reached.
      Item {
        width: 50; height: 60
        scale: 0.8; transformOrigin: Item.TopLeft
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath { strokeWidth: -1; fillColor: col.pal.mag; startX: 18; startY: 0
            PathLine { x: 26; y: 26 } PathLine { x: 31; y: 26 } PathLine { x: 22; y: 0 } }
          ShapePath { strokeWidth: -1; fillColor: col.pal.cyan; startX: 44; startY: 0
            PathLine { x: 36; y: 26 } PathLine { x: 31; y: 26 } PathLine { x: 40; y: 0 } }
        }
        Rectangle {
          x: 7; y: 22; width: 48; height: 48; radius: 24
          color: col.pal.alpha(col.pal.acc, 0.2)
          border.color: col.pal.acc; border.width: 2
          Column {
            anchors.centerIn: parent; spacing: 4
            Repeater {
              model: 2
              Rectangle {
                required property int index
                width: 22; height: 3
                color: col.pal.acc2
                opacity: seasonPanel.s && seasonPanel.s.bars > index ? 1 : 0.2
              }
            }
          }
        }
      }
      Column {
        width: seasonPanel.width - 2 * seasonPanel.pad - 54
        spacing: 6
        Row {
          width: parent.width
          HText { width: parent.width - gradeText.width; text: seasonPanel.s ? (seasonPanel.s.grade ? "GRADE" : "RUNNING · " + col.fmtH((seasonPanel.s.hours || 0) * 3600)) : ""; color: col.pal.mut; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
          HText {
            id: gradeText
            text: seasonPanel.s ? (seasonPanel.s.grade || (seasonPanel.s.bars >= 2 ? "A" : seasonPanel.s.bars >= 1 ? "B" : "—")) : "—"
            color: col.pal.acc2; font.pixelSize: 30; font.weight: Font.Bold
          }
        }
        HBar {
          pal: col.pal
          width: parent.width; height: 6
          readonly property real topV: seasonPanel.s ? Math.max(1, seasonPanel.s.hardGoal || seasonPanel.s.goal || 1) : 1
          value: seasonPanel.s ? seasonPanel.s.xp / topV : 0
          marks: seasonPanel.s ? [
            { at: Math.min(1, seasonPanel.s.goal / topV), color: "white" },
            { at: Math.min(1, (seasonPanel.s.hardGoal || seasonPanel.s.goal) / topV), color: col.pal.alpha(col.pal.fg, 0.5) }
          ] : []
        }
        HText {
          text: seasonPanel.s ? seasonPanel.s.xp + " / " + seasonPanel.s.goal + " XP (1 bar) · " + seasonPanel.s.hardGoal + " (2)" : ""
          color: col.pal.dim; font.pixelSize: 9
        }
      }
    }
  }

  // -------------------------------------------------------- leaderboards
  HPanel {
    id: boardsPanel
    pal: col.pal
    y: 426; width: col.width; height: 106
    label: "Leaderboards"
    tip: "Your current score against your all-time best on each board (cyan tick = the record). Bottom: today's rank among all your days. Click: Leaderboards tab."
    note: "now / record"
    tab: "leaderboard"

    readonly property var rows: [
      { key: "days", name: "Best day" },
      { key: "weeks", name: "Best week" },
      { key: "sessions", name: "Best session" },
      { key: "quests", name: "Best quest" }
    ]
    Column {
      width: parent.width
      spacing: 5
      Repeater {
        model: boardsPanel.rows
        Row {
          id: brow
          required property var modelData
          readonly property var b: col.prom.boards[modelData.key]
          readonly property var best: b && b.entries && b.entries.length ? b.entries[0] : null
          readonly property var you: b ? b.you : null
          readonly property real cur: you && you.current ? you.value : 0
          width: parent.width
          spacing: 8
          HText { width: 118; text: brow.modelData.name; color: col.pal.fg }
          HBar {
            pal: col.pal
            width: parent.width - 118 - 104 - 16; anchors.verticalCenter: parent.verticalCenter
            value: brow.best && brow.best.value > 0 ? brow.cur / brow.best.value : 0
            marks: [{ at: 1, color: col.pal.cyan }]
          }
          HText {
            width: 104; horizontalAlignment: Text.AlignRight
            text: brow.best ? (brow.you && brow.you.current ? brow.cur : "–") + " / " + brow.best.value + " " + (brow.best.unit || "") : "–"
            color: col.pal.dim; font.pixelSize: 9
          }
        }
      }
    }
  }

  // ------------------------------------------------ quests & achievements
  HPanel {
    id: questPanel
    pal: col.pal
    y: 542; width: col.width; height: 170
    label: "Quests · achievements"
    tip: "Open quests (▶ = the active one; hover a row to activate, set aside or complete it). Next achievements: the tiers closest to unlocking, with your progress. Capsules: your latest unlocked achievements, coloured by rarity. Click the panel: Quests tab."
    tipAbove: true
    note: col.prom.questList ? (col.prom.questList.quests || []).length + " open" : ""
    tab: "quests"

    readonly property var open: col.prom.questList ? (col.prom.questList.quests || []).slice().sort(function(a, b) { return (b.active ? 1 : 0) - (a.active ? 1 : 0) }).slice(0, 3) : []
    // The tiers closest to unlocking, one per family.
    readonly property var nextTiers: {
      var a = col.prom.achievements
      if (!a || !a.families) return []
      var out = []
      for (var i = 0; i < a.families.length; i++) {
        var f = a.families[i]
        if (f.secret || f.masked) continue
        for (var j = 0; j < f.tiers.length; j++) {
          var t = f.tiers[j]
          if (t.unlockedAt || !t.threshold) continue
          var pr = f.compare === "le" ? (f.value > 0 ? t.threshold / f.value : 0) : f.value / t.threshold
          if (pr < 1) out.push({ name: t.name, pr: pr, rarity: t.rarity, value: f.value, threshold: t.threshold })
          break
        }
      }
      out.sort(function(x, y) { return y.pr - x.pr })
      return out
    }
    readonly property var latest: {
      var a = col.prom.achievements
      if (!a || !a.families) return []
      var all = []
      a.families.forEach(function(f) {
        f.tiers.forEach(function(t) { if (t.unlockedAt) all.push({ name: t.name, at: t.unlockedAt, rarity: t.rarity }) })
      })
      all.sort(function(x, y) { return y.at - x.at })
      return all.slice(0, 4)
    }
    function short(v) { return v >= 10000 ? Math.round(v / 1000) + "k" : v >= 1000 ? (v / 1000).toFixed(1) + "k" : Math.round(v) }

    Column {
      width: parent.width
      spacing: 5

      // Quests: the open ones, or a way to start one.
      HText { text: "QUESTS"; color: col.pal.mut; font.pixelSize: 7; font.letterSpacing: 1.5 }
      Item {
        visible: questPanel.open.length === 0
        width: parent.width; height: 18
        HText { anchors.verticalCenter: parent.verticalCenter; text: "no open quest"; color: col.pal.dim; font.pixelSize: 9 }
        HButton {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          pal: col.pal; size: 8; text: "+ new quest"
          onClicked: Quickshell.execDetached(["omarchy-shell", "austraz.prometheus", "openTab", "quests"])
        }
      }
      Repeater {
        model: questPanel.open
        Item {
          id: qrow
          required property var modelData
          width: parent.width; height: 18
          HoverHandler { id: qhover }
          Rectangle {
            visible: qrow.modelData.active
            anchors.fill: parent; anchors.leftMargin: -4; anchors.rightMargin: -4
            color: col.pal.alpha(col.pal.series(0), 0.07)
            border.color: col.pal.alpha(col.pal.series(0), 0.35)
          }
          HText {
            x: 2; width: 118; anchors.verticalCenter: parent.verticalCenter
            text: (qrow.modelData.active ? "▶ " : "") + qrow.modelData.title
            color: qrow.modelData.active ? col.pal.fg : col.pal.dim
          }
          HBar {
            visible: !qhover.hovered
            pal: col.pal
            x: 126; width: parent.width - 126 - 36; anchors.verticalCenter: parent.verticalCenter
            color: qrow.modelData.color || col.pal.series(0)
            value: qrow.modelData.activity ? Math.min(1, (qrow.modelData.activity.seconds || 0) / 36000) : 0
          }
          HText {
            visible: !qhover.hovered
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: qrow.modelData.kind === "daily" ? "daily" : (qrow.modelData.daysWorked || 0) + " d"
            color: col.pal.mut; font.pixelSize: 9
          }
          Row {
            visible: qhover.hovered
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            HButton {
              pal: col.pal; tone: qrow.modelData.active ? "g" : "c"; size: 8
              text: qrow.modelData.active ? "set aside" : "activate"
              onClicked: col.prom.act(qrow.modelData.active ? "quests:deactivate" : "quests:activate", [qrow.modelData.id])
            }
            HButton {
              pal: col.pal; size: 8; text: "complete"
              onClicked: col.prom.act("quests:complete", [qrow.modelData.id])
            }
          }
        }
      }

      // Achievements: the tiers closest to unlocking, as many as fit.
      HText { visible: questPanel.open.length < 3; text: "NEXT ACHIEVEMENTS"; color: col.pal.mut; font.pixelSize: 7; font.letterSpacing: 1.5 }
      Repeater {
        // As many as fit above the latest unlocks.
        model: questPanel.nextTiers.slice(0, questPanel.open.length === 0 ? 2 : Math.max(0, 3 - questPanel.open.length))
        Item {
          required property var modelData
          width: parent.width; height: 14
          HText {
            width: 118; anchors.verticalCenter: parent.verticalCenter
            text: modelData.name
            color: col.rarityColor(modelData.rarity); font.pixelSize: 9
          }
          HBar {
            pal: col.pal
            x: 124; width: parent.width - 124 - 70; anchors.verticalCenter: parent.verticalCenter
            color: col.rarityColor(modelData.rarity)
            value: modelData.pr
          }
          HText {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 64; horizontalAlignment: Text.AlignRight
            text: questPanel.short(modelData.value) + " / " + questPanel.short(modelData.threshold)
            color: col.pal.dim; font.pixelSize: 8
          }
        }
      }
    }

    // The latest unlocks, as capsules in their rarity's colour.
    Column {
      anchors.bottom: parent.bottom
      width: parent.width
      spacing: 4
      HText { text: "LATEST UNLOCKED"; color: col.pal.mut; font.pixelSize: 7; font.letterSpacing: 1.5 }
      // One line: the capsules that fit.
      Flow {
        width: parent.width; height: 16
        clip: true
        spacing: 4
        Repeater {
          model: questPanel.latest
          Rectangle {
            required property var modelData
            width: capText.implicitWidth + 14; height: 16; radius: 8
            color: "transparent"
            border.color: col.rarityColor(modelData.rarity)
            HText {
              id: capText
              anchors.centerIn: parent
              text: (parent.modelData.rarity === "legendary" ? "✦ " : parent.modelData.rarity === "epic" ? "★ " : parent.modelData.rarity === "rare" ? "◆ " : "") + parent.modelData.name
              color: col.rarityColor(parent.modelData.rarity); font.pixelSize: 8
            }
          }
        }
      }
    }
  }
}
