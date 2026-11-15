import QtQuick
import QtQuick.Shapes

// Right column: CPU, memory, NPU, applications, and the week's focus.
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
    { v: sys.mem.used, c: pal.acc, n: "utilisée" },
    { v: sys.mem.cache, c: pal.blue, n: "cache" },
    { v: sys.mem.zram, c: pal.mag, n: "zram" },
    { v: sys.mem.free, c: pal.alpha(pal.fg, 0.15), n: "libre" }
  ] : []

  // ---------------------------------------------------------------- cpu
  HPanel {
    pal: col.pal
    width: 330; height: 168
    label: "CPU · " + (col.sys.cpu.threads ? col.sys.cpu.threads.length : "–") + " threads"
    note: (col.sys.cpu.ghz ? col.sys.cpu.ghz.toFixed(1) + " GHz" : "") + (col.sys.cpu.temp ? " · " + col.sys.cpu.temp + " °C" : "")

    Row {
      width: parent.width; height: 30
      HText {
        width: 80; anchors.bottom: parent.bottom
        text: col.sys.cpu.total !== undefined ? Math.round(col.sys.cpu.total * 100) + "%" : "–"
        color: col.pal.fg; font.pixelSize: 22; font.weight: Font.DemiBold
      }
      Spark {
        width: parent.width - 80; height: 30
        values: col.sys.cpuHist; color: col.pal.acc
      }
    }
    Grid {
      id: cells
      y: 38
      readonly property int n: col.sys.cpu.threads ? col.sys.cpu.threads.length : 12
      columns: n > 16 ? Math.ceil(n / 2) : Math.min(n, 12)
      spacing: 3
      readonly property real cw: (parent.width - (columns - 1) * spacing) / columns
      Repeater {
        model: col.sys.cpu.threads || []
        Rectangle {
          required property var modelData
          width: cells.cw; height: cells.n > 12 ? 20 : 42
          color: col.inSession ? col.pal.acc : col.pal.blue
          opacity: 0.12 + modelData * 0.88
          Behavior on opacity { NumberAnimation { duration: 500 } }
        }
      }
    }
    HText {
      anchors.bottom: parent.bottom
      text: col.inSession ? "■ en session" : "■ hors session"
      color: col.inSession ? col.pal.acc : col.pal.blue; font.pixelSize: 9
    }
  }

  // ------------------------------------------------------------- memory
  HPanel {
    pal: col.pal
    y: 180; width: 330; height: 124
    label: "Mémoire"
    note: col.sys.mem.total ? Math.round(col.sys.mem.total / 1073741824) + " Go" : ""

    Row {
      spacing: 16
      HiCanvas {
        id: ring
        width: 86; height: 86
        pixelScale: col.pixelScale
        property var parts: col.memParts
        onPartsChanged: requestPaint()
        function draw(ctx) {
          var total = col.sys.mem.total || 1
          var a = -Math.PI / 2
          ctx.lineWidth = 9
          for (var i = 0; i < parts.length; i++) {
            var da = parts[i].v / total * 2 * Math.PI
            var n = Math.max(1, Math.round(parts[i].v / total * 64))
            ctx.strokeStyle = col.pal.css(parts[i].c)
            for (var k = 0; k < n; k++) {
              ctx.beginPath()
              ctx.arc(43, 43, 36, a + k * da / n, a + (k + 0.7) * da / n)
              ctx.stroke()
            }
            a += da
          }
        }
      }
      Column {
        width: 200
        spacing: 3
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: col.memParts
          Row {
            required property var modelData
            width: 200
            HText { text: "■ "; color: modelData.c }
            HText { width: 120; text: modelData.n; color: col.pal.fg }
            HText { width: 64; horizontalAlignment: Text.AlignRight; text: col.sys.bytes(modelData.v); color: col.pal.fg }
          }
        }
      }
    }
    HText {
      anchors.centerIn: undefined
      x: 43 - width / 2; y: 43 - height / 2
      text: col.sys.mem.total ? Math.round(col.sys.mem.used / col.sys.mem.total * 100) + "%" : ""
      color: "white"; font.pixelSize: 13
    }
  }

  // ---------------------------------------------------------------- npu
  HPanel {
    pal: col.pal
    y: 316; width: 330; height: 116
    label: "NPU · Lemonade"
    note: col.sys.npu.up ? (col.sys.npu.busy ? "en calcul" : "prêt") : "arrêté"

    HText {
      width: parent.width
      text: col.sys.npu.model || "—"
      color: col.pal.fg
    }
    Row {
      y: 18; width: parent.width; height: 30
      HText {
        width: 50; anchors.bottom: parent.bottom
        text: col.sys.npu.tps ? Math.round(col.sys.npu.tps) : "–"
        color: col.pal.cyan; font.pixelSize: 22; font.weight: Font.DemiBold
      }
      HText { width: 50; anchors.bottom: parent.bottom; anchors.bottomMargin: 4; text: "tok/s"; color: col.pal.mut; font.pixelSize: 9 }
      Spark {
        width: parent.width - 100; height: 26; anchors.bottom: parent.bottom
        values: col.sys.npuHist; max: 60; color: col.pal.cyan
      }
    }
    HText {
      anchors.bottom: parent.bottom
      text: "FILE " + (col.sys.npu.running ? "▮" : "▯") + "▮".repeat(Math.min(6, col.sys.npu.waiting || 0))
        + " " + (col.sys.npu.waiting || 0) + " en attente · " + (col.sys.npu.requests || 0) + " requêtes"
      color: col.pal.dim; font.pixelSize: 9
    }
  }

  // --------------------------------------------------------------- apps
  HPanel {
    pal: col.pal
    y: 444; width: 330; height: 118
    label: "Applications"
    note: "CPU · RAM"
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
            width: 110
            text: modelData.name + (modelData.count > 1 && modelData.name !== "Hyprland + shell" ? " ×" + modelData.count : "")
            color: col.pal.fg
          }
          HBar {
            pal: col.pal
            width: parent.width - 110 - 40 - 46 - 18; anchors.verticalCenter: parent.verticalCenter
            value: Math.min(1, modelData.cpu * 2.5)
          }
          HText { width: 40; horizontalAlignment: Text.AlignRight; text: Math.round(modelData.cpu * 100) + "%"; color: col.pal.dim; font.pixelSize: 9 }
          HText { width: 46; horizontalAlignment: Text.AlignRight; text: col.sys.bytes(modelData.rss); color: col.pal.dim; font.pixelSize: 9 }
        }
      }
    }
  }

  // ------------------------------------------------------- week of focus
  HPanel {
    id: weekPanel
    pal: col.pal
    y: 574; width: 330; height: 138
    label: "Semaine · focus"
    tab: "stats"
    readonly property var days: col.prom.week ? col.prom.week.days || [] : []
    readonly property real focusTotal: days.reduce(function(a, d) { return a + (d.focusSeconds || 0) }, 0)
    note: Math.floor(focusTotal / 3600) + " h " + String(Math.floor(focusTotal % 3600 / 60)).padStart(2, "0")

    Row {
      spacing: 12
      // Mon–Sun: tracked time faint, focus bright.
      Column {
        width: 100
        spacing: 3
        Repeater {
          model: weekPanel.days
          Row {
            required property var modelData
            spacing: 4
            readonly property real span: 10 * 3600
            HText {
              width: 8
              text: "DLMMJVS".charAt(new Date(modelData.date + "T12:00:00").getDay())
              color: modelData.date === (col.prom.p ? col.prom.p.todayDate : "") ? col.pal.fg : col.pal.mut
              font.pixelSize: 8
            }
            Item {
              width: 84; height: 9
              Rectangle { width: Math.min(84, 84 * (modelData.trackedSeconds || 0) / parent.parent.span); height: 9; color: col.pal.alpha(col.pal.fg, 0.07) }
              Rectangle { width: Math.min(84, 84 * (modelData.focusSeconds || 0) / parent.parent.span); height: 9; color: col.pal.acc; opacity: 0.85 }
            }
          }
        }
      }
      // Weekday × hour over the last weeks.
      Column {
        spacing: 3
        readonly property var minutes: col.prom.extra && col.prom.extra.heatmap ? col.prom.extra.heatmap.minutes : []
        readonly property real maxM: {
          var m = 1
          for (var r = 0; r < minutes.length; r++) for (var c = 0; c < minutes[r].length; c++) m = Math.max(m, minutes[r][c])
          return m
        }
        Repeater {
          model: parent.minutes
          Row {
            required property var modelData
            spacing: 1.2
            Repeater {
              model: modelData
              Rectangle {
                required property var modelData
                width: 6.6; height: 9
                color: modelData > 0 ? col.pal.acc : col.pal.alpha(col.pal.fg, 0.05)
                opacity: modelData > 0 ? 0.15 + 0.85 * modelData / parent.parent.parent.maxM : 1
              }
            }
          }
        }
      }
    }
  }
}
