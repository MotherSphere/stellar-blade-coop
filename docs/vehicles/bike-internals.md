# The bike: how it works

The player page is [vehicles/bike.md](bike.md). The bike is `vehicles/bike/ride.lua` (the part, the checks, the mount
and the dismount, the lean, the pose, the parked bike's place), `vehicles/bike/model.lua` (the riding model),
`vehicles/bike/park.lua` (the parked bike's rules, its record and its line), `vehicles/bike/stand.lua` (the parked
bike's actor), `vehicles/bike/paint.lua` (the paint for EVE's outfit), `vehicles/bike/others.lua` (the other players'
parked bikes), `vehicles/bike/fetch.lua` (the paid fetch at Xion), `vehicles/bike/commands.lua` (`coop bike`) and the
native part's `game/bike.h` with `vehicles/bike/bike_game.inc` and `bike_worker.inc` (the preload and the gate). It is
not tested in game yet. The addresses are build 26123051's.

## The preload

With `bike=on`, the ride's first 250 ms pass asks `bike load <clip>`; `bike=off` asks `bike free`. The native part loads
the bike's mesh and the riding clip in one request, the way SB loads EVE's custom animations (`0x1420b4ed0`, the call at
`0x1420b5238`): `FStreamableManager::RequestAsyncLoad`'s array form `0x1445c5440(manager, &handle, paths, delegate, 100,
0, 0, debug name)`, with priority 100 and `bManageActiveHandle` 0 as SB passes them. The manager is the asset manager's
`+0x178`; the asset manager is GEngine's (`0x1470e7eb8`) `+0x2a0`, read directly and refused when null (SB's
`UAssetManager::Get`, `0x143ff83b0`, stops the game then). The delegate is unbound.

SB drops its own handle at the end of `0x1420b4ed0` (its `ASBCharacter +0x36b8` holds the clip's `FSoftObjectPath`). SBO
keeps the returned `TSharedPtr` handle, so the garbage collector leaves both assets in memory. Every 250 ms the game
thread reads the handle's `bLoadCompleted` at `+0x10`, which SB's `CompleteLoad` (`0x1445c2af0`) sets once every path
loaded or failed; `+0x12` is `bCanceled`. Once it is set, each path is looked up with SB's
`FSoftObjectPath::ResolveObject` (`0x142b82f40`), which finds an object in memory and never loads one. Both found:
`bike=ready`. One missing: `bike=failed:missing_mesh` or `failed:missing_clip`, with the handle released. The release is
the `TSharedPtr`'s own end: the strong count at `+8` down, at 0 the controller's `DestroyObject` (vtable `+0`), then the
weak count at `+0xc` down, at 0 its deleting destructor (vtable `+8`).

The clip must be one of EVE's clips in object path form (`game/anim.h`'s `path_ok`), so the ride's play later takes it.
`Ride.CLIP` is the one place that names it. When the status line still reads `bike=off` 5 s after a `bike load`, the ask
was lost on the way and the ride asks again. The same clip asked again while it is held (a new Lua load) does nothing.

## The part on EVE

Once `bike=ready` and an EVE has been in the world for 2 s (the capture's own wait), `vehicles/bike/ride.lua` calls
`core/actors.lua`'s `attach`: one `SkeletalMeshComponent` showing `Adam_Vehicle_02`, attached KeepRelative to her main
mesh, collision off, single-node mode with no clip, so it keeps its reference pose. It sits at (1.53, 0.52, 2.95) cm
with a pitch of 0.69 degrees relative to her main mesh, from the attach tracks of the game's SD20 scene (riders on the
bike's bone `Base`). It starts hidden, with its component tick off and `VisibilityBasedAnimTickOption` 3
(`OnlyTickPoseWhenRendered`): its reference pose needs no tick and her mesh moves it, so it costs no tick a frame on
every EVE with `bike=on`. It carries the component tag `SBO_Bike` (`Ride.TAG`), written into its empty `ComponentTags`
and read back with `ComponentHasTag`. A tag that does not hold leaves the part in use for this Lua load. The log then
says `bike part tag SBO_Bike not written (<why>): a Ctrl+R will not find this part`. The log line
`bike part ready on EVE (made in <ms> ms)` gives the time. A part that cannot be made is not tried again on that EVE; a
mount says why.

After Ctrl+R the part is already there. The new Lua load's first tick (`self.restore`) looks among her components
(`K2_GetComponentsByClass`) for one that shows the bike's mesh and carries that tag. It hides it, keeps it as this
load's part and logs `bike part found on EVE (an earlier Lua load's), hidden`. This happens before any `bike=` word is
read, so it also holds when the preload reads `fault` or `failed:<why>`. With `bike=off`, the load's first 250 ms pass
removes it (`bike part removed from EVE`). An EVE that is not in the world at that tick gets the same look 2 s after
`bike=ready` (`bike part ready on EVE (found ...)`). A component on the bike's mesh without the tag belongs to another
mod: the ride never hides, uses or removes it. It makes its own part beside it.

The key press loads nothing, spawns nothing and walks no object array: every lookup and load happens at the preload or
when a new EVE appears.

## Mount and dismount

A mount first runs the checks that [vehicles/bike.md](bike.md#getting-on-and-off) lists, on EVE's reflected state:
`IsAttachedToLevelSequenceWithoutPlayable`, `IsRunningInteraction`, `bEnableInteractionBlock`, `IsMoveInputBlock`, the
movement component's `MovementMode` (swimming, a custom mode for the ladders, ropes, beams, wires and event moves, the
air, or anything but walking), `IsRunningSkill`, `IsBattle`, `GetFishingModeType`, `IsTPSMode`, `bFreeCamMode`,
`VehicleActor` (a lift or the monorail), the native warp word, the pause, the photo modes, the friend's photo freeze and
her life state. Then come SBO's own: a race drive or the probe, an armed race, the Doro look, `coop emote`, a hall seat,
`coop fly`'s keys, `coop glide`, Night Operation, an open screen of the mod. Every refusal is logged with its reason.
With a place, the parked bike's rules come next ([Getting on at the parked bike](#getting-on-at-the-parked-bike)).

Then, in this order:

1. `coop-bike.txt` (through `link.store`): EVE's object path, her main mesh's relative rotation and location. A file
   this Lua load kept for her (a dismount that could not write her mesh back) gives the base instead, since her mesh may
   still lean. A file that cannot be written refuses the mount.
2. `vehicles/bike/drive.lua`'s drive (the bike's copy of the races' `online/modes/race/drive.lua`) with
   `vehicles/bike/model.lua` (why `bike`). It keeps her movement component's `MaxAcceleration`, `GroundFriction`,
   `BrakingDecelerationWalking` and `BrakingFrictionFactor` in `coop-drive.txt`, then sets them to 0
   ([Driving](../online/modes/race-internals.md#driving)).
3. `bike gate on` (below).
4. `anim play <id> <clip> ride` (below).
5. The part shown.

A step that fails runs the dismount for what was done. The dismount runs backward: the part hidden, `anim stop`,
`bike gate off`, the drive off, her main mesh's relative rotation and location written back (on the EVE she rode only),
`coop-bike.txt` cleared unless that write failed. Each step runs in its own `pcall`; the log line names the ones that
failed. The next Lua load replays `coop-bike.txt` at its first tick (`self.restore`): her mesh back on that EVE if she
still is one, the part hidden. Her movement values come back through `coop-drive.txt` the same way. The native part
turns the gate off and stops the clip itself at a new Lua load and at `coop off`.

Every 250 ms while she rides, the ride checks again and takes her off with the reason: a load or warp, a cutscene, an
interaction, the move block, water, a custom mode, a lift or train, fishing, her life state 3 to 5, selfie mode, her EVE
changed, the drive gone, or the gate not reading `on` 1 s after the mount. Combat, the air, a skill, aiming and the free
camera do not take her off.

## The gate

SB gates its gameplay actions with `ASBPlayerController::InputActionStateMap`, a transient `TMap<FName, uint8>` at
controller `+0x6b0`. Its bindings run `0x142047190` as their predicate, which looks the action's name up there (a
missing name counts as on) and drops the action when its byte is 0. SB writes it with
`0x1423ca710(controller, name, state)` and finds a name with `0x140e6c8e0(map, &index, name)`; each element is 0x14
bytes, its byte at `+8`.

`bike gate on` checks that the player controller is an `SBPlayerController` (its class at `0x1470402c8`), keeps each
name's state (absent, or its byte) and writes 0 through SB's own setter, for these 54 names: `AttackLight`,
`AttackStrong`, `Evade`, `Guard`, `SpecialCommand1` and `2`, `Scan`, `BetaSkillPreCommand`, `BetaSkill1` to `4`,
`BetaSkillView`, `BurstSkillPreCommand`, `BurstSkill1` to `4`, `BurstSkillView`, `TachyModeTwoKey1` and `2`, `TPSMode`,
`TPSFire`, `ToggleSprint`, `SwimDash`, `FishingModeCancel`, `CommandKey1` to `12`, `Combination1` and `2`,
`CrossKey_Up`, `_Down`, `_Left` and `_Right`, `LeftShoulderKey`, `LeftTriggerKey`, `RightTriggerKey`, `RightKey_Up`,
`_Down`, `_Left`, `_Right` and `_Click`, `LeftKey_Click` and `FocusChangeKey`. `Jump` stays SB's. The four
`CombinationCross` names stay out too: SB turns them on and off itself. So does `Interaction_Key`: the interaction
manager's tick (`0x141b35720`) writes it every frame through `0x141b3cdd0` and `0x14228df50`, 1 while something is in
reach, else 0, so a 0 from the gate would not hold. An interaction in reach still starts from the saddle; the ride's 250
ms check then takes her off. `Item_Interaction` (R2 or F) and `Item_UseHeal`, `Item_UseUtil` and `Item_UseBullet` (D-pad
Up and Down) have their own predicates outside the map, so they stay on as well. A name that is not in the game's FName
pool has no binding, so it is skipped.

`bike gate off` writes each kept state back (an absent name as 1, which SB reads the same way), unless the name no
longer reads 0: SB wrote it during the ride, so SB's value stays. The log names the actions turned off with what each
held, then the ones left as SB set them. When the controller the gate was made on is gone (a map change), its map went
with it: nothing is written.

## The riding clip

SB has no clip of EVE driving a bike. The default is `eve_bikeSleepPose`
(`/Game/Art/Character/PC/CH_P_EVE_01/Animation/event/G03/MV_SD20_AfterBruteBattle_Main/eve/`), her pose asleep as a
passenger: 301 frames at 30 fps, no root motion. The ride asks `anim play <id> <clip> ride`: SB's by-path call
`0x1420b7800` on slot 0 as [coop emote](../eve/eve-internals.md#emotes) plays, looped with count -1, priority 0, with
the call's int 30 at 2. `PlayCustomAnim` keeps it at the slot's `+0x68` and turns her foot IK off over the blend-in
through `0x1421119c0`, under the key `ASBCharacter::PlayCustomAnim_29770`, at priority 100. Only a call at priority 100
or more can turn it back on. SB's stop (`0x1420b23f0`) does that only while the slot's `+0x68` still reads 1 or 2. When
one of SB's clips takes slot 0, its own type replaces ours there, so SB's stop no longer turns her foot IK on. So once
the ride's play is over without SB doing it (another clip took the slot, a replay was refused, or our stop found another
clip there), the game thread does what SB's stop does. It does nothing when her foot IK is already on, or when the clip
now in slot 0 is of type 1 or 2 (its own stop turns it on). Otherwise, when `0x142111440(character, 0)` allows it, it
calls `0x1421119c0(character, "ASBCharacter::StopCustomAnim_29443", 1, 0.25, -1, 0, 0, 100)`. When it does not, it sets
`+0x2b23` to 1, as SB's stop does; `0x1420fe2b0` later turns her foot IK on from it, at priority 100. `coop-link.log`
says which (`anim: EVE's foot IK ...`). Before the play, the game thread looks the clip up with `ResolveObject`; the log
says whether it was in memory (`bike ride clip in memory before ride play <n>`) or whether SB's call loaded it.

Every 250 ms the ride's pass reads the `anim=` word for its id in the status text it already has: no frame reads the
file. When SB ends the clip, the ride plays it again at that pass,
unless photo mode is open, a skill runs or a root-motion move plays. Three ends within 1 s take her off the bike: SB
uses the slot.

## Riding

`vehicles/bike/model.lua` adapts the motorcycle model of Eve On Wheels' `handling.lua` to
`vehicles/bike/drive_model.lua`'s table shape, so `vehicles/bike/drive.lua` feeds it the same input
(`GetLastMovementInputVector`, the drift keys, her velocity) and gives her what it returns (a velocity or a launch, then
her yaw), as for a race ([Driving](../online/modes/race-internals.md#driving)). No move block is set while she rides:
SB's move handler (`0x142059df0`) still reaches `AddMovementInput`, so the stick keeps working.

The model keeps one signed speed along a path and a nose apart from it. The nose turns by a bicycle yaw rate (wheelbase
170.6 cm) that the lateral grip caps (2 x turning angle / 35 in g); the steering eases toward the stick at 3 and 4 full
locks a second; its share of the turning angle falls with speed (1 at 500 cm/s, 0.41 at 2500, 0.16 at 4500). On grip the
path is the nose. In a drift (a drift key above 500 cm/s) the path follows the nose at 2.5 times the slip a second, at
most 42 degrees behind. The brake is 400 x 15^(hardness/100) cm/s², the engine braking 180, the rolling loss 40. Reverse
comes after the brake is held 0.3 s at a stop, up to 300 cm/s. The stick's reading is SBO's (throttle by the cosine of
its angle off the nose, full lock from 45 degrees, brake past 120 degrees); its dead zone of 0.15 is his.
`tests/lua/vehicles/bike/model_test.lua` checks the numbers of his defaults.

## Lean and pitch

The model gives a lean from the path's turn rate, `atan(v x turn rate / g)`, at most 38 degrees, eased at 103 degrees a
second, in full from 600 cm/s. The pitch comes from the vertical speed, `atan(vz, max(v, 200))`. After each drive frame
her main mesh's relative rotation becomes the kept base rotation composed with a turn about her forward axis (lean) and
her side axis (pitch), through `KismetMathLibrary`'s `ComposeRotators` (the library looked up once at the mount),
written with teleport off (a teleport clears
cloth inertia) and only after a change of 0.05 degrees or more. The part hangs from that mesh, so it leans with her. The
signs (`LEAN_SIGN`, `PITCH_SIGN`) are to be checked in the first ride; the mount's log line prints her mesh's relative
rotation for that.

## The parked bike

`vehicles/bike/stand.lua` makes the parked bike with `core/actors.lua`'s `spawn`: a plain `Actor` whose root is one
`SkeletalMeshComponent` showing `Adam_Vehicle_02` at scale 1 in its reference pose. `vehicles/bike/ride.lua` makes one
for each EVE right after her part, under the same gate (`bike=ready`, EVE in the world for 2 s). It starts hidden with
its collision off. The log says `bike stand made in <ms> ms`. A new EVE (a map change, a respawn) has the old EVE's
stand removed first. A stand that cannot be made (`bike stand not made: <why>`) is not tried again on that EVE: a mount
then ignores the place and the bike comes out under her.

The component is `WorldDynamic`, blocks every channel but `Camera`, makes no overlap events and has
`CanCharacterStepUpOn` set to `ECB_No`. Its body is the mesh's own physics asset; no capsule is added. Shown, the
actor's collision is on (`SetActorEnableCollision`) and each 250 ms pass sets the component's by
`vehicles/bike/park.lua`'s clearance rule. That rule measures from her capsule to the bike's body, taken as a capsule of
radius 83 cm around the bike's X axis from -97 to 314 cm (the capsule of the bike's physics asset), with nothing past
200 cm up or down. Below 0 she stands inside it: the component has no collision, since a blocking overlap would push her
out sideways. Over 20 cm it turns `QueryOnly`, which her movement's sweeps hit. A bike that appears beside her is solid
at once. Enemies stop at it the same way; the open state follows our EVE only. The first time it turns solid the log
reads the engine back: `bike stand solid: type <n>, collision on|off`. Hidden, the actor's and the component's collision
are off.

Every 250 ms while she rides, the checks keep her ground pose when her movement mode is `Walking` or `NavWalking` and
her floor counts: `CharacterMovement.CurrentFloor` reads `bWalkableFloor` and `GetMovementBase()` is not `Movable` (a
lift, a train, a pawn). The pose is her map (`U.map_of`), her main mesh's world location (her feet) and
`KismetMathLibrary`'s `MakeRotFromZX` of the floor's `ImpactNormal` and the part's forward vector: the part's heading
laid on the floor. A dismount by the key, the pad or `coop bike` reads the same pose live and parks there (`here`). When
that pose does not read, as for every forced dismount, the bike parks at the last kept pose (`last ground`), else it
stays where it was (`before the mount`). The log says `bike parked on <map> at <x>,<y>,<z> (here|last ground|before the
mount)`. The stand moves with `K2_SetActorLocationAndRotation`, teleport on, no sweep. When `CurrentFloor` does not read
through UE4SS's reflection, the log says once `bike floor: CurrentFloor not read (<why>): walking on a fixed base
counts`: walking on a base that is not `Movable` counts, with an up normal, so the bike keeps the yaw alone.

The stand shows at its place while that place is on the map it was made on, her EVE has been in the world 2 s, she does
not ride and no level sequence holds her (`IsAttachedToLevelSequenceWithoutPlayable`). Its first show on an EVE that no
park caused logs `bike put back on <map> at <x>,<y>,<z>`.

### Getting on at the parked bike

With a place, a mount that passed the checks of [Mount and dismount](#mount-and-dismount) compares it with her, from
the cached place and her main mesh's location:

- on another map: `Your bike is on another map: <name>.`, the name from `core/worlds.lua`'s table, else the
  path's last part;
- on her map with the stand not shown: `Your bike is not back yet.`;
- out of reach (`vehicles/bike/park.lua`'s `reach`: her capsule more than 50 cm from the bike's body by the clearance
  rule above, with her capsule's radius read from `CapsuleComponent`, or her feet more than 100 cm up or down from the
  stand's root): `Your bike is <n> m away, <side>.` The distance is the 3D one rounded to whole metres, so a refusal
  says 1 m or more. The side is the quarter the bike lies in from `GetControlRotation()`'s yaw: within 45 degrees `ahead
  of you`, from 135 degrees `behind you`, else `to your right` or `to your left`. A bike straight above or below is
  ahead;
- within reach: the stand is hidden, then her actor goes through `K2_TeleportTo`, SB's teleport, which checks the spot
  with `UWorld::FindTeleportSpot`. `vehicles/bike/park.lua`'s `seat` takes her actor's offset to the part, turns its X
  and Y by the change of yaw and lays it from the parked root, so the part lands on the root with the parked heading
  (`bike mount: onto the parked bike`). A teleport that returns false or raises logs `bike mount: teleport refused, the
  bike came to her`: she mounts where she stands. Then the mount's steps of [Mount and dismount](#mount-and-dismount)
  run. A mount that fails shows the stand again where it was.

Refusals are logged in English (`bike refused: <reason>`) and shown in the menu's language. Each 250 ms pass while the
stand shows and she does not ride, coming within reach shows `<bike_key>: get on the bike` once.

## The place per save

`vehicles/bike/park.lua`'s `key` names the record from the status text: `coop-bike-<steamid>-<saves><index>.txt`, with
the SteamID of the `mod=` line, then the `saves=` word and the slot index of the `slot=` line while its verdict is
`coop` or `main`. The file is in the mod folder, read with `link.read_file` and written with `link.write_file` (a
`.tmp`, then a rename). Its one line is `1<TAB><map><TAB><x><TAB><y><TAB><z><TAB><pitch><TAB><yaw><TAB><roll>`: version
1, the map's package path, then centimetres and degrees as `%.9g` with a dot. No file means no place. A line that does
not read (another version, a map the bike line would refuse, a missing field, a position past 10,000,000 cm or an angle
past 360 degrees) reads as no place.

The 250 ms pass reads the key while she does not ride. A new key is read once: `bike place: <file>: <map>`,
`bike place: <file>: none` or `bike place: <file>: unreadable, read as none`. A map arrival reads nothing. Each park
that moves the bike writes the record at the key read last; a write that fails logs
`bike place: write failed: <error>; kept in memory`. Since the key is read only while she does not ride, a Load Game of
another save during a ride writes the forced park into the old save's record. A park made before any key (the slot
line not read yet at game start, a Ctrl+R while she rode) waits in memory and is written at the first key, which then
is not read: `bike place: <file>: kept the park made before the key`. With no key at all (a build other than the
pinned one, `saves=off`, no native part) the place lives in memory for the Lua load.

While an SBO lobby is open (`online/lobby/sbo.lua`'s `active()`) the place and the key are dropped and nothing is read
or written. The lobby plays a session copy of the save, which a record written there would outlive. Leaving the lobby
drops them again, so the next pass reads the save's record.

The stand and the other players' copies outlive the Lua state. The stand's actor path goes to `coop-bike-stand.txt`
(through `link.store`) when it is made. The copies' paths go to `coop-bike-copies.txt`, tab-separated, each time the set
changes. After Ctrl+R, the next Lua load's first tick sweeps each path with `Doro.sweep`, which removes an actor only
while its root shows the bike's mesh, then clears the file. The stand is made again 2 s later and shows at the record's
place. When the earlier load left her riding, `coop-bike.txt`'s restore puts her mesh back, then parks the bike at her
feet when her floor counts.

`coop off` and `bike=off` take her off the bike, then remove the stand with `Doro.remove` and clear
`coop-bike-stand.txt`; the place stays. After `bike=off` the next pass with the bike on makes the stand again. `coop
off` holds until the game restarts and no pass runs meanwhile, so the stand comes back at the next game start.

## The bike line

Each player sends her own parked bike to every member: `park <map> <x> <y> <z> <pitch> <yaw> <roll>` or `none` (the wire
is in [The bike line](../online/steam-link-internals.md#the-bike-line)). `vehicles/bike/park.lua`'s `wire` builds it
from the place in whole centimetres and hundredths of a degree within (-180, 180], or `none` for a place the line cannot
carry. It is `none` while she rides (her ghost carries the part then), with `bike=off` and without a place. The ride
hands it to `link.bike` at a mount, a dismount and each 250 ms pass when it changed. `link.bike` writes
`coop-parked.txt` (a `.tmp`, then a rename), which the native worker takes at its next pass; the newest line wins. The
ride keeps a line as sent only once that write succeeded, so a failed write goes again at the next pass. The line does
not follow her map changes: her bike on map A stays `park` on A while she walks map B.

The native part keeps the newest payload `bike_ok()` accepts and sends it, reliable on channel 0, to each member past
the handshake who has not had it, again after her hello and her return from lost. Each member's last payload comes back
in `coop-status.txt` as `bike_of=<SteamID> <payload>`, after the `member=` lines. `core/link.lua`'s `bikes()` reads
them by SteamID and keeps them out of `UE4SS.log`.

`vehicles/bike/others.lua` draws them, every 250 ms after the ride's pass. For each member but us whose line parks on
the map our EVE stands on, once our EVE has been in the world 2 s, it makes a copy with `vehicles/bike/stand.lua` and a
cull distance of 20000 cm (200 m), at most one a pass, in SteamID order. A copy moves when her line changes. It is
removed when her line says `none`, names another map or is gone (she left the lobby), or when its actor is gone. A new
EVE of ours drops them all (the level took them). No copy shows while our `bike=off` or while the preload is not
`ready`: a copy needs the mesh in memory and `bike=off` frees it. A copy that cannot be made is not tried again until
her line changes. Copies hide while a level sequence holds our EVE and follow the open-then-solid rule against our EVE.
The log has `bike of <name>: parked on <map's last part> at <x>,<y>,<z>` or `bike of <name>: none` once each time her
line changes, `bike of <name>: copy removed (<why>)` and `bike of <name>: copy not made: <why>`. `coop off` removes
every copy.

The receiver does not tie the copy to her ghost. At a dismount the copy appears at once while her ghost still shows the
part until her capture's next look (once a second) and the receiver's next ghost (a table that needs a new ghost is
taken at most once every 2 s): two bikes can show for about 2 s. At a mount the copy goes at once while her new ghost
with the part comes as late, so no bike shows for about as long. The grouped game test measures both.

## Bringing it back

`vehicles/bike/ride.lua`'s mount offers the paid fetch only after the far and another-map refusals, only outside an SBO
lobby and only when `online/group/travel.lua`'s `camp_near('Xion', 10)` names a camp. That is the nearest Xion camp of
the follow's camp table whose spawn point stands within 10 m of our EVE on Xion's map and which the `activated=` read
lists. The spawn points are walked with `FindAllOf('SBSpawnPoint')` once a map, as the follow does, on this refusal
only. A mount within reach never asks.

The offer keeps for 5 s (`Fetch.WINDOW`) the place the bike would take: her pose as a park takes it, else her feet with
her actor's yaw alone when that pose does not read (on a `Movable` base). A press within the window starts
`vehicles/bike/fetch.lua` (`bike fetch asked at <camp> for 500 betacrystal`); a later one offers again. While the
payment runs, every press is refused with `Paying 500 betacrystal for your bike.`, so it charges once. Each 250 ms the
payment's step runs before the ride's pass. Paid, the place becomes the offer's pose, written as a park (outside an SBO
lobby), shown and sent: `bike brought to <camp> for 500 betacrystal`. Nothing of a payment is kept across Lua loads.

The on-screen lines put the money's name in a `%s`. On the screen's words it is SB's own: the ItemTable row
`BetaCrystal` names the key `Item_BetaCrystal_Name`, read from `/Game/Local/Localize/ItemStringTable.ItemStringTable`
through `core/unreal.lua`'s `game_text` (Gold in English, Or in French, 골드 in Korean). `main/base.lua`'s `game_words`
reads nothing under `ui_language=english`. The English copy of another language (the line above EVE), the log, a name
that does not read and a name over 32 bytes (`Fetch.NAME_MAX`) take `betacrystal`. So does an offer whose refusal and
name pass the feed's 200 bytes: `ui/text_test` fits every refusal and offer with `betacrystal` and the other lines with
a 32-byte name.

`vehicles/bike/fetch.lua` spends the money as SB's shops spend it. Read in Ghidra on build 26123051:

- The shop's buy, `FSBActorLogicObject::BuyItem` (`0x141bbe480`), takes bucket type 1 (the inventory) of the buyer's
  actor GUID (`0x141ad8490`), checks the count of each money alias first (`0x141be1580`; under the price it refuses the
  whole buy and removes nothing), then removes the price by alias (`0x141bdfb10`).
- The player controller's `ServerRequest_ItemBucketItemRemove` (`0x1423bfa00`), which `coop gift` already calls, queues
  SB's remove request (type 0x16), whose `Simulate` (`0x141b0cc60`) runs the same `0x141ad8490` and `0x141bdfb10` with
  no category or SaveType filter. Asked for more than she has, it takes what there is, so the count comes first.
- `0x141be1580` walks the sets that `cutmenus/items.h` reads (the bucket's alias map at `+0x90`, the manager's instance
  map at `+0x210`, each item's count at `+0x6c`), so the native part's read reaches the betacrystal whatever its
  ItemTable SaveType.
- SB's code builds the FName `BetaCrystal`; ShopItemTable writes `betacrystal`. FNames compare without case, so
  `BetaCrystal` finds the same alias.

The steps are `coop gift`'s ([The inventory read](../cutmenus/menus-internals.md#the-inventory-read), [The remove, the
gift and its answer](../cutmenus/menus-internals.md#the-remove-the-gift-and-its-answer)) for one alias and one price.
The native part reads her count (`items <ask> BetaCrystal <FName index> <FName number>`, the FName found with
`FNAME_Find` and read back as the alias). Under 500 nothing is removed (`bike fetch refused: you carry <n> betacrystal,
500 needed`). Else, unless the game is paused or shows one of its screens, Lua calls
`ServerRequest_ItemBucketItemRemove(1, <EVE's GUID>, BetaCrystal, 500, -1)` (`remove asked: BetaCrystal x500 of <n>
(guid <g>)`), then reads every 0.5 s until the count fell by 500. An `unread` or `noeve` answer after the remove is read
again. The engine line holds only the last `items=` answer, which `coop gift`'s reads share, so a read with no answer
after 1 s goes again with its number; the fetch numbers its reads from 32768, `coop gift` from 1. 10 s of play without
the fall (time paused, in photo mode or in the friend's photo mode that pauses ours does not count) or no answer to a
read within 5 s fails the payment: `bike fetch failed: <why>`, which says the betacrystal may be gone once the remove
was asked. `tests/tools/matchmaking_scan_test.py` holds `vehicles/bike/fetch.lua` to that one `ServerRequest_` call.

## Paint

`vehicles/bike/paint.lua` holds the paint table, `Paint.BY_MESH`, keyed by the object path of EVE's body mesh (the
`SkeletalMesh` of her main mesh). The ride's 250 ms pass reads that path after the part step and hands it to the paint
with two components: the part on EVE and the parked bike's. The paint runs once a second. A component already set for
that mesh is left alone. Any other is cleared first: its four slots get the bike mesh's own materials back
(`SetMaterial`, with each material read from the mesh's `Materials`, never from `GetMaterial`). Then, when the table has
the mesh, each listed slot gets `CreateDynamicMaterialInstance` from that own material with `SetVectorParameterValue`
per parameter. A component is known by its address and object path, so after a new Lua load (Ctrl+R) or for a new EVE it
is cleared before it is painted: an earlier load's instance never stays. The ride also clears each parked bike it makes,
which drops what the paint kept for that address and path. A parked bike made after `coop off` at the freed address and
path of the removed one is painted again. A failed call leaves the component cleared, with one `bike paint not set on
...` line per component and mesh. `coop off` clears the part before the parked bike leaves the world. `bike=off` removes
both. A table that fails `Paint.check` logs `bike paint table refused: <reason>` once at load and paints nothing. The
ridden part's instances reach ghosts through the capture's dyes. The clear before the first paint runs for every
outfit, so the part's `OverrideMaterials` then lists the bike's four own material instances. With dyes on, the capture
sends them as four more material lines of the ridden part, also for an outfit with no paint. They name the bike's own
instances, so the ghost's bike looks the same. The parked bike's paint stays on the player's own screen, since [the
bike line](#the-bike-line) carries a map and a pose only.

## Ghosts

While EVE rides, the part is one more skeletal mesh component of hers in `online/partner/capture.lua`'s table (37 bones,
667 bytes more in a keyframe pose), so the ride needs no line of its own. Her lean reaches every ghost through her main
mesh's transform. This works for the friend in ghost slot 0 and for each member in slots 1 to 6 (a match lobby, or an
online session of more than 2 players). While she does not ride, her parked bike travels as its own line ([The bike
line](#the-bike-line)).

The part stays on her, hidden, while `bike=on`. While she does not ride, the capture leaves it out.
`online/partner/wiring.lua` gives `capture.leave_out` the ride's `idle_part`, which the capture asks once a look (once a
second) with her actor's address. `idle_part` answers the address of the part this Lua load made, or found by its tag,
on that EVE. It answers nothing while she rides, before the part exists and after `bike=off`. It makes no engine call.
The capture compares that address with each component's. Only SBO's own part is left out: another mod's component on the
same mesh has no `SBO_Bike` tag and stays a part. The part list changes at each mount and dismount, so each one starts a
new capture generation and every ghost is built again with or without the bike. A ride that ends on a fault, `coop off`,
`bike=off` and a new Lua load each leave `riding()` false, which the next look follows. After a Lua load the first tick
names the earlier load's part, before the capture's first look and whatever the `bike=` word reads. With `bike=off` the
first 250 ms pass removes it. While the bike module is off (it failed to load), no ride can show the part. One an
earlier Lua load left may still be on her: `online/partner/bike_part.lua`, the partner's own copy of the ride's part
lookup, answers that part's address by its tag ([Modules and isolation](../dev/architecture.md#modules-and-isolation)).

While she rides, the part has no `MasterPoseComponent`, so `capture.lua` ranks it with the leaders, ahead of every
follower. With `MAX_PARTS` at 16, an EVE with 16 skeletal parts or more loses the last follower of her outfit from every
ghost until she gets off. Over the pose size, `capture.lua` drops the last leader in `K2_GetComponentsByClass` order,
which follows her actor's component set: the bike is a part like any other there. Parts added after it go first.

## Status words and the latch

The engine status line carries `bike=<off|loading|ready|failed:<why>|fault>`, `bike_gate=<on|off|refused:controller>`
and `bike_life=<n>`, EVE's life state. The worker reads that state from her `FSBActor +0x2600` (the read of the partner
card's numbers, `ReadProcessMemory`, which fails instead of faulting) at most every 250 ms, on any save; the word is
left out when the read failed. The ride's down check reads it. Without it, the check falls back on `link.life()`, which
only a session gives. The native lines (`bike preload ready after <ms> ms`, `bike gate on: ...`, `bike gate off: ...`,
the clip lookups) go to `coop-link.log`. The rest runs in `coop_tick` on the pinned build under its own SEH latch: the
first fault tries once to turn the gate off, leaves the handle as it is (a leaked reference only keeps the bike in
memory) and turns the bike's native side off for the run, with `The bike stopped until the game restarts (a fault).` on
screen. `bike load`, `bike free` and `bike gate on|off` are local asks between Lua and the native part. The one bike
message on the link is the bike line ([The bike line](#the-bike-line)).

## Credits

`vehicles/bike/model.lua` and the lean in `vehicles/bike/ride.lua` adapt Eve On Wheels 1.2.1 by dCharisma1 ([Nexus Mods,
Stellar Blade mod 4165](https://www.nexusmods.com/stellarblade/mods/4165)), used with his written consent of 2026-11-16
under the SBO License 1.0 or any later version (see [NOTICE](../../NOTICE)). Each adapted function says so in its
comment. No file of Eve On Wheels ships with Stellar Blade Online.
