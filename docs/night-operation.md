# Night Operation

Night Operation is a multiplayer wave-survival mode that Shift Up prototyped and cut before Stellar Blade's release.
Much of it is still in the game files. StellarCoop has a run of its waves, `coop nightop`, which you play alone or with
a linked partner at one of four levels, a shop that sells seven items (three of them cut items) for the points runs
earn, in the game's own shop screen with the cut Beta Seed as its currency, Night Operation choices in Roxanne's
dialogue in Xion, and five challenges on the same code, `coop challenge`: four solo fights and the Shooting Range,
which the host can also run for both players. Two research previews test other parts of the cut mode; they are not
playable modes. The shop screen opened in game on 2026-10-27, with its rows added. One solo run was played on
2026-10-28: its waves spawned, but the mod tracked none of its monsters, so no kill scored, and some monsters stood
inside walls. The fixes for both have not been tested in game yet, and neither have buying, Roxanne's choices and the
challenges.

The reward shop, the challenges and the two previews have pages of their own:
[night-operation-shop.md](night-operation-shop.md), [challenges.md](challenges.md) and
[night-operation-previews.md](night-operation-previews.md).

## What the game files contain

- The Xion recruiter. He was meant to stand next to Roxanne in Xion's Scrap Market, at a spawn point named
  `TeleportPoint_Xion_MultiPlay`. His dialogue, left in Korean in the game files, asks whether you want to join the
  night operation, with a Join and a Cancel choice. Several of his lines are still marked as temporary text.
- A rule manager and a rule table, `MultiPlayRuleTable`, which ships empty. Its rows have fields for a duration, a
  number of lives, a respawn time and timed zone events. These fields describe a timed survival round.
- Multiplayer test rows in the game's zone event, condition and spawn tables. The game's event system runs them.
- A revive. An interaction graph, `Multi_NightOperation_Revive`, holds only its prompt, Resuscitate. The game's text
  table has the mode's revive messages (a request to the other player, its receipt, Spectating, and Spend {Name} to
  Self-Resuscitate). The item table's one revival item, the WB Pump ("Revives in the same place when killed in
  combat"), is likely the {Name} that the self revive spent. The rule table's fields include a coma effect, the state
  a downed player was in.
- The online part. The recruiter's Join choice starts the mode's matchmaking: a request to Shift Up's online services,
  a matchmaking service and dedicated game servers hosted on Amazon.

