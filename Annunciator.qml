import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// An annunciator panel for the services listed under `uptime` in the config
// (checked by the collector): one lamp per service and a master caution
// light, the "dark cockpit" way. A service that answers stays dark, with a
// faint status line and its latency; a slow one (or one whose certificate
// expires within 14 days) lights amber; a down one lights red, and the
// master light flashes until acknowledged. A grey lamp is not an outage:
// this machine has no Internet (NO LINK) or no Tailscale (OFF).
//
// Left click on a lamp: open the service (its URL, or its `open` command).
// Left click on the master light: acknowledge; with nothing to acknowledge,
// a lamp test (every lamp lit a moment) and everything checked again.
// Right click: details.
Item {
  id: ann

  required property var pal
  required property var sys
  property bool animate: true

  readonly property var list: sys.uptime || []
  visible: list.length > 0
  implicitHeight: visible ? 30 : 0

  readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/hudwall"
  readonly property color amber: pal.yellow

  readonly property var faults: list.filter(function(t) { return t.state === "down" || t.state === "slow" })
  readonly property bool anyDown: faults.some(function(t) { return t.state === "down" })
  readonly property bool allNoLink: list.length > 0 && list.every(function(t) { return t.state === "nolink" || t.state === "off" })
  readonly property int nominal: list.filter(function(t) { return t.state === "up" }).length
  // A fault is acknowledged for as long as it holds: name, state and since.
  readonly property string faultKey: faults.map(function(t) { return t.name + ":" + t.state + ":" + t.since }).sort().join("|")
  property string ackKey: ""
  readonly property bool pending: faultKey !== "" && faults.some(function(t) {
    return ackKey.split("|").indexOf(t.name + ":" + t.state + ":" + t.since) < 0
  })

  FileView {
    id: ackFile
    path: ann.stateDir + "/uptime-ack"
    printErrors: false
    onLoaded: ann.ackKey = text().trim()
  }
  function acknowledge() {
    ackKey = faultKey
    ackFile.setText(faultKey + "\n")
  }

  // The lamp test: every lamp lit for a moment, and a fresh check of all.
  property bool lampTest: false
  Timer { id: lampTimer; interval: 1400; onTriggered: ann.lampTest = false }
  function test() {
    lampTest = true
    lampTimer.restart()
    Quickshell.execDetached(["sh", "-c", "mkdir -p \"$1\" && touch \"$1/uptime.poke\"", "sh", stateDir])
  }

  // One flash a second while a fault waits for acknowledgement.
  property real blink: 1
  SequentialAnimation on blink {
    running: ann.pending && ann.animate && ann.visible
    loops: Animation.Infinite
    onRunningChanged: if (!running) ann.blink = 1
    NumberAnimation { to: 0.25; duration: 450; easing.type: Easing.InQuad }
    NumberAnimation { to: 1; duration: 150 }
    PauseAnimation { duration: 400 }
  }

  function clock(ts) {
    if (!ts) return "–"
    var d = new Date(ts * 1000), now = new Date()
    var hm = Qt.formatTime(d, "HH:mm")
    return d.toDateString() === now.toDateString() ? hm : Qt.formatDate(d, "d MMM") + " " + hm
  }
  function ago(ts) {
    if (!ts) return "never"
    var s = Math.max(0, Math.round(Date.now() / 1000 - ts))
    return s < 90 ? s + " s ago" : s < 5400 ? Math.round(s / 60) + " min ago" : Math.round(s / 3600) + " h ago"
  }
  function readout(t) {
    if (lampTest) return "TEST"
    switch (t.state) {
    case "down": return t.code ? String(t.code) : "DOWN"
    case "off": return "OFF"
    case "nolink": return "NO LINK"
    case "wait": return "···"
    case "slow":
      if (t.cert !== null && t.cert !== undefined && t.cert < 14) return "CERT " + t.cert + "d"
      return t.ms >= 1000 ? (t.ms / 1000).toFixed(1) + "s" : t.ms + "ms"
    default: return t.ms !== null && t.ms !== undefined ? t.ms + "ms" : ""
    }
  }
  function details(t) {
    var words = { up: "UP", slow: "SLOW", down: "DOWN", off: "OFF (Tailscale not running)", nolink: "NO LINK (this machine is offline)", wait: "not checked yet" }
    var lines = [t.name + (t.note ? " · " + t.note : ""), t.target,
                 (words[t.state] || t.state) + " since " + clock(t.since)]
    var m = []
    if (t.ms !== null && t.ms !== undefined) m.push(t.ms + " ms")
    if (t.code) m.push("HTTP " + t.code)
    if (t.cert !== null && t.cert !== undefined) m.push("certificate " + t.cert + " days")
    if (m.length) lines.push(m.join(" · "))
    if (t.err) lines.push(t.err)
    lines.push("checked " + ago(t.checked) + (t.open ? " · click opens it" : ""))
    return lines.join("\n")
  }

  readonly property real masterW: 58
  readonly property real gapW: 5
  readonly property real lampW: Math.min(72, (width - masterW - 10 - (list.length - 1) * gapW) / Math.max(1, list.length))

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 10

    // ---------------------------------------------------- master caution
    Item {
      id: master
      width: ann.masterW; height: 30
      readonly property bool lit: ann.lampTest || ann.faults.length > 0
      readonly property color tint: ann.anyDown || ann.lampTest ? ann.pal.red : ann.amber
      Rectangle {
        anchors.fill: parent
        radius: 2
        color: master.lit ? ann.pal.alpha(master.tint, ann.pending ? 0.9 * ann.blink : 0.16) : "transparent"
        border.width: 1
        border.color: master.lit ? master.tint
                    : masterArea.containsMouse ? ann.pal.alpha(ann.pal.acc, 0.8) : ann.pal.alpha(ann.pal.mut, 0.6)
      }
      Column {
        anchors.centerIn: parent
        spacing: 0
        HText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: master.lit ? "MASTER" : ann.allNoLink ? "NO" : "SVC"
          color: master.lit ? (ann.pending && ann.blink > 0.5 ? ann.pal.bg : master.tint) : ann.pal.dim
          font.pixelSize: 7; font.letterSpacing: 1.5; font.weight: Font.Bold
        }
        HText {
          anchors.horizontalCenter: parent.horizontalCenter
          text: master.lit ? (ann.anyDown || ann.lampTest ? "WARNING" : "CAUTION")
              : ann.allNoLink ? "LINK" : ann.nominal + " / " + ann.list.length
          color: master.lit ? (ann.pending && ann.blink > 0.5 ? ann.pal.bg : master.tint) : ann.allNoLink ? ann.pal.dim : ann.pal.acc
          font.pixelSize: 8; font.letterSpacing: 1.2; font.weight: Font.Bold
        }
      }
      MouseArea {
        id: masterArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ann.pending ? ann.acknowledge() : ann.test()
      }
      HoverTip {
        pal: ann.pal; raiseTarget: ann; tipWidth: 300
        text: "Services watched from this computer (uptime in hudwall.json). Dark = answering, amber = slow or certificate under 14 days, red = down twice in a row, grey = this machine is offline. Click: acknowledge the flashing light; with nothing to acknowledge, a lamp test and a fresh check of every service."
      }
    }

    // ---------------------------------------------------- lamps
    Row {
    spacing: ann.gapW
    Repeater {
      model: ann.list
      delegate: Item {
        id: lamp
        required property var modelData
        required property int index
        readonly property string st: modelData.state
        readonly property bool down: ann.lampTest || st === "down"
        readonly property bool slow: !ann.lampTest && st === "slow"
        readonly property bool grey: !ann.lampTest && (st === "off" || st === "nolink" || st === "wait")
        readonly property bool hot: lampArea.containsMouse
        width: ann.lampW; height: 30

        Rectangle {
          anchors.fill: parent
          radius: 2
          color: lamp.down ? ann.pal.alpha(ann.pal.red, 0.82)
               : lamp.slow ? ann.pal.alpha(ann.amber, 0.14)
               : lamp.hot ? ann.pal.alpha(ann.pal.acc, 0.1) : ann.pal.alpha(ann.pal.bgLight, 0.55)
          border.width: 1
          border.color: lamp.down ? ann.pal.red : lamp.slow ? ann.amber
                      : lamp.hot ? ann.pal.alpha(ann.pal.acc, 0.8) : ann.pal.alpha(ann.pal.mut, lamp.grey ? 0.3 : 0.5)
          Behavior on color { ColorAnimation { duration: Style.duration(200) } }
        }
        // The status line: the lamp's filament, lit while the service answers.
        Rectangle {
          visible: !lamp.down && !lamp.grey
          x: 4; width: parent.width - 8
          y: parent.height - 3; height: 2
          radius: 1
          color: lamp.slow ? ann.amber : ann.pal.acc
          opacity: lamp.slow ? 0.9 : lamp.hot ? 0.9 : 0.45
        }
        HText {
          x: 6; y: 3.5
          width: parent.width - 12
          text: lamp.modelData.name
          color: lamp.down ? ann.pal.bg : lamp.slow ? ann.amber : lamp.grey ? ann.pal.mut : lamp.hot ? ann.pal.fg : ann.pal.dim
          font.pixelSize: 9; font.letterSpacing: 1.2; font.weight: lamp.down ? Font.Bold : Font.DemiBold
        }
        HText {
          x: 6; y: 14
          width: parent.width - 12
          text: ann.readout(lamp.modelData)
          color: lamp.down ? ann.pal.alpha(ann.pal.bg, 0.85) : lamp.slow ? ann.amber : lamp.grey ? ann.pal.mut : ann.pal.alpha(ann.pal.dim, 0.75)
          font.pixelSize: 8; font.letterSpacing: 0.8
        }
        MouseArea {
          id: lampArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: lamp.modelData.open ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: {
            var o = lamp.modelData.open
            if (!o) return
            if (/^https?:\/\//.test(o)) Quickshell.execDetached(["xdg-open", o])
            else Quickshell.execDetached(["sh", "-c", o])
          }
        }
        HoverTip {
          pal: ann.pal; raiseTarget: ann; tipWidth: 260
          // Opening inwards, so the box stays over the centre column.
          tipX: lamp.index >= ann.list.length / 2 ? lamp.width - 260 : 0
          text: ann.details(lamp.modelData)
        }
      }
    }
    }
  }
}
