import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray

// The small status pill shown top left while the HUD is covered by windows
// (the Omarchy bar is off): time and date, weather, volume (scroll to
// change, click to mute) and the system tray.
Rectangle {
  id: pill

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: pill.visible; onTriggered: pill.now = new Date() }

  HudPalette { id: pal }

  implicitWidth: row.implicitWidth + 24
  implicitHeight: 28
  radius: height / 2
  color: pal.alpha(pal.bg, 0.88)
  border.width: 1
  border.color: pal.alpha(pal.acc, 0.25)

  property var weather: null
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/weather-current.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { pill.weather = JSON.parse(text()) } catch (e) { pill.weather = null } }
  }

  readonly property var sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: pill.sink ? [pill.sink] : [] }
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 12
    HText {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatTime(pill.now, "HH:mm")
      color: pal.fg; font.pixelSize: 13; font.weight: Font.DemiBold
    }
    HText {
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.locale("en_GB").toString(pill.now, "ddd d MMM")
      color: pal.dim; font.pixelSize: 11
    }
    HText {
      visible: !!pill.weather
      anchors.verticalCenter: parent.verticalCenter
      text: pill.weather ? Math.round(pill.weather.tempC) + " °C" : ""
      color: pal.dim; font.pixelSize: 11
    }
    HText {
      anchors.verticalCenter: parent.verticalCenter
      text: pill.muted ? "♪ muted" : "♪ " + Math.round(pill.volume * 100) + "%"
      color: volArea.containsMouse ? pal.acc : pal.dim; font.pixelSize: 11
      MouseArea {
        id: volArea
        anchors.fill: parent; anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (pill.sink && pill.sink.audio) pill.sink.audio.muted = !pill.sink.audio.muted
        onWheel: function(wheel) {
          if (!pill.sink || !pill.sink.audio) return
          var v = pill.sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)
          pill.sink.audio.volume = Math.max(0, Math.min(1, v))
        }
      }
    }
    Repeater {
      model: SystemTray.items
      Item {
        id: trayItem
        required property var modelData
        anchors.verticalCenter: parent.verticalCenter
        width: 16; height: 16
        IconImage { anchors.fill: parent; source: trayItem.modelData.icon; implicitSize: 16 }
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
