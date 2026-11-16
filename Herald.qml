import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Shapes
import qs.Commons

// Prometheus' messages over every window: avionic cards at the top of the
// screen, in the side bars' style. Questions waiting for an answer ("Still there?", a
// coffee) stay while they are asked, with their buttons; toasts (medals,
// achievements, quests, challenges, session ends) follow one another below,
// six seconds each (ten for an achievement), held while hovered. The bar,
// which used to show them, is hidden.
PanelWindow {
  id: herald

  required property var prom          // the HUD's Prom (its client is always live)
  property var targetScreen: null

  readonly property var p: prom ? prom.p : null
  HudPalette { id: pal }

  screen: targetScreen
  color: "transparent"
  anchors.top: true
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "austraz-herald"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  // ------------------------------------------------------------ content

  // For testing: a question shown as if Prometheus asked it; its buttons
  // only close it (`omarchy-shell austraz.hudwall heraldTest presence|coffee|toast`).
  property var testQuestion: null
  function test(kind) {
    if (kind === "presence") testQuestion = {
      kind: "presence", title: "Still there?", text: "the session pauses in 4:59 (test)",
      buttons: [{ text: "I'm here", act: function() { herald.testQuestion = null } }]
    }
    else if (kind === "coffee") testQuestion = {
      kind: "coffee", title: "Coffee time", text: "Now: caffeine is low (test)",
      buttons: [
        { text: "☕ have one", act: function() { herald.testQuestion = null } },
        { text: "not now", tone: "g", act: function() { herald.testQuestion = null } }
      ]
    }
    else if (kind === "toast") prom.toast("achievement", "Test Achievement", "+0 XP · a test, nothing won", "rare")
    else testQuestion = null
    return kind
  }

  readonly property var question: {
    if (testQuestion) return testQuestion
    if (!p) return null
    if (p.presence) {
      return {
        kind: "presence", title: "Still there?",
        // Read again each second by the card (the countdown).
        textFn: function() {
          var pr = herald.p ? herald.p.presence : null
          var left = pr && pr.pauseAt ? Math.max(0, Math.round((pr.pauseAt - herald.now) / 1000)) : -1
          return left >= 0 ? "the session pauses in " + Math.floor(left / 60) + ":" + String(left % 60).padStart(2, "0") : "the session waits for you"
        },
        buttons: [{ text: "I'm here", act: function() { herald.p.confirmPresence() } }]
      }
    }
    if (p.coffeeNudge) return {
      kind: "coffee", title: "Coffee time", text: p.coffeeNudge.reason || "",
      buttons: [
        { text: "☕ have one", act: function() { herald.p.coffeeOk() } },
        { text: "not now", tone: "g", act: function() { herald.p.coffeeNo() } }
      ]
    }
    return null
  }
  property real now: Date.now()
  Timer { interval: 1000; repeat: true; running: !!herald.question; onTriggered: herald.now = Date.now() }

  property var queue: []
  property var current: null
  Connections {
    target: herald.prom
    function onToast(kind, title, text, rarity) {
      herald.queue = herald.queue.concat([{ kind: kind, title: title, text: text, rarity: rarity }])
      if (!herald.current) herald.next()
    }
  }
  function next() {
    if (!queue.length) { current = null; return }
    current = queue[0]
    queue = queue.slice(1)
    life.duration = current.kind === "achievement" ? 10000 : 6000
    life.restart()
  }
  // Time left on the toast, drawn as a line; paused while hovered.
  property real remaining: 1
  NumberAnimation {
    id: life
    target: herald; property: "remaining"; from: 1; to: 0
    paused: running && toastCard.hovered
    onFinished: leaving.start()
  }
  SequentialAnimation {
    id: leaving
    PauseAnimation { duration: 260 }
    ScriptAction { script: herald.next() }
  }

  function rarityColor(r) {
    return r === "legendary" ? pal.series(2) : r === "epic" ? pal.series(4) : r === "rare" ? pal.series(3) : r === "common" ? pal.series(1) : pal.acc
  }
  function look(m) {
    var k = m.kind
    if (k === "achievement") return { glyph: m.rarity === "legendary" ? "✦" : m.rarity === "epic" ? "★" : m.rarity === "rare" ? "◆" : "●",
      label: (m.rarity ? m.rarity + " " : "") + "achievement", color: rarityColor(m.rarity) }
    if (k === "medal") return { glyph: "✪", label: "medal", color: pal.series(2) }
    if (k === "quest") return { glyph: "◈", label: "quest", color: pal.series(1) }
    if (k === "won") return { glyph: "⚑", label: "challenge", color: pal.series(1) }
    if (k === "ended") return { glyph: "■", label: "session", color: pal.acc }
    if (k === "absent" || k === "error") return { glyph: "!", label: k === "error" ? "error" : "session", color: pal.red }
    if (k === "presence") return { glyph: "?", label: "presence", color: pal.series(2) }
    if (k === "coffee") return { glyph: "☕", label: "caffeine", color: pal.series(1) }
    if (k === "goal") return { glyph: "◎", label: "goal", color: pal.series(1) }
    return { glyph: "•", label: k, color: pal.acc }
  }

  // ------------------------------------------------------------ the notch
  //
  // A notch hanging from the top edge, like a phone's: concave shoulders
  // meeting the edge, rounded corners below, a thin outline in the message's
  // colour and a scale along its bottom. It grows down when a message comes,
  // the cards sliding down inside it, and goes back up when none is left.

  readonly property var hp: pal
  readonly property bool any: !!herald.question || !!herald.current || !!questionCard.shown || !!toastCard.shown
  readonly property real shoulder: 18
  readonly property real pad: 22
  readonly property real notchW: stack.width + 2 * pad
  property real notchH: any ? stack.implicitHeight + 2 * pad - 6 : 0
  Behavior on notchH { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
  readonly property color ink: questionCard.shown ? questionCard.ink : toastCard.ink
  readonly property color inkDim: Qt.tint(pal.bg, Qt.alpha(ink, 0.5))
  readonly property color black: Qt.darker(pal.bg, 1.6)

  visible: any || notchH > 1
  implicitWidth: notchW + 2 * shoulder + 8
  implicitHeight: Math.max(1, notchH + 6)
  mask: Region { item: notch }

  Item {
    id: notch
    anchors.horizontalCenter: parent.horizontalCenter
    width: herald.notchW + 2 * herald.shoulder
    height: herald.notchH

    Shape {
      id: shape
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      readonly property real s: herald.shoulder
      readonly property real r: Math.min(18, herald.notchH / 2)
      readonly property real w: width
      readonly property real h: Math.max(0, height)
      ShapePath {
        fillColor: Qt.alpha(herald.black, 0.97)
        strokeColor: herald.inkDim
        strokeWidth: 1
        startX: 0; startY: 0
        // Left shoulder, concave into the edge.
        PathQuad { x: shape.s; y: Math.min(shape.s, shape.h); controlX: shape.s; controlY: 0 }
        PathLine { x: shape.s; y: Math.max(shape.s, shape.h - shape.r) }
        PathQuad { x: shape.s + shape.r; y: shape.h; controlX: shape.s; controlY: shape.h }
        PathLine { x: shape.w - shape.s - shape.r; y: shape.h }
        PathQuad { x: shape.w - shape.s; y: Math.max(shape.s, shape.h - shape.r); controlX: shape.w - shape.s; controlY: shape.h }
        PathLine { x: shape.w - shape.s; y: Math.min(shape.s, shape.h) }
        PathQuad { x: shape.w; y: 0; controlX: shape.w - shape.s; controlY: 0 }
      }
    }
    // Scan lines inside.
    Image {
      x: herald.shoulder; width: herald.notchW; height: parent.height
      fillMode: Image.Tile
      verticalAlignment: Image.AlignTop; horizontalAlignment: Image.AlignLeft
      source: "data:image/svg+xml," + encodeURIComponent(
        "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'><rect width='4' height='1' fill='"
        + herald.ink + "' fill-opacity='0.05'/></svg>")
    }
    // The scale along the bottom, and its bright centre mark.
    Item {
      x: herald.shoulder + 26; width: herald.notchW - 52; height: 6
      y: parent.height - 9
      visible: herald.notchH > 30
      Repeater {
        model: 41
        Rectangle {
          required property int index
          x: index * (parent.width - 1) / 40
          y: index % 5 === 0 ? 0 : 3
          width: 1; height: index % 5 === 0 ? 5 : 2
          color: index === 20 ? herald.ink : herald.inkDim
        }
      }
    }

    // The cards, sliding down with the notch.
    Item {
      x: herald.shoulder; width: herald.notchW; height: parent.height
      clip: true
      Column {
        id: stack
        anchors.horizontalCenter: parent.horizontalCenter
        y: herald.notchH - implicitHeight - herald.pad + 4
        width: 440
        spacing: 22
        HeraldCard {
          id: questionCard
          pal: herald.hp
          msg: herald.question
          look: herald.question ? herald.look(herald.question) : null
        }
        HeraldCard {
          id: toastCard
          pal: herald.hp
          msg: herald.current
          look: herald.current ? herald.look(herald.current) : null
          remaining: herald.remaining
          leavingNow: leaving.running
          onDismissed: { life.stop(); leaving.start() }
        }
      }
    }
  }
}
