import QtQuick
import Quickshell
import Quickshell.Io

// System readings from bin/hudwall-collector, which runs only while the HUD
// is seen. Each line is a JSON object with the sections that were read.
Item {
  id: sys

  property bool active: false

  property var cpu: ({})
  property var gpu: ({})
  property var host: ({})
  property var mem: ({})
  property var net: ({})
  property var bat: ({})
  property var procs: []
  property var npu: ({})
  property var peers: ({ geo: false, list: [] })
  property var tail: ({})
  property var batDay: ({})

  // Short histories for the sparklines (one sample a second).
  property var cpuHist: []
  property var gpuHist: []
  property var downHist: []
  property var upHist: []
  property var npuHist: []

  readonly property string collector: Qt.resolvedUrl("bin/hudwall-collector").toString().replace(/^[a-z]+:\/\//, "")

  function push(list, v, n) {
    var out = list.slice(list.length >= n ? 1 : 0)
    out.push(v)
    return out
  }

  function ingest(line) {
    var d
    try { d = JSON.parse(line) } catch (e) { return }
    if (d.cpu) {
      cpu = d.cpu
      if (d.cpu.total !== undefined) cpuHist = push(cpuHist, d.cpu.total, 60)
    }
    if (d.gpu) {
      gpu = d.gpu
      if (d.gpu.busy !== undefined) gpuHist = push(gpuHist, d.gpu.busy, 60)
    }
    if (d.host) host = d.host
    if (d.mem) mem = d.mem
    if (d.net) {
      net = d.net
      if (d.net.down !== undefined) {
        downHist = push(downHist, d.net.down, 80)
        upHist = push(upHist, d.net.up, 80)
      }
    }
    if (d.bat) bat = d.bat
    if (d.procs) procs = d.procs
    if (d.npu) {
      npu = d.npu
      npuHist = push(npuHist, d.npu.busy ? (d.npu.tps || 0) : 0, 40)
    }
    if (d.peers) peers = d.peers
    if (d.tail) tail = d.tail
    if (d.batDay) batDay = d.batDay
  }

  Process {
    id: proc
    command: [sys.collector]
    stdout: SplitParser { onRead: data => sys.ingest(data) }
    stderr: SplitParser { onRead: data => console.warn("hudwall-collector:", data) }
    onExited: if (sys.active) restart.start()
  }
  Timer { id: restart; interval: 5000; onTriggered: if (sys.active && !proc.running) proc.running = true }
  onActiveChanged: proc.running = active
  Component.onCompleted: proc.running = active

  // Formatting shared by the panels.
  function bytes(n) {
    if (n === undefined || n === null) return "–"
    if (n >= 1e9) return (n / 1e9).toFixed(1) + " G"
    if (n >= 1e6) return (n / 1e6).toFixed(0) + " M"
    return (n / 1e3).toFixed(0) + " k"
  }
  function rate(n) {
    if (n === undefined || n === null) return "–"
    if (n >= 1e6) return (n / 1e6).toFixed(1) + " MB/s"
    if (n >= 1e3) return (n / 1e3).toFixed(0) + " kB/s"
    return Math.round(n) + " B/s"
  }
}