StellarCoop never contacts those servers. They belong to Shift Up and served a mode that never shipped. See
[How the original matchmaking is blocked](night-operation-previews.md#how-the-original-matchmaking-is-blocked).

## The plan

The plan is to bring Night Operation back as a mode you play with friends over Steam, without Shift Up's servers. These
parts exist:

- The run, alone or for two linked players. Both games get the same waves, both screens show one timer and one score,
  and with shared enemies on, each wave monster has one HP bar and one death in both games
  (see [The co-op run](#the-co-op-run)).
- The cut mode's revive in a co-op run, with the experimental `revive` setting on: a dead EVE waits 30 s for her
  partner, who revives her with the interact key, or revives herself a few times a run (see
  [Down and revive](#down-and-revive)).
- The reward shop, on the console, with two cut items the game never sold (see [The reward shop](night-operation-shop.md)).
- The recruiter, as a preview: he stands next to Roxanne in Xion's Scrap Market. His lines stay in Korean (see
  [His language](night-operation-previews.md#his-language)).
- Everything runs on a co-op save, a copy of your save, and never on your own saves.

These parts do not exist yet:

- The recruiter's Join choice starting StellarCoop's Steam friends matchmaking. Today the host types
  `coop nightop start`.
- More players, up to six. The Steam link holds two.
- A boss wave.

The Steam link connects two players and shows each player the other's ghost (see [playing-with-a-friend.md](playing-with-a-friend.md)). The previews
test how the cut mode's parts behave.

## The solo run (`coop nightop`)

`coop nightop start` sends five timed waves of the game's monsters at EVE where she stands, with an 8-minute timer and a
score. That is the normal level; three other levels change the number of monsters, the time limit and the shop points
(see [Levels](#levels)). It runs on a co-op save. With no Steam session it is a solo run, described in this section;
with a partner linked, see [The co-op run](#the-co-op-run). Each step is logged in `UE4SS.log` as `[StellarCoop][NR]`
lines.

A solo run was played once, on 2026-10-28, before the two fixes described in [The waves](#the-waves): the tracking of
its monsters and the ground check of their spawn points. The fixed run has not been tested in game yet, and the co-op
run not at all. Check in game: each wave logs `wave 1 find +1 s: tracked 4/4` with every monster of the wave counted,
each kill logs a `kill` line, no monster appears inside a wall or under the floor, and a success pays points. On open
ground no spawn line should end with `(ground: unchecked: ...)`. If every run shows it, the navigation calls do not
work in this UE4SS build and the monsters spawn at their points unchecked, as on 2026-10-28. In a two-PC run, compare
both players' spawn lines for the same key. If the points differ and the guest's log shows `missing` with a `nearest
new body` for that key, report it: her game looks for each copy at its own point, not at the host's.

The run keeps its own timer in the mod. It adds no row to the game's rule table and starts none of the cut mode's
rules, so a death goes through the game's usual death screen and respawn. Parts of the run adapt code from Survival
Protocol, with its author's permission (see [Credits](../README.md#credits)).

| Command | What it does |
| --- | --- |
| `coop nightop start` | Start a run where EVE stands, at the normal level |
| `coop nightop start <level>` | The same at a level: `easy`, `normal`, `hard` or `nightmare` (see [Levels](#levels)). A test switch may follow it: `coop nightop start hard noaggro` |
| `coop nightop start noaggro` | The same, but the monsters are not sent at EVE (a test switch) |
| `coop nightop start nomove` | The same, but stuck or fallen monsters are not moved (a test switch) |
| `coop nightop stop` | End the run that is on, Night Operation or a challenge, on any save. `coop off` ends it too |
| `coop nightop revive` | In a co-op run with `revive=on`, while your EVE is down: revive her yourself, a few times a run (see [Down and revive](#down-and-revive)) |
| `coop nightop` | The run's wave, run time, score and kills while a run is on, then the census: how many living characters stand within 40 m of EVE, and the wave monsters still in the world that show a wave key, each with its run number (8 at most are named). The game shows a monster's wave key only in a networked game, so this list is empty in practice |
| `coop nightop shop` | Open the game's own shop screen with the items of the [reward shop](night-operation-shop.md), your points shown as Beta Seeds (see [The shop screen](night-operation-shop.md#the-shop-screen-coop-nightop-shop)) |
| `coop nightop buy` | Your points and the seven items, in the console |
| `coop nightop buy <n> [count]` | Buy 1 to 10 of item n with your points (see [Buying from the console](night-operation-shop.md#buying-from-the-console-coop-nightop-buy)) |

### Before your first run

1. Load a co-op save, as in step 1 of [Before you try a preview](night-operation-previews.md#before-you-try-a-preview). For a solo run, leave any
   Steam session (`coop leave`).
2. Back up your saves and keep Steam Cloud off for Stellar Blade (steps 2 and 3 there). Whether the game saves a wave
   monster that is still alive when it saves is not known yet.
3. If you used `coop no rule` in this game run, restart the game: a run does not start while the probe's rule is set.

A run edits no game table, so you can quit from the menu afterwards as usual. The co-op save keeps the session's
progress like any co-op save, and your own saves are not touched.

### Starting a run

Go to open ground outside Xion, with no enemy or other character within 40 m of EVE, and type `coop nightop start`.
On a co-op save you can also pick the level from Roxanne in Xion: see
[Night Operation at Roxanne's](night-operation-shop.md#night-operation-at-roxannes).
The answer is `OK: Night Operation starts in 5 s (run 0x2A)`, where `0x2A` is the run's number, or
`OK: Night Operation (hard) starts in 5 s (run 0x2A)` at another level. The command refuses with one `STOP:` line, and
changes nothing, when:

- the save is not a co-op save;
- the Steam link is not ready yet;
- you are the guest in a session (`the host starts a co-op run`), or you host one with no partner linked;
- a run is already on;
- the `coop no` probe's rule is set in this game run;
- EVE is not in the world;
- EVE is in Xion, whose people and quests stay out of a fight;
- a living character other than EVE stands within 40 m. The line gives the count and the nearest distance, for
  example `STOP: census: 1 living within 40 m (nearest 23.4 m); 0 wave bodies: go where no one is within 40 m`.

The census counts a character only while its `InteractionState` reads 0 and it has a controller. Monsters that an
earlier run left in the world read 1 (see [The waves](#the-waves)), so they do not stop a start and the census does not
count them.

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

The run of 2026-10-28 used these points as they were, and some monsters spawned inside walls. Before each spawn the mod
now checks the point against the navmesh, the walkable ground the game's AI moves on. It follows the navmesh in a
straight line from EVE's start towards the point. If a wall, a ledge or a gap stops the line, the point comes back to
1.5 m short of the stop. The point then goes down or up to the navmesh floor, looked for within 5 m of the start's
height, or within 15 m on a slope. If the point ends up less than 5 m from the start, or there is no floor, the monster
goes to another point that holds: first a gate that no other monster of its wave uses, then a point 2.5 m beside
another monster's point, so two monsters of one wave never get the same point. If no gate holds, the monster goes to
the farthest point that a blocked line left at least 2 m from the start, and if there is none, to its own point as
before the check (the spawn line then ends with `raw spot`). The height follows the floor: on flat ground the monster
appears 1 m above the start point, as before, and on a floor 3 m higher it appears 3 m higher. The spawn line in
`UE4SS.log` says when a point moved. Three lines of one wave:

```
spawn 0xD82A0100 M_Antlion at 14305,-17676,3280 yaw -40 (ground: moved 6.5 m)
spawn 0xD82A0101 M_Antlion at 15454,-16730,3280 yaw -112 (ground: gate 3 blocked, gate 2)
spawn 0xD82A0102 M_Antlion at 15580,-16946,3280 yaw -120
```

The line towards the first monster's gate stopped 9 m out, so the monster came back to 7.5 m. The second one's gate
was blocked and every gate had a monster of the wave, so it spawned 2.5 m beside the third one's point. A run started
in a corridor, where no gate holds, logs lines like this one:

```
spawn 0xD8510100 M_Antlion at 20226,-9627,3050 yaw 55 (ground: gate 4 blocked, no other gate holds: 3.2 m out)
```

A move of less than 1 m adds nothing to the line. The gates are numbered in the order above: 1 and 2 ahead, 3 and 4
behind. If the game's navigation calls are missing or fail, or EVE's start is not on the navmesh, the run places every
monster as it did before the check, and its first spawn line ends with `(ground: unchecked: <reason>)`. In a co-op
run each game checks the points against its own copy of the map. Both get the same points unless one side logs
`unchecked` or its navmesh differs.

The game does not keep a monster's wave key where the mod can read it (it copies the key to the character only in a
networked game), so the mod finds each monster by where it stands. Just before a wave's first spawn, it lists the
characters in the world and where each one stands. 1 s and 2.5 s after the wave's last spawn, it lists them again and
logs how many of the wave's monsters it has found (`wave 1 find +1 s: tracked 4/4`). A character that is alive and
shown, is not EVE, is not one of the run's monsters already, and is not standing within 50 m of where it stood before
the wave counts as new. It becomes the monster of the nearest of the wave's spawn points within 5 m (the points the
spawn requests used, after the ground check). Alive means that its `InteractionState` reads 0 or 1. A monster from the
run's spawn request reads 1 (executable) from its first second until it dies, when it reads 3. The run of 2026-10-28
took only 0 as alive, so it found none of its monsters: each wave's finds logged 0 (`wave 1 find +2.5 s: tracked 0/4`),
every monster was `missing` with `no new body`, and no kill scored. A field enemy that walked onto a point before the
wave is never taken. The game reuses its characters, sometimes from far away, which is why the 50 m rule exists. A
monster not found 2.5 s after its wave's last spawn is logged as `missing`, with the distance of the nearest new
character left over (`missing 0xD82A0103 M_Antlion (nearest new body 6.2 m)`, or `no new body`), and its wave does not
wait for it.

The mod then sends each new monster at EVE. 0.6 s after the monster is found, the mod reports a 0.01 damage event and
a noise from EVE, puts the monster in battle state, and gives it EVE as focus and a move towards her; if it is still
not fighting 4 s later, the mod does this again. A monster with no AI controller gets its default one first.

From 2.5 s after it is found, and then every 3 s, a monster more than 10 m below both the start point and EVE, or more
than 40 m from both, is moved to 7 m from EVE. This happens at most twice per monster. A monster still out after that
no longer holds up its wave, and killing it later still scores.

Once wave 2 is down, and again once wave 4 is down, the mod fires the game's full heal (the probe's heal event,
`SE_10_E_ActorEff_011`).

### Levels

The word after `coop nightop start` sets how many monsters each wave holds, the time limit and the shop points a run
earns. With no word the level is normal, the run described above.

| Level | Monsters in waves 1 to 5 | In all | Time limit | Shop points |
| --- | --- | --- | --- | --- |
| `easy` | 3, 2, 4, 3, 3 | 15 | 9:00 | 50 % |
| `normal` | 4, 3, 5, 4, 4 | 20 | 8:00 | 100 % |
| `hard` | 6, 5, 7, 6, 6 | 30 | 7:30 | 150 % |
| `nightmare` | 8, 8, 8, 8, 8 | 40 | 7:00 | 200 % |

A larger wave takes more of its own monsters: it goes through the wave's list in [The waves](#the-waves) again from
its first monster. Hard's wave 2 is `M_SkullSwordAlone`, `M_SkullSwordAlone`, `M_SkullGunnerAlone`,
`M_SkullSwordAlone`, `M_SkullSwordAlone`, and nightmare's wave 5 has two `M_SkullHammerAlone`. Easy drops the last
monsters of each wave, so its wave 2 has no `M_SkullGunnerAlone`. The extra monsters come through the same spawn
request and stand at the same four points, the fifth to the eighth of a wave 2.5 m from a point. They are found, sent
at EVE, moved back and scored like the others. The waves keep their run times, the 10 s after a clear, the heals and
the cap of 8, so a nightmare wave starts only once every monster of the waves before it is down.

A monster's HP and damage are the game's at every level: the mod has no way to change them in a solo game. In a co-op
run with shared enemies on, the host's `enemy_hp_scale` and `enemy_balance_scale` apply at every level, as they do to
any shared enemy (see [Shared waves](#shared-waves)).

The card counts down the level's time limit but does not name the level, and neither do the notices. The start
answer, `coop nightop` (`run 0x2A level hard: wave, wave 2/5, ...`), the `start:` line in `UE4SS.log`
(`... map <map> level hard; census: ...`) and the `result:` line (`challenge=night_hard`) name it. Each level keeps its
own best run (see [Best runs](challenges.md#best-runs-coop-recordstxt)).

### Score and the end of a run

Each kill scores by the monster's rank: 10 for `M_Antlion`, 20 for `M_SkullGunnerAlone` and `M_LurkerA`, 40 for
`M_SkullSwordAlone`, `M_SkullSpearAlone` and `M_HedgeBoarA`, and 60 for `M_SkullHammerAlone`. A monster counts as down
for its wave once it is dying or the game hides it, and it scores once it dies.

A run ends in one of four ways:

- Success: every monster of the five waves is down, written off, missing or no longer tracked. The score gets 1 point
  for each whole second left.
- Time up: run time reaches the level's time limit, 8:00 at the normal level.
- Failed: EVE dies. The game's death screen and respawn run as usual. A co-op run gives a dead EVE 30 s to be revived
  first (see [Down and revive](#down-and-revive)).
- Aborted: `coop nightop stop` or `coop off`; fast travel, a map change or a load; EVE more than 80 m from the start
  point for 10 s; a save that is no longer a co-op save; a Steam session that starts during a solo run; or an error in
  the run, which `UE4SS.log` names.

The log then has one line such as:

```
result: success waves=5/5 kills=20 score=731 time=5:28 find_ms=0.9/2.4 challenge=night best=731/328 new
```

`find_ms` is the mean and the longest time the mod took to list the game's characters, which it does once a second
while monsters are tracked, and at each wave's start and finds. It asks the engine for the characters of one class
(`GetAllActorsOfClass`); up to 0.6.0-beta.3 the run used `FindAllOf`, which walks every object (25 to 80 ms in game).
A success that beats the best run kept in `coop-records.txt` is written there, and `best=` gives the best after the run
(see [Best runs](challenges.md#best-runs-coop-recordstxt)).

Monsters still alive when a run ends, written-off ones after a success included, stay in the world as ordinary enemies,
and they no longer score. The mod has no safe way to remove them. Ctrl+R during a run ends it with no result, and its
monsters stay too. They already stand in the world when the next run's waves begin, so that run never takes them for
its own.

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
`ui_language=english` (see [interface.md](interface.md#options)).

With `coop ui off`, the same facts come as notices: the start, each wave, each wave cleared, and the result.

### What a run touches

A run spawns its monsters with the same game request as the probe's `coop no actor`. Each monster carries a wave key
from `0xD8000000` to `0xD8FFFFFF`, a range that none of the game's spawn rows uses. The heal is the only zone event a
run fires. Before each spawn the run asks the game's navigation system (`NavigationSystemV1`) where the walkable ground
is; those calls only read the navmesh. A run itself adds or edits no table row (the shop and Roxanne's choices do, see
their sections), starts no rule, writes no save, and never hides or removes a monster. No word typed after `start`
reaches a game call: the level only picks the wave sizes, the time limit and the points, and `noaggro` and `nomove` only
turn off the mod's own steps.

Each kill most likely counts toward the game's general kill achievements, as any kill does: the ones for 10 and 1500
kills and the ones for kills with each kind of skill. A run can unlock one of them if your save is close to its count.
Restoring a backup does not take an unlocked achievement back.

## The co-op run

With a partner linked over the Steam link, the host starts the run for both players. Each game spawns the same waves
at the same points around the host's start point, and both cards show one timer and one score. The host's level is
the run's: the waves, the score for each kill, the heals and the time limit are those of a solo run at that level. The
Steam link holds two players, so a run has two at most, each on a co-op save.

### Starting a run together

Both players stand together on open ground outside Xion. The host types `coop nightop start`, with a level if he
wants one (`coop nightop start hard`). His game makes the checks of [Starting a run](#starting-a-run) on his side and
answers `OK: Night Operation: waiting for <partner> to join (run 0x2A)`, or at another level
`OK: Night Operation (hard): waiting for <partner> to join (run 0x2A)`, and his card reads `WAITING FOR PARTNER`. On
the guest's game the same command answers `STOP: the host starts a co-op run`.

The guest's game asks her nothing. It checks her side at once, and the first check that fails gives the reason that
the host gets as a notice, `<partner> cannot join the run: <reason>.`:

| Check on the guest's game | Reason in the host's notice |
| --- | --- |
| A co-op save is loaded | `not on a co-op save` |
| No run of hers is on, and her game is not paused and shows none of its screens | `already in a run` |
| Her EVE is in the world, on the host's map | `on another map` |
| Her EVE stands within 50 m of the host's start point | `more than 50 m from you` |
| No living character but her EVE stands within 40 m | `enemies or people within 40 m` |
| No monster left by an earlier run with the same run number is in her world | `monsters of an earlier run are still there` |

With no answer within 5 s, the reason is `no answer`. A refused run is dropped with no result. After a refusal for
monsters of an earlier run, the host's next starts skip that run number until the mod reloads. That last check reads
the wave keys the census lists, which the game does not show outside a networked game, so it does not refuse in
practice.

When she answers that she is ready, both cards count down from `STARTS IN 5`, and the guest gets the notice
`<host> started Night Operation. It begins in <n> s.` From then on each game spawns its own copy of each monster.

His night line carries the level, and her game builds its waves from it. Her `join:` line in `UE4SS.log` names it
(`join: run 0x2A seed 0x... at ... map <map> level hard; census: ...`), and so does `coop nightop` on her side while
the run is on. Her notice and card do not.

### During the run

- The host's game decides when each wave starts and when and how the run ends. The guest's game follows the host's
  night line, which comes at least once a second (see
  [internals/steam-link.md](internals/steam-link.md#channel-0-text)).
- A monster scores once, when it dies in either world. With shared enemies on, a death in both worlds also scores
  once.
- A wave is down once each of its monsters is down, written off, missing or no longer tracked in both worlds, so the
  next wave waits for the slower player or for its run time. The cap of 8 counts the monsters not done in both worlds.
  Both games fire the full heal once wave 2, and again once wave 4, is down.
- The timer is the host's game time. His pause stops it on both cards, while the guest's game keeps running and her
  monsters keep fighting. Her pause stops only her spawns and reads; she spawns the waves she missed when it ends. Her
  card shows his run time plus half the ping's round trip, and moves only when it is more than 1 s off.

### Down and revive

In a co-op run a death does not end the run at once when the dead player has the experimental `revive` setting on
(Options > Session > Friend can revive me, or `revive=on` in `coop-settings.txt`; off by default): the dead EVE is down.
She lies where she fell with the game's death screen up, and the run goes on for her partner. The cut mode put a
downed player in a coma that its rule set up; the rule table ships empty and the run starts no rule, so the mod keeps
the game's death screen and revives with the game's in-place respawn. With `revive=off`, a death ends the run as it
did before the revive.

- She waits up to 30 s. Her card's title reads `Spectating` and the time left. The card hides while the game shows
  one of its own screens, so whether it shows over the death screen is not known yet. Her screen shows
  `Asked <partner> for a resuscitation.` and her partner's shows `<name> has requested resuscitation.`
- Her partner revives her by standing next to her EVE (its ghost within 2 m across and 1 m up or down of the partner's
  EVE) and holding the interact key, F or the pad's right trigger, for 3 s. The partner's card reads
  `Resuscitate [F]` and her time left, then the percent of the hold. Letting go, stepping away or a pause starts the hold over. Only the game's
  default interact keys count, not a key rebound in the game's options.
- Once the hold is full, her game calls the game's in-place respawn on her EVE, the call that `coop revive test` makes
  (see [playing-with-a-friend.md](playing-with-a-friend.md#revive-by-your-friend-experimental)). She gets up where she fell with full health and her
  recovery items refilled, as after a camp respawn, and the zone does not reset. She reads `Revived by <partner>.`,
  her partner reads `You revived <name>.` and `<name> has joined the game.`
- She can revive herself with `coop nightop revive`: 3 times a run at easy, 2 at normal, 1 at hard and none at
  nightmare. The answer is `OK: revive asked: 1 self revives left in this run`. `coop nightop` adds
  `down 24 s, 1 self revives left` to the run's state while she is down. Nobody stands next to her body to show it
  lies on ground she can get up on, so her own revive needs the body within 2 m across and 1 m up or down of the last
  place where her EVE walked, or where her body now lies on a floor. A body that fell through the map, into a pit or
  off a ledge is refused (`no revive: your EVE lies 0.4 m across and 6.2 m up or down from where she last walked`),
  and the refusal spends no self revive.
- One call is made per down. If she is not up 5 s after it, the call did not take: the down asks for no other, and
  she waits out the 30 s or respawns at a camp, which both end the run as a death. Getting up within those 5 s counts
  as the revive, even if it was the death screen's respawn.
- The heal after waves 2 and 4 skips a downed EVE. The revive gives her full health.

The words on the card and in these notices are the cut mode's own, in the game's language. With
`ui_language=english`, or when the game's text table cannot be read, they are its English.

The run fails when:

- the 30 s run out with no revive (a call already made gets 5 s more for its result), or she gets up with no revive
  asked or after a call that did not take, which is the death screen's own respawn at a camp. The lines are those of a
  death in [How a co-op run ends](#how-a-co-op-run-ends);
- both EVEs are down at once for 6 s, with no revive call of the host's under way. The guest's line does not say
  when she has made a call, and a call has 5 s to get her up, so the host's game waits that long and one second more
  for her line. Both screens then show the game's own `All players have died.`

The down also needs each game's own life state, the `life=` line that `coop status` shows while a session holds.
Without it, a death ends the run as in a solo run. A revive call also needs `revive=on` at the time of the call, the
death screen up, a life state of 3 to 5, no respawn or warp under way, a standalone game and no `coop no` probe rule.
During a run the [friend's revive](playing-with-a-friend.md#revive-by-your-friend-experimental) (3 s next to the downed EVE with no
key) and its notices stand aside, so a revive comes only from the run.

`UE4SS.log` has `[StellarCoop][NR]` lines for each step: on the downed side `down (life 3): 30 s for a revive, 2 self
revives left`, `revive asked (friend) after 6.5 s down`, `revive not asked (self): <why>`, `up: revived (friend)` and,
for a call that did not take, `revive (friend) did not take: not up 5 s after the call`;
on the partner's side `Kaanta is down`, `revive of Kaanta stopped at 50 %`, `revive of Kaanta: held for 3 s` and
`Kaanta is up again`. The call's own lines are `[StellarCoop][GR] revive: ...` and `revive result (...)`.

The game's achievement table has no row on a death, a respawn or a revival, so a revive counts toward no achievement
and against none. Like the rest of the run, it happens only on a co-op save. None of this has been tried in game yet,
and neither has the in-place respawn itself.

### How a co-op run ends

The run ends on both screens, each with its result panel. The line under the heading says who ended the run:

| What ended the run | Host's line | Guest's line |
| --- | --- | --- |
| Success | none | none |
| Time up | `Time is up.` | `Time is up.` |
| The host's EVE died and was not revived | `Your EVE died.` | `Your partner's EVE died.` |
| The guest's EVE died and was not revived | `Your partner's EVE died.` | `Your EVE died.` |
| Both EVEs down at once for 6 s | `All players have died.` | `All players have died.` |
| On the host's side: `coop nightop stop`, a map change or a load, 80 m from the start point for 10 s, a save that is no longer a co-op save, or an error | His reason, as in the solo run | `Your partner left the run.` |
| The same on the guest's side | `Your partner left the run.` | Her reason, as in the solo run |
| The session ended: `coop leave` (F8) or `coop off` on either side | `The link to your partner was lost.` | `The link to your partner was lost.` |

A player who types `coop off` ends their own run as a stop (`result: aborted (coop off)` in `UE4SS.log`); only the
partner reads the lost line. A game's night line stops while that game does not tick, for example during a load. Once it
has not reached the other game for 5 s, the other player's run ends with `The link to your partner was lost.` The player
whose game stalled reads their own reason if their game found one first (`Ended by a map change or a load.` after a
load), else the same lost line.

A death on either side ends both runs as failed once its down ends with no revive (see
[Down and revive](#down-and-revive)). A host who stops while he still waits for the guest's answer drops the run with no
result.

### Shared waves

With shared enemies on (the default, see [shared-enemies.md](shared-enemies.md#shared-enemies-experimental)), each wave monster pairs
with its copy in the other game by its spawn key, like a field enemy: one HP bar, balance gauge and death, decided by
the host's game, with the host's `enemy_hp_scale` and `enemy_balance_scale`. A copy dies in your world only if you took
part in its fight (see [internals/safety.md](internals/safety.md#achievements)). A copy that stays alive in your world for that
reason keeps your wave open until you kill it, it is still out of reach after its two moves (as in the solo run), or
the time runs out.

With same place on (the default), a pair's two copies stand in the same place on both screens: one game runs the
monster's AI and the other draws its copy (see [shared-enemies.md](shared-enemies.md#same-place-experimental)). The guest's game then
leaves the push towards her EVE and the stuck moves of a monster to same place while all of these hold: her shared
enemies run as the guest, same place draws at least one copy (`pilot=on piloted=1` or more in `coop status`), and the
host's night line lists that monster as found and not yet down, killed, written off or lost in his world. `UE4SS.log`
says so once a monster, for example `[StellarCoop][NR] aggro 0xD82A0200: left to the pilot`. A monster that the host's
game never found keeps the solo run's rules in her world. Once the host's copy is done, her copy gets the stuck moves
back, but the pushes towards her EVE that were skipped are not made again.

Same spawns leave wave monsters out, since none of the game's spawn rows holds their keys. No wave has a boss.

With `shared_enemies=off` on either PC, nothing pairs: each player fights the monsters of their own world, and the
wave starts, the timer and the score are still shared.
