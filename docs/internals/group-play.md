# Group play: how it works

The player's side is in [Playing with a friend](../playing-with-a-friend.md), and the teleport screen in
[Interface](../interface.md#teleport-screen).

## Shared quests

Shared quests (`shared_quests`, experimental, off by default, not tested in game yet) move the guest's quests to the
host's state through the game's own quest functions, one step at a time, for the steps the two players make together.
`quest/sync.h` holds the line format, the quest table and each side's rules; `quest/engine.h` holds the reads and calls
on the game's quest data and the worker's side.

The game's quest manager runs on the game thread, so the mod's pass does too: every 250 ms `coop_tick` reads the local
player's quest unit (the quest manager at `0x147032588`, its unit from `FUN_141c5e880`) under the shared quests' own SEH
latch. The pass walks the unit's three quest arrays (in progress, complete, failed) and its ID map, and for each shared
quest reads its state, its active group and the state of each task the game made for it. Before each pass and each call
it checks that it is not on the game's logic worker thread (whose ID the game keeps at `0x1470634f0`) and that the save
is still the co-op save it started on: another save ends the side with `SBQ19 off slot` (the worker starts a new one
on the next co-op save), while a load (the title screen, a map change) only pauses it.

- The host only reads. Each quest whose state changed goes to the guest as one reliable line on channel 2 with the
  whole state, numbered per quest, so a repeated or late line changes nothing: `SBQ19 q <gen> <seq> <id> <state>
  <acquire mark> <finished groups> <tasks done> <done mark>`. A group or a task is named by its place (container and
  position), which the game builds the same on both PCs from the same tables.
- Each step carries a mark that says where it may be made: `-` anywhere (no zone event, or only quest, item, UI or
  hint events), `t` in the zones the game's tables give for its events (spawns, despawns, environment changes, scenes),
  `z<n>` in the zone where the host stood when its pass saw the step (for the 38 steps the tables cannot place), `?`
  for such a step the host's pass did not see, `K` for a kill task and `#` for a quest the host denies. The table that
  gives each step's class, zones and events is built into `quest/sync.h` from the tables of build 24463856; another
  game build needs it built again.
- The guest's pass compares each host line with her own quest and plans the next forward step: an Epic or Sub quest
  she lacks is acquired by ID (`FUN_141c5cf20`, the call a quest zone event makes), a Request on her board is accepted
  with the board's own call (the Request quest's vtable `+0x10`), and a task is completed through its own Complete
  (task vtable `+0x60`). There is no quest-complete call: an Epic or Sub quest completes inside its last task's
  Complete, with its reward and next quest, and a Request stops ready to hand in, as in solo play.
- Each call has its guards, read again just before it: a task only at state 1 in her active group, whose parent is
  that group and whose Complete slot is one of the game's two Complete functions; an acquire only for an ID her quest
  map does not hold (the game refuses any other too, and after each load the pass checks that every complete and failed
  quest is in that map before it acquires anything); a Request accept only at state 0 on a Request her board accepts.
  A step the game refuses leaves that quest alone for the session. At most one step goes per pass.
- A step is the guest's only when she stood in the host's zone when its line came and her quest stood where the host's
  stood before the step. A quest the host moved without her is behind: nothing of it is planned, a forced step
  included, until her own play brings it to the host's state.
- The guest sends display lines only: `at` (her zone), `have`, `wait <why>` and `ahead`. The host applies nothing from
  them.
- When the guest's side comes on, the host sends a snapshot (`snap`, the `zone` and `q` lines, then `end` with their
  count and an FNV-1a digest) of the quests it moved while linked with that friend. It sends a new one after its own
  load, and when one of its quests goes back (an older save). On either side, a pass that finds a known quest object
  gone, or a started Epic or Sub quest that none of the unit's three arrays lists, waits for the next pass to read the
  same objects, so a quest unit read while the game still fills it sends, records and applies nothing.

