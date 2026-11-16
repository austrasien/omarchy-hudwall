import QtQuick
import Quickshell
import qs.Commons

// A HUD panel: a faint frame with two corner brackets, a small caps label
// and a note on the right. With `tab` set, a click opens that tab of the
// Prometheus panel in the bar.
Item {
  id: panel

  required property var pal
  property string label: ""
  property string note: ""
  property color labelColor: pal.acc
  property string tab: ""
  // Or any command: ["austraz.power", "toggle"] runs `omarchy-shell austraz.power toggle`.
  property var action: null
  property string actionLabel: ""
  readonly property bool clickable: tab.length > 0 || !!action
  property string tip: ""          // what the panel shows, on hover
  property bool tipAbove: false
  property real pad: 12
  readonly property bool hovered: hover.hovered
  default property alias content: body.data
  readonly property real bodyTop: label.length ? pad + 18 : pad

  Rectangle {
    anchors.fill: parent
    color: panel.pal.alpha(panel.pal.bgLight, 0.38)
    border.width: 1
    border.color: panel.pal.alpha(panel.pal.acc, panel.clickable && hover.hovered ? 0.35 : 0.08)
    Behavior on border.color { ColorAnimation { duration: Style.duration(160) } }
  }

  // Corner brackets: top left, bottom right.
  Rectangle { x: -1; y: -1; width: 10; height: 1; color: panel.pal.acc; opacity: 0.7 }
  Rectangle { x: -1; y: -1; width: 1; height: 10; color: panel.pal.acc; opacity: 0.7 }
  Rectangle { x: panel.width - 9; y: panel.height; width: 10; height: 1; color: panel.pal.acc; opacity: 0.7 }
  Rectangle { x: panel.width; y: panel.height - 9; width: 1; height: 10; color: panel.pal.acc; opacity: 0.7 }

  HText {
    id: labelText
    visible: panel.label.length > 0
    x: panel.pad; y: panel.pad - 2
    // All the room the note leaves.
    width: panel.width - 2 * panel.pad - (panel.note.length ? noteText.implicitWidth + 10 : 0)
    // Steps aside for the hints when both would not fit.
    opacity: hover.hovered && hints.opacity > 0 && contentWidth + hints.implicitWidth + 12 > panel.width - 2 * panel.pad ? 0 : 0.9
    Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }
    text: panel.label.toUpperCase()
    color: panel.labelColor
    font.pixelSize: 9
    font.letterSpacing: 2
  }
  HText {
    id: noteText
    visible: panel.note.length > 0
    anchors.right: parent.right; anchors.rightMargin: panel.pad
    y: panel.pad - 2
    horizontalAlignment: Text.AlignRight
    text: panel.note.toUpperCase()
    color: panel.pal.dim
    font.pixelSize: 9
    font.letterSpacing: 2
    opacity: hover.hovered && hints.text.length ? 0 : 1
    Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }
  }
  // On hover, in place of the note: a right-click explains the panel, a
  // click opens where it leads.
  HText {
    id: hints
    anchors.right: parent.right; anchors.rightMargin: panel.pad
    y: panel.pad - 2
    horizontalAlignment: Text.AlignRight
    text: (panel.tip.length ? "? RIGHT-CLICK" : "")
      + (panel.tip.length && panel.clickable ? "  ·  " : "")
      + (panel.clickable ? "↗ " + (panel.actionLabel || panel.tab).toUpperCase() : "")
    color: panel.pal.acc
    font.pixelSize: 9
    font.letterSpacing: 1.5
    opacity: hover.hovered && text.length ? 0.85 : 0
    Behavior on opacity { NumberAnimation { duration: Style.duration(160) } }
  }

  HoverHandler { id: hover }
  // Under the content: a click on a legend or a button inside stays there.
  MouseArea {
    anchors.fill: parent
    z: -1
    enabled: panel.clickable
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(panel.action
      ? ["omarchy-shell"].concat(panel.action)
      : ["omarchy-shell", "austraz.prometheus", "openTab", panel.tab])
  }

  Item {
    id: body
    x: panel.pad
    y: panel.bodyTop
    width: panel.width - 2 * panel.pad
    height: panel.height - panel.bodyTop - panel.pad
  }

  HoverTip {
    pal: panel.pal
    text: panel.tip
    above: panel.tipAbove
    tipWidth: panel.width
  }
}
