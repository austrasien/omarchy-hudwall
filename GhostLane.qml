import QtQuick

// One lane of the ghost race: where you are now on a track whose finish
// line is the record day's total; the ghost (the record day at this same
// hour) and yesterday (same hour) ride along. Above: the race's name, where
// you are, the gap to the ghost, the pace (today's total if the rest of the
// day brings what the record's did from here); below: the others' figures.
Item {
  id: lane

  required property var pal
  property string label: ""
  property real nowV: 0           // today so far
  property real ghostV: 0         // the record day at this hour
  property real yestV: 0          // yesterday at this hour
  property real finishV: 0        // the record day's total
  property var format: function(v) { return String(Math.round(v)) }
  property bool animate: false
  // The ghost's float and the tip's breath move on the HUD's 8 Hz clock: a
  // smooth animation would redraw the whole HUD at 60 fps for as long as it
  // shows.
  property int beat: 0

  readonly property real gap: nowV - ghostV
  readonly property bool ahead: gap >= 0
  // Today's total if the rest of the day brings what the record's did
  // from this hour on.
  readonly property real pace: nowV + Math.max(0, finishV - ghostV)
  readonly property bool beaten: finishV > 0 && nowV > finishV
  readonly property real scaleTop: Math.max(finishV, nowV, 1e-9) * 1.06
  function px(v) { return Math.max(0, Math.min(1, v / scaleTop)) * track.width }

  readonly property color you: pal.series(0)
  readonly property color ghostColor: pal.series(1)
  readonly property color yestColor: pal.series(2)
  readonly property color gapColor: ahead ? pal.series(1) : pal.red

  height: 62

  function g(cp) { return String.fromCodePoint(cp) }

  // ---- header: name, where you are, the gap to the ghost
  Row {
    width: parent.width
    spacing: 8
    HText {
      y: 5
      text: lane.label; color: lane.pal.mut; font.pixelSize: 9; font.letterSpacing: 1.5
    }
    HText {
      id: nowText
      text: lane.format(lane.nowV); color: lane.pal.fg
      font.pixelSize: 15; font.weight: Font.DemiBold
    }
    Rectangle {
      anchors.verticalCenter: nowText.verticalCenter
      width: gapText.implicitWidth + 10; height: gapText.implicitHeight + 2; radius: 2
      color: lane.pal.alpha(lane.gapColor, 0.14)
      border.color: lane.pal.alpha(lane.gapColor, 0.5)
      HText {
        id: gapText
        anchors.centerIn: parent
        text: (lane.ahead ? "▲ " : "▼ ") + lane.format(Math.abs(lane.gap))
        color: lane.gapColor; font.pixelSize: 9; font.weight: Font.DemiBold
      }
    }
  }

  // The pace, or the record beaten, bottom right.
  HText {
    anchors.right: parent.right
    y: 48
    text: lane.beaten ? "★ record!" : "pace " + lane.format(lane.pace)
    color: lane.beaten ? lane.pal.series(1) : lane.pal.dim; font.pixelSize: 9
  }

  // ---- the track
  Item {
    id: track
    y: 24; width: parent.width - 14; height: 18

    // Ruler.
    Rectangle { y: parent.height / 2; width: parent.width; height: 1; color: lane.pal.alpha(lane.pal.fg, 0.12) }
    Repeater {
      model: 11
      Rectangle {
        required property int index
        x: index * (track.width - 1) / 10; y: track.height / 2 - (index % 5 === 0 ? 3 : 1.5)
        width: 1; height: index % 5 === 0 ? 7 : 4
        color: lane.pal.alpha(lane.pal.fg, 0.14)
      }
    }
    // The ghost's trail and the ghost.
    Rectangle {
      y: parent.height / 2 - 1; height: 2; width: lane.px(lane.ghostV)
      color: lane.pal.alpha(lane.ghostColor, 0.35)
    }
    HText {
      id: ghostMark
      x: lane.px(lane.ghostV) - width / 2
      // Floats up and down by 2 units over 2.2 s, in steps (see `beat`).
      y: lane.animate ? -4 - Math.sin(lane.beat * 2 * Math.PI / 17.6) : -3
      text: lane.g(0xF02A0)
      color: lane.ghostColor; font.pixelSize: 13
      opacity: 0.85
    }
    // Yesterday: a small diamond under the line.
    Rectangle {
      x: lane.px(lane.yestV) - 3.5; y: parent.height / 2 + 4
      width: 7; height: 7; rotation: 45
      color: lane.yestColor
    }
    // You: the bar, and a glowing tip.
    Rectangle {
      y: parent.height / 2 - 2; height: 4; radius: 2
      width: lane.px(lane.nowV)
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: lane.pal.alpha(lane.you, 0.15) }
        GradientStop { position: 1; color: lane.you }
      }
    }
    Rectangle {
      id: halo
      x: lane.px(lane.nowV) - width / 2; y: parent.height / 2 - height / 2
      width: 14; height: 14; radius: 7
      color: lane.pal.alpha(lane.you, 0.25)
      // Breathes over 1.8 s, in steps (see `beat`).
      scale: lane.animate ? 0.975 + 0.275 * Math.sin(lane.beat * 2 * Math.PI / 14.4) : 1
    }
    Rectangle {
      x: lane.px(lane.nowV) - 3.5; y: parent.height / 2 - 3.5
      width: 7; height: 7; radius: 3.5
      color: lane.you
      border.color: lane.pal.fg; border.width: 1
    }
    // The finish line, checkered: the record day's total; lit once beaten.
    Grid {
      x: lane.px(lane.finishV) - 3; y: 0
      columns: 2
      Repeater {
        model: 12
        Rectangle {
          required property int index
          width: 3; height: 3
          color: (index + Math.floor(index / 2)) % 2 === 0
            ? (lane.beaten ? lane.pal.series(1) : lane.pal.fg) : lane.pal.alpha(lane.pal.fg, 0.08)
        }
      }
    }
  }

  // ---- below: the ghost's and yesterday's figures (the finish is the
  // checkered line; its figure is in the tooltip)
  Row {
    y: 48
    spacing: 10
    HText { text: lane.g(0xF02A0) + " " + lane.format(lane.ghostV); color: lane.ghostColor; font.pixelSize: 9 }
    HText { text: "◆ " + lane.format(lane.yestV); color: lane.yestColor; font.pixelSize: 9 }
  }
}
