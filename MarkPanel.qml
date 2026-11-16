import QtQuick
import QtQuick.Effects
import Quickshell

// The company mark with the machine: host name, kernel, time since boot.
// The mark and its name come from hudwall.json (`mark`); without them, the
// host name.
Item {
  id: mp

  required property var pal
  required property var sys
  // { image: path, name: text } from the config.
  property var mark: null
  readonly property string markImage: mark && mark.image ? String(mark.image).replace(/^~/, Quickshell.env("HOME")) : ""

  function uptime(s) {
    s = Math.max(0, s || 0)
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return (d > 0 ? d + " d " : "") + h + " h " + String(m).padStart(2, "0")
  }

  HPanel {
    pal: mp.pal
    anchors.fill: parent
    pad: 10
    tip: "This machine: host name, kernel, time since boot (the mark and name are set in hudwall.json)."

    Image {
      id: logo
      x: 2
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height - 2
      width: mp.markImage ? height * Math.max(0.5, implicitWidth / Math.max(1, implicitHeight)) : 0
      source: mp.markImage ? "file://" + mp.markImage : ""
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
      visible: false
    }
    MultiEffect {
      anchors.fill: logo
      source: logo
      colorization: 1.0
      colorizationColor: mp.pal.fg
    }
    Column {
      x: logo.width + (logo.width > 0 ? 16 : 4)
      width: parent.width - x
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      HText { text: mp.mark && mp.mark.name ? mp.mark.name : (mp.sys.host.name || "").toUpperCase(); color: mp.pal.fg; font.pixelSize: 14; font.letterSpacing: 4; font.weight: Font.DemiBold }
      HText { width: parent.width; text: (mp.sys.host.name || "") + " · " + (mp.sys.host.kernel || ""); color: mp.pal.dim; font.pixelSize: 9 }
      HText { text: "up " + mp.uptime(mp.sys.host.uptime); color: mp.pal.mut; font.pixelSize: 9 }
    }
  }
}
