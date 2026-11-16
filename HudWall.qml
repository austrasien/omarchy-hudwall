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
    home: Array.isArray(rawConfig.home) && rawConfig.home.length === 2 ? rawConfig.home : [0, 51.48],
    // The mark at the top of the right column: { image, name }; without it,
    // the machine's name.
    mark: rawConfig.mark && typeof rawConfig.mark === "object" ? rawConfig.mark : null,
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
  // Super+H held: the HUD comes over the windows until the key is let go,
  // coming up like an old VHS tape whose grid drops out tile by tile
  // (shaders/fog.frag), and closing back faster.
  property bool peeking: false
  property bool overWindows: false
  property real reveal: 1
  property real fogTime: 0
  onPeekingChanged: {
    if (peeking) {
      settle.stop(); active = true
      hideFog.stop()
      overWindows = true
      showFog.restart()
    } else if (overWindows) {
      showFog.stop()
      hideFog.restart()
    }
  }
  NumberAnimation { id: showFog; target: root; property: "reveal"; from: 0; to: 1; duration: 550; easing.type: Easing.InOutQuad }
  SequentialAnimation {
    id: hideFog
    NumberAnimation { target: root; property: "reveal"; to: 0; duration: 550; easing.type: Easing.InOutQuad }
    ScriptAction { script: { root.overWindows = false; root.reveal = 1 } }
  }
  NumberAnimation on fogTime { running: root.reveal < 1; from: 0; to: 100; duration: 100000; loops: Animation.Infinite }
  // Brief window flashes (a launcher, a notification popup on the desk)
  // should not stop and restart everything: going inactive waits a little.
  property bool active: false
  readonly property bool wantActive: cfg.visible && (deskEmpty || previewOpen || peeking)
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
    WlrLayershell.layer: root.overWindows ? WlrLayer.Overlay : WlrLayer.Bottom
    // On an empty desk, a click on the HUD can take the keyboard (its fields:
    // tasks, a coffee's time); a field asking for it keeps it while typed in.
    WlrLayershell.keyboardFocus: root.active || hud.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    Hud {
      id: hud
      anchors.fill: parent
      active: root.active
      cfg: root.cfg
      devicePixelRatio: root.targetScreen ? root.targetScreen.devicePixelRatio : 1
      // Only while the fog moves: the effect costs nothing otherwise.
      layer.enabled: root.reveal < 1
      layer.effect: ShaderEffect {
        fragmentShader: Qt.resolvedUrl("shaders/fog.frag.qsb")
        property real reveal: root.reveal
        property real time: root.fogTime
        property real aspect: hud.width / Math.max(1, hud.height)
        property real lines: hud.height / 3
        property color edgeColor: hud.accent
      }
    }
  }

  // While the HUD shows, the hidden bar opens its widgets' panels beside the
  // HUD's bar icons widget (see austraz.bar's hudDock).
  readonly property string dockJson: active && hud.width > 0 ? JSON.stringify(hud.barDock) : ""
  onDockJsonChanged: dockSync.restart()
  Timer {
    id: dockSync
    interval: 200
    onTriggered: Quickshell.execDetached(["omarchy-shell", "omarchy.bar", "hudDock", root.dockJson])
  }

  // Prometheus' messages over every window, hanging from the top edge.
  Herald {
    id: herald
    prom: hud.promData
    targetScreen: root.targetScreen
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
    // For development: a Prometheus or system field as the HUD holds it,
    // e.g. `dump prom.summary` or `dump sys.npu`.
    function dump(path: string): string {
      var parts = path.split(".")
      var o = parts[0] === "sys" ? hud.sysData : hud.promData
      for (var i = 1; i < parts.length && o !== undefined && o !== null; i++) o = o[parts[i]]
      try { return JSON.stringify(o) } catch (e) { return String(o) }
    }
    // `peek on` / `peek off`: bound to Super+H pressed and released.
    function peek(state: string): string { root.peeking = state === "on"; return root.peeking ? "on" : "off" }
    // `geekTest on|off`: show a geek day in the header.
    function geekTest(state: string): string {
      hud.promData.geekDate = state === "on" ? ["towel", "Towel Day", "Carry a towel all day, for Douglas Adams.", "Don't panic"] : null
      return state
    }
    function hitTest(x: string, y: string): string { return hud.hitTest(Number(x), Number(y)) }
    function heraldTest(kind: string): string { return herald.test(kind) }
    function status(): string {
      return JSON.stringify({ active: root.active, deskEmpty: root.deskEmpty, workspace: root.shownWorkspace, preview: root.previewOpen })
    }
  }
}
