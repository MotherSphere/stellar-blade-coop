# Night Operation

Night Operation is a multiplayer mode that Stellar Blade's developers started and then cut. This page explains what
StellarCoop found in the game files, what we plan to do with it, and the two research previews you can try today. The
previews are tests of the cut mode's pieces, not a playable mode.

## A mode cut before release

Night Operation is a **multiplayer wave-survival mode** that Shift Up prototyped and cut before the game's release. It
never shipped, but much of it is still in the game files, where this project found it:

- **A recruiter.** The Xion recruiter was meant to stand next to Roxanne in Xion's Scrap Market, at a spawn point
  named `TeleportPoint_Xion_MultiPlay`. His dialogue, left in Korean in the game files, asks whether you want to join
  the night operation, with a Join and a Cancel choice. Several of his lines are still marked as temporary text.
- **A rule system.** The game has a rule manager and a rule table, `MultiPlayRuleTable`, which ships empty. Its rows
  have fields for a duration, a number of lives, a respawn time and timed zone events: the shape of a timed survival
  round.
- **Multiplayer test rows** in the game's zone event, condition and spawn tables, which the game's own event system
  runs.
- **An online side.** The recruiter's Join choice starts the mode's matchmaking: a request to Shift Up's own online
  services, a matchmaking service and dedicated game servers hosted on Amazon.