The record beside each co-op slot (`StellarCoopQuests0N.txt` in the account's save folder) keeps, per friend, the
host's marks (`h` lines) and the host lines the guest's game took (`g` lines). The worker writes it through the same
name check as the co-op copies, at most once a second and only on a change, as a temporary file renamed over the old
one. A bad line only loses that quest's marks; her live quests always decide what is made.

## Following the host

The guest's travel to the host (`session/travel.lua`, the camps lines, `game/travel.h` and the native call) moves only
the guest's EVE, through the game's own fast travel, and changes nothing in the host's game. It has not been tested in
game yet, and in this version it never travels: `main.lua` leaves it off until that test (see below).

- The guest's Lua sends `camps? <id>` when she presses F7 (`follow_key`) or types `coop travel host`, and with
  `follow_host=always` 5 s after the host arrived somewhere new. It sends one at most each 2.5 s.
- The host's Lua answers from the game's spawn points on its map: those named after one of the travel camps of its
  world, read once a map, sorted by distance to the host's EVE. The answer names the world and the 8 nearest, or
  `none` with `title`, `loading`, `nocamp` or `busy` (a warp or respawn of the host's under way).
- The travel camps are the 120 ZoneCampTable rows of type FullCamp, SimplyCamp, PhoneBooth or Tetrapod that lead to
  exactly one story world in build 24463856. Autosave volumes, camps that lead to several worlds or none, and the camps
  of the developer test worlds are left out. The guest's game uses a camp of the answer only if it is in her own table
  under the host's world, her save has activated it, and it already exists as a name in her game (`FName` with
  `FNAME_Find`, which never makes one).
- Her Lua checks its guards again, then hands the camp's name to the native part. On the game thread, the native part
  builds the game's 0x60-byte camp request as the game's ReturnToCamp job does and calls the game's fast travel
  (`0x141cdd7b0`), out of line under its own SEH latch. Before the call it reads the globals that the call's getters
  reach, the client's flow and phase, any warp or respawn in flight, and whether the local player's EVE is in the
  world. It makes at most 3 calls in 10 s and none for 10 s after an accepted one.
- A return of 0 is the game's refusal, and the guest's Lua tries the next camp of the answer.
- The game's fast travel does not check whether her save has activated the camp (`game/travel.h`), and activating a camp
  counts toward the game's camp achievements (`Trophy_Activate_AllCamp` and the camp rows of AchievementTable). Her Lua
  therefore takes only a camp that the native read of her activated camps lists (below). With no read at that moment
  (a load, the title), the travel is refused with `no read of the camps this save has activated (<why>)`.
- The follow itself is off: `main.lua` does not pass `follow` to `session/travel.lua`, so every travel is refused
  before `camps?` is sent (`travel refused: the follow stays off until it has been tested in game` in `UE4SS.log`, and
  the failed notice), and no offer shows. `coop travel probe` and `coop mxiii leave` use the read already.
- The read (`game/camps.h`) asks the game's own camp list. The camp list screen (`FUN_141f65980`) calls
  `FUN_141d1d650(zones, region, type, out, false)`, which returns the ZoneCampTable rows of that region and CampType
  that hold an active row: a camp's rows are the ZoneEnvSpawn rows whose `TargetCamp` names it (the zone manager's
  `+0x550` map, built by `FUN_141d18100`), and a row is active when its `ESBZoneEnvActiveState` is Active (1), read from
  the live env object (`+0x21c`, set by `FSBZoneEnvRegister` through `FUN_141fdf900`) for a row of the zone EVE stands
  in and from the zone's stored record (`+0x24`) for the others.
  - The game thread checks the client is in game, with no warp, respawn or logic task in flight, every 250 ms, and then
    calls that function every 2 s with no region (every region) once for each travel type (SimplyCamp, FullCamp,
    Tetrapod, PhoneBooth), frees each list with the game's `FMemory::Free` (`0x14261adb0`) and reads the names from the
    game's name pool. It reads the list again at once in a new world, and drops it when the client leaves the game (a
    load), so a list never outlives its save.
  - It also reads the camp EVE respawns at: her FSBActor's `+0x26d0`, which the respawn (`FUN_141b0f8f0`) reads, and
    that row's `TargetCamp` (`+0x270`). `+0x26d0` is the ZoneEnvSpawn row of her last rest or fast-travel arrival: in
    warp phase 0xd the client tick (`FUN_141cd0b30`) passes the travel's camp and its first row to the arrival
    (`FUN_141a8afe0`), which writes it there, since every camp travel (`FUN_141cdd7b0`) sets the request's arrival flag
    (client `+0xa22`).
  - It runs out of line under its own SEH latch; `coop-status.txt` carries it as
    `activated=<n>:<camp>,... rested=<camp>`, or `activated=none:<why>`.
