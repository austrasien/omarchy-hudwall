import QtQuick
import Quickshell
import qs.Commons

// The middle of the HUD, around the globe: XP and medal rack on top, toasts
// and the hours goal in the upper corners, today's apps and insights in the
// lower ones, questions over the globe, the session underneath.
Item {
  id: center

  required property var pal
  required property var prom
  required property var sys
  property bool active: false
  property bool animate: active
  property var cfg: ({})
  property real pixelScale: 1
  property bool wantsKeyboard: false

  readonly property var p: prom.p
  readonly property bool live: prom.live

  width: 560
  height: 728

  // Geometry: a compact header, the session at the bottom, and the globe
  // with its rings as big as the space between allows.
  readonly property real headerH: header.height + 6
  readonly property real sessionY: height - sessionBlock.height - 2
  readonly property real areaTop: headerH + 4
  readonly property real areaH: sessionY - 4 - areaTop
  readonly property real gs: Math.max(0.6, Math.min(areaH, width - 10) / 540)
  readonly property real gx: width / 2
  readonly property real gy: areaTop + areaH / 2

  function hm(sec) {
    var s = Math.max(0, Math.round(sec || 0))
    var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60)
    return h > 0 ? h + " h " + String(m).padStart(2, "0") : m + " min"
  }

  // Apps of today, the biggest first, each with a color of the theme.
  readonly property var apps: {
    var tl = prom.timeline
    if (!tl || !tl.segments) return []
    var tot = {}
    for (var i = 0; i < tl.segments.length; i++) {
      var s = tl.segments[i]
      tot[s.app] = (tot[s.app] || 0) + (s.end - s.start) / 1000
    }
    var list = Object.keys(tot).map(function(k) { return { app: k, seconds: tot[k] } })
    list.sort(function(a, b) { return b.seconds - a.seconds })
    return list
  }
  readonly property var palette: [pal.acc, pal.blue, pal.mag, pal.cyan, pal.acc2, pal.red]
  readonly property var appColors: {
    var out = {}
    for (var i = 0; i < apps.length && i < palette.length; i++) out[apps[i].app] = palette[i]
    return out
  }

  // ------------------------------------------------------------ header
  Column {
    id: header
    // Above the rings and globe, so the medals' legends show over them.
    z: 5
    x: 0; width: center.width; y: 0
    spacing: 6
    HText {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: Qt.locale("en_GB").toString(new Date(), "dddd d MMMM yyyy").toUpperCase()
        + (center.prom.geekDate ? "  ·  " + center.prom.geekDate[1].toUpperCase() : "")
      color: center.pal.dim; font.pixelSize: 9; font.letterSpacing: 3
    }
    HText {
      visible: !!center.prom.geekDate
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: center.prom.geekDate ? center.prom.geekDate[2] + " « " + center.prom.geekDate[3] + " »" : ""
      color: center.pal.cyan; font.pixelSize: 9
    }
      Column {
        id: xpBlock
        width: parent.width
        spacing: 4
        readonly property var pr: center.p ? center.p.profile : null
        HText {
          text: (center.p && center.p.handle ? "@" + center.p.handle + " · " : "") + "LVL " + (xpBlock.pr ? xpBlock.pr.level : "–")
          color: center.pal.acc
        }
        HBar {
          pal: center.pal
          width: parent.width
          value: xpBlock.pr && xpBlock.pr.levelCost ? xpBlock.pr.levelXp / xpBlock.pr.levelCost : 0
        }
        Row {
          spacing: 8
          HText {
            text: xpBlock.pr ? xpBlock.pr.levelXp + " / " + xpBlock.pr.levelCost + " XP" : ""
            color: center.pal.dim; font.pixelSize: 9
          }
          HText {
            text: "⚙"
            color: gearArea.containsMouse ? center.pal.acc : center.pal.dim
            font.pixelSize: 11
            MouseArea {
              id: gearArea
              anchors.fill: parent; anchors.margins: -4
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Quickshell.execDetached(["omarchy-shell", "austraz.prometheus", "openTab", "settings"])
            }
          }
        }
      }
      MedalRack {
        width: parent.width
        pal: center.pal
        medals: center.p ? center.p.medals : []
        seasonMedals: center.p ? center.p.seasonMedals : []
      }
  }

  // ------------------------------------------------------------ rings & globe
  Rings {
    id: rings
    pal: center.pal
    x: center.gx - 270; y: center.gy - 270
    width: 540; height: 540
    scale: center.gs
    pixelScale: center.pixelScale * center.gs
    year: center.prom.year
    timeline: center.prom.timeline
    appColors: center.appColors
    session: center.p ? center.p.session : null
    Timer { interval: 60000; repeat: true; running: center.active; onTriggered: rings.minute++ }
  }
  Globe {
    pal: center.pal
    x: center.gx - 210; y: center.gy - 210
    width: 420; height: 420
    scale: center.gs
    active: center.animate
    fps: center.cfg.fps || 24
    home: center.cfg.home || [2.35, 48.85]
    // The last peers, plus the places named in the config ({ name: [lon, lat] }),
    // lit when Tailscale sees that host online.
    peers: {
      var out = (center.sys.peers.list || []).slice()
      var places = center.cfg.places || {}
      var tail = center.sys.tail.peers || []
      Object.keys(places).forEach(function(name) {
        var ll = places[name]
        if (!Array.isArray(ll) || ll.length !== 2) return
        var t = tail.filter(function(x) { return x.name === name })[0]
        out.push({ lon: ll[0], lat: ll[1], city: name, proc: "", live: !t || t.online, own: true })
      })
      return out
    }
  }
  HText {
    visible: !center.sys.peers.geo
    x: center.gx - width / 2; y: center.gy + 150 * center.gs
    text: "no GeoIP database · bin/hudwall-fetch-data"
    color: center.pal.mut; font.pixelSize: 8
  }

  // ------------------------------------------------------------ toasts
  Column {
    x: 0; y: center.areaTop + 6; width: 200
    spacing: 5
    Repeater {
      model: toastModel
      Rectangle {
        required property string title
        required property string text
        required property string kind
        required property string rarity
        width: 200; height: toastText.implicitHeight + 10
        color: center.pal.alpha(center.pal.bg, 0.6)
        readonly property color tint: rarity === "legendary" ? center.pal.acc2 : rarity === "epic" ? center.pal.mag : rarity === "rare" ? center.pal.cyan : center.pal.acc
        Rectangle { width: 2; height: parent.height; color: parent.tint }
        HText {
          id: toastText
          x: 8; y: 5; width: 188
          wrapMode: Text.WordWrap; elide: Text.ElideNone; maximumLineCount: 3
          text: parent.title + (parent.text ? " · " + parent.text : "")
          color: center.pal.fg; font.pixelSize: 9
        }
      }
    }
  }
  ListModel { id: toastModel }
  Connections {
    target: center.prom
    function onToast(kind, title, text, rarity) {
      toastModel.insert(0, { kind: kind || "", title: title || "", text: text || "", rarity: rarity || "", at: Date.now() })
      while (toastModel.count > 4) toastModel.remove(toastModel.count - 1)
    }
  }
  // Toasts wait while the desk is covered, then stay 12 s once seen.
  onActiveChanged: if (active) for (var i = 0; i < toastModel.count; i++) toastModel.setProperty(i, "at", Date.now())
  Timer {
    interval: 1000; repeat: true; running: toastModel.count > 0 && center.active
    onTriggered: {
      for (var i = toastModel.count - 1; i >= 0; i--)
        if (Date.now() - toastModel.get(i).at > 12000) toastModel.remove(i)
    }
  }

  // ------------------------------------------------------------ hours goal
  Column {
    visible: center.prom.goal !== null
    x: center.width - 150; y: center.areaTop + 6; width: 150
    spacing: 3
    readonly property var g: center.prom.goal
    readonly property real worked: g && g.progress ? (g.progress.workedSeconds || 0) + (center.p ? center.p.elapsed : 0) : 0
    readonly property real target: g && g.goal ? g.goal.hours * 3600 : 0
    HText {
      width: parent.width; horizontalAlignment: Text.AlignRight
      text: "GOAL · " + (parent.g && parent.g.goal ? ({ day: "DAY", week: "WEEK", month: "MONTH" })[parent.g.goal.period] || "" : "")
      color: center.pal.acc; font.pixelSize: 8; font.letterSpacing: 2
    }
    HText {
      width: parent.width; horizontalAlignment: Text.AlignRight
      text: center.hm(parent.worked) + " / " + center.hm(parent.target)
      color: center.pal.fg; font.pixelSize: 12
    }
    HBar { pal: center.pal; width: parent.width; height: 3; color: center.pal.cyan; value: parent.target > 0 ? parent.worked / parent.target : 0 }
  }

  // ------------------------------------------------------------ apps today
  Column {
    x: 0; y: center.sessionY - 100; width: 140
    spacing: 2
    HText { text: "TODAY BY APP"; color: center.pal.acc; font.pixelSize: 8; font.letterSpacing: 2 }
    Repeater {
      model: center.apps.slice(0, 5)
      Row {
        required property var modelData
        spacing: 4
        HText { text: "■"; color: center.appColors[modelData.app] || center.pal.mut; font.pixelSize: 9 }
        HText { width: 82; text: modelData.app; color: center.pal.dim; font.pixelSize: 9 }
        HText { width: 44; horizontalAlignment: Text.AlignRight; text: center.hm(modelData.seconds).replace(" min", "m"); color: center.pal.fg; font.pixelSize: 9 }
      }
    }
  }

  // ------------------------------------------------------------ insights
  Column {
    x: center.width - 170; y: center.sessionY - 100; width: 170
    spacing: 2
    readonly property var ins: center.prom.insights
    function delta() {
      if (!ins) return "–"
      var d = (ins.today.focusSeconds || 0) - (ins.yesterdaySameTime.focusSeconds || 0)
      var t = (ins.today.trackedSeconds || 0) - (ins.yesterdaySameTime.trackedSeconds || 0)
      var v = d !== 0 ? d : t
      return (v >= 0 ? "+" : "−") + center.hm(Math.abs(v)) + (d !== 0 ? " focus" : " tracked")
    }
    HText { width: parent.width; horizontalAlignment: Text.AlignRight; text: "INSIGHTS"; color: center.pal.acc; font.pixelSize: 8; font.letterSpacing: 2 }
    HText { width: parent.width; horizontalAlignment: Text.AlignRight; text: "vs yesterday same time " + parent.delta(); color: center.pal.dim; font.pixelSize: 9 }
    HText { width: parent.width; horizontalAlignment: Text.AlignRight; text: parent.ins && parent.ins.topApp ? "top app " + parent.ins.topApp.app : ""; color: center.pal.dim; font.pixelSize: 9 }
    HText {
      width: parent.width; horizontalAlignment: Text.AlignRight
      text: parent.ins && parent.ins.busiestDay ? "busiest day " + Qt.locale("en_GB").toString(new Date(parent.ins.busiestDay.date + "T12:00:00"), "ddd d MMM") : ""
      color: center.pal.dim; font.pixelSize: 9
    }
  }
  MouseArea {
    x: center.width - 170; y: center.sessionY - 100; width: 170; height: 52
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["omarchy-shell", "austraz.prometheus", "openTab", "stats"])
  }


  // ------------------------------------------------------------ tooltips
  // Invisible hover zones over the pieces that are not panels.
  Item {
    x: 0; y: xpBlock.y; width: center.width; height: xpBlock.height
    HoverTip {
      pal: center.pal; raiseTarget: center
      tipWidth: 360
      text: "Your Prometheus level and the XP still needed for the next one. XP comes from focus (1 per 10 min), tasks, quests, challenges, medals, achievements and agent tokens. ⚙ opens Prometheus settings."
    }
  }
  Item {
    x: center.gx - 250 * center.gs; y: center.gy - 250 * center.gs; width: 500 * center.gs; height: 500 * center.gs
    HoverTip {
      pal: center.pal; raiseTarget: center
      tipWidth: 300; tipX: parent.width / 2 - 150; tipY: parent.height * 0.62
      text: "Globe: the Earth lit by the real sun, turning once a minute. Arcs: the last 10 public servers this computer opened a connection to (orange = still connected), labelled app · city; white ring = home. Inner ring: today's 24 hours, coloured by the app in use. Outer ring: this year, one tick per day, brighter with more focus."
    }
  }
  Item {
    x: 0; y: center.sessionY - 100; width: 140; height: 100
    HoverTip {
      pal: center.pal; raiseTarget: center; above: true; tipWidth: 260
      text: "Time spent in each app today, as tracked by Prometheus. The colours match the 24-hour ring."
    }
  }
  Item {
    x: center.width - 170; y: center.sessionY - 100; width: 170; height: 52
    HoverTip {
      pal: center.pal; raiseTarget: center; above: true; tipWidth: 260; tipX: -90
      text: "Today against yesterday at the same hour (focus, or tracked time if no focus yet), your most used app today, and your busiest day. Click: Stats tab."
    }
  }
  Item {
    visible: center.prom.goal !== null
    x: center.width - 150; y: center.areaTop + 6; width: 150; height: 40
    HoverTip {
      pal: center.pal; raiseTarget: center; tipWidth: 240; tipX: -90
      text: "Your focus-hours goal for the day, week or month (set in Prometheus settings) and the time done so far."
    }
  }

  // ------------------------------------------------------------ question card
  Item {
    id: ask
    x: center.gx - 160; y: center.gy + 42 * center.gs; width: 320; height: 70
    readonly property var q: {
      var p = center.p
      if (!p) return null
      if (p.presence) return { k: "PRESENCE", q: "Still there?", b: [{ t: "yes", tone: "c", ch: "presence:confirm", a: [] }] }
      if (p.challenge && p.challenge.state === "offered")
        return { k: "EXTENSION CHALLENGE " + p.challenge.index + "/" + p.challenge.max, q: "+" + p.challenge.minutes + " min · +" + p.challenge.xp + " XP",
                 b: [{ t: "accept", tone: "c", ch: "challenge:accept", a: [p.challenge.id] }, { t: "decline", tone: "g", ch: "challenge:decline", a: [p.challenge.id] }] }
      if (p.breakNudge) return { k: "PAUSE", q: (p.breakNudge.workedMinutes ? p.breakNudge.workedMinutes + " min without a break. " : "") + "Take a break?",
                                 b: [{ t: "pause", tone: "c", ch: "break:take", a: [] }, { t: "later", tone: "g", ch: "break:later", a: [] }] }
      if (p.coffeeNudge) return { k: "COFFEE", q: "Good time for a coffee?",
                                  b: [{ t: "yes", tone: "c", ch: "coffee:nudgeOk", a: [] }, { t: "no", tone: "g", ch: "coffee:nudgeNo", a: [] }] }
      return null
    }
    Rectangle {
      visible: ask.q !== null
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(320, qcol.implicitWidth + 28); height: qcol.implicitHeight + 18
      color: center.pal.alpha(center.pal.bg, 0.85)
      border.color: center.pal.alpha(center.pal.cyan, 0.45 + 0.25 * glow.v)
      QtObject { id: glow; property real v: 0 }
      SequentialAnimation {
        running: parent.visible && center.active; loops: Animation.Infinite
        NumberAnimation { target: glow; property: "v"; to: 1; duration: 1200; easing.type: Easing.InOutSine }
        NumberAnimation { target: glow; property: "v"; to: 0; duration: 1200; easing.type: Easing.InOutSine }
      }
      Column {
        id: qcol
        anchors.centerIn: parent
        spacing: 6
        HText { anchors.horizontalCenter: parent.horizontalCenter; text: ask.q ? ask.q.k : ""; color: center.pal.cyan; font.pixelSize: 8; font.letterSpacing: 2 }
        HText { anchors.horizontalCenter: parent.horizontalCenter; text: ask.q ? ask.q.q : ""; color: center.pal.fg }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 8
          Repeater {
            model: ask.q ? ask.q.b : []
            HButton {
              required property var modelData
              pal: center.pal; text: modelData.t; tone: modelData.tone
              onClicked: center.prom.act(modelData.ch, modelData.a)
            }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ session
  SessionBlock {
    id: sessionBlock
    x: center.gx - 200; y: center.sessionY; width: 400
    pal: center.pal
    prom: center.prom
    onWantsKeyboardChanged: center.wantsKeyboard = wantsKeyboard
  }
}
