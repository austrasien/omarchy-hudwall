import QtQuick
import Quickshell
import Quickshell.Io

// The current Omarchy theme's colors.toml, read directly: Commons.Color
// only carries foreground, background, accent, urgent and muted, and the
// HUD wants the cyan, blue and magenta of the theme too.
QtObject {
  id: pal

  property color bg: "#0e0e10"
  property color bgLight: "#161618"
  property color fg: "#f5f5f7"
  property color dim: "#98989d"
  property color mut: "#5a5a60"
  property color acc: "#ff9f0a"
  property color acc2: "#ffb340"
  property color cyan: "#a6dcef"
  property color blue: "#8fb8de"
  property color mag: "#ff8fa3"
  property color red: "#ff5f4a"

  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  // A color as a CSS string, for Canvas.
  function css(c, a) {
    return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + (a === undefined ? c.a : a) + ")"
  }

  readonly property string path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"

  property FileView file: FileView {
    path: pal.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: pal.parse(text())
  }

  function parse(t) {
    var v = {}
    var lines = (t || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = lines[i].match(/^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"/)
      if (m) v[m[1]] = m[2]
    }
    function pick() {
      for (var k = 0; k < arguments.length; k++) if (v[arguments[k]]) return v[arguments[k]]
      return null
    }
    var c
    if ((c = pick("darker_background", "background"))) bg = c
    if ((c = pick("lighter_background", "background"))) bgLight = c
    if ((c = pick("foreground"))) fg = c
    if ((c = pick("dark_foreground", "muted"))) dim = c
    if ((c = pick("selection", "muted"))) mut = Qt.lighter(c, 1.4)
    if ((c = pick("accent"))) acc = c
    if ((c = pick("bright_green", "bright_yellow", "accent"))) acc2 = c
    if ((c = pick("cyan"))) cyan = c
    if ((c = pick("blue"))) blue = c
    if ((c = pick("magenta"))) mag = c
    if ((c = pick("red"))) red = c
  }
}
