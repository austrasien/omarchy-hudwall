import QtQuick
import QtQuick.Shapes

// A ring gauge: a faint track and `value` (0..1) as an arc from the bottom
// left round to the bottom right (270°), ticked like a dial; an optional
// inner ring shows `value2`. The centre holds `text` over `caption`.
Item {
  id: g

  required property var pal
  property real value: 0
  property color color: pal.acc
  property real value2: -1            // < 0: no inner ring
  property color color2: pal.red
  property string text: ""
  property string caption: ""
  property real thickness: 5

  readonly property real r: Math.min(width, height) / 2 - thickness / 2 - 1
  readonly property real cx: width / 2
  readonly property real cy: height / 2

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    // Track.
    ShapePath {
      strokeColor: g.pal.alpha(g.pal.fg, 0.08); strokeWidth: g.thickness; fillColor: "transparent"; capStyle: ShapePath.FlatCap
      PathAngleArc { centerX: g.cx; centerY: g.cy; radiusX: g.r; radiusY: g.r; startAngle: 135; sweepAngle: 270 }
    }
    // Value.
    ShapePath {
      strokeColor: g.color; strokeWidth: g.thickness; fillColor: "transparent"; capStyle: ShapePath.FlatCap
      PathAngleArc { centerX: g.cx; centerY: g.cy; radiusX: g.r; radiusY: g.r; startAngle: 135; sweepAngle: 270 * Math.max(0, Math.min(1, g.value)) }
    }
    // Inner ring.
    ShapePath {
      strokeColor: g.value2 >= 0 ? g.pal.alpha(g.pal.fg, 0.06) : "transparent"; strokeWidth: 2; fillColor: "transparent"
      PathAngleArc { centerX: g.cx; centerY: g.cy; radiusX: g.r - g.thickness - 2; radiusY: g.r - g.thickness - 2; startAngle: 135; sweepAngle: 270 }
    }
    ShapePath {
      strokeColor: g.value2 >= 0 ? g.pal.alpha(g.color2, 0.55) : "transparent"; strokeWidth: 1.5; fillColor: "transparent"
      PathAngleArc { centerX: g.cx; centerY: g.cy; radiusX: g.r - g.thickness - 2; radiusY: g.r - g.thickness - 2; startAngle: 135; sweepAngle: 270 * Math.max(0, Math.min(1, g.value2)) }
    }
  }
  // Dial ticks every 10 %.
  Repeater {
    model: 11
    Rectangle {
      required property int index
      readonly property real a: (135 + 27 * index) * Math.PI / 180
      readonly property real rr: g.r + g.thickness / 2 + 2
      x: g.cx + Math.cos(a) * rr - width / 2
      y: g.cy + Math.sin(a) * rr - height / 2
      width: 2; height: 2; radius: 1
      color: index / 10 <= g.value ? g.color : g.pal.alpha(g.pal.fg, 0.2)
    }
  }
  Column {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: 2
    HText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: g.text; color: g.pal.fg
      font.pixelSize: Math.max(10, Math.round(g.r * 0.62)); font.weight: Font.DemiBold
    }
    HText {
      visible: g.caption.length > 0
      anchors.horizontalCenter: parent.horizontalCenter
      text: g.caption; color: g.pal.dim; font.pixelSize: 7; font.letterSpacing: 1
    }
  }
}
