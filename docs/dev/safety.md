# Achievements and safety design

What the mod writes in the save folder is listed in [Saves](../players/saves.md#what-the-mod-reads-and-writes).

## Achievements

The mod calls no achievement function. Each game raises its own Kill achievement, kill rewards, drops, quest kill tasks
and a boss's story events from a death in its own world, with the death's cause as the killer. Shared enemies keep one
rule there: a fight done together counts for both players, and nothing done without a player reaches that player's
save. The rule applies where the mod makes a death, the other game's kill (the host's `dead`, or the guest's lethal
claim the host accepts):

- That kill kills our copy, with our EVE as the cause, only when our EVE took part in its fight: a drop on our copy
  that no write of ours made (her own hit), our EVE as the game's last player on the copy, or, with
  `kill_credit=together` (the default), our EVE within 30 m of the copy (FSBActor `+0x4cc`) at the kill. The last
  player is the GUID at logic actor `+0x638`, which the game stores (`FUN_141ba93d0`) when an enemy targets a player or
  a player's hit lands, and which its death handler (`FUN_141baf820`) takes as the killer of a death with no player
  cause. No EVE of ours found counts as no part. Damage from before the enemy was shared or paired does not count as
  our hit: the other player's claims before a pause hurt it too.
- Our mirrored crowd controls go through the game's effect call (`FUN_141ad1af0`) with our EVE as the caster. Whether
  that call can reach `FUN_141ba93d0` is not ruled out, so the engine reads `+0x638` before and after each such call:
  a copy on which it turned into our EVE is noted for the session (`last player ... set by a mirrored crowd control`),
  and its `+0x638` no longer counts as our part.
- Without part, our copy does not die, since a death with no cause still drops loot, records the death in the zone and
  runs the enemy's death events. It goes back to its full HP, with no cause and no damage number, so one hit later
  does not finish what the other player's hits did. The guest ends the pair (`dead-unshared`), so her copy lives on as
  her own enemy, its floor, scaling, freeze and finish guard taken off, until same spawns' next drop despawns it (the
  host lacks it), which is no kill. A boss copy is back above 1 HP before the guard is taken off, so the guard keeps
  the boss's Immortal. The host keeps its copy alive, leaves it out of its later
  censuses and of same spawns (`kill-unshared`), and sends `dead`, so her copy dies on her side's own test.
- A boss's `bstart` runs SetBattleMode on her copy only while her EVE is within 30 m of it or its last player, so its
  battle-start events never run in her world for a fight she is not in.
