import QtQuick
import Quickshell

// Under the globe: the session (name, timer, challenges) with its controls
// on hover, and the tasks behind a closed chip — their names only show
// while the pointer is on it, they can be private.
Item {
  id: block

  required property var pal
  required property var prom
  readonly property var p: prom.p
  property bool wantsKeyboard: false

  // As tall as its content, so the tasks chip at the bottom stays inside
  // (the pointer does not reach what overflows).
  height: content.implicitHeight + 12

  readonly property var session: p ? p.session : null
  readonly property bool paused: !!(p && p.paused)
  readonly property var challenge: p ? p.challenge : null
  readonly property var openTasks: prom.tasks ? prom.tasks.tasks || [] : []

  HoverHandler { id: hover }
  // The controls can be wider than the block (start plus recent names):
  // hovering them keeps them up too.
  readonly property bool hot: hover.hovered || controlsHover.hovered

  Column {
    id: content
    width: parent.width
    spacing: 2

    HText {
      width: parent.width; horizontalAlignment: Text.AlignHCenter
      text: block.session
        ? (block.paused ? "PAUSED" : "SESSION") + " · " + (block.session.task || "untitled").toUpperCase()
        : "NO SESSION"
      color: block.session && !block.paused ? block.pal.acc : block.pal.dim
      font.pixelSize: 9; font.letterSpacing: 2.5
    }

    // Timer, or the controls while hovered.
    Item {
      width: parent.width; height: 32
      HText {
        visible: !block.hot
        anchors.centerIn: parent
        text: block.session ? block.p.formatDuration(block.p.elapsed) : "— : — —"
        color: block.session ? block.pal.fg : block.pal.mut
        opacity: block.paused ? 0.45 : 1
        font.pixelSize: 26; font.weight: Font.DemiBold; font.letterSpacing: 1
      }
      Row {
        visible: block.hot
        anchors.centerIn: parent
        spacing: 8
        HoverHandler { id: controlsHover }
        HButton {
          visible: !block.session
          pal: block.pal; text: "▶ start"; size: 10
          onClicked: Quickshell.execDetached(["omarchy-shell", "austraz.prometheus", "startSession"])
        }
        Repeater {
          model: !block.session && block.prom.names ? (block.prom.names.recent || []).slice(0, 3) : []
          HButton {
            required property var modelData
            pal: block.pal; tone: "g"; text: modelData.name; size: 8
            onClicked: block.prom.act("session:start", [modelData.name])
          }
        }
        HButton {
          visible: !!block.session
          pal: block.pal
          text: block.paused ? "▶ resume" : "❚❚ pause"
          onClicked: block.prom.act(block.paused ? "session:resume" : "session:pause", [])
        }
        HButton {
          visible: !!block.session
          pal: block.pal; tone: "r"; text: "■ end"
          enabled: !(block.challenge && block.challenge.state === "active")
          opacity: enabled ? 1 : 0.4
          onClicked: block.prom.act("session:end", ["manual"])
        }
        HButton {
          visible: !!(block.challenge && block.challenge.state === "active")
          pal: block.pal; tone: "g"; text: "abandon challenge"
          onClicked: block.prom.act("challenge:abandon", [])
        }
      }
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 10
      // Challenges of the session: won, the current one, the rest.
      Row {
        visible: !!block.challenge
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        HText { text: "CHALLENGES"; color: block.pal.mut; font.pixelSize: 8; font.letterSpacing: 1.5 }
        Repeater {
          model: block.challenge ? block.challenge.max : 0
          HText {
            required property int index
            readonly property int won: block.challenge ? block.challenge.index - 1 : 0
            text: index < won ? "●"
              : index === won ? (block.challenge.state === "active"
                  ? "◐ " + block.p.formatDuration(block.challenge.remainingSeconds || 0)
                  : "◌ offered")
              : "○"
            color: index < won ? block.pal.acc : index === won ? (block.challenge.state === "active" ? block.pal.acc2 : block.pal.cyan) : block.pal.mut
            font.pixelSize: 9
          }
        }
      }

      // Tasks, closed: just a count and a lock.
      Item {
        id: chip
        width: chipText.implicitWidth + 12; height: 15
        anchors.verticalCenter: parent.verticalCenter
        Rectangle { anchors.fill: parent; color: "transparent"; border.color: block.pal.alpha(block.pal.fg, 0.2) }
        HText {
          id: chipText
          anchors.centerIn: parent
          text: "▤ TASKS " + block.openTasks.length + " · 🔒"
          color: block.pal.dim; font.pixelSize: 8; font.letterSpacing: 1
        }
        // A click opens the task list in Prometheus' panel. The zone runs
        // past the chip so its whole drawing answers the pointer.
        MouseArea {
          id: chipArea
          anchors.fill: parent
          anchors.margins: -10
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Quickshell.execDetached(["omarchy-shell", "austraz.prometheus", "openTab", "tasks"])
        }

        // The list, above the chip, only while hovered (or typing).
        Rectangle {
          id: pop
          visible: chipArea.containsMouse || popHover.hovered || field.activeFocus
          z: 30
          width: 330; height: popCol.implicitHeight + 20
          x: (chip.width - width) / 2
          y: -height - 2
          color: block.pal.alpha(block.pal.bg, 0.95)
          border.color: block.pal.alpha(block.pal.acc, 0.35)
          HoverHandler { id: popHover }
          Column {
            id: popCol
            x: 12; y: 10; width: parent.width - 24
            spacing: 4
            HText {
              visible: !block.session
              text: "Tasks can be ticked during a session."
              color: block.pal.mut; font.pixelSize: 9
            }
            Repeater {
              model: block.openTasks.slice(0, 8)
              Row {
                required property var modelData
                width: popCol.width
                spacing: 6
                Rectangle {
                  width: 11; height: 11
                  anchors.verticalCenter: parent.verticalCenter
                  color: "transparent"; border.color: block.pal.acc
                  opacity: block.session ? 1 : 0.4
                  MouseArea {
                    anchors.fill: parent; anchors.margins: -3
                    enabled: !!block.session
                    cursorShape: Qt.PointingHandCursor
                    onClicked: block.prom.act("tasks:complete", [modelData.id])
                  }
                }
                HText { width: popCol.width - 60; text: modelData.text; color: block.pal.fg }
                HText { width: 38; horizontalAlignment: Text.AlignRight; text: "+" + (modelData.xp || 1) + " XP"; color: block.pal.mut; font.pixelSize: 9 }
              }
            }
            Item {
              width: popCol.width; height: 22
              Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: block.pal.alpha(block.pal.acc, 0.4) }
              TextInput {
                id: field
                anchors.fill: parent; anchors.topMargin: 4
                color: block.pal.fg
                font.pixelSize: 10
                clip: true
                onActiveFocusChanged: block.wantsKeyboard = activeFocus
                Keys.onEscapePressed: { text = ""; focus = false }
                onAccepted: {
                  var t = text.trim()
                  if (t.length) block.prom.act("tasks:add", [t, "manual"])
                  text = ""
                }
              }
              HText {
                visible: field.text.length === 0
                y: 4
                text: "+ add a task (Enter)"
                color: block.pal.mut
              }
              MouseArea {
                anchors.fill: parent
                visible: !field.activeFocus
                cursorShape: Qt.IBeamCursor
                onClicked: { block.wantsKeyboard = true; field.forceActiveFocus() }
              }
            }
          }
        }
      }
    }
  }

  HoverTip {
    pal: block.pal
    raiseTarget: block.parent
    tipWidth: 400
    text: "Focus session: name and time (pauses excluded). Hover for pause, resume or end, or to start one. Challenges: extension bets of the session (● won, ◐ running, ◌ offered, ○ left). TASKS: your open tasks, shown only while hovered; tick them during a session or add one."
  }
}
