import QtQuick
import Quickshell

// The medal rack, as on a uniform: one ribbon per medal won, rows as wide as
// the rack,
// the short row on top and centred; season medals lead. A ribbon carries 1
// to 3 dots (day, week, month), edge stripes for the harder ones, and the
// number of times it was won.
Item {
  id: rack

  required property var pal
  property var medals: []
  property var seasonMedals: []
  // As many ribbons to a row as the width given holds.
  readonly property int perRow: Math.max(1, Math.floor((width + 3) / 57))
  implicitHeight: col.implicitHeight
  height: implicitHeight

  // The daemon pushes a fresh array every two seconds: rebuild the ribbons
  // only when their content changes.
  readonly property string sig: JSON.stringify([medals || [], seasonMedals || []])
  readonly property var all: {
    var parsed = JSON.parse(sig)
    var s = (parsed[1] || []).map(function(m) {
      return { name: m.name || ("Season " + m.number), desc: m.desc || "", period: "season", color: m.color, dot: m.dot, edges: m.edge || "none", dots: m.bars || 1, count: 1, star: true }
    })
    return s.concat(parsed[0] || [])
  }
  readonly property var rows: {
    var l = all.slice()
    var out = []
    if (!l.length) return out
    out.push(l.splice(0, l.length % perRow || perRow))
    while (l.length) out.push(l.splice(0, perRow))
    return out
  }
  // The same legend as Prometheus' own placard.
  function legendFor(m) {
    if (m.period === "season") return m.name + " · " + (m.desc || "") + " · kept for good"
    return m.name + ((m.count || 1) > 1 ? " ×" + m.count : "") + (m.desc ? " · " + m.desc : "")
      + (m.current ? " · won " + (m.period === "day" ? "today" : m.period === "week" ? "this week" : "this month") : "")
  }
  // The ribbon under the pointer, and where it sits in the rack.
  property var hoveredMedal: null
  property point hoveredAt: Qt.point(0, 0)

  readonly property int attributions: all.reduce(function(a, m) { return a + (m.count || 1) }, 0)

  Column {
  id: col
  width: rack.width
  spacing: 3
  Repeater {
    model: rack.rows
    Row {
      required property var modelData
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 3
      Repeater {
        model: modelData
        Item {
          id: rib
          required property var modelData
          width: 54; height: 16
          Rectangle {
            anchors.fill: parent
            radius: 2
            color: rib.modelData.color
            border.width: 1
            border.color: Qt.darker(rib.modelData.color, 1.8)
            clip: true
            Rectangle {
              visible: rib.modelData.edges === "left" || rib.modelData.edges === "both"
              x: 6; width: 4; height: parent.height; color: rib.modelData.dot
            }
            Rectangle {
              visible: rib.modelData.edges === "both"
              x: parent.width - 10; width: 4; height: parent.height; color: rib.modelData.dot
            }
            Row {
              visible: !rib.modelData.star
              anchors.centerIn: parent
              spacing: 3
              Repeater {
                model: Math.max(1, Math.min(3, rib.modelData.dots || 1))
                Rectangle { width: 7; height: 7; radius: 3.5; color: rib.modelData.dot; border.width: 1; border.color: Qt.darker(rib.modelData.dot, 1.4) }
              }
            }
            HText {
              visible: !!rib.modelData.star
              anchors.centerIn: parent
              text: "★"; color: rib.modelData.dot; font.pixelSize: 13
            }
            // Sheen.
            Rectangle {
              anchors.fill: parent
              gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.35) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.25) }
              }
            }
          }
          HText {
            visible: (rib.modelData.count || 1) > 1
            anchors.right: parent.right; anchors.rightMargin: 2
            anchors.bottom: parent.bottom; anchors.bottomMargin: -1
            text: rib.modelData.count
            color: "white"; font.pixelSize: 8; font.weight: Font.Bold
            style: Text.Outline; styleColor: "black"
          }
          HoverHandler {
            onHoveredChanged: {
              if (hovered) {
                rack.hoveredMedal = rib.modelData
                rack.hoveredAt = rib.mapToItem(rack, rib.width / 2, rib.height)
              } else if (rack.hoveredMedal === rib.modelData) rack.hoveredMedal = null
            }
          }
        }
      }
    }
  }
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    topPadding: 3
    spacing: 8
    HText {
      text: rack.all.length ? rack.all.length + " DECORATIONS · " + rack.attributions + " AWARDS" : "NO DECORATIONS"
      color: rack.pal.mut; font.pixelSize: 8; font.letterSpacing: 1.5
    }
    // Share: Prometheus builds its card (the rack among it) and offers to save it.
    HText {
      text: String.fromCodePoint(0xF0497) + " SHARE"
      color: shareArea.containsMouse ? rack.pal.acc : rack.pal.dim
      font.pixelSize: 8; font.letterSpacing: 1.5
      MouseArea {
        id: shareArea
        anchors.fill: parent; anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["omarchy-shell", "austraz.prometheus", "shareCard"])
      }
    }
  }
  }

  // The legend of the hovered ribbon, above everything around the rack.
  Rectangle {
    visible: rack.hoveredMedal !== null
    z: 100
    width: Math.min(340, legend.implicitWidth + 16)
    height: legend.implicitHeight + 10
    x: Math.max(0, Math.min(rack.width - width, rack.hoveredAt.x - width / 2))
    y: rack.hoveredAt.y + 4
    color: rack.pal.alpha(rack.pal.bg, 0.96)
    border.color: rack.pal.alpha(rack.pal.acc, 0.45)
    radius: 3
    HText {
      id: legend
      x: 8; y: 5
      width: Math.min(implicitWidth, 324)
      wrapMode: Text.WordWrap
      text: rack.hoveredMedal ? rack.legendFor(rack.hoveredMedal) : ""
      color: rack.pal.fg; font.pixelSize: 9
    }
  }

  HoverTip {
    pal: rack.pal
    raiseTarget: rack.parent
    tipWidth: 340
    tipX: (rack.width - 340) / 2
    text: "Medals won, as a ribbon rack: 1, 2 or 3 dots = daily, weekly or monthly medal; edge stripes = harder ones; number = times won; season medals first. Hover a ribbon for its name. SHARE: Prometheus builds an image card with the rack and asks where to save it."
  }
}
