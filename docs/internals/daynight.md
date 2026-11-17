# Day and night: how it works

The player's side is in [Features](../features.md#features), the `daynight` setting in
[Settings](../settings.md#coop-settingstxt) and `coop daynight` in [Keys and commands](../usage.md#console-commands). The
cycle is not tested in game yet. Every address and offset below is build 26123051's, read in Ghidra.

The code:

- `native/src/game/sky.h`: the clock, the sun and moon, the light factors, the writer of SB's env array and the status
  line, with no Windows types, tested on the build machine;
- `native/src/glue/tick/sky_game.inc`: the game thread's pass inside `coop_tick`, under its own SEH latch;
- `native/src/glue/tick/sky_worker.inc`: Lua's request, the log lines and the `sky=` line of `coop-status.txt`;
- `mod/StellarCoop/Scripts/sky/rule.lua`: the map table and the rules, with no engine call;
- `mod/StellarCoop/Scripts/sky/daynight.lua`: the request in the 250 ms pass, the sky dressing and SBO's own maps;
- `mod/StellarCoop/Scripts/commands/daynight.lua`: `coop daynight`.

The list of features follows the README of dCharisma1's "Activate Day Night Cycle" plugin for CPS. SBO uses none of its
code or values.

## The clock

One real hour is one game day, the same for every player. The native part reads the PC's UTC clock
(`GetSystemTimePreciseAsFileTime`) at each pass:

```
t    = UTC time in seconds since 1970, with its fraction
hour = 24 * (((t - 120) mod 3600) / 3600)          0 <= hour < 24
```

Midnight falls at :02 past each real hour, sunrise (04:00) at :12, noon at :32 and sunset (20:00) at :52. Lua never
computes the hour: it reads it from the native status line, so the formula lives in one place. A PC clock one second
off moves the sun by under 0.1 degree. Two SBO players on the same map see the same sky with no network message.

## The sun and the moon

The day (04:00 to 20:00) and the night (20:00 to 04:00) are two sine arcs:

```
day   p = (hour - 4) / 16             elevation = 65 * sin(pi * p)       heading = H + 180 * (p - 0.5)
night q = ((hour - 20) mod 24) / 8    elevation = -30 * sin(pi * q)      heading = H + 90 + 180 * q
```

The sun peaks at 65 degrees at noon and sinks to 30 degrees under the horizon at midnight. `heading` is the yaw of the
light, the direction it travels. `H` is each map's noon heading, taken from the light of the map's main preset, so at
noon the shadows fall the way SB's artists drew them. Under -4 degrees the moon is the light: the point opposite the
sun, 30 degrees up at midnight. The vector written into SB's settings is `(cos le cos ly, cos le sin ly, -sin le)`,
with `le` and `ly` the light's elevation and heading.

## Dawn and dusk

Every ramp runs on the sun's elevation `el`, so it is the same on every PC. `ramp(x, a, b)` is a smoothstep, 0 at `a`
and 1 at `b`. `hz` is the map's horizon: 2 degrees on flat desert, 8 elsewhere.

| Value | Formula | Day | Full night |
| --- | --- | --- | --- |
| Sun light | `ramp(el, hz, hz + 10)` times the preset's sun | 1 | 0, so SB culls the light |
| Moon light | `0.15 * ramp(el, -4, -12)` times the preset's sun | 0 | 0.15 |
| Night amount `n` | `1 - ramp(el, -12, 6)` | 0 | 1 |
| Sky light | `1 - 0.8 n` | 1 | 0.2 |
| EVE's two character lights | `1 - 0.5 n` | 1 | 0.5 |
| Fog colour | `1 - 0.85 n` | 1 | 0.15 |
| Sun glow in the fog | the sun light's factor | 1 | 0 |
| Exposure | `-1.0 n` EV, only where the preset sets its own bias | 0 | -1 EV |
| Sun colour | from (1.00, 0.55, 0.30) at `hz` to white at `hz + 15` | white | |
| Moon colour | (0.70, 0.80, 1.00) | | cold |

With `hz` 8 the sun is full until about :48 and gone at :50. The moon fades in from :53 to :55. Full night runs from
:55 to :09 and the moon fades out from :09 to :11. The sun is back at :14 and full at :16. The stars show from about :54
to :10.

## Maps

`sky/rule.lua` keys each map by its world's package path in lower case, as `U.map_of` gives it. A map with no row is
never touched.

| Map | Sky | `hz` | `H` |
| --- | --- | --- | --- |
| Wasteland (E03) | real, SBO's star layer | 8 | 0 |
| Great Desert (E05) | SkyCreator | 2 | 200 |
| Eidos 7 (F02) | real, SkyCreator stars | 8 | 88 |
| Eidos 9 (F01) | real, SkyCreator stars | 8 | 88 |
| Xion (E04) | painted, SB's night dome | 8 | 205 |
| Matrix 11 | real, SBO's star layer | 8 | 172 |
| Spire 4 (B07) | real (four domes), SkyCreator stars | 8 | 242 |
| NIKKE minigame, Waste | real, SBO's star layer | 8 | 60 |
| NIKKE minigame, City | real, SBO's star layer | 8 | 76 |
| Matrix XIII (SBO) | engine | 2 | 85 |
| Hotel, Station, Cloister and Foyer halls | engine | 8 | 308, 61, 230, 61 |

These maps keep their fixed light: the NIKKE boss arena (a night map, SBO's free-for-all arena), the prologue's beach
(G03), the Nest (C05, covered, with story skies), Altess Levoire, Abyss Levoire, the ending and the epilogue, the
Terrace hall (the night hall) and the title world.

How each kind of sky is dressed:

- Real: the map's painted sky domes are hidden while the cycle runs. The SkyAtmosphere already in each of these maps
  draws the sky from the env sun: blue at noon, orange near the horizon, dark at night under the moon light.
- SkyCreator: each 250 ms pass calls `SetTime` on the map's SkyCreator actors when the hour moved. Our 04:00 to 20:00
  maps onto the actor's own `SunriseTime` to `SunsetTime`, our night onto the rest, so its star map and its moon turn
  with our sun. An off gives each actor the time it had.
- SBO's star layer: one `StaticMeshComponent` of ours on the first hidden dome's actor, showing the dome's own mesh with
  SB's star material of the Nest's night ending (`001_A_MI_C05_Star_SKY`), no collision, no shadow. It is added the
  first time the stars show in a world and tagged `SBO_Stars`, so a Lua reload finds it again instead of adding a
  second one. When the material has a scalar parameter whose name holds `Emissive`, `Bright`, `Intens` or `Opacity`,
  the layer shows from -4 degrees with a dynamic instance faded in down to -8. Without one it shows from -8 degrees,
  when the sky is already dark.
- Painted (Xion): the day dome stays. At -4 degrees and below it hides and SB's own night dome (`SM_SkySphere_NIGHT`)
  shows.
- Engine (SBO's own maps): these maps have no SB env settings, so the native part writes nothing there. Lua turns the
  `Sun` actor to pitch `-le` and yaw `ly` when either moved 0.01 degree or more. Its light's intensity becomes the one
  it had times `k`, its colour the one it had times the tint. The `SkyLight`'s intensity becomes the one it had times
  `amb`. Matrix XIII's zone 0 runs auto exposure (`Z0_PPV_Desert`, bias 1.0): its bias becomes `1.0 + 2 * ev`,
  down to -1.0 at full night. The halls use manual exposure, so a dimmer light is a darker picture. Each value is
  written only when it changes and put back at an off.

## Rules

`Rule.decide` gives the request for the native part with its reason. The first case that matches wins:

| Case | Read through | Request |
| --- | --- | --- |
| `daynight=off` | the setting | `sky off` |
| `coop daynight off` | the command | `sky off` |
| No EVE (the title screen) | the map read | `sky off` |
| A map with no row or a fixed one | the table | `sky off` |
| The SBO lobby in Xion's training room | `sbo.in_lobby()` with no hall | `sky off` |
| Xion's story night (Burning Xion) | `bActiveVolume` of `E04_Area_02_Global_ENV_01_NIGHT`, read every 2 s on Xion | `sky off`, Xion's domes left to SB |
| An SB cutscene or dialogue scene, in an online session | `group.cutscene_playing()`, read once a second while a friend is linked | `sky off` |
| SB's pause menu or one of its screens | `kit.paused(true)` | `sky off`: their studio scenes are env volumes too |
| Photo mode | `photo_state()` | `sky hold`: the hour it opened at |
| `coop daynight hour <h>` | the command | `sky hour <minute> <hz> <H>` |
| Night Operation runs | `night.running()` | `sky hour 0 <hz> <H>`: midnight |
| Anything else | | `sky cycle <hz> <H>` |

A covered spot in an open map (a cave, a room, a lab) keeps its own light at any hour: see the sunlit rule below.

The native part does not wait for Lua to see a cutscene. At each of its passes, in every mode, solo included, it reads
SB's own test for a theater (a cutscene or a talk scene): the theater manager's theater, set and not finished. While
one plays, it puts SB's values back and writes nothing (state `scene`). The scene's `CutScene_` and `Dialogue_` volumes
then blend SB's light. Lua puts its dressing back too, since `scene` is not a state where the sky follows our sun.

## What the native part writes

On every SB map with env volumes, the sun, the sky light, EVE's two character lights, the height fog, the
SkyAtmosphere and part of the post process come from SB's env settings, not from the light components. Each frame, for
each view, `FUN_1446B00A0` blends the array `AWorldSettings.WorldEnvControlSettings` (data at WorldSettings `+0x2E0`,
`Num` at `+0x2E8`, elements of `0xB30` bytes). It asks each element's volume (`+0x18`, vtable `+0x6C0`) for its weight,
merges the elements that share a data pointer (`+0x20`), clamps the weights to a sum of 1 at most, then sums
`w * element` field by field (`FUN_1444F60D0`). When WorldSettings `+0x2F0` and `+0x2F8` are set (SB's
`ApplySBEnvSettingDataToScene`), it copies that one forced block instead and skips the array. `FUN_1430FA210` culls an
env light whose blended intensity is 0 or less.

So the cheapest correct write goes into the array's elements: SB's own blend does the per-frame work. The native
part reaches the array every 100 ms (`sky::kPassMs`; the sun moves 0.01 degree in that time) through SB's player
controller getter (`FUN_142321EE0`), its `GetWorld` (vtable `+0x158`), the world's persistent level (`+0x30`) and the
level's WorldSettings (`+0x268`), the reach `freeze_game.inc` uses. Per element:

| Field | Offset | Written in | Value |
| --- | --- | --- | --- |
| `Direction_Sun` | `+0x4C` | every element | the light's travel vector (sun or moon) |
| `Color_Sun` RGB | `+0x5C` | sunlit elements | the original times the sun or moon colour |
| `Intensity_Sun` | `+0x70` | sunlit elements | the original times the sun or moon factor; 0 culls the light |
| `Intensity_SkyLight` | `+0x180` | sunlit elements | the original times the sky light factor |
| `Intensity_Character` | `+0x1D8` | sunlit elements | the original times EVE's factor |
| `Intensity_CharacterSub` | `+0x20C` | sunlit elements | the original times EVE's factor |
| `FogInscatteringColor` RGB | `+0x254` | sunlit elements | the original times the fog factor |
| `DirectionalInscatteringColor` RGB | `+0x2AC` | sunlit elements | the original times the sun factor |
| `PostProcessData.AutoExposureBias` | `+0x76C` | sunlit elements whose override byte `+0x43B` has bit `0x02` | the original plus the night EV |

A sunlit element is one whose original `Intensity_Sun` is above 0. Every other element (a cave, a room, a lab, Matrix
11's underground) gets only the direction, which changes nothing while its sun is 0. The `bUse` bytes are never
written: the readers ignore them.

The rules of a pass (`sky::Sky::pass`):

- A theater plays (WorldSettings aside): SB's values back, nothing written (state `scene`). The theater manager is the
  global `0x1470375a0`, read and never made since its getter allocates. Its `+0x18` is the theater; `FUN_1424d70c0`
  tells whether it has finished: the test SB itself makes in `FUN_141e0f720` and `FUN_142554300`.
- SB's forced settings in place: nothing written, the array left as it is (state `forced`). An off still puts the array
  back.
- WorldSettings `+0x2018` set (the blend gated by the `bUse` bytes): SB's values back, nothing written (`gated`). No map
  is known to set it.
- More than 256 elements: SB's values back, nothing written (`full`). The largest array in the map dump holds 114.
- Each pass reads the array's pointer and `Num` again, reads the originals of each element it has not seen, then
  writes every field from the originals. A full write each pass heals a copy SB makes into an element, such as a
  sublevel streamed in again.
- An element is known when its volume and data pointers are cached and its `Intensity_Sun` is still its original or
  the value the last pass wrote. Anything else (SB copied other values in, or a new world reused the address) is read
  as new, so cached originals never land on an element they do not belong to.
- Another world or WorldSettings, or none: the cache is dropped, since the old array died with its world.
- An off (the request, `coop off`, a cutscene in an online session, SB's screens): each element of the current world that still holds our
  value or its original gets its originals back once, then nothing is written.
- The first fault: one try to put SB's values back, then the cycle stays off for the game run (state `fault`).

Two caches of 256 elements swap each pass, so a pass allocates nothing. WorldSettings `+0x1420` (the main view's copy
is set) and `+0x14A0` (the blended sun intensity at the camera) say for free whether EVE stands in env sunlight
(`seen=` on the status line).

## The request and the status line

Lua asks through `coop-request.txt`, a local file that never goes on the wire:

```
sky off
sky cycle <hz> <H>              hz 0 to 30, H 0 to 359, whole degrees
sky hour <minute> <hz> <H>      minute 0 to 1439 of the game day
sky hold                        the hour of the pass that took it, kept
```

`coop-status.txt` gets one line at each worker pass:

```
sky=cycle h=13.42 el=61.3 le=61.3 ly=211.9 k=1.000 moon=0 amb=1.000 eve=1.000 ev=0.00 tint=1.00,1.00,1.00 n=114 lit=20 seen=1
```

The state is `off`, `cycle`, `pinned`, `held`, `waiting` (no world or no array), `forced`, `scene` (SB plays a theater),
`gated`, `full`, `fault` or `refused` (off the pinned game build: the values are computed, nothing is written). `h` is the hour, `el` the sun's
signed elevation, `le` and `ly` the light's elevation and heading (sun or moon), `k` the light's factor, `moon` 1 when
the moon is the light, `amb` the sky light's factor, `eve` that of EVE's lights, `ev` the exposure offset, `tint` the
light's colour, `n` the elements, `lit` the sunlit ones and `seen` 1 when EVE stands in env sunlight. The line moves
each second, so it stays out of the `link:` lines of `UE4SS.log`.

`coop-link.log` gets a `sky:` line at each change of state and at each new world the cycle writes in, for example
`sky: cycle, 114 volumes, 20 in the sun`, then `sky: not written: <why>` once per request off the pinned build and the
fault once. `UE4SS.log` gets a `daynight:` line at each change of the request or its reason (`daynight: cycle 8 0
(clock)`) and one at each world entry with what the lookups found and the time they took. A part that is missing or
that refuses a write gets one line, once per world.

## Lua's part

`main.lua` calls `daynight.slow(off)` in its 250 ms loop, after `coop off` too, so the cycle asks `sky off` once then.
The pass reads the map with `U.map_of` only when EVE's address changes, never on a timer. It reads SB's state only on a
map whose row is on, decides the request and sends it only when it changes. Then it dresses the sky from the status
line's values while the native state is one where the sky follows our sun (`cycle`, `pinned`, `held` or `forced`).

Each part of the dressing is looked up once per world: the domes by their full object path, the SkyCreators and
the engine maps' lights through `U.actors_of`'s class hash, Xion's story-night volume by its path. A lookup that misses
logs one line and is not tried again in that world. Each write goes through a `pcall` on a part that is still valid; a
write that fails is logged once and that part left alone in the world. The star material comes through one synchronous
`LoadAsset` the first time the stars show in a world, timed in its log line.

An off puts SB's look back: the domes shown, each SkyCreator's own time, the star layer hidden, Xion's two domes as SB
ships them (except during its story night, which SB owns), the engine maps' lights and bias as the lookup read them. A
Lua reload that starts while the native part still holds an earlier load's cycle looks the parts up again, so it can
put that load's dressing back.

## Cost

The third-party plugin's README says the stutter of its 1.5.0 came from searching every light of the game every 2 s.
SBO searches nothing on a timer.

| Where | Work | Bound |
| --- | --- | --- |
| Native, each frame | one clock read and one compare | |
| Native, every 100 ms | two SB calls and six pointer reads; up to 256 elements, each a key compare and up to 22 float writes | the minute line's native tick maximum shows it |
| Lua, every 250 ms | the rules on cached values, the pass's status text, a request only on change | |
| Lua, SkyCreator maps | one `SetTime` a pass while the hour moves | 4 calls a second |
| Lua, SBO's own maps | up to 4 reflected writes a pass, only on change | 16 a second |
| Lua, Xion | one bool read | every 2 s |
| Lua, each world entry | up to 4 dome lookups by path, one class-hash list, one star material load on star-layer maps | once per world |
| Lua, each frame | nothing | |
| GPU | no new light, shadow or effect; a hidden dome is one draw less; the star layer is one sphere at night | |

The star material's load is synchronous. If its logged time passes 16 ms, it moves to SB's async load, the call the
bike's preload uses (`bike_game.inc`).

## Online

The clock is common, so the cycle sends nothing: no line on the wire, no lobby key, no protocol change. Light is world
state, so it never enters the capture and starts no new generation of the ghost. The hall lobbies follow the clock for
every member. The free-for-all arena keeps its night. Night Operation pins midnight on every game that runs it. An hour
pinned by a private match's creator would need a lobby key and a protocol change, so it is left for later.

## Next to the plugin

The "Activate Day Night Cycle" plugin and SBO write the same light. At its first pass, Lua checks once whether
`CPS/Plugins/activate_day_night_cycle.cps` exists beside the game's `Win64` folder and logs one line asking to turn one
of them off. It turns nothing off by itself.
