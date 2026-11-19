import QtQuick
import Quickshell

// The HUD itself, laid out on a 1440 x 960 grid and scaled to whatever it
// is given (2304 x 1536 on the Framework at 1.25). Text and Shapes stay
// sharp under the scale; Canvases render at the real pixel size.
Item {
  id: hud

  property bool active: false
  property var cfg: ({})
  property real devicePixelRatio: 1
  readonly property bool wantsKeyboard: center.wantsKeyboard || bottomRow.wantsKeyboard

  readonly property real k: Math.min(width / 1440, height / 960)
  readonly property real pixelScale: k * devicePixelRatio

  // The stage fills the screen, at least 1440 x 960 units, with the same
  // margin all around (`edge` units), counted on the sides from the inner
  // edge of the day tape and day bar rails (about 12 px each):
  // cfg.margins = [left, right] in screen pixels.
  readonly property real stageW: width / k
  readonly property real stageH: height / k
  readonly property var margins: Array.isArray(cfg.margins) && cfg.margins.length === 2 ? cfg.margins : [12, 12]
  readonly property real edge: 28
  readonly property real mL: margins[0] / k + edge
  readonly property real mR: margins[1] / k + edge
  readonly property real avail: stageW - mL - mR
  readonly property real gap: 16
  readonly property real colW: Math.max(270, Math.min(300, avail * 0.21))
  readonly property real centerX: mL + colW + gap
  readonly property real centerW: avail - 2 * colW - 2 * gap
  // The bar icons widget, top left, in screen pixels: the hidden bar opens
  // its panels to the right of it, top-aligned.
  // `gap`: the space between two panels of a column (10 units), so the
  // panels keep the same distance from the widget.
  // The bar's icons sit at the top of the right column: the bar's panels
  // open left of them (austraz.bar's hudDock `left`).
  readonly property var barDock: ({ left: Math.round(x + (stageW - mR - colW) * k), top: Math.round(y + edge * k), gap: Math.round(10 * k) })
  readonly property real bottomY: stageH - edge - 176
  // Where the globe ends up, in stage units.
  readonly property real globeX: centerX + center.gx
  readonly property real globeY: edge + center.gy

  property string paletteFile: ""
  property int barIconsTest: 0
  property int beaconPeek: -1
  HudPalette { id: theme; colorsFile: hud.paletteFile }
  readonly property color accent: theme.acc
  // On a low battery the HUD stays up but stops moving.
  readonly property bool lowPower: sys.bat.status === "Discharging" && sys.bat.pct !== undefined && sys.bat.pct <= 15
  Sys { id: sys; active: hud.active; beat: hud.beat }
  // The HUD's one clock for whatever keeps moving (the globe's sweep, the
  // season ribbon's shine, the ghosts): eight steps a second, all on the
  // same frames. Any running Qt animation, a pause included, would redraw
  // the whole HUD at 60 fps for as long as it runs.
  property int beat: 0
  Timer { interval: 125; repeat: true; running: hud.active && !hud.lowPower; onTriggered: hud.beat++ }
  Prom { id: prom; active: hud.active }
  // For development: the chain of topmost items at a screen point.
  function hitTest(x, y) {
    var out = [], it = hud, px = x, py = y
    for (var d = 0; d < 30 && it; d++) {
      var c = it.childAt(px, py)
      if (!c) break
      var pt = it.mapToItem(c, px, py)
      out.push(String(c).split("(")[0].replace(/_QMLTYPE_\d+/, "") + " z" + c.z + " @" + Math.round(pt.x) + "," + Math.round(pt.y) + " in " + Math.round(c.width) + "x" + Math.round(c.height))
      it = c; px = pt.x; py = pt.y
    }
    return out.join(" > ")
  }
  readonly property var promData: prom
  readonly property var sysData: sys

  Rectangle {
    anchors.fill: parent
    opacity: hud.cfg.backdrop === undefined ? 1 : hud.cfg.backdrop
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.darker(theme.bg, 1.1) }
      GradientStop { position: 0.45; color: theme.bg }
      GradientStop { position: 1; color: Qt.darker(theme.bg, 1.6) }
    }
  }

  // Hidden behind windows, nothing is drawn: the stage only renders while
  // the HUD can be seen (the backdrop stays, for the gaps between windows).
  Item {
    id: stage
    visible: hud.active
    width: hud.stageW
    height: hud.stageH
    scale: hud.k
    transformOrigin: Item.TopLeft

    // A faint glow behind the globe.
    Rectangle {
      x: hud.globeX - 420; y: hud.globeY - 420; width: 840; height: 840; radius: 420
      gradient: Gradient {
        GradientStop { position: 0; color: theme.alpha(theme.acc, 0.05) }
        GradientStop { position: 0.6; color: "transparent" }
      }
      opacity: 0.8
    }

    Constellation {
      x: hud.globeX - 400 * center.gs; y: hud.globeY - 400 * center.gs; width: 800 * center.gs; height: 800 * center.gs
      inner: 272 * center.gs
      pal: theme
      pixelScale: hud.pixelScale
      year: prom.year
      season: prom.season
    }

    PromLeft {
      beat: hud.beat
      mark: hud.cfg.mark || null
      x: hud.mL; y: hud.edge
      width: hud.colW
      pal: theme; prom: prom; sys: sys
    }
    Center {
      id: center
      beat: hud.beat
      x: hud.centerX; y: hud.edge
      width: hud.centerW
      height: hud.bottomY - hud.edge - 10
      pal: theme; prom: prom; sys: sys
      active: hud.active
      animate: hud.active && !hud.lowPower
      cfg: hud.cfg
      pixelScale: hud.pixelScale
      beaconPeek: hud.beaconPeek
    }
    SysRight {
      barIconsTest: hud.barIconsTest
      x: hud.stageW - hud.mR - hud.colW; y: hud.edge
      width: hud.colW
      pal: theme; sys: sys; prom: prom
      pixelScale: hud.pixelScale
    }
    BottomRow {
      id: bottomRow
      beat: hud.beat
      x: hud.mL; y: hud.bottomY
      width: hud.avail
      pal: theme; sys: sys; prom: prom
      pixelScale: hud.pixelScale
    }

    Celebration {
      anchors.fill: parent
      pal: theme; prom: prom
      active: hud.active
    }
    Announcement {
      anchors.fill: parent
      pal: theme; prom: prom
    }
    HText {
      visible: hud.lowPower
      x: hud.globeX - width / 2; y: hud.stageH - 20
      text: "LOW BATTERY · ANIMATIONS PAUSED"
      color: theme.red; font.pixelSize: 9; font.letterSpacing: 2
    }

    HText {
      visible: !prom.live
      x: hud.globeX - width / 2; y: 12
      text: "PROMETHEUS OFFLINE"
      color: theme.red; font.pixelSize: 9; font.letterSpacing: 2
    }
  }
}
