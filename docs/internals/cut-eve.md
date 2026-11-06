# EVE's cut moves: how they work

## The cut ChainSpin

EVE's four shipped Tachy Mode skills (ChainStab1, ScrewAttack1, SwordAura1 and ParrySlash1) each have a SkillTable row
(`P_Eve_Tachy_Skill_<name>_1`, IDs 1004501 to 1004504) that names its first step and its AcquisitionSkillTable row
(`TachyMode_<name>`), a SkillCommandTable row of the same name on one of the Beta skill commands
(`SkillCommandState_BetaSkill1` to `4`, a press, `GlobalCommand` set), a place in the `P_Eve_Tachy` stance's
`CommandArray` (the stance runs while EVE has the effect `P_Eve_TachyMode`), and an acquisition row that puts it in its
fixed slot (`ESBSkillSlotType_TachySlot_1` to `4`) and skill tree box. Their steps play Shows under
`CH_P_EVE_01/Skill/`.

The ChainSpin has none of these. The game ships EVE's clip `P_Eve_Tachy_Skill_ChainSpin1` with its root motion data,
the wing clip `P_Eve_TachyWing_Skill_ChainSpin1`, two CharacterMoveTable rows (`P_Eve_Tachy_Skill_ChainSpin1_Move1`,
750 cm forward over 0.8 s, and `_Move2`, 290 cm after 0.2 s; IDs 1004500 and 1004501, next to ChainStab's block) with
their curves, and the icon `SI_TachyMode_ChainSpin1`. No step of EVE's names those moves and no Show of hers plays the
clip. The prologue's Tachy NPC kept them: its skill `N_TachyNPC_SwingChain` plays the Show
`CH_NPC_TachyNPC/Skill/N_TachyNPC_SwingChain`, whose one anim key plays EVE's clip by its absolute path (3.25 s in nine
steps, with trail and rule move keys), and its Hit1 and Cast4 steps take the two moves. That Show has no wing anim key.

The 11 rows after the stimpacks' build EVE's version from it, each a copy of a shipped row with a few fields changed:

| Row | Table | ID | Copy of | Changed |
| --- | --- | --- | --- | --- |
| `P_Eve_Tachy_Skill_ChainSpin1_1_Cast1` to `_Finish1` (9 steps) | SkillActiveStepTable | 100450001 to 100450009 | ChainStab1's `Cast1`, `Cast2`, `Hit1`, `Hit5` and `Finish1` steps | the Tachy NPC's durations (0.5, 0.15, 0.1, 0.1, 0.15, 0.1, 0.8, 0.1 and 1.25 s), the chain of step names, the Show on `Cast1`, `Move1` on `Hit1` and `Move2` on `Cast4`; on the four hits ChainStab's results `Hit1`, `Hit2`, `Hit3` and `Hit5` (a 1.5 s stun), a quarter of the damage each and the 1000 cm hit area `P_Eve_Sword_1000_360_500_HitArea`, as the NPC's |
| `P_Eve_Tachy_Skill_ChainSpin1_1` | SkillTable | 1004500 | `P_Eve_Tachy_Skill_ChainStab1_1` | its first step; no Tachy Fusion branch, no acquisition, no achievement tag (`TachySkill`), so a use moves no trophy counter |
| `P_Eve_Tachy_Skill_ChainSpin1_Use` | EffectTable | 1004500 | `M_Scarlet_CounterLinkStart` | `EffectAction_UseSkill` of the skill above, with the condition `P_Eve_TachyMode` |

