import QtQuick
import qs.Commons

// A tooltip for whatever it fills: a right click on the item shows a box
// with `text` under (or above) it, as wide as `tipWidth`; leaving the item
// or a second right click hides it. The item is raised while the box shows
// so its neighbours do not cover it.
Item {
  id: tip

  required property var pal
  property string text: ""
  property bool above: false
  property real tipWidth: Math.max(220, width)
  property real tipX: 0
  property real tipY: NaN                // set to place the box freely
  property var raiseTarget: parent       // raised while the box shows
  property bool open: false
  readonly property bool shown: open && text.length > 0

  anchors.fill: parent
  // Under the content it covers, so the buttons and hover zones inside keep
  // the pointer; above it while the box shows.
  z: shown ? 100 : -1

  HoverHandler { id: hover; onHoveredChanged: if (!hovered) tip.open = false }
  TapHandler {
    acceptedButtons: Qt.RightButton
    onTapped: tip.open = !tip.open
  }

  Binding { target: tip.raiseTarget; property: "z"; value: 60; when: tip.shown }

  Rectangle {
    visible: opacity > 0
    opacity: tip.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Style.duration(140) } }
    x: tip.tipX
    y: !isNaN(tip.tipY) ? tip.tipY : tip.above ? -height - 6 : tip.height + 6
    width: tip.tipWidth
    height: body.implicitHeight + 14
    color: tip.pal.alpha(tip.pal.bg, 0.96)
    border.color: tip.pal.alpha(tip.pal.cyan, 0.5)
    HText {
      id: body
      x: 9; y: 7
      width: parent.width - 18
      wrapMode: Text.WordWrap
      elide: Text.ElideNone
      text: tip.text
      color: tip.pal.fg
      font.pixelSize: 10
      lineHeight: 1.15
    }
  }
}
