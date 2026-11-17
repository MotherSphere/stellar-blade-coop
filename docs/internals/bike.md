# The bike: how it works

The player page is [bike.md](../bike.md). The bike is `bike/ride.lua` (the part, the checks, the mount and the dismount,
the lean, the pose), `bike/model.lua` (the riding model), `commands/bike.lua` (`coop bike`) and the native part's
`game/bike.h` with `glue/tick/bike_game.inc` and `bike_worker.inc` (the preload and the gate). It is not tested in game
yet. The addresses are build 26123051's.

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

Once `bike=ready` and an EVE has been in the world for 2 s (the capture's own wait), `bike/ride.lua` calls
`race/doro.lua`'s `Doro.attach`: one `SkeletalMeshComponent` showing `Adam_Vehicle_02`, attached KeepRelative to her
main mesh, collision off, single-node mode with no clip, so it keeps its reference pose. It sits at (1.53, 0.52, 2.95)
cm with a pitch of 0.69 degrees relative to her main mesh, from the attach tracks of the game's SD20 scene (riders on
the bike's bone `Base`). It starts hidden. After Ctrl+R the part is already there: the ride finds it among her
components (`K2_GetComponentsByClass`) by its mesh and uses it again. The log line
`bike part ready on EVE (made in <ms> ms)` or `(found ...)` gives the time. A part that cannot be made is not tried
again on that EVE; a mount says why.

The key press loads nothing, spawns nothing and walks no object array: every lookup and load happens at the preload or
when a new EVE appears.

## Mount and dismount

A mount first runs the checks that [bike.md](../bike.md#getting-on-and-off) lists, on EVE's reflected state:
`IsAttachedToLevelSequenceWithoutPlayable`, `IsRunningInteraction`, `bEnableInteractionBlock`, `IsMoveInputBlock`, the
movement component's `MovementMode` (swimming, a custom mode for the ladders, ropes, beams, wires and event moves, the
air, or anything but walking), `IsRunningSkill`, `IsBattle`, `GetFishingModeType`, `IsTPSMode`, `bFreeCamMode`,
`VehicleActor` (a lift or the monorail), the native warp word, the pause, the photo modes, the friend's photo freeze and
her life state. Then come SBO's own: a race drive or the probe, an armed race, the Doro look, `coop emote`, a hall seat,
`coop fly`'s keys, `coop glide`, Night Operation, an open screen of the mod. Every refusal is logged with its reason.

Then, in this order:

1. `coop-bike.txt` (through `link.store`): EVE's object path, her main mesh's relative rotation and location. A file
   this Lua load kept for her (a dismount that could not write her mesh back) gives the base instead, since her mesh may
   still lean. A file that cannot be written refuses the mount.
2. `race/drive.lua`'s drive with `bike/model.lua` (why `bike`). It keeps her movement component's `MaxAcceleration`,
   `GroundFriction`, `BrakingDecelerationWalking` and `BrakingFrictionFactor` in `coop-drive.txt`, then sets them to 0
   ([Driving](doro-races.md#driving)).
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
`0x1420b7800` on slot 0 as [coop emote](cut-eve.md#emotes) plays, looped with count -1, priority 0, with the call's int
30 at 2. `PlayCustomAnim` keeps it at the slot's `+0x68` and turns her foot IK off over the blend-in through
`0x1421119c0`, under the key `ASBCharacter::PlayCustomAnim_29770`, at priority 100. Only a call at priority 100 or more
can turn it back on. SB's stop (`0x1420b23f0`) does that only while the slot's `+0x68` still reads 1 or 2. When one of
SB's clips takes slot 0, its own type replaces ours there, so SB's stop no longer turns her foot IK on. So once the
ride's play is over without SB doing it (another clip took the slot, a replay was refused, or our stop found another
clip there), the game thread does what SB's stop does. It does nothing when her foot IK is already on, or when the clip
now in slot 0 is of type 1 or 2 (its own stop turns it on). Otherwise, when `0x142111440(character, 0)` allows it, it
calls `0x1421119c0(character, "ASBCharacter::StopCustomAnim_29443", 1, 0.25, -1, 0, 0, 100)`. When it does not, it sets
`+0x2b23` to 1, as SB's stop does; `0x1420fe2b0` later turns her foot IK on from it, at priority 100. `coop-link.log`
says which (`anim: EVE's foot IK ...`). Before the play, the game thread looks the clip up with `ResolveObject`; the log
says whether it was in memory (`bike ride clip in memory before ride play <n>`) or whether SB's call loaded it.

Every 0.1 s the ride reads the status line's `anim=` word for its id. When SB ends the clip, the ride plays it again,
unless photo mode is open, a skill runs or a root-motion move plays. Three ends within 1 s take her off the bike: SB
uses the slot.

## Riding

`bike/model.lua` adapts the motorcycle model of Eve On Wheels' `handling.lua` to `race/drive_model.lua`'s table shape,
so `race/drive.lua` feeds it the same input (`GetLastMovementInputVector`, the drift keys, her velocity) and gives her
what it returns (a velocity or a launch, then her yaw), as for a race ([Driving](doro-races.md#driving)). No move block
is set while she rides: SB's move handler (`0x142059df0`) still reaches `AddMovementInput`, so the stick keeps working.

The model keeps one signed speed along a path and a nose apart from it. The nose turns by a bicycle yaw rate (wheelbase
170.6 cm) that the lateral grip caps (2 x turning angle / 35 in g); the steering eases toward the stick at 3 and 4 full
locks a second; its share of the turning angle falls with speed (1 at 500 cm/s, 0.41 at 2500, 0.16 at 4500). On grip the
path is the nose. In a drift (a drift key above 500 cm/s) the path follows the nose at 2.5 times the slip a second, at
most 42 degrees behind. The brake is 400 x 15^(hardness/100) cm/s², the engine braking 180, the rolling loss 40. Reverse
comes after the brake is held 0.3 s at a stop, up to 300 cm/s. The stick's reading is SBO's (throttle by the cosine of
its angle off the nose, full lock from 45 degrees, brake past 120 degrees); its dead zone of 0.15 is his.
`tests/lua/bike/model_test.lua` checks the numbers of his defaults.

## Lean and pitch

The model gives a lean from the path's turn rate, `atan(v x turn rate / g)`, at most 38 degrees, eased at 103 degrees a
second, in full from 600 cm/s. The pitch comes from the vertical speed, `atan(vz, max(v, 200))`. After each drive frame
her main mesh's relative rotation becomes the kept base rotation composed with a turn about her forward axis (lean) and
her side axis (pitch), through `KismetMathLibrary`'s `ComposeRotators`, written with teleport off (a teleport clears
cloth inertia) and only after a change of 0.05 degrees or more. The part hangs from that mesh, so it leans with her. The
signs (`LEAN_SIGN`, `PITCH_SIGN`) are to be checked in the first ride; the mount's log line prints her mesh's relative
rotation for that.

## Ghosts

Nothing new travels. The part is one more skeletal mesh component of EVE, so `partner/capture.lua` lists it in her table
(37 bones, 667 bytes more in a keyframe pose) and republishes the table under the same generation when it is shown or
hidden. Each ghost applies that with `SetVisibility`. Her lean reaches every ghost through her main mesh's transform.
This works for the friend in ghost slot 0 and for each match-lobby member in slots 1 to 6. The part stays on her,
hidden, while `bike=on`. It has no `MasterPoseComponent`, so `capture.lua` ranks it with the leaders, ahead of every
follower; with `MAX_PARTS` at 16, an EVE with 16 skeletal parts or more loses the last follower of her outfit from every
ghost, ridden or not. Over the pose size, `capture.lua` drops the last leader in `K2_GetComponentsByClass` order, which
follows her actor's component set: the bike is a part like any other there. Parts added after it go first.

## Status words and the latch

The engine status line carries `bike=<off|loading|ready|failed:<why>|fault>`, `bike_gate=<on|off|refused:controller>`
and `bike_life=<n>`, EVE's life state. The worker reads that state from her `FSBActor +0x2600` (the read of the partner
card's numbers, `ReadProcessMemory`, which fails instead of faulting) at most every 250 ms, on any save; the word is
left out when the read failed. The ride's down check reads it. Without it, the check falls back on `link.life()`, which
only a session gives. The native lines (`bike preload ready after <ms> ms`, `bike gate on: ...`, `bike gate off: ...`,
the clip lookups) go to `coop-link.log`. The rest runs in `coop_tick` on the pinned build under its own SEH latch: the
first fault tries once to turn the gate off, leaves the handle as it is (a leaked reference only keeps the bike in
memory) and turns the bike's native side off for the run, with `The bike stopped until the game restarts (a fault).` on
screen. `bike load`, `bike free` and `bike gate on|off` are local asks between Lua and the native part: the link
protocol does not change.

## Credits

`bike/model.lua` and the lean in `bike/ride.lua` adapt Eve On Wheels 1.2.1 by dCharisma1 ([Nexus Mods, Stellar Blade mod
4165](https://www.nexusmods.com/stellarblade/mods/4165)), used with his written consent of 2026-11-16 under the SBO
License 1.0 or any later version (see [NOTICE](../../NOTICE)). Each adapted function says so in its comment. No file of
Eve On Wheels ships with Stellar Blade Online.