The steps keep ChainStab's hit collision (`Collision_WeaponAndRightArm`, which EVE's collision data has) and its step
effects. The generator checks that the step chain from `Cast1` lasts as long as the Show's own steps, one for one, that
every clip the Show plays is in the pak listing, that the steps' moves are rows of the dump and that the effect's
condition names a shipped effect. There is no SkillCommandTable or AcquisitionSkillTable row: the four Beta skill
commands are taken in Tachy Mode. A fifth command would go into the `P_Eve_Tachy` stance row; it could be appended in
place, as `lion/shock.h` does for the gun stances (see [The cut Shock Bolt](night-operation-shop.md#the-cut-shock-bolt)), and was not added.

`coop chainspin` (`cut/chainspin.lua`) starts it. It gets the rows in through `Lion.rows`, as the shop does, then calls
`ServerRequest_Cheat(<EVE's GUID>, 0, "SBApplyEffectMe", "1004500")` on the player controller. The request's
implementation queues an `FSBCheat` logic request (`0x141afe5e0`); its `Simulate` (`0x141b11800`) finds the actor by
GUID, reads the first argument as a number and calls the effect function `0x141ad08b0` (the one the shared fight's job
calls) with the actor as target and caster. The effect's action 69 turns its `ActionValue1` into an FName, finds the
SkillTable row by that name (`0x141a9a620`) and calls `FSBActorLogicObject::UseSkill` (`0x141ba23c0`) with the row's ID.
The effect's condition keeps all of it to Tachy Mode. Two other ways were ruled out in the disassembly:
`ServerRequest_UseSkill` builds an `FSBUseSkill` request whose `Simulate` looks for a command node in the actor's
stance and global command lists and does nothing without one ("skillCommandNode is null"), and the cheat manager's
`SBPlayerUseSkill` only reads its argument in this build. EVE's GUID comes from the engine line's `me=` (the key of the
world's player map, which the revive uses too); nothing is asked while `warp=` says busy. None of this has run in game.

## Developer flight and slow motion

`coop fly` and `coop slowmo` switch on two developer gates that the game ships off (`game/debug_keys.h`, run by
`glue/tick/debug_game.inc`; not tested in game yet). EVE's character tick reads the flight key (R2 or Z) only through
one function (`0x1423c9ea0`) and the time-control key (R1) only through another (`0x1423c9f90`), and each passes its key
on only while its gate reads true. A gate is one bool in a settings singleton of the game's, not a UObject: the pointer
at `0x147032540` (the globals block's `+0x18`) leads to a `TMap<int32, bool>` at `+0xa8`, keyed by the
`Strihash_DEPRECATED` of the gate's name (`UseFlyingActionKey` `0x1147F83C`, `UseTimeControlKey` `0x43812976`), which
its constructor fills with false. The cheat command meant for them, `USBCheatManager::SBSetCustomBool`, does nothing in
the shipping build, and the character's own `SetCustomBool` writes another map, so no Lua call reaches them.

Every 250 ms while a gate is wanted, the game thread looks its key up as the game's lookup (`0x14261db60`) does and
writes 1 into the value byte of the element it finds. It first checks that the gate function's own copy of the key (a
static that function fills at its first call, at `0x1471082ec` and `0x1471082f4`) holds the same key, that the map's
counts and buckets are in range and that the byte reads 0 or 1. It never inserts an element. The reads go through
`ReadProcessMemory`, and the one write runs under the gates' own SEH latch. The value read before the first write goes
back once the gate is no longer wanted: `off`, `coop off`, the next Lua load (the worker clears the asks when Lua's
session token changes) or a save that is not a co-op one. Slow motion is wanted only while no friend is linked, since
time dilation is local. If the game builds the map again (its values back to false), the next pass sets the gate again
and the log says `gates set again`. A missing key, a static that holds another key or a map out of range refuses the
gate on screen, with no write. The worker numbers each ask and hands the number over with the gates it wants; the game
thread hands back the number its last pass read. A gate's state is logged, and a refusal said, only from the first pass
that read its ask, so a state left from before the ask never reaches the log or the screen.

With the flight gate on, the character tick starts a flight while the key is held in the air (the falling movement
mode) and the time pool allows it (`RemainFlyingActionTime` at least `FlyingActionEnableRemainTime`, 3 s, and no
cooldown), and ends it when the key is released. With the slow-motion gate on, holding R1 sets the time dilation to
`TimeControlKeyScale` (0.2), and every tick without it sets 1 again, so slow motion ends by itself.

The start and the level flight (`Hold` in `game/debug_keys.h`) set the flight key's flag after the game's key pass.
The player controller's input pass (`0x1423c47a0`, its `ProcessPlayerInput(dt, paused)`) recomputes `USBPlayerInput`'s
`bPushedFlyingActionKey` (`+0x193`) from the keys held each frame, through `0x1423c86f0`, and EVE's tick, which runs
after the controller's, starts a flight while the flight flag reads true in the air and ends it when the flag reads
false. A write from Lua came before the pass, which cleared it, and one from a
hook on EVE's blueprint `ReceiveTick` came after the character tick's check: both times the flight ended 0.02 s after
the keys were let go. The pass is called only through two vtable slots, `0x145cc74a8` and `0x145cd37a8` (its other
references are unwind data). At the first `coop fly on` of a run, the worker swaps each slot by a compare-and-swap from
the game's function to a hook of ours, only after checking that both hold exactly that function. The hook calls the
game's pass, then, on the game thread, while both slots hold it, the fly gate is ours and the game is not paused, reads
the controller's pawn (`+0x2f8`) and input handler (`+0x668`). The same pass sets `bPushedJumpKey` (`+0x197`) only
from `DefinedJumpKeyLists` (`+0xF8`, at `0x1423c887e`), and `DefaultInput.ini` puts no key in that list, so the flag
stays 0. The first version of the hook read it and counted no press in a test of 2026-10-26 (six presses in the air,
no flight). The hook asks the game whether the space bar is down instead, through `FUN_14231f470`, the check the pass
runs on each key of its lists: it looks the key up in the player input's `KeyStateMap` (the controller's `PlayerInput`,
`+0x3F0`). A space typed into the co-op chat, a Space select in the co-op menu or saves list (they take the game's input
with `SetInputMode_UIOnlyEx` while the game runs) and a key pressed in the Steam overlay never reach that map, so none
of them counts as a press or drops a flight. The build before read the keyboard with `GetAsyncKeyState`, which saw
those keys too. A press is the key going down. A key already down when the hook first reads it counts only once let go
and pressed again. A Jump key rebound in the game's settings is not followed.

The hook counts the space bar's presses since EVE left the ground. She is on the ground when her movement component
(`ACharacter`'s `+0x330`) has a `MovementMode` (`+0x19C`) other than falling (3): the pinned build's `IsFalling`
(`0x1440a5b80`, in the movement component's vtable) compares that byte with 3. There the count is 0, or 1 while the
press she jumps with is still down or less than 0.3 s old (game time, from the pass's own delta), since her
jump may leave the ground a frame or more after the press and a short tap can end before that. Each press in the air
adds one. The third press arms the start: from then on, on every frame her `bFlyingAction` (`+0x1101`) reads 0, the
hook writes 1 into the flight flag, as a held R2 would, whether the space bar is still down or not. The character tick
starts the flight when its own checks allow it: no root motion from an action (the movement component's `+0xEA8`), no
actor move (`+0x2470`), at least 3 s in the pool and 0.5 s since the last flight. The arm ends when the flight starts or
she lands (the count back to 0 or 1), and `coop fly off` drops it. With `bFlyingAction` at 1 and the flight flag at 0,
the hook writes 1, so she flies level. The press that armed the start is no press in the flight, even if it is still
down. The next press stops the writes until the flight ends, so the space bar drops her, and the count starts over at
0. Once a second, when a count changed, `coop-link.log` gets a line such as `fly hold: 5400 steps, 7 presses, 1 armed,
12 armed writes, 1 takeoffs`: the hook's runs, the space bar presses it saw, the starts it armed, the frames it wrote
the flag outside a flight and the flights it saw start. While `coop fly` is on, `cut/flight.lua` writes R2
over Z (and over any third slot) in `DefinedFlyActionKeyLists` (`+0xC0`), so Z and S, which walk forward and back on an
AZERTY keyboard, no longer start a flight; it puts Z back at `off`, `coop off` and the next Lua load. The reads go
through `ReadProcessMemory`; the write runs under the hook's own SEH latch, and a fault puts both slots back for the
run. `coop off` puts them back too. The pass recomputes the flag each frame, so nothing else needs putting back.

## Cut glide

`coop glide` (`cut/glide.lua`, not tested in game yet) plays the part of a cut piece of EVE's movement code. In the
pinned build, `ASBCharacter`'s `bGlide` (`+0x1100`) has four readers and no writer. The movement component's gravity
(`0x14214d380`, its `GetGravityZ` slot) checks it before the flight and the wall run and scales gravity by
`GlideGravityScale` (`+0xC80`, 0.1). Its air control (`0x142154f80`) scales by `GlideAirControlScale` (`+0xC8C`, 1.0,
the same as without a glide). The reflected `IsGlide` (`0x142686080`) returns it, and the movement debug print shows it
as `Glide %s`. No instruction writes it, and nothing reads `GlideHoldKeyDurationOnJump` (`+0x1360`, 0.2) or
`RemainGlideKeyHoldDuration` (`+0x1364`): the hold-Jump code that set and cleared the flag was cut. Unlike the flight,
no setting gates it, so no write to the settings map could turn it on.

`bGlide` is a reflected property, so Lua sets it. Each frame while `coop glide` is on, the module reads the player's
EVE and her movement's `IsFalling`. In the air it also reads her velocity, `bFlyingAction` and the game's default Jump
keys (`SpaceBar`, `Gamepad_FaceButton_Bottom`) through the player controller's `IsInputKeyDown`. A glide starts once
Jump has been held for 0.2 s of her world time (`GetGameTimeSinceCreation`, which stops in the pause menu) while she
falls with a velocity Z at or below 0 and is not in the flight, and it ends as soon as one of these no longer holds.
The velocity check keeps a held jump from rising ten times higher, as the low gravity would also act on the way up. A
hitch counts as 0.1 s at most, and another EVE (a map change) starts the hold over.

The module writes `bGlide` only when a glide starts or ends, on the player's own EVE. It puts false back at
`coop glide off`, at `coop off`, when her EVE changes and when the save is not a co-op one (`coop_slot`, read once a
second). A failing frame puts it back and turns `coop glide` off with a line on screen. Since no code of the game sets
`bGlide`, a true value at the next Lua load can only come from an earlier load, so that load's first tick sets false
on the player's EVE when it reads true. The property is transient: nothing of it reaches a save.

## Emotes

`coop emote` (`cut/emote.lua`, not tested in game yet) plays one of 39 clips under
`/Game/Art/Character/PC/CH_P_EVE_01/Animation/`: the 31 of `PhotoMode/` that are not in `Bear/` and not a `_Selfie`
file, each a still (7 frames over 0.2 s, or 2 frames over 0.033 s) played in a loop; and, played once, the two selfie
waves `PhotoMode/Hello_Selfie_L` and `_R` (3 s each, not additive) and six clips made for two enemies with no
character folder, mesh, `CharacterTable` row or text string in the game files: for the Chariot, removed (an
`EventSpawnTable` test row and `M_Chariot_Despawn` still name it), `Hit_Chariot_Confront` (14.8 s),
`Hit_Chariot_ConfrontAttack` (10.0 s), `Hit_Chariot_ConfrontFail` (1.5 s) and `P_Eve_Sword_Normal_LinkAttack1_Chariot`
(4.9 s); for Kali, which may be an early name of a shipped enemy (`M_Kali_Despawn` also names it),
`P_Eve_Sword_Normal_LinkAttack1_Kali` (5.6 s) and `M_Kali_Beta_Grab` (5.8 s). All of them are on EVE's skeleton, with
no additive type and no root motion. The command loads its clip (`Doro.resolve`: in memory, else `LoadAsset`), so the
native call finds it in memory. A start is refused in the air or during a skill.

The montage most likely shows nothing: `CH_P_EVE_01_AnimBP_New`, EVE's animation blueprint, has no slot node and no
montage in the 2026-10-06 extract. SB plays her clips through its own custom animation nodes
(`SBAnimNode_SequenceBlendedPlayer`, `CustomAnimNode` in that blueprint), fed by `ASBCharacter::PlayCustomAnim`
(`0x1420ae740`, 38 parameters), which no reflected function reaches. It plays a clip in one of the character's custom
animation slots (0x70 bytes each, the array at `+0x21b8`, its count at `+0x21c0`) and returns the play's FGuid, all
zero when it refused: an additive clip, another skeleton, no animation instance, or a slot whose clip has a higher
priority. Each tick `UpdateCustomAnimWeight` (`0x1420a7130`) moves a slot's time and weight; a clip played once blends
out at its end and clears the slot's playing byte (`+0x18`), a loop with count -1 never does. Photo mode stops the
player's custom animation. Photo mode's own poses do not use these clips either: its pose setter (`0x1420f12f0`)
writes `PoseName_PhotoMode` and hands a pose snapshot baked from them to the animation instance, which the blueprint
reads only in photo mode.

So the native part plays the clip (`game/anim.h`, `glue/tick/anim_game.inc`). Lua asks
`anim play <id> <path> once|loop` (the id counts up from the load's start time; the path must start with
`/Game/Art/Character/PC/CH_P_EVE_01/Animation/`). On its next frame the game thread takes our EVE as the pawn
(`AController::Pawn`, `+0x2f8`) of the player controller SB's getter `0x14231c710` gives, the actor
`UEHelpers.GetPlayer` gives Lua, once it checked she is a live `ASBCharacter`, and calls SB's by-path entry
`0x1420b31d0` the way the MovingTarget animation calls it (`0x1420909c3`): slot 0, the path as a `const FString&`,
start 0, end -1 (the whole clip), rate 1, 0.25 s blends, -1 for SB's own stop at input (off), the loop flag with count
-1 or none, priority 0 (the flight start's), and five empty
`FString` arguments, which that function frees only when their data is set. It loads the path as a
`UAnimSequenceBase`, applies the priority rule, builds the other defaults itself and returns 0 once it played, 1 for an
additive clip, -1 when the clip did not load or the slot's clip outranks ours; the FGuid comes back in its fourth
argument. The flight start's wrapper `0x1420af3c0` was not used: it has no loop flag. `anim stop` calls SB's stop
`0x1420addc0(character, 0, 0.25, the clip's FName, 1)`, which blends the slot out only while it holds that clip.
While ours plays, the game thread reads slot 0 every 100 ms after checking the character is still the live object it
played on: another FGuid, a cleared playing byte or a gone EVE end it, and a slot that took no weight in 1 s (SB's
node is not playing it, so its time would never move) is freed and reported as `ended:weight`. Only time in a world
that is not paused counts toward that second: the weight moves in her tick (`0x1420a7fd0`, the only caller of
`UpdateCustomAnimWeight`), which a paused world does not run, so while the slot has no weight yet each watch asks the
photo pause's read of the WorldSettings' `PauserPlayerState`. A new Lua load and `coop off` stop ours. A play taken
while ours still plays stops ours first, and a play taken in the same frame as a new Lua load or after `coop off` is
refused (`session` or `off`), so no clip of ours goes unwatched. All of it runs on the pinned build under its own SEH
latch; the first fault tries once to stop ours and turns the native clips off for the run.

The engine status line carries `anim=<state> anim_id=<id>` for the last play the game thread took (`idle`, `playing`,
`ended`, `ended:weight`, `stopped`, `refused:<eve|slots|game|off|session>` or `fault`). Lua sends a start only while
that field is there and not `fault`, and acts only on its own id: `ended` and the refusals end the emote with nothing
to stop, and no answer in 5 s ends it with `anim stop` asked anyway. Each frame while one plays, the module reads that
field (every 0.1 s once it says `playing`), `GetLastMovementInputVector`, the movement's `IsFalling` and
`IsRunningSkill`, and asks `anim stop` at movement input longer than 0.1, in the air or at a skill.

Without that field (no native part, another game build) or after its fault, the module calls
`PlaySlotAnimationAsDynamicMontage(clip, DefaultSlot, 0.25, 0.25, 1.0, loops, -1, 0)` on the animation instance of
EVE's main mesh, with 1048576 loops for a pose (the still holds for hours; 0 would end it at once) and 1 for the rest,
reads `Montage_IsPlaying` each frame and calls `Montage_Stop(0.25)` at the same end rules. The next Lua load stops a
montage under `/Engine/Transient` (a dynamic one; the game's montages come from its packages) left on the player's
EVE. Nothing new travels between the two games: the ghost copies the bones the pose stream carries.
