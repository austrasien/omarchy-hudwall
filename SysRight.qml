import QtQuick
import QtQuick.Effects

// Right column: the company mark with the machine, CPU, GPU, memory, NPU and
// applications.
Item {
  id: col

  required property var pal
  required property var sys
  required property var prom

  width: 330
  height: 712

  property real pixelScale: 1
  readonly property bool inSession: !!(prom.p && prom.p.running)
  readonly property var memParts: sys.mem.total ? [
    { v: sys.mem.used, c: pal.acc, n: "used" },
    { v: sys.mem.cache, c: pal.blue, n: "cache" },
    { v: sys.mem.zram, c: pal.mag, n: "zram" },
    { v: sys.mem.free, c: pal.alpha(pal.fg, 0.15), n: "free" }
  ] : []

  function uptime(s) {
    s = Math.max(0, s || 0)
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return (d > 0 ? d + " d " : "") + h + " h " + String(m).padStart(2, "0")
  }

  // ---------------------------------------------------------------- mark
  HPanel {
    pal: col.pal
    width: col.width; height: 80
    pad: 10
    tip: "Askalon, and this machine: host name, kernel, time since boot."

    Image {
      id: logo
      x: 2
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height - 2
      width: height * 400 / 327
      source: Qt.resolvedUrl("assets/askalon-logo.png")
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
      x: logo.width + 16
      width: parent.width - x
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      HText { text: "ΛSKΛLON"; color: col.pal.fg; font.pixelSize: 14; font.letterSpacing: 4; font.weight: Font.DemiBold }
      HText { width: parent.width; text: (col.sys.host.name || "") + " · " + (col.sys.host.kernel || ""); color: col.pal.dim; font.pixelSize: 9 }
      HText { text: "up " + col.uptime(col.sys.host.uptime); color: col.pal.mut; font.pixelSize: 9 }
    }
  }

  // ---------------------------------------------------------------- cpu
  HPanel {
    pal: col.pal
    y: 90; width: col.width; height: 132
    label: "CPU · " + (col.sys.cpu.threads ? col.sys.cpu.threads.length : "–") + " threads"
    tip: "CPU load of the whole machine (graph: last minute) and per thread. Cells are orange while a Prometheus session runs, blue otherwise. Header: average clock and CPU temperature."
    note: (col.sys.cpu.ghz ? col.sys.cpu.ghz.toFixed(1) + " GHz" : "") + (col.sys.cpu.temp ? " · " + col.sys.cpu.temp + " °C" : "")

    Row {
      width: parent.width; height: 28
      HText {
        width: 70; anchors.bottom: parent.bottom
        text: col.sys.cpu.total !== undefined ? Math.round(col.sys.cpu.total * 100) + "%" : "–"
        color: col.pal.fg; font.pixelSize: 22; font.weight: Font.DemiBold
      }
      Spark { width: parent.width - 70; height: 28; values: col.sys.cpuHist; color: col.pal.acc }
    }
    Grid {
      id: cells
      y: 36
      readonly property int n: col.sys.cpu.threads ? col.sys.cpu.threads.length : 12
      columns: n > 16 ? Math.ceil(n / 2) : Math.min(n, 12)
      spacing: 3
      readonly property real cw: (parent.width - (columns - 1) * spacing) / columns
      Repeater {
        model: col.sys.cpu.threads || []
        Rectangle {
          required property var modelData
          width: cells.cw; height: cells.n > 16 ? 14 : 22
          color: col.inSession ? col.pal.acc : col.pal.blue
          opacity: 0.12 + modelData * 0.88
          Behavior on opacity { NumberAnimation { duration: 500 } }
        }
      }
    }
  }

  // ---------------------------------------------------------------- gpu
  HPanel {
    pal: col.pal
    y: 232; width: col.width; height: 104
    label: "GPU"
    note: (col.sys.gpu.mhz ? col.sys.gpu.mhz + " MHz" : "") + (col.sys.gpu.temp ? " · " + col.sys.gpu.temp + " °C" : "")
    tip: "Integrated GPU (amdgpu): load (graph: last minute), clock and temperature; dedicated video memory (VRAM) and system memory it borrows (GTT); power drawn by the chip."

    Row {
      width: parent.width; height: 28
      HText {
        width: 70; anchors.bottom: parent.bottom
        text: col.sys.gpu.busy !== undefined ? Math.round(col.sys.gpu.busy * 100) + "%" : "–"
        color: col.pal.fg; font.pixelSize: 22; font.weight: Font.DemiBold
      }
      Spark { width: parent.width - 70; height: 28; values: col.sys.gpuHist; color: col.pal.mag }
    }
    HText {
      anchors.bottom: parent.bottom
      width: parent.width
      text: "VRAM " + col.sys.bytes(col.sys.gpu.vramUsed) + "/" + col.sys.bytes(col.sys.gpu.vramTotal)
        + " · GTT " + col.sys.bytes(col.sys.gpu.gttUsed)
        + (col.sys.gpu.watts !== undefined ? " · " + col.sys.gpu.watts + " W" : "")
      color: col.pal.dim; font.pixelSize: 9
    }
  }

  // ------------------------------------------------------------- memory
  HPanel {
    pal: col.pal
    y: 346; width: col.width; height: 112
    label: "Memory"
    note: col.sys.mem.total ? Math.round(col.sys.mem.total / 1073741824) + " GB" : ""
    tip: "RAM split: used by programs, page cache (freed when needed), compressed swap in zram, free."

    Row {
      spacing: 14
      Item {
        width: 70; height: 70
        HiCanvas {
          anchors.fill: parent
          pixelScale: col.pixelScale
          property var parts: col.memParts
          onPartsChanged: requestPaint()
          function draw(ctx) {
            var total = col.sys.mem.total || 1
            var a = -Math.PI / 2
            ctx.lineWidth = 8
            for (var i = 0; i < parts.length; i++) {
              var da = parts[i].v / total * 2 * Math.PI
              var n = Math.max(1, Math.round(parts[i].v / total * 56))
              ctx.strokeStyle = col.pal.css(parts[i].c)
              for (var k = 0; k < n; k++) {
                ctx.beginPath()
                ctx.arc(35, 35, 29, a + k * da / n, a + (k + 0.7) * da / n)
                ctx.stroke()
              }
              a += da
            }
          }
        }
        HText {
          anchors.centerIn: parent
          text: col.sys.mem.total ? Math.round(col.sys.mem.used / col.sys.mem.total * 100) + "%" : ""
          color: "white"; font.pixelSize: 12
        }
      }
      Column {
        width: col.width - 70 - 14 - 20
        spacing: 2
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: col.memParts
          Row {
            required property var modelData
            width: parent.width
            HText { text: "■ "; color: modelData.c }
            HText { width: parent.width - 70; text: modelData.n; color: col.pal.fg }
            HText { width: 56; horizontalAlignment: Text.AlignRight; text: col.sys.bytes(modelData.v); color: col.pal.fg }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------------- npu
  HPanel {
    pal: col.pal
    y: 468; width: col.width; height: 102
    label: "NPU · Lemonade"
    note: col.sys.npu.up ? (col.sys.npu.busy ? "busy" : "ready") : "stopped"
    tip: "The local LLM on the NPU (Lemonade). Tokens per second of the last generation (graph while generating), request queue, and requests served since start."

    HText { width: parent.width; text: col.sys.npu.model || "—"; color: col.pal.fg }
    Row {
      y: 16; width: parent.width; height: 26
      HText {
        width: 46; anchors.bottom: parent.bottom
        text: col.sys.npu.tps ? Math.round(col.sys.npu.tps) : "–"
        color: col.pal.cyan; font.pixelSize: 20; font.weight: Font.DemiBold
      }
      HText { width: 40; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; text: "tok/s"; color: col.pal.mut; font.pixelSize: 9 }
      Spark { width: parent.width - 86; height: 24; anchors.bottom: parent.bottom; values: col.sys.npuHist; max: 60; color: col.pal.cyan }
    }
    HText {
      anchors.bottom: parent.bottom
      width: parent.width
      text: "QUEUE " + (col.sys.npu.running ? "▮" : "▯") + "▮".repeat(Math.min(6, col.sys.npu.waiting || 0))
        + " " + (col.sys.npu.waiting || 0) + " waiting · " + (col.sys.npu.requests || 0) + " requests"
      color: col.pal.dim; font.pixelSize: 9
    }
  }

  // --------------------------------------------------------------- apps
  HPanel {
    pal: col.pal
    y: 580; width: col.width; height: 132
    label: "Applications"
    note: "CPU · RAM"
    tip: "Busiest program groups: share of the whole machine's CPU (all cores) and resident memory. ×N = number of instances."
    tipAbove: true
    Column {
      width: parent.width
      spacing: 3
      Repeater {
        model: (col.sys.procs || []).slice(0, 5)
        Row {
          required property var modelData
          width: parent.width
          spacing: 6
          HText {
            width: 104
            text: modelData.name + (modelData.count > 1 && modelData.name !== "Hyprland + shell" ? " ×" + modelData.count : "")
            color: col.pal.fg
          }
          HBar {
            pal: col.pal
            width: parent.width - 104 - 34 - 44 - 18; anchors.verticalCenter: parent.verticalCenter
            value: Math.min(1, modelData.cpu * 2.5)
          }
          HText { width: 34; horizontalAlignment: Text.AlignRight; text: Math.round(modelData.cpu * 100) + "%"; color: col.pal.dim; font.pixelSize: 9 }
          HText { width: 44; horizontalAlignment: Text.AlignRight; text: col.sys.bytes(modelData.rss); color: col.pal.dim; font.pixelSize: 9 }
        }
      }
    }
  }
}
