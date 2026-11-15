import QtQuick
import qs.Commons

// Big moments, one after the other: a level up, a medal, an epic or
// legendary achievement, a challenge won. They wait in a queue while the
// desk is covered and play when it shows again, four seconds each.
Item {
  id: cel

  required property var pal
  required property var prom
  property bool active: false

  property var queue: []
  property var current: null

  function push(item) {
    queue = queue.concat([item])
    if (!current) next()
  }
  function next() {
    if (!active || !queue.length) { current = null; return }
    current = queue[0]
    queue = queue.slice(1)
    hold.restart()
  }
  onActiveChanged: if (active && !current) next()

  Timer { id: hold; interval: 4200; onTriggered: { cel.current = null; gap.restart() } }
  Timer { id: gap; interval: 500; onTriggered: cel.next() }

  Connections {
    target: cel.prom
    function onToast(kind, title, text, rarity) {
      if (kind === "medal") cel.push({ k: "MEDAL", t: title, s: text, c: cel.pal.acc2 })
      else if (kind === "achievement" && (rarity === "epic" || rarity === "legendary"))
        cel.push({ k: rarity === "legendary" ? "LEGENDARY ACHIEVEMENT" : "EPIC ACHIEVEMENT", t: title, s: text, c: rarity === "legendary" ? cel.pal.acc2 : cel.pal.mag })
      else if (kind === "won") cel.push({ k: "CHALLENGE WON", t: title, s: text, c: cel.pal.cyan })
    }
  }
  // Level ups are not toasts: watch the level.
  property int lastLevel: -1
  readonly property int level: prom.p && prom.p.profile ? prom.p.profile.level : -1
  onLevelChanged: {
    if (lastLevel > 0 && level > lastLevel) push({ k: "LEVEL UP", t: "LEVEL " + level, s: "", c: pal.acc })
    if (level > 0) lastLevel = level
  }

  visible: opacity > 0
  opacity: current ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }

  Rectangle {
    anchors.centerIn: parent
    width: 720; height: 220; radius: 110
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0; color: "transparent" }
      GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.7) }
      GradientStop { position: 1; color: "transparent" }
    }
  }
  Column {
    anchors.centerIn: parent
    spacing: 8
    scale: cel.current ? 1 : 0.96
    Behavior on scale { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }
    HText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: cel.current ? cel.current.k : ""
      color: cel.pal.dim; font.pixelSize: 11; font.letterSpacing: 6
    }
    HText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: cel.current ? cel.current.t.toUpperCase() : ""
      color: cel.current ? cel.current.c : cel.pal.fg
      font.pixelSize: 46; font.letterSpacing: 10; font.weight: Font.DemiBold
    }
    HText {
      anchors.horizontalCenter: parent.horizontalCenter
      width: Math.min(implicitWidth, 640)
      text: cel.current ? cel.current.s : ""
      color: cel.pal.fg; font.pixelSize: 12
    }
  }
}