- The 30 m clause counts only while our EVE is alive (life state 1 or 6), so a dead EVE gets no kill made next to her
  body. While a player is down, the hand-overs move an enemy only within 30 m of the EVE that takes it
  ([A player down](../online/group-internals.md#a-player-down)).
- `coop fight test kill` (the solo probe) kills only an enemy our EVE took part in, by the same test with the 30 m.
- The [spawn filter](../fight/enemies-internals.md#the-spawn-filter) (on by default) refuses the guest's spawn of an enemy the host's game lacks
  and never kills, so no kill, reward, drop, quest kill or achievement comes of it, and no death is recorded in her
  zone.
- The mod's kills pass no skill to ApplyStat, so they never count toward the skill-kill achievements. The mirrored
  crowd controls and the HP corrections never kill, and the game's AchievementTable has no row for a hit.
- [Shared quests](../online/group-internals.md#shared-quests) keep the same rule: the guest's game takes a host step only when her quest stood
  where the host's did and she stood in the host's zone when its line came. A kill task waits for her own copy to
  complete it, by her own kill or by a shared enemy that died in her world under the rule above. `coop quests force`
  never applies a step of a quest she is behind on.
- Night Operation keeps the same rule. With shared enemies off, each world fights its own copy of each wave monster,
  and each kill is that player's own. With them on, a wave monster pairs like a field enemy, and its death reaches a
  player's save only by the took-part test above. The shop's points go only to a player whose own game ran the run from
  its countdown to a success or a time up: each game credits its own player, a guest whose game missed the countdown
  gets none, and no line between the games carries points.
- The challenges but the Shooting Range run only without a Steam session: a start refuses one, and a session that
  starts ends the run. The Shooting Range also runs for two linked players, under Night Operation's rule above. A
  challenge's kills are the player's own, and it gives no shop points. A best run goes into `coop-records.txt` only on
  the PC whose own solo run ended in success, never from a co-op run and never over the link.
- Every camp travel of the mod but `coop mxiii`'s and `coop mxiii 30`'s goes only to a camp the player's save has
  already activated, because activating a camp counts toward achievements and the game's fast travel does not check it
  ([Following the host](../online/group-internals.md#following-the-host)). The native read asks the game's own camp list
  (`FUN_141d1f860`, the function the camp list screen calls) for the camps of the travel table that hold an active
  ZoneEnvSpawn row, so the mod travels only where the game's own camp list would let the player travel.
  - The follow, `coop travel probe <camp>` (its solo test) and `coop mxiii leave` refuse any camp the read does not
    list, and every camp while there is no read (a load, the title, after a fault). Whether arriving at a camp through
    the game's fast travel activates it has not been checked.
  - `coop mxiii` and `coop mxiii 30` travel to their own camps (`DLC02_00_Camp_00` or `DLC02_10_Camp_01`, and
    `DLC02_30_Camp_01`) without that read ([The cut Matrix XIII area](../world/matrix13-internals.md)): the two camp
    trophies count only named ZoneEnvSpawnTable rows turning On (`Trophy_Activate_FirstCamp` one,
    `Trophy_Activate_AllCamp` the 89 `ChangeState_ZoneEnv_*_Camp` rows of AchievementTable), and none of them names
    `DLC02_00_EnvS_960`, `DLC02_10_EnvS_900` or `DLC02_30_EnvS_900`, the mod's rows for those camps.
- A revive changes only the downed player's own EVE: her life, her HP and the recovery items that a camp respawn refills
  too. The cutscene wait is a pause, and the solid partner changes no game state.
- Matrix XIII's rows go in at the title whenever the test pak is installed and the game uses the co-op save files ([At
  the title](../world/matrix13-internals.md#at-the-title)), so they stand in memory under co-op saves that never use
  `coop mxiii`. They can neither unlock nor block a camp trophy.
  - `Trophy_Activate_AllCamp` (trophy 26, `Activate_AllCamp`) completes at a fixed count, 89 in both AchievementTable
    and TrophyTable, and only its 89 `ChangeState_ZoneEnv_*_Camp` rows raise it, each on one named shipped
    ZoneEnvSpawnTable row turning On (`DED10_EnvS_113` and the others). `Trophy_Activate_FirstCamp` takes
    `DED10_EnvS_100` alone. No count of ZoneCampTable or ZoneEnvSpawnTable rows goes into either: the game's code names
    `Trophy_Activate_AllCamp` once, in `FSBActorProgressAchievement::Execute` (`FUN_141b1c4c0`), to call `FUN_141ce8050`
    after that row has progressed.
  - None of the 2747 AchievementTable rows names a `DLC02` row, zone or world, `MXIII` or `DLCMatrix13`. The only rows
    that match a camp object by its class are the skill machine's guide rows (`Ach_Guide_InteractEnvAlias_SkillMachine`,
    `Ach_Guide_TrainingRoom`), which open a guide and the skill manual page and lead to no trophy, as any camp's skill
    machine does. A row that is only present raises no event: the kit's objects exist only inside the area.
  - The test pak's levels are copies of Matrix 11's, and the camp vending machines in them keep Matrix 11's rows
    (`ME_01_EnvS_017` and `_018`, `ME_03_EnvS_005`, `_015` and `_023`, `ME_04_EnvS_008` and `_009`), seven of the 89.
    Matrix 11's zones never start in that world, which should leave them unusable, but that was not checked, so v3 moves
    all seven 400 m below the floor (v2 moves only `ME_01_EnvS_017`).
- A [Doro race](../online/modes/race-internals.md) gives nothing to either player: its Doros cannot die, and it calls no
  achievement, reward or save function.
- A [Lion](../fight/bosses-internals.md#the-cut-lion) lives only in the world of the player who typed the command and is never shared: its kill is
  that player's, like any Naytiba's.
- `coop shortcut load` writes a cut Load Shortcut developer save as a co-op copy only after it drops the save's
  achievement list and the six gears from which a load-time fix-up makes achievement entries, and only with
  `shortcut_load=on`, since the developer's progress left in it can still complete an achievement in play
  ([Loading one](../cutmenus/menus-internals.md#loading-one)).
- A [gift](../cutmenus/menus-internals.md#cut-mailbox) moves consumables between two co-op saves and nothing else. Its seven items lead to no trophy
  in the AchievementTable: their acquire rows (`Acquire_Item_Grenade`, `Ach_Reward_Acquire_Item_ConcussionGrenade` and
  the potion and grenade category guides) open guides only. A gift that arrives can open those guides early, as a shop
  buy can.
- The [Night Operation shop screen](../online/modes/nightop-shop-internals.md#the-night-operation-shop-screen) sells for Beta Seeds, which no AchievementTable
  row names, from shops with no tag. Its purchase raises the game's BuyItem event for the item bought; the four BuyItem
  rows name cosmetics the shop does not sell, and an Acquire row on PulseGrenade or ConcussionGrenade fires as it does
  for the console's buy. [Roxanne's choices](../online/modes/nightop-shop-internals.md#roxannes-night-operation-choices) route to her goodbye and call no quest,
  item or achievement function.
- Gun mode's [rounds](../fight/gunmode.md#rounds-on-a-co-op-save) are sold in the camp vending machines, which carry
  the `AllShop` tag. A buy of them raises the game's BuyItem event with that tag, as a buy of drone ammo there does,
  so it counts toward the gold-spending trophy. Their drops are the game's own rolls in each player's own world. Their
  rows go in only once a co-op save from the co-op save files has loaded. From then on `coop saves main` is refused
  until the game restarts, so none of the player's own saves loads while they are in.

## Safety design

Stellar Blade Online reads and writes game memory, so it fails closed: a failed check or a fault stops the affected
feature or drops the input.

- Before it reads any engine memory, the native part checks the game's exe against the pinned build (Steam build
  26123051): its PE time stamp, its image size and 19 code bytes. On any other build the pose path stays off
  (`engine=off reason=...`) and nothing is read. The save slot read, the vitals read for the partner card and the
  Night Operation poller also run only on the pinned build.
- Every engine access in `coop_tick` runs under a Windows structured exception (SEH) guard. The first fault latches the
  feature off for the run and is logged with its code, the DLL offset, the address and the part. Effects have a latch of
  their own. A fault inside Steam in the worker (for example a call racing the game's Steam shutdown at exit) stops the
  link and the pose path for the rest of the run (`stopped=fault <code>`) instead of crashing the game. The log's last
  line gives the reason the worker stopped. The rows batches (the cut Naytibas, the Shock Bolt, Matrix XIII and the
  Night Operation shop) share one latch; [The Gardener's batch in the native
  part](../fight/bosses-internals.md#the-gardeners-batch-in-the-native-part) says why.
- On the Lua side, a module that fails to load is off alone until the mod reloads ([Modules and
  isolation](architecture.md#modules-and-isolation)). `main/frame.lua` and `main/pass.lua` call each module's work in
  the two loops (every frame and every 250 ms) through an `xpcall` guard. An error that escapes one, for example
  `fight/bosses/lion.lua`'s tick, is logged with the module's name, the message and its stack traceback: `[StellarCoop]
  lion: error (logged once until the mod reloads; the other modules go on): <message>`, then `stack traceback:` and its
  lines. The traceback gives the script and the line, which the message alone lacks for most of the mod's errors (raised
  with `error(why,0)`) and for UE4SS's own. Each guarded call logs its first error once a Lua load. Several calls share
  a name (`ghost` covers eight of `online/partner/puppet.lua`'s, and each restore has its module's name), and each of
  them still logs its own first error. The modules after it still run in that pass, and the module is called again at
  the next one, so one that recovers goes on working. Measured with Lua 5.4 on the build machine, the guard adds about
  40 ns a call. The per-frame loop makes 38 to 59 guarded calls (50 with the on-screen UI, plus the inbox while a race
  is armed and up to 8 pad events), under 2.5 µs a frame.
- The save slot read, the vitals read and the Night Operation poller read through `ReadProcessMemory`, which returns an
  error instead of faulting, and only after a plausibility check of every pointer and count.
- `coop_tick` never blocks the game thread. It runs once per engine frame (it checks the engine's frame counter) and
  shares only atomics and a lock it never waits on: when the worker holds the lock, the hand-over waits for the next
  frame. Nothing is allocated under the lock: the worker sizes the pose buffers beforehand and the game thread only
  swaps them. Every 60 s the log gives the tick's cost and, while poses flow, the stream's counts.
- Everything from your friend's game is checked before use: the table parser and the pose decoder (both fuzzed by the
  tests), the mesh path rule, the channel 1 size and rate limits, at most 8 effect starts a second, race lines
  (printable ASCII, 512 bytes and 40 lines a second at most, then the bounds in [Race
  lines](../online/modes/race-internals.md#race-lines)) and the dr lines of a race in a match (the same, 16 lines a
  second, then the sender and bound checks in [Races in a match](../online/modes/race-internals.md#races-in-a-match)).
- The [Doro look](../online/modes/race-internals.md#the-doro-look) and a race's [driving](../online/modes/race-internals.md#driving) write to the player actor. The look
  writes `bHiddenInGame` on EVE's mesh parts from Lua. It writes `coop-look.txt` before it changes them. It undoes
  them at the race's end, on `coop race look off` and `coop off`, after a map change and at its first error. It also
  sets `bHiddenInGame` on the main mesh of the drone that follows EVE, records the drone in the same file first, and
  clears it again on the same exits. The next Lua load undoes them from the file when this one could not. The driving
  gives her movement a velocity and her a yaw each frame. The two property writes, her movement component's four
  values at 0 and her main mesh's `VisibilityBasedAnimTickOption` at 0, are the native part's: on the game thread,
  on live objects only, behind the races' own SEH latch, put back at each end Lua asks, at `coop off`, at a new Lua
  load and at the first fault, also for as long as a cutscene or photo mode lasts ([The native
  hold](../online/modes/race-internals.md#the-native-hold)). A race in a match also teleports EVE onto her grid slot
  with `K2_TeleportTo` at its start and again at GO when she stands more than 3 m from it. When Stellar Blade's own
  chair seats her at GO it does not teleport her: she sits out.
- The [bike](../vehicles/bike-internals.md) writes to the player actor too. It adds one skeletal mesh component to EVE's
  actor, hung on her main mesh and hidden until she rides. While she rides it sets her main mesh's relative rotation for
  the lean and drives her with its own drive (`coop-drive.txt`, the four values, a velocity and a yaw). Through the native
  part it turns 54 of SB's actions off in the player controller's `InputActionStateMap` (each one's state kept) and
  plays the riding pose in her custom animation slot. It writes `coop-bike.txt` (her main mesh's relative rotation and
  location) before any of it. A dismount, `coop off`, `bike=off`, a new EVE and the ride's first error put it all back:
  the pose stopped, each action's kept state written back unless SB changed it during the ride, the four values, her
  mesh. The next Lua load puts her mesh back from `coop-bike.txt`; the native part turns the actions back on and stops
  the pose itself at a new Lua load. Its preload keeps a handle to SB's own async load of the bike's mesh and the riding
  clip, released at `bike=off` and `coop off`. All of it runs under its own SEH latch ([The bike: how it
  works](../vehicles/bike-internals.md#status-words-and-the-latch)). The parked bike adds a plain actor with the bike's
  mesh to the level of its map. Each other player's parked bike on the map EVE stands on adds one more. Their paths go
  to `coop-bike-stand.txt` and `coop-bike-copies.txt`, so the next Lua load removes them. They block EVE and enemies. A
  mount at her parked bike moves EVE onto its seat with `K2_TeleportTo`, SB's own teleport ([The parked
  bike](../vehicles/bike-internals.md#the-parked-bike)).
- The co-op save copies (`StellarBladeCoop00.sav` to `04.sav`) are made only on a `saves convert`, `saves coop` or
  `saves refresh N` request (the question on the title screen, `auto_coop_save=always` or `coop saves`), and only at the
  title: Lua reports the title screen (`world=title` in `coop-state.txt`), no save is loaded, Continue or Load Game
  was not chosen (the game's load mode is 0), and the game is not reloading the save itself (client +0x2f9c is 0).
  - A pass checks this again before each file and before the switch. The native part reads your saves and writes each
    copy as a `.coop-tmp` file, renames it over the copy and reads it back.
  - One name check guards every write but the export's (below): only the copies, their temporary files,
    `StellarCoopSaves.txt`, the shared quests' records `StellarCoopQuests00.txt` to `04.txt`, the shortcut saves' marks
    `StellarCoopShortcut00.txt` to `04.txt`, the SBO session records `StellarCoopSBO00.bin` to `04.bin` and the backup in
    `StellarCoopBackups` pass it. The backup is taken before any copy whenever `StellarCoopSaves.txt` does not exist
    yet, and a refresh backs up the copy it replaces first.
  - A `saves export N M` request is the one write to your own saves, behind a check of its own that passes only
    `StellarBladeSave00.sav` to `04.sav` and their `.coop-tmp` files. It refuses a co-op copy with a shortcut save's
    mark beside it before it reads anything.
    - It reads the co-op copy, checks it as the game does, refuses it when its stored CRC-32 is one of the 12 cleaned
      developer saves' or it names one of their five items with no `ItemTable` row, and refuses it while an `ItemAlias`
      field or a quick slot names one of the mod's items, while `BulletItemSlotIndex` is 5 or more (the Shock Bolt
      `rows/shock.h` appends after the five ammo types the game ships), or while the save's `MapName` is `MXIII_P` or one
      of its four camp fields (`CampAlias`, `CampEnvSpawnAlias`, `LastFullCampEnvSpawnAlias`,
      `LastSimplyCampEnvSpawnAlias`) holds a name that starts with `DLC02_`, a row of the Matrix XIII area. A find
      inside `NewGamePlusBaseData`, the New Game+ copy of the inventory and camps that playing does not change, is refused
      too, with a line that says so instead of what to use up or where to rest.
    - Only then does it back up the target save, read the copy again (unchanged since the check, or it stops), scan those
      bytes again, check that the target save is as its backup read it (or still missing) and write the copy over that
      save through a `.coop-tmp` file and a rename, then read it back. It never edits a save's bytes.
  - The switch to the copies is one 8-byte compare-and-swap in the game's memory, on the pinned build only, read back
    every 250 ms; an entry that moves or changes stops it for the run.
  - With `sbo_lobby=on`, the game thread reads the game's `Backup\StellarBladeCoop0N_Old.sav` once the game's save
    queue falls to 0 after a write to that co-op save, in the same call, so no save of the game's is under way. The
    worker writes it into `StellarCoopBackups\autosave\StellarBladeCoop0N\` through a `.coop-tmp` file and reads it
    back; only then does it remove the oldest copies there past the 10 newest, by a name check that passes only those
    copies' names, and never the two copies an open SBO session's record names
    ([players/saves.md](../players/saves.md#copies-before-each-save)).
- These slots in the game's image, rather than in memory the game allocated, can hold the mod's value for its hooks.
  Each one is an 8-byte pointer in `.rdata`. Each swap is a compare-and-swap from the game's own value only, with the
  page writable for that store alone. A slot that holds another value is never written.
  - The [spawn filter](../fight/enemies-internals.md#the-spawn-filter)'s slot, `0x145c15ea0`, is swapped when the
    filter's gate first opens (on by default) and swapped back from the mod's value at `coop off` or after a fault.
  - The [teleport screen's extra tabs](../online/group-internals.md#the-teleport-screens-extra-tabs) use `0x145c44978`.
    It is swapped once a run on the pinned build, with no setting in front of it, and swapped back at `coop off` or
    after a fault. If it will not swap back, the hook stays in it and passes every call on to the game's function.
  - The [level flight](../eve/eve-internals.md#developer-flight-and-slow-motion) uses `0x145ccd738` and `0x145cd9a38`,
    swapped together at the first `coop fly on` of a run. If the second will not swap, the first is swapped back. Both
    are swapped back at `coop off` or after a fault, and a slot that will not swap back keeps a hook that does nothing
    past the game's pass.
  - The recruiter's Join slot, `0x145bfece8`, is swapped at the first `sbo arm`, which Lua sends once the recruiter
    stands in Xion, only with `sbo_lobby=on`; with it off, the slot is never written. Its hook counts the recruiter's
    Join and always calls the game's own function, and the slot is swapped back from the mod's value at `coop off`.
  - [Her sounds](../online/partner-internals.md#her-sounds-sent) and [her world
    effects](../online/partner-internals.md#her-world-effects) use eleven slots in three sets. Each set is swapped all
    or none. The context set (`0x145c51bb0`, `0x145c525f0`, `0x145c60d60`, `0x145cf6398`, `0x145cf5a40`, `0x145cf5cb0`,
    `0x1463c3358`) is swapped while the sounds look or the effects look is on. The audio starts (`0x1463db320`,
    `0x145d07e48`) are swapped while the sounds look is on. The world-effect starts are swapped while the effects look
    is on: `0x145952d08` (UNiagaraComponent's Activate) with `0x14645f648` (UParticleSystemComponent's ActivateSystem).
    If one slot of a set holds another value, the slots of that set already swapped go back. That set then stays as it
    is for the run. A set goes back when none of the looks it serves is on, until one is on again. At `coop off` every
    set goes back for the run. After a sounds fault the context and audio sets go back for the run. After a world
    effects fault the world-effect set does. A slot that will not swap back keeps a hook that only runs the game's
    function.
- Except for those copies, the mod never reads or writes a save, unlocks or equipment. It adds to the inventory only for
  a Night Operation shop buy (`coop nightop buy`, co-op saves only) and for `coop gift` (a take, or a gift coming back,
  co-op saves only), through the game's own request (`ServerRequest_ItemBucketItemAdd`) with an item of its list and 1
  to 10 of it. It removes from the inventory only through the game's own request (`ServerRequest_ItemBucketItemRemove`),
  after the native part read that EVE carries that many: for a `coop gift` send, with one of seven consumables and 1 to
  10 of it; for the bike's paid fetch at a Xion camp, on any save, with 500 `BetaCrystal` ([Bringing it
  back](../vehicles/bike-internals.md#bringing-it-back)); for gun mode's reload, with `Bullet_Nikke`, the rifle's round
  ([Rounds on a co-op save](../fight/gunmode.md#rounds-on-a-co-op-save)). Gun mode removes once a reload, at most a
  magazine (`cfg.mag_size`, 60) and at most the count she carries (the last read less the takes it does not show
  yet). It removes only while its rows are in and a co-op save is loaded. On your own saves the magazines stay free.
  It removes only while the game plays: SB's logic stops while the game is
  paused or in photo mode, its remove with it. After a refused take the next empty reload waits 5 s. Its count reads
  ask the `items` request with the numbers 20000 to 32767. With `gun_mode=off` gun mode asks no rows. It asks them
  once a co-op save from the co-op save files has loaded, never at the title, on your own saves or on the manual
  co-op slot. Those rows patch the three shipped camp ShopTable rows (`Shop_SimpleCamp`, `Shop_FullCamp`,
  `Shop_NestCamp`) in place for the game run, with `SBO_Camp_Bullet_Nikke_Buy` added to their `ShopItems` and their
  other items as shipped.
  They add `SBO_Camp_Bullet_Nikke_Buy` to ShopItemTable and 8 RewardGroupTable rows (31114 to 31121) to the ammo groups
  enemies and supply boxes roll. No shipped RewardGroupTable row changes. SB's own buy and drops add the rounds: gun
  mode adds none. Apart from enemy stats with the experimental shared enemies
  (`coop fight`, on by default, co-op saves only), their positions and animations with the experimental same place (on
  by default), the quest steps of the experimental shared quests (on by default, co-op saves only, made by the guest's
  game through its own quest functions) and a Night Operation run's state on the night line and `coop gift`'s
  consumables, nothing is copied between the two players' games. Beside the saves it reads only the co-op marker
  `StellarCoopSlot.txt` and the copies' manifest `StellarCoopSaves.txt`; Lua only checks whether a copy exists, opening
  none of your own saves. See [players/saves.md](../players/saves.md).
- The follow and the revive call the game's own functions on the local player only. A travel runs on the guest's own
  request, on a co-op save, for a camp of her own table that her game already knows by name, under its own SEH latch:
  a fault turns it off until the game restarts. The revive calls the game's respawn on the downed player's own EVE,
  once per death, at the death screen only. No address, pointer or name index goes over the network for either.
- `coop lion` adds [the Lion's 78 rows](../fight/bosses-internals.md#the-rows) to the game's tables through the game's own AddRow, on the game
  thread with no logic task in flight, after a check of each table's vtable, AddRow slot and row size, under their own
  SEH latch. No shipped row changes, no row is added twice and nothing is written to disk.
- `coop off` stops engine access, the link and every feature until the game restarts, even across a Lua reload,
  because the native part keeps the flag.
- The DLL pins itself in memory, so a Lua reload that frees the script's libraries never unloads code the worker is
  running. It also pins Steam's DLLs, so a call in flight at game exit returns into mapped code.
