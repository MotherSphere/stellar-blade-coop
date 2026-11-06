# Night Operation previews

- The probe, `coop no`, checks whether a heal event, a rule, a wave spawn and one monster from the cut mode still work
  in a solo game.
- The recruiter, `coop recruiter`, brings back the cut recruiter near Roxanne. You can talk to him in your game
  language.

Both are research tools and run only on a co-op save. Neither writes a game file, but their changes stay in the
running game until it ends.

## Before you try a preview

1. Load a co-op save: at the title, choose Play co-op (see [INSTALL.md: Co-op saves](../INSTALL.md#co-op-saves)), then
   load your save. `coop status` must then show `slot=coop`. Both previews refuse to run on any other save.
2. Back up your saves, with the game closed: `python3 tools/save_guard.py backup` on Linux, or a copy of the save
   folder on Windows. See [saves.md](saves.md#backups).
3. Keep Steam Cloud off for Stellar Blade during preview runs, so nothing from the run replaces the good copy in the
   cloud. See [saves.md](saves.md#steam-cloud).
4. End the run by killing the game, not with Quit from the menu, which saves. On Linux:
   `pkill -9 -f SB-Win64-Shipping`. On Windows: Task Manager, End task. Never load another save in that run.
5. Afterwards, with the game closed, check and restore your backup (see
   [After a preview run](#after-a-preview-run)).

Without a co-op save loaded, each preview stops with a `STOP:` line that names the command and the current slot line,
for example:

```
STOP: coop recruiter runs only on a co-op save (INSTALL.md: Co-op saves); now slot=main index=0 marker=none saves=main
```

## Preview 1: the probe (`coop no`)

The probe checks, on your own PC, whether the cut mode's parts still respond. You run it by hand, one command at a
time. Each step is logged in `UE4SS.log` as `[StellarCoop][NO]` lines.

The probe fires only the zone events and the one monster listed below (no achievement, no drop). It kills nothing and
calls no save, inventory, equip or quest function. No console argument reaches a game call.

1. `coop no` starts the native part's read-only poller and logs a baseline. Every 100 ms the poller reads the game's
   rule manager and a few of its neighbours, and writes a line to `nightop-probe.txt` on each change, otherwise once a
   second. `coop status` shows `nightop=on`. Each subcommand below refuses to run until the poller runs.
2. `coop no heal` fires the game's heal zone event `SE_10_E_ActorEff_011`. EVE's health bar should refill.
3. `coop no rule` adds a probe row to the game's empty `MultiPlayRuleTable` (no achievement, quest or reward), reads it
   back field by field and sets it as the rule, once per game run (`nightop=rule`). 60 s later the native part writes
   its verdict to `nightop-probe.txt` and `coop-link.log`, and so to `UE4SS.log` as a `link:` line.
4. `coop no spawnpt` fires one spawn row of the `DLC02_20` area on a loaded spawn point 60 m or more from EVE. 3 s later
   it logs the new characters, with a `G8=yes` or `G8=no` verdict.
5. `coop no actor` asks the game for one `M_Antlion` 60 m ahead of EVE and logs it 3 s and 10 s later, with a `G7=yes`
   or `G7=no` verdict.

While the probe runs:

- At the `spawnpt` check (+3 s) and the `actor` checks (+3 s and +10 s), a new character within 20 m of EVE logs a
  `STOP` line: kill the game. No check runs at other times, so if a monster comes towards EVE, kill the game.
- A probe rule ends only when the game ends. `coop off` stops the poller but not the rule, so the test always ends by
  killing the game.

If you ran the probe, send `nightop-probe.txt` with the other logs (see
[troubleshooting.md](troubleshooting.md#which-logs-to-send)).

## Preview 2: the recruiter (`coop recruiter`)

`coop recruiter` brings back the cut recruiter: a Xion guard (the `N_XionGuardA` model) with the recruiter's dialogue,
so you can talk to him. Each step is logged in `UE4SS.log` as `[StellarCoop][RC]` lines.

### Where to stand

The command runs only in Xion (`/game/art/bg/worldmap/level_p/e04`), with EVE in the world within 50 m of
`TeleportPoint_Xion_MultiPlay`, the recruiter's cut spawn point near Roxanne in the Scrap Market. Anywhere else it stops
with `STOP:` and changes nothing. He is never spawned automatically.

### What it does, in order

1. The command disarms Join first. In the game data, the dialogue's Join choice starts the cut mode's matchmaking. The
   command sets that zone event (`MultiplayTest_ZoneE_059`) to a harmless type and reads it back. If the row is not the
   one expected, or the write does not read back, it stops with `STOP:` and spawns nothing. In this preview, Join does
   nothing.
2. Once the Join event reads back, a `STOP: text:` line ending `TEXT=no` says that his text stays in Korean (see
   [His language](#his-language)), and the command goes on.
3. If someone already stands at the spawn point, the command says so and spawns nothing. Otherwise, in memory only, it
   flips the recruiter's network condition (so the question and its two choices show), points one unused test spawn
   row at the cut spawn point (a Xion guard with the recruiter's dialogue, not marked for saving, no walking path), and
   points one unused test filter at that row, for the despawn. It edits each row in place, field by field, and reads
   it back. It adds and removes no rows.
4. The game's Spawn event places him. 3 s later a line says whether he stands at the point
   (`RECRUITER=yes: talk to him`).

The game spawns a row only once per game run, so after `coop recruiter off` another `coop recruiter` may need a game
restart.

### His language

His lines (speaker title, question, Join and Cancel, the replies) stay in Korean, as the game files have them. The mod
has them in the game's 23 languages (`nightop/recruiter_text.lua`), but showing them needs the game's text
registration, KismetTextLibrary `PolyglotDataToText`, which takes the languages as a map inside a struct parameter.
The UE4SS build the mod uses cannot pass a Lua table there. In game on 2026-10-28 the same call for Roxanne's choices
raised `StrProperty can only be set to a string or FString`, and depending on Lua's table order it can read another
field as a string, which may crash the game. So the command makes no text call and logs:

```
[StellarCoop][RC] STOP: text: this UE4SS build cannot pass a Lua table as a map inside a struct parameter (PolyglotDataToText LocalizedStrings): nothing registered, his text stays Korean: TEXT=no
```

### Sending him away

`coop recruiter off` despawns him through the game's Despawn event and reports 2 s later whether he is gone. `coop off`
despawns him too. A map change removes him.

### What stays changed

Everything the command changes stays in the running game until it ends: the Join event, the network condition, the test
spawn row and the test filter. The mod neither undoes nor saves any of it. Whether the game saves the spawned recruiter
is not known yet, so the run ends by killing the game and restoring your backup.

## After a preview run

With the game killed and closed:

- On Linux, from the repository: `python3 tools/save_guard.py check`, then
  `python3 tools/save_guard.py restore <backup> --yes`, where `<backup>` is the folder name that `backup` printed.
- On Windows: in File Explorer, find the files with a newer modified time, then copy the backup back over the save
  folder.

Only these files may differ: the co-op save you played (`StellarBladeCoop0N.sav`, or the manual co-op slot) and its
`Backup/` copy, the game's `StellarBladeSetting.sav` and its `Backup/` copy, the `steam_autocloud.vdf` files and other
mods' saves. Any other `StellarBladeSave0N.sav`, or its `Backup/` copy, means the run wrote one of your own slots. The
restore puts it back; please send the logs in that case. The full recovery steps are in
[INSTALL.md: Recovery](../INSTALL.md#recovery).

## How the original matchmaking is blocked

The cut mode's Join choice would ask Shift Up's servers for a match. StellarCoop keeps that request from leaving your
game in these ways:

- `coop recruiter` disarms the Join zone event and reads it back before it writes anything else (step 1 above). It also
  checks that the shipped zone event table is the only one in memory, so no other copy of the row can run. If any check
  fails, it stops, and no recruiter is spawned.
- Each preview fires zone events through one guarded function that accepts only its own short list: the heal event and
  eleven safe spawn rows for the probe, and the recruiter's spawn row and despawn filter for `coop recruiter`. A run,
  solo or co-op, fires only the heal, through the probe's function. No console argument reaches that function.
- `tests/tools/matchmaking_scan_test.py` scans every script and native source of the mod and fails if any of them could
  reach the matchmaking path. The Join row may appear only as the recruiter's constant, which the recruiter neutralizes
  and never fires. The test also sets how many calls each file may make that fire zone events, add table rows or make
  game requests: the run has one spawn request and the shop one item request. The only console call it allows is
  main.lua's photo pause, which sets `SB.PhotoMode.PauseMethod` to 0 or 1. It first runs on planted violations, so no
  rule passes vacuously.
- The mod has no code that talks to Shift Up's services. Its only network use is the Steam link between friends,
  through the Steam client the game already runs (see [internals/steam-link.md](internals/steam-link.md)).
