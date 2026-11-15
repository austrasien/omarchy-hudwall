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
  readonly property bool wantsKeyboard: center.wantsKeyboard

  readonly property real k: Math.min(width / 1440, height / 960)
  readonly property real pixelScale: k * devicePixelRatio

  // The stage fills the screen, at least 1440 x 960 units. The side rails
  // (the day tape on the left, the day bar on the right) are kept clear:
  // cfg.margins = [left, right] in screen pixels.
  readonly property real stageW: width / k
  readonly property real stageH: height / k
  readonly property var margins: Array.isArray(cfg.margins) && cfg.margins.length === 2 ? cfg.margins : [40, 84]
  readonly property real mL: margins[0] / k + 16
  readonly property real mR: margins[1] / k + 16
  readonly property real avail: stageW - mL - mR
  readonly property real gap: 16
  readonly property real colW: Math.max(300, Math.min(460, (avail - 560 - 2 * gap) / 2))
  readonly property real centerX: mL + colW + gap + (avail - 2 * colW - 2 * gap - 560) / 2

  HudPalette { id: theme }
  // On a low battery the HUD stays up but stops moving.
  readonly property bool lowPower: sys.bat.status === "Discharging" && sys.bat.pct !== undefined && sys.bat.pct <= 15
  Sys { id: sys; active: hud.active }
  Prom { id: prom; active: hud.active }

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
      x: hud.centerX + 280 - 420; y: 448 - 420; width: 840; height: 840; radius: 420
      gradient: Gradient {
        GradientStop { position: 0; color: theme.alpha(theme.acc, 0.05) }
        GradientStop { position: 0.6; color: "transparent" }
      }
      opacity: 0.8
    }

    Constellation {
      x: hud.centerX + 280 - 400; y: 448 - 400; width: 800; height: 800
      pal: theme
      pixelScale: hud.pixelScale
      year: prom.year
      season: prom.season
    }

    PromLeft {
      x: hud.mL; y: 28
      width: hud.colW
      pal: theme; prom: prom
    }
    Center {
      id: center
      x: hud.centerX; y: 28
      pal: theme; prom: prom; sys: sys
      active: hud.active
      animate: hud.active && !hud.lowPower
      cfg: hud.cfg
      pixelScale: hud.pixelScale
    }
    SysRight {
      x: hud.stageW - hud.mR - hud.colW; y: 28
      width: hud.colW
      pal: theme; sys: sys; prom: prom
      pixelScale: hud.pixelScale
    }
    BottomRow {
      x: hud.mL; y: Math.max(756, hud.stageH - 204)
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
      x: hud.centerX + 280 - width / 2; y: hud.stageH - 20
      text: "LOW BATTERY · ANIMATIONS PAUSED"
      color: theme.red; font.pixelSize: 9; font.letterSpacing: 2
    }

    HText {
      visible: !prom.live
      x: hud.centerX + 280 - width / 2; y: 12
      text: "PROMETHEUS OFFLINE"
      color: theme.red; font.pixelSize: 9; font.letterSpacing: 2
    }
  }
}
