import QtQuick
import qs.Commons

// A league or season end, full screen, until it is acknowledged; then the
// daemon is told (announce:seen). Nothing is marked seen without a click.
Item {
  id: ann

  required property var pal
  required property var prom
  readonly property var a: prom.p && prom.p.announcements && prom.p.announcements.length ? prom.p.announcements[0] : null
  readonly property string grade: a && a.kind === "season" ? (a.grade || "") : ""

  visible: opacity > 0
  opacity: a ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: Style.duration(240); easing.type: Easing.OutCubic } }

  readonly property color tint: !a ? pal.cyan
    : a.kind === "league" ? (a.after && a.after.color ? a.after.color : pal.cyan)
    : pal.acc2

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.55) }
      GradientStop { position: 0.5; color: Qt.rgba(0, 0, 0, 0.75) }
      GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
    }
  }
  MouseArea { anchors.fill: parent }   // the HUD under it stays still

  Column {
    anchors.centerIn: parent
    spacing: 10
    HText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: !ann.a ? "" : ann.a.kind === "league"
        ? "END OF WEEK · " + (ann.a.outcome === "up" ? "PROMOTED" : ann.a.outcome === "down" ? "RELEGATED" : "STAYED")
        : "END OF SEASON · " + (ann.a.label || "")
      color: ann.pal.dim; font.pixelSize: 11; font.letterSpacing: 6
    }
    HText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: !ann.a ? "" : ann.a.kind === "league" ? (ann.a.after ? ann.a.after.name.toUpperCase() : "") : (ann.grade ? "GRADE " + ann.grade : "SEASON OVER")
      color: ann.tint
      font.pixelSize: 60; font.letterSpacing: 18; font.weight: Font.DemiBold
      style: Text.Raised; styleColor: Qt.rgba(ann.tint.r, ann.tint.g, ann.tint.b, 0.4)
    }
    HText {
      anchors.horizontalCenter: parent.horizontalCenter
      text: !ann.a ? "" : ann.a.kind === "league"
        ? "rank " + ann.a.rank + " · " + ann.a.xp + " XP" + (ann.a.before ? " · before: " + ann.a.before.name : "")
        : ann.a.xp + " XP · goals " + ann.a.goal + " / " + ann.a.hardGoal + " · " + ann.a.bars + " bar(s)"
      color: ann.pal.fg; font.pixelSize: 12
    }
    HButton {
      anchors.horizontalCenter: parent.horizontalCenter
      pal: ann.pal; tone: "c"; text: "OK"; size: 11
      onClicked: if (ann.a) ann.prom.act("announce:seen", [ann.a.id])
    }
  }
}
