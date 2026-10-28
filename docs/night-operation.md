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
[How the original matchmaking is blocked](#how-the-original-matchmaking-is-blocked).

## The plan

The plan is to bring Night Operation back as a mode you play with friends over Steam, without Shift Up's servers. These
parts exist:

- The run, alone or for two linked players. Both games get the same waves, both screens show one timer and one score,
  and with shared enemies on, each wave monster has one HP bar and one death in both games
  (see [The co-op run](#the-co-op-run)).
- The cut mode's revive in a co-op run, with the experimental `revive` setting on: a dead EVE waits 30 s for her
  partner, who revives her with the interact key, or revives herself a few times a run (see
  [Down and revive](#down-and-revive)).
- The reward shop, on the console, with two cut items the game never sold (see [The reward shop](#the-reward-shop)).
- The recruiter, as a preview: he stands next to Roxanne in Xion's Scrap Market. His lines stay in Korean (see
  [His language](#his-language)).
- Everything runs on a co-op save, a copy of your save, and never on your own saves.

These parts do not exist yet:

- The recruiter's Join choice starting StellarCoop's Steam friends matchmaking. Today the host types
  `coop nightop start`.
- More players, up to six. The Steam link holds two.
- A boss wave.

The Steam link connects two players and shows each player the other's ghost (see [usage.md](usage.md)). The previews
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
each kill logs a `kill` line, no monster appears inside a wall or under the floor, and a success pays points.

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
| `coop nightop shop` | Open the game's own shop screen with the items of the [reward shop](#the-reward-shop), your points shown as Beta Seeds (see [The shop screen](#the-shop-screen-coop-nightop-shop)) |
| `coop nightop buy` | Your points and the seven items, in the console |
| `coop nightop buy <n> [count]` | Buy 1 to 10 of item n with your points (see [Buying from the console](#buying-from-the-console-coop-nightop-buy)) |

### Before your first run

1. Load a co-op save, as in step 1 of [Before you try a preview](#before-you-try-a-preview). For a solo run, leave any
   Steam session (`coop leave`).
2. Back up your saves and keep Steam Cloud off for Stellar Blade (steps 2 and 3 there). Whether the game saves a wave
   monster that is still alive when it saves is not known yet.
3. If you used `coop no rule` in this game run, restart the game: a run does not start while the probe's rule is set.

A run edits no game table, so you can quit from the menu afterwards as usual. The co-op save keeps the session's
progress like any co-op save, and your own saves are not touched.

### Starting a run

Go to open ground outside Xion, with no enemy or other character within 40 m of EVE, and type `coop nightop start`.
On a co-op save you can also pick the level from Roxanne in Xion: see
[Night Operation at Roxanne's](#night-operation-at-roxannes).
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
1.5 m short of the stop. If that leaves it less than 5 m from the start, or if the navmesh has no floor at the point,
the monster goes to the next of the four points, and if none of them holds, to its own point unchecked. The height
follows the floor at the point: on flat ground the monster appears 1 m above the start point, as before, and on a floor
3 m higher it appears 3 m higher. The spawn line in `UE4SS.log` says when a point moved:

```
spawn 0xD82A0100 M_Antlion at 14306,-17676,3280 yaw -40 (ground: moved 6.5 m)
spawn 0xD82A0101 M_Antlion at 15580,-16946,3280 yaw -120 (ground: gate 1 blocked, gate 2)
spawn 0xD82A0102 M_Antlion at 14180,-19370,3280 yaw 60 (ground: gate 3 blocked, no other gate holds: raw spot)
```

A move of less than 1 m adds nothing to the line. The gates are numbered in the order above: 1 and 2 ahead, 3 and 4
behind. If the game's navigation calls are missing or fail, or EVE's start is not on the navmesh, the run places every
monster as it did before the check, and its first spawn line ends with `(ground: unchecked: <reason>)`. In a co-op
run each game checks the points against its own copy of the map, so both should get the same points.

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
own best run (see [Best runs](#best-runs-coop-recordstxt)).

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
(see [Best runs](#best-runs-coop-recordstxt)).

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
`ui_language=english` (see [usage.md](usage.md#options)).

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
  [how-it-works.md](how-it-works.md#channel-0-text)).
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
  (see [usage.md](usage.md#revive-by-your-friend-experimental)). She gets up where she fell with full health and her
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
During a run the [friend's revive](usage.md#revive-by-your-friend-experimental) (3 s next to the downed EVE with no
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

With shared enemies on (the default, see [usage.md](usage.md#shared-enemies-experimental)), each wave monster pairs
with its copy in the other game by its spawn key, like a field enemy: one HP bar, balance gauge and death, decided by
the host's game, with the host's `enemy_hp_scale` and `enemy_balance_scale`. A copy dies in your world only if you took
part in its fight (see [how-it-works.md](how-it-works.md#achievements)). A copy that stays alive in your world for that
reason keeps your wave open until you kill it, it is still out of reach after its two moves (as in the solo run), or
the time runs out.

With same place on (the default), a pair's two copies stand in the same place on both screens: one game runs the
monster's AI and the other draws its copy (see [usage.md](usage.md#same-place-experimental)). The guest's game then
leaves the push towards her EVE and the stuck moves of a monster to same place while all of these hold: her shared
enemies run as the guest, same place draws at least one copy (`pilot=on piloted=1` or more in `coop status`), and the
host's night line lists that monster as found and not yet down, killed, written off or lost in his world. `UE4SS.log`
says so once a monster, for example `[StellarCoop][NR] aggro 0xD82A0200: left to the pilot`. A monster that the host's
game never found keeps the solo run's rules in her world. Once the host's copy is done, her copy gets the stuck moves
back, but the pushes towards her EVE that were skipped are not made again.

Same spawns leave wave monsters out, since none of the game's spawn rows holds their keys. No wave has a boss.

With `shared_enemies=off` on either PC, nothing pairs: each player fights the monsters of their own world, and the
wave starts, the timer and the score are still shared.

## The reward shop

A run of yours that goes from its countdown to a success or a time up gives you points: 1 for each 25 of its final score
at the normal level, times the level's percent at the others (50 % at easy, 150 % at hard, 200 % at nightmare), rounded
down. The score counts up to the highest its level allows, so a run gives at most 20 points at easy, 42 at normal, 83 at
hard and 129 at nightmare. A normal run with a score of about 730 gives 29, a hard one 43. Your game adds them to your
own points and shows `Night Operation: +29 points, 41 in all.` A success where a monster never came (its spawn failed)
or nothing was killed pays for its kills only, without the bonus for the time left. A solo run counts too; a challenge
gives none. A failed or aborted run gives nothing, and a guest whose game missed the countdown gets nothing either. Each
game credits only its own player: no line between the two games carries points. If the points cannot be written, a
notice says so and `UE4SS.log` says why.

The shop sells seven items. `coop nightop shop` opens them in the game's own shop screen (below), and
`coop nightop buy` sells them from the console, the way the shop worked before the screen.

| # | Item | Points (Beta Seeds) | At a camp |
| --- | --- | --- | --- |
| 1 | `HP_Potion` | 15 | 400 gold |
| 2 | `HP_Potion_Small` | 10 | 300 gold |
| 3 | `PulseGrenade` | 6 | 300 gold |
| 4 | `ConcussionGrenade` | 8 | 400 gold |
| 5 | `HP2Burst_Potion` (Burst Stimpack) | 20 | not sold |
| 6 | `Buff_HP2MP` (Beta Stimpack) | 16 | not sold |
| 7 | `Bullet_Shock` (Shock Bolt) | 5 a bolt | not sold |

Items 1 to 4 and their prices come from the cut mode's own shop table, `Shop_NightOperation`. It lists 12 items; these
four are the ones every camp shop sells with no story condition, so a buy here skips no story gate.

Items 5 to 7 are cut items. The game ships their effects, use conditions, icons and English text, but no ItemTable
row, so it cannot hold them. Their prices are the mod's own starting values.

- The Burst Stimpack takes 400 HP and fills the Burst gauge by 600. The game's use conditions refuse it when EVE has
  too little HP or a full Burst gauge.
- The Beta Stimpack takes 20% of EVE's maximum HP and gives 50 Beta energy, refused the same way with too little HP or
  full Beta energy.
- The Shock Bolt is ammo for EVE's gun. A hit stuns a common enemy for 10 s, or until it is hit again, with the game's
  own stun effect, which does nothing to animals, elites or bosses. EVE carries 30 bolts at most; each shot takes one,
  and the next shot waits 1.5 s. The game adds bolts only up to 30 and drops the rest, and the shop cannot read how
  many she holds, so a buy past 30 costs the points of the dropped bolts.

The two stimpacks play the health potion's drinking animation and have a charge count of 2 that no upgrade raises, like
the Heal Grenade. The native part adds the rows of all three through the game's own AddRow, in memory for the game
run: the stimpacks' (two ItemTable rows, the Beta Stimpack's ItemConsumableTable row and the skill both play, which the
game names but never shipped) in the same batch as the [cut Lion's](usage.md#cut-boss-coop-lion) rows, and the Shock
Bolt's (its item, skill, projectile and hit result) in a batch of their own, so a Shock Bolt row the game refuses
leaves the Lion and the stimpacks alone. A buy of item 5, 6 or 7 asks for its rows first. When they are already in, the
buy goes through at once. Otherwise the answer is `OK: Buff_HP2MP x1: its rows are asked of the native part; the buy
follows once they are in`, and the buy's own answer follows within 30 s, as an `OK:` or `STOP:` line of `coop lion`.
Rows that cannot be added buy nothing and take no points: `STOP: Buff_HP2MP cannot be added to the game (...): nothing
bought, no points taken`, with the reason in the parentheses.

For the Shock Bolt the rows are not enough: EVE's two gun stances list only its failed shot, and the game's ammo list
stops at five types. Right after the Shock Bolt's rows go in, the native part adds the two fire commands the game
ships to both stances and `Bullet_Shock` as a sixth ammo type, in place (see [usage.md](usage.md#cut-ammo-shock-bolt)).
Only the shop does this, through a Shock Bolt buy or `coop nightop shop`: a stimpack buy, `coop lion` and
`coop chainspin` leave the gun as the game ships it. A buy of item 7 goes through only when `coop-status.txt` then
reads `shock=in`. Otherwise it stops with
`STOP: Bullet_Shock cannot be fired in this game (shock=...): nothing bought, no points taken`, and the shop screen
leaves the Shock Bolt out.

The rows of these items went in during the 2026-10-27 game run and the shop screen opened, but no item has been
bought, used or fired in game yet. Check that the items show with their names and icons, that using a stimpack
plays the animation and changes HP and the gauge, that the Shock Bolt shows in the ammo selector, fires and stuns, and
what happens to a cut item left in the inventory when the game saves: after a restart the rows are not in until the next
buy of that item or the next `coop nightop shop` (or `coop lion rows` for the stimpacks), and how the game loads an
item it has no row for is not known. Use them up or
keep a backup of the co-op save. If the Shock Bolt is selected, switch to another ammo before you save or quit from the
menu; the game's autosaves at a camp or a zone change keep the selected slot too.

### The shop screen (`coop nightop shop`)

`coop nightop shop` opens the game's own shop screen, the one its vending machines use, with the items of the table
above. It shows each item's icon, price, Available and Stored counts, and its Purchase button buys through the game's
own purchase. While the screen is open your points are Beta Seeds, the cut mode's currency: the top of the screen
shows how many you hold, every price is in Beta Seeds (one seed for one point), and a purchase takes them out of the
inventory. The screen also caps a purchase as the game's vending machines do: at most what your seeds pay for, what
the item's carry limit leaves (30 Shock Bolts) and 99.

What the command does, in order:

1. It checks the co-op save, your Steam ID, that no run is on and that the game plays (no pause, no menu screen).
2. It asks the native part for three rows batches at once, through `coop lion`'s flow (their `[LI]` lines start with
   `lion`, `bolt` and `shop`): the stimpacks' (the lion rows batch), the Shock Bolt's (which also grows EVE's gun
   lists, as a Shock Bolt buy does) and the shop's own 6 rows. The shop's go last because they have not been added in
   game yet: a fault in the game's AddRow stops every batch that is not in yet until the game restarts, and a batch
   already in stays usable. The shop's rows and the stimpacks' have to go in, since both shops list the stimpacks.
   Without the Shock Bolt's, the screen leaves the Shock Bolt out.
3. It reads EVE again and stops if her map changed while the rows were asked. Then it puts as many Beta Seeds in the
   inventory as your wallet holds (seeds left over from a crash are taken out first), waits until the native part
   counts them, and asks it to open the screen. The Shock Bolt is on sale only when its rows are in and
   `coop-status.txt` reads `shock=in`. Until the screen opens, each step first checks that the co-op save the wallet
   belongs to is still the one loaded.
4. While the screen is open, each change of the seed count is written to your wallet at once.
5. When you close the screen, the wallet keeps what is left and the seeds leave the inventory.

Beta Seeds are in the inventory from step 3 until they leave after the close. A save made in that time, an autosave
included, holds them. So does a save made after a removal that failed: the log then says that the next
`coop nightop shop` takes them, and that screen sets the count back to the wallet. A game restarted from such a save
loads Beta Seeds before the shop's rows are in, and how the game loads an item it has no row for is not known (as for
the cut items above), so keep a backup of the co-op save. Each step logs a `[StellarCoop][NR]` line in `UE4SS.log`:

```
[StellarCoop][NR] shop: 41 points; its rows asked
[StellarCoop][NR] shop: rows in (Shock Bolt in)
[StellarCoop][NR] shop: wallet 41, the bucket held 0 Beta Seeds: +41
[StellarCoop][NR] shop: SB's shop screen open with 41 Beta Seeds, the Shock Bolt sold
[StellarCoop][NR] shop: 26 Beta Seeds, wallet written
[StellarCoop][NR] shop: closed: 26 Beta Seeds back in the wallet; 26 Beta Seeds left the inventory
```

The command answers at once with
`OK: Night Operation shop: 41 points as Beta Seeds; SB's shop screen opens once its rows are in ([NR] lines)`. It
answers with one `STOP:` line and opens nothing when the save is not a co-op save, the Steam link has no Steam ID yet,
a run is on, the game is paused or shows one of its screens, the screen is already open, `coop-status.txt` has no
`nightshop` line (an older DLL) or reads a fault there, or the wallet holds more than 999999 points.

Once the seeds are counted, a pause or one of the game's screens (the pause menu that Escape opens when it closes the
console, for example) holds the open: it goes on when the game plays again, for up to 30 s.

If a later step fails (the shop's or the stimpacks' rows refused, EVE's map changed while they were asked, the seeds
not counted within 5 s, the game still paused or on one of its screens 30 s after they are, the game not opening the
screen),
the seeds leave the inventory, the wallet stays as it was, the log has a `STOP: shop:` line with the reason, and a
notice says `The Night Operation shop could not open. UE4SS.log says why.` A shop screen the game already had open
stays open. When another save was loaded before the open (or a load still reads no save), the mod stops in the same
way but adds no seeds, asks no open and removes nothing: seeds it already added stay with the co-op save, and the next
`coop nightop shop` there takes them. After a fault in the native part's shop calls, the mod can no longer read or close the screen: the seeds it
counted last leave the inventory, so a screen left open sells nothing more, and you close it yourself. A fault while
the game sets the new screen up leaves that screen open without its goods in the same way. While the screen runs, no
run starts, a guest turns down the host's run, and `coop nightop buy` refuses. `coop off` closes it first, writes the
last seed count to the wallet and takes the seeds out (before the screen opened, the seeds the mod added); a purchase
made in the last 250 ms before `coop off` is not counted. In the 250 ms or so between the open request and its answer,
`coop off` closes whatever shop screen is up, a vending machine's included. After a Lua reload while the screen is
open, the mod takes it over at its first tick, so purchases still reach the wallet and the seeds leave after the close.
Seeds still in the inventory with no shop screen open leave at that first tick, and the wallet keeps its count.

The rows are a sixth rows batch of the native part, `shop` (`native/src/lion/rows.h`), added through the game's own
AddRow in memory for the game run, as the Lion's are:

| Table | Row | ID | Copy of |
| --- | --- | --- | --- |
| ItemTable | `Money_NightOperation` (Beta Seed) | 9011 | `FishingPoint`, Clyde's currency |
| ShopItemTable | `NightOperation_HP2Burst_Potion_Buy`, 20 seeds | 3571 | `NightOperation_HP_Potion_Buy` |
| ShopItemTable | `NightOperation_Buff_HP2MP_Buy`, 16 seeds | 3572 | `NightOperation_HP_Potion_Buy` |
| ShopItemTable | `NightOperation_Bullet_Shock_Buy`, 5 seeds | 3573 | `NightOperation_Bullet_Scatter_Buy` |
| ShopTable | `Shop_NightOperation_Coop` | 1061 | `Shop_NightOperation` |
| ShopTable | `Shop_NightOperation_CoopBolt` | 1062 | `Shop_NightOperation` |

The Beta Seed keeps the name, function and lore text the game ships for it ("Beta Seed", "Used for trading with
Roxanne") and uses BetaCore's icon, since no seed icon ships. The two shops have the Beta Seed as their currency and no
shop tag; the first lists items 1 to 6 (the shipped rows of items 1 to 4 and the two new stimpack rows), the second the
same and the Shock Bolt. No shipped row changes. A purchase takes Beta Seeds, which none of the game's achievement
rows names, in a shop with no tag. The gold-spending trophy needs gold spent in a shop tagged `AllShop`, so a purchase
here cannot move it.

Check in game: the screen opens with the seed count at the top and the items with their icons and prices; a purchase
takes the seeds, adds the item and writes the wallet; the screen stops the Shock Bolt at 30; the seeds are gone from
the inventory after the close; whether the screen takes the game's input and keeps EVE still with no vending machine
behind it; a save made while it is open and loaded again gives the same count.

### Buying from the console (`coop nightop buy`)

`coop nightop buy` with no number lists your points and the seven items:

```
OK: Night Operation shop, 41 points: 1 HP_Potion 15, 2 HP_Potion_Small 10, 3 PulseGrenade 6, 4 ConcussionGrenade 8, 5 HP2Burst_Potion 20, 6 Buff_HP2MP 16, 7 Bullet_Shock 5. coop nightop buy <n> [count] buys up to 10.
```

`coop nightop buy <n> [count]` buys 1 to 10 of item n, 1 when the count is left out. The answer reads
`OK: bought 2 HP_Potion for 30 points; 11 left`. The game's own request for adding an item puts it in the inventory
of the co-op save, with the game's pickup message. The buy takes no points and answers with one `STOP:` line when:

- the save is not a co-op save, or the Steam link has not given the mod your Steam ID yet;
- the item number or the count is not a whole number in range, or a word follows them;
- a run is on, or the shop screen is open;
- the game is paused or shows one of its screens;
- EVE or the player controller is not in the world, or EVE's GUID reads 0;
- you have too few points, for example `STOP: HP_Potion x1 needs 15 points; you have 11`;
- for items 5 and 6, their rows cannot be added, or `coop lion` is busy with another command;
- the game's request raises an error.

The points go once the game's request has returned. If the game turns the item down without an error, the points
are gone all the same, so check the inventory after a buy. The first potion or grenade a save gets can open the game's
guide for it, as a buy at a camp does. In the game's tables, none of items 1 to 4 feeds a Steam achievement.

Your points are kept per Steam ID and co-op slot, in `coop-night-<steamid>-<index>.txt` in the mod folder, one line
with the number. The game never reads that file, so restoring a save backup does not give points back or take them
away. `coop off` leaves the file as it is, an install never removes it, and `tools/install.py --uninstall` backs it up
with the mod's other files. While the file cannot be opened (another program holds it, or access is denied), a run's
points are not credited and `coop nightop shop` and `buy` refuse with `wallet not read:`, so the total in the file stays
as it is.

## Night Operation at Roxanne's

On a co-op save, Roxanne in Xion's Scrap Market offers Night Operation in her dialogue. Talk to her as usual: above
her Shop and End Conversation choices, the list shows Night Operation (Easy), Night Operation (Normal), Night Operation
(Hard) and Night Operation supplies, in the game's language. The game ships no such dialogue. Her graph's one dormant
Night Operation branch only greets a customer who paid her in Beta Seeds, and nothing reaches it. So the mod lends her
four of the game's test choice rows, which no story dialogue lists.

- A level: she says one of her goodbyes and the run is booked, with the notice
  `Night Operation starts once you leave Xion and no one is within 40 m.` A run never starts in Xion, so it starts on
  its own once EVE is out of Xion, the game plays and no one is within 40 m, as `coop nightop start <level>` would
  (the mod tries every 5 s, through that command's own checks). `coop nightop stop` drops the booking. In a Steam
  session only the host's pick books a run; a guest's pick shows `In a co-op session, only the host starts Night
  Operation.` The host's start asks the guest to join, and the booking holds until the guest's answer. When the guest
  cannot join (another map, more than 50 m away, a game screen up), the host gets a notice with the reason and the
  mod asks again 30 s later, until the run counts down or `coop nightop stop` drops the booking.
- Night Operation supplies: she says goodbye, and 5 s later the shop screen opens, as with `coop nightop shop`.
- Shop and End Conversation work as before, and the cancel input still ends the talk.

Nightmare is not in her list: the choice box has six slots, and her own two choices take two of them.
`coop nightop start nightmare` starts it.

Once EVE is in Xion on a co-op save, the mod reads the game's language, edits the rows in place (each checked first,
then read back: InteractionGraphExec `Success2`, the one her End Conversation uses, NextTaskTagName `None`, and
DisplayText the label in that language, or in English for a language the game does not ship), then asks the native part
to point her choice list in the game's select cache at the four rows and her two (`roxanne on`). The labels take the
game's language each time the rows are armed: at the next Lua load (game start or Ctrl+R), or when her choices come back
after `coop off` or after a save that is not a co-op save. Going to the title and loading a co-op save keeps the labels.
A pick is read from the game's choice boxes, looked for every 250 ms so a box the game builds for a later talk is read
too: a selected line turning from none to one, and that line's text matched against the labels. Everything goes back on
`coop off` and on a save that is not a co-op save: the choice list first (asked again every 10 s until the native part
has put it back), then the rows' shipped values. Until the list is back, and after a fault in its calls, the rows keep
the goodbye, which ends the talk on any save. A map load, leaving Xion included, reads no save for a while: a booking
and her choices hold through it. The supplies' shop screen waits up to 30 s for the game to play (while it is paused or
loading), then the pick goes. The title screen and another co-op save drop the booking and the supplies pick. Nothing is
saved, and a game restart undoes it too. Talking to her still runs her own graph, so her first meeting and her side
quest start as without the mod. No quest, item, achievement or save call is added.

`UE4SS.log` has `[StellarCoop][NR]` lines for each step, for example:

```
[StellarCoop][NR] roxanne text: game language fr-FR -> fr; the 4 rows get its labels
[StellarCoop][NR] roxanne: 4 rows read back as ours; asked the native part: roxanne on
[StellarCoop][NR] roxanne: hard booked: it starts once EVE is out of Xion with no one within 40 m
[StellarCoop][NR] roxanne: the booked hard run waits: census: 1 living within 40 m (nearest 23.4 m); 0 wave bodies: go where no one is within 40 m
[StellarCoop][NR] roxanne: the booked hard run: Night Operation (hard) starts in 5 s (run 0x2A)
[StellarCoop][NR] roxanne off (coop off): asked the native part: roxanne off; the 4 rows go back once her list reads off
[StellarCoop][NR] roxanne: her two choices back, the 4 rows shipped
```

A step that fails logs a `STOP: roxanne` line and leaves her two choices as the game ships them until the next Lua load
(the rows it wrote are put back, also when a label does not read back, and nothing is asked of the native part). After
a Ctrl+R while her list still holds the six choices, a step that fails leaves the rows as they are instead, since they
only play her goodbye; `coop off` or a save that is not a co-op save puts them back.
`coop-status.txt`'s `roxanne=` line is described in
[usage.md](usage.md#night-operations-shop-screen-and-roxannes-choices).

Check in game: the six choices in this order, End Conversation last, the four labels in the game's language; each level
books its run and the run starts out of Xion; the supplies open the shop screen after her goodbye; Shop and End
Conversation as before; `coop off` gives her two choices back.

## Challenges (`coop challenge`)

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
[Starting a run](#starting-a-run)). The Steam session line names the challenge:
`STOP: Target Practice is solo for now: leave the Steam session first (coop leave)`. The Shooting Range has no such
line: in a session it starts for both players (see [The Shooting Range for two](#the-shooting-range-for-two)). One run
exists at a time, so a start while a challenge or Night Operation is on gets
`STOP: a run is on: coop challenge stop ends it`. A word that is neither a challenge's name nor its number gets
`STOP: unknown challenge: coop challenge lists them`. On a save that is not a co-op save, every form except
`coop challenge stop` gets the co-op save line (see [usage.md](usage.md#night-operation-previews)).

A start answers `OK: Target Practice starts in 5 s (run 0x2A)`, and its `start:` line in `UE4SS.log` names the
challenge after the map (`... map <map> challenge targets; census: ...`).

### The challenges

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
waves](#the-waves)). The full heal is the solo run's too.

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

Each wave draws its own order of the spots, so the dummies stand in other places each round. Each spot goes through the
solo run's ground check (see [The waves](#the-waves)): a blocked spot comes back towards the start point, or the dummy
goes to the next spot (`(ground: spot 3 blocked, spot 4)`). A dummy appears as high above the floor at its spot as a
monster does, and faces the start point. The mod neither sends it at EVE nor gives it an AI controller. How the
dummies look, whether they stand still and how many shots each one takes are not known yet.

Start Target Practice on flat open ground, with nothing in the way for 32 m ahead of EVE. When the ground check cannot
run (`(ground: unchecked: ...)` in the log), a spot on a slope can lie inside the ground or above it. A dummy more than
10 m below both the start point and EVE, or more than 40 m from both, is written off where it is at its first check
(2.5 s after it is found, then every 3 s). It is never moved, its wave stops waiting for it, and shooting it later still
scores. Dummies left after a run stay in the world, as monsters do (see [Score and the end of a
run](#score-and-the-end-of-a-run)).

### Shooting Range

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

### The Shooting Range for two

With a partner linked, the host types `coop challenge range` (or `coop challenge 5`). The run then starts, plays and
ends as a co-op Night Operation run does (see [The co-op run](#the-co-op-run)). The dummies are wave monsters there
too: with shared enemies on, the two copies of a dummy pair as [Shared waves](#shared-waves) says. The differences:

- His night line carries `range` in place of a level. Her `join:` line in `UE4SS.log` names it
  (`... challenge range; census: ...`), and her notice reads `Shooting Range: <host> started the challenge. It begins
  in 5 s.`
- `coop challenge range` on the guest's side answers `STOP: the host starts a co-op run`.
- There is no heal. A co-op run gives no shop points and keeps no best on either PC. Each result panel's Best row
  shows the best already kept on that player's own PC.
- A death is a down as in a co-op Night Operation run (see [Down and revive](#down-and-revive)), but the range gives
  no self revive: `coop nightop revive` answers `STOP: no self revive left in this run`, and only the partner's hold
  gets a downed EVE up.

### Score

Each kill scores by the monster's rank, as in the solo run: 10 for `M_Antlion`, 20 for `M_SkullGunnerAlone` and
`M_LurkerA`, 40 for `M_SkullSwordAlone`, `M_SkullSpearAlone`, `M_HedgeBoarA` and each dummy, and 60 for
`M_SkullHammerAlone`. A success adds a time bonus: 1 point for each whole second left, or in Target Practice and the
Shooting Range 10 points per second left, counted to the tenth of a second. A Target Practice run that shoots all 18
dummies with 53 s left scores 720 for the kills and 530 for the time, 1250 in all. A Shooting Range run that downs all
12 dummies with 89 s left scores 480 and 890, 1370 in all.

A challenge ends in the solo run's four ways (see [Score and the end of a run](#score-and-the-end-of-a-run)): success
once every monster of its last wave is down, time up at its time limit, failed when EVE dies, and aborted, which
includes `coop challenge stop`.

### The card and the result panel

The card shows the challenge's name in place of `NIGHT OPERATION`. The result panel is the solo run's (see
[What you see](#what-you-see)), with a fifth row, Best: the best run kept for this challenge as score and time, for
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

### Best runs (`coop-records.txt`)

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

### What a challenge touches

A challenge spawns only the solo run's monster rows and the three dummy rows, through the same game request and with
wave keys in the same range, `0xD8000000` to `0xD8FFFFFF`. Like the solo run, it adds or edits no table row, starts no
rule, writes no save, and fires no zone event other than the full heal. It gives no item or reward. Its kills count
toward nothing but the game's general kill achievements, as the solo run's do (see
[What a run touches](#what-a-run-touches)). The only file a challenge writes is `coop-records.txt`. The Shooting Range
also puts one widget on screen, the cut `WB_ShootingTrainingTest`.

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
  through the Steam client the game already runs (see [how-it-works.md](how-it-works.md#the-steam-link)).
