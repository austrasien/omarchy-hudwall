import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// Top left, in place of the Omarchy bar: the time and date, the weather, the
// volume (scroll to change, click to mute), the Wi-Fi network, and the
// system tray (click: open, middle click: secondary action, right click:
// the item's menu).
HPanel {
  id: status

  required property var sys
  pad: 10

  // ---- time
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: status.visible; onTriggered: status.now = new Date() }

  // ---- weather, from the Omarchy weather plugin's last reading
  property var weather: null
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/weather-current.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { status.weather = JSON.parse(text()) } catch (e) { status.weather = null } }
  }
  function wmo(code) {
    if (code === undefined || code === null) return ""
    if (code === 0) return "clear"
    if (code <= 2) return "partly cloudy"
    if (code === 3) return "overcast"
    if (code <= 48) return "fog"
    if (code <= 57) return "drizzle"
    if (code <= 67) return "rain"
    if (code <= 77) return "snow"
    if (code <= 82) return "showers"
    if (code <= 86) return "snow showers"
    return "storm"
  }

  // ---- volume
  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: status.sink ? [status.sink] : [] }
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)

  Row {
    spacing: 14
    height: parent.height

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1
      HText {
        text: Qt.formatTime(status.now, "HH:mm")
        color: status.pal.fg; font.pixelSize: 26; font.weight: Font.DemiBold
      }
      HText {
        text: Qt.locale("en_GB").toString(status.now, "ddd d MMM").toUpperCase()
        color: status.pal.dim; font.pixelSize: 9; font.letterSpacing: 2
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      HText {
        text: status.weather ? Math.round(status.weather.tempC) + " °C · " + status.wmo(status.weather.wmoCode) : "–"
        color: status.pal.fg; font.pixelSize: 10
      }
      HText {
        text: (status.muted ? "♪ muted" : "♪ " + Math.round(status.volume * 100) + " %")
        color: volArea.containsMouse ? status.pal.acc : status.pal.dim; font.pixelSize: 10
        MouseArea {
          id: volArea
          anchors.fill: parent; anchors.margins: -3
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (status.sink && status.sink.audio) status.sink.audio.muted = !status.sink.audio.muted
          onWheel: function(wheel) {
            if (!status.sink || !status.sink.audio) return
            var v = status.sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)
            status.sink.audio.volume = Math.max(0, Math.min(1, v))
          }
        }
      }
      HText {
        text: "⌔ " + (status.sys.net.ssid || status.sys.net.iface || "offline")
        color: status.pal.dim; font.pixelSize: 10
      }
    }
  }

  // The system tray, top right of the panel.
  Flow {
    anchors.right: parent.right
    anchors.top: parent.top
    width: Math.min(110, parent.width * 0.4)
    layoutDirection: Qt.RightToLeft
    spacing: 6
    Repeater {
      model: SystemTray.items
      Item {
        id: trayItem
        required property var modelData
        width: 16; height: 16
        IconImage {
          anchors.fill: parent
          source: trayItem.modelData.icon
          implicitSize: 16
        }
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) {
            var it = trayItem.modelData
            if (mouse.button === Qt.RightButton || it.onlyMenu) {
              if (it.hasMenu) {
                var pt = trayItem.QsWindow.contentItem.mapFromItem(trayItem, mouse.x, mouse.y)
                it.display(trayItem.QsWindow.window, pt.x, pt.y)
              }
            } else if (mouse.button === Qt.MiddleButton) it.secondaryActivate()
            else it.activate()
          }
          onWheel: function(wheel) { trayItem.modelData.scroll(wheel.angleDelta.y, false) }
        }
      }
    }
  }
}
