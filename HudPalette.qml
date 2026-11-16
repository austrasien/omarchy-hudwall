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

  // Colors for data series, from the theme's hues, each far enough from
  // the others (CIE Lab distance) to be told apart: series(i) cycles them.
  // The accent leads; a hue too close to one already picked is skipped
  // (in Tokyo Night, accent and blue are the same color).
  property var seriesColors: [acc, acc2, mag, cyan, red]
  property real seriesMinDistance: 0
  readonly property real minSeriesGap: 28
  function series(i) { return seriesColors[((i % seriesColors.length) + seriesColors.length) % seriesColors.length] }

  function lab(c) {
    function lin(u) { return u <= 0.04045 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4) }
    var r = lin(c.r), g = lin(c.g), b = lin(c.b)
    var x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    var y = (r * 0.2126 + g * 0.7152 + b * 0.0722)
    var z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
    function f(t) { return t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116 }
    return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))]
  }
  function distance(a, b) {
    var p = lab(a), q = lab(b)
    return Math.sqrt(Math.pow(p[0] - q[0], 2) + Math.pow(p[1] - q[1], 2) + Math.pow(p[2] - q[2], 2))
  }
  function buildSeries(v) {
    var order = ["accent", "green", "magenta", "yellow", "cyan", "red", "orange", "blue",
                 "bright_cyan", "bright_magenta", "bright_green", "bright_yellow", "bright_red", "bright_blue"]
    var out = [], minGap = 1e9
    for (var i = 0; i < order.length; i++) {
      var hex = v[order[i]]
      if (!hex) continue
      var c = Qt.color(hex)
      var near = 1e9
      for (var k = 0; k < out.length; k++) near = Math.min(near, distance(c, out[k]))
      if (out.length && near < minSeriesGap) continue
      if (out.length) minGap = Math.min(minGap, near)
      out.push(c)
    }
    if (out.length >= 2) { seriesColors = out; seriesMinDistance = minGap }
  }

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
    buildSeries(v)
  }
}
