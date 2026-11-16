import QtQuick
import qs.Commons

// One of the herald's cartouches: a badge, a kind, a title, a line, and
// buttons for a question. It drops from above when a message arrives and
// rises away when `leavingNow`; the first one hangs from the screen's edge.
Item {
  id: card

  required property var pal
  property var msg: null
  property var look: null
  property bool hanging: false
  property real remaining: 1          // a toast's time left, as a line
  property bool leavingNow: false
  readonly property bool hovered: hover.hovered
  signal dismissed()

  readonly property color tint: look ? look.color : pal.acc
  width: parent ? parent.width : 480
  height: msg ? body.implicitHeight + (hanging ? 26 : 22) : 0
  visible: !!msg
  clip: true

  // Arrival: from above, with a little bounce.
  property real drop: 0
  onMsgChanged: if (msg) { drop = 0; arrive.restart() }
  NumberAnimation { id: arrive; target: card; property: "drop"; from: 0; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.2 }

  Item {
    id: face
    width: parent.width; height: parent.height
    y: -height * (1 - card.drop) - (card.leavingNow ? height : 0)
    Behavior on y { enabled: card.leavingNow; NumberAnimation { duration: 240; easing.type: Easing.InCubic } }

    // Square top hanging from the edge (when first), rounded below; a line
    // of the message's colour along the bottom shows a toast's time left.
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: card.hanging ? -16 : 0
      radius: 14
      color: Qt.rgba(card.pal.bg.r, card.pal.bg.g, card.pal.bg.b, 0.96)
      border.width: 1
      border.color: card.pal.alpha(card.tint, 0.55)
    }
    Rectangle {
      anchors.bottom: parent.bottom; anchors.bottomMargin: 1
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width - 40; height: 2; radius: 1
      color: card.pal.alpha(card.tint, 0.2)
      Rectangle { width: parent.width * card.remaining; height: parent.height; radius: 1; color: card.tint }
    }

    Row {
      id: body
      x: 18; y: card.hanging ? 12 : 10
      width: parent.width - 36
      spacing: 14
      Rectangle {
        width: 38; height: 38; radius: 19
        anchors.verticalCenter: parent.verticalCenter
        color: card.pal.alpha(card.tint, 0.15)
        border.width: 1; border.color: card.tint
        Text {
          anchors.centerIn: parent
          text: card.look ? card.look.glyph : ""; color: card.tint
          font.pixelSize: 18
        }
        // A legendary achievement shines.
        Rectangle {
          visible: !!card.msg && card.msg.rarity === "legendary"
          anchors.centerIn: parent
          width: parent.width + 8; height: width; radius: width / 2
          color: "transparent"; border.width: 1; border.color: card.tint
          SequentialAnimation on opacity { running: parent.visible; loops: Animation.Infinite; NumberAnimation { from: 0.8; to: 0; duration: 1200 } }
          SequentialAnimation on scale { running: parent.visible; loops: Animation.Infinite; NumberAnimation { from: 1; to: 1.35; duration: 1200 } }
        }
      }
      Column {
        width: parent.width - 38 - 14 - (buttons.visible ? buttons.width + 14 : 0)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          text: card.look ? card.look.label.toUpperCase() : ""
          color: card.tint
          font.family: Style.fontFamily; font.pixelSize: 9; font.letterSpacing: 2
        }
        Text {
          width: parent.width
          text: card.msg ? card.msg.title || "" : ""
          color: card.pal.fg
          font.family: Style.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold
          elide: Text.ElideRight
        }
        Text {
          visible: text.length > 0
          width: parent.width
          text: card.msg ? card.msg.text || "" : ""
          color: card.pal.dim
          font.family: Style.fontFamily; font.pixelSize: 11
          wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
        }
      }
      Row {
        id: buttons
        visible: !!(card.msg && card.msg.buttons)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Repeater {
          model: card.msg && card.msg.buttons ? card.msg.buttons : []
          HButton {
            required property var modelData
            pal: card.pal
            tone: modelData.tone || ""
            text: modelData.text
            size: 9
            onClicked: modelData.act()
          }
        }
      }
    }
    HoverHandler { id: hover }
    // A toast goes away on a click.
    TapHandler {
      enabled: !(card.msg && card.msg.buttons)
      onTapped: card.dismissed()
    }
  }
}
