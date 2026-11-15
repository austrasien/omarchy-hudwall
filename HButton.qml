import QtQuick
import qs.Commons

// A small square HUD button: accent, cyan ("c"), grey ("g") or red ("r").
Item {
  id: btn

  required property var pal
  property string text: ""
  property string tone: ""
  property real size: 9
  signal clicked()

  readonly property color tint: tone === "c" ? pal.cyan : tone === "g" ? pal.dim : tone === "r" ? pal.red : pal.acc
  implicitWidth: label.implicitWidth + 20
  implicitHeight: label.implicitHeight + 8

  Rectangle {
    anchors.fill: parent
    color: btn.pal.alpha(btn.tint, area.containsMouse ? 0.22 : btn.tone === "g" ? 0 : 0.08)
    border.width: 1
    border.color: btn.pal.alpha(btn.tint, btn.tone === "g" ? 0.35 : 0.55)
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }
  }
  HText {
    id: label
    anchors.centerIn: parent
    text: btn.text.toUpperCase()
    color: btn.tint
    font.pixelSize: btn.size
    font.letterSpacing: 1.4
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
