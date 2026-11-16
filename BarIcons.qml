import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// The Omarchy bar's icons, on the HUD (the bar itself is hidden): one cell
// per bar widget, with its state, and a click opens that widget's own panel
// through its IPC target; the system tray's icons follow.
HPanel {
  id: bar

  required property var sys
  pad: 10

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: bar.visible; onTriggered: bar.now = new Date() }

  property var weather: null
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/weather-current.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { bar.weather = JSON.parse(text()) } catch (e) { bar.weather = null } }
  }

  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: bar.sink ? [bar.sink] : [] }
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool btOn: !!(adapter && adapter.enabled)

  property string layout: ""
  Process {
    id: kb
    command: ["hyprctl", "devices", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(this.text)
          var k = (d.keyboards || []).filter(function(x) { return x.main })[0] || (d.keyboards || [])[0]
          bar.layout = k ? String(k.active_keymap || "").slice(0, 2).toLowerCase() : ""
        } catch (e) {}
      }
    }
  }
  Timer { interval: 15000; repeat: true; running: bar.visible; triggeredOnStart: true; onTriggered: kb.running = true }

  function g(cp) { return String.fromCodePoint(cp) }
  function batteryGlyph(p, charging) {
    if (charging) return g(0xF0084)
    var steps = [0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E, 0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]
    return g(steps[Math.max(0, Math.min(10, Math.round((p || 0) / 10)))])
  }
  function open(target, fn, args) {
    Quickshell.execDetached(["omarchy-shell", target, fn || "toggle"].concat(args || []))
  }

  // One cell per widget of the bar, in its order.
  readonly property var cells: [
    { glyph: Qt.formatTime(now, "HH:mm"), text: true, value: Qt.locale("en_GB").toString(now, "ddd d"), target: "austraz.clock", tip: "clock" },
    { glyph: weather ? Math.round(weather.tempC) + "°" : "–", text: true, value: "weather", target: "omarchy.weather" },
    { glyph: g(0xF0EF2), value: "zones", target: "omarchy.elsewhen" },
    { glyph: muted ? g(0xF075F) : g(0xF057E), value: muted ? "mute" : Math.round(volume * 100) + "%", target: "omarchy.audio", on: !muted },
    { glyph: sys.net.ssid ? g(0xF05A9) : g(0xF05AA), value: sys.net.ssid ? "wi-fi" : "offline", target: "omarchy.network", on: !!sys.net.iface },
    { glyph: btOn ? g(0xF00AF) : g(0xF00B2), value: btOn ? "on" : "off", target: "omarchy.bluetooth", on: btOn },
    { glyph: g(0xF0582), value: sys.tail.up ? "up" : "down", target: "omarchy.tailscale", on: !!sys.tail.up },
    { glyph: g(0xF0582), value: "vpn", target: "io.github.guiestrela.nordvpn" },
    { glyph: batteryGlyph(sys.bat.pct, sys.bat.status === "Charging"), value: (sys.bat.pct !== undefined ? sys.bat.pct + "%" : "–"), target: "austraz.power", on: (sys.bat.pct || 100) > 15 },
    { glyph: g(0xF06A9), value: "agents", target: "omarchy.agents" },
    { glyph: g(0xF0238), value: "focus", target: "austraz.prometheus", fn: "openTab", args: ["session"] },
    { glyph: g(0xF0379), value: "screens", target: "im0001gt.screens" },
    { glyph: g(0xF0100), value: "camguard", target: "austraz.camguard" },
    { glyph: g(0xF011C), value: "flux", target: "shell", fn: "toggle", args: ["flux", "{}"] },
    { glyph: g(0xF030C), value: layout || "kbd", target: "" }
  ]

  Flow {
    width: parent.width
    spacing: 4
    Repeater {
      model: bar.cells
      Item {
        id: cell
        required property var modelData
        width: modelData.text ? 36 : 26; height: 26
        Rectangle {
          anchors.fill: parent
          radius: 3
          color: area.containsMouse && area.armed && cell.modelData.target ? bar.pal.alpha(bar.pal.acc, 0.16) : "transparent"
        }
        HText {
          anchors.horizontalCenter: parent.horizontalCenter
          y: 1
          text: cell.modelData.glyph
          color: cell.modelData.on === false ? bar.pal.mut : bar.pal.fg
          font.pixelSize: cell.modelData.text ? 12 : 14
          font.weight: cell.modelData.text ? Font.DemiBold : Font.Normal
        }
        HText {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          width: parent.width; horizontalAlignment: Text.AlignHCenter
          text: cell.modelData.value
          color: bar.pal.dim; font.pixelSize: 7
        }
        MouseArea {
          id: area
          // A panel opening over the HUD takes the pointer without a leave
          // event: the highlight goes on click, back on the next move in.
          property bool armed: true
          anchors.fill: parent
          hoverEnabled: true
          enabled: !!cell.modelData.target
          cursorShape: Qt.PointingHandCursor
          onEntered: armed = true
          onPositionChanged: armed = true
          onClicked: { armed = false; bar.open(cell.modelData.target, cell.modelData.fn, cell.modelData.args) }
        }
      }
    }
    // The system tray.
    Repeater {
      model: SystemTray.items
      Item {
        id: trayItem
        required property var modelData
        width: 26; height: 26
        IconImage {
          id: trayIcon
          anchors.horizontalCenter: parent.horizontalCenter
          y: 2
          implicitSize: 14
          source: trayItem.modelData.icon
          visible: false
          layer.enabled: true
        }
        // The icon's shape filled with the text colour, like the other cells.
        Rectangle {
          id: trayFill
          anchors.fill: trayIcon
          color: bar.pal.fg
          visible: false
          layer.enabled: true
        }
        MultiEffect {
          anchors.fill: trayIcon
          source: trayFill
          maskEnabled: true
          maskSource: trayIcon
          maskThresholdMin: 0.2
          maskSpreadAtMin: 0.2
        }
        HText {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          width: parent.width; horizontalAlignment: Text.AlignHCenter
          text: String(trayItem.modelData.title || trayItem.modelData.id || "").toLowerCase()
          color: bar.pal.dim; font.pixelSize: 7
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
