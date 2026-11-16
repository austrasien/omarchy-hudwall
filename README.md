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
- **System**: CPU, GPU, the NPU (Lemonade) over 24 h, RAM, applications,
  network and Tailscale peers, battery with the day from UPower.
- **The bar's icons**, top left, while the Omarchy bar stays hidden: with
  [austraz.bar](https://github.com/austrasien/omarchy-bar) and
  [austraz.tray](https://github.com/austrasien/omarchy-tray), their panels
  open beside the widget.

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
| `places` | `{}` | named points always on the globe, `{ "server": [lon, lat] }`, lit when Tailscale sees that host |

## IPC

```bash
omarchy-shell austraz.hudwall preview   # the HUD in a window, to look at it with a busy desk
omarchy-shell austraz.hudwall status    # active, deskEmpty, workspace, preview
omarchy-shell austraz.hudwall peek toggle   # the HUD over the windows, or back under them (also on / off)
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

On battery at 15 % or less, the HUD stops moving.

## Layout

| file | |
|---|---|
| `HudWall.qml` | entry: config, the layer surface, when the HUD is seen, IPC |
| `Hud.qml` | the 1440 × 960 stage, scaled to the screen |
| `Prom.qml`, `Sys.qml` | data: Prometheus calls, `bin/hudwall-collector` |
| `PromLeft.qml`, `SysRight.qml`, `BottomRow.qml`, `Center.qml` | the four areas |
| `Globe.qml`, `Rings.qml`, `MedalRack.qml`, `SessionBlock.qml`, `Announcement.qml` | centre pieces |
| `HPanel`, `HText`, `HBar`, `HButton`, `Spark`, `HiCanvas`, `HudPalette` | building blocks |
| `bin/hudwall-collector` | system readings, one JSON line a second (stdlib Python) |
| `bin/mmdb.py` | a minimal MaxMind DB reader |
| `bin/hudwall-fetch-data`, `bin/hudwall-land` | the datasets |

## License

MIT
