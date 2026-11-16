import QtQuick

// A legend whose entries switch their series on and off: `items` =
// [{ key, name, color, value? }]; `hidden` maps a key to true while it is
// off. Charts show a series while `on(key)`. Entries wrap onto lines, each
// line centred in the legend's width.
Item {
  id: legend

  required property var pal
  property var items: []
  property var hidden: ({})
  property real size: 9
  // > 0: one entry per line, this wide, its value aligned right.
  property real columnWidth: 0
  property real spacing: 10

  // Lay the entries out: lines as wide as the legend allows, each centred.
  property var places: []
  implicitHeight: places.length ? places[places.length - 1].bottom : 0
  function layout() {
    var out = [], line = [], lineW = 0, y = 0, lineH = 0
    var n = rep.count
    function flush() {
      var x = Math.max(0, (legend.width - lineW) / 2)
      for (var j = 0; j < line.length; j++) {
        out[line[j].i] = { x: legend.columnWidth > 0 ? 0 : x, y: y, bottom: y + lineH }
        x += line[j].w + legend.spacing
      }
      y += lineH + legend.spacing; line = []; lineW = 0; lineH = 0
    }
    for (var i = 0; i < n; i++) {
      var it = rep.itemAt(i)
      if (!it) continue
      var w = it.width
      if (line.length && (legend.columnWidth > 0 || lineW + legend.spacing + w > legend.width)) flush()
      lineW += (line.length ? legend.spacing : 0) + w
      lineH = Math.max(lineH, it.height)
      line.push({ i: i, w: w })
    }
    if (line.length) flush()
    var last = 0
    for (var k = 0; k < out.length; k++) if (out[k]) last = Math.max(last, out[k].bottom)
    out.push({ bottom: last })
    places = out
  }
  onWidthChanged: relayout.restart()
  onItemsChanged: relayout.restart()
  onColumnWidthChanged: relayout.restart()
  Timer { id: relayout; interval: 0; onTriggered: legend.layout() }
  Component.onCompleted: relayout.restart()

  function on(key) { return !hidden[key] }
  function toggle(key) {
    var h = Object.assign({}, hidden)
    if (h[key]) delete h[key]; else h[key] = true
    hidden = h
  }

  Repeater {
    id: rep
    model: legend.items
    Item {
      id: entry
      required property var modelData
      required property int index
      readonly property bool shown: legend.on(modelData.key)
      readonly property var place: legend.places[index]
      x: place ? place.x : 0; y: place ? place.y : 0
      width: line.width; height: line.height
      onWidthChanged: relayout.restart()
      opacity: shown ? 1 : 0.4
    Row {
      id: line
      spacing: 4
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: legend.size - 1; height: legend.size - 1; radius: 1
        color: entry.shown ? entry.modelData.color : "transparent"
        border.width: 1; border.color: entry.modelData.color
      }
      HText {
        width: legend.columnWidth > 0 ? legend.columnWidth - legend.size - 3 - valueText.width - 8 : implicitWidth
        text: entry.modelData.name + (legend.columnWidth <= 0 && entry.modelData.value !== undefined ? " " + entry.modelData.value : "")
        color: entry.shown ? legend.pal.fg : legend.pal.mut
        font.pixelSize: legend.size
        font.strikeout: !entry.shown
      }
      HText {
        id: valueText
        visible: legend.columnWidth > 0 && entry.modelData.value !== undefined
        width: visible ? implicitWidth : 0
        text: entry.modelData.value !== undefined ? entry.modelData.value : ""
        color: entry.shown ? legend.pal.fg : legend.pal.mut
        font.pixelSize: legend.size
      }
    }
      MouseArea {
        anchors.fill: parent; anchors.margins: -3
        cursorShape: Qt.PointingHandCursor
        onClicked: legend.toggle(entry.modelData.key)
      }
    }
  }
}
