import QtQuick
import Quickshell
import Quickshell.Wayland
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
  implicitWidth: 500
  implicitHeight: stack.height + 44
  exclusionMode: ExclusionMode.Ignore
  exclusiveZone: 0
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "austraz-herald"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  // Only the cards take the pointer.
  mask: Region { item: stack }

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

  // ------------------------------------------------------------ cards

  readonly property var hp: pal
  visible: !!questionCard.shown || !!toastCard.shown

  Column {
    id: stack
    anchors.horizontalCenter: parent.horizontalCenter
    y: 20
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
