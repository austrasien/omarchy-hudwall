import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// A live HUD on the Bottom layer: above the wallpaper (OWE and Omarchy's
// background are on Background), under every window. It only animates and
// collects while the focused desk has no window, so it costs nothing while
// it cannot be seen.
//
// Settings are in ~/.config/omarchy/hudwall.json (see the README).
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string home: Quickshell.env("HOME")
  readonly property string configPath: home + "/.config/omarchy/hudwall.json"

  // ------------------------------------------------------------ config

  property var rawConfig: ({})
  readonly property var cfg: ({
    visible: rawConfig.visible !== false,
    monitor: typeof rawConfig.monitor === "string" ? rawConfig.monitor : "",
    // 1: the HUD paints its own backdrop; below 1 the wallpaper shows through.
    backdrop: typeof rawConfig.backdrop === "number" ? Math.max(0, Math.min(1, rawConfig.backdrop)) : 1,
    home: Array.isArray(rawConfig.home) && rawConfig.home.length === 2 ? rawConfig.home : [2.35, 48.85],
    fps: typeof rawConfig.fps === "number" ? Math.max(5, Math.min(60, rawConfig.fps)) : 24
  })

  FileView {
    id: configFile
    path: root.configPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.rawConfig = JSON.parse(text() || "{}") } catch (e) { console.warn("hudwall: bad config", e) }
    }
    onLoadFailed: root.rawConfig = ({})
  }

  // ------------------------------------------------------------ screen

  readonly property var targetScreen: {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++)
      if (screens[i].name === cfg.monitor) return screens[i]
    return screens.length ? screens[0] : null
  }
  readonly property var targetMonitor: targetScreen ? Hyprland.monitorFor(targetScreen) : null

  // ------------------------------------------------------------ activity
  //
  // The HUD is seen only when the workspace shown on its monitor holds no
  // mapped window. Everything that costs (animations, the collector, the
  // slow Prometheus calls) follows `active`.

  readonly property int shownWorkspace: targetMonitor && targetMonitor.activeWorkspace ? targetMonitor.activeWorkspace.id : -1
  // A special workspace (scratchpad) shown on top covers the desk too.
  readonly property bool specialShown: {
    var m = root.targetMonitor
    var ipc = m && m.lastIpcObject ? m.lastIpcObject : {}
    return !!(ipc.specialWorkspace && ipc.specialWorkspace.id !== 0)
  }
  readonly property bool deskEmpty: {
    var ws = root.shownWorkspace
    if (ws === -1 || root.specialShown) return false
    var values = Hyprland.toplevels.values
    for (var i = 0; i < values.length; i++) {
      var t = values[i]
      var ipc = t.lastIpcObject || {}
      if (ipc.mapped === false || ipc.hidden === true) continue
      if (t.workspace && t.workspace.id === ws) return false
    }
    return true
  }
  property bool previewOpen: false
  // Brief window flashes (a launcher, a notification popup on the desk)
  // should not stop and restart everything: going inactive waits a little.
  property bool active: false
  readonly property bool wantActive: cfg.visible && (deskEmpty || previewOpen)
  onWantActiveChanged: {
    if (wantActive) { settle.stop(); active = true }
    else settle.restart()
  }
  Component.onCompleted: active = wantActive
  Timer { id: settle; interval: 3000; onTriggered: root.active = root.wantActive }

  // Hyprland only sends toplevel events; refresh the IPC objects so
  // `mapped` and `hidden` stay true to life.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var n = event.name
      if (n === "openwindow" || n === "closewindow" || n === "movewindowv2" || n === "workspacev2" || n === "focusedmonv2" || n === "activespecial")
        refresh.restart()
    }
  }
  Timer { id: refresh; interval: 120; onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshMonitors() } }

  // ------------------------------------------------------------ surface

  PanelWindow {
    id: win
    screen: root.targetScreen
    visible: root.cfg.visible && root.targetScreen !== null
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }

    WlrLayershell.namespace: "austraz-hudwall"
    WlrLayershell.layer: WlrLayer.Bottom
    // The task field asks for the keyboard only while it is being typed in.
    WlrLayershell.keyboardFocus: hud.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    Hud {
      id: hud
      anchors.fill: parent
      active: root.active
      cfg: root.cfg
      devicePixelRatio: root.targetScreen ? root.targetScreen.devicePixelRatio : 1
    }
  }

  // A window with the same HUD, to look at it without emptying a desk.
  FloatingWindow {
    id: preview
    visible: root.previewOpen
    title: "HUD wallpaper preview"
    color: "black"
    implicitWidth: 1440
    implicitHeight: 960

    Loader {
      anchors.fill: parent
      active: root.previewOpen
      sourceComponent: Component {
        Hud { active: root.active; cfg: root.cfg; devicePixelRatio: root.targetScreen ? root.targetScreen.devicePixelRatio : 1 }
      }
    }
  }

  IpcHandler {
    target: "austraz.hudwall"
    function preview(): string { root.previewOpen = !root.previewOpen; return root.previewOpen ? "open" : "closed" }
    function status(): string {
      return JSON.stringify({ active: root.active, deskEmpty: root.deskEmpty, workspace: root.shownWorkspace, preview: root.previewOpen })
    }
  }
}
