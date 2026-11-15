import QtQuick
import Quickshell
import Quickshell.Io

// Prometheus for the HUD: the pushed state through the plugin's own client
// (../austraz.prometheus/Prometheus.qml, idle reporting off: the bar does
// it), plus what the state does not carry, fetched slowly and only while
// the HUD is seen.
Item {
  id: prom

  property bool active: false

  readonly property var p: loader.item
  readonly property bool live: p ? p.live : false

  property var league: null        // leagues:get .current, + .leagues
  property var leagues: []
  property var season: null        // the running season
  property var boards: ({})        // days, weeks, sessions, quests -> leaderboard:get
  property var questList: null     // quests:list
  property var achievements: null  // achievements:list
  property var extra: null         // stats:extra
  property var insights: null      // stats:insights
  property var summary: null       // stats:summary (today)
  property var timeline: null      // stats:timeline (today)
  property var week: null          // stats:days 0
  property var lastWeek: null      // stats:days -1
  property var year: []            // [{ date, focusSeconds }], 53 weeks
  property var coffeeDay: null     // coffee:day
  property var coffeeStats: null   // stats:coffee
  property var tasks: null         // tasks:list
  property var goal: null          // hoursGoal:get
  property var names: null         // sessions:names
  property var yesterday: null     // stats:timeline of yesterday, for the ghost race
  property var bestDay: null       // stats:timeline of the best day

  signal toast(string kind, string title, string text, string rarity)

  Loader {
    id: loader
    source: Qt.resolvedUrl("../austraz.prometheus/Prometheus.qml")
    onLoaded: item.idleTimeout = 0
    onStatusChanged: if (status === Loader.Error) console.warn("hudwall: Prometheus client not found next to the plugin")
  }
  Connections {
    target: prom.p
    ignoreUnknownSignals: true
    function onToast(kind, title, text, rarity, extra) {
      prom.toast(kind, title, text, rarity)
      fast.restart()
    }
    function onLiveChanged() { if (prom.live && prom.active) prom.refreshAll() }
  }

  function call(channel, args, then) {
    if (!p || !live) return
    p.call(channel, args || [], function(ok, d) {
      if (ok && d && d.success !== false) then(d)
    })
  }

  // The daemon's day starts at dayStartHour.
  function dayStart(offsetDays) {
    var start = new Date()
    var h = p ? p.dayStartHour : 5
    if (start.getHours() < h) start.setDate(start.getDate() - 1)
    start.setHours(h, 0, 0, 0)
    start.setDate(start.getDate() + (offsetDays || 0))
    return start.getTime()
  }

  function refreshFast() {
    call("leagues:get", [], function(d) { prom.league = d.current; prom.leagues = d.leagues || [] })
    call("stats:insights", [], function(d) { prom.insights = d })
    call("stats:summary", [{ fromMs: dayStart(0), toMs: Date.now() }], function(d) { prom.summary = d })
    call("stats:timeline", [], function(d) { prom.timeline = d })
    call("stats:days", [0], function(d) { prom.week = d })
    call("coffee:day", [dayStart(0)], function(d) { prom.coffeeDay = d })
    call("quests:list", [], function(d) { prom.questList = d })
    call("tasks:list", [], function(d) { prom.tasks = d })
    call("hoursGoal:get", [], function(d) { prom.goal = d.goal ? d : null })
  }

  function refreshSlow() {
    call("seasons:get", [], function(d) {
      var s = (d.seasons || []).filter(function(x) { return x.running })
      prom.season = s.length ? s[0] : ((d.seasons || [])[0] || null)
    })
    ;["days", "weeks", "sessions", "quests"].forEach(function(b) {
      call("leaderboard:get", [b], function(d) {
        var next = Object.assign({}, prom.boards)
        next[b] = d
        prom.boards = next
        if (b === "days") prom.bestDayTimeline()
      })
    })
    call("achievements:list", [], function(d) { prom.achievements = d })
    call("stats:extra", [], function(d) { prom.extra = d })
    call("stats:coffee", [], function(d) { prom.coffeeStats = d })
    call("sessions:names", [], function(d) { prom.names = d })
    call("stats:days", [1], function(d) { prom.lastWeek = d })
    call("stats:timeline", [{ fromMs: dayStart(-1), toMs: dayStart(-1) + (Date.now() - dayStart(0)) }], function(d) { prom.yesterday = d })
    geek.running = true
  }

  // The best day by XP on the leaderboard, as a timeline, for the ghost race.
  function bestDayTimeline() {
    var b = boards.days
    if (!b || !b.entries || !b.entries.length) return
    var top = b.entries[0]
    if (!top.date) return
    var parts = top.date.split("-")
    var d = new Date(+parts[0], +parts[1] - 1, +parts[2], p ? p.dayStartHour : 5, 0, 0, 0)
    call("stats:timeline", [{ fromMs: d.getTime(), toMs: d.getTime() + 86400000 }], function(t) { prom.bestDay = t })
  }

  // A year of days for the outer ring, one week per call, spread out.
  property int yearWeek: 0
  property var yearAcc: []
  function refreshYear() { yearWeek = 0; yearAcc = []; yearStep.start() }
  Timer {
    id: yearStep
    interval: 150
    repeat: true
    onTriggered: {
      if (!prom.active || prom.yearWeek > 52) {
        stop()
        if (prom.yearWeek > 52) { prom.year = prom.yearAcc; prom.lastYear = Date.now() }
        return
      }
      var w = prom.yearWeek
      prom.yearWeek++
      prom.call("stats:days", [w], function(d) {
        prom.yearAcc = prom.yearAcc.concat((d.days || []).map(function(x) { return { date: x.date, focus: x.focusSeconds || 0 } }))
      })
    }
  }

  function refreshAll() { refreshFast(); refreshSlow() }

  // Today's geek date, from Prometheus' own calendar (prometheus/geekdates.py
  // in the repository the bar plugin is linked from).
  property var geekDate: null     // [id, name, description, line] or null
  readonly property string promPlugin: Qt.resolvedUrl("../austraz.prometheus").toString().replace(/^[a-z]+:\/\//, "")
  Process {
    id: geek
    command: ["python3", "-I", "-c",
      "import sys, os, json, datetime\n" +
      "root = os.path.dirname(os.path.realpath(sys.argv[1]))\n" +
      "sys.path.insert(0, root)\n" +
      "from prometheus import geekdates\n" +
      "print(json.dumps(geekdates.event_on(datetime.date.today())))",
      prom.promPlugin]
    stdout: StdioCollector { onStreamFinished: { try { prom.geekDate = JSON.parse(this.text) } catch (e) { prom.geekDate = null } } }
  }

  onActiveChanged: if (active && live) { refreshFast(); if (Date.now() - lastSlow > 120000) { refreshSlow(); lastSlow = Date.now() } }
  property real lastSlow: 0
  property real lastYear: 0

  Timer {
    interval: 60000; repeat: true; running: prom.active && prom.live
    onTriggered: prom.refreshFast()
  }
  Timer {
    interval: 300000; repeat: true; running: prom.active && prom.live
    onTriggered: { prom.refreshSlow(); prom.lastSlow = Date.now() }
  }
  Timer {
    interval: 2000; repeat: true; running: prom.active && prom.live
    onTriggered: if (!yearStep.running && Date.now() - prom.lastYear > 3600000) prom.refreshYear()
  }
  // After a toast or an action: refresh what may have moved.
  Timer { id: fast; interval: 600; onTriggered: if (prom.active) prom.refreshFast() }
  function poke() { fast.restart() }

  // ---- actions (they also poke a refresh)

  function act(channel, args) {
    if (!p || !live) return
    p.call(channel, args || [], function() { prom.poke() })
  }
}