- The game's ReturnToCamp job (`FUN_141b2b000`) takes another camp: effect action 26 (`FUN_141bc7af0`) gives it the
  FSBActor's `+0x2738`, which the camp arrival (`FUN_141a8afe0`) writes only for a Tetrapod camp, so that job returns
  EVE to her last Tetrapod. The mod does not use it.
- After an accepted call, the native part reads the game's warp block every 250 ms: `pending`, `warping`, `arrived`,
  or `refused:stuck` when the warp has not started 10 s after the call. `coop status` shows it as `travel=` on the
  engine line, and `coop-link.log` has one line per call and per state.
- The guards, read before the request and again before each call: a guest in a session, on a co-op save, her EVE
  alive, no warp or respawn under way, the game not paused and not in photo mode or a menu, no Night Operation run, no
  cutscene in her game, and while shared enemies run no boss fight and no enemy in battle within 30 m on her side (the
  `fight=` line's `boss=` and `battle=`), and 10 s since the last accepted travel.

## The teleport screen's extra tabs

The between-regions teleport screen, `WB_AreaTeleport_Set`, has 7 tabs, and an 8th active Tetrapod never shows. The Region
logic (`FSBUILogic` type 0xBC, vtable `0x145c3eb08`) fills its tab array once per open and holds child logic objects of
type 0xBD, not widgets. A node exists only for a widget in the list of 0x2C records that `FUN_14252de30` builds from the
widget's class properties. `AddChildSBUserWidget` and `CreateDynamicChildUserWidget` discard their records, so a tab made
at run time gets no node and no camp.

`ui/region_tabs.lua` hooks the Set's `Construct` and makes tabs 8 and 9 with `CreateDynamicChildUserWidget`, with `TabCount`
and `TabName` set (`WB_AreaTeleport_Tab_8` and so on, as the Set stores for its own). The trailing spacer is removed first
and added back after them. Each tab starts collapsed. The game shows a tab only through its logic (`FUN_141f690e0` sets
each filled tab to `SelfHitTestInvisible` and each surplus one to `Collapsed`), so a tab that got no node stays hidden and
takes no focus. That is the fallback for every failure below.

`FUN_141fc4d20` builds the root node, calls its vtable +0x30, and only then walks the records (`0x141fc4e5a`). The native
part swaps that slot, `.rdata` `0x145c3eb38`, from `FUN_141f66a00` to a hook, once a run, by the same aligned
compare-and-swap as [the spawn filter](shared-enemies.md#the-spawn-filter). No instruction byte changes. The hook acts only when its return
address is `0x141fc4e21`, the root's call: the other call site, a child's at `0x141fc4fa2`, holds a pointer into the list
that a grow would leave dangling. It reads the list's address from `0x141fc4d20`'s fifth argument on the stack
(`[rbp+0x50]`, 0xb8 above the hook's return address). The list must look sane and hold at least one child of
`HB_AreaTeleportRoot`, otherwise nothing changes. That child's class is the tab class. Each panel child of that class with
no record then gets what `FUN_1425303c0` gives a class-property widget: `+0x4d0 = 0xBD`, `FUN_1425315e0` and a GUID from
`FUN_142269830`. Its record `{name, guid, 0xBD, node+0x44}` is appended with the count raised before the grow
(`FUN_1418fc350`), as the game's own code does. Node creation, the delegates, the array and the camp list then run unchanged.

Surplus tabs stay collapsed by `FUN_141f690e0`, so a save with 8 regions shows 8 tabs. The row is `HB_AreaTeleportRoot`, a
horizontal ScrollBox that ships with `ScrollBarVisibility` `Hidden`. A tab is 410 units wide in the row and the space is
3528, so 8 tabs fit in 3340 and 9 need 3750. The Lua sets `SetClipping(1)`, `SetScrollBarVisibility(0)` and
`SetScrollbarThickness` once. The engine collapses the bar while nothing overflows. The bar keeps the engine's default
look, since `WidgetBarStyle` applies only when the Slate widget is built.

There is no tab 10. While a newly activated camp's tab plays `Unlock`, the logic's `+0x128` stays set (`0x141f67478` sets
it, `0x141f68f05` clears it once the unlock list is empty), and `FUN_141f67cc0` returns early on it, which blocks the hold
and the close. A 10th tab would start at about 3700, wholly outside the row at scroll 0. From UE 4.26's source, Slate then
does not paint it, it gets no tick, and its animation does not advance, so the lock would never clear. That engine step
has not been run in game. With 9 tabs the row scrolls only 222 units, so every 410-wide tab stays partly painted.

Which camp a hold takes comes from `+0xb4`, which the handler `FUN_141f68750` sets from the last `_` token of a
`NotifyBlueprint` string. The Set's `Construct` binds its `EventFocusSlotN` chain for Tab_1 to Tab_7 only, so a focus on tab 8
would leave `+0xb4` on the last vanilla tab and a keyboard or gamepad hold would travel to that tab's camp. The Lua hooks
the Tab's `EventWidgetFocusActive`: for `TabCount` above 7 it calls `ParentWidget:NotifyBlueprint(TabName)`. The focus hook
is registered before the `Construct` hook, and a failed send collapses that tab. The focus hook keeps running after coop
off and after a failure, for tabs already on screen. A mouse press takes `+0xb4` from the slot's own `+0x2f4` through the slot's
delegate. An out-of-range `+0xb4` can start no hold: `FUN_141f67d80` checks it against the array's count.

The game can unload a Blueprint class that nothing references, and a class loaded again would have no hook. A rooted
instance of the Set class (`StellarCoop_RegionTabsKeeper`, never added to a screen) holds both classes. The asset load and
the hooks run once a Lua load, at the first tick with a player controller.

The slot goes back at coop off and after a fault in the hook, by a compare-and-swap from the hook only. The DLL is pinned
and is never unloaded, so nothing restores the slot at unload, as with the spawn filter. The feature writes only to UI
objects and the records list: no save, trophy, inventory or table write. The `0xb8` offset and every address hold only on
build 24463856, and the hook is never installed off the pinned build.

## A player down

Each game reads its own EVE's life state with its vitals (`life=` in `coop status`) and the friend's from her vit line:
down in life state 3 to 5 or at 0 HP, alive in 1 or 6, unknown in any other state or when no vit line came for 3 s. The
native worker hands the friend's state to the shared fight's job as a local message, on each change and once a second.
It never goes on the wire.

- On the host, while the guest's EVE is down, each same-place pair she owns comes back to the host at the next turn,
  guards or not, if the enemy stands within 30 m of the host's EVE, and stays his while she is down. While the host's
  EVE is down and hers is alive, his common pairs within 30 m of her ghost go to her once the 4 s hold and the busy
  guards allow it. Bosses stay the host's. An unknown state changes nothing, and `aggro=host` keeps every pair with the
  host. Each of these hand-overs writes one log line.
- The 30 m limit is there for achievements: the game that takes an enemy forces its target onto its own EVE, which makes
  that EVE the enemy's last player, and a kill counts for its last player from any distance. A pair already where the
  down rule puts it stays there, so nothing is handed to the down EVE.
- While the host's EVE is down, the host drops the guest's claims on boss pairs. Their numbers are still acknowledged,
  so her copy's HP goes back to the host's. The host's respawn resets the boss in his world and her copy follows, as a
  death ends a boss fight in solo play.
- A down EVE takes no part in a kill through the 30 m clause (see [Achievements](safety.md#achievements)).

### Revive

The revive runs on the downed player's side (`session/group.lua`, every 250 ms) and sends nothing: her game reads its
own state, the friend's vitals and the friend's ghost. The friend's game calls nothing.

- These conditions must hold for 3 s with no gap: the downed player's `revive=on`; her life state 3 and the death
  screen's animation playing (the lookup Night Operation's solo run uses, in `core/unreal.lua`); `warp=idle` on the
  engine line (no respawn or warp in flight, read by the native part on the game thread); the friend linked, with vitals
  alive; the friend's ghost on her map within 2 m across and 1 m up or down of her EVE's mesh; `boss=0` on the
  `fight=` line (shared enemies running and no boss fight on her side, the 10 s after a host's `bstart` included); a
  standalone game (`KismetSystemLibrary::IsStandalone`, since in net mode 3 the call would go to a server); and no
  Night Operation probe rule set (with one, the respawn would spend a life count).
- Her game then calls `ServerRequest_ActorRespawn(<her EVE's id>, false)` on her player controller: the game's in-place
  respawn, with no camp warp and no zone reset. The game refills the recovery items as at a camp respawn. If her life
  state has not moved 2 s later and every condition holds again, `ServerRequest_ActorRevival` follows once. One call
  per death.
- A death screen that still plays over a living EVE is hidden, as Survival Protocol hides it, and shown again at the
  next death, at the end of the session, when the revive turns off for the run and at `coop off`.
- The log gives one `revive result` line: the life state, HP and death screen before and after, and whether the EVE
  pawn is the same.
- The friend's game shows its notices from her vitals: `<name> is down. Stand next to them for 3 s to revive them.`
  once per death, while the friend's own EVE is alive, on her map and outside a boss fight; and `You revived <name>.`
  when her vitals turn alive while the friend's EVE stands within 3 m of her ghost.
- `coop revive test` makes the same call alone, at the death screen of a co-op save outside a session, for the first
  in-game check.
- With both players down, nobody can revive. Each respawns at a camp in their own game, each world resets on its own,
  and same spawns brings the guest's enemies back to the host's set.
- During a Night Operation run (`nightop/run.lua`), the run owns the revive. The 3 s rule and the friend's notices
  wait; the run says `You revived <name>.` itself when the partner's own hold was full. A death is a down only with
  `revive=on`. The run asks `session/group.lua` for the call (`night_revive`) when the partner's night line says her
  interact key was held next to the downed EVE for 3 s, or for `coop nightop revive`, which first needs the body
  within 2 m across and 1 m up or down of the last place where the EVE's movement read walking. The call then has
  `revive=on` and the guards of `coop revive test` (life 3 to 5, the death screen, `warp=idle`, standalone, no probe
  rule), none of the friend's distance or the shared fight, and the same fallback, result line and hidden death
  screen. See [Down and revive](../night-operation.md#down-and-revive).

## Camp rests in a shared area

Either player may rest. Nothing blocks the guest's rest, since a block would need a hook on the camp interaction. A
rest resets only the resting player's own game.

- The host's rest resets his zone. Same spawns sees the spawn manager's reset states and moves its epoch, and the
  guest's game follows the host's enemy set: full HP and the host's positions for her pairs, and the rows of his that
  she lacks created on her side.
- The guest's rest heals her and resets her own game. In the zone she shares with the host (his epoch line's zone,
  his ghost within 100 m), same spawns then removes again each enemy she respawned that the host's game lacks, so her
  rest brings no enemy back there. Elsewhere, or with same spawns off, her rest is the game's own.
- The guest's Lua reads `epoch=<zone>/<n>/<resets>` on the `fight=` line. The host's `n` moving in the same zone,
  while his vitals read alive and he was not down in the last 10 s, gives
  `Enemies are back: the area reset in <host>'s game.` Her own `resets` moving while same spawns run, after her EVE
  was alive for 10 s, gives `Shared area: only <host>'s camp rest brings its enemies back.` On the guest a reset counts
  only in the host's zone while his ghost stands within 100 m. A respawn after a death gives neither notice.

## Cutscene wait

Each game looks once a second, while linked, for the game's theater observers (`SBTheaterLevelSequenceObserver`). A
cutscene plays while one of them has a valid sequence player whose `IsPlaying()` is true. Finding the observers walks
every object (25 to 80 ms on the game thread), so the walk runs only when the set of playing level sequence actors
changes (those actors come from the engine's class hash, a fraction of a millisecond), and the observer found is kept. A
looping sequence with no theater costs one walk and one line, `cutscene: no theater for the playing sequences <names>`.
The class hash reads EVE's world, or the SB player controller's when there is no EVE; with neither (the title screen, a
load) nothing is read. Up to 0.6.0-beta.1 the walk ran every second while linked, a frozen frame each second. The log
says `cutscene on: <sequence>` and `cutscene off`. The player controller's cinematic flag is not in this build's
reflection data, so Lua cannot read it.

While a cutscene plays in the host's game and its own photo state is `0`, the host's Lua writes `c` as its photo state,
and its photo line carries `c`. The guest's Lua writes `cut=1` in `coop-state.txt` while her `cutscene_wait` is on and
the host's ghost is on her map. Her native part then holds the photo sync pause for that `c`, with the photo pause's
release rules and `photo_freeze_max`; `photo_sync` plays no part in it. The native part shows no notice for it, and her
Lua shows one in her language, once per pause. A cutscene in the guest's game pauses nothing on the host's side.
Whether every story scene, dialogue and boss intro runs through a theater observer has not been checked in game yet.
