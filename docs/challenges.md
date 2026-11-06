# Challenges (`coop challenge`)

This page is one of four on Night Operation, with [the run](night-operation.md),
[the reward shop](night-operation-shop.md) and [the previews](night-operation-previews.md).

A challenge is a short fight picked from a fixed list. Three of them send waves of the game's monsters at EVE, as the
solo run does. Target Practice stands the game's target dummies in front of her, and the Shooting Range all around her.
Each run ends on the result panel with the time, the score and the best run kept on this PC. The challenges run on the
solo run's code, on a co-op save, and log `[StellarCoop][NR]` lines. Four of them need no Steam session; the Shooting
Range also runs for two linked players (see [The Shooting Range for two](#the-shooting-range-for-two)). They give no
shop points. They have not been tested in game yet.

| Command | What it does |
| --- | --- |
| `coop challenge` | List the challenges and Night Operation's four levels with each one's best run, then the run that is on, if any |
| `coop challenge <name>` | Start that challenge where EVE stands. Its number in the list works too: `coop challenge 5` is `coop challenge range` |
| `coop challenge stop` | End the run that is on, a challenge or Night Operation, on any save. `coop nightop stop` and `coop off` end a challenge too |

With no best kept yet, the list reads:

```
OK: 1 swarm Antlion Swarm: 3 waves, 3:00, no best yet
2 skulls Skull Squad: 3 waves, 6:00, no best yet
3 gauntlet Gauntlet: 8 waves, 12:00, no best yet
4 targets Target Practice: 3 waves, 1:30, no best yet
5 range Shooting Range: 3 waves, 2:00, no best yet
night_easy: Night Operation easy (coop nightop start easy), no best yet
night: Night Operation (coop nightop start), no best yet
night_hard: Night Operation hard (coop nightop start hard), no best yet
night_nightmare: Night Operation nightmare (coop nightop start nightmare), no best yet
```

A start runs the checks of `coop nightop start` and refuses for the same reasons, with one `STOP:` line (see
[Starting a run](night-operation.md#starting-a-run)). The Steam session line names the challenge:
`STOP: Target Practice is solo for now: leave the Steam session first (coop leave)`. The Shooting Range has no such
line: in a session it starts for both players (see [The Shooting Range for two](#the-shooting-range-for-two)). One run
exists at a time, so a start while a challenge or Night Operation is on gets
`STOP: a run is on: coop challenge stop ends it`. A word that is neither a challenge's name nor its number gets
`STOP: unknown challenge: coop challenge lists them`. On a save that is not a co-op save, every form except
`coop challenge stop` gets the co-op save line (see [usage.md](usage.md#commands-that-need-a-co-op-save)).

A start answers `OK: Target Practice starts in 5 s (run 0x2A)`, and its `start:` line in `UE4SS.log` names the
challenge after the map (`... map <map> challenge targets; census: ...`).

## The challenges

| # | Name | Waves | Time limit | Next wave | Full heal after wave | Score for all kills | Points per second left |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `swarm`, Antlion Swarm | 3 | 3:00 | 5 s after a clear | none | 180 | 1 |
| 2 | `skulls`, Skull Squad | 3 | 6:00 | 5 s after a clear | 2 | 320 | 1 |
| 3 | `gauntlet`, Gauntlet | 8 | 12:00 | 5 s after a clear | 3 and 6 | 900 | 1 |
| 4 | `targets`, Target Practice | 3 | 1:30 | 3 s after a clear | none | 720 | 10 |
| 5 | `range`, Shooting Range | 3 | 2:00 | 3 s after a clear | none | 480 | 10 |

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
| Shooting Range | 1 | 3 `M_DummyA` |
| Shooting Range | 2 | 4 `M_DummyA` |
| Shooting Range | 3 | 5 `M_DummyA` |

The 5 s countdown comes first, and wave 1 comes when it ends. Each later wave comes only once the wave before it is
down: 5 s after, or 3 s in Target Practice and the Shooting Range. Meanwhile the card counts down to it
(`NEXT WAVE IN 4`). Unlike Night Operation's waves, a challenge's waves have no set run time, so a slow clear holds the
next wave back until the time limit. As in the solo run, a wave is down once each of its monsters is dying, is hidden
by the game, is written off, is missing or is no longer tracked.

In Antlion Swarm, Skull Squad and Gauntlet the monsters come as in the solo run: at the four points 14 m from where EVE
started, after the same ground check, sent at her, and moved back at most twice when they are stuck or fall (see [The
waves](night-operation.md#the-waves)). The full heal is the solo run's too.

## Target Practice

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

Each wave draws its own order of the spots, so the dummies stand in other places each round. Each spot goes through the
solo run's ground check (see [The waves](night-operation.md#the-waves)): a blocked spot comes back towards the start point, or the dummy
goes to the next spot that no other dummy of its wave uses (`(ground: spot 3 blocked, spot 6)`). The third wave uses
all eight spots, so there the dummy stands 2.5 m beside another one's spot. A dummy appears as high above the floor at
its spot as a monster does, and faces the start point. The mod neither sends it at EVE nor gives it an AI controller.
How the dummies look, whether they stand still and how many shots each one takes are not known yet.

Start Target Practice on flat open ground, with nothing in the way for 32 m ahead of EVE. When the ground check cannot
run (`(ground: unchecked: ...)` in the log), a spot on a slope can lie inside the ground or above it. A dummy more than
10 m below both the start point and EVE, or more than 40 m from both, is written off where it is at its first check
(2.5 s after it is found, then every 3 s). It is never moved, its wave stops waiting for it, and shooting it later still
scores. Dummies left after a run stay in the world, as monsters do (see [Score and the end of a
run](night-operation.md#score-and-the-end-of-a-run)).

## Shooting Range

The Shooting Range brings back the game's cut shooting test. Its test level, `LV_Test_Shooting_01`, is no longer in
the game's files, but the game's tables still hold its zone and its quest: 12 `M_DummyA` (character ID 40010) and
three rounds that asked for 3, then 4, then 5 kills. The range keeps those rounds. Its dummies stand all around the
point where EVE started, not only in front of her. Angles are from the way she faced:

| Spots | Angle | Distance from the start point |
| --- | --- | --- |
| 1 and 5 | straight ahead and straight behind | 15 m |
| 3 and 7 | 90 degrees to each side | 15 m |
| 2, 4, 6 and 8 | 45 and 135 degrees to each side | 20 m |

Each round draws its own order of the eight spots. The dummies are placed and written off as in Target Practice (see
[Target Practice](#target-practice)), so start the range on flat open ground with nothing in the way for 20 m around
EVE.

The range is meant for the gun: switch to the drone's ranged mode and shoot. Ranged mode needs the drone's gun, which
the story unlocks. Before that, EVE can still reach the dummies with her sword, and they score the same. How many
shots a dummy takes is not known yet.

The game's own gun targets, the target drones (`BP_TargetDrone_01`), are not used. The game breaks a drone through
data it keeps only for the drones it placed from its own tables, so a drone spawned by the mod would most likely never
break.

While a Shooting Range run is on, and during its 10 s result, its score also shows on `WB_ShootingTrainingTest`, the
cut test's own score widget, which held a placeholder Korean score. It is one line of pink text near the top left
corner, in the card's words (`SCORE 120`), drawn at half its size. It hides while the game is paused, after the
result, with `coop ui off` and at `coop off`. When the widget cannot be made, `UE4SS.log` has one
`[StellarCoop][NR] board: off until the mod reloads (...)` line and the card shows the score alone.

## The Shooting Range for two

With a partner linked, the host types `coop challenge range` (or `coop challenge 5`). The run then starts, plays and
ends as a co-op Night Operation run does (see [The co-op run](night-operation.md#the-co-op-run)). The dummies are wave monsters there
too: with shared enemies on, the two copies of a dummy pair as [Shared waves](night-operation.md#shared-waves) says. The differences:

- His night line carries `range` in place of a level. Her `join:` line in `UE4SS.log` names it
  (`... challenge range; census: ...`), and her notice reads `Shooting Range: <host> started the challenge. It begins
  in 5 s.`
- `coop challenge range` on the guest's side answers `STOP: the host starts a co-op run`.
- There is no heal. A co-op run gives no shop points and keeps no best on either PC. Each result panel's Best row
  shows the best already kept on that player's own PC.
- A death is a down as in a co-op Night Operation run (see [Down and revive](night-operation.md#down-and-revive)), but the range gives
  no self revive: `coop nightop revive` answers `STOP: no self revive left in this run`, and only the partner's hold
  gets a downed EVE up.

## Score

Each kill scores by the monster's rank, as in the solo run: 10 for `M_Antlion`, 20 for `M_SkullGunnerAlone` and
`M_LurkerA`, 40 for `M_SkullSwordAlone`, `M_SkullSpearAlone`, `M_HedgeBoarA` and each dummy, and 60 for
`M_SkullHammerAlone`. A success adds a time bonus: 1 point for each whole second left, or in Target Practice and the
Shooting Range 10 points per second left, counted to the tenth of a second. A Target Practice run that shoots all 18
dummies with 53 s left scores 720 for the kills and 530 for the time, 1250 in all. A Shooting Range run that downs all
12 dummies with 89 s left scores 480 and 890, 1370 in all.

A challenge ends in the solo run's four ways (see [Score and the end of a run](night-operation.md#score-and-the-end-of-a-run)): success
once every monster of its last wave is down, time up at its time limit, failed when EVE dies, and aborted, which
includes `coop challenge stop`.

## The card and the result panel

The card shows the challenge's name in place of `NIGHT OPERATION`. The result panel is the solo run's (see
[What you see](night-operation.md#what-you-see)), with a fifth row, Best: the best run kept for this challenge as score and time, for
example `1250  0:37`, or `-` when none is kept. After a success that set a new best, the line under the heading reads
`New personal best.` A challenge ended with `coop challenge stop` or `coop nightop stop` shows
`Stopped with coop challenge stop.` `coop off` turns the mod's screens off before it ends the run, so only the
`result: aborted (coop off)` line in `UE4SS.log` says how that run ended.

The `result:` line in `UE4SS.log` ends with the challenge and its best:

```
result: success waves=3/3 kills=18 score=1250 time=0:37 find_ms=0.8/2.1 challenge=targets best=1250/37 new
```

`new` means this run wrote the best and `kept` that the stored best stays. `best=none` means no best is kept, or the
file could not be read.

With `coop ui off`, the notices name the challenge (`Target Practice: wave 2/3.`), and after the result a new best adds
a `New personal best.` notice.

## Best runs (`coop-records.txt`)

Best runs are kept in `Mods/StellarCoop/coop-records.txt`, one line per challenge in the form
`best_<name>=<score> <seconds>`. Night Operation's lines are `best_night` for the normal level, `best_night_easy`,
`best_night_hard` and `best_night_nightmare`. After a first Target Practice best, the file reads:

```
# StellarCoop: your best challenge runs on this PC (score and seconds).
best_targets=1250 37
```

A run reads its best when it starts, for the Best row. The file is written only when a run ends in success and beats the
stored best, if there is one: a higher score, or the same score in less time. Failed, time up and aborted runs never
write it. A success keeps no best when a monster never came (its spawn failed), when nothing was killed, when `coop
nightop start` ran with `noaggro` or `nomove`, or in a co-op run, Night Operation or the Shooting Range. The log says
why in a `record: not kept (...)` line.

Before it writes, the mod reads the file again and changes only that challenge's line, so every other line, a note of
yours included, stays. It writes `coop-records.txt.tmp` first, then deletes the old file and renames the `.tmp` to
`coop-records.txt`, or writes `coop-records.txt` directly if the rename is refused. A write that fails before the
delete leaves the file as it was. One that fails after it leaves the new text only in `coop-records.txt.tmp`: rename
that file to `coop-records.txt` before the next run or update, or the bests it holds are lost. A file that cannot be
read gives a `record: cannot read coop-records.txt (...)` line, and nothing is written. A write that fails gives
`record: cannot write coop-records.txt (...)`.

The file stays on this PC and never goes over the Steam link. `tools/install.py` keeps it, as it keeps every
`coop-*.txt` file, and `--uninstall` backs it up with the folder. When you update from the zip, copy it out and back
with `coop-settings.txt` (see [INSTALL.md: Update](../INSTALL.md#update)).

## What a challenge touches

A challenge spawns only the solo run's monster rows and the three dummy rows, through the same game request and with
wave keys in the same range, `0xD8000000` to `0xD8FFFFFF`. Like the solo run, it adds or edits no table row, starts no
rule, writes no save, and fires no zone event other than the full heal. It gives no item or reward. Its kills count
toward nothing but the game's general kill achievements, as the solo run's do (see
[What a run touches](night-operation.md#what-a-run-touches)). The only file a challenge writes is `coop-records.txt`. The Shooting Range
also puts one widget on screen, the cut `WB_ShootingTrainingTest`.
