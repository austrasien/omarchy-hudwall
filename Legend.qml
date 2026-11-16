import QtQuick

// A legend whose entries switch their series on and off: `items` =
// [{ key, name, color, value? }]; `hidden` maps a key to true while it is
// off. Charts show a series while `on(key)`.
Flow {
  id: legend

  required property var pal
  property var items: []
  property var hidden: ({})
  property real size: 8
  // > 0: one entry per line, this wide, its value aligned right.
  property real columnWidth: 0
  spacing: 10

  function on(key) { return !hidden[key] }
  function toggle(key) {
    var h = Object.assign({}, hidden)
    if (h[key]) delete h[key]; else h[key] = true
    hidden = h
  }

  Repeater {
    model: legend.items
    Item {
      id: entry
      required property var modelData
      readonly property bool shown: legend.on(modelData.key)
      width: line.width; height: line.height
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
