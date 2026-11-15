import QtQuick

// The medal rack, as on a uniform: one ribbon per medal won, four to a row,
// the short row on top and centred; season medals lead. A ribbon carries 1
// to 3 dots (day, week, month), edge stripes for the harder ones, and the
// number of times it was won.
Column {
  id: rack

  required property var pal
  property var medals: []
  property var seasonMedals: []
  readonly property int perRow: 4
  spacing: 3

  // The daemon pushes a fresh array every two seconds: rebuild the ribbons
  // only when their content changes.
  readonly property string sig: JSON.stringify([medals || [], seasonMedals || []])
  readonly property var all: {
    var parsed = JSON.parse(sig)
    var s = (parsed[1] || []).map(function(m) {
      return { name: m.name || ("Saison " + m.number), color: m.color, dot: m.dot, edges: m.edge || "none", dots: m.bars || 1, count: 1, star: true }
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
  readonly property int attributions: all.reduce(function(a, m) { return a + (m.count || 1) }, 0)

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
          HoverHandler { id: ribHover }
          Rectangle {
            visible: ribHover.hovered
            z: 20
            y: 20; x: (parent.width - width) / 2
            width: tip.implicitWidth + 12; height: tip.implicitHeight + 8
            color: rack.pal.alpha(rack.pal.bg, 0.95)
            border.color: rack.pal.alpha(rack.pal.acc, 0.4)
            HText {
              id: tip
              anchors.centerIn: parent
              text: rib.modelData.name + ((rib.modelData.count || 1) > 1 ? " ×" + rib.modelData.count : "") + (rib.modelData.desc ? " — " + rib.modelData.desc : "")
              color: rack.pal.fg; font.pixelSize: 9
            }
          }
        }
      }
    }
  }
  HText {
    anchors.horizontalCenter: parent.horizontalCenter
    topPadding: 3
    text: rack.all.length ? rack.all.length + " DÉCORATIONS · " + rack.attributions + " ATTRIBUTIONS" : "AUCUNE DÉCORATION"
    color: rack.pal.mut; font.pixelSize: 8; font.letterSpacing: 1.5
  }
}
