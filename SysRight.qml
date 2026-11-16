import QtQuick
import QtQuick.Effects
import Quickshell

// Right column: the company mark with the machine, CPU, GPU, memory, NPU and
// applications. Series take the palette's series colors (told apart in Lab);
// legends switch series on and off; graphs label their highest peaks.
Item {
  id: col

  required property var pal
  required property var sys
  required property var prom

  width: 330
  height: 712

  property real pixelScale: 1
  // { image: path, name: text } from the config; without it, the host.
  property var mark: null
  readonly property string markImage: mark && mark.image ? String(mark.image).replace(/^~/, Quickshell.env("HOME")) : ""
  readonly property bool inSession: !!(prom.p && prom.p.running)

  function uptime(s) {
    s = Math.max(0, s || 0)
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return (d > 0 ? d + " d " : "") + h + " h " + String(m).padStart(2, "0")
  }
  function pct(v) { return Math.round(v * 100) + "%" }

  // ---------------------------------------------------------------- mark
  HPanel {
    pal: col.pal
    width: col.width; height: 80
    pad: 10
    tip: "This machine: host name, kernel, time since boot (the mark and name are set in hudwall.json)."

    Image {
      id: logo
      x: 2
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height - 2
      width: col.markImage ? height * Math.max(0.5, implicitWidth / Math.max(1, implicitHeight)) : 0
      source: col.markImage ? "file://" + col.markImage : ""
      fillMode: Image.PreserveAspectFit
      smooth: true
      mipmap: true
      visible: false
    }
    MultiEffect {
      anchors.fill: logo
      source: logo
      colorization: 1.0
      colorizationColor: col.pal.fg
    }
    Column {
      x: logo.width + (logo.width > 0 ? 16 : 4)
      width: parent.width - x
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      HText { text: col.mark && col.mark.name ? col.mark.name : (col.sys.host.name || "").toUpperCase(); color: col.pal.fg; font.pixelSize: 14; font.letterSpacing: 4; font.weight: Font.DemiBold }
      HText { width: parent.width; text: (col.sys.host.name || "") + " · " + (col.sys.host.kernel || ""); color: col.pal.dim; font.pixelSize: 9 }
      HText { text: "up " + col.uptime(col.sys.host.uptime); color: col.pal.mut; font.pixelSize: 9 }
    }
  }

  // ---------------------------------------------------------------- cpu
  HPanel {
    id: cpuPanel
    pal: col.pal
    y: 90; width: col.width; height: 124
    label: "CPU · " + (col.sys.cpu.threads ? col.sys.cpu.threads.length : "–") + " threads"
    note: col.sys.cpu.temp ? col.sys.cpu.temp + " °C" : ""
    tip: "Dial: load of the whole machine, clock in the middle; inner ring: CPU temperature (out of 100 °C). Graph: load over the last minute, highest peaks labelled. Bars: each thread now (accent while a Prometheus session runs)."
    readonly property color c: col.inSession ? col.pal.series(1) : col.pal.series(0)

    Gauge {
      id: cpuGauge
      pal: col.pal
      width: 80; height: 80
      anchors.verticalCenter: parent.verticalCenter
      value: col.sys.cpu.total || 0
      color: cpuPanel.c
      value2: col.sys.cpu.temp ? col.sys.cpu.temp / 100 : -1
      color2: col.pal.series(4)
      text: col.sys.cpu.total !== undefined ? col.pct(col.sys.cpu.total) : "–"
      caption: col.sys.cpu.ghz ? col.sys.cpu.ghz.toFixed(1) + " GHz" : ""
    }
    Item {
      x: cpuGauge.width + 12
      width: parent.width - x; height: parent.height
      Spark {
        y: 8; width: parent.width; height: 30
        values: col.sys.cpuHist; color: cpuPanel.c
        format: function(v) { return col.pct(v) }
      }
      // One bar per thread, bottom-aligned.
      Row {
        id: threads
        anchors.bottom: parent.bottom
        width: parent.width; height: 34
        readonly property int n: col.sys.cpu.threads ? col.sys.cpu.threads.length : 12
        spacing: 2
        readonly property real bw: (width - (n - 1) * spacing) / n
        Repeater {
          model: col.sys.cpu.threads || []
          Item {
            required property var modelData
            width: threads.bw; height: threads.height
            Rectangle { anchors.fill: parent; color: col.pal.alpha(col.pal.fg, 0.05) }
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width; height: Math.max(1, parent.height * modelData)
              color: cpuPanel.c
              opacity: 0.45 + 0.55 * modelData
              Behavior on height { NumberAnimation { duration: 400 } }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- gpu
  HPanel {
    id: gpuPanel
    pal: col.pal
    y: 224; width: col.width; height: 120
    label: "GPU"
    note: col.sys.gpu.temp ? col.sys.gpu.temp + " °C" : ""
    tip: "Integrated GPU (amdgpu). Dial: load, clock in the middle; inner ring: temperature. Graph: load and power over the last minute (click a legend entry to hide it). Bars: dedicated video memory (VRAM) and system memory it borrows (GTT)."
    readonly property var g: col.sys.gpu

    Gauge {
      id: gpuGauge
      pal: col.pal
      width: 80; height: 80
      anchors.verticalCenter: parent.verticalCenter
      value: gpuPanel.g.busy || 0
      color: col.pal.series(0)
      value2: gpuPanel.g.temp ? gpuPanel.g.temp / 100 : -1
      color2: col.pal.series(4)
      text: gpuPanel.g.busy !== undefined ? col.pct(gpuPanel.g.busy) : "–"
      caption: gpuPanel.g.mhz ? gpuPanel.g.mhz + " MHz" : ""
    }
    Item {
      x: gpuGauge.width + 12
      width: parent.width - x; height: parent.height
      Legend {
        id: gpuLegend
        pal: col.pal
        width: parent.width
        items: [
          { key: "load", name: "load", color: col.pal.series(0), value: gpuPanel.g.busy !== undefined ? col.pct(gpuPanel.g.busy) : "" },
          { key: "watts", name: "power", color: col.pal.series(2), value: gpuPanel.g.watts !== undefined ? gpuPanel.g.watts + " W" : "" }
        ]
      }
      Item {
        y: 20; width: parent.width; height: 28
        readonly property real wMax: Math.max(10, Math.max.apply(null, col.sys.gpuWattHist.concat([1])) * 1.1)
        Spark {
          visible: gpuLegend.on("load")
          anchors.fill: parent
          values: col.sys.gpuHist; color: col.pal.series(0); peaks: 3
          format: function(v) { return col.pct(v) }
        }
        Spark {
          visible: gpuLegend.on("watts")
          anchors.fill: parent; fill: false; lineWidth: 1
          values: col.sys.gpuWattHist; max: parent.wMax; color: col.pal.series(2); peaks: 2
          format: function(v) { return v.toFixed(1) + " W" }
        }
      }
      Column {
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: 3
        Repeater {
          model: [
            { n: "VRAM", u: gpuPanel.g.vramUsed, t: gpuPanel.g.vramTotal },
            { n: "GTT", u: gpuPanel.g.gttUsed, t: gpuPanel.g.gttTotal }
          ]
          Row {
            required property var modelData
            spacing: 6
            HText { width: 30; text: modelData.n; color: col.pal.dim; font.pixelSize: 8; font.letterSpacing: 1 }
            Item {
              width: parent.parent.width - 30 - 6 - 6 - 74; height: 5
              anchors.verticalCenter: parent.verticalCenter
              Rectangle { anchors.fill: parent; color: col.pal.alpha(col.pal.fg, 0.06) }
              Rectangle {
                width: modelData.t ? parent.width * Math.min(1, modelData.u / modelData.t) : 0; height: parent.height
                color: col.pal.series(3)
              }
            }
            HText { width: 74; horizontalAlignment: Text.AlignRight; text: col.sys.bytes(modelData.u) + " / " + col.sys.bytes(modelData.t); color: col.pal.dim; font.pixelSize: 8 }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------- memory
  HPanel {
    id: memPanel
    pal: col.pal
    y: 480; width: col.width; height: 106
    label: "RAM"
    note: col.sys.mem.total ? Math.round(col.sys.mem.total / 1073741824) + " GB" : ""
    tip: "RAM split: used by programs, page cache (freed when needed), compressed swap in zram, free. Graph: the last minute of each, out of the whole RAM. Click a legend entry to leave it out of the ring and the graph."
    readonly property var parts: col.sys.mem.total ? [
      { key: "used", name: "used", v: col.sys.mem.used, color: col.pal.series(0) },
      { key: "cache", name: "cache", v: col.sys.mem.cache, color: col.pal.series(1) },
      { key: "zram", name: "zram", v: col.sys.mem.zram, color: col.pal.series(2) },
      { key: "free", name: "free", v: col.sys.mem.free, color: col.pal.alpha(col.pal.fg, 0.25) }
    ] : []

    Row {
      spacing: 16
      anchors.verticalCenter: parent.verticalCenter
      Item {
        width: 64; height: 64
        HiCanvas {
          anchors.fill: parent
          pixelScale: col.pixelScale
          property var parts: memPanel.parts
          property var hidden: memLegend.hidden
          onPartsChanged: requestPaint()
          onHiddenChanged: requestPaint()
          function draw(ctx) {
            var total = col.sys.mem.total || 1
            var a = -Math.PI / 2
            ctx.lineWidth = 7
            for (var i = 0; i < parts.length; i++) {
              var da = parts[i].v / total * 2 * Math.PI
              if (!hidden[parts[i].key]) {
                var n = Math.max(1, Math.round(parts[i].v / total * 56))
                ctx.strokeStyle = col.pal.css(parts[i].color)
                for (var k = 0; k < n; k++) {
                  ctx.beginPath()
                  ctx.arc(32, 32, 27, a + k * da / n, a + (k + 0.7) * da / n)
                  ctx.stroke()
                }
              }
              a += da
            }
          }
        }
        HText {
          anchors.centerIn: parent
          text: col.sys.mem.total ? Math.round(col.sys.mem.used / col.sys.mem.total * 100) + "%" : ""
          color: col.pal.fg; font.pixelSize: 12; font.weight: Font.DemiBold
        }
      }
      // Right of the ring: the parts (click to hide one) over their last
      // minute, as on the GPU panel.
      Item {
        width: memPanel.width - 2 * memPanel.pad - 64 - 16; height: 64
        anchors.verticalCenter: parent.verticalCenter
        Legend {
          id: memLegend
          pal: col.pal
          width: parent.width
          spacing: 8
          items: memPanel.parts.map(function(p) { return { key: p.key, name: p.name, color: p.color, value: col.sys.bytes(p.v) } })
        }
        Item {
          anchors.bottom: parent.bottom
          width: parent.width; height: 28
          readonly property real total: col.sys.mem.total || 1
          function gb(v) { return (v / 1073741824).toFixed(1) + " G" }
          Spark {
            visible: memLegend.on("cache")
            anchors.fill: parent; fill: false; lineWidth: 1
            values: col.sys.memCacheHist; max: parent.total; color: col.pal.series(1); peaks: 1
            format: function(v) { return parent.gb(v) }
          }
          Spark {
            visible: memLegend.on("zram")
            anchors.fill: parent; fill: false; lineWidth: 1
            values: col.sys.memZramHist; max: parent.total; color: col.pal.series(2); peaks: 1
            format: function(v) { return parent.gb(v) }
          }
          Spark {
            visible: memLegend.on("used")
            anchors.fill: parent
            values: col.sys.memUsedHist; max: parent.total; color: col.pal.series(0); peaks: 3
            format: function(v) { return parent.gb(v) }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- npu
  HPanel {
    id: npuPanel
    pal: col.pal
    y: 354; width: col.width; height: 116
    label: "NPU · " + (col.sys.npu.model || "Lemonade")
    note: col.sys.npu.up ? (col.sys.npu.busy ? "busy" : "ready") : "stopped"
    tip: "The local LLM on the NPU (Lemonade). Speed of the last generation and the request queue. Bars: the last 24 hours, busy time per hour by client (from the npu-queue journal, so it survives restarts); click a legend entry to hide a client. Peaks: busy minutes."
    readonly property var day: col.sys.npuDay
    readonly property var clients: {
      var tot = {}
      var hs = day ? day.hours : []
      for (var i = 0; i < hs.length; i++) for (var k in hs[i]) tot[k] = (tot[k] || 0) + hs[i][k]
      var l = Object.keys(tot)
      l.sort(function(a, b) { return tot[b] - tot[a] })
      return l.map(function(k, i) { return { key: k, name: k, color: col.pal.series(i), secs: tot[k] } })
    }
    function shownSecs(h) {
      var s = 0
      for (var i = 0; i < clients.length; i++) if (npuLegend.on(clients[i].key)) s += h[clients[i].key] || 0
      return s
    }
    readonly property var totals: day ? day.hours.map(function(h) { return npuPanel.shownSecs(h) }) : []
    readonly property real topS: Math.max(60, Math.max.apply(null, totals.concat([0])) * 1.15)

    Row {
      width: parent.width; height: 20
      spacing: 6
      HText {
        anchors.bottom: parent.bottom
        text: col.sys.npu.tps ? Math.round(col.sys.npu.tps) : "–"
        color: col.pal.fg; font.pixelSize: 18; font.weight: Font.DemiBold
      }
      HText { anchors.bottom: parent.bottom; anchors.bottomMargin: 2; text: "tok/s"; color: col.pal.mut; font.pixelSize: 9 }
      Item { width: 10; height: 1 }
      HText {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
        text: "queue " + (col.sys.npu.running ? "▮" : "▯") + "▮".repeat(Math.min(6, col.sys.npu.waiting || 0))
          + " · " + (npuPanel.day ? npuPanel.day.requests : (col.sys.npu.requests || 0)) + " requests / 24 h"
        color: col.pal.dim; font.pixelSize: 9
      }
    }
    Legend {
      id: npuLegend
      y: 24
      pal: col.pal
      width: parent.width
      items: npuPanel.clients.map(function(c) { return { key: c.key, name: c.name, color: c.color } })
    }
    Item {
      id: bars
      anchors.bottom: parent.bottom
      width: parent.width; height: 34
      readonly property real bw: width / 24
      Repeater {
        model: npuPanel.day ? npuPanel.day.hours : []
        Item {
          id: hourBar
          required property var modelData
          required property int index
          x: index * bars.bw + 1; width: bars.bw - 2; height: bars.height
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: col.pal.alpha(col.pal.fg, 0.12) }
          Column {
            anchors.bottom: parent.bottom
            width: parent.width
            Repeater {
              model: npuPanel.clients.slice().reverse()
              Rectangle {
                required property var modelData
                width: hourBar.width
                height: npuLegend.on(modelData.key) ? bars.height * (hourBar.modelData[modelData.key] || 0) / npuPanel.topS : 0
                color: modelData.color
              }
            }
          }
        }
      }
      Spark {
        anchors.fill: parent
        centered: true; fill: false; lineWidth: 0
        values: npuPanel.totals; max: npuPanel.topS; color: col.pal.fg
        format: function(v) { return Math.round(v / 60) + "m" }
      }
    }
  }

  // --------------------------------------------------------------- apps
  HPanel {
    pal: col.pal
    y: 596; width: col.width; height: 116
    label: "Applications"
    note: "CPU · RAM"
    tip: "Busiest program groups: share of the whole machine's CPU (all cores) and resident memory. ×N = number of instances."
    tipAbove: true
    Column {
      width: parent.width
      spacing: 1
      Repeater {
        model: (col.sys.procs || []).slice(0, 5)
        Row {
          required property var modelData
          width: parent.width; height: 14
          spacing: 6
          HText {
            width: 104; anchors.verticalCenter: parent.verticalCenter
            text: modelData.name + (modelData.count > 1 && modelData.name !== "Hyprland + shell" ? " ×" + modelData.count : "")
            color: col.pal.fg
          }
          HBar {
            pal: col.pal
            width: parent.width - 104 - 34 - 44 - 18; anchors.verticalCenter: parent.verticalCenter
            value: Math.min(1, modelData.cpu * 2.5)
          }
          HText { width: 34; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: Math.round(modelData.cpu * 100) + "%"; color: col.pal.dim; font.pixelSize: 9 }
          HText { width: 44; anchors.verticalCenter: parent.verticalCenter; horizontalAlignment: Text.AlignRight; text: col.sys.bytes(modelData.rss); color: col.pal.dim; font.pixelSize: 9 }
        }
      }
    }
  }
}
