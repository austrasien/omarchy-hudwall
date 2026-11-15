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
    width: 1440
    height: 960
    scale: hud.k
    transformOrigin: Item.TopLeft
    x: (hud.width - 1440 * hud.k) / 2
    y: (hud.height - 960 * hud.k) / 2

    // A faint glow behind the globe.
    Rectangle {
      x: 720 - 420; y: 420 - 420; width: 840; height: 840; radius: 420
      gradient: Gradient {
        GradientStop { position: 0; color: theme.alpha(theme.acc, 0.05) }
        GradientStop { position: 0.6; color: "transparent" }
      }
      opacity: 0.8
    }

    Constellation {
      x: 720 - 400; y: 448 - 400; width: 800; height: 800
      pal: theme
      pixelScale: hud.pixelScale
      year: prom.year
      season: prom.season
    }

    PromLeft {
      x: 104; y: 28
      pal: theme; prom: prom
    }
    Center {
      id: center
      x: 440; y: 28
      pal: theme; prom: prom; sys: sys
      active: hud.active
      animate: hud.active && !hud.lowPower
      cfg: hud.cfg
      pixelScale: hud.pixelScale
    }
    SysRight {
      x: 1006; y: 28
      pal: theme; sys: sys; prom: prom
      pixelScale: hud.pixelScale
    }
    BottomRow {
      x: 104; y: 756
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
      x: 720 - width / 2; y: 940
      text: "BATTERIE FAIBLE · ANIMATIONS EN PAUSE"
      color: theme.red; font.pixelSize: 9; font.letterSpacing: 2
    }

    HText {
      visible: !prom.live
      x: 720 - width / 2; y: 12
      text: "PROMETHEUS HORS LIGNE"
      color: theme.red; font.pixelSize: 9; font.letterSpacing: 2
    }
  }
}
