import QtQuick
import qs.Commons

// A tooltip for whatever it fills: after a short hover, a box with `text`
// shows under (or above) the item, as wide as `tipWidth`. The item is raised
// while hovered so the box is not covered by its neighbours.
Item {
  id: tip

  required property var pal
  property string text: ""
  property bool above: false
  property real tipWidth: Math.max(220, width)
  property real tipX: 0
  property real tipY: NaN                // set to place the box freely
  property var raiseTarget: parent       // raised while hovered
  readonly property bool hovered: hover.hovered

  anchors.fill: parent

  HoverHandler { id: hover }
  Timer { id: delay; interval: 500; running: hover.hovered && tip.text.length > 0 }
  readonly property bool shown: hover.hovered && !delay.running && text.length > 0

  Binding { target: tip.raiseTarget; property: "z"; value: 60; when: tip.hovered }

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
