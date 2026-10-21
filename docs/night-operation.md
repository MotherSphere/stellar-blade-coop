# Night Operation

Night Operation is a multiplayer wave-survival mode that Shift Up prototyped and cut before Stellar Blade's release.
Much of it is still in the game files. StellarCoop has a solo run of its waves, `coop nightop`, four solo challenges on
the same code, `coop challenge`, and two research previews that test parts of the cut mode. The previews are not
playable modes, and neither the solo run nor the challenges have been tested in game yet.

## What the game files contain

- The Xion recruiter. He was meant to stand next to Roxanne in Xion's Scrap Market, at a spawn point named
  `TeleportPoint_Xion_MultiPlay`. His dialogue, left in Korean in the game files, asks whether you want to join the
  night operation, with a Join and a Cancel choice. Several of his lines are still marked as temporary text.
- A rule manager and a rule table, `MultiPlayRuleTable`, which ships empty. Its rows have fields for a duration, a
  number of lives, a respawn time and timed zone events. These fields describe a timed survival round.
- Multiplayer test rows in the game's zone event, condition and spawn tables. The game's event system runs them.
- The online part. The recruiter's Join choice starts the mode's matchmaking: a request to Shift Up's online services,
  a matchmaking service and dedicated game servers hosted on Amazon.

StellarCoop never contacts those servers. They belong to Shift Up and served a mode that never shipped. See
[How the original matchmaking is blocked](#how-the-original-matchmaking-is-blocked).

## The plan

The plan is to bring Night Operation back as a mode you play with friends over Steam, without Shift Up's servers:

- The recruiter stands next to Roxanne in Xion's Scrap Market. His Join choice starts StellarCoop's Steam friends
  matchmaking.
- Every player gets the same waves, and kills are synced between the games.
- The players share a timer and a score.
- Two players first, then up to six.
- The mode runs on a co-op save, a copy of your save, and never on your own saves.
- The recruiter's lines are translated into the game's 23 languages.

The Steam link connects two players and shows each player the other's ghost (see [usage.md](usage.md)). The solo run
below has the waves, a timer and a score on one PC, with no Steam session. Waves for two players, kills in sync and a
shared timer and score do not exist yet. The previews test how the cut mode's parts behave.

## The solo run (`coop nightop`)

`coop nightop start` sends five timed waves of the game's monsters at EVE where she stands, with an 8-minute timer and
a score. It runs on a co-op save with no Steam session, and it has not been tested in game yet. Each step is logged in
`UE4SS.log` as `[StellarCoop][NR]` lines.

The run keeps its own timer in the mod. It adds no row to the game's rule table and starts none of the cut mode's
rules, so a death goes through the game's usual death screen and respawn. Parts of the run adapt code from Survival
Protocol, with its author's permission (see [Credits](../README.md#credits)).

| Command | What it does |
| --- | --- |
| `coop nightop start` | Start a run where EVE stands |
| `coop nightop start noaggro` | The same, but the monsters are not sent at EVE (a test switch) |
| `coop nightop start nomove` | The same, but stuck or fallen monsters are not moved (a test switch) |
| `coop nightop stop` | End the run that is on, Night Operation or a challenge, on any save. `coop off` ends it too |
| `coop nightop` | The run's wave, run time, score and kills while a run is on, then the census: how many living characters stand within 40 m of EVE, and the wave monsters still in the world, this run's included, each with its run number (8 at most are named) |

### Before your first run

1. Load a co-op save, as in step 1 of [Before you try a preview](#before-you-try-a-preview). Leave any Steam session
   (`coop leave`): the run is solo.
2. Back up your saves and keep Steam Cloud off for Stellar Blade (steps 2 and 3 there). Whether the game saves a wave
   monster that is still alive when it saves is not known yet.
3. If you used `coop no rule` in this game run, restart the game: a run does not start while the probe's rule is set.

A run edits no game table, so you can quit from the menu afterwards as usual. The co-op save keeps the session's
progress like any co-op save, and your own saves are not touched.

### Starting a run

Go to open ground outside Xion, with no enemy or other character within 40 m of EVE, and type `coop nightop start`.
The answer is `OK: Night Operation starts in 5 s (run 0x2A)`, where `0x2A` is the run's number. The command refuses
with one `STOP:` line, and changes nothing, when:

- the save is not a co-op save;
- a Steam session is linked, or the Steam link is not ready yet;
- a run is already on;
- the `coop no` probe's rule is set in this game run;
- EVE is not in the world;
- EVE is in Xion, whose people and quests stay out of a fight;
- a living character other than EVE stands within 40 m. The line gives the count and the nearest distance, for
  example `STOP: census: 1 living within 40 m (nearest 23.4 m); 0 wave bodies: go where no one is within 40 m`.

### The waves

A 5 s countdown comes first. Run time starts at 0 when it ends, and wave 1 comes at once. Each later wave comes at its
run time below, or 10 s after the wave before it is down if that is sooner. A wave also waits while the monsters still
up plus its own would be more than 8. Run time is game time, so it stops while the game is paused.

| Wave | Run time | Monsters |
| --- | --- | --- |
| 1 | 0:00 | 4 `M_Antlion` |
| 2 | 1:15 | 2 `M_SkullSwordAlone`, 1 `M_SkullGunnerAlone` |
| 3 | 2:30 | 3 `M_HedgeBoarA`, 2 `M_LurkerA` |
| 4 | 4:00 | 2 `M_SkullSpearAlone`, 2 `M_SkullGunnerAlone` |
| 5 | 5:30 | 1 `M_SkullHammerAlone`, 2 `M_SkullSwordAlone`, 1 `M_SkullGunnerAlone` |

The monsters come from seven of the game's base monster rows (character IDs 50110, 50173, 50183, 50193, 50440, 50450
and 50161). These rows drop nothing and have no kill achievement of their own. The Skull rows are the `Alone`
variants, which summon no Skullings. Each wave appears at four points 14 m from where EVE started: two ahead of her,
40 degrees to each side of the way she faced, and two behind, 140 degrees to each side. A number drawn at the start
picks the order of the points for each wave. A fifth monster stands 2.5 m from its point. Each monster faces the start
point.

The mod then sends each new monster at EVE. 0.6 s after the monster is found, the mod reports a 0.01 damage event and
a noise from EVE, puts the monster in battle state, and gives it EVE as focus and a move towards her; if it is still
not fighting 4 s later, the mod does this again. A monster with no AI controller gets its default one first.

From 2.5 s after it is found, and then every 3 s, a monster more than 10 m below both the start point and EVE, or more
than 40 m from both, is moved to 7 m from EVE. This happens at most twice per monster. A monster still out after that
no longer holds up its wave, and killing it later still scores. A monster not found 2.5 s after its wave's last spawn
is logged as `missing`, and its wave does not wait for it.

Once wave 2 is down, and again once wave 4 is down, the mod fires the game's full heal (the probe's heal event,
`SE_10_E_ActorEff_011`).

