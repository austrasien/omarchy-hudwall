import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Widgets

// The globe: the Earth itself is a shader (shaders/globe.frag) reading the
// land mask written by bin/hudwall-fetch-data; on top, a light Canvas draws
// the arcs from home to the last network peers, with packets running along.
// It turns only while `active`, at `fps`.
Item {
  id: globe

  required property var pal
  property bool active: false
  property real fps: 24
  property var home: [0, 51.48]
  property var peers: []          // [{ lat, lon, proc, city, live }]
  property real radius: 170
  property real tilt: 25
  property real pixelScale: 1

  property real lon0: home[0] - 20
  property real phase: 0

  // Where the globe looks: the smallest span of longitudes holding home and
  // every route's end (the circle cut at its widest empty gap). When it fits
  // in the visible face, the globe settles on its middle and stays; when it
  // does not, it sweeps left and right over that span only.
  readonly property real faceHalf: 65
  readonly property var span: {
    var l = [globe.home[0]]
    var list = globe.peers || []
    for (var i = 0; i < list.length; i++) if (list[i].lon !== undefined) l.push(list[i].lon)
    l = l.map(function(x) { return ((x % 360) + 360) % 360 })
    l.sort(function(a, b) { return a - b })
    var gap = 0, after = l[0]
    for (var k = 0; k < l.length; k++) {
      var next = k + 1 < l.length ? l[k + 1] : l[0] + 360
      if (next - l[k] > gap) { gap = next - l[k]; after = next }
    }
    var width = l.length > 1 ? 360 - gap : 0
    return { start: after % 360, width: width, centre: (after + width / 2) % 360 }
  }
  readonly property bool sweeping: span.width / 2 > faceHalf
  property real sweepT: 0
  // The shortest signed turn from a to b, in degrees.
  function turn(a, b) { return ((b - a) % 360 + 540) % 360 - 180 }
  function steer(dt) {
    var target
    if (sweeping) {
      // From one end of the span to the other and back, about 6 degrees a
      // second, easing at the ends.
      var amp = span.width / 2 - faceHalf
      var period = Math.max(20, 4 * amp / 6)
      sweepT = (sweepT + dt) % period
      target = span.centre + amp * Math.sin(2 * Math.PI * sweepT / period)
    } else {
      target = span.centre
    }
    lon0 = (lon0 + turn(lon0, target) * Math.min(1, dt * 1.5) + 360) % 360
  }
  property var sunPos: sun()

  // An app's icon from its process group name, through the desktop entries
  // (as the launcher finds them); "" when there is none.
  readonly property var iconNames: ({ "Brave": "brave-origin", "Claude": "claude-desktop", "Chromium": "chromium",
                                      "Firefox": "firefox", "Obsidian": "obsidian" })
  property var iconCache: ({})
  function appIcon(proc) {
    if (!proc) return ""
    if (iconCache[proc] !== undefined) return iconCache[proc]
    var name = iconNames[proc]
    if (!name) {
      var e = DesktopEntries.heuristicLookup(proc.toLowerCase())
      name = e ? e.icon : ""
    }
    var path = name ? Quickshell.iconPath(name, true) : ""
    iconCache[proc] = path || ""
    return iconCache[proc]
  }

  readonly property real cx: width / 2
  readonly property real cy: height / 2
  readonly property real rad: Math.PI / 180
  readonly property string maskPath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/hudwall/land.png"

  // Smooth while the globe turns; once settled on its routes, one frame a
  // second is enough (the packets then step along their arcs).
  readonly property bool moving: sweeping || Math.abs(turn(lon0, span.centre)) > 0.2
  property real lastTick: 0
  Timer {
    interval: globe.moving ? Math.round(1000 / globe.fps) : 1000
    repeat: true
    running: globe.active && globe.visible
    onTriggered: {
      var now = Date.now()
      var dt = globe.lastTick ? Math.min(1.5, (now - globe.lastTick) / 1000) : 1 / globe.fps
      globe.lastTick = now
      globe.steer(dt)
      globe.phase = (globe.phase + dt / 3) % 1
      globe.frame = globe.computeFrame()
    }
  }
  Timer {
    interval: 60000; repeat: true; running: globe.active
    onTriggered: globe.sunPos = globe.sun()
  }
  onPathsChanged: frame = computeFrame()
  onLon0Changed: if (!active) frame = computeFrame()

  // Subsolar point: [lon, lat] of the sun overhead, now.
  function sun() {
    var d = new Date()
    var start = new Date(d.getFullYear(), 0, 0)
    var doy = (d - start) / 86400000
    var dec = -23.44 * Math.cos(2 * Math.PI / 365 * (doy + 10))
    var ut = d.getUTCHours() + d.getUTCMinutes() / 60
    return [(12 - ut) * 15, dec]
  }

  // Reloaded now and then until it exists (after bin/hudwall-fetch-data).
  property int maskRev: 0
  Timer {
    interval: 20000; repeat: true
    running: globe.active && mask.status !== Image.Ready
    onTriggered: globe.maskRev++
  }
  Image {
    id: mask
    source: "file://" + globe.maskPath + "?" + globe.maskRev
    visible: false
    cache: false
    smooth: false
    mipmap: false
  }

  // The heat of each place the peers are in: the bytes exchanged with it,
  // on a log scale against the busiest (a place barely used still glows).
  readonly property var heat: {
    var by = {}
    var list = globe.peers || []
    for (var i = 0; i < list.length; i++) {
      var pe = list[i]
      if (pe.own || pe.lat === undefined || pe.lon === undefined) continue
      var key = Math.round(pe.lon) + "," + Math.round(pe.lat)
      if (!by[key]) by[key] = { lon: pe.lon, lat: pe.lat, bytes: 0 }
      by[key].bytes += pe.bytes || 0
    }
    var out = Object.keys(by).map(function(k) { return by[k] })
    out.sort(function(a, b) { return b.bytes - a.bytes })
    out = out.slice(0, 10)
    var top = out.length ? Math.log(out[0].bytes + 1) : 1
    return out.map(function(h) {
      return Qt.vector4d(h.lon, h.lat, Math.max(0.15, top > 0 ? Math.log(h.bytes + 1) / top : 0.15), 0)
    })
  }
  function heatAt(i) { return i < heat.length ? heat[i] : Qt.vector4d(0, 0, 0, 0) }

  ShaderEffect {
    anchors.fill: parent
    fragmentShader: Qt.resolvedUrl("shaders/globe.frag.qsb")
    property var land: mask
    property real lon0: globe.lon0
    property real tilt: globe.tilt
    property real sunLon: globe.sunPos[0]
    property real sunLat: globe.sunPos[1]
    property real radius: globe.radius / (globe.width / 2)
    property real dotStep: 2.0
    property real hasLand: mask.status === Image.Ready ? 1 : 0
    property color dayColor: globe.pal.alpha(globe.pal.acc2, 0.85)
    property color nightColor: globe.pal.alpha(globe.pal.blue, 0.4)
    property color oceanColor: Qt.darker(globe.pal.bg, 1.15)
    property color gridColor: globe.pal.alpha(globe.pal.acc, 0.12)
    property color rimColor: globe.pal.alpha(globe.pal.acc, 0.55)
    property color heatWarm: globe.pal.series(2)
    property color heatHot: globe.pal.series(4)
    property vector4d h0: globe.heatAt(0)
    property vector4d h1: globe.heatAt(1)
    property vector4d h2: globe.heatAt(2)
    property vector4d h3: globe.heatAt(3)
    property vector4d h4: globe.heatAt(4)
    property vector4d h5: globe.heatAt(5)
    property vector4d h6: globe.heatAt(6)
    property vector4d h7: globe.heatAt(7)
    property vector4d h8: globe.heatAt(8)
    property vector4d h9: globe.heatAt(9)
  }

  // Orthographic projection, the same as the shader's: [x, y, visible].
  function project(lon, lat) {
    var l = (lon - lon0) * rad, p = lat * rad, p0 = tilt * rad
    var cosc = Math.sin(p0) * Math.sin(p) + Math.cos(p0) * Math.cos(p) * Math.cos(l)
    var x = radius * Math.cos(p) * Math.sin(l)
    var y = radius * (Math.cos(p0) * Math.sin(p) - Math.sin(p0) * Math.cos(p) * Math.cos(l))
    return [cx + x, cy - y, cosc > 0]
  }
  function vec(lon, lat) {
    var l = lon * rad, p = lat * rad
    return [Math.cos(p) * Math.cos(l), Math.cos(p) * Math.sin(l), Math.sin(p)]
  }
  // Point at fraction t along the great circle a -> b, [lon, lat].
  function slerp(a, b, t) {
    var va = vec(a[0], a[1]), vb = vec(b[0], b[1])
    var dot = Math.max(-1, Math.min(1, va[0] * vb[0] + va[1] * vb[1] + va[2] * vb[2]))
    var w = Math.acos(dot)
    if (w < 1e-6) return a
    var s = Math.sin(w)
    var k1 = Math.sin((1 - t) * w) / s, k2 = Math.sin(t * w) / s
    var v = [k1 * va[0] + k2 * vb[0], k1 * va[1] + k2 * vb[1], k1 * va[2] + k2 * vb[2]]
    return [Math.atan2(v[1], v[0]) / rad, Math.asin(Math.max(-1, Math.min(1, v[2]))) / rad]
  }
  function dist(a, b) {
    var va = vec(a[0], a[1]), vb = vec(b[0], b[1])
    return Math.acos(Math.max(-1, Math.min(1, va[0] * vb[0] + va[1] * vb[1] + va[2] * vb[2])))
  }

  // The great circles only change with the peers: computed once.
  readonly property var paths: {
    var out = []
    for (var n = 0; n < peers.length; n++) {
      var pe = peers[n]
      if (pe.lat === undefined || pe.lon === undefined) continue
      var dest = [pe.lon, pe.lat]
      var pts = []
      for (var k = 0; k <= 32; k++) pts.push(slerp(home, dest, k / 32))
      out.push({ pts: pts, d: dist(home, dest), live: pe.live, own: !!pe.own, dest: dest,
                 proc: pe.proc || "", place: pe.city || pe.country || "",
                 label: (pe.proc ? pe.proc + " · " : "") + (pe.city || pe.country || "") })
    }
    return out
  }

  // Screen positions of the arcs for the current rotation: per peer, the
  // visible stretches of its arc, the packet, the end point.
  property var frame: []
  function computeFrame() {
    var out = []
    var placed = []
    for (var n = 0; n < paths.length; n++) {
      var a = paths[n]
      var segs = [], cur = [], screen = []
      for (var k = 0; k < a.pts.length; k++) {
        var pr = project(a.pts[k][0], a.pts[k][1])
        var lift = 1 + Math.sin(Math.PI * k / (a.pts.length - 1)) * Math.min(0.18, a.d * 0.12)
        var q = Qt.point(cx + (pr[0] - cx) * lift, cy + (pr[1] - cy) * lift)
        screen.push([q, pr[2]])
        if (pr[2]) cur.push(q)
        else if (cur.length) { if (cur.length > 1) segs.push(cur); cur = [] }
      }
      if (cur.length > 1) segs.push(cur)
      var pk = screen[Math.floor(((phase + n * 0.13) % 1) * (screen.length - 1))]
      var end = project(a.dest[0], a.dest[1])
      var labelOn = end[2] && n < 8
      for (var c = 0; labelOn && c < placed.length; c++)
        if (Math.abs(placed[c][0] - end[0]) < 90 && Math.abs(placed[c][1] - end[1]) < 12) labelOn = false
      if (labelOn) placed.push(end)
      out.push({ segs: segs, packet: pk[0], packetOn: a.live && pk[1], end: Qt.point(end[0], end[1]), endOn: end[2], labelOn: labelOn })
    }
    var h = project(home[0], home[1])
    homePt = Qt.point(h[0], h[1]); homeOn = h[2]
    return out
  }
  property point homePt: Qt.point(0, 0)
  property bool homeOn: false

  Repeater {
    model: globe.paths.length
    Item {
      id: arc
      required property int index
      anchors.fill: parent
      readonly property var f: globe.frame[index] || null
      readonly property var p: globe.paths[index] || null
      readonly property color tint: p && p.own ? globe.pal.acc2 : p && p.live ? globe.pal.acc : globe.pal.cyan
      Shape {
        anchors.fill: parent
        ShapePath {
          strokeColor: globe.pal.alpha(arc.tint, arc.p && arc.p.live ? 0.65 : 0.3)
          strokeWidth: 1.1
          fillColor: "transparent"
          PathMultiline { paths: arc.f ? arc.f.segs : [] }
        }
      }
      Rectangle {
        visible: !!(arc.f && arc.f.packetOn)
        x: arc.f ? arc.f.packet.x - 2 : 0; y: arc.f ? arc.f.packet.y - 2 : 0
        width: 4; height: 4; radius: 2; color: "white"
      }
      Rectangle {
        visible: !!(arc.f && arc.f.endOn)
        x: arc.f ? arc.f.end.x - 3 : 0; y: arc.f ? arc.f.end.y - 3 : 0
        width: 6; height: 6; radius: 3; color: arc.tint
      }
      // The label: the app's icon when it has one, then the place; the
      // process name in words otherwise. Labels that would overlap an
      // earlier one are left out.
      Row {
        visible: !!(arc.f && arc.f.labelOn)
        x: arc.f ? arc.f.end.x + 6 : 0; y: arc.f ? arc.f.end.y - 14 : 0
        spacing: 3
        readonly property string icon: arc.p ? globe.appIcon(arc.p.proc) : ""
        IconImage {
          visible: parent.icon.length > 0
          anchors.verticalCenter: parent.verticalCenter
          implicitSize: 12
          source: parent.icon
        }
        HText {
          anchors.verticalCenter: parent.verticalCenter
          text: !arc.p ? "" : parent.icon.length > 0 || !arc.p.proc ? arc.p.place : arc.p.proc + " · " + arc.p.place
          color: arc.tint; font.pixelSize: 9
        }
      }
    }
  }

  // Home, pulsing.
  Rectangle {
    visible: globe.homeOn
    readonly property real s: 8 + 6 * Math.sin(globe.phase * 2 * Math.PI * 3)
    x: globe.homePt.x - s / 2; y: globe.homePt.y - s / 2
    width: s; height: s; radius: s / 2
    color: "transparent"; border.color: "white"; border.width: 1
  }
  Rectangle {
    visible: globe.homeOn
    x: globe.homePt.x - 2.5; y: globe.homePt.y - 2.5
    width: 5; height: 5; radius: 2.5; color: "white"
  }
}
