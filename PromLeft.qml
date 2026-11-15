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
    return r === "legendary" ? pal.acc2 : r === "epic" ? pal.mag : r === "rare" ? pal.cyan : pal.dim
  }

  // ------------------------------------------------------------- status
  StatusPanel {
    pal: col.pal
    sys: col.sys
    width: col.width; height: 80
    tip: "Time and date; outside temperature and conditions (Omarchy weather); volume (scroll to change, click to mute); Wi-Fi network. Icons: the system tray (click to open, middle click for the secondary action, right click for the menu)."
  }

  // ------------------------------------------------------------- league
  HPanel {
    id: leaguePanel
    pal: col.pal
    y: 90; width: col.width; height: 200
    label: "League"
    tip: "Weekly league race against 9 historical rivals. Dots: each player's XP this week (you in white, cyan = promotion zone, red = relegation zone). At week end the top ranks move up a league, the bottom ones down. Bars: your XP per day this week, stacked by source. Click: Leagues tab."
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

    Row {
      spacing: 12
      z: rivalArea.containsMouse ? 20 : 0
      // The league's gem in its own color.
      Shape {
        width: 54; height: 60
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: -1
          fillGradient: LinearGradient {
            x1: 0; y1: 0; x2: 54; y2: 60
            GradientStop { position: 0; color: Qt.lighter(leaguePanel.lg ? leaguePanel.lg.color : col.pal.cyan, 1.6) }
            GradientStop { position: 0.5; color: leaguePanel.lg ? leaguePanel.lg.color : col.pal.cyan }
            GradientStop { position: 1; color: Qt.darker(leaguePanel.lg ? leaguePanel.lg.color : col.pal.cyan, 2) }
          }
          startX: 27; startY: 2
          PathLine { x: 51; y: 16 } PathLine { x: 51; y: 44 } PathLine { x: 27; y: 58 }
          PathLine { x: 3; y: 44 } PathLine { x: 3; y: 16 } PathLine { x: 27; y: 2 }
        }
        ShapePath {
          strokeWidth: -1
          fillColor: Qt.rgba(1, 1, 1, 0.25)
          startX: 27; startY: 2
          PathLine { x: 51; y: 16 } PathLine { x: 27; y: 30 } PathLine { x: 3; y: 16 } PathLine { x: 27; y: 2 }
        }
      }
      Column {
        spacing: 2
        HText {
          text: leaguePanel.lg ? leaguePanel.lg.name.toUpperCase() : "—"
          color: leaguePanel.lg ? Qt.lighter(leaguePanel.lg.color, 1.3) : col.pal.dim
          font.pixelSize: 22; font.weight: Font.DemiBold; font.letterSpacing: 1
        }
        HText {
          text: leaguePanel.lg ? "league " + (leaguePanel.lg.league + 1) + " / " + col.prom.leagues.length
                + " · rank " + leaguePanel.myRank + " / " + leaguePanel.players.length : ""
          color: col.pal.dim
        }
        Item {
          width: rivalText.implicitWidth; height: rivalText.implicitHeight
          HText {
            id: rivalText
            text: leaguePanel.rival ? (leaguePanel.myRank > 1 ? "rival · " : "chaser · ") + leaguePanel.rival.name : ""
            color: col.pal.fg
          }
          Rectangle { anchors.top: rivalText.bottom; width: rivalText.width; height: 1; color: col.pal.alpha(col.pal.cyan, 0.5) }
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
            width: 290; height: bioCol.implicitHeight + 16
            color: col.pal.alpha(col.pal.bg, 0.96)
            border.color: col.pal.alpha(col.pal.cyan, 0.45)
            Column {
              id: bioCol
              x: 10; y: 8; width: 270; spacing: 3
              HText {
                width: parent.width
                text: leaguePanel.rival ? leaguePanel.rival.name + " · " + (leaguePanel.rival.bio ? leaguePanel.rival.bio.life : "") : ""
                color: col.pal.cyan
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

    // The ten leagues, the current one ringed.
    Row {
      y: 64
      spacing: 0
      Repeater {
        model: col.prom.leagues
        Item {
          required property var modelData
          required property int index
          width: 30; height: 14
          readonly property int cur: leaguePanel.lg ? leaguePanel.lg.league : -1
          Rectangle {
            visible: parent.index < col.prom.leagues.length - 1
            x: 15; y: 6; width: 30; height: 1
            color: parent.index < parent.cur ? col.pal.acc : col.pal.alpha(col.pal.fg, 0.15)
          }
          Rectangle {
            x: 15 - width / 2; y: 7 - height / 2
            width: parent.index === parent.cur ? 11 : 6; height: width; radius: width / 2
            color: parent.index <= parent.cur ? parent.modelData.color : col.pal.alpha(col.pal.fg, 0.12)
            border.width: parent.index === parent.cur ? 1 : 0
            border.color: "white"
          }
        }
      }
    }

    // The week's race: every player on an XP axis, you in white.
    Item {
      id: race
      y: 82; width: parent.width; height: 34
      readonly property real maxXp: {
        var m = 1
        for (var i = 0; i < leaguePanel.players.length; i++) m = Math.max(m, leaguePanel.players[i].xp)
        return m * 1.08
      }
      Rectangle { y: 16; width: parent.width; height: 2; color: col.pal.alpha(col.pal.fg, 0.08) }
      Repeater {
        model: leaguePanel.players
        Item {
          required property var modelData
          x: race.width * modelData.xp / race.maxXp - 4
          y: modelData.you ? 9 : 12
          width: 8; height: 8
          Rectangle {
            anchors.centerIn: parent
            width: parent.modelData.you ? 10 : 6; height: width; radius: width / 2
            color: parent.modelData.you ? "white"
              : parent.modelData.zone === "promotion" ? col.pal.cyan
              : parent.modelData.zone === "relegation" ? col.pal.red : col.pal.dim
            opacity: parent.modelData.you ? 1 : 0.8
          }
        }
      }
      HText {
        y: 24
        text: leaguePanel.lg ? leaguePanel.lg.xp + " XP"
          + (leaguePanel.lg.toPromotion > 0 ? " · promotion at +" + leaguePanel.lg.toPromotion : " · promotion zone")
          + (leaguePanel.lg.zone === "relegation" && leaguePanel.lg.toSafety > 0 ? " · safe at +" + leaguePanel.lg.toSafety : "")
          : ""
        color: leaguePanel.lg && leaguePanel.lg.zone === "relegation" ? col.pal.red : col.pal.dim
        font.pixelSize: 9
      }
    }

    // XP of the week, by source, a stacked bar a day.
    Row {
      y: 122
      spacing: 12
      Repeater {
        model: col.prom.extra ? col.prom.extra.xpSources : []
        Item {
          id: day
          required property var modelData
          width: 30; height: 30
          readonly property var parts: [
            { v: modelData.focus || 0, c: col.pal.acc },
            { v: modelData.tasks || 0, c: col.pal.acc2 },
            { v: (modelData.quests || 0) + (modelData.challenges || 0), c: col.pal.mag },
            { v: (modelData.medals || 0) + (modelData.achievements || 0), c: col.pal.cyan },
            { v: modelData.agents || 0, c: col.pal.blue }
          ]
          readonly property real total: parts.reduce(function(a, x) { return a + x.v }, 0)
          readonly property real maxDay: {
            var src = col.prom.extra ? col.prom.extra.xpSources : []
            var m = 1
            for (var i = 0; i < src.length; i++) {
              var d = src[i]
              m = Math.max(m, (d.focus || 0) + (d.tasks || 0) + (d.quests || 0) + (d.challenges || 0) + (d.medals || 0) + (d.achievements || 0) + (d.agents || 0))
            }
            return m
          }
          Column {
            anchors.bottom: parent.bottom
            Repeater {
              model: day.parts.slice().reverse()
              Rectangle {
                required property var modelData
                width: 30; height: modelData.v / day.maxDay * 24
                color: modelData.c; opacity: 0.85
              }
            }
          }
          HText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: -11
            text: "SMTWTFS".charAt(new Date(day.modelData.date + "T12:00:00").getDay())
            color: col.pal.mut; font.pixelSize: 8
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- season
  HPanel {
    id: seasonPanel
    pal: col.pal
    y: 300; width: col.width; height: 110
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
    y: 420; width: col.width; height: 112
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
    tip: "Open quests (▶ = the active one; hover a row to activate, set aside or complete it). Next tier: the achievement closest to unlocking. Capsules: your latest unlocked achievements, coloured by rarity. Click: Quests tab."
    tipAbove: true
    note: col.prom.questList ? (col.prom.questList.quests || []).length + " open" : ""
    tab: "quests"

    readonly property var open: col.prom.questList ? (col.prom.questList.quests || []).slice().sort(function(a, b) { return (b.active ? 1 : 0) - (a.active ? 1 : 0) }).slice(0, 3) : []

    Column {
      width: parent.width
      spacing: 4
      Repeater {
        model: questPanel.open
        Item {
          id: qrow
          required property var modelData
          width: parent.width; height: 20
          HoverHandler { id: qhover }
          Rectangle {
            visible: qrow.modelData.active
            anchors.fill: parent; anchors.leftMargin: -4; anchors.rightMargin: -4
            color: col.pal.alpha(col.pal.mag, 0.07)
            border.color: col.pal.alpha(col.pal.mag, 0.35)
          }
          HText {
            x: 2; width: 118; anchors.verticalCenter: parent.verticalCenter
            text: (qrow.modelData.active ? "▶ " : "") + qrow.modelData.title
            color: qrow.modelData.active ? col.pal.fg : col.pal.dim
          }
          HBar {
            visible: !qhover.hovered
            pal: col.pal
            x: 126; width: 110; anchors.verticalCenter: parent.verticalCenter
            color: qrow.modelData.color || col.pal.mag
            value: qrow.modelData.activity ? Math.min(1, (qrow.modelData.activity.seconds || 0) / 36000) : 0
          }
          HText {
            visible: !qhover.hovered
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: qrow.modelData.kind === "daily" ? "daily" : (qrow.modelData.daysWorked || 0) + " d"
            color: qrow.modelData.active ? col.pal.mag : col.pal.mut; font.pixelSize: 9
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
      HText {
        text: "+ new quest"
        color: col.pal.mut; font.pixelSize: 9
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: Quickshell.execDetached(["omarchy-shell", "austraz.prometheus", "openTab", "quests"])
        }
      }

      // The closest tier still to unlock.
      Item {
        width: parent.width; height: 16
        readonly property var next: {
          var a = col.prom.achievements
          if (!a || !a.families) return null
          var best = null
          for (var i = 0; i < a.families.length; i++) {
            var f = a.families[i]
            if (f.secret || f.masked) continue
            for (var j = 0; j < f.tiers.length; j++) {
              var t = f.tiers[j]
              if (t.unlockedAt || !t.threshold) continue
              var pr = f.compare === "le" ? (f.value > 0 ? t.threshold / f.value : 0) : f.value / t.threshold
              if (pr < 1 && (!best || pr > best.pr)) best = { name: t.name, pr: pr, value: f.value, threshold: t.threshold }
              break
            }
          }
          return best
        }
        HText { width: 110; text: "Next tier"; color: col.pal.dim; anchors.verticalCenter: parent.verticalCenter }
        HBar {
          pal: col.pal; x: 116; width: 80; anchors.verticalCenter: parent.verticalCenter
          color: col.pal.acc2; value: parent.next ? parent.next.pr : 0
        }
        HText {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 204; horizontalAlignment: Text.AlignRight
          text: parent.next ? parent.next.name : ""
          color: col.pal.mut; font.pixelSize: 9
        }
      }

      // The latest unlocks, as capsules in their rarity's color.
      Flow {
        width: parent.width
        spacing: 4
        Repeater {
          model: {
            var a = col.prom.achievements
            if (!a || !a.families) return []
            var all = []
            a.families.forEach(function(f) {
              f.tiers.forEach(function(t) { if (t.unlockedAt) all.push({ name: t.name, at: t.unlockedAt, rarity: t.rarity }) })
            })
            all.sort(function(x, y) { return y.at - x.at })
            return all.slice(0, 3)
          }
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