### Score and the end of a run

Each kill scores by the monster's rank: 10 for `M_Antlion`, 20 for `M_SkullGunnerAlone` and `M_LurkerA`, 40 for
`M_SkullSwordAlone`, `M_SkullSpearAlone` and `M_HedgeBoarA`, and 60 for `M_SkullHammerAlone`. A monster counts as down
for its wave once it is dying or can be executed, and it scores once it dies.

A run ends in one of four ways:

- Success: every monster of the five waves is down, written off, missing or no longer tracked. The score gets 1 point
  for each whole second left.
- Time up: run time reaches 8:00.
- Failed: EVE dies. The game's death screen and respawn run as usual.
- Aborted: `coop nightop stop` or `coop off`; fast travel, a map change or a load; EVE more than 80 m from the start
  point for 10 s; a save that is no longer a co-op save; a Steam session that starts; or an error in the run, which
  `UE4SS.log` names.

The log then has one line such as:

```
result: success waves=5/5 kills=20 score=731 time=5:28 find_ms=0.9/2.4 challenge=night best=731/328 new
```

`find_ms` is the mean and the longest time the mod took to list the game's characters, which it does once a second
while monsters are tracked. A success that beats the best run kept in `coop-records.txt` is written there, and `best=`
gives the best after the run (see [Best runs](#best-runs-coop-recordstxt)).

Monsters still alive when a run ends, written-off ones after a success included, stay in the world as ordinary enemies,
and they no longer score. The mod has no safe way to remove them. Ctrl+R during a run ends it with no result, and its
monsters stay too. The next run takes a run number that no monster in the world carries, so they never count for it.

Resting at a camp during a run is not supported: the rest resets the area's enemies, and the run loses track of its
monsters.

### What you see

A card at the top centre of the screen shows `NIGHT OPERATION` over the countdown (`STARTS IN 5`), then the wave, the
run time left and the score (`WAVE 2/5  6:12  SCORE 100`). After a wave is down, the line counts down to the next one
instead (`NEXT WAVE IN 9  6:12  SCORE 140`). The card hides while the game is paused or shows one of its own screens.

When the run ends, a result panel takes the card's place for 10 s. Its heading is the game's own text for the mode,
Operation Successful or Operation Failed in the game's language. The line under it says why a run did not succeed, or
reads `New personal best.` after a success that set one. The rows give the waves cleared, the kills, the score, the time
and the best run kept on this PC (`-` when none is). The card and the panel follow the game's language, or English with
`ui_language=english` (see [usage.md](usage.md#options)).

With `coop ui off`, the same facts come as notices: the start, each wave, each wave cleared, and the result.

### What a run touches

A run spawns its monsters with the same game request as the probe's `coop no actor`. Each monster carries a wave key
from `0xD8000000` to `0xD8FFFFFF`, a range that none of the game's spawn rows uses. The heal is the only zone event a
run fires. A run adds or edits no table row, starts no rule, writes no save, and never hides or removes a monster. No
word typed after `start` reaches a game call: `noaggro` and `nomove` only turn off the mod's own steps.

Each kill most likely counts toward the game's general kill achievements, as any kill does: the ones for 10 and 1500
kills and the ones for kills with each kind of skill. A run can unlock one of them if your save is close to its count.
Restoring a backup does not take an unlocked achievement back.

## Challenges (`coop challenge`)

A challenge is a short solo fight picked from a fixed list. Three of them send waves of the game's monsters at EVE, as
the solo run does, and Target Practice stands the game's target dummies in front of her. Each run ends on the result
panel with the time, the score and the best run kept on this PC. The challenges run on the solo run's code, on a co-op
save with no Steam session, and log `[StellarCoop][NR]` lines. They have not been tested in game yet.

| Command | What it does |
| --- | --- |
| `coop challenge` | List the challenges and Night Operation with each one's best run, then the run that is on, if any |
| `coop challenge <name>` | Start that challenge where EVE stands. Its number in the list works too: `coop challenge 4` is `coop challenge targets` |
| `coop challenge stop` | End the run that is on, a challenge or Night Operation, on any save. `coop nightop stop` and `coop off` end a challenge too |

With no best kept yet, the list reads:

```
1 swarm Antlion Swarm: 3 waves, 3:00, no best yet
2 skulls Skull Squad: 3 waves, 6:00, no best yet
3 gauntlet Gauntlet: 8 waves, 12:00, no best yet
4 targets Target Practice: 3 waves, 1:30, no best yet
night: Night Operation (coop nightop start), no best yet
```

A start runs the checks of `coop nightop start` and refuses for the same reasons, with one `STOP:` line (see
[Starting a run](#starting-a-run)). The Steam session line names the challenge:
`STOP: Target Practice is solo for now: leave the Steam session first (coop leave)`. One run exists at a time, so a
start while a challenge or Night Operation is on gets `STOP: a run is on: coop challenge stop ends it`. A word that is
neither a challenge's name nor its number gets `STOP: unknown challenge: coop challenge lists them`. On a save that is
not a co-op save, every form except `coop challenge stop` gets the co-op save line (see
[usage.md](usage.md#night-operation-previews)).

A start answers `OK: Target Practice starts in 5 s (run 0x2A)`, and its `start:` line in `UE4SS.log` names the
challenge after the map (`... map <map> challenge targets; census: ...`).

### The challenges

| # | Name | Waves | Time limit | Next wave | Full heal after wave | Score for all kills | Points per second left |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `swarm`, Antlion Swarm | 3 | 3:00 | 5 s after a clear | none | 180 | 1 |
| 2 | `skulls`, Skull Squad | 3 | 6:00 | 5 s after a clear | 2 | 320 | 1 |
| 3 | `gauntlet`, Gauntlet | 8 | 12:00 | 5 s after a clear | 3 and 6 | 900 | 1 |
| 4 | `targets`, Target Practice | 3 | 1:30 | 3 s after a clear | none | 720 | 10 |

| Challenge | Wave | Monsters |
| --- | --- | --- |
| Antlion Swarm | 1 | 4 `M_Antlion` |
| Antlion Swarm | 2 | 6 `M_Antlion` |
| Antlion Swarm | 3 | 8 `M_Antlion` |
| Skull Squad | 1 | 1 `M_SkullSwordAlone`, 2 `M_SkullGunnerAlone` |
| Skull Squad | 2 | 2 `M_SkullSpearAlone`, 1 `M_SkullGunnerAlone` |
| Skull Squad | 3 | 1 `M_SkullHammerAlone`, 1 `M_SkullSwordAlone`, 1 `M_SkullSpearAlone` |
| Gauntlet | 1 | 4 `M_Antlion` |
| Gauntlet | 2 | 3 `M_LurkerA` |
| Gauntlet | 3 | 2 `M_SkullSwordAlone`, 1 `M_SkullGunnerAlone` |
| Gauntlet | 4 | 3 `M_HedgeBoarA` |
| Gauntlet | 5 | 2 `M_SkullSpearAlone`, 2 `M_SkullGunnerAlone` |
| Gauntlet | 6 | 3 `M_LurkerA`, 3 `M_HedgeBoarA` |
| Gauntlet | 7 | 1 `M_SkullHammerAlone`, 1 `M_SkullSwordAlone`, 1 `M_SkullGunnerAlone` |
| Gauntlet | 8 | 1 `M_SkullHammerAlone`, 1 `M_SkullSpearAlone`, 1 `M_SkullSwordAlone`, 1 `M_SkullGunnerAlone` |
| Target Practice | 1 | 2 `M_DummyA`, 2 `M_DummyB` |
| Target Practice | 2 | 2 `M_DummyA`, 2 `M_DummyB`, 2 `M_DummyC` |
| Target Practice | 3 | 3 `M_DummyA`, 3 `M_DummyB`, 2 `M_DummyC` |

The 5 s countdown comes first, and wave 1 comes when it ends. Each later wave comes only once the wave before it is
down: 5 s after, or 3 s in Target Practice. Meanwhile the card counts down to it (`NEXT WAVE IN 4`). Unlike Night
Operation's waves, a challenge's waves have no set run time, so a fast clear brings the next wave sooner. As in the
solo run, a wave is down once each of its monsters is dying, can be executed, is written off, is missing or is no
longer tracked.

In Antlion Swarm, Skull Squad and Gauntlet the monsters come as in the solo run: at the four points 14 m from where EVE
started, sent at her, and moved back at most twice when they are stuck or fall (see [The waves](#the-waves)). The full
heal is the solo run's too.

### Target Practice

Target Practice uses the game's three target dummy rows, `M_DummyA`, `M_DummyB` and `M_DummyC` (character IDs 40010,
40020 and 40030). The shipped game places `M_DummyC` in two areas of its DLC. Like the monster rows, the dummy rows drop
nothing and have no kill achievement of their own.

The dummies stand on eight spots in front of the point where EVE started. Angles are from the way she faced:

| Spots | Angle | Distance from the start point |
| --- | --- | --- |
| 1 and 2 | 45 degrees to each side | 12 m |
| 3 and 4 | 25 degrees to each side | 18 m |
| 5 | straight ahead | 22 m |
| 6 and 7 | 40 degrees to each side | 26 m |
| 8 | straight ahead | 32 m |

Each wave draws its own order of the spots, so the dummies stand in other places each round. A dummy appears 1 m above
the height of the start point and faces it. The mod neither sends it at EVE nor gives it an AI controller. How the
dummies look, whether they stand still and how many shots each one takes are not known yet.

Start Target Practice on flat open ground, with nothing in the way for 32 m ahead of EVE. On a slope a spot can lie
inside the ground or above it. A dummy more than 10 m below both the start point and EVE, or more than 40 m from both,
is written off where it is at its first check (2.5 s after it is found, then every 3 s). It is never moved, its wave
stops waiting for it, and shooting it later still scores. Dummies left after a run stay until the next map load.

### Score

Each kill scores by the monster's rank, as in the solo run: 10 for `M_Antlion`, 20 for `M_SkullGunnerAlone` and
`M_LurkerA`, 40 for `M_SkullSwordAlone`, `M_SkullSpearAlone`, `M_HedgeBoarA` and each dummy, and 60 for
`M_SkullHammerAlone`. A success adds a time bonus: 1 point for each whole second left, or in Target Practice 10 points
per second left, counted to the tenth of a second. A Target Practice run that shoots all 18 dummies with 53 s left
scores 720 for the kills and 530 for the time, 1250 in all.

A challenge ends in the solo run's four ways (see [Score and the end of a run](#score-and-the-end-of-a-run)): success
once every monster of its last wave is down, time up at its time limit, failed when EVE dies, and aborted, which
includes `coop challenge stop`.

### The card and the result panel

The card shows the challenge's name in place of `NIGHT OPERATION`. The result panel is the solo run's (see
[What you see](#what-you-see)), with a fifth row, Best: the best run kept for this challenge as score and time, for
example `1250  0:37`, or `-` when none is kept. After a success that set a new best, the line under the heading reads
`New personal best.` A challenge ended with `coop challenge stop`, `coop nightop stop` or `coop off` shows
`Stopped with coop challenge stop.`

The `result:` line in `UE4SS.log` ends with the challenge and its best:

```
result: success waves=3/3 kills=18 score=1250 time=0:37 find_ms=0.8/2.1 challenge=targets best=1250/37 new
```

`new` means this run wrote the best and `kept` that the stored best stays. `best=none` means no best is kept, or the
file could not be read.

With `coop ui off`, the notices name the challenge (`Target Practice: wave 2/3.`), and after the result a new best adds
a `New personal best.` notice.

### Best runs (`coop-records.txt`)

Best runs are kept in `Mods/StellarCoop/coop-records.txt`, one line per challenge in the form
`best_<name>=<score> <seconds>`. Night Operation's line is `best_night`. After a first Target Practice best, the file
reads:

```
# StellarCoop: your best challenge runs on this PC (score and seconds).
best_targets=1250 37
```

A run reads its best when it starts, for the Best row. The file is written only when a run ends in success and beats
the stored best, if there is one: a higher score, or the same score in less time. Failed, time up and aborted runs
never write it. A success keeps no best when a monster never came (its spawn failed), when nothing was killed, or when
`coop nightop start` ran with `noaggro` or `nomove`. The log says why in a `record: not kept (...)` line.

Before it writes, the mod reads the file again and changes only that challenge's line, so every other line, a note of
yours included, stays. It writes `coop-records.txt.tmp` first and renames it over the file, so a write that fails
leaves the file as it was. A file that cannot be read or written gives a `record: cannot read coop-records.txt (...)`
or `record: cannot write coop-records.txt (...)` line, and nothing is written.

The file stays on this PC and never goes over the Steam link. `tools/install.py` keeps it, as it keeps every
`coop-*.txt` file, and `--uninstall` backs it up with the folder. When you update from the zip, copy it out and back
with `coop-settings.txt` (see [INSTALL.md: Update](../INSTALL.md#update)).

### What a challenge touches

A challenge spawns only the solo run's monster rows and the three dummy rows, through the same game request and with
wave keys in the same range, `0xD8000000` to `0xD8FFFFFF`. Like the solo run, it adds or edits no table row, starts no
rule, writes no save, and fires no zone event other than the full heal. It gives no item or reward. Its kills count
toward nothing but the game's general kill achievements, as the solo run's do (see
[What a run touches](#what-a-run-touches)). The only file a challenge writes is `coop-records.txt`.

## The two previews

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
2. Once the Join event reads back, the command registers the dialogue's 12 text keys, and no other text, with the
   game's localization. This happens in memory only; no game file changes. The recruiter's lines (speaker title,
   question, Join and Cancel, the replies) then show in your game language, any of the 23 the game ships. A `text:`
   line ending `TEXT=yes` means the registration worked.
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

The language is the game's setting, which can be changed only in the main menu. If the text step fails, a
`STOP: text:` line says how far it got, and the command continues:

- after `nothing registered`, his text stays in Korean;
- otherwise the keys it registered may show another language, or a mix with Korean (a registration is never undone).

### Sending him away

`coop recruiter off` despawns him through the game's Despawn event and reports 2 s later whether he is gone. `coop off`
despawns him too. A map change removes him.

### What stays changed

Everything the command changes stays in the running game until it ends: the Join event, the network condition, the
test spawn row, the test filter and the registered text. The mod neither undoes nor saves any of it. Whether the game
saves the spawned recruiter is not known yet, so the run ends by killing the game and restoring your backup.

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
  eleven safe spawn rows for the probe, and the recruiter's spawn row and despawn filter for `coop recruiter`. The solo
  run fires only the heal, through the probe's function. No console argument reaches that function.
- `tests/matchmaking_scan_test.py` scans every script and native source of the mod and fails if any of them could
  reach the matchmaking path. The Join row may appear only as the recruiter's constant, which the recruiter neutralizes
  and never fires. The test also sets how many calls each file may make that fire zone events, add table rows or make
  game requests. The only console call it allows is main.lua's photo pause, which sets `SB.PhotoMode.PauseMethod` to 0
  or 1. It first runs on planted violations, so no rule passes vacuously.
- The mod has no code that talks to Shift Up's services. Its only network use is the Steam link between friends,
  through the Steam client the game already runs (see [how-it-works.md](how-it-works.md#the-steam-link)).
