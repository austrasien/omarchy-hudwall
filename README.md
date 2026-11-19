# HUD wallpaper (austraz.hudwall)

A live HUD behind the windows of an Omarchy desktop, drawn by the Omarchy
shell on the Bottom layer: above the wallpaper, under every window.

- **Centre**: a globe lit by the real sun, with arcs from home to the last
  ten public peers this machine talked to (the app's icon on each), land
  dots heated by the bytes exchanged; it sweeps over the routes only when
  they do not all fit its visible face. Around it, today's 24 hours cut by
  application and the year, a tick a day.
- **Prometheus** ([omarchy-prometheus](https://github.com/austrasien/omarchy-prometheus)):
  level and XP, the medal rack, league race and rival, the season and its
  medal, quests and achievements, the session with its controls and
  challenges, caffeine and its effect on tokens, focus quality, ghost races
  (focus and agent tokens), today against yesterday, the week. Its messages
  (medals, achievements, "Still there?", coffee) come down from the top of
  the screen over every window, in a notch.
- **Services**: a beacon per service you list (`uptime`) on the arc over
  the globe, west to north to east; hover one for its data card. See below.
- **System**: CPU, GPU, the NPU (Lemonade) over 24 h, RAM, applications,
  network and Tailscale peers, battery with the day from UPower.
- **The bar's icons**, top right, while the Omarchy bar stays hidden: with
  [austraz.bar](https://github.com/austrasien/omarchy-bar) and
  [austraz.tray](https://github.com/austrasien/omarchy-tray), their panels
  open left of the widget. The company mark (`mark` in hudwall.json) sits top left.

It only animates and collects while the workspace shown on its monitor has
no window. Covered, it costs nothing.

## Install

The folder lives in `~/.config/omarchy/plugins/austraz.hudwall`, next to
`austraz.prometheus` (its Prometheus client is loaded from there).

```bash
omarchy plugin enable austraz.hudwall
~/.config/omarchy/plugins/austraz.hudwall/bin/hudwall-fetch-data
```

`hudwall-fetch-data` downloads two public datasets into
`~/.local/share/hudwall`: Natural Earth's land (via the world-atlas package,
public domain) rasterised into `land.png` for the globe, and DB-IP's free
IP-to-city database (CC BY 4.0) to place peers. Lookups stay on the machine.
Without them the globe shows no land and peers stay unplaced.

After editing QML, restart the shell (`omarchy-restart-shell`): hot reload
keeps stale sibling components.

## Settings

`~/.config/omarchy/hudwall.json`, all optional:

| key | default | |
|---|---|---|
| `visible` | `true` | show the HUD at all |
| `monitor` | first screen | connector name, e.g. `eDP-1` |
| `backdrop` | `1` | opacity of the HUD's own background; below 1 the wallpaper shows through |
| `home` | `[0, 51.48]` | `[lon, lat]` where the arcs start |
| `mark` | none | `{ "image": "~/path/logo.png", "name": "ACME" }`: the mark at the top of the right column (the host name without it) |
| `fps` | `24` | globe frame rate while seen (5–60) |
| `pingPeers` | first 3 online | Tailscale host names to ping for latency |
| `uptime` | `[]` | services shown as beacons over the globe (below) |
| `uptimeSource` | none | URL of the watcher whose states the beacons show (below) |
| `places` | `{}` | named points always on the globe, `{ "server": [lon, lat] }`, lit when Tailscale sees that host |

## Services (beacons)

The HUD does not check anything itself: a watcher running elsewhere (a
server that stays up) does, and the HUD shows what it reads from it every
15 s, so one copy of the checks, round the clock, with their history.

```json
"uptimeSource": "https://watcher.example:8444/status",
"uptime": [
  { "name": "API", "url": "https://api.example.com", "note": "production" },
  { "name": "NAS", "tcp": "192.0.2.10:22", "open": "xdg-terminal-exec ssh nas" },
  { "name": "WATCH", "watcher": true, "note": "the watcher's own server" }
]
```

`uptimeSource` answers
`{ "targets": [{ "name", "state", "since", "ms", "code", "cert", "err", "checked", "hist" }] }`,
`state` one of `up`, `slow`, `down`, `off`, `nolink`, `wait`; `hist` the
last checks as `[time, ms or null, "u"|"s"|"d"]`. The `uptime` list gives the
order and, for each beacon, its name, `note`, target (`url` or `tcp`, shown
only) and what a click opens (`open`, the URL by default). A service the
watcher does not keep shows as pending; `"watcher": true` is the watcher
itself, up while it answers. While the watcher cannot be read, every beacon
is a grey ring (`NO WATCHER`): nothing is known, which is not an outage.

The beacons sit on the arc over the globe, just outside the months, from
west-south-west to east-south-east. A service that answers is a plain dot
in the HUD's accent (the colour of the panels' titles); amber: slow, or a
certificate expiring within 14 days; red, with the two rings of a ping: down.
A hollow grey ring: the watcher cannot tell (`NO LINK`, `NO TAILNET`) or cannot
be read. Hovering a beacon locks a data card onto it, the day tape's way
(wipe, closing brackets, scan line, typed text on a worn tape): target,
state and since when, latency, HTTP status, certificate, last check, error,
and the ping history of the last checks (a bar each, red when failed) with
the uptime over them. A click opens the service.

## IPC

```bash
omarchy-shell austraz.hudwall preview   # the HUD in a window, to look at it with a busy desk
omarchy-shell austraz.hudwall status    # active, deskEmpty, workspace, preview
omarchy-shell austraz.hudwall peek toggle   # the HUD over the windows, or back under them (also on / off)
omarchy-shell austraz.hudwall beacon 2    # the data card of service beacon 2, as a hover would (-1 closes it)
```

### Peek with a key

To bring the HUD over the windows with a key (here Super+H, again to send it
back), in `~/.config/hypr/bindings.lua`:

```lua
hl.unbind("SUPER + H")
o.bind("SUPER + H", "Show/hide the HUD over the windows",
  hl.dsp.exec_cmd("omarchy-shell austraz.hudwall peek toggle"))
```

The HUD comes up like an old VHS tape whose grid drops out tile by tile
(`shaders/fog.frag`), and goes back the same way.

### The HUD as every theme's background

So that a shell restart shows the HUD while it loads, not a photo:

```bash
bin/hudwall-theme-snapshots --select   # all themes; or name some: ... tokyo-night nord
```

The HUD comes over the windows, renders in each theme's colours in turn and
saves itself as `~/.config/omarchy/backgrounds/<theme>/00-hudwall.png`;
`--select` makes it each theme's remembered background (then
`omarchy-theme-bg-set` it for the current theme). After the HUD has been on
screen a minute, the current theme's snapshot is refreshed (at most every six
hours).

## Cost

Measured on a Framework 13 (Ryzen AI 300, 2304 × 1536 logical), whole
shell process: about 4 % of a core with the HUD disabled, about 13 % with the
HUD on screen at 24 fps (no GeoIP yet, so no arcs). In the preview window,
eight arcs added about 5 %. Covered by windows, the stage is not drawn and the
collector is stopped. The globe is a fragment shader (`shaders/globe.frag`,
compiled with
`/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o shaders/globe.frag.qsb shaders/globe.frag`);
animated Canvases were far too costly (arcs alone: about 57 % of a core).

Once the globe has settled on its routes it draws one frame a second (24
while it turns): with the HUD on screen the shell then costs about 2 % of a
core more than with it hidden. The collector reads the battery every 5 s and
the NPU journal only after the NPU served requests.

Any running Qt animation, a pause in a looping one included, makes Qt
redraw the whole HUD at 60 fps for as long as it runs: with the league
glint, the season ribbon's shine, the ghosts' float and the CPU threads'
easing it was at 60 fps all the time, about 60 % of a core. What keeps
moving now steps on one 8 Hz clock (`beat` in Hud.qml), on the same frames:
the globe, the ghosts, the league glint (every 8 s), the season shine (a
sweep every 12 s: its layer effect costs two frames a step), and the
collector's readings, applied on the next beat; data-driven bars no longer
ease. About 11 frames a second, 19 % of a core for the whole shell
(measured 2026-11-19 with `frames` below). A new animation should step on
`beat` rather than loop or ease.

`omarchy-shell austraz.hudwall frames` gives the frames drawn so far; twice
a few seconds apart, the frame rate.

On battery at 15 % or less, the HUD stops moving.

## Layout

| file | |
|---|---|
| `HudWall.qml` | entry: config, the layer surface, when the HUD is seen, IPC |
| `Hud.qml` | the 1440 × 960 stage, scaled to the screen |
| `Prom.qml`, `Sys.qml` | data: Prometheus calls, `bin/hudwall-collector` |
| `PromLeft.qml`, `SysRight.qml`, `BottomRow.qml`, `Center.qml` | the four areas |
| `ServiceBeacons.qml` | the services' beacons over the globe and their data card |
| `Globe.qml`, `Rings.qml`, `MedalRack.qml`, `SessionBlock.qml`, `Announcement.qml` | centre pieces |
| `HPanel`, `HText`, `HBar`, `HButton`, `Spark`, `HiCanvas`, `HudPalette` | building blocks |
| `bin/hudwall-collector` | system readings, one JSON line a second (stdlib Python) |
| `bin/mmdb.py` | a minimal MaxMind DB reader |
| `bin/hudwall-fetch-data`, `bin/hudwall-land` | the datasets |

## License

MIT
