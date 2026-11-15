import QtQuick
import QtQuick.Shapes
import Quickshell

// The globe: the Earth itself is a shader (shaders/globe.frag) reading the
// land mask written by bin/hudwall-fetch-data; on top, a light Canvas draws
// the arcs from home to the last network peers, with packets running along.
// It turns only while `active`, at `fps`.
Item {
  id: globe

  required property var pal
  property bool active: false
  property real fps: 24
  property var home: [2.35, 48.85]
  property var peers: []          // [{ lat, lon, proc, city, live }]
  property real radius: 170
  property real tilt: 25
  property real pixelScale: 1

  property real lon0: home[0] - 20
  property real phase: 0
  property var sunPos: sun()

  readonly property real cx: width / 2
  readonly property real cy: height / 2
  readonly property real rad: Math.PI / 180
  readonly property string maskPath: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/hudwall/land.png"

  Timer {
    interval: Math.round(1000 / globe.fps)
    repeat: true
    running: globe.active && globe.visible
    onTriggered: {
      globe.lon0 = (globe.lon0 + 6 / globe.fps) % 360   // one turn a minute
      globe.phase = (globe.phase + 1 / (globe.fps * 3)) % 1
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
        var lift = 1 + Math.sin(Math.PI * k / (a.pts.length - 1)) * Math.min(0.35, a.d * 0.25)
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
      HText {
        // Labels that would overlap an earlier one are left out.
        visible: !!(arc.f && arc.f.labelOn)
        x: arc.f ? arc.f.end.x + 6 : 0; y: arc.f ? arc.f.end.y - 14 : 0
        text: arc.p ? arc.p.label : ""
        color: arc.tint; font.pixelSize: 9
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
