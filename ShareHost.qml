import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../austraz.prometheus" as PromUi

// SHARE from the HUD: Prometheus' share card, built here (off screen, in the
// HUD's own window) rather than by opening Prometheus' panel: the card is
// grabbed frame by frame, every shine a step further, ffmpeg folds the frames
// into a looping animated image, and a save dialog asks where it goes. The
// steps are Prometheus' own (its BarWidget share), with its colours.
Item {
  id: host

  required property var prom
  property bool busy: false

  readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR")
  property string format: "gif"
  readonly property string ext: format === "apng" ? "png" : "gif"
  readonly property string temp: runtime + "/hudwall-share." + ext
  readonly property int frames: 18
  readonly property real scale_: 1.2
  property string target: ""
  function frame(k) { return runtime + "/hudwall-share-" + (k < 10 ? "0" : "") + k + ".png" }

  // What the card reads from its host (Prometheus' bar widget).
  QtObject {
    id: look
    readonly property string fontFamily: Style.font.family
    readonly property color gold: "#e0af68"
    readonly property color green: "#9ece6a"
    readonly property color red: Color.urgent
    readonly property color legendaryColor: "#ffc93c"
  }

  PromUi.ShareCard {
    id: card
    x: -20000
    w: look
  }

  function share() {
    if (busy || !prom.p) return
    busy = true
    prom.p.call("share:get", [], function(ok, d) {
      if (!ok || !d || !d.success) { done("error", "Could not build the card", ""); return }
      card.info = d
      host.format = d.format === "apng" ? "apng" : "gif"
      prom.toast("ended", "Building your card", "a few seconds", "")
      Qt.callLater(function() { host.grab(0) })
    })
  }
  function grab(k) {
    if (k >= frames) { encode(); return }
    // Shifted so the first frame (all a still viewer shows) is mid-shine.
    card.frame = (k / frames + 0.45) % 1
    Qt.callLater(function() {
      var ok = card.grabToImage(function(r) {
        if (!r.saveToFile(host.frame(k))) { host.done("error", "Could not render the card", ""); return }
        host.grab(k + 1)
      }, Qt.size(Math.round(card.width * host.scale_), Math.round(card.height * host.scale_)))
      if (!ok) host.done("error", "Could not render the card", "the HUD is not on screen")
    })
  }
  function encode() {
    // 256 colours, one palette for the whole loop: under 1 MB, no visible loss.
    var args = ["ffmpeg", "-loglevel", "error", "-y", "-framerate", "9",
      "-i", runtime + "/hudwall-share-%02d.png",
      "-vf", "split[a][b];[a]palettegen=max_colors=256:stats_mode=full[p];[b][p]paletteuse=dither=sierra2_4a"]
    encodeProc.command = format === "apng"
      ? args.concat(["-plays", "0", "-f", "apng", temp])
      : args.concat(["-loop", "0", "-f", "gif", temp])
    encodeProc.running = true
  }
  function done(kind, title, text) {
    busy = false
    if (kind) prom.toast(kind, title, text, "")
  }

  Process {
    id: encodeProc
    onExited: function(code) {
      if (code !== 0) { host.done("error", "Could not make the animated card", "ffmpeg failed"); return }
      var day = Qt.formatDate(new Date(), "yyyy-MM-dd")
      saveDialog.command = ["zenity", "--file-selection", "--save", "--confirm-overwrite",
        "--title=Save your Prometheus card",
        host.format === "apng" ? "--file-filter=Animated PNG | *.png" : "--file-filter=GIF image | *.gif",
        "--filename=" + Quickshell.env("HOME") + "/Pictures/prometheus-" + day + "." + host.ext]
      // Over the windows (Super+H), the HUD would hide the dialog.
      Quickshell.execDetached(["omarchy-shell", "austraz.hudwall", "peek", "off"])
      saveDialog.running = true
    }
  }
  Process {
    id: saveDialog
    stdout: StdioCollector {
      onStreamFinished: {
        var path = text.trim()
        if (path === "") { host.done("", "", ""); return }          // cancelled
        if (path.toLowerCase().slice(-4) !== "." + host.ext) path += "." + host.ext
        host.target = path
        copyShare.command = ["cp", "-f", host.temp, path]
        copyShare.running = true
      }
    }
  }
  Process {
    id: copyShare
    onExited: function(code) {
      if (code === 0) host.done("ended", "Card saved", host.target)
      else host.done("error", "Could not save the card", host.target)
    }
  }
}
