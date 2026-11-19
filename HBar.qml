import QtQuick
import qs.Commons

// A thin gauge with a glowing fill; `ghost` draws a dashed projection,
// `marks` vertical ticks ([{ at: 0..1, color }]).
Item {
  id: bar

  required property var pal
  property real value: 0
  property real ghost: -1
  property color color: pal.acc
  property var marks: []
  implicitHeight: 5

  Rectangle { anchors.fill: parent; color: bar.pal.alpha(bar.pal.fg, 0.06) }
  Rectangle {
    visible: bar.ghost > bar.value
    width: parent.width * Math.min(1, bar.ghost); height: parent.height
    color: "transparent"
    border.width: 1
    border.color: bar.pal.alpha(bar.color, 0.5)
  }
  Rectangle {
    id: fill
    width: parent.width * Math.max(0, Math.min(1, bar.value)); height: parent.height
    color: bar.color
    // No easing: values arrive on the HUD's clock, and easing them would
    // redraw the whole HUD at 60 fps for a quarter of a second each time.
  }
  // The glow: a wider, fainter copy.
  Rectangle {
    width: fill.width; height: parent.height + 4; y: -2
    color: bar.pal.alpha(bar.color, 0.18)
    radius: 2
  }
  Repeater {
    model: bar.marks
    Rectangle {
      required property var modelData
      x: bar.width * modelData.at - 1; y: -3
      width: 2; height: bar.height + 6
      color: modelData.color
    }
  }
}
