# Shared enemies and bosses

Shared enemies and every option that builds on them are experimental. Their settings are in
[coop-settings.txt](settings.md#coop-settingstxt), problems in
[troubleshooting.md](troubleshooting.md#shared-enemies-and-group-play), and how each part works in
[internals/shared-enemies.md](internals/shared-enemies.md).

## Shared enemies (experimental)

`coop fight` is the first stage of shared enemies. It has not been tested in game yet. With a friend linked, each
enemy that both games spawned at the same spawn point, with the same character id and maximum HP, shares one HP bar,
balance gauge and death, decided by the host. Each player who took part in its fight gets the kill and the loot in
their own game (`kill_credit` below). Each screen's enemy still fights only its own EVE, and positions are not shared
unless [same place](#same-place-experimental) is on.
It changes enemy stats through the game's own code, so it shares enemies only on a co-op save, and kills count in the
co-op save. Back up your saves first (see [saves.md](saves.md)). When an enemy becomes shared, or shared again after a
death, a load or photo mode, the guest's copy takes the host's HP without a damage number; later drops from the host's
hits show one.

### Knockdowns and kills

When a hit knocks a shared enemy down (face up or face down), launches it or slams it into a wall on one screen, the
other game starts the same effect on its copy, as if its own EVE had landed that hit. A copy that is already down, in
the air or groggy finishes that first and skips it, and a copy the game holds immune to it stays up. Groggy needs
nothing of this: each copy goes groggy when the shared balance gauge empties.

When you are the guest and your hit kills a shared enemy, `guest_kills=at_once` (the default) kills it on your screen
at once. If the host's copy had more HP left (more than 10 % of the enemy's maximum HP above what yours had), the
host's game refuses that kill: the enemy lives on in the host's game and stays dead in yours, and `coop-link.log` says
`desync guest-dead`. With `guest_kills=confirmed`, your copies keep at least 1 HP until the host's game kills its own,
so the enemy dies on your screen about one ping later, and a refused kill leaves it alive at the host's HP. Only the
guest's setting counts. The mod holds that 1 HP through the game's MinimumHP stat and sets the stat back when the
enemy dies or stops being shared, and when shared enemies stop. After a fault inside the game's own code it leaves the
stat as it is: the fault's line in `coop-link.log` then says how many of these changes stay until their enemies leave
the map.

A kill decided in the other game waits while your copy of the enemy holds the game's NoDamageNoHit state (it grabs
your EVE, burrows or warps in), because the game never kills an enemy in the middle of a grab. Your copy dies when the
state ends, or after 6 seconds anyway. When the guest's hit is the kill, the host's copy waits at 1 HP.
`coop-link.log` says `fight kill held <key>`, then `fight held-expired <key>` when the 6 seconds ran out.

### Two-player scaling

Shared enemies get more HP and balance, since two players hit them. The host's `enemy_hp_scale` (default `1.35`)
multiplies a shared enemy's maximum HP, and `enemy_balance_scale` (default `1.15`) its balance gauge, each from `1.0`
(no change) to `4.0`. Both games use the host's values for the whole session; the guest's are not used, and the guest's
`coop-link.log` says so once a run when they are not both `1.0`.

An enemy gets them when it becomes shared, and its HP and balance rise in the same proportion, so an enemy at half HP
stays at half. When it stops being shared, or shared enemies stop, it gets its own maximums back and keeps the same
share of HP and balance. On the host's side an enemy gets them once the guest's side is on, and keeps them until it dies
or leaves the 16 shared places, even while the guest pauses. That covers every enemy in the 16 places, also one the
guest's game never links (it is in another part of the map, or its copy does not match), which the host then fights
alone at the higher values.

The mod changes the game's MaxHPValue and MaxStamina stats through the game's own code. An enemy whose maximum HP the
game has changed in another way keeps its own (the stats line of `coop-fight.log` counts it as unscaled). The
`Shared enemies on` notice names the values when they are not both 1.0, for example
`Shared enemies on: 3 enemies linked. Enemy HP 135 %, balance 115 % (the host's setting).`, and the `fight=` line of
`coop status` has `scale=135/115`.

### Kill credit

`kill_credit` is each player's own and decides when you took part in a shared enemy's fight. With `together`, the
default, you took part when your EVE hit it, when it targeted your EVE, or when your EVE stands within 30 m of it as it
dies. With `fought`, the distance does not count, and with either value it does not count while your EVE is down.
Whether it targeted you or your hit landed comes from the game's record of the last player an enemy fought, the record
the game itself uses to credit a kill. An enemy that your own hit kills always gives you the kill.

When the other player kills a shared enemy you took no part in, your copy does not die: it stops being shared and stays
alive in your game, back at full HP, so its kill rewards, drops, quest kills and achievements never reach your save, and
one hit of yours later does not finish what the other player's hits did. A boss copy goes back to full HP the same way.
Whether you can then beat that boss alone before the area reloads has not been tested in game. The guest's
`coop-link.log` then says `fight dead-unshared <key> hguid=<n> not taken part`, the host's says
`fight kill-unshared <key> hguid=<n> not taken part`, and the host's game does not share that enemy again in this
session.

As the guest, while [same spawns](#same-spawns-experimental) run (within 100 m of each other in one zone), the host's
next drop line removes the copy of a common enemy from your game a few seconds later, without a kill, unless you are
fighting it. Damage dealt before an enemy became shared does not count as yours, since the other player may have dealt
it. When a knockdown the other player started, mirrored on your copy, makes the game record your EVE as that enemy's
last player, the log says `fight last player <key> set by a mirrored crowd control` and that record no longer counts for
this enemy: your hit or the 30 m still do. `kill_credit=all` from 0.4.0-beta.1, which gave you every shared kill
wherever you stood, is gone (see [coop-settings.txt](settings.md#coop-settingstxt)).

### Slow motion

Slow motion is not shared: each game slows down on its own, as in solo. With [same place](#same-place-experimental)
on, a shared enemy runs in the game of the player it fights, and the other screen draws it from that game. So when
that player's perfect dodge slows the enemy down, it slows down on both screens, and an enemy that your friend's game
runs keeps its speed on your screen while your own perfect dodge slows your game down. The stats line in
`coop-fight.log` counts slow motion as `slow motion <n> times (<t> turns, lowest <p> %)`: how often your EVE or an
enemy of the shared fight began to run below normal speed, the turns that lasted, and the lowest speed in percent.
How the two screens compare during slow motion has not been tested in game yet.

### Turning it on and off

It is on by default. Options > Combat > Shared enemies (experimental) in the [co-op menu](interface.md#options) shows On, and a
new [coop-settings.txt](settings.md#coop-settingstxt) has `shared_enemies=on`; a file with no `shared_enemies` line counts as on
too. A file from version 0.2 says `shared_enemies=off` and keeps it off until you turn the row on. It starts by itself
once you are linked and both play a [co-op save](playing-with-a-friend.md#co-op-saves), and changes no enemy on your own save. Enemies get
linked only while you are on the same map. Turning the row off (`shared_enemies=off`) stops it at once, but not the
solo test tools below.

### Which enemies are shared

`fight_chars=auto`, the default, shares every common enemy (the game's Monster type). Bosses and Alpha Naytibas (the
game's BossMonster type) are shared only with the host's `bosses=on` ([shared bosses](#shared-bosses-experimental)).
`auto` also leaves out a few Monster-type enemies that are not common
ones: the Gorgon (character id 50330), the two laser turrets with 999,999 HP (35027002 and 35027003), and any enemy
with more than 500,000 maximum HP. The common enemy with the most HP has 213,125, on Hard. A list of character ids
instead, for example `fight_chars=15011001 15011002` (16 at most), shares those enemies only, of any type, including
the ones `auto` leaves out. A file written before `auto` existed has `fight_chars=` with nothing after it, which counts
as `auto`.

The host shares 16 enemies at a time. When all 16 places are taken, an enemy the host hurts takes the place of one at
full HP that the friend never hit. When every place holds an enemy in a fight, `coop-link.log` says
`fight full every place holds an enemy in a fight; a hurt one is not shared`, and the next enemies stay unshared until
one of the 16 dies or leaves.

### Notices

While something keeps it from sharing, one notice says what. It shows again only when that changes, or in the next
session, and 5 seconds after the last one at the soonest:

| What is missing | Notice |
| --- | --- |
| You play your own save | `Shared enemies need a co-op save, not your own. Quit to the title screen, choose Convert and play co-op (or Play co-op), then Continue or load the same slot.` |
| The same, with `auto_coop_save=off` or when the co-op copies cannot be used (`saves=off` or `saves=?`) | `Shared enemies need a co-op save, not your own. With the co-op copies off, only the manual co-op slot counts (see INSTALL.md).` |
| Your friend plays their own save | `Shared enemies wait: <name> plays their own save. They can switch at the title screen with Convert and play co-op (or Play co-op).` |
| Your friend has shared enemies off | `Shared enemies wait: <name> has them off (co-op menu, Options, Combat).` |
| Shared enemies stopped in your friend's game | `Shared enemies stopped for this run in <name>'s game. Their coop-link.log says why.` |
| You are on different maps | `Shared enemies wait until you and <name> are on the same map.` |

Waiting for a friend, a load or the end of photo mode or of a pause shows nothing. `Shared enemies on: <n> enemies
linked.` shows when enemies get linked after none (the host counts none until the friend's side is on).
`Shared enemies off. coop-link.log says why.` shows when it stops after it ran or waited, unless you stopped it yourself
(the row, `coop fight off` or `coop off`). `Shared enemies stopped until the game restarts. coop-link.log says why.`
shows when a check of the game's memory turned it off for the run. These notices use the menu's language.

When your friend's game loads other `.pak` mods than yours, a notice says so once a session. The mod compares the
`.pak`, `.ucas` and `.utoc` files beside the base game's in `SB/Content/Paks` and its folders (`~mods`, `LogicMods`),
by name and size; `coop-link.log` lists yours at its start. With the names of your friend's mods (their `mod_names=on`,
the default), it names those they use and you lack, and those you both have in another version, up to two file names
each, then `(+n)` for the others:

- `Kaanta uses mods you don't have: lily_hair_p, hd-atool_p (+1). Parts of their outfit from them look different here.`
- `Kaanta uses other versions of mods you have: menu_p. Parts of their outfit from them may look different here.`

Without names (their `mod_names=off`), or when only you have mods they lack, it gives the counts instead:
`Kaanta loads other .pak mods than you (1 there, 2 here). Enemies that differ stay unshared.` It is a warning only.
`coop status` lists the three groups in full (`mods_missing=`, `mods_other=`, `mods_extra=`). With `mod_names=off`
in `coop-settings.txt`, your game sends only the count and the hash of your mods, never their names, and your capture
leaves out every path from a mod's own folder (see [Mods and CNS outfits](ghost.md#mods-and-cns-outfits)).

The guest also sees two notices while enemies are shared. `Shared enemies: some enemies have another max HP in <name>'s
game (another difficulty or New Game+). They stay unshared.` shows once, until shared enemies stop or the friend
leaves, when an enemy of the host's cannot be paired because its maximum HP differs (by more than 0.5, before any
scaling). `Shared enemies: <name> is down. Once they respawn, the enemies you share go back to full health.` shows each
time the host goes down while enemies are linked: the host's respawn resets the enemies in the host's game, and your
copies follow them back to full health. A respawn on another map leaves your copies unshared, with the HP they had.

### Commands

- `coop fight on` asks for it by hand (it needs `shared_enemies=on`) and `coop fight off` stops it until the mod reloads
  or the row is turned off and on again. It waits for a linked friend, a loaded save and a co-op save, and pauses while
  either player is in photo mode or has the game paused (the pause menu, a cutscene, the game window in the background).
  Loading your own save pauses it until you load a co-op save again. Setting `shared_enemies=off` in the file and pressing Ctrl+R also stops it (the solo test
  tools below keep running).
- `coop fight status` prints the `fight=` line of `coop status`, for example
  `fight=on mode=on role=host enemies=3 ... her=on`. The guest's line has `unpaired=<n>` (the host's enemies it could
  not pair) and `maxhp=<n>` (those of them with another maximum HP), and the answer then lists up to 8 of them by spawn
  key and reason (`charId`, `maxhp` or `duplicate`), for example
  `; unpaired: 5003:0 charId, 5005:1 maxhp; 3 of ours not on the host's list`. The last count is the guest's own
  enemies that the host's list lacked since the host's last world change. While a friend is linked, `her=` gives
  their side: `on`, `own-save` (their own save), `off` (shared enemies off), `stopped` (stopped for the run),
  `waiting` (a load, photo mode, a paused game, `coop off`, or a reason their `coop-link.log` gives) or `?` (nothing heard from their
  game yet).
- Solo test tools: `coop fight probe` is read only and logs each actor (character id, type, HP, Shield, Stamina) to
  `coop-fight.log`, where you find the ids for `fight_chars`. With no `fight_chars` list, the line of a Monster that
  `auto` leaves out has `left_out=charId` (the Gorgon or a turret) or `left_out=MaxHP` (more than 500,000
  maximum HP). A line adds `states=` when the actor holds one of the game states the mod reads: 3
  (NoDamageNoHit, during a grab), 4 (NoDamage), 6 (Down), 7 (Groggy), 8 (Airborne) or 27 (Immortal). A `cc=` part
  follows when a knockdown or launch effect the mod mirrors runs on it: 9900001 (Airborne), 3000300 (Down), 3000301
  (DownFaceUp), 3000303 (DownFaceDown) or 3000401 (WallHit). Once the log says `fight writes=armed`,
  `coop fight test hp|sh|st <change>` (whole units, never 0) and `coop fight test kill` write to the shared enemy with
  the lowest HP share. `coop fight record` keeps the host's side in `coop-fight-record.txt` until `coop fight off`;
  `coop fight replay` plays that file into the guest's side. Both change enemies (record through the host's scaling,
  when it is above 1.0), so the mod refuses them until the log says `fight writes=armed`.
- The test tools are typed on purpose. `coop fight test kill` kills only an enemy your EVE took part in, as for a
  shared kill (you hit it, it targeted you, or it stands within 30 m of your EVE); its kill rewards and achievements
  then count in your save as if your EVE had killed it. Any other enemy is refused with
  `fight test <key> refused: not taken part`. A `test hp` drop larger than the enemy's HP kills it too, with no killer:
  your game skips its kill rewards, but its drops and the game's other death events still happen, and the kill still
  counts toward the kill achievements when your EVE hit it or it targeted your EVE. A replay kills your copies on the
  recorded deaths with the `kill_credit` rule of a live fight, so with `together` one within 30 m of your EVE dies with
  your EVE as its killer.
- The solo test tools stop on another slot with
  `STOP: coop fight runs only on a co-op save (INSTALL.md: Co-op saves); now <the slot line>`.

## Same place (experimental)

With `same_place=on` in the host's game, each shared enemy stands in the same place on both screens. One game runs the
enemy's AI, so the enemy moves there and attacks that game's EVE. In the other game the copy follows it about 200 ms
late, the same delay as the ghost, and plays its attacks, reactions, sounds and effects with the game's own animation
files. Hits land on either copy and count through shared enemies as before, and HP and death stay with the host's
game.

The host's `aggro` setting decides which game runs an enemy's AI. With `aggro=game`, the default, an enemy goes to the
player who hit it last. After 10 s without a hit, it goes to the other player once that player's EVE has stood at least
3 m nearer to it, and within 30 m of it, for 2 s. An enemy changes hands at most once in 4 s, and never during one of
its attacks, while it is down, groggy, in the air or in a takedown, or while it dies. An enemy the guest's game refuses
or gives back stays with the host's game for 30 s. With `aggro=host`, every enemy stays with the host's game and never
attacks the guest. Same place is on by default and has not been tested in game yet.

A takedown moves the enemy at once. When either player starts a takedown on a groggy enemy, that player's game takes
the enemy for it, without the 4 s wait, and the other game shows the takedown from its stream, on the same timeline as
the ghost. The host's game applies the guest's killing hit only once her takedown ends, or after 6 s. If the host kills
the enemy during her takedown, her game gets that death only then too. An enemy that lives through a takedown stays
with the player who did it for 10 s, or until the other player hits it. With `aggro=host`, the guest's takedown plays
only on her screen, and the host's still shows on hers. The host's game refuses the guest's takedown of a boss or an
Alpha Naytiba, shared through `bosses=on` or named in `fight_chars`. A boss in its Finish stance (GorillaB, Tachy or
SkullJuggernaut at 1 HP, for example) ends only by the host's finisher: her killing hit leaves the host's boss at 1 HP,
and her game takes the finisher's state off her copy. A boss without a Finish stance dies of her killing hit as a
common enemy does, unless its own thresholds or Immortal hold it.

In the game that draws an enemy, the mod puts the game's own BlockAI effect on the copy, takes its movement component
out of the game's movement manager, writes its position every frame from the other game's stream and replays that
game's Shows (the game's animation sequences) on it. A copy that is knocked down, groggy or in the air moves by the
game's own rules until that ends. When an enemy changes hands, the game that takes it removes BlockAI, puts the movement
component back and points the enemy at its own EVE with the game's force target function.
[internals/shared-enemies.md](internals/shared-enemies.md#same-place-enemies) has the details.

- It needs shared enemies running, and only the host's value counts, as with the scaling: Options > Combat > Same
  place (experimental) in the host's co-op menu, or `same_place=on` in its [coop-settings.txt](settings.md#coop-settingstxt).
- `aggro` is the host's too, and counts from the next start of shared enemies: Options > Combat > Enemies attack
  (host's), Both players (`aggro=game`) or The host only (`aggro=host`).
- While shared enemies wait or run, turning the row off stops same place at once on your side (as host, on both
  screens), and turning it on starts it again. Otherwise, as host, the next start of shared enemies takes the row's
  value. As guest, the host's value decides at every start.
- `coop fight pilot off` stops it on your side until the next `coop fight on`. As host, the guest's copies go back
  too. `coop fight pilot on` starts it again (it needs `same_place=on`). `coop fight off`, `shared_enemies=off` and
  `coop off` stop it with shared enemies. As host, a reload (Ctrl+R) with `same_place=off` in coop-settings.txt stops
  it too while shared enemies run or wait. Each copy goes back to the game within a second and fights its own EVE
  again.
- `coop fight pilot status` prints the `pilot=` line of `coop status`: `pilot=on piloted=<n> owned=<n> drawn=<n>`
  (piloted: the enemies this game moves as host, or the copies it moves as guest; owned: the enemies whose AI runs in
  this game; drawn: the copies it draws from the other game), `pilot=off why=<why>`, `pilot=stopped` (an error
  stopped it until the game restarts) or `pilot=refused why=<why>` (another game build, or `coop off`), with
  `probe=on` and `test=<step>` while those run. `why=` is `fight` (shared enemies are not running), `setting` (the
  host's `same_place` is off), `host` (as guest: the host's game has it off) or `asked` (`coop fight pilot off`).
- Notices, in the menu's language: `Same place: <n> enemies piloted.` when enemies start to be moved after none,
  `Same place off: <name>'s game turned it off.` on the guest's screen when the host's game stops it, and
  `Same place off: stopped by an error until the game restarts. coop-link.log says why.` Your own
  `coop fight pilot off` and the row show nothing.
- While it runs, `coop-fight.log` gets a `pilot stats:` line each second (the `pilot=` line, the host's reads of its
  enemies and their cost, the show lines sent, and the bytes both ways with the rate a second, `-` on the first line
  after a pause) and a `pilot drawn:` line when the guest's side changed (copies moved, movement components taken out,
  releases, snaps, drift, Shows replayed, late or missing, those not replayed because the copy already plays them, and
  the game thread's time a frame while it holds copies).
  `coop fight pilot probe` adds each `SBE` message and show line sent and received, until `coop fight pilot off`. The
  `SBE` messages take about 13 KB/s with 16 enemies.
- The drawing game's `coop-link.log` gets a line for each copy released (`pilot released hguid=<n>`), back on the
  stream (`pilot converged hguid=<n>`) or moved in one jump (`pilot snapped hguid=<n>`).
- Each change of hands is logged: on the host, `fight own <key> hguid=<n> to her` or `back`, and
  `fight own-no hguid=<n> <why>` when the guest refuses one or gives one back; on the guest, `fight own <key> hguid=<n>
  taken` and `fight own-no hguid=<n> <why>`. The game that takes an enemy logs `pilot taken hguid=<n> oe=<epoch>:
  target our EVE`, or `pilot take-over refused hguid=<n> oe=<epoch>: <why>` when its force target cannot run: `not
  net mode 0`, `a logic task in flight` or `copy not found` after 250 ms, `a game singleton not made yet`, `no EVE of
  ours` or `no AI on the copy`. The guest then gives the enemy back (`own-no target`). The `pilot stats:` line counts
  these take-overs.
- Takedowns are logged in `coop-link.log`. On the guest: `fight exec <key> hguid=<n> our takedown begins` and `our
  takedown ends` (without the key once the copy is gone). On the host: `fight exec <key> hguid=<n> her takedown begins`,
  `her takedown ended` or `her takedown timed out` (no end within 6 s), `fight exec refused <key> hguid=<n> <why>` (`no
  Groggy or takedown on our copy`, or `one runs already`; one within 2 s of her last one for that enemy is counted with
  no line), `fight kill held <key> hguid=<n> her takedown` and `fight dead held <key> hguid=<n> her takedown` while the
  host waits, and `fight held-expired <key> hguid=<n>` when 6 s passed first. The `fight stats:` lines count `takedowns
  of hers (<n> refused)` on the host and `takedowns told` on the guest.
- After an error in the game's own code, copies the mod already moved can keep their movement component out of the
  manager and stand still until they leave the map or you rest at a camp. The error's line in `coop-link.log` says
  so.

To test it alone, record the host's side once, then play it into the guest's side after a camp
rest:

1. With `same_place=on`: `coop puppet`, then `coop fight probe` until `coop-link.log` says `fight writes=armed`, then
   `coop fight off`.
2. `coop record` and `coop fight record`, fight one enemy (a few hits from different sides and a skill or two), then
   `coop fight off` and `coop record off`.
3. Rest at a camp, so the enemy is back where it started.
4. `coop fight pilot test <step>`, then `coop replay` and `coop fight replay`. Watch the enemy, then `coop fight off`
   and `coop replay off`.

The step says how far the guest's side goes: `freeze` (the BlockAI effect only: the enemy stands and plays its own
animations), `cmc` (its movement component out of the game's manager too, nothing written: the `pilot drawn:` line's
drift says how far the game still moves it), `drive` (its position, speed and velocity from the recording too, no Show
replayed) or `replay` (all of it). It holds until the next `coop fight pilot test` or `coop fight on`.

`coop fight pilot test target` tests the force target alone, during step 2 (as host, every shared enemy runs in your
game). At the next frame it points the first of them at your EVE. `coop-link.log` says
`pilot target test hguid=<n>: forced` or `pilot target test hguid=<n> refused: <why>`, then
`pilot target test hguid=<n> +<ms> ms: target <our EVE|another actor|none>, aggro level <n>, detect result <n>` each
time one of the three changes during the next second.

`coop fight pilot test exec` tests a takedown, during step 4 with `replay`. At the shared fight's next turn it empties
the balance of the first frozen copy, so the copy goes groggy; take it down before that ends. `coop-link.log` says
`fight pilot test exec <key> hguid=<n> balance emptied: take it down`, or why not (`refused: no frozen copy drawn`,
`refused: gone or dying`, `its balance is empty already`). Then come `pilot released hguid=<n>` as the copy goes
groggy, `fight exec <key> hguid=<n> our takedown begins` and `our takedown ends` around the takedown, and
`pilot converged hguid=<n>` (or `pilot snapped hguid=<n>`) once the copy lives on after it.

## Same spawns (experimental)

With `same_spawns=on` in the host's coop-settings.txt, the guest's game holds the same common enemies as the host's
game wherever both players stand within 100 m of each other in one zone. The guest's game creates the enemies it lacks
where the host's stand, and removes the ones the host's game lacks without killing them, so they give no rewards.
Bosses, Alpha Naytibas, quest and event enemies, and the enemies a save records (Save rows, and rows kept through a
zone reset) stay as they are in both games. Same spawns is on by default and has not been tested in game yet.

The guest's game calls its own spawn function for each enemy it lacks (the one the game calls when a zone's enemies
spawn) and its own despawn job for each enemy the host's game lacks (the one zone events send). No code of the game is
changed. When she enters a zone, her game spawns its own enemies first, so an enemy can appear there and vanish again
a few seconds later. The same happens after each reset of her zone, unless she turns the
[spawn filter](#spawn-filter-experimental) on.

- It needs shared enemies running. Only the host's value counts, from the next `coop fight on`: Options > Combat >
  Same spawns (experimental) in the host's co-op menu, or `same_spawns=on` in its
  [coop-settings.txt](settings.md#coop-settingstxt). Record, replay and the probe never use it.
- A zone counts as shared from 3 s after either game entered it or reset its enemies (a camp rest, a death), so the
  game's own spawns come in first. Where the other player stands comes from the same-place code, so after its error
  on either PC (`pilot=stopped`) same spawns stop in both games until that PC's game restarts.
- The guest's game sends its list of enemies there at once, then every 5 s while the zone is shared. The host's game
  answers with up to 16 enemies to create and 16 to remove each time. It asks for an enemy more than 1 km from the
  guest only once she comes nearer.
- `coop-link.log` names each change by spawn key.
  - On the guest: `fight spawned <key>`, `fight despawned <key>`, `fight spawn refused <key> <why>` and
    `fight drop refused <key> <why>`, where why is `too far` (more than 1 km from your EVE), `no row`, `save-row`,
    `keep-row`, `event-row` or `another zone` (as your game's tables have it), `no spawn manager`, `not shared` (an
    enemy shared enemies leave out: no common enemy, or one `fight_chars` does not name), `full` (240 enemies already
    handled since either game's last `fight spawns epoch`, or 48 extras), `row taken`, `no such enemy` and `not made`
    (for an extra, below), `gone` or `busy` (you are fighting that enemy or taking it down: it is removed once you are
    done, if the host's game still lacks it); and `fight spawn undone <key> <why>` when an enemy it created turns out to
    be one shared enemies leave out (`not shared`) or another character than the host's (`charId`), or
    `fight spawn kept <key> <why>` when that enemy could not be removed (it was dying, for one).
  - On the host: `fight spawn sent <key>` and `fight drop sent <key>`.
  - Both log `fight spawns epoch <why>` when their zone changes (`zone`), its enemies reset (`reset`), or 3 or more of
    them come back at once (`guids`). `fight spawns leave <spawnId>:0 save-row` (or `keep-row`) comes once a session for
    a row of a shared enemy that same spawns leave as it is. A game keeps the first 512 rows it reads, and rows past
    those are not logged.
- The `fight=` line of `coop status` (and `coop fight status`) says `spawns=off`, `spawns=on` or `spawns=stopped` (the
  error of same place stopped them too), and on the guest's side `spawned=<n> despawned=<n> spawns_differ=<n>`: the
  enemies her game created and removed, and the refusals that show the two games differ (`no row`, `save-row`,
  `keep-row`, `event-row`, `another zone`, `row taken` and `not shared`, and enemies undone or kept).
- Notices, in the menu's language, once a session each: `Same spawns on: where you and <name> stand within 100 m of
  each other in one zone, their game holds the same common enemies as yours.` (on the guest's screen: `your game
  holds the same common enemies as theirs.`), `Same spawns stopped by an error until the game restarts.
  coop-link.log says why.`, and on the guest's screen `Same spawns: some enemies differ between your game and
  <name>'s (other .pak mods or fight_chars) and stay as they are. coop-link.log names them.`
- The `fight stats:` lines in `coop-fight.log` add `same spawns <on|off>, epoch <n> (ours moved <n> times), <n> rounds
  <answered|sent>, <n> spawn and <n> drop lines, <n> spawned, <n> despawned (<n> undone), <n> refused, <n> differ,
  <n> stale, <n> over the rates`. `differ` is the count `spawns_differ=` shows, so it can exceed `refused`.

`coop fight spawn probe` checks the reads of same spawns on one PC, with no friend: it runs on a co-op save, as
`coop fight probe` does, whatever `same_spawns` says. At each probe census, `coop-link.log` gets `fight spawns epoch
<why>` when the zone changes or its enemies reset (rest at a camp to see `reset`, or `guids` when the reset fell
between two probe censuses, which come once a second), and once an epoch for each shared enemy, 32 a census at most,
`fight spawns probe <key> <how>`: `takes part` (same spawns would create or remove it), `save-row`, `keep-row`,
`event-row`, `another zone` or `no row`. `fight spawns probe no zone` means the current zone has no ZoneTable ID. The
probe reads two game tables and calls neither the spawn function nor the despawn job. The `fight=` line says
`spawns=probe` while it runs; `coop fight off` ends it.

## Spawn filter (experimental)

`spawn_filter=on` in the guest's own coop-settings.txt keeps away, in her game, enemies that the host's game no longer
has. It is off by default, has no row in the co-op menu, and has not been tested in game. On, the mod changes one
pointer in the game's memory on her PC ([internals/shared-enemies.md](internals/shared-enemies.md#the-spawn-filter)).

With it off, [same spawns](#same-spawns-experimental) work as above: when her zone resets (her death, a camp rest),
her game spawns its own enemies again, the ones the host's game lacks among them, and the host's next drop lines remove
them a few seconds later. With it on, her game does not spawn those enemies at all. The filter knows two kinds: an
enemy her game removed on the host's drop line, and a shared enemy whose death came from the host's game and that died
in hers too (she took part in its fight). A spawn line from the host's game for one of these takes it off the list
before her game creates it, so an enemy that the host's game holds again comes back. The list empties at the host's
next epoch (its zone changes or resets), at a world change in either game (a load, or a check that finds every enemy
new: `fight world <why>` in `coop-link.log`), and when the session ends. Whether her deaths and camp rests count as
world changes in her game has not been tested yet; one that does is not covered by the filter.

- The first entry into a zone still shows the old spawn and its removal: her game learns what the host's lacks only
  from those drop lines and deaths. The filter covers her later resets there, until the host's next epoch, except a
  reset that is also a world change in her game (see above). It holds 240 enemies at most; one more spawns and is
  removed, as with the filter off.
- The filter only refuses a spawn. It never kills, so a refused enemy gives no kill, reward, drop or quest progress,
  and no death of it is recorded. Quest and zone event enemies are other rows and never reach the list.
- It refuses spawns on the guest's side only, on game build 26123051, and its list fills only while the host's
  `same_spawns=on` runs. The setting is read when the mod loads and counts from the next start of shared enemies.
- The pointer is changed once a run, when shared enemies first start with the filter on the guest's side (or at
  `coop fight spawn probe`), and stays changed until `coop off` or the game exits. Between sessions every spawn passes.
  `coop off` puts the game's pointer back at once. To turn the filter off, close the game and set `spawn_filter=off`.

The guest's `coop-link.log` says:

- `spawn filter on: 0x145c15ea0 swapped from the game's Execute to our filter`: the filter is in place.
- `spawn filter refused <spawnId>:<index>`: her game asked to spawn that enemy, and the filter refused it. Her game asks
  again after a while; each enemy is named once a session, and later refusals only count. `spawn filter: <n> more
  refused, not listed` counts the ones the log did not name.
- `spawn filter refused: 0x145c15ea0 holds <address>, not the game's Execute (another mod's hook?); ...` or `spawn
  filter refused: the page of 0x145c15ea0 would not become writable (error <n>); ...`: the filter did not start, and
  every spawn goes on as with it off. Nothing was written.
- `spawn filter fault <code> in <where> reading <address>: off for this run`, then `spawn filter off (a fault): ...`:
  a fault in the filter's lookup turned it off until the game restarts.
- `spawn filter off (coop off): 0x145c15ea0 holds the game's Execute again`. If another value is there by then, the
  line names it and the mod leaves it.

While the filter is in place, the `fight stats:` lines in `coop-fight.log` add `filter <n> seen, <n> refused`: the
spawn requests it looked at and those it refused.

`coop fight spawn probe` with `spawn_filter=on` puts the filter in place with an empty list, so every spawn passes and
`seen` counts them. It checks the pointer change on one PC.

## Extra enemies (experimental)

With `enemy_extra` at 1, 2 or 3 in the host's coop-settings.txt and same spawns on, each common enemy where both players
stand within 100 m of each other in one zone gets that many more next to it, 2 to 4 m away, in both games. Bosses, Alpha
Naytibas, Elites (the game ranks M_RoyalGuardFemale and its two variants Elite), quest and event enemies, and the
enemies a save records get none, and so does an enemy more than 116 m from both players. No more extras come while 16
common enemies stand within 120 m of either player, counting the extras: shared enemies pair 16 at most. An extra goes
once both players are more than 120 m from it, and every extra goes when shared enemies stop on either PC. Extras have
not been tested in game yet, and the default is 0.

- Only the host's value counts, from the next `coop fight on`, and only with `same_spawns=on`: Options > Combat >
  Extra enemies (host's) in the host's co-op menu, or `enemy_extra` in its [coop-settings.txt](settings.md#coop-settingstxt).
- `coop-link.log` names each extra by its key: `3758096641:1` is the first enemy's first extra. In both games: `fight
  extra made <key>` and, at the end, `fight extra despawned <key> end`. On the host: `fight extra refused <key> <why>`
  (`full`: 48 extras already; `not made`: the game made none), `fight extra despawned <key> far` (both players more than
  120 m away), and `fight extras off <key> key range taken` when the host's tables use the extras' first key, so no
  extras this session. `fight extra kept <key> <why>` means the despawn job could not be sent, or with `guid unread`
  that the game made the extra but its GUID could not be read: shared enemies stop until the game restarts, and that
  extra stays until it leaves the map. On the guest an extra arrives as any same spawns key (`fight spawned <key>`).
  `fight spawn refused <key> row taken` means her game's tables hold a row at that key. `fight spawn refused <key> no
  such enemy` means none of her common enemies has the extra's charId yet: the host's game sends that extra again, and
  it comes once the enemy it stands next to is in her game. `full` there means her game holds 48 extras, and `not made`
  that her game made none. None of these three counts in `spawns_differ=`.
- The `fight stats:` lines in `coop-fight.log` add `extras <n> an enemy, <n> made, <n> despawned`.

## Shared bosses (experimental)

With `bosses=on` in the host's coop-settings.txt, shared enemies also share the bosses and Alpha Naytibas (the game's
BossMonster type) that both games hold: one HP bar, balance gauge and death, as for a common enemy. Shared bosses are on
by default and have not been tested in game yet.

With same place on, the guest's copy is frozen like any copy her game draws, so it never casts its own skills. The
host's game tells hers when its boss enters battle mode, which phase effects it holds and which enemies it summons, and
her game applies the same to her copy: the arena events, the phase changes and the summoned enemies, which are shared
like any other. Her copy leaves battle mode up to 10 s after the host's boss does, not counting time while the host's
game is paused, and at once when it stops being shared. Without same place, each game runs these for its own copy.

A boss in its Finish stance ends only by the host's finisher: a killing hit of the guest's then leaves it at 1 HP, and
her game takes the finisher's state off her copy. If the boss stops being shared first (the link drops, the host's world
changes, `coop fight off`), her game removes the Immortal it put back on her copy, and her own hit ends that boss in her
game. A boss without a Finish stance dies of her killing hit as a common enemy does, unless its own thresholds or
Immortal hold it.

When the host's boss dies, her copy dies too if she took part in its fight (`kill_credit` under
[shared enemies](#shared-enemies-experimental)), its thresholds taken off first. Otherwise her copy stays alive in her
game, so the boss's trophy and story events come only when she fights it herself. Her game starts the boss fight on her
copy (the arena events) only while her EVE stands within 30 m of it or has hit it.
[How it works](internals/shared-enemies.md#shared-bosses) has the details, and
[troubleshooting](troubleshooting.md#a-shared-boss-differs-between-the-two-games) the log lines.

- Only the host's values count, from the next `coop fight on`: Options > Combat > Shared bosses (experimental) and
  Boss HP (host's) in the host's co-op menu, or `bosses` and `boss_hp_scale` in its
  [coop-settings.txt](settings.md#coop-settingstxt). `coop fight record` keeps them in its file, and `coop fight replay` uses the
  recorded ones.
- `boss_hp_scale` (default `2.0`, from `1.0` to `4.0`) multiplies a shared boss's maximum HP in place of
  `enemy_hp_scale`, the Alpha Naytibas' too; `enemy_balance_scale` still sets its balance gauge. The mod does not adjust
  a boss's phase thresholds yet. The game sets each one (a minimum HP) as a share of the maximum HP the boss has when
  the threshold starts. The first one starts at spawn, before the scaling: at `2.0`, a boss whose first phase ends at
  60 % can end it at 30 % of its scaled HP (not measured in game yet). Later ones start from the scaled maximum and can
  sit above the HP the boss has left, which then rises to the threshold the next time the boss is hit: at `2.0`,
  Tachy's first threshold leaves it at 75 % of its unscaled maximum, and its second one, 45 % of the scaled maximum, is
  90 %. When the scaling ends during a fight (`coop fight off`, the end of the session), a threshold taken from the
  scaled maximum stays as it was and can be above the boss's own maximum HP.
- A boss takes one of the 16 shared places before any common enemy, even the place of a common enemy in a fight, which
  then stops being shared, unless that enemy's death or takedown is under way. A common enemy never takes a boss's
  place.
- With same place on, a shared boss always fights the host: its AI never moves to the guest's game, whoever hits it.
- A boss that only one save still holds (the other player already killed it, for example) stays unshared. The host's
  game fights its own alone, at `boss_hp_scale` once the guest's side is on, as with common enemies; a boss that only
  the guest's save holds stays as it is in her game. Same spawns never create or remove a boss.
- The `fight=` line of `coop status` carries `bosses=<percent>` (the host's `boss_hp_scale`) or `bosses=off`, on
  both PCs.

To test shared bosses alone, record the host's side of a boss fight as the [same place](#same-place-experimental)
steps do, with `bosses=on`, load the save again so the boss is back, then play the recording into the guest's side
with `coop replay` and `coop fight replay`. A recording keeps no boss start, phase or summon lines, so the guest's side
of a shared boss does not run in a replay by itself. Four commands run it on the frozen boss copy nearest your EVE, at
the shared fight's next turn, one test at a time. They work only while `coop fight replay` runs; otherwise
`coop-link.log` says `pilot test <name> refused: only while coop fight replay runs`. Each test logs `fight pilot test
<name> <key> hguid=<n> ...` lines in `coop-link.log` and ends with a `done` line, or with a `stopped` line when the
copy goes. A test asked while another one runs is refused (`another test runs`).

- `coop fight pilot test bstart` logs the copy's battle mode, first-time latch, on-battle flag, states 30 and 39 and
  whether its AI runs a task (`before: b58=<0|1> 45a=<n> 45b=<n> state30=<0|1> state39=<0|1> ai=<0|1>`), starts the boss
  fight on the copy as the host's game would (`SetBattleMode called`, or `SetBattleMode not called: <why>`, where
  `again` means it already ran on this copy and the copy is still in battle mode), then logs each change of those values
  for 1 s (`after <ms> ms: ...`, then `done: ...`). A replay has no host to repeat the boss start, so the copy leaves
  battle mode 10 s after the call (`fight battle off` in `coop-link.log`), and a test after that calls it again. Once
  the replay has played all its lines, the copy stays in battle mode until `coop fight off`. From the next `coop fight
  replay` until the next `coop fight on`, boss copies get no `BattleMode_5s` from the recording, so a second run after a
  reload shows the boss start alone. The replay that ran the test still gets it on its boss copies, so its other tests
  find the copy as the guest's side would.
- `coop fight pilot test phase` sends the copy the first phase row of its boss that it lacks (5005115 for GorillaB),
  and 5 s later the dispel of its HP threshold, as the host's phase lines would. Each line logs `line: <rows>; floor
  <stat 107>` and `cast: <n> taken, <n> refused`, and at the next turn `next turn: floor <stat 107>; rows <the rows
  it holds>`. `refused: every phase row held` means the copy holds them all already.
- `coop fight pilot test finish` holds the copy at 1 HP for 10 s through the guest's HP correction, so none of the drop
  counts as your hit, then gives it the host's HP back. It logs `start: HP <n>, floor <n>, 2001101=<0|1>
  2001102=<0|1> state27=<0|1> state3=<0|1>` (Passive_DeathReady and Passive_FinishReady on the copy, then its
  Immortal and NoDamageNoHit states), each change as `after <ms> ms: HP <n> ...`, and `done: <n> guard turns, HP <n>;
  the host's HP from the next turn`. Run it after `phase`, so no threshold holds the copy above 1 HP. Back up your
  saves first ([saves.md](saves.md)): a boss that dies here stays dead in that save once the game saves, and its kill,
  trophy and story events count there. Hit the copy once, and only after a line shows `state27=1` (its Immortal): with
  the finish guard working, it stays at 1 HP. If the test stops before its `done` line (`coop fight off`, or the copy
  no longer drawn), the copy gets back the HP it had when the test started.
- `coop fight pilot test summon` makes a DollHead (SE_M_DollHead_02) 3 m in front of your EVE under the first summon
  key, `4026531841:0`, with its summon row's effects (5025010 and 5025013) and the guest's freeze, as her game does
  for a host's summon: `fight summon made 4026531841:0`, then `made 3 m ahead: life <n>, freeze taken`, or `the game
  froze it first` when its row's effects froze it already. For 10 s it logs each change of the DollHead's life state
  and state 39, and freezes it again when the game ends the freeze (`frozen again`). If the game refuses the guest's
  freeze, the mod removes the DollHead at once (`not made: freeze refused` or `stopped: freeze refused`, and `fight
  summon despawned 4026531841:0 freeze refused`). No host enemy pairs with it, so 3 s after its `done` line the mod
  removes it (`fight summon despawned 4026531841:0 unpaired`), or at `coop fight off`. `refused: same place off`
  means same place does not run on this side. A DollHead you kill meanwhile counts in your save (its kill and album
  entry).
