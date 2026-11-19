import QtQuick
import Quickshell
import qs.Commons

// The services listed under `uptime` in the config (checked by the
// collector), as beacons on the arc over the globe, west to north to east,
// just outside the months. A service that answers is a plain dot in the
// HUD's accent (the panels' titles); amber when slow (or its certificate expires
// within 14 days); red, sending out pings, when it failed twice in a row;
// a hollow grey ring when this machine cannot tell (no Internet, no
// Tailscale), which is not an outage.
//
// Hovering a beacon locks a data card onto it, the way the day tape does
// (the panel wipes open, the brackets close in, a scan line paints it, the
// text types out on a worn tape). A click opens the service (its URL, or
// its `open` command).
Item {
  id: beacons

  required property var pal
  required property var sys
  property bool animate: true
  // The globe's centre and the radius of the arc, in this item's units.
  property real cx: width / 2
  property real cy: height / 2
  property real radius: 260

  readonly property var list: sys.uptime || []
  function dur(ms) { return animate ? ms : 0 }

  // The card's colours, as the day tape's.
  readonly property color hud: pal.acc
  readonly property color bright: Qt.tint(hud, Qt.alpha("#ffffff", 0.45))
  readonly property color dim: Qt.tint(pal.bg, Qt.alpha(hud, 0.45))
  readonly property color hudBlack: Qt.darker(pal.bg, 1.6)

  // From west-south-west to east-south-east over the top, evenly.
  function angleOf(i) {
    var n = list.length
    if (n <= 1) return -Math.PI / 2
    var a0 = 195, a1 = 345
    return (a0 + (a1 - a0) * i / (n - 1)) * Math.PI / 180
  }
  function tint(t) {
    switch (t.state) {
    case "down": return pal.red
    case "slow": return pal.yellow
    case "up": return hud
    default: return pal.mut
    }
  }

  function clock(ts) {
    if (!ts) return "–"
    var d = new Date(ts * 1000), now = new Date()
    var hm = Qt.formatTime(d, "HH:mm")
    return d.toDateString() === now.toDateString() ? hm : Qt.formatDate(d, "d MMM") + " " + hm
  }
  function ago(ts) {
    if (!ts) return "NEVER"
    var s = Math.max(0, Math.round(Date.now() / 1000 - ts))
    return s < 90 ? s + " S AGO" : s < 5400 ? Math.round(s / 60) + " MIN AGO" : Math.round(s / 3600) + " H AGO"
  }
  // Figures over a service's kept checks.
  function stats(hist) {
    var n = hist.length, ok = 0, sum = 0, cnt = 0, max = 0
    for (var i = 0; i < n; i++) {
      var h = hist[i]
      if (h[2] !== "d") ok++
      if (h[1] !== null && h[1] !== undefined) { sum += h[1]; cnt++; max = Math.max(max, h[1]) }
    }
    var lat = hist.filter(function(h) { return h[1] !== null && h[1] !== undefined }).map(function(h) { return h[1] }).sort(function(a, b) { return a - b })
    var p90 = lat.length ? lat[Math.min(lat.length - 1, Math.floor(lat.length * 0.9))] : 0
    return { n: n, up: n ? ok / n * 100 : 0, avg: cnt ? Math.round(sum / cnt) : 0, max: max, p90: p90, low: lat.length ? lat[0] : 0, first: n ? hist[0][0] : 0 }
  }
  readonly property var stateWord: ({ up: "NOMINAL", slow: "CAUTION", down: "DOWN", off: "NO TAILNET", nolink: "NO LINK", wait: "PENDING" })

  // ------------------------------------------------------------ beacons

  property int hoveredIndex: -1
  // For testing: a beacon's card shown as a hover would (-1 closes it).
  property int peek: -1
  onPeekChanged: hoveredIndex = peek

  // By count, not by the list: a new reading (a new list) then updates the
  // beacons in place instead of rebuilding them.
  Repeater {
    model: beacons.list.length
    delegate: Item {
      id: beacon
      required property int index
      readonly property var modelData: beacons.list[index] || ({})
      readonly property real ang: beacons.angleOf(index)
      readonly property color tint: beacons.tint(modelData)
      readonly property bool down: modelData.state === "down"
      readonly property bool grey: ["up", "slow", "down"].indexOf(modelData.state) < 0
      readonly property bool hot: beacons.hoveredIndex === index

      x: beacons.cx + beacons.radius * Math.cos(ang) - width / 2
      y: beacons.cy + beacons.radius * Math.sin(ang) - height / 2
      width: 22; height: 22

      // A service that is down: a ping frozen on its way out, two red rings.
      // Still on purpose: every frame of the HUD costs (a moving ping, even
      // at three steps a second, took a quarter of a core).
      Repeater {
        model: beacon.down ? 2 : 0
        Rectangle {
          required property int index
          anchors.centerIn: parent
          width: 14 + index * 7; height: width; radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: beacons.pal.alpha(beacons.pal.red, index ? 0.35 : 0.7)
        }
      }
      // A faint halo, and a target ring while hovered.
      Rectangle {
        anchors.centerIn: parent
        width: beacon.hot ? 18 : 14; height: width; radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: beacons.pal.alpha(beacon.tint, beacon.hot ? 0.9 : beacon.grey ? 0 : 0.28)
        Behavior on width { NumberAnimation { duration: beacons.dur(140) } }
      }
      Rectangle {
        anchors.centerIn: parent
        width: 8; height: 8; radius: 4
        color: beacon.grey ? "transparent" : beacon.tint
        border.width: beacon.grey ? 1.2 : 0
        border.color: beacon.tint
      }

      HoverHandler {
        cursorShape: beacon.modelData.open ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: {
          if (hovered) beacons.hoveredIndex = beacon.index
          else if (beacons.hoveredIndex === beacon.index) beacons.hoveredIndex = -1
        }
      }
      TapHandler {
        onTapped: {
          var o = beacon.modelData.open
          if (!o) return
          if (/^https?:\/\//.test(o)) Quickshell.execDetached(["xdg-open", o])
          else Quickshell.execDetached(["sh", "-c", o])
        }
      }
    }
  }

  // ------------------------------------------------------------ data card

  Item {
    id: card
    z: 10

    property var svc: null       // kept through the closing animation
    property int index: -1
    property real t: 0
    property real spin: 0
    property real spinFrom: 180
    property int spinMs: 1000
    property real typed: 0
    readonly property bool locked: t >= 0.75
    readonly property real cardW: 236
    readonly property real pad: 4

    // The service as it is now (the list is replaced every check).
    readonly property var live: index >= 0 && index < beacons.list.length ? beacons.list[index] : svc

    readonly property var rows: {
      var s = live
      if (!s) return []
      var out = [["TGT", s.target || ""], ["STATE", (beacons.stateWord[s.state] || s.state) + " SINCE " + beacons.clock(s.since)]]
      if (s.ms !== null && s.ms !== undefined) out.push(["LAT", s.ms + " MS"])
      if (s.code) out.push(["HTTP", String(s.code)])
      if (s.cert !== null && s.cert !== undefined) out.push(["CERT", s.cert + " DAYS"])
      out.push(["CHK", beacons.ago(s.checked)])
      out.push(["SRC", s.via === "remote" ? "WATCHER, ROUND THE CLOCK" : "THIS COMPUTER, WHILE SEEN"])
      if (s.err) out.push(["ERR", String(s.err).toUpperCase()])
      if (s.open) out.push(["OPEN", "CLICK THE BEACON"])
      return out
    }
    // What the card types, in order: the name, the note, then each row.
    readonly property var texts: live ? [String(live.name || ""), String(live.note || "").toUpperCase()].concat(rows.map(function(r) { return r[1] })) : []
    readonly property var plan: {
      var items = [], total = 0
      texts.forEach(function(text) {
        var n = (String(text).match(/\S+/g) || []).length
        items.push({ start: total, count: n })
        total += n
      })
      return { items: items, total: total }
    }
    function typedText(i) {
      var text = texts[i] || "", item = plan.items[i]
      if (!item) return ""
      var left = Math.floor(typed) - item.start, words = /\S+/g, end = 0
      while (left-- > 0 && words.exec(text)) end = words.lastIndex
      var out = text.slice(0, end)
      return i === cursorAt ? out + (cursorOn ? " █" : "") : out
    }
    readonly property int cursorAt: {
      var last = -1
      for (var i = 0; i < plan.items.length; i++) {
        var it = plan.items[i]
        if (!it.count) continue
        last = i
        if (Math.floor(typed) < it.start + it.count) return i
      }
      return last
    }
    property bool cursorOn: true
    Timer {
      interval: 450; repeat: true
      running: card.visible && Math.floor(card.typed) >= card.plan.total && card.t > 0
      onRunningChanged: card.cursorOn = true
      onTriggered: card.cursorOn = !card.cursorOn
    }

    function seg(a, b) {
      var p = Math.max(0, Math.min(1, (t - a) / (b - a)))
      return 1 - Math.pow(1 - p, 3)
    }
    readonly property real spread: (1 - seg(0.3, 0.6)) * 10
    readonly property real bracketOpacity: t < 0.3 ? 0 : (t > 0.62 && t < 0.66) || (t > 0.7 && t < 0.74) ? 0.15 : 1

    Connections {
      target: beacons
      function onHoveredIndexChanged() {
        var i = beacons.hoveredIndex
        if (i >= 0) {
          closing.stop(); opening.stop()
          card.spinFrom = 70 + Math.random() * 220
          card.spinMs = 500 + Math.random() * 700
          card.index = i
          card.svc = beacons.list[i]
          card.t = 0; card.typed = 0
          opening.restart()
        } else if (card.svc) {
          opening.stop()
          closing.restart()
        }
      }
    }
    readonly property int paintMs: 420
    ParallelAnimation {
      id: opening
      NumberAnimation { target: card; property: "spin"; from: 1; to: 0; duration: beacons.dur(card.spinMs) }
      SequentialAnimation {
        PauseAnimation { duration: beacons.dur(200) }
        NumberAnimation { target: card; property: "typed"; from: 0; to: card.plan.total; duration: beacons.dur(Math.min(1200, card.plan.total * 40)) }
      }
      SequentialAnimation {
        NumberAnimation { target: card; property: "t"; to: 0.74; duration: beacons.dur(card.paintMs) }
        PauseAnimation { duration: beacons.dur(Math.max(0, card.spinMs - card.paintMs)) }
        NumberAnimation { target: card; property: "t"; to: 1; duration: beacons.dur(160) }
      }
    }
    SequentialAnimation {
      id: closing
      NumberAnimation { target: card; property: "t"; to: 0; duration: beacons.dur(140) }
      ScriptAction { script: { card.svc = null; card.index = -1 } }
    }

    visible: svc !== null && t > 0
    // Beside its beacon, towards the globe, inside the centre column.
    readonly property real bx: index >= 0 ? beacons.cx + beacons.radius * Math.cos(beacons.angleOf(index)) : 0
    readonly property real by: index >= 0 ? beacons.cy + beacons.radius * Math.sin(beacons.angleOf(index)) : 0
    x: Math.max(0, Math.min(beacons.width - width, bx < beacons.cx ? bx + 18 : bx - 18 - width))
    y: Math.max(0, Math.min(beacons.height - height, by - 14))
    width: cardW
    height: body.implicitHeight + 24

    // The leader from the beacon to the card.
    Rectangle {
      readonly property real fromX: card.bx - card.x
      readonly property real toX: fromX < 0 ? 0 : card.width
      x: Math.min(fromX, toX); y: card.by - card.y
      width: Math.abs(toX - fromX) * card.seg(0, 0.2); height: 1
      color: beacons.bright
      opacity: 0.8
    }

    Item {
      id: wipe
      width: card.width * card.seg(0.1, 0.4)
      height: card.height
      clip: true

      Rectangle {
        width: card.width; height: card.height
        color: beacons.hudBlack
        border.width: 1
        border.color: beacons.dim
      }
      // CRT lines across the panel.
      Image {
        width: card.width; height: card.height
        fillMode: Image.Tile
        verticalAlignment: Image.AlignTop; horizontalAlignment: Image.AlignLeft
        source: "data:image/svg+xml," + encodeURIComponent(
          "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'><rect width='4' height='1' fill='"
          + beacons.hud + "' fill-opacity='0.07'/></svg>")
      }

      // The content, painted down as the scan line passes.
      Item {
        id: painted
        width: card.width
        height: card.height * card.seg(0.35, 0.85)
        clip: true

        Column {
          id: body
          x: 12; y: 12
          width: card.width - 24
          spacing: 5

          Item {
            width: parent.width
            height: tag.implicitHeight
            HText {
              id: tag
              text: "◆ SVC " + String(card.index + 1).padStart(2, "0") + "/" + String(beacons.list.length).padStart(2, "0")
              color: beacons.hud; font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
            }
            HText {
              anchors.right: parent.right
              text: !card.locked ? "ACQUIRING" : card.live ? (beacons.stateWord[card.live.state] || "") : ""
              color: card.locked && card.live ? (card.live.state === "up" ? beacons.bright : beacons.tint(card.live)) : beacons.bright
              opacity: card.locked || Math.floor(card.t * 24) % 2 ? 1 : 0.3
              font.pixelSize: 8; font.bold: true; font.letterSpacing: 1
            }
          }
          ScaleLine {}
          Typed {
            width: parent.width - 40
            order: 0
            font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.5
          }
          Typed {
            visible: (card.texts[1] || "") !== ""
            width: parent.width - 40
            order: 1
            shownColor: beacons.hud
            font.pixelSize: 8
          }
          ScaleLine {}
          Repeater {
            model: card.rows.length
            delegate: Row {
              required property int index
              readonly property var modelData: card.rows[index] || ["", ""]
              width: body.width
              spacing: 6
              HText {
                width: 34
                text: modelData[0]
                color: beacons.dim; font.pixelSize: 8; font.bold: true
              }
              Typed {
                width: body.width - 40
                order: index + 2
                font.pixelSize: 8
                wrapMode: Text.WrapAnywhere
                maximumLineCount: 2
              }
            }
          }

          // ---- the ping history: one bar per check, the latest on the right
          ScaleLine { visible: history.n > 0 }
          Item {
            id: history
            visible: n > 0
            readonly property var hist: card.live && card.live.hist ? card.live.hist : []
            readonly property var st: beacons.stats(hist)
            readonly property int n: hist.length
            width: parent.width
            height: histHead.implicitHeight + 4 + 30 + 4 + histFoot.implicitHeight
            HText {
              id: histHead
              text: "PING · " + history.n + " CHECKS"
              color: beacons.dim; font.pixelSize: 8; font.bold: true
            }
            HText {
              anchors.right: parent.right
              text: "UP " + (history.st.up >= 99.95 ? "100" : history.st.up.toFixed(1)) + " %"
              color: history.st.up >= 99.95 ? beacons.bright : history.st.up >= 95 ? beacons.pal.yellow : beacons.pal.red
              font.pixelSize: 8; font.bold: true
            }
            Item {
              id: chart
              y: histHead.implicitHeight + 4
              width: parent.width; height: 30
              // Room for at least 40 bars, so a few checks stay thin.
              readonly property real step: width / Math.max(40, history.n)
              // From just under the fastest ping to 1.5 x the 90th percentile:
              // the usual jitter shows, and a spike is clipped to the top
              // rather than flattening the rest.
              readonly property real low: history.st.low * 0.8
              readonly property real peak: Math.max(low + 20, history.st.p90 * 1.5)
              Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: beacons.dim; opacity: 0.6 }
              Repeater {
                model: history.n
                delegate: Rectangle {
                  required property int index
                  readonly property var modelData: history.hist[index] || [0, 0, "u"]
                  readonly property bool failed: modelData[2] === "d"
                  x: chart.width - (history.n - index) * chart.step
                  width: Math.max(1, chart.step - 0.6)
                  height: failed ? chart.height : chart.height * (0.12 + 0.88 * Math.max(0, Math.min(1, ((modelData[1] || 0) - chart.low) / (chart.peak - chart.low))))
                  y: chart.height - height
                  color: failed ? beacons.pal.red : modelData[2] === "s" ? beacons.pal.yellow : beacons.hud
                  opacity: failed ? 0.75 : index === history.n - 1 ? 1 : 0.6
                }
              }
            }
            HText {
              id: histFoot
              y: chart.y + chart.height + 4
              text: "AVG " + history.st.avg + " MS · MAX " + history.st.max + " MS"
              color: beacons.hud; font.pixelSize: 8
            }
            HText {
              anchors.right: parent.right
              y: histFoot.y
              text: "SINCE " + beacons.clock(history.st.first)
              color: beacons.dim; font.pixelSize: 8
            }
          }
        }

        // The reticle spins down onto the target and locks.
        Item {
          x: card.width - 12 - width; y: 24
          width: 28; height: 28
          scale: 1 + (1 - card.seg(0.3, 0.75)) * 0.6
          Item {
            anchors.fill: parent
            rotation: card.spin * card.spinFrom
            Rectangle { anchors.fill: parent; anchors.margins: 4; radius: width / 2; color: "transparent"; border.width: 1; border.color: beacons.bright }
            Rectangle { x: parent.width / 2; y: 0; width: 1; height: 8; color: beacons.bright }
            Rectangle { x: parent.width / 2; y: parent.height - 8; width: 1; height: 8; color: beacons.bright }
            Rectangle { x: 0; y: parent.height / 2; width: 8; height: 1; color: beacons.bright }
            Rectangle { x: parent.width - 8; y: parent.height / 2; width: 8; height: 1; color: beacons.bright }
          }
          Rectangle {
            anchors.centerIn: parent
            width: 7; height: 7
            color: card.live ? beacons.pal.alpha(beacons.tint(card.live), 0.9) : "transparent"
            border.width: 1; border.color: beacons.hud
            rotation: 45 - card.spin * card.spinFrom * 0.75
          }
        }
      }

      // Worn tape: dark lines over everything, text included.
      Image {
        width: card.width; height: card.height
        fillMode: Image.Tile
        verticalAlignment: Image.AlignTop; horizontalAlignment: Image.AlignLeft
        source: "data:image/svg+xml," + encodeURIComponent(
          "<svg xmlns='http://www.w3.org/2000/svg' width='3' height='3'><rect width='3' height='1' fill='"
          + beacons.hudBlack + "' fill-opacity='0.6'/></svg>")
      }
      // The scan line and its trail.
      Rectangle {
        visible: card.t > 0.35 && card.t < 0.74
        y: painted.height - height
        width: card.width; height: 22
        gradient: Gradient {
          GradientStop { position: 0; color: Qt.alpha(beacons.hud, 0) }
          GradientStop { position: 1; color: Qt.alpha(beacons.hud, 0.4) }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1.5; color: beacons.bright }
      }
      // The flash of the lock.
      Rectangle {
        width: card.width; height: card.height
        color: beacons.bright
        opacity: card.locked ? (1 - card.seg(0.75, 1)) * 0.3 : 0
      }
    }
    // The bright front edge of the wipe.
    Rectangle {
      visible: card.t > 0.1 && card.t < 0.42
      x: wipe.width - 1; width: 1.5; height: card.height
      color: beacons.bright
    }

    Bracket { x: -card.spread; y: -card.spread; opacity: card.bracketOpacity }
    Bracket { x: card.width - width + card.spread; y: -card.spread; onRight: true; opacity: card.bracketOpacity }
    Bracket { x: -card.spread; y: card.height - height + card.spread; onBottom: true; opacity: card.bracketOpacity }
    Bracket { x: card.width - width + card.spread; y: card.height - height + card.spread; onRight: true; onBottom: true; opacity: card.bracketOpacity }
  }

  component Bracket: Item {
    property bool onRight: false
    property bool onBottom: false
    width: 10; height: 10
    Rectangle { y: parent.onBottom ? parent.height - 1.5 : 0; width: parent.width; height: 1.5; color: beacons.bright }
    Rectangle { x: parent.onRight ? parent.width - 1.5 : 0; width: 1.5; height: parent.height; color: beacons.bright }
  }
  // A graduated line, like the scale of a HUD tape.
  component ScaleLine: Item {
    id: scaleLine
    width: parent.width
    height: 4
    Rectangle { width: parent.width; height: 1; color: beacons.dim }
    Repeater {
      model: 25
      delegate: Rectangle {
        required property int index
        x: index * (scaleLine.width - 1) / 24
        y: 1
        width: 1; height: index % 4 === 0 ? 3 : 1.5
        color: beacons.dim
      }
    }
  }
  // Text typed out word by word; it keeps the whole text's size from the
  // start, so the card does not grow as the words come.
  component Typed: HText {
    id: typedText
    property int order: 0
    property color shownColor: beacons.bright
    text: card.texts[order] || ""
    color: "transparent"
    wrapMode: Text.Wrap
    elide: Text.ElideRight
    HText {
      width: parent.width
      text: card.typedText(typedText.order)
      color: typedText.shownColor
      font: typedText.font
      wrapMode: typedText.wrapMode
      elide: typedText.elide
      maximumLineCount: typedText.maximumLineCount
    }
  }
}
