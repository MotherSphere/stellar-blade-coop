# Night Operation

Night Operation is a multiplayer wave-survival mode that Shift Up prototyped and cut before Stellar Blade's release.
Much of it is still in the game files. StellarCoop has a run of its waves, `coop nightop`, which you play alone or with
a linked partner, a shop that sells six items (two of them cut items) for the points runs earn, and four solo
challenges on the same code, `coop challenge`. Two research previews test other parts of the cut mode; they are not
playable modes. The run, the shop and the challenges have not been tested in game yet.

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

The plan is to bring Night Operation back as a mode you play with friends over Steam, without Shift Up's servers. These
parts exist:

- The run, alone or for two linked players. Both games get the same waves, both screens show one timer and one score,
  and with shared enemies on, each wave monster has one HP bar and one death in both games
  (see [The co-op run](#the-co-op-run)).
- The reward shop, on the console, with two cut items the game never sold (see [The reward shop](#the-reward-shop)).
- The recruiter, as a preview: he stands next to Roxanne in Xion's Scrap Market, and his lines show in any of the
  game's 23 languages.
- Everything runs on a co-op save, a copy of your save, and never on your own saves.

These parts do not exist yet:

- The recruiter's Join choice starting StellarCoop's Steam friends matchmaking. Today the host types
  `coop nightop start`.
- More players, up to six. The Steam link holds two.
- A boss wave, and a revive for a fallen partner during a run.

The Steam link connects two players and shows each player the other's ghost (see [usage.md](usage.md)). The previews
test how the cut mode's parts behave.

## The solo run (`coop nightop`)

`coop nightop start` sends five timed waves of the game's monsters at EVE where she stands, with an 8-minute timer and
a score. It runs on a co-op save. With no Steam session it is a solo run, described in this section; with a partner
linked, see [The co-op run](#the-co-op-run). It has not been tested in game yet. Each step is logged in `UE4SS.log` as
`[StellarCoop][NR]` lines.

The run keeps its own timer in the mod. It adds no row to the game's rule table and starts none of the cut mode's
rules, so a death goes through the game's usual death screen and respawn. Parts of the run adapt code from Survival
Protocol, with its author's permission (see [Credits](../README.md#credits)).

| Command | What it does |
| --- | --- |
| `coop nightop start` | Start a run where EVE stands |
| `coop nightop start noaggro` | The same, but the monsters are not sent at EVE (a test switch) |
| `coop nightop start nomove` | The same, but stuck or fallen monsters are not moved (a test switch) |
| `coop nightop stop` | End the run that is on, Night Operation or a challenge, on any save. `coop off` ends it too |
| `coop nightop` | The run's wave, run time, score and kills while a run is on, then the census: how many living characters stand within 40 m of EVE, and the wave monsters still in the world that show a wave key, each with its run number (8 at most are named). The game shows a monster's wave key only in a networked game, so this list is empty in practice |
| `coop nightop shop` | Your points and the six items of the [reward shop](#the-reward-shop) |
| `coop nightop buy <n> [count]` | Buy 1 to 10 of item n with your points |

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
The answer is `OK: Night Operation starts in 5 s (run 0x2A)`, where `0x2A` is the run's number. The command refuses
with one `STOP:` line, and changes nothing, when:

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

The game does not keep a monster's wave key where the mod can read it (it copies the key to the character only in a
networked game), so the mod finds each monster by where it stands. Just before a wave's first spawn, it lists the
characters in the world and where each one stands. 1 s and 2.5 s after the wave's last spawn, it lists them again. A
character that is alive and shown, is not EVE, is not one of the run's monsters already, and is not standing within
50 m of where it stood before the wave counts as new, and becomes the monster of the nearest point of that wave within
5 m. A field enemy that walked onto a point before the wave is never taken. The game reuses its characters, sometimes
from far away, which is why the 50 m rule exists. A monster not found 2.5 s after its wave's last spawn is logged as
`missing`, with the distance of the nearest new character left over (`missing 0xD82A0103 M_Antlion (nearest new body
6.2 m)`, or `no new body`), and its wave does not wait for it.

The mod then sends each new monster at EVE. 0.6 s after the monster is found, the mod reports a 0.01 damage event and
a noise from EVE, puts the monster in battle state, and gives it EVE as focus and a move towards her; if it is still
not fighting 4 s later, the mod does this again. A monster with no AI controller gets its default one first.

From 2.5 s after it is found, and then every 3 s, a monster more than 10 m below both the start point and EVE, or more
than 40 m from both, is moved to 7 m from EVE. This happens at most twice per monster. A monster still out after that
no longer holds up its wave, and killing it later still scores.

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
run fires. A run adds or edits no table row, starts no rule, writes no save, and never hides or removes a monster. No
word typed after `start` reaches a game call: `noaggro` and `nomove` only turn off the mod's own steps.

Each kill most likely counts toward the game's general kill achievements, as any kill does: the ones for 10 and 1500
kills and the ones for kills with each kind of skill. A run can unlock one of them if your save is close to its count.
Restoring a backup does not take an unlocked achievement back.

## The co-op run

With a partner linked over the Steam link, the host starts the run for both players. Each game spawns the same waves
at the same points around the host's start point, and both cards show one timer and one score. The waves, the score
for each kill, the heals and the 8-minute limit are those of the solo run. The Steam link holds two players, so a run
has two at most, each on a co-op save.

### Starting a run together

Both players stand together on open ground outside Xion. The host types `coop nightop start`. His game makes the
checks of [Starting a run](#starting-a-run) on his side and answers
`OK: Night Operation: waiting for <partner> to join (run 0x2A)`, and his card reads `WAITING FOR PARTNER`. On the
guest's game the same command answers `STOP: the host starts a co-op run`.

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

### How a co-op run ends

The run ends on both screens, each with its result panel. The line under the heading says who ended the run:

| What ended the run | Host's line | Guest's line |
| --- | --- | --- |
| Success | none | none |
| Time up | `Time is up.` | `Time is up.` |
| The host's EVE died | `Your EVE died.` | `Your partner's EVE died.` |
| The guest's EVE died | `Your partner's EVE died.` | `Your EVE died.` |
| On the host's side: `coop nightop stop`, a map change or a load, 80 m from the start point for 10 s, a save that is no longer a co-op save, or an error | His reason, as in the solo run | `Your partner left the run.` |
| The same on the guest's side | `Your partner left the run.` | Her reason, as in the solo run |
| The session ended: `coop leave` (F8) or `coop off` on either side | `The link to your partner was lost.` | `The link to your partner was lost.` |

A player who types `coop off` ends their own run as a stop (`result: aborted (coop off)` in `UE4SS.log`); only the
partner reads the lost line. A game's night line stops while that game does not tick, for example during a load. Once it
has not reached the other game for 5 s, the other player's run ends with `The link to your partner was lost.` The player
whose game stalled reads their own reason if their game found one first (`Ended by a map change or a load.` after a
load), else the same lost line.

A death on either side ends both runs as failed: there is no revive. The game's own `All players have died.` line is
not used, since only one EVE died. A host who stops while he still waits for the guest's answer drops the run with no
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

A run of yours that goes from its countdown to a success or a time up gives you points: 1 for each 25 of its final
score, at most 42 a run. A full run with a score of about 730 gives 29. Your game adds them to your own points and shows
`Night Operation: +29 points, 41 in all.` A success where a monster never came (its spawn failed) or nothing was killed
pays for its kills only, without the bonus for the time left. A solo run counts too; a challenge gives none. A failed or
aborted run gives nothing, and a guest whose game missed the countdown gets nothing either. Each game credits only its
own player: no line between the two games carries points. If the points cannot be written, a notice says so and
`UE4SS.log` says why.

`coop nightop shop` lists your points and the six items:

```
OK: Night Operation shop, 41 points: 1 HP_Potion 15, 2 HP_Potion_Small 10, 3 PulseGrenade 6, 4 ConcussionGrenade 8, 5 HP2Burst_Potion 20, 6 Buff_HP2MP 16. coop nightop buy <n> [count] buys up to 10.
```

| # | Item | Points | At a camp |
| --- | --- | --- | --- |
| 1 | `HP_Potion` | 15 | 400 gold |
| 2 | `HP_Potion_Small` | 10 | 300 gold |
| 3 | `PulseGrenade` | 6 | 300 gold |
| 4 | `ConcussionGrenade` | 8 | 400 gold |
| 5 | `HP2Burst_Potion` (Burst Stimpack) | 20 | not sold |
| 6 | `Buff_HP2MP` (Beta Stimpack) | 16 | not sold |

Items 1 to 4 and their prices come from the cut mode's own shop table, `Shop_NightOperation`. It lists 12 items; these
four are the ones every camp shop sells with no story condition, so a buy here skips no story gate.

Items 5 and 6 are cut items. The game ships their effects, use conditions, icons and English text, but no ItemTable
row, so it cannot hold them. Their prices are the mod's own starting values.

- The Burst Stimpack takes 400 HP and fills the Burst gauge by 600. The game's use conditions refuse it when EVE has
  too little HP or a full Burst gauge.
- The Beta Stimpack takes 20% of EVE's maximum HP and gives 50 Beta energy, refused the same way with too little HP or
  full Beta energy.

Both play the health potion's drinking animation and have a charge count of 2 that no upgrade raises, like the Heal
Grenade. The native part adds their rows (two ItemTable rows, the Beta Stimpack's ItemConsumableTable row and the skill
both play, which the game names but never shipped) in the same batch as the [cut Lion's](usage.md#cut-boss-coop-lion)
rows, through the game's own AddRow, in memory for the game run. A buy of item 5 or 6 asks for those rows first. When
they are already in, the buy goes through at once. Otherwise the answer is `OK: Buff_HP2MP x1: its rows are asked of the
native part; the buy follows once they are in`, and the buy's own answer follows within 30 s, as an `OK:` or `STOP:`
line of `coop lion`. Rows that cannot be added buy nothing and take no points: `STOP: Buff_HP2MP cannot be added to the
game (...): nothing bought, no points taken`, with the reason in the parentheses.

None of this has been tried in game yet. Check that the items show with their names and icons, that using one plays
the animation and changes HP and the gauge, and what happens to a stimpack left in the inventory when the game saves:
after a restart the rows are not in until the next buy of a cut item (or `coop lion rows`), and how the game loads an
item it has no row for is not known. Use them up or keep a backup of the co-op save.

The cut Shock Bolt ammo is not sold. The game has its bullet and consumable rows, but EVE's two gun stances list only
its failed-shot command (`P_Eve_Gun_ShootShockSlugFail1_1`), so adding the item and its missing skill row would still
not let her fire it. That would mean replacing stance rows EVE is using, and AddRow frees the old row as it replaces it.

`coop nightop buy <n> [count]` buys 1 to 10 of item n, 1 when the count is left out. The answer reads
`OK: bought 2 HP_Potion for 30 points; 11 left`. The game's own request for adding an item puts it in the inventory
of the co-op save, with the game's pickup message. The buy takes no points and answers with one `STOP:` line when:

- the save is not a co-op save, or the Steam link has not given the mod your Steam ID yet;
- the item number or the count is not a whole number in range, or a word follows them;
- a run is on;
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

## Challenges (`coop challenge`)

A challenge is a short solo fight picked from a fixed list. Three of them send waves of the game's monsters at EVE, as
the solo run does, and Target Practice stands the game's target dummies in front of her. Each run ends on the result
panel with the time, the score and the best run kept on this PC. The challenges run on the solo run's code, on a co-op
save with no Steam session, and log `[StellarCoop][NR]` lines. They give no shop points. They have not been tested in
game yet.

| Command | What it does |
| --- | --- |
| `coop challenge` | List the challenges and Night Operation with each one's best run, then the run that is on, if any |
| `coop challenge <name>` | Start that challenge where EVE stands. Its number in the list works too: `coop challenge 4` is `coop challenge targets` |
| `coop challenge stop` | End the run that is on, a challenge or Night Operation, on any save. `coop nightop stop` and `coop off` end a challenge too |

With no best kept yet, the list reads:

```
OK: 1 swarm Antlion Swarm: 3 waves, 3:00, no best yet
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
Operation's waves, a challenge's waves have no set run time, so a slow clear holds the next wave back until the time
limit. As in the solo run, a wave is down once each of its monsters is dying, can be executed, is written off, is
missing or is no longer tracked.

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
stops waiting for it, and shooting it later still scores. Dummies left after a run stay in the world, as monsters do
(see [Score and the end of a run](#score-and-the-end-of-a-run)).

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
`best_<name>=<score> <seconds>`. Night Operation's line is `best_night`. After a first Target Practice best, the file
reads:

```
# StellarCoop: your best challenge runs on this PC (score and seconds).
best_targets=1250 37
```

A run reads its best when it starts, for the Best row. The file is written only when a run ends in success and beats the
stored best, if there is one: a higher score, or the same score in less time. Failed, time up and aborted runs never
write it. A success keeps no best when a monster never came (its spawn failed), when nothing was killed, when `coop
nightop start` ran with `noaggro` or `nomove`, or in a co-op Night Operation run. The log says why in a `record: not
kept (...)` line.

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
