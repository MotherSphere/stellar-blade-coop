# Group play: how it works

The player's side is in [Playing with a friend](../players/playing-with-a-friend.md), and the teleport screen in
[Interface](../players/interface.md#teleport-screen).

## Shared quests

Shared quests (`shared_quests`, experimental, on by default, not tested in game yet) move the guest's quests to the
host's state through the game's own quest functions, one step at a time, for the steps the two players make together.
`game/quests/sync.h` holds the line format, the quest table and each side's rules; `game/quests/engine.h` holds the
reads and calls on the game's quest data and the worker's side.

The game's quest manager runs on the game thread, so the mod's pass does too: every 250 ms `coop_tick` reads the local
player's quest unit (the quest manager at `0x147037428`, its unit from `FUN_141c5fad0`) under the shared quests' own SEH
latch. The pass walks the unit's three quest arrays (in progress, complete, failed) and its ID map, and for each shared
quest reads its state, its active group and the state of each task the game made for it. Before each pass and each call
it checks that it is not on the game's logic worker thread (whose ID the game keeps at `0x1470683b0`) and that the save
is still the co-op save it started on: another save ends the side with `SBQ29 off slot` (the worker starts a new one
on the next co-op save), while a load (the title screen, a map change) only pauses it.

- In an online session of more than 2 players, the host's side runs one `quest::Host` per guest linked past the
  handshake, in the order they came. The pass reads his quests once and feeds every Host. Each Host keeps its guest's
  `h` lines in the one record of the co-op slot. It sends her our `on`, her own snapshot and her lines. A guest who
  comes gets a Host and our `on` line; one who leaves loses hers. Neither starts the side again. Only the pair's step
  lines are taken (story together runs within the pair): the host's game makes a step the pair made first. His
  next read brings it to the others. Any other guest sends none. Her quest stays ahead of the host's until his game
  makes that step. The host's ahead notice names her (`quest_note=` carries her SteamID).
- The host reads his quests. Each quest whose state changed goes to the guest as one reliable line on channel 2 with
  the whole state, numbered per quest, so a repeated or late line changes nothing: `SBQ29 q <gen> <seq> <id> <state>
  <acquire mark> <finished groups> <tasks done> <done mark>`. A group or a task is named by its place (container and
  position), which the game builds the same on both PCs from the same tables. He also makes a step the guest made
  first. Her `SBQ29 step <gen> <seq> <id> <state> <acquire mark> <finished groups> <tasks done> <done mark> <zone>`
  line holds her quest's state after the step and the zone she made it in. His pass judges it with `accept()`, then
  `apply()` makes it on his own unit (see
  [Story together: how it works](../story/together-internals.md#quest-steps-the-guest-makes-first)).
- Each step carries a mark that says where it may be made: `-` anywhere (no zone event, or only quest, item, UI or hint
  events), `t` in the zones the game's tables give for its events (spawns, despawns, environment changes, scenes),
  `z<n>` in the zone where the host stood when its pass saw the step (for the 33 steps the tables cannot place), `?` for
  such a step the host's pass did not see, `K` for a kill task, `I` for an item task and `#` for a quest the host
  denies. `kItems` lists the 19 item tasks, which are never forced: every task of a Request whose hand-in removes an
  item (the board pays the reward with no item check), plus each RequireItem task in count mode 1 in a container of
  several tasks (the game puts it back in progress when her count drops while its group is open). The table that gives
  each step's class, zones and events is built into `game/quests/sync.h` from the tables of build 26123051; another game
  build needs it built again.
- The guest's pass compares each host line with her own quest and plans the next forward step: an Epic or Sub quest
  she lacks is acquired by ID (`FUN_141c5e170`, the call a quest zone event makes), a Request on her board is accepted
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

The guest's travel to the host (`online/group/travel.lua`, the camps and spot lines, `game/travel.h` and the native
call) moves only the guest's EVE and changes nothing in the host's game. It has not been tested in game yet. On the
host's map it is [the spot warp](#the-spot-warp). On another map it is the camp travel below, then the spot warp once
she stands on his map.

- The guest's Lua sends `camps? <id>` when she presses F7 (`follow_key`) or types `coop travel host` while the host is
  on another map. With `follow_host=always` it sends one 5 s after the host arrived somewhere new. It sends one at
  most each 2.5 s. A camp travel whose host came to her map before the call asks his spot instead.
- In an online session of more than 2 players, each guest asks the host only and reads the host's map and place from the
  ghost in the slot of the host's `member=` line (slot 0, `online/partner/wiring.lua`'s puppet, on every guest). The
  host's Lua answers while any guest is linked, by the number its native part gave each request. That part sends the
  answer to the guest who asked alone, with her own number (see [The camps
  lines](steam-link-internals.md#the-camps-lines)).
- The host's Lua answers from the game's spawn points on its map: those named after one of the travel camps of its
  world, read once a map, sorted by distance to the host's EVE. The answer names the world and the 8 nearest, or
  `none` with `title`, `loading`, `nocamp` or `busy` (a warp or respawn of the host's under way).
- The travel camps are the 120 ZoneCampTable rows of type FullCamp, SimplyCamp, PhoneBooth or Tetrapod that lead to
  exactly one story world in build 26123051. Autosave volumes, camps that lead to several worlds or none, and the camps
  of the developer test worlds are left out. The guest's game uses a camp of the answer only if it is in her own table
  under the host's world, her save has activated it, and it already exists as a name in her game (`FName` with
  `FNAME_Find`, which never makes one).
- Her Lua checks its guards again, then hands the camp's name to the native part. On the game thread, the native part
  builds the game's 0x60-byte camp request as the game's ReturnToCamp job does and calls the game's fast travel
  (`0x141cdfbd0`), out of line under its own SEH latch. Before the call it reads the globals that the call's getters
  reach, the client's flow and phase, any warp or respawn in flight, and whether the local player's EVE is in the
  world. It makes at most 3 calls in 10 s and none for 10 s after an accepted one.
- A return of 0 is the game's refusal, and the guest's Lua tries the next camp of the answer.
- The game's fast travel does not check whether her save has activated the camp (`game/travel.h`), and activating a camp
  counts toward the game's camp achievements (`Trophy_Activate_AllCamp` and the camp rows of AchievementTable). Her Lua
  therefore takes only a camp that the native read of her activated camps lists (below). With no read at that moment
  (a load, the title), the travel is refused with `no read of the camps this save has activated (<why>)`.
- `online/group/wiring.lua` passes `follow=true` to `online/group/travel.lua`. Without it, every travel is refused
  before `camps?` is sent (`travel refused: the follow is off (no o.follow)` in `UE4SS.log`, and the failed notice), and
  no offer shows. `coop travel probe` and `coop mxiii leave` use the same read.
- The read (`game/camps.h`) asks the game's own camp list. The camp list screen (`FUN_141f69530`) calls
  `FUN_141d1f860(zones, region, type, out, false)`, which returns the ZoneCampTable rows of that region and CampType
  that hold an active row: a camp's rows are the ZoneEnvSpawn rows whose `TargetCamp` names it (the zone manager's
  `+0x550` map, built by `FUN_141d1a310`), and a row is active when its `ESBZoneEnvActiveState` is Active (1), read from
  the live env object (`+0x21c`, set by `FSBZoneEnvRegister` through `FUN_141fe3b20`) for a row of the zone EVE stands
  in and from the zone's stored record (`+0x24`) for the others.
  - The game thread checks the client is in game, with no warp, respawn or logic task in flight, every 250 ms, and then
    calls that function every 2 s with no region (every region) once for each travel type (SimplyCamp, FullCamp,
    Tetrapod, PhoneBooth), frees each list with the game's `FMemory::Free` (`0x1426207f0`) and reads the names from the
    game's name pool. It reads the list again at once in a new world, and drops it when the client leaves the game (a
    load), so a list never outlives its save.
  - It also reads the camp EVE respawns at: her FSBActor's `+0x26d0`, which the respawn (`FUN_141b10b30`) reads, and
    that row's `TargetCamp` (`+0x270`). `+0x26d0` is the ZoneEnvSpawn row of her last rest or fast-travel arrival: in
    warp phase 0xd the client tick (`FUN_141cd2f50`) passes the travel's camp and its first row to the arrival
    (`FUN_141a8bef0`), which writes it there, since every camp travel (`FUN_141cdfbd0`) sets the request's arrival flag
    (client `+0xa22`).
  - It runs out of line under its own SEH latch; `coop-status.txt` carries it as
    `activated=<n>:<camp>,... rested=<camp>`, or `activated=none:<why>`.
- The game's ReturnToCamp job (`FUN_141b2c240`) takes another camp: effect action 26 (`FUN_141bc8d40`) gives it the
  FSBActor's `+0x2738`, which the camp arrival (`FUN_141a8bef0`) writes only for a Tetrapod camp, so that job returns
  EVE to her last Tetrapod. The mod does not use it.
- After an accepted call, the native part reads the game's warp block every 250 ms: `pending`, `warping`, `arrived`,
  or `refused:stuck` when the warp has not started 10 s after the call. `coop status` shows it as `travel=` on the
  engine line, and `coop-link.log` has one line per call and per state.
- The guards, read before the request and again before each call: a guest in a session, on a co-op save, her EVE
  alive, no warp or respawn under way, the game not paused and not in photo mode or a menu, no Night Operation run, no
  cutscene in her game. While shared enemies run, no boss fight and no enemy in battle within 30 m on her side (the
  `fight=` line's `boss=` and `battle=`). No [solo area](#solo-areas) on her side (`zonetype=` on her engine line) or
  on the host's (his vitals' zone type). 10 s since the last accepted travel.

### The spot warp

The spot warp puts EVE on another member's last ground point through the game's own position warp, with no camp. It
serves the follow on the host's map, the second hop after a camp travel and the
[way back after a death](#back-to-a-friend-after-a-death).

- Every member's Lua keeps its last ground point while linked: each 250 ms tick, while its EVE's
  `CharacterMovement.MovementMode` is Walking (1) or NavWalking (2), her `K2_GetActorLocation` and the yaw of her
  `K2_GetActorRotation` in whole centimetres and degrees. A map change or a new EVE drops it.
- The guest's Lua asks on the host's map when F7 comes more than 5 m from his ghost. A camp travel to his map asks by
  itself once it reads `arrived` there and the guards pass (the 10 s after the accepted call among them), for up to
  30 s after the arrival, with no notice. Either sends `spot? <id> <SteamID>` to its native part, which sends
  `SBC29 spot? <id>` to that member (see [The spot lines](steam-link-internals.md#the-spot-lines)).
- The member asked answers each new number of its status's `spot?=` line once: `spot <n> <x> <y> <z> <yaw>` when its
  point is at most 10 s old and on its current map, else `spot <n> none <why>` with the first of `title`, `loading`
  (no EVE), `busy` (a cutscene in its game), `solo`, `boss` (a `boss=` other than 0 on its `fight=` line), `busy` (no
  `warp=idle`) and `air`. A guest outside the pair has no `boss=`, since her shared fight never runs, so her answer
  skips that check.
- The asker reads the answer from its `spot=` status line. `air` gives its own notice, `title` the failed one, any
  other `none` and no answer within 10 s the busy one. A point passes the guards again and the check that the target
  still stands on her map. Then Lua asks `travel spot <x> <y> <z> <yaw>`.
- The game thread makes the call under the camp travel's latch, count and watch: 3 calls in 10 s at most, none for
  10 s after an accepted one, the same reads before it. It refuses with `refused:solo` while its own zone type is 2 to
  6. It builds the 0x78-byte record that the game's WarpSBActor message (`FUN_141ac3d80`) builds: zero but `+0x18` our
  EVE's GUID, `+0x38` -1.0, `+0x54` the location and `+0x60` the rotation (pitch 0, the yaw, roll 0). It then calls
  the position warp `FUN_141cdfe70(client, record)`. That function returns 1 once it wrote the warp block at client
  `+0xa20`, 0 when our EVE is not in the world's actor map or when `FUN_141cf7630` reads a Boss Challenge zone. It
  copies the record's `+0x09` to the camp arrival flag (client `+0xa22`). The record keeps 0 there, so the arrival
  leaves the respawn camp alone. `ServerRequest_WarpPosition` is never called.
- `coop-link.log` has `travel spot call <x> <y> <z> <yaw> ret=<0|1> other=<0|1>` or `travel spot refused: <why>`, then
  the watch's states as for a camp travel.
- `coop travel spot [<world>] <x> <y> <z>` makes the same call alone, with yaw 0, under `coop travel probe`'s guards
  (solo, a co-op save). With a world of `core/worlds.lua`, found with `FNAME_Find`, its FName goes to the record's
  `+0x00`. `FUN_141cdfe70` copies that to client `+0xa6c` and sets `+0xa26` when it is not None and differs from the
  client's world at `+0x60`. Where EVE lands then is a question for the in-game test.

## The teleport screen's extra tabs

The between-regions teleport screen, `WB_AreaTeleport_Set`, has 7 tabs, and an 8th active Tetrapod never shows. The Region
logic (`FSBUILogic` type 0xBC, vtable `0x145c44948`) fills its tab array once per open and holds child logic objects of
type 0xBD, not widgets. A node exists only for a widget in the list of 0x2C records that `FUN_142533870` builds from the
widget's class properties. `AddChildSBUserWidget` and `CreateDynamicChildUserWidget` discard their records, so a tab made
at run time gets no node and no camp.

`online/group/region_tabs.lua` hooks the Set's `Construct` and makes tabs 8 and 9 with `CreateDynamicChildUserWidget`,
with `TabCount` and `TabName` set (`WB_AreaTeleport_Tab_8` and so on, as the Set stores for its own). The trailing
spacer is removed first and added back after them. Each tab starts collapsed. The game shows a tab only through its
logic (`FUN_141f6cc40` sets each filled tab to `SelfHitTestInvisible` and each surplus one to `Collapsed`), so a tab
that got no node stays hidden and takes no focus. That is the fallback for every failure below.

`FUN_141fc8f40` builds the root node, calls its vtable +0x30, and only then walks the records (`0x141fc907a`). The native
part swaps that slot, `.rdata` `0x145c44978`, from `FUN_141f6a560` to a hook, once a run, by the same aligned
compare-and-swap as [the spawn filter](../fight/enemies-internals.md#the-spawn-filter). No instruction byte changes. The hook acts only when its return
address is `0x141fc9041`, the root's call: the other call site, a child's at `0x141fc91c2`, holds a pointer into the list
that a grow would leave dangling. It reads the list's address from `0x141fc8f40`'s fifth argument on the stack
(`[rbp+0x50]`, 0xb8 above the hook's return address). The list must look sane and hold at least one child of
`HB_AreaTeleportRoot`, otherwise nothing changes. That child's class is the tab class. Each panel child of that class with
no record then gets what `FUN_142535e00` gives a class-property widget: `+0x4d0 = 0xBD`, `FUN_142537020` and a GUID from
`FUN_14226eeb0`. Its record `{name, guid, 0xBD, node+0x44}` is appended with the count raised before the grow
(`FUN_1418fc4e0`), as the game's own code does. Node creation, the delegates, the array and the camp list then run unchanged.

Surplus tabs stay collapsed by `FUN_141f6cc40`, so a save with 8 regions shows 8 tabs. The row is `HB_AreaTeleportRoot`, a
horizontal ScrollBox that ships with `ScrollBarVisibility` `Hidden`. A tab is 410 units wide in the row and the space is
3528, so 8 tabs fit in 3340 and 9 need 3750. The Lua sets `SetClipping(1)`, `SetScrollBarVisibility(0)` and
`SetScrollbarThickness` once. The engine collapses the bar while nothing overflows. The bar keeps the engine's default
look, since `WidgetBarStyle` applies only when the Slate widget is built.

There is no tab 10. While a newly activated camp's tab plays `Unlock`, the logic's `+0x128` stays set (`0x141f6afd8` sets
it, `0x141f6ca65` clears it once the unlock list is empty), and `FUN_141f6b820` returns early on it, which blocks the hold
and the close. A 10th tab would start at about 3700, wholly outside the row at scroll 0. From UE 4.26's source, Slate then
does not paint it, it gets no tick, and its animation does not advance, so the lock would never clear. That engine step
has not been run in game. With 9 tabs the row scrolls only 222 units, so every 410-wide tab stays partly painted.

Which camp a hold takes comes from `+0xb4`, which the handler `FUN_141f6c2b0` sets from the last `_` token of a
`NotifyBlueprint` string. The Set's `Construct` binds its `EventFocusSlotN` chain for Tab_1 to Tab_7 only, so a focus on tab 8
would leave `+0xb4` on the last vanilla tab and a keyboard or gamepad hold would travel to that tab's camp. The Lua hooks
the Tab's `EventWidgetFocusActive`: for `TabCount` above 7 it calls `ParentWidget:NotifyBlueprint(TabName)`. The focus hook
is registered before the `Construct` hook, and a failed send collapses that tab. The focus hook keeps running after coop
off and after a failure, for tabs already on screen. A mouse press takes `+0xb4` from the slot's own `+0x2f4` through the slot's
delegate. An out-of-range `+0xb4` can start no hold: `FUN_141f6b8e0` checks it against the array's count.

The game can unload a Blueprint class that nothing references, and a class loaded again would have no hook. A rooted
instance of the Set class (`StellarCoop_RegionTabsKeeper`, never added to a screen) holds both classes. The asset load and
the hooks run once a Lua load, at the first tick with a player controller.

The slot goes back at coop off and after a fault in the hook, by a compare-and-swap from the hook only. The DLL is pinned
and is never unloaded, so nothing restores the slot at unload, as with the spawn filter. The feature writes only to UI
objects and the records list: no save, trophy, inventory or table write. The `0xb8` offset and the addresses here are
build 26123051's, and the hook is never installed off the pinned build.

## A player down

Each game reads its own EVE's life state with its vitals (`life=` in `coop status`) and the friend's from her vit line:
down in life state 3 to 5 or at 0 HP, alive in 1 or 6, unknown in any other state or when no vit line came for 3 s. In
an online session of more than 2 players, Lua reads each member's from her `vit=` status line (the slot-0 member's
from `mate=`). The native worker hands the pair's state to the shared fight's job as a local message, on each change
and once a second. It never goes on the wire. The native read (`link/protocol.h`'s `life_of`) takes life state 2 as
Coma before the 0 HP rule, since a Coma EVE has 0 HP. The boss claim rule below counts a member in Coma as up; the
hand-overs count her as down.

- On the host, while the guest's EVE is down, each same-place pair she owns comes back to the host at the next turn,
  guards or not, if the enemy stands within 30 m of the host's EVE, and stays his while she is down. While the host's
  EVE is down and hers is alive, his common pairs within 30 m of her ghost go to her once the 4 s hold and the busy
  guards allow it. Bosses go the same way while the boss pilot runs
  ([Boss hand-overs](../fight/enemies-internals.md#boss-hand-overs)). An unknown state changes nothing. `aggro=host`
  keeps every pair with the host. Each of these hand-overs writes one log line.
- The 30 m limit is there for achievements: the game that takes an enemy forces its target onto its own EVE, which makes
  that EVE the enemy's last player, and a kill counts for its last player from any distance. A pair already where the
  down rule puts it stays there, so nothing is handed to the down EVE.
- While the host's EVE is down (life state 3 to 5) and no other member is alive or in Coma by her vitals, the host
  drops the guest's claims on boss pairs (`fight claim dropped hguid=<n> on our boss while our EVE is down`, once a
  down). Their numbers are still acknowledged, so her copy's HP goes back to the host's. While she stands, her claims
  count as before. The engine sets this before it drains her lines and again after each of her vitals in the drain,
  so a claim is judged on the vitals that came before it. The host's camp respawn resets the boss in his world. Her
  copy follows, as a death ends a boss fight in solo play.
- A player down in a shared boss fight watches a living member instead of the death screen
  ([Spectate](../fight/enemies-internals.md#spectate)). Group's revive and F7's way back need `boss=0`, so neither
  runs while spectate does.
- A down EVE takes no part in a kill through the 30 m clause (see [Achievements](../dev/safety.md#achievements)).

### Revive

The revive runs on the downed player's side (`online/group/group.lua`, every 250 ms) and sends nothing: her game reads
its own state, the friend's vitals and the friend's ghost. The friend's game calls nothing. In an online session of more
than 2 players, every member past the handshake counts as a friend: her vitals from `vit=` (or `mate=` for slot 0) and
her ghost from her slot (`online/partner/wiring.lua`'s puppet for slot 0, `online/partner/ghosts.lua`'s for slots 1 to
6). The nearest member alive within the distance revives; the wait notice names the first member alive on her map while
none is near enough.

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
  next death, at the end of the session, when the revive turns off for the run and at `coop off`. While it is hidden,
  `coop-death-screen.txt` keeps its visibility from before and its address. After a Lua reload (Ctrl+R), the new
  load's first tick reads that file. If SB's death screen is still the widget at that address and reads Hidden, the
  new load takes it over (`revive: death screen hidden by an earlier Lua load, taken over`) and shows it again at the
  same moments. Otherwise the file is removed and the widget left as it is.
- The log gives one `revive result` line: the life state, HP and death screen before and after, and whether the EVE
  pawn is the same.
- The friend's game shows its notices from her vitals: `<name> is down. Stand next to them for 3 s to revive them.`
  once per death, while the friend's own EVE is alive, on her map and outside a boss fight; and `You revived <name>.`
  when her vitals turn alive while the friend's EVE stands within 3 m of her ghost. With more than 2 players, each
  game shows them for the host and the pair only (`host=` line's `id` and `pair`): a guest outside the pair has no
  `boss=0` on her `fight=` line, as her shared fight never runs, so her game never makes the call. Her own game logs
  `revive waits: no shared fight` and shows no wait notice. It shows no down notice either, for the same reason.
- A [solo area](#solo-areas) stops the revive: on her side it waits (`revive waits: solo area`). A friend in one does
  not count as near (`friend in a solo area` when no other friend is). The friend's down notice waits while either
  side stands in one.
- `coop revive test` makes the same call alone, at the death screen of a co-op save outside a session, for the first
  in-game check.
- With both players down, nobody can revive. Each respawns at a camp in their own game, each world resets on its own,
  and same spawns brings the guest's enemies back to the host's set.
- During a Night Operation run (`online/modes/nightop/run.lua`), the run owns the revive. The 3 s rule and the friend's
  notices wait; the run says `You revived <name>.` itself when the partner's own hold was full. A death is a down only
  with `revive=on`. The run asks `online/group/group.lua` for the call (`night_revive`) when the partner's night line
  says her interact key was held next to the downed EVE for 3 s, or for `coop nightop revive`, which first needs the
  body within 2 m across and 1 m up or down of the last place where the EVE's movement read walking. The call then has
  `revive=on` and the guards of `coop revive test` (life 3 to 5, the death screen, `warp=idle`, standalone, no probe
  rule), none of the friend's distance or the shared fight, and the same fallback, result line and hidden death screen.
  See [Down and revive](modes/nightop.md#down-and-revive).

### Back to a friend after a death

The way back runs on the dead player's side (`online/group/group.lua`), with the revive's call and the
[spot warp](#the-spot-warp). It sends nothing but the spot warp's `spot?`.

- The target: on a guest the host (his `host=` line's member, else slot 0's); on the host the living guest on his map
  nearest his EVE (her ghost's feet), leaving out a guest whose ghost is not placed.
- The offer comes once per death while all of these hold: her life state 3 under the playing death screen, a co-op
  save (`slot=coop`), `revive=on`, no Night Operation run, `boss=0` on the `fight=` line, the target alive by her
  vitals on her map, no solo area on either side, no respawn call of hers in this death yet and none in the 10 s
  before it started. With `follow_key=none` or `follow_host=off` a log line takes the notice's place. With
  `follow_host=always` the notice says the 5 s. The call follows unless `follow_key` comes first.
- `follow_key` reaches it through `online/group/travel.lua`'s press, which asks the group first: while the offer
  shows, the key is the way back (or cancels `always`'s 5 s). At any other time the key is the follow.
- The call runs `coop revive test`'s guards held to life 3, then the revive's `ServerRequest_ActorRespawn(<her EVE's
  id>, false)` with its fallback, result line and hidden death screen. No `Revived by` notice follows: nobody revived
  her.
- Once her life reads 1 or 6 with `warp=idle` and the game not paused (10 s at most), her Lua asks the spot warp next
  to the target if the target is still linked, alive, on her map and outside a solo area. Otherwise one log line
  (`return: no warp, <why>`) and no warp. A respawn whose result line reads her EVE still down drops the warp
  (`return: no warp, the respawn did not take`). So does a new death before it (`down again before it`).
- The friend's 3 s revive marks nothing for the warp. A death has one respawn call, whichever of the friend's revive
  and `follow_key` comes first.

## Camp rests in a shared area

Any member may rest. Nothing blocks a guest's rest, since a block would need a hook on the camp interaction. With
`shared_world=on`, [a rest reaches the other members](#rests-between-members). With it off, a rest resets only the
resting player's own game, as below.

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
  only in the host's zone while his ghost stands within 100 m. A respawn after a death gives neither notice. These two
  notices show only with `shared_world=off`: with it on, the rested notice below takes their place.

### Rests between members

Each game reads the starts of the game's own camp process. Its Lua sends its own rests. Each receiver standing in that
zone makes the game's zone reset for its own EVE. This has not been tested in game yet.

- The game's camp process starts in `FUN_141ca7040`. That function refuses while world `+0x34` is 1. Otherwise it
  copies the camp request to world `+0x1a0` (its `+0x18` GUID to `+0x1b8`, its `+0x24` type to `+0x1c4`) and sets
  `+0x1a0` to 1. Type 0 (Interact) clears both in the same call. Types 1 (InteractWithResetZone) and 2
  (OnlyResetZone) keep them while the process runs.
- The game thread reads `+0x1a0` at each frame under the warp read's latch (`game/travel.h`'s `Rests`). A 0 to 1 edge
  with type 1 or 2 is a start. With our EVE's GUID (client `+0x58`, never 0) it is ours, with its type and area. The
  engine line shows `zonetype=<n> area=<zone|none> rest=<ours>:<area>:<type> starts=<n>`. `area=` is world `+0x90`
  only while the logic's zone (`+0x598` of the object at `0x1470373e0`) is the same, else `none`. `coop-link.log` has
  `zone reset start: type <t> guid <g> ours|another in <zone>` for each start.
- A start of ours sends `rest <area>` while linked with `shared_world=on`, on a co-op save, outside a solo area, with
  an area read: type 1 at once, type 2 only after our EVE read alive for 10 s (else it is a death's camp respawn).
  None goes within 10 s of our own `ServerRequest_ResetZone` call. The link adds our SteamID: a guest sends it to the
  host, the host to every guest. The host relays a guest's rest to the other guests, one each 2 s from each guest,
  only when it names her (see [The rest line](steam-link-internals.md#the-rest-line)).
- A received rest waits in a queue, one per zone. A zone reset in our game in the last 30 s (our own rest, a call
  already made) drops it. Each second the queue is read again. A rest is dropped with one log line
  (`rest: <why> (<zone> of member <SteamID> dropped)`) once the session ended, with `shared_world=off`, off a co-op
  save, outside its zone (`area=`), with no life read, in a solo area of ours, with no `boss=` and `battle=` on the
  `fight=` line (no shared fight in this game), in a game that is not standalone, or for a zone `FNAME_Find` does not
  know. It waits through a fight, a cutscene, a pause, no EVE, a respawn or warp, our EVE down, a GUID read as 0 or no
  controller, 60 s at most. Then the skipped notice.
- The call is `ServerRequest_ResetZone(<our EVE's GUID>, <the zone's FName>)` on our player controller, with the
  rested notice. Its exec (`0x14275eae0`) reads a uint32 GUID then an FName. The game then runs `FSBResetZone`: its Simulate
  (`FUN_141b128a0`, then `FUN_141ace080`) resets the zone only while the logic's `+0x598` names it. Its Execute
  (`FUN_141b2f470`) writes a type-2 camp request with GUID 0, which starts the camp process in our world. That start
  reads as another actor's, so it sends no rest line back.
- The stop latch: more than 3 starts within 30 s after one call end the calls for the Lua load, with one log line and
  the stop notice.
- `ServerRequest_ResetZone` and the other RPCs here are standalone only: in net mode 3 the call would go to a
  server.

## Cutscene wait

Each game looks once a second, while linked, for the game's theater observers (`SBTheaterLevelSequenceObserver`). A
cutscene plays while one of them has a valid sequence player whose `IsPlaying()` is true. Finding the observers walks
every object (25 to 80 ms on the game thread), so the walk runs only when the set of playing level sequence actors
changes (those actors come from the engine's class hash, a fraction of a millisecond), and the observer found is kept. A
looping sequence with no theater costs one walk and one line, `cutscene: no theater for the playing sequences <names>`.
The class hash reads EVE's world, or the SB player controller's when there is no EVE; with neither (the title screen, a
load) nothing is read. Up to 0.6.0-beta.1 the walk ran every second while linked, a frozen frame each second. With the
native part's `theater=` field (SB's own theater test) there is no walk; without it, as before. The log says
`cutscene on: <sequence>` and `cutscene off`. The player controller's cinematic flag is not in this build's
reflection data, so Lua cannot read it.

While a cutscene plays in the host's game and its own photo state is `0`, the host's Lua writes `c` as its photo state,
and its photo line carries `c`. The guest's Lua writes `cut=1` in `coop-state.txt` while her `cutscene_wait` is on and
the host's ghost (the one in the slot of the host's `member=` line) is on her map. Her native part then holds the photo
sync pause for that `c`, with the photo pause's release rules and `photo_freeze_max`; `photo_sync` plays no part in it.
With more than 2 players, the host's photo line pauses each guest that asks for it, the pair or not: a guest's native
part follows the host's line only (`Link::leader()`). With story together on, the pause is not held while a shared scene
starts or plays in her game or a scene line of the host's waits for her next pass (`story_scene`, see [Story together:
how it works](../story/together-internals.md#the-guests-side)). The native part shows no notice for it, and her Lua
shows one in her language, once per pause. A cutscene in the guest's game pauses nothing on the host's side. Whether
every story scene, dialogue and boss intro runs through a theater observer has not been checked in game yet.

## Solo areas

A zone of one player is a zone whose ZoneTable type is 2 to 6. The game's ESBZoneType (its value table at
`0x145e29730`) names them `Zone_TrainningRoom` (2), `Zone_SpiritRoom` (3), `Zone_TestZone` (4), `Zone_BossChallenge`
(5) and `Zone_Nikke` (6). 0 is `Zone_None` and 1 `Zone_Public`. `Link.solo()` in `core/link.lua` and `solo_zone()` in
`link/protocol.h` hold that rule. This has not been tested in game yet.

- The game thread reads our zone's type every 250 ms (`online/group/warp_game.inc`). It calls `FUN_141d01910`
  (`sbo::kCurrentZoneRow`) on a local copy of client `+0x68`, the zone's FName, as the game's `FUN_141cf7630` reads it
  before its Boss Challenge test. The call runs only in game (client `+0xa00` 2, `+0xb9c` 0xe), with the tables'
  global set, when those 8 bytes changed since its last call. It returns the zone's row after the row's first use
  (row `+8`, vfunc `+0x20`). Row `+0x25` is the type. The call has its own SEH latch: a fault gives `zonetype=0` for
  the run with one `coop-link.log` line and leaves the warp read on. A type above 6 goes out as 0, logged once per
  zone. The engine line shows `zonetype=<n>`. The log has `zone <alias>: type <n>` at each change.
- The type is the vit line's 13th number. Each game reads the others' types from their vitals.
- `online/group/group.lua` says each other member's stay once (`<name> is in <place>. Online play waits until they are
  back.`), then `<name> is back.` once her type reads 1. No vitals and type 0 keep the last state. The travel, the
  spot answer (`none solo`), the revive, the way back and the rests refuse a solo area on either side, as above. The
  guest asks no cutscene pause while the host or she stands in one.
- `online/partner/puppet.lua` hides the ghost of a member whose vitals read a solo type, the slot-0 puppet and the
  ghosts of `online/partner/ghosts.lua` alike. `UE4SS.log` says `Ghost hidden: she is in a solo area.` once a stay.
- `glue/steam.cpp` checks `Link::solo_pair()` each pass: our type, or the pair's last vit line's type, is a solo
  area. Story together and the shared fight then read the pair as unlinked, as on another map: the pair's `SBS` and
  fight lines are dropped and ours are not sent. A stay ends the shared fight (floors and scaling restored). A return
  starts it again. The shared world and the shared quests go on. `coop-link.log` says `online play paused toward the
  pair: a solo area` and `online play resumed toward the pair`. The pair's type counts whatever its age while the
  session holds, so a load or a few lost vit lines never resume the shared fight for a moment.
