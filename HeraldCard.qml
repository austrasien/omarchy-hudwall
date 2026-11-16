import QtQuick
import qs.Commons

// One of the herald's cards, in the avionic style of the side bars' cards
// (austraz.daybar's HudCard): dark worn-tape panel, target brackets, a
// header with the kind, a scale, the title in capitals, and on the right the
// message's badge inside a targeting reticle. It opens as a target lock: the
// panel wipes open from the middle, the brackets close in and blink, a scan
// line paints the content while the reticle spins down onto the badge, and
// a flash marks the lock. Closing is the opening backwards.
//
// A question's buttons: on hover the card splits into as many zones as it
// has buttons, each one big and clickable. A toast goes away on a click.
Item {
  id: card

  required property var pal
  property var msg: null
  property var look: null
  property real remaining: 1          // a toast's time left, along the scale
  property bool leavingNow: false
  readonly property bool hovered: hover.hovered
  signal dismissed()

  // What is drawn: the message, kept while the card closes.
  property var shown: null
  property var shownLook: null
  readonly property color ink: shownLook ? shownLook.color : pal.acc
  readonly property color bright: Qt.tint(ink, Qt.alpha("#ffffff", 0.45))
  readonly property color dim: Qt.tint(pal.bg, Qt.alpha(ink, 0.45))
  readonly property color black: Qt.darker(pal.bg, 1.6)
  readonly property var buttons: shown && shown.buttons ? shown.buttons : []

  width: parent ? parent.width : 440
  height: shown ? body.implicitHeight + 28 : 0
  visible: !!shown

  // ------------------------------------------------------------ the lock
  property real t: 0
  property real spin: 0
  property real spinFrom: 180
  property int spinMs: 1100
  function seg(a, b) {
    var p = Math.max(0, Math.min(1, (t - a) / (b - a)))
    return 1 - Math.pow(1 - p, 3)
  }
  readonly property real spread: (1 - seg(0.3, 0.6)) * 14
  readonly property real bracketOpacity: t < 0.3 ? 0 : (t > 0.62 && t < 0.66) || (t > 0.7 && t < 0.74) ? 0.15 : 1

  onMsgChanged: {
    if (msg) {
      // The same question asked again (the state is pushed anew): no new lock.
      var same = shown && !closing.running && msg.kind === shown.kind && msg.title === shown.title && !!msg.buttons
      shown = msg; shownLook = look
      if (same) return
      closing.stop()
      spinFrom = 70 + Math.random() * 220
      spinMs = 700 + Math.random() * 700
      t = 0; spin = 1
      lockAnim.restart()
    } else if (shown) {
      lockAnim.stop()
      closing.restart()
    }
  }
  onLookChanged: if (msg) shownLook = look
  onLeavingNowChanged: if (leavingNow) { lockAnim.stop(); closing.restart() }
  ParallelAnimation {
    id: lockAnim
    NumberAnimation { target: card; property: "spin"; from: 1; to: 0; duration: card.spinMs; easing.type: Easing.OutCubic }
    SequentialAnimation {
      NumberAnimation { target: card; property: "t"; to: 0.74; duration: 533 }
      PauseAnimation { duration: Math.max(0, card.spinMs - 533) }
      NumberAnimation { target: card; property: "t"; to: 1; duration: 187 }
    }
  }
  SequentialAnimation {
    id: closing
    NumberAnimation { target: card; property: "t"; to: 0; duration: 200 }
    ScriptAction { script: if (!card.msg) { card.shown = null; card.shownLook = null } }
  }

  // ------------------------------------------------------------ the panel
  Item {
    id: wipe
    anchors.horizontalCenter: parent.horizontalCenter
    width: card.width * card.seg(0.1, 0.4)
    height: parent.height
    clip: true

    Item {
      x: (wipe.width - card.width) / 2
      width: card.width
      height: card.height

      Rectangle { anchors.fill: parent; color: card.black; border.width: 1; border.color: card.dim }
      Image {
        anchors.fill: parent
        fillMode: Image.Tile
        verticalAlignment: Image.AlignTop; horizontalAlignment: Image.AlignLeft
        source: "data:image/svg+xml," + encodeURIComponent(
          "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'><rect width='4' height='1' fill='"
          + card.ink + "' fill-opacity='0.07'/></svg>")
      }

      // The content, painted down as the scan line passes.
      Item {
        id: painted
        width: parent.width
        height: parent.height * card.seg(0.35, 0.85)
        clip: true

        Column {
          id: body
          x: 14; y: 14
          width: card.width - 28 - 60
          spacing: 6

          Item {
            width: parent.width; height: head.implicitHeight
            Text {
              id: head
              text: "◆ " + (card.shownLook ? card.shownLook.label.toUpperCase() : "")
              color: card.ink
              font.family: Style.fontFamily; font.pixelSize: 12; font.bold: true
            }
            Text {
              anchors.right: parent.right
              text: card.t < 0.75 ? "ACQUIRING" : card.buttons.length ? "AWAITING" : "LOCKED"
              color: card.t < 0.75 ? card.bright : card.ink
              opacity: card.t >= 0.75 || Math.floor(card.t * 24) % 2 ? 1 : 0.3
              font.family: Style.fontFamily; font.pixelSize: 12; font.bold: true
            }
          }
          // The scale; for a toast, its time left runs along it.
          Item {
            id: scale
            width: parent.width; height: 5
            Rectangle { width: parent.width; height: 1; color: card.dim }
            Rectangle { width: parent.width * (card.buttons.length ? 1 : card.remaining); height: 1; color: card.ink }
            Repeater {
              model: 25
              delegate: Rectangle {
                required property int index
                x: index * (scale.width - 1) / 24; y: 1
                width: 1; height: index % 4 === 0 ? 4 : 2
                color: card.dim
              }
            }
          }
          Text {
            width: parent.width
            text: card.shown ? card.shown.title || "" : ""
            color: card.ink
            font.family: Style.fontFamily; font.pixelSize: 15; font.bold: true
            font.capitalization: Font.AllUppercase
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
          }
          Text {
            visible: text.length > 0
            width: parent.width
            text: !card.shown ? "" : card.shown.textFn ? card.shown.textFn() : card.shown.text || ""
            color: card.bright
            font.family: Style.fontFamily; font.pixelSize: 12; font.bold: true
            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
          }
        }

        // The badge inside the reticle: the reticle spins down onto it.
        Item {
          x: card.width - 14 - width
          y: Math.max(14, (card.height - height) / 2)
          width: 48; height: 48
          scale: 1 + (1 - card.seg(0.3, 0.75)) * 0.6

          // Once locked, it keeps turning slowly round the badge.
          property real turn: 0
          NumberAnimation on turn { running: card.visible; from: 0; to: 360; duration: 9000; loops: Animation.Infinite }
          Item {
            anchors.fill: parent
            rotation: card.spin * card.spinFrom + parent.turn
            Rectangle { anchors.fill: parent; anchors.margins: 5; radius: width / 2; color: "transparent"; border.width: 1; border.color: card.bright }
            Rectangle { x: parent.width / 2; width: 1; height: 9; color: card.bright }
            Rectangle { x: parent.width / 2; y: parent.height - 9; width: 1; height: 9; color: card.bright }
            Rectangle { y: parent.height / 2; width: 9; height: 1; color: card.bright }
            Rectangle { x: parent.width - 9; y: parent.height / 2; width: 9; height: 1; color: card.bright }
            Rectangle { x: parent.width / 2 - 3; y: 2; width: 7; height: 3; color: card.bright }
          }
          // Centred on the whole circle, not on the glyph's baseline.
          Text {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: card.shownLook ? card.shownLook.glyph : ""
            color: card.ink
            font.pixelSize: 18
          }
          // A legendary achievement keeps pulsing once locked.
          Rectangle {
            visible: !!card.shown && card.shown.rarity === "legendary" && card.t >= 1
            anchors.centerIn: parent
            width: parent.width; height: width; radius: width / 2
            color: "transparent"; border.width: 1; border.color: card.ink
            SequentialAnimation on opacity { running: parent.visible; loops: Animation.Infinite; NumberAnimation { from: 0.8; to: 0; duration: 1200 } }
            SequentialAnimation on scale { running: parent.visible; loops: Animation.Infinite; NumberAnimation { from: 1; to: 1.5; duration: 1200 } }
          }
        }
      }

      // Worn tape over everything.
      Image {
        anchors.fill: parent
        fillMode: Image.Tile
        verticalAlignment: Image.AlignTop; horizontalAlignment: Image.AlignLeft
        source: "data:image/svg+xml," + encodeURIComponent(
          "<svg xmlns='http://www.w3.org/2000/svg' width='3' height='3'><rect width='3' height='1' fill='"
          + card.black + "' fill-opacity='0.6'/></svg>")
      }
      // The scan line and its trail.
      Rectangle {
        visible: card.t > 0.35 && card.t < 0.74
        y: painted.height - height
        width: parent.width; height: 34
        gradient: Gradient {
          GradientStop { position: 0; color: Qt.alpha(card.ink, 0) }
          GradientStop { position: 1; color: Qt.alpha(card.ink, 0.4) }
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: card.bright }
      }
      // The flash of the lock.
      Rectangle {
        anchors.fill: parent
        color: card.bright
        opacity: card.t >= 0.75 ? (1 - card.seg(0.75, 1)) * 0.3 : 0
      }

      // The answers: on hover the card splits into one zone per button.
      Row {
        anchors.fill: parent
        visible: card.buttons.length > 0 && hover.hovered && card.t >= 1
        Repeater {
          model: card.buttons
          Item {
            id: zone
            required property var modelData
            required property int index
            width: card.width / card.buttons.length; height: card.height
            Rectangle {
              anchors.fill: parent
              // Opaque: the card's text does not show through the answer.
              color: zoneArea.containsMouse ? Qt.tint(card.black, Qt.alpha(card.ink, zoneArea.pressed ? 0.45 : 0.28)) : card.black
              border.width: 1
              border.color: zoneArea.containsMouse ? card.bright : card.dim
            }
            Text {
              anchors.centerIn: parent
              text: zone.modelData.text.toUpperCase()
              color: zoneArea.containsMouse ? card.bright : card.ink
              font.family: Style.fontFamily; font.pixelSize: 18; font.bold: true; font.letterSpacing: 2
            }
            MouseArea {
              id: zoneArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: zone.modelData.act()
            }
          }
        }
      }
    }
  }
  // The bright edges of the wipe.
  Rectangle { visible: card.t > 0.1 && card.t < 0.42; x: (card.width - wipe.width) / 2 - 1; width: 2; height: parent.height; color: card.bright }
  Rectangle { visible: card.t > 0.1 && card.t < 0.42; x: (card.width + wipe.width) / 2 - 1; width: 2; height: parent.height; color: card.bright }

  component Bracket: Item {
    property bool onRight: false
    property bool onBottom: false
    width: 14; height: 14
    opacity: card.bracketOpacity
    Rectangle { y: parent.onBottom ? parent.height - 2 : 0; width: parent.width; height: 2; color: card.bright }
    Rectangle { x: parent.onRight ? parent.width - 2 : 0; width: 2; height: parent.height; color: card.bright }
  }
  Bracket { x: -4 - card.spread; y: -4 - card.spread }
  Bracket { x: card.width - width + 4 + card.spread; y: -4 - card.spread; onRight: true }
  Bracket { x: -4 - card.spread; y: card.height - height + 4 + card.spread; onBottom: true }
  Bracket { x: card.width - width + 4 + card.spread; y: card.height - height + 4 + card.spread; onRight: true; onBottom: true }

  HoverHandler { id: hover }
  // A toast goes away on a click.
  TapHandler {
    enabled: card.buttons.length === 0
    onTapped: card.dismissed()
  }
}
