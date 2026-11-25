# Matrix XIII: the cut area (experimental)

The game's tables keep an area that was cut before release, Matrix XIII (world `DLCMatrix13`), with four zones and the
enemies of each, but no pak holds its map and no camp or warp leads there. `coop mxiii` tests one way in and gives the
first zone a camp; `coop mxiii 30` goes to a second camp, in the third zone. It needs the zMXIII_P test pak, which does
not come with the mod: a map at the path the game's world table names, built from shipped Matrix 11 levels. Without that
pak the command refuses and changes nothing. It is a test command, left out of the usage line, and runs only alone (not
in a session) on a [co-op save](../players/playing-with-a-friend.md#co-op-saves). Its lines go to `UE4SS.log` as
`[StellarCoop][MX]`, the travel's as `[StellarCoop][TR]`.

[Lily's signal](lily-signal.md) leads into the same area through two quests of the mod's own. The rows and the camp
travel behind the command are described in [world/matrix13-internals.md](matrix13-internals.md).

## The test pak

The test pak has five builds. The command logs which one it found and goes on with v5 only. v1 holds the map, the
zone and the enemies' spawn points, with the camp's arrival point at the start of the area. v2 adds spawn points for the
camp's six objects and its coin at the site of Matrix 11's first simple camp (`ME01_Camp_01`, in Area01), and moves
the arrival point there. v3 adds the arrival point of the third zone's camp at the site of Matrix 11's camp
`ME03_Camp_01` (26392, -23650, 4414, in Area03), between the two doors that v2 already moves out of the way, and moves
that Matrix 11 camp's six objects out of the way too. It also moves the vending machines of Matrix 11's other camps in
those levels, since activating a Matrix 11 camp counts toward the camp trophy. v2 leaves one of them in the first zone
(Matrix 11's `ME01_Camp_02`, at 28804, 1308): do not use it. v4 is the full map, with the arrival point of the
Tetrapod camp beside Lily. v5 adds the `MXIII_Camps_A` level, which places the objects of the first zone's two camps.
The mod's rows for those camps use these placed objects, so with an older pak the two camps would have none, and
`coop mxiii` and `coop mxiii 30` refuse it.

## Using `coop mxiii`

1. With the game closed, put `zMXIII_P.utoc`, `zMXIII_P.ucas` and `zMXIII_P.pak` in `SB/Content/Paks/~mods` (or
   `SB/Content/Paks/LogicMods`).
2. Load a co-op save you can lose. Entering a world the save has never been in may write that world, its zone and its
   enemies into the save; `coop saves refresh <0-4>` at the title replaces a co-op copy with a new copy of your save.
   Once the game saves inside the area, that co-op save loads only while zMXIII_P is installed. The camp's rows
   live in memory only, so the mod adds them again at the title of each game start, before you load a save, while the
   pak is installed and the game uses the co-op saves (see the save notes below). Before you remove the pak, replace
   that copy with `coop saves refresh <0-4>`.
3. Type `coop mxiii`. It checks the pak and the travel's conditions and adds the rows to the game's tables in memory,
   unless they went in at the title already. Among them are
   the camp `DLC02_10_Camp_01`, a row in the area's first zone (`Zone_DLC02_10`) that leads the travel there, one
   row for each of the camp's six objects, and the third zone's camp `DLC02_30_Camp_01` with the row in
   `Zone_DLC02_30` that leads there. It also switches on two of the fourth zone's own trigger rows in memory, so
   the enemies that wait for its drain devices appear (see below). Then it asks the game's
   own camp travel to go there, as `coop travel probe` does for an activated camp. EVE arrives at the Tetrapod camp
   `DLC02_00_Camp_00`, beside Lily, with no camp of the area active. Before any of that it checks that
   the other seven batches (Naytibas; loot; the mechanisms of zones 0 to 2, of zone 3 and of zone 4; the Lion's and
   the Gardener's rows) went in at the title. If one did not, it asks nothing and names it: return to the title with
   the co-op save files, wait until `coop-link.log` shows all seven in, then load the save and type `coop mxiii` again.
4. If the log says `travel: SB refused DLC02_00_Camp_00`, the game listed its camps when the map started, before the
   rows went in (they did not go in at the title). Load the save again (or travel to any camp), then type `coop mxiii`
   again: the rows stay until the game exits, so the second time it only travels.
5. `coop mxiii 30` adds the same rows and travels to `DLC02_30_Camp_01` instead, from the main game or from the first
   zone. Before v5 it refuses after the checks and asks nothing, as `coop mxiii` does.
   Step 4 applies to it as well, with `coop mxiii 30` typed again. The arrival saves the game, so from then on the
   save rests at that camp, and only v3 and later have the point the game puts EVE at there. Type `coop mxiii leave`
   (or replace the copy with `coop saves refresh <0-4>` at the title) before you put v2 or v1 in place of a later build.
6. To leave, type `coop mxiii leave`. EVE respawns at the camp of her last rest or fast-travel arrival, so the arrival
   in Matrix XIII makes its camp hers, and that camp is not one of the 120 travel camps. `coop mxiii` therefore keeps
   the camp where she respawned when it asked the travel in, and `coop mxiii leave` travels back to it if your save has
   activated it; a `coop mxiii` or `coop mxiii 30` typed inside the area keeps the camp it had. If not, or if the
   game or the mod's scripts restarted since, it travels to the camp where EVE respawns now when that is an activated
   travel camp, and otherwise to the first camp on the `activated=` line of `coop status` that is one of the 120 travel
   camps. `coop mxiii leave` refuses when the mod has no read of your activated camps yet (during a load, for example);
   try again a few seconds later.

## The camps

On the full map every full and simple camp stands inactive with its own coin on the floor beside its vending machine,
put there when EVE enters that camp's zone. A full camp has the tall vending machine, a skill machine, a chair, a
storage box, a turntable, a phone booth and the base with its parasol and fire, which light up on activation. A simple
camp has the small vending machine, a skill machine, a chair and a turntable, as in the base game. Pick the coin up and
use it at the machine to activate the camp. A camp
you activated in an earlier test stays active in that save and its coin stays taken, so check this on a co-op slot
that has not been in the area. A full camp activated before the base rows existed keeps an unlit base with no way to
light it: the shield belt and the off light, no parasol or fire (read from the row data, not seen in game).

The first zone's two camps, `DLC02_10_Camp_01` and `DLC02_10_Camp_02`, use objects placed in the `MXIII_Camps_A`
level of the v5 pak, the way the base game places its own camps: the game finds each object by the name in its row
and spawns nothing (read from the game's code, not seen in game yet). The other camps still spawn their objects at
spawn points. The other four full camps still have cooked copies of the base's meshes and a cooked vending machine
under the working one, so those objects appear twice, and a machine that failed to spawn would look present.

Lily's Talk prompt opens her menu there: the other region (the teleport screen), the
console and her goodbye, the bike signal once its conditions hold, and the mod's row at the end of On Time. Picking
"leave" under the bike signal ends the trip for Quest_Epic_11 and there is no row back, so a save with On Time
running should not take it.

Once activated, the first zone's full camp shows in the camp list with the picture of Matrix 11's first full camp,
`ME01_Camp_03`, whose row it copies. Its name, "Lift Head" ("Tête d'ascenseur"), comes from the `mxnames` batch. Without
that batch it keeps the Matrix 11 camp's name. The area's camps have a region of their own, so a full camp's list shows
only the area's full camps. The region teleport screen at a Tetrapod gives the area a tab of its own, "Matrix 13"
("Matrice 13"), right after Matrix 11's, under the region name the `mxnames` batch writes. That tab was seen in game on
2026-11-03 (build v0.7.5-110-g5e18200), with Matrix 11's picture. The camps' own names have no recorded run in game.

`coop mxiii 30` arrives at the third zone's first rest stop, `DLC02_30_Camp_01`, a simple camp with its own coin. The
arrival makes it the camp EVE respawns at, so a death in the third or fourth zone should bring her back there (read
from the game's code, not tried).

## Enemies of the later zones

Some enemies of the area's later zones start, in the shipped rows, from props of the cut map. In the second zone
(`Zone_DLC02_20`), three waves of Antlions (4, 3 and 4) come when three gates open. In the fourth zone
(`Zone_DLC02_40`), two chains of enemies (5 Antlions, then 3 Clrikets) wait for two zone triggers that stay switched
off until EVE uses the zone's two drain devices.

The full map's pak has three triggers of its own inside the second zone's arena doorways. Each starts one wave and
shuts the arena gate behind EVE. The fourth zone's two triggers in the main hall, `DLC02_40_ZTrigger_001` (the 5
Antlions, one after another) and `DLC02_40_ZTrigger_002` (the 3 Clrikets), start switched on: the `mxiii` batch
patches them in memory for the game run, like the camp's rows. They keep the game's save type, which saves nothing for
them (from the rows, not checked in game). These rows belong to zones that only this area has.

## Notes on the pak, the save and the rows

- The pak check reads `zMXIII_P.utoc` once per command and looks for `WorldMap_DLC_01`, `Level_P` and `MXIII_P.umap` in
  it, with `zMXIII_P.pak` and `zMXIII_P.ucas` beside it. It then reads `zMXIII_P.ucas` 16 MB at a time, up to its
  end as the `.utoc` gives it, until it has seen all three names: v2 names the objects' spawn points there
  (`DLC02_10_EnvS`), v1 does not, v3 also names the third zone's camp point (`DLC02_30_Camp_01`), and the full map (v4)
  the Tetrapod camp's (`DLC02_00_Camp_00`). v5 is a v4 pak whose `.utoc` also names `MXIII_Camps_A.umap`. A
  container compressed with Oodle hides those names and reads as v1. A pak under another name is
  not found. The check reads the folder as it is now: it cannot tell whether the game mounted the pak at start, and the
  game mounts paks only at start. Copy the files in with the game closed.
- The mod's camp reaches the save file as soon as you activate it, without a save and quit: the vending machine saves
  the game after the activation, and the phone booth saves before it opens the camp list. The save's activated camps
  then include `DLC02_10_Camp_01`, and its last camp is one of the mod's rows (`DLC02_10_EnvS_906` after the
  activation).
  - So that such a save never loads without them, the mod adds the rows at the title, before any save loads, whenever
    the pak is installed and the game uses the co-op saves; `coop mxiii` then finds them in and only travels. They are
    not added on your own saves, and not for a manual co-op slot (`StellarCoopSlot.txt`), whose file is one of your own
    saves: there the rows exist only once `coop mxiii` has run in the same game run, and what the game does with a save
    that names a camp or row it does not have has not been checked.
  - Resting at another camp afterwards does not clean the save: `DLC02_10_Camp_01` stays among the activated camps, and
    a rest at a simple camp leaves the last full camp on a mod row. To get a slot without them back (before you remove
    the pak, for example), type `coop saves refresh <0-4>` at the title, while the game uses your own saves, before you
    load the slot again. The same applies if the game crashes after the activation.
  - The game also saves on each camp travel arrival (read from its code), so after `coop mxiii 30` the save's camp is
    the mod's row `DLC02_30_EnvS_900` until a travel out.
- At the title the rows go in once per game run. The native part adds rows only on a frame with no game logic
  running and the game offline, and gives up after 300 frames. If it gave up, the mod asks again 10 s later, at most
  four times each time the title shows; after that `coop mxiii` adds them as above. They then stay for the game run,
  even if you switch back to your own saves: nothing in the main game leads to the area or its camps. The two camp
  trophies count only named camps of the main game, so these rows can neither unlock nor block them
  ([How it works](../dev/safety.md#achievements)).
- The rows go in through the same native calls as `coop lion` and the shop's cut items. A fault in those calls during
  `coop mxiii` or at the title stops them all until the game restarts: `coop lion`, `coop gardener fight`,
  `coop tendril fight`, and the shop's stimpacks, ChainSpin and Shock Bolt that are not in yet then answer that the
  rows stopped on a fault.
- The game has no world map for Matrix 11 or Matrix XIII, so the camp shows only in the camp list. The mod adds nothing
  else: no zone warp, no quest step, no item.
- What else you find there depends on the test pak. The area's first zone spawns its enemies as you enter it (14
  Antlions and a data drone in the game's spawn table). The second zone's waves and the fourth zone's chains come
  from the triggers above.
- `coop off` ends the wait for the rows. A travel the game already took goes on. At the title, the mod asks for the
  rows again after `coop on`.

## The full map

With the full map's pak (all four zones, cooked with the mechanisms), the title adds the rest of the area after the
camp rows: its other camps and their kits, Lily and the Tetrapod on the zone 0 plaza, the zones' enemies with the three
bosses, and the mechanisms, built the way Matrix 11 builds its own.

- Every door starts closed. Its panel on either side shows the game's open prompt; a one-way door's far side says it
  cannot be opened from there.
- Gates open from their switches, a lift goes to the landing whose call switch you use, and the zone 4 water drains
  through its panels.
- Arena doors shut when the fight starts and open once its last enemy dies; the Lion's fan door and D7 shut when it
  fights and open on its death. If EVE dies in an arena, its locks should reset with the zone and lock again at the next
  fight (not tested in game).
- The R02 shutter under the surface lift starts down and rises from the switch on the pillar between its two halves.
- The car 9 airlock and the zone 3 pressure door start open and close by their own mechanism (the pressure door for
  good, behind EVE).
- The map has no warp switch: for tests, `coop mxiii warp` lists in `UE4SS.log` the 72 points the old switches led to,
  and `coop mxiii warp <n|name>` puts EVE on one (solo, on a co-op save, in the area only).

Once in the area, the mod spawns the ladders, ledges and the two ropes itself (`[MXMOVE]` lines) and fixes the Lion
and the Gardener when the game spawns them (`[MXBOSS]` lines). The ladders, ledges, ropes, boxes and barrels are placed
under the game's own loading black when you arrive, which stays up a few seconds longer, so none of them appears in
play. `coop mxiii boss`, typed within 25 m of the Lion's or the
Gardener's spawn point, spawns that boss as `coop lion` or `coop gardener fight` would (no saved death), for when the
game spawned none there. The fan levers wait for the Lion's death: a save whose Lion died on a build older than these
levers needs a new run. A boss that never spawns locks nothing: its doors lock on its first fight.

This version uses link protocol 29: both players need a build with the same rows. A co-op save that played in the area
can no longer be exported to your own saves ([players/saves.md](../players/saves.md)).

## Status lines

| Line | What it answers |
| --- | --- |
| `[StellarCoop][MX] title: the co-op save files and test pak v<n>: the rows asked before any save loads (try <k> of 4)` | At the title, the rows asked of the native part |
| `[StellarCoop][MX] title: test pak v<n> has no MXIII_Camps_A.umap: the rows go in, but the two zone 10 camps will have no kit, and coop mxiii refuses this pak` | At the title with a pak before v5, once per start of the mod's scripts: the rows still go in, for a co-op save that names them |
| `[StellarCoop][MX] title: the rows are in, before any save loads` | They went in at the title and read back as written |
| `[StellarCoop][MX] title: the rows are in, after the title closed: a save may have loaded before them` | They went in and read back, but a save was loading by then; if the travel then gets `SB refused`, see step 4 of [Using `coop mxiii`](#using-coop-mxiii) |
| `[StellarCoop][MX] title: <why> (asked again in 10 s if the title still shows)` or `... (no more tries this visit of the title: coop mxiii adds them)` | The native part kept its gate shut, gave no answer yet, or a table was not loaded |
| `[StellarCoop][MX] title: the rows are in already (mxiii=rows ...)` | The rows were in before, from the title or a `coop mxiii` earlier in the game run |
| `[StellarCoop][MX] checks: solo on a co-op save, the native travel idle, <path> holds WorldMap_DLC_01/Level_P/MXIII_P.umap beside its .pak and .ucas; test pak v1 (...)` to `...; test pak v5 (...)` | The checks passed, the test pak holds the map, and which build it is, with where EVE arrives; before v5 the next line refuses it |
| `[StellarCoop][MX] refused: test pak v4 has no MXIII_Camps_A.umap` (or v1 to v3) | `coop mxiii` or `coop mxiii 30` with a pak before v5: nothing was asked |
| `[StellarCoop][MX] refused: no test pak: no <path> or <path>` | No test pak in either folder: nothing was asked |
| `[StellarCoop][MX] refused: no test pak: <path> does not hold <name>` or `no <path> beside <path>` | The `.utoc` names the map under another folder or not at all, or its `.pak` or `.ucas` is missing: nothing was asked |
| `[StellarCoop][MX] refused: <why>` | A condition of the travel failed (a session, another save, a travel under way or under 10 s ago, the native travel stopped by a fault): nothing was asked |
| `mxiii rows: 75/75 in, 39 added through SB's AddRow 0x1441815b0 and 36 shipped rows patched in place, 0 refused` (`coop-link.log`) | The native part added the camp rows and changed the shipped kit and trigger rows |
| `mxiii rows refused <row>: <why>; <n>/75 added` (`coop-link.log`) | A row the native part would not add or change, and why: no travel |
| `[StellarCoop][MX] rows read back through FindRow: 75/75 authored rows, <n> fields as written (<k> differ from the template row)` | Every field the native part wrote reads as written |
| `mxspawn rows: 51/51 in, ...`, `mxenv rows: 172/172 in, ...`, `mxupper rows: 168/168 in, ...`, `mxmiddle rows: 106/106 in, ...`, `mxlower rows: 105/105 in, ...`, `mxrecords rows: 100/100 in, ...` (`coop-link.log`) | The full map's other batches went in at the title, after the camp rows (`mxrecords`: the 25 records, optional) |
| `mxnames rows: 11/11 in, ...` (`coop-link.log`) | The camps' names went in, last of all and only after `camptext=ready` |
| `mxlily rows: 6/6 in, 0 added through SB's AddRow 0x1441815b0 and 6 shipped rows patched in place, 0 refused` (`coop-link.log`) | Lily's menu conditions were patched for this game run. `coop mxiii` does not wait for this batch; if it is refused or missing she has no menu in the area and travel still works |
| `[StellarCoop][MX] refused: mxspawn rows not in` (or `mxenv`, `mxupper`, `mxmiddle`, `mxlower`, `lion`, `gardener`) | `coop mxiii` found a batch that did not go in at the title (a save loaded before the chain ended, or the tries ran out): nothing was asked; return to the title with the co-op save files, wait until `coop-link.log` shows all seven batches in, then run it again |
| `camptext=wait` that never turns `ready`, or `camptext=fault` (`coop-status.txt`) | Matrix XIII's camps keep their donors' names and travel still works: `coop mxiii` does not wait for the `mxnames` batch. On a fault `coop-link.log` has a `camp names off` line, and the names stay off until the game restarts |
| `[StellarCoop][MX] mxspawn title: ...`, `mxenv title: ...`, `mxupper title: ...`, `mxmiddle title: ...`, `mxlower title: ...`, `lion title: ...`, `gardener title: ...`, `mxlily title: ...`, `mxnames title: ...` | Each of those batches at the title, with the same words as the camp rows' lines |
| `[StellarCoop][MX] [MXMOVE] ladder: <n>/41 spawned, <n> deferred spawn; <k> stacks filled again front to back` (then `ledge: <n>/5 ...` and `rope: <n>/2 ...`) | In the area, the ladders, ledges and ropes the mod spawned, by class, and how (`SpawnActor, construction script run again` when the deferred spawn failed). `filled again front to back` counts the ladders whose `Meshes` stack read back wrong after the first fill and right after the second |
| `[StellarCoop][MX] [MXMOVE] ladder <key> at <x> <y> <z> yaw <d> height <h> stack <pieces> built <h> (<role>), deferred spawn`, or `<kind> <key> not spawned: <why>` | A line of its own comes only for an entry that did not spawn, for one that ends in `SpawnActor, construction script not run`, or for a ladder whose `built` (the `TotalHeight` its construction script came to) is not its `height`. When `built` is larger, the ladder stands `built - height` cm too high. `stack` is the ladder's `Meshes` as the actor holds them before it finishes spawning (for example `3,3`); a `0` there, or `?`, means the stack did not go in and the ladder is short |
| `[StellarCoop][MX] [MXMOVE] spread over <n> ticks in <s> s, the longest <ms> ms, lookups <ms> ms in all` | The spawns ran over that many frames, one or more a frame; the slowest of those frames spent that many ms spawning. `lookups` is the part of all the spawns that went into finding their classes and the ledge mesh. `[MXBREAK]` has the same line for the boxes |
| `[StellarCoop][MX] [MXMOVE] <n>/48 ladders, ledges and ropes spawned in world 2800` | All of them, once a world |
| `[StellarCoop][MX] [MXMOVE] spread stopped after <k>/48 entries (<why>): <n> spawned` | The spread ended before its last entry, and the class lines for those spawns never come. `<why>` is `world 2800 left`, `new world` (another world address) or `first spawn gone` (the first actor it spawned is no longer valid, as after a reload at the same address). The list starts over in the next world 2800. `[MXBREAK]` has the same line for the boxes, with `loaded again` for a reload seen through the world's real time, and `<n> proxies hidden` at the end |
| `[StellarCoop][MX] warp <n> <point> (<mover>)` | `coop mxiii warp` alone: one line per point |
| `[StellarCoop][MX] warp <n> <point> (<mover>) to <x> <y> <z> yaw <d>` | `coop mxiii warp <n\|name>` moved EVE there (`: the game refused the teleport` when it did not) |
| `[StellarCoop][MX] [MXBOSS] Lion DLC02_40_E_CharS_051 found near its point: <what was done>` (or the Gardener) | The game spawned the boss from its row and the mod fixed it |
| `[StellarCoop][MX] [MXBOSS] no Lion body within 30 m of DLC02_40_E_CharS_051 after 20 s: coop mxiii boss spawns one (key 0, no saved death)` | No body at the arena: type `coop mxiii boss` there for the fallback fight |
| `[StellarCoop][MX] travel to DLC02_00_Camp_00 asked: ...` (or `DLC02_10_Camp_01`, `DLC02_30_Camp_01`) | The camp travel went to the native part |
| `[StellarCoop][TR] travel accepted: DLC02_00_Camp_00` (or `DLC02_10_Camp_01`, `DLC02_30_Camp_01`) | The game took the travel: the fade and the load follow |
| `[StellarCoop][TR] travel: SB refused DLC02_00_Camp_00` (or `DLC02_10_Camp_01`, `DLC02_30_Camp_01`) | The game did not find the camp (see step 4 of [Using `coop mxiii`](#using-coop-mxiii)) |

## What to check in game

Parts of it ran in game with older test paks. On 2026-10-27 (build v0.6.0-beta.3-250-g51dbdf1, test pak v2) the
game refused the first travel, since the rows went in after the world started. After a reload the second
`coop mxiii` travelled and the map loaded. On 2026-10-28 (build v0.6.0-beta.3-258-g9bb5cd5, test pak v3) the rows
went in at the title, `coop mxiii leave` travelled out and a travel from the camp list worked. On 2026-11-18 (build
v0.11.0-277-gd9bb23bf, v5 pak) a run of [Lily's signal](lily-signal.md) asked `coop mxiii`'s travel from the first
world after the title. The travel to `DLC02_00_Camp_00`, the Tetrapod camp beside Lily, arrived.

The checks below are for the v5 pak. Start the game with it installed and the co-op saves on, then check:

1. At the title, before you load a save: `UE4SS.log` shows
   `[StellarCoop][MX] title: the rows are in, before any save loads` and `coop-link.log` shows `mxiii rows: 75/75 in`.
   If it shows `mxiii rows refused -: net mode 4` or `no logic or net-mode global`, note which, then load and use
   `coop mxiii` as before.
2. With the rows in at the title, the first `coop mxiii` travels at once.
3. The travel loads the map and EVE stands on its floor at the camp's arrival point. Note which enemies appear.
4. The fourth zone's main hall brings its 5 Antlions and 3 Clrikets.
5. `coop mxiii 30` puts EVE at the third zone's first rest stop (`coop where`: `map=` ending in `mxiii_p`). A death in
   the third zone brings her back to that camp. `coop mxiii leave` from there goes back out.
6. The game keeps running and saves normally after you leave. Then replace the slot with `coop saves refresh <0-4>` at
   the title.

### With the full map's pak

With the full map's pak, check at the title that `coop-link.log` shows the six Matrix XIII batches and the lion and
gardener batches in, each `rows=N/N` on its status line, and that no `[MX]` line says a table is missing. The `mxlily`
batch comes after them, and so does `mxnames`, which is asked only once `coop-status.txt` reads `camptext=ready`: check
for `mxnames rows: 11/11 in` in `coop-link.log`. `mxnames=off` with `camptext=wait` is no failure, only a batch not
asked yet. Check `mxlily rows: 6/6 in` too.

Then, on a co-op slot that has not been in the area, in one session:

1. `coop mxiii` arrives beside Lily at the Tetrapod and no camp of the area is active.
2. Talk opens her menu, its console and goodbye work, the other region opens the teleport screen with the Matrix 13 tab
   and comes back.
3. Each camp in zones 1 to 4 has a coin on the floor and activates with it.
4. A Great Desert Lily still shows her own menu after the patch.
5. The surface lift rides down from its cab panel and comes back to the call switch you use.
6. The R02 shutter is down and rises from the switch on the pillar.
7. Every door you meet is closed and opens from its panel, and a one-way door refuses from its far side.
8. Zone 1's enemies appear in R08, R20, R23 and R26, the new rows included (`DLC02_10_E_CharS_901` in R20).
9. The `[MXMOVE]` lines show `ladder: 41/41 spawned` and `48/48 ladders, ledges and ropes`, and no line names a single
   ladder.
10. The R10 ladder climbs.
11. The R28 rope drops when its winch turns and ladder gate 435's lever makes its ladder usable (the two rows the mod's
    late spawns bind by `EnvActorName`).
12. A rest at the R04 camp brings a killed Creeper back.
13. The R29 gate opens from its switch.
14. Zone 2's waves come at the arena doorways, the arena gate shuts behind you and opens after the last kill, and after
    a death in the arena the waves and the lock come back at the doorway.
15. The Gardener comes at the gantry step.
16. The car 9 airlock shuts its outer door before the inner one opens.
17. The Stalker in Z3R19 dies at 0 HP and the hall doors open then.
18. The pressure door shuts behind you.
19. The zone 4 trio appears only after trigger 004.
20. The water drops from its panels.
21. The Lion spawns with the `[MXBOSS]` fix line and its name on the boss bar, the fan door and D7 shut during the fight
    and open on its death.
22. `coop mxiii warp 1` puts EVE at the surface lift.
23. `coop saves export` refuses the save afterwards.