StellarCoop never contacts those servers. They belong to Shift Up and served a mode that never shipped. See
[Why the original matchmaking can never run](#why-the-original-matchmaking-can-never-run).

## Our plan

The goal is to bring Night Operation back as a mode you play with your friends, over Steam, without Shift Up's servers:

- The recruiter stands next to Roxanne in Xion's Scrap Market, and his Join choice starts **StellarCoop's own Steam
  friends matchmaking**.
- Every player gets **identical waves**, and **kills stay in sync** between the games.
- A **shared timer and score**.
- **Two players first**, then up to six.
- It runs on a **dedicated co-op save slot**, a copy of your save, so your own slots are never involved.
- The recruiter speaks your language: his lines are translated into the game's 23 languages.

Today the Steam link connects two players and shows each other's ghost (see [usage.md](usage.md)), but nothing of the
world is shared yet: no enemies, no kills, no score. The work so far maps how the cut mode's pieces behave.

## The two previews

| Preview | Command | What it shows |
| --- | --- | --- |
| The probe | `coop no` | Whether the cut mode's machinery still answers in a solo game: a heal event, a rule, a wave spawn, one monster |
| The recruiter | `coop recruiter` | The cut recruiter near Roxanne, whom you can talk to, in your game language |

Both are research tools. Both run only on the co-op save slot. Neither writes a game file, but their changes stay in
the running game until it ends. Read the next section before you try either.

## Before you try a preview

1. **Make the co-op save slot.** Both previews refuse to run on any other save. Make it once, with the game closed:
   follow [INSTALL.md: Co-op save slot](../INSTALL.md#co-op-save-slot). `coop status` must then show `slot=coop`.
2. **Back up your saves**, with the game closed: `python3 tools/save_guard.py backup` on Linux, or a copy of the save
   folder on Windows. See [saves.md](saves.md#backups).
3. **Keep Steam Cloud off** for Stellar Blade during preview runs, so nothing from the run replaces the good copy in
   the cloud. See [saves.md](saves.md#steam-cloud).
4. **End the run by killing the game**, not by Quit from the menu, which saves. On Linux:
   `pkill -9 -f SB-Win64-Shipping`. On Windows: Task Manager, End task. Never load another save in that run: the
   preview's changes stay in the game until it ends.
5. **Afterwards**, with the game closed, check and restore your backup (see [After a preview run](#after-a-preview-run)).

Without the co-op slot loaded, each preview stops with a `STOP:` line naming the command and the current slot line,
for example:

```
STOP: coop recruiter runs only with the co-op save slot loaded (INSTALL.md: Co-op save slot); now slot=main index=0 marker=4
```

## Preview 1: the probe (`coop no`)

The probe asks, on your own PC, whether the cut mode's pieces still respond. It is run by hand only, one command at a
time, and every step is logged in `UE4SS.log` as `[StellarCoop][NO]` lines.

What the probe never does: it fires only the zone events and the one monster listed below (no achievement, no drop),
kills nothing, and calls no save, inventory, equip or quest function. No console argument reaches a game call.

1. **`coop no`** starts the native part's read-only poller and logs a baseline. Every 100 ms the poller reads the
   game's rule manager and a few of its neighbours into `nightop-probe.txt`: a line on each change, otherwise once a
   second. `coop status` shows `nightop=on`. Each subcommand below refuses until the poller runs.
2. **`coop no heal`** fires the game's heal zone event `SE_10_E_ActorEff_011`. EVE's health bar should refill.
3. **`coop no rule`** adds a probe row to the game's empty `MultiPlayRuleTable` (no achievement, quest or reward), reads
   it back field by field and sets it as the rule, once per game run (`nightop=rule`). 60 s later the native part
   writes its verdict to `nightop-probe.txt` and `coop-link.log`, and so to `UE4SS.log` as a `link:` line.
4. **`coop no spawnpt`** fires one spawn row of the `DLC02_20` area on a loaded spawn point 60 m or more from EVE, and
   logs the new characters 3 s later, with a `G8=yes` or `G8=no` verdict.
5. **`coop no actor`** asks the game for one `M_Antlion` 60 m ahead of EVE and logs it 3 s and 10 s later, with a
   `G7=yes` or `G7=no` verdict.

Safety while it runs:

- At the `spawnpt` check (+3 s) and the `actor` checks (+3 s and +10 s), a new character within 20 m of EVE logs a
  `STOP` line: kill the game. Nothing watches at other times: if a monster comes towards EVE, kill the game.
- A probe rule only ends with the game. `coop off` stops the poller but does not end the rule, so the test always ends
  by killing the game.

Send `nightop-probe.txt` with the other logs if you ran the probe (see
[troubleshooting.md](troubleshooting.md#which-logs-to-send)).

## Preview 2: the recruiter (`coop recruiter`)

`coop recruiter` brings back the cut recruiter: a Xion guard (the `N_XionGuardA` model) carrying the recruiter's
dialogue, so you can talk to him. Every step is logged in `UE4SS.log` as `[StellarCoop][RC]` lines.

### Where to stand

It runs only in Xion (`/game/art/bg/worldmap/level_p/e04`), with EVE in the world within 50 m of
`TeleportPoint_Xion_MultiPlay`, the recruiter's cut spawn point near Roxanne in the Scrap Market. Otherwise it stops
with `STOP:` and changes nothing. He is never spawned automatically.

### What it does, in order

1. **It disarms Join first.** In the game data, the dialogue's Join choice starts the cut mode's matchmaking. Before
   anything else, the command sets that zone event (`MultiplayTest_ZoneE_059`) to a harmless type and reads it back.
   If the row is not the one expected, or the write does not read back, it stops with `STOP:` and nothing is spawned.
   In this preview, Join does nothing.
2. **It registers his text.** Once the Join event reads back, the command registers the dialogue's 12 text keys, and
   no other text, with the game's localization, in memory only (no game file is changed). His lines (speaker title,
   question, Join and Cancel, the replies) then show in your game language, any of the 23 the game ships. A `text:`
   line ending `TEXT=yes` says they took.
3. **It prepares his spawn.** If someone already stands at the point, it says so and spawns nothing. Otherwise, in
   memory only, it flips the recruiter's network condition (so the question and its two choices show), points one
   unused test spawn row at the cut spawn point (a Xion guard with the recruiter's dialogue, not marked for saving, no
   walking path), and points one unused test filter at that row, for the despawn. Rows are edited in place, field by
   field, and read back; no row is added or removed.
4. **The game spawns him.** The game's own Spawn event places him. 3 s later a line says whether he stands at the point
   (`RECRUITER=yes: talk to him`).

The game spawns a row once per game run, so after `coop recruiter off` another `coop recruiter` may need a game
restart.

### His language

The language is the game's own setting, changed in the main menu only. If the text step fails, a `STOP: text:` line
says how far it got, and the command goes on:

- after `nothing registered`, his text stays Korean;
- otherwise the keys it registered may show another language, or a mix with Korean (a registration is never undone).

### Sending him away

`coop recruiter off` despawns him through the game's own Despawn event and says 2 s later whether he is gone.
`coop off` despawns him too. A map change removes him, and he does not come back by himself.

### What stays changed

Everything the command changes stays in the running game until it ends: the Join event, the network condition, the
test spawn row, the test filter and the registered text. None of it is undone or saved by the mod. It is not yet known
whether the game saves the guard, which is why the run ends by killing the game and restoring your backup.

## After a preview run

With the game killed and closed:

- **Linux**, from the repository: `python3 tools/save_guard.py check`, then
  `python3 tools/save_guard.py restore <backup> --yes`, where `<backup>` is the folder name that `backup` printed.
- **Windows**: see in File Explorer which files have a newer modified time, then copy the backup back over the save
  folder.

Only these may differ: the co-op slot and its `Backup/StellarBladeSave0N_Old.sav` copy, the game's own
`StellarBladeSetting.sav` and its `Backup/` copy, the `steam_autocloud.vdf` files and other mods' saves. Any other
`StellarBladeSave0N.sav`, or its `Backup/` copy, means the run wrote one of your own slots: the restore puts it back,
and please send the logs. The full recovery steps are in [INSTALL.md: Recovery](../INSTALL.md#recovery).

## Why the original matchmaking can never run

The cut mode's Join choice would ask Shift Up's servers for a match. StellarCoop makes sure that request never leaves
your game:

- **Join is disarmed before anything else.** `coop recruiter` turns the Join zone event into a harmless one and reads
  it back before it writes anything else. It checks that the shipped zone event table is the only one in memory, so no
  other copy of the row can run. At the first doubt it stops, and no recruiter exists to talk to.
- **Only listed events can fire.** Each preview fires zone events through one guarded function that accepts only its
  own short list (the heal event and eleven safe spawn rows for the probe; the guard's spawn row and despawn filter
  for the recruiter). No console argument reaches it.
- **A test checks the source.** `tests/matchmaking_scan_test.py` scans every script and native source of the mod and
  fails if any of them could reach the matchmaking path. The Join row may appear only as the recruiter's constant,
  which it neutralizes and never fires, and the calls that fire zone events, add table rows or make game requests are
  counted and rationed. The test first runs on planted violations, so no rule passes vacuously.
- **No connection to Shift Up.** The mod contains no code that talks to Shift Up's services. Its only network use is
  the Steam link between friends, through the Steam client the game already runs (see
  [how-it-works.md](how-it-works.md#the-steam-link)).

Bringing Night Operation back therefore means replacing its online side: Join will start StellarCoop's own Steam
friends matchmaking instead.
