# Cut enemies and models

Test commands show cut enemies and other cut models from the game's files in a viewer with a free camera, or spawn three
cut enemies to fight: the Lion, the Gardener and the Tendril. How the mod adds their table rows is in
[internals/cut-enemies.md](internals/cut-enemies.md). The other cut content is in [cut-eve.md](cut-eve.md),
[cut-scenes-and-menus.md](cut-scenes-and-menus.md) and [matrix-xiii.md](matrix-xiii.md).

## Cut enemy preview: `coop leviathan`, `coop gardener` and `coop tendril`

The game's files hold enemies that have not been seen in the game. These test commands, left out of the usage line,
show three of them:

- `coop leviathan`: Naytiba 10, the Leviathan, in `/Game/Art/Character/Monster/CH_M_NA_10/`.
- `coop gardener`: Naytiba 1, the Gardener, in `/Game/Art/Character/Monster/CH_M_NA_01/`. It is an artillery Naytiba
  about 20 m tall at scale 1, with its own textures. The prologue shows its mesh far away as scenery; its fight and its
  Data Bank entry were cut. [`coop gardener fight`](#cut-enemy-coop-gardener-fight) spawns it as an enemy.
- `coop tendril`: Naytiba 6, the Tendril, in `/Game/Art/Character/Monster/CH_M_NA_06/`. It is a prototype mesh
  (`CH_M_NA_06_test`, about 7 m tall) with 44 animations and blend spaces and no material.
  [`coop tendril fight`](#cut-enemy-coop-tendril-fight) spawns it as an enemy.

The three commands take the same words, described below with `coop leviathan`, and share one display and one
[free camera](#free-camera) with four more commands for
[other cut models](#other-cut-models-coop-mann-coop-nier-coop-orcal-and-coop-enya). One model is shown at a time: a
`show` of another one removes the first, and its answer starts with
`Leviathan removed: one cut model is shown at a time.` (or the name of the other model). They never spawn
an enemy or a character. What they show is a plain actor with one mesh and collision off, like the Doros of a race, so
nothing of it can fight, die or reach a save. Their lines go to `UE4SS.log` as `[StellarCoop][LV]`.

- `coop leviathan` or `coop leviathan list` only reads. It logs one line for each mesh, skeleton, animation, blend
  space and Blueprint class it looks for: `missing`, or the object's class, with the skeleton of a mesh or an
  animation and the parent class of a Blueprint class. Two more `list asset` lines give the same for
  `M_Leviathan_Despawn`, from the game's despawn shows, and for `Default` in the Leviathan's folder. Then it logs
  each CharacterTable row whose name, or one of its name fields such as `Type` or `RefAppearance`, contains `NA_10`
  or `eviathan` (Leviathan, and Reviathan as the statue spells it), with the row's character ID and `MeshScale`, and
  the number of rows it read.
- `coop leviathan show [body|a|b|tentacle|statue] [<distance m>|auto] [<height m>|auto] [<scale>]` puts one mesh in
  front of EVE, facing her, and turns on the [free camera](#free-camera). `body` (the default) is `CH_M_NA_10`, `a` and
  `b` are `Leviathan_A` and `Leviathan_B`, `tentacle` is `M_LeviathanTentacleA` and `statue` is `C_Reviathan`, a static
  mesh from the game's secret room assets.
  - The distance is in metres, up to 5000; `auto`, the default, is 1.6 times the radius of the mesh's bounding sphere,
    and at least 6 m.
  - The height is in metres above EVE's feet, and a negative one lowers the mesh; `auto`, the default, lifts the mesh
    until its lowest point is 5 m above her feet. The two `auto` values use the bounds stored in the mesh asset, times
    the scale. When those cannot be read, the mesh goes 6 m ahead, with the point it stands on 5 m up. The log line
    `show body: bounding sphere radius 50 m, centre 30 m and lowest point -2 m above its root` gives the radius, and the
    heights of the mesh's middle and of its lowest point above the point it stands on.
  - The scale goes from 0.01 to 100, 1 by default.
  - A number first is a distance for the body: `coop leviathan show 40 15` shows the body 40 m away and 15 m up.
  - The mesh plays each animation made for its skeleton twice, one after another, and starts over after the last, with a
    log line for each. A blend space plays at input 0, 3 s twice.
  - A second `show` replaces the first and keeps the last skin. It runs only on a
    [co-op save](playing-with-a-friend.md#co-op-saves).
- `coop leviathan move <distance m>|auto [<height m>|auto]` puts the shown mesh that far in front of where EVE stands
  now, facing her, at that height. `auto` works as for `show`, and a missing height is `auto`. It is the same mesh,
  with its animation, scale and skin: walk EVE to another spot, then move it there.
- `coop leviathan skin statue|hydra|default` sets every material slot of the shown mesh to one material. The
  Leviathan's only material, `Default` in its folder, is a grey placeholder. `statue` is the secret room statue's
  material (`C_Reviathan_MI`), `hydra` the Hydra's tentacle material (`MI_M_NA_09_V03_Tentacle`), and `default` puts
  the mesh's own materials back. The skin stays through `play` and `move`, and the next `show` uses it. The log line
  gives the number of slots set.
- `coop leviathan play <name>` holds one animation of the shown mesh in a loop, for screenshots. The name is matched
  in any case against the end of the animation names, then anywhere in them: `coop leviathan play lightningball` plays
  `M_Leviathan_LightningBall1_1`. `coop leviathan play` alone goes back to the cycle. Both turn the free camera on.
- `coop leviathan off` removes the mesh and turns the free camera off. `coop off`, a map change and its first error
  remove it too. While it is shown, `coop-leviathan.txt` holds its path, so the next Lua load (Ctrl+R) removes it if
  this one could not. The next `show` tries again first, and shows nothing new while the old mesh cannot be removed.

`coop gardener` and `coop tendril` differ in these points:

- `show` has one mesh, `body`: `CH_M_NA_01` for the Gardener, `CH_M_NA_06_test` for the Tendril. Its `auto` height
  puts the mesh's lowest point at EVE's feet, since both stand on the ground, and its root at her feet when the bounds
  cannot be read. At scale 1, `auto` puts the Gardener about 23 m away and the Tendril about 12 m away.
- `list` reads their own folders. For the Gardener: its mesh and skeleton, 29 animations and blend spaces, 4 Blueprint
  classes, its projectile class, the `M_Gardener_SingleShot_1`, `M_Gardener_MultipleShot_1` and `M_Gardener_ToxicBeam`
  shows from `/Game/Art/Show/CH_M_NA_01_Gardener/Skill/` and `Default` in its folder. Its CharacterTable rows are those
  that contain `NA_01` or `Gardener`. For the Tendril: its mesh, skeleton, 44 animations and blend spaces, 2 Blueprint
  classes and its physics asset, and the rows that contain `NA_06` or `Tendril`. No row of the game's CharacterTable
  contains any of these words (read offline on 2026-10-23), so both lists report 0 rows.
- `play` matches their own animation names: `coop gardener play toxic_beam` plays `Mon_Gardener_S_03_Toxic_Beam`,
  `coop gardener play hide` plays `Mon_Gardener_C_Hide` and `coop gardener play unhide` plays `Mon_Gardener_C_UnHide`.
  `coop tendril play whipattack` plays `M_Tendril_WhipAttack`; its left and right versions need their `_l` or `_r`.
- `skin`: the Gardener has only `default`, its own textures. The Tendril has `hydra` and `default`. Its `default` is the
  engine's grey, since its one material slot is empty. Each creature keeps its own last skin for its next `show`.
- `move`, `skin` and `play` act on the shown mesh only when it is that command's creature: with the Gardener shown,
  `coop tendril move 20` answers `no Tendril is shown: coop tendril show first`. `off` of any of the viewer commands
  removes the shown mesh, whichever it is, and turns the free camera off.

### Other cut models: `coop mann`, `coop nier`, `coop orcal` and `coop enya`

Four more test commands use the same viewer, words and free camera for cut models that are not Naytibas. None of them
has been tried in game yet.

| Command | `show` words | What it shows |
| --- | --- | --- |
| `coop mann` | `body` | The early Mann, `CH_NPC_Mann` in `/Game/Art/Character/NPC/Mann/`, about 3.5 m tall, with his 4 animations: 3 idles and a run. The shipped Mann uses another mesh, `CH_NPC_Mann_Body` in `CH_NPC_Mann_01/`. |
| `coop nier` | `square` (the default), `squareb`, `cylinder`, `cylinderb`, `cylinderc`, `sphere`, `sphereb` | The NieR collaboration's three cut machines, `CH_M_NA_951` to `CH_M_NA_953` in `/Game/DLC_1/Art/Character/Monster/`, with their TypeB and TypeC variants: blockout shapes of 32 to 810 vertices with no material, drawn in the engine's grey |
| `coop orcal` | `test1` (the default), `test2`, `native`, `preview` | Orcal prototypes in `/Game/Art/Character/NPC/CH_NPC_XionElder/`: `OrcalTest_01`, `OrcalTest_02` (both about 1 m tall), `XionElder_Native_Preview` and `PreviewMesh/CH_NPC_XE_testmesh` (1.8 m tall and 3.7 m wide) |
| `coop enya` | `mech` (the default), `enya05` | Enya prototypes in `/Game/Art/Character/NPC/CH_NPC_Enya/Temp/`: `CH_NPC_Enya_Mech` and `Enya_05`, 1.6 and 1.7 m tall |

- Only the early Mann plays animations. The NieR machines have none: their blend spaces hold no samples, so `list`
  reads them as `list asset` lines and nothing plays them. The Orcal and Enya meshes have one bone each, in a fixed
  pose. `CH_NPC_XE_testmesh` names no skeleton in its file, so the engine draws it in its reference pose and `list`
  reads `skeleton=-` for it.
- `auto` puts each model's lowest point at EVE's feet, 1.6 times its bounding sphere radius away and at least 6 m
  (3 m for the Orcal and Enya statues).
- `skin` takes `default` only.
- `list` reads each command's meshes, skeletons, Blueprint classes and physics assets (the NieR blend spaces too), then
  the CharacterTable rows that contain `CH_NPC_Mann_Blueprint`, `NA_95`, `OrcalTest`, `Enya_Mech` or `Enya_05`. A
  plain `Mann` would match the shipped Mann's rows.

### Free camera

The free camera is for filming the mesh. `show` and `play` turn it on, and `coop leviathan cam` turns it on or off
(`cam` of the other viewer commands does the same with the same camera).
Turning it on needs a co-op save, like `show`; turning it off works on any save. It starts where the game's camera is
and blends there in 0.3 s. EVE keeps standing where she was: while the camera is on, the game ignores the move input
of her controller. Its look input stays on, and the free camera turns with the controller, so the mouse and a
controller's right stick turn it as they turn the game's own camera, with your sensitivity settings. The camera stays off when `coop-leviathan.txt` cannot be written, since the next Lua load
could not give the controller back without it.

| Key | Free camera |
| --- | --- |
| W or Z | Forward, where the camera looks |
| S | Back |
| A or Q | Left |
| D | Right |
| Space or E | Up |
| Left Ctrl or C | Down |
| Left Shift, held | 4 times as fast |
| Mouse or right stick, and the arrow keys | Turn |

The keys cover QWERTY and AZERTY. The speed is 10 m/s; `coop leviathan cam <m/s>` sets another one, from 0.1 to 500,
until the next Lua load. The arrow keys add 90 degrees a second to the turn. If the controller's rotation cannot be
read, the log says so once and only the arrow keys turn the camera.
No key moves the camera while the co-op menu, the chat box or another co-op box is open.

The game's HUD stays on screen: hide it in the game's own settings before you film. Only walking is blocked, so a key
the game binds to another action (an attack on the left mouse button, for example) still reaches EVE where she stands,
and the game's camera turns behind the free one: back on EVE, it looks where you last looked.

`coop leviathan cam` again, `coop leviathan off`, `coop off`, a map change and the camera's first error turn it off.
The view goes back to what it showed before the camera turned on: EVE, or a fixed camera of the game's, and EVE when
that camera is gone. If the game moved the view to another camera meanwhile (a dialogue), the view stays there. Her
controller ignores move and look input again only if it did before, and the camera is removed. While it is on,
`coop-leviathan.txt` also holds the camera's path, the player controller's and the view's from before, so the next Lua
load (Ctrl+R) does the same if this one could not.

## Cut boss: `coop lion`

The game's files hold a boss that was cut before release: Naytiba 02, the Lion, in
`/Game/Art/Character/Monster/CH_M_NA_02/`. Its blueprint, meshes, animations, hit data and skill presentations (Shows)
ship, but no table row names it, so the game cannot spawn it. `coop lion` adds the 222 rows it lacks to the game's
tables in memory and spawns it as an enemy to fight. The same batch starts with 4 rows for the cut stimpacks of the
[reward shop](night-operation-shop.md) and 11 for EVE's [cut ChainSpin](cut-eve.md#cut-tachy-skill-coop-chainspin),
237 rows in 14 tables, and a buy of a stimpack, the shop screen or `coop chainspin` asks for it as `coop lion rows`
does. The cut [Shock Bolt](night-operation-shop.md#cut-ammo-shock-bolt) ammo's 4 rows are a batch of their own that only the shop asks for: a
Shock Bolt buy, and `coop nightop shop` (or Roxanne's supplies choice) before it opens the shop screen. Every row of
the Lion's is written for it: its stats, its skills, the timing of its hits and the moves that follow its own
animations. It is a test command, left out of the usage line. Its lines go to `UE4SS.log` as `[StellarCoop][LI]`; the
native part's go to `coop-link.log` as `lion rows ...`.

- `coop lion` spawns a Lion 10 m in front of EVE and 1 m up, facing her. The first time in a game run it asks the native
  part to add the rows and waits for the answer, 30 s at most. Each time it reads every row back first and stops at the
  first value that differs, with no spawn. It runs only on a [co-op save](playing-with-a-friend.md#co-op-saves).
- `coop lion intro` first plays the Lion's entrance from the cut boss intro (`Mon_LionC_Scene01_Appearance`, 13 s) on a
  copy of its mesh where it will stand, then spawns the Lion where the copy's root ended (at the 10 m spot when that is
  more than 20 m away) and removes the copy as soon as the Lion is there. The copy is a display only, like the Doros of
  a race: it cannot fight or be hit. A copy that cannot be made skips the entrance and spawns at once. A map change
  during the entrance spawns nothing. Co-op save only.
- `coop lion rows` adds the rows (the Lion's, the stimpacks' and the ChainSpin's) and reads them back, with no spawn.
  Any save.
- `coop lion control` spawns an Antlion (M_Antlion, 50110), a shipped Naytiba, through the same call and with no rows.
  If the Antlion comes and the Lion does not, the rows are at fault rather than the call. Co-op save only. The native
  part reads the game's spawn counter only once rows were asked in the game run, so run `coop lion rows` first if the
  Antlion's lines should carry it; before that they show `spawn count ?`.
- `coop lion brain skulling|lurker` picks the behaviour tree of the next Lions until the mod reloads. `skulling`, the
  default, spawns 50020 (row M_LionC, tree M_Skulling_AI_Test); `lurker` spawns 50021 (row M_LionC_Lurker, the Lesser
  Lurker's tree). Any save.
- `coop lion unfreeze` sets, on each living Lion, every engine switch that can keep a mesh's pose still back to its
  running value: the mesh's tick, its animation pause, its rate scale, its skeleton updates, its visibility-based and
  rate-optimized ticking and the actor's time dilation. It then logs the mesh line again. `coop lion unfreeze init`
  also builds the Lion's animation instance again (`SetAnimInstanceClass` with its own class). The game's skills may
  not survive that, so try it last. Any save.

While a command waits for its rows, its body or its entrance, another `coop lion` answers that it is busy.

Try it in an open, flat area such as the Great Desert, with open ground 10 m in front of EVE, away from story events,
quest areas and Behemoths.

What to expect:

- The Lion has 160000 HP, 3300 shield and 14 stamina, and attacks with a power of 960. That is a little under the Great
  Desert bosses (170500 HP, 3500 shield, 15 stamina). On Story mode it has 10% less HP and 30% less attack; on Hard
  mode, 150% more HP, shield and attack. Its rank is Elite, and it is a boss to the game, so the boss bar shows once it
  targets EVE. The game has no name text for it and writes `<M_LionC>` on the bar; while a Lion lives, `coop lion`
  changes that to `Lion` (checked once a second, since the game writes the name again at each boss bind).
- It has 21 skills, each one playing one of its own skill animations: two claws, two chasing claws, two turning
  attacks, two running attacks, two jumping attacks, two back jumps, a roar, two side steps, a three-claw chain and a
  rush. Under 60% HP it switches to its second phase, which adds a four-claw chain, a chain of claws on the move, a
  chain of four pounces, and a roar at the switch. Both trees pick the skills flagged MeleeAttack, which leaves out the
  side steps and the switch's roar (the switch itself starts that one). Whether the game plays that roar is not known
  yet; the phase switch itself is how the game's Raven fight works.
- Each attack hits during the part of its animation where the claw, paw or jaw swings, measured on the animation
  itself. The roars and the high jump cannot be parried or blocked, only dodged; the other attacks can be parried,
  blocked and perfect-parried.
- Each move follows its animation: the Lion travels as far as its feet show, when they show it. A move toward EVE
  stops short of her, where the next blow lands, so a leap does not carry the Lion past her when she stands closer than
  the leap's length. A skill that leaps before its first blow starts only when EVE stands at least 30 cm past where
  that leap stops (8.3 m for the high jump, 1.8 m for the low jump), so the Lion does not back off before it strikes.
  The two claw chains and the dash chain would have no range left that way: their first steps go up to EVE instead.
  Leaps are estimates, since the feet are off the ground. The two running attacks and one chasing
  claw look for EVE to the side and keep the Lion's heading; the other skills turn it toward her. Each skill's range is
  the reach of its first hit toward EVE plus what its moves close before it, and a skill whose moves take the Lion 3 m
  or more one way needs that much open ground to start. It walks at 2 m/s and runs at 9 m/s, the Behemoth's pace. Its
  run animation, at the Lion's size, strides faster than that, so its feet may slide.
- EVE's link attack on it plays the generic link: the Lion reacts with its own `Hit_Sword_Normal_LinkAttack1` clip.
  When its balance gauge empties it goes groggy as Stalker and Abaddon do, with their one-second delay before EVE can
  link.
- Its rows give it its own death animation (7 s), then a dissolve (15 s). It drops nothing.
- It should not come back from a save: a Lion alive when you load a save or change maps is gone. No command removes one:
  it goes when it dies or with the map.
- No quest event runs for it. A kill counts toward the two achievement counters that take any enemy, as any Naytiba kill
  does. It unlocks no album entry.
- The rows stay in memory until the game exits. A second `coop lion` only reads them back. Nothing is written to a game
  file or a save.
- Only your game has the Lion. In a session your friend does not see it, and her ghost on your screen is no target for
  it. If she types `coop lion`, she gets her own Lion in her game.

The entrance is off by default because the Lion's animation blueprint has no montage slot: a montage played on it would
not show; a clip played straight on its mesh would replace the animation instance that the game plays the Lion's skills
on while its AI runs.

The log lines, in `UE4SS.log` unless marked:

| Line | What it answers |
| --- | --- |
| `tables: 14/14 found: CharacterTable=0x...` | The 14 tables the Lion's rows go into, found, with the addresses sent to the native part |
| `lion rows: 237/237 added through SB's AddRow 0x14417ba30, 0 refused` (`coop-link.log`) | The native part added every row |
| `lion rows by SB's lookups: CharacterTable 50020-50021 2/2, SkillTable 1004500-6000101 23/23, stance 500200-500201 2/2` (`coop-link.log`) | The game's own lookups by ID find the rows, which the spawn and the skills need (SkillTable: the Lion's 21 skills, the stimpacks' skill, 6000101, and the ChainSpin, 1004500) |
| `rows read back through FindRow: 237/237 authored rows, 3178 fields as written (2156 differ from the template row)` | Every field the native part wrote reads as written; 2156 of them hold a value the shipped row it started from did not, and the other 1022 restate that row's value |
| `rows already in (237/237; ...): not added again` | A later `coop lion` in the same game run |
| `spawn 50020: CreateActor returned; body CH_M_NA_02_BluePrint_Large_C 9.8 m from EVE, ...; controller SBAIController; EventSpawnId 0` | The body is in the world, with its controller and its spawn key (0) |
| `lion 1 (50020): 3.1 m, xyz 40764,-12702,-19058, speed 0, skill yes, anim alpha 0.00/0.00, hand moved 0 cm, battle 1, state 1, controller yes, spawn count -5, frame 16.7 ms (worst 24.1), lion Lua 0.4 ms/s, longest tick 0.3 ms (last pass: follow 0.2 ms, boss name 0.0 ms)` | Once a second while it lives: its distance to EVE, where it stands, the speed its walk animation reads (cm/s), whether a skill runs, how much of a skill's clip its animation blueprint shows (0 to 1, two layers), how far its left front paw (`Bip001-L-Hand`) moved in its own frame since the last line (0 cm while it runs or attacks: its pose does not play), battle mode, state, controller, the game's spawn counter, and over the last second the mean and worst frame time, the time this file's tick took and its longest single tick (to tell the Lion's cost from the mod's: a longest tick near the worst frame is the mod's), and what the last once-a-second pass took by part |
| `before the spawn: frame 16.4 ms (worst 19.0), lion Lua 0.1 ms/s, longest tick 0.1 ms (last pass: none yet)` | The same frame part while the command waited, before the Lion was there: compare it with the follow lines |
| `lion 1 (50020) mesh: anim instance CH_M_NA_02_AnimBP_C, anim class CH_M_NA_02_AnimBP_C, its skeleton CH_M_NA_46_Skeleton, mesh skeleton CH_M_NA_46_Skeleton, mode 0, leader none, anim set sync true, mesh CH_M_NA_02_Large, tick true, pause false, rate 1.0, no skeleton update false, visibility tick 0, rate optimizations true, actor dilation 1.0, sequencer anim mode false` | Its mesh as the engine ticks it, before its first line and at each change: the animation instance class (`none` when it has none), the mesh's anim class, that class's target skeleton, the mesh's skeleton, its animation mode (0: animation blueprint, 1: single node), the component it copies its pose from (`MasterPoseComponent`), SB's `bInitAnimSetSyncData` (the character's animation set read), its mesh asset, the mesh's tick, `bPauseAnims`, `GlobalAnimRateScale`, `bNoSkeletonUpdate`, `VisibilityBasedAnimTickOption`, `bEnableUpdateRateOptimizations`, the actor's `CustomTimeDilation` and SB's `bSequencerAnimMode`; `?` for a field that does not read |
| `lion 1 (50020) had no anim instance: its own class built none, ...; stand-in: the single-node instance plays IdleRun_BS_ by speed; mesh: ...` | When no AnimBP builds one: the engine's single-node instance loops the Lion's battle idle-run blend space, its speed input set each frame from the anim graph speed (600 cm/s at most), so the Lion stands, walks and runs. Its skills play no clip with it |
| `...; leader: the Lion AnimBP runs on a hidden CH_M_NA_46, the Lion mesh copies its pose; mesh: ...` | When no AnimBP builds an instance on the Lion's mesh: the body's mesh component takes the Behemoth's mesh (whose bones hang as the skeleton's do) with the Lion's AnimBP, drawn in no pass (no main pass, depth or shadow) so the engine still ticks it, and a new component draws the Lion's mesh and copies that pose bone by bone. SB's skills and moves then play as on any monster. If that fails too, the Lion gets its mesh back and the stand-in plays |
| `lion 2 (50110) rebuild test: its own class built one; mesh: ...` | The control Antlion's first line: its instance rebuilt with its own class (written into `AnimClass`, mode 1 then 0), which says whether that rebuild works on a shipped Naytiba's body |
| `entrance copy AnimBP test: its own class built none, CH_M_NA_02_AnimBP_C built one` | `coop lion intro`, before the spawn: the same tries on the entrance copy, a plain actor's mesh rather than an SBCharacter's. An instance there means the Lion's AnimBP is sound and the Lion's body refuses it |
| `lion 1 (50020) had no anim instance: its own class built none, CH_M_NA_02_AnimBP_C built one; mesh: ...` | Its mesh had no animation instance. Once a body (never for the control Antlion), the mod asks the engine to build one: with the mesh's own anim class, then the Lion's AnimBP, then the Behemoth's (same skeleton), each class found by its path, written into the mesh's `AnimClass` and followed by a switch to single-node mode and back. The line says what each try gave, then the mesh line |
| `lion 1 (50020) unfreeze: tick, pause, rate, skeleton, visibility, optimizations, dilation; mesh: ...` | What `coop lion unfreeze` set (a failed one with its reason) and the mesh line after it |
| `boss name: <M_LionC> -> Lion` | The boss bar's name set to Lion |
| `lion 1 (50020) recycled: SB moved its body back for this spawn` | The game reused a Lion body it had sent far away for the next spawn; that spawn's line ends with `a body SB reused` |
| `lion 1 (50020) dead after 143 s (InteractionState 3, no controller); body gone after 22.4 s` | Its death and its body's despawn |
| `lion 1 spawn count: before 6, alive 7, after death 6` | The game's spawn counter before the spawn, while it lived and after |
| `entrance: ...` | What `coop lion intro` played, or why the entrance was skipped |

A refusal names its reason in `coop-link.log` (`lion rows refused <row>: <why>; <n>/237 added`) and ends with a `STOP:`
line in `UE4SS.log`. Asking again skips the rows already added. Ask in a loaded save: on the title screen the native
part can wait for a game state that never comes and refuse after 300 frames. See
[internals/cut-enemies.md](internals/cut-enemies.md#the-cut-lion) for how the rows go in.

In the tests of 2026-10-23 and 2026-10-24 the Lion fought like a boss, but its body stayed on the first frame of its
idle pose: its mesh had no animation instance. The cause: the Lion's three meshes hang the `Bip001` bone under `Root`,
while the skeleton they share with the Behemoth (`CH_M_NA_46_Skeleton`) hangs it under a `Base` bone added later. UE
4.26 builds an animation blueprint's instance only for a mesh whose bones match its skeleton's hierarchy, so neither the
Lion's AnimBP nor the Behemoth's ran on any Lion mesh, while the single-node instance (the entrance, the stand-in) has
no such check. `coop lion` now runs the Lion's AnimBP on a hidden Behemoth mesh and draws the Lion's mesh on top,
copying its pose bone by bone, so its skills and moves animate through the game's own system.

## Cut enemy: `coop gardener fight`

The Gardener, Naytiba 1 of the [viewer](#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril), was cut
with its fight. The game still ships its blueprint, its skill presentations (Shows), its shells, its appearance, death
and detection rows and a whole skill kit, but no CharacterTable row and no behaviour tree, so it cannot spawn.
`coop gardener fight` adds the 13 rows it lacks to the game's tables in memory, as a batch of their own next to the
[Lion's](#cut-boss-coop-lion), and spawns it as an enemy to fight. Each row is a copy of a shipped one with a few
fields changed. It is a test command, left out of the usage line, and it has not been tried in game yet. Its lines go
to `UE4SS.log` as `[StellarCoop][GD]`; the native part's go to `coop-link.log` as `gardener rows ...`.

- `coop gardener fight` spawns the Gardener (row `M_Gardener`, 50010) 25 m in front of EVE and 7.5 m above her feet,
  facing her. The first time in a game run it asks the native part to add the rows and waits for the answer, 30 s at
  most. Each time it reads the 13 rows back first and stops at the first value that differs, with no spawn. It runs
  only on a [co-op save](playing-with-a-friend.md#co-op-saves).
- `coop gardener fight half` spawns `M_Gardener_Half` (50012), the same at half size, 12.5 m away. Co-op save only.
- `coop gardener fight skulling` spawns `M_Gardener_Skulling` (50011), which runs the Lion's tree
  (`M_Skulling_AI_Test`) instead of `M_Tentacle_AI`. Try it if the default Gardener never attacks. Co-op save only.
- `coop gardener fight intro` first plays `Mon_Gardener_C_Appear` (15.5 s) on a copy of its mesh where it will stand,
  then spawns the Gardener there and removes the copy as soon as the body is there. `coop gardener show` then
  `coop gardener play appear` or `coop gardener play spawn` previews the spawn animations in the viewer. Co-op save
  only.
- `coop gardener fight rows` adds the rows and reads them back, with no spawn. Any save.

The words that spawn first put away a viewer display and the free camera, so the viewer's model and the Gardener never
stand in the same place. While a command waits for its rows, its body or its entrance, another `coop gardener fight`
answers that it is busy. Every other `coop gardener` word is the viewer's.

Try it on open, flat ground with 30 m clear in front of EVE and no Naytiba within 50 m: each shell kills any Naytiba
within 2.3 m of where it lands.

What to expect:

- It is about 20 m tall and never walks: its stance moves at 0 cm/s, and it turns toward EVE at 100 degrees a second,
  and in 0.3 s at the start of each attack. Its skeleton faces sideways compared with the game's monsters, so the mod
  turns its mesh by 90 degrees once it spawns, and again if the game turns it back.
- It has 37840 HP and 1455 shield (the Behemoth's) and attacks with a power of 930. Its rank is Elite and it is a boss
  to the game, so the boss bar shows once it targets EVE, with the game's own name text for it (the album's
  `Char_M_Gardener_AlbumName`, most likely "Gardener" in English).
- It has three attacks, all shells fired from its mouth: SingleShot (shells on EVE and up to 3 m around her, then 15 and
  18 m ahead of her), MultipleShot (three volleys, every 10 s at most) and ToxicBeam (its beam animation, then 8 shells
  from EVE out to 15 m ahead of her within 0.7 s, every 15 s at most). No beam is drawn: the game ships no effect for
  it. A shell marks where it will land 2 s before, explodes for 100 HP within 2.3 m and leaves a poison zone for 5 s (30
  HP a second), before difficulty.
- Its tree, `M_Tentacle_AI`, was made for monsters that stay put. It may play the Tentacle's 1 s battle-start animation
  once a fight, which the Gardener's skeleton lacks: nothing shows, or a wrong pose for 1 s.
- It never staggers, falls or goes groggy (it has no animations for them) and has no weak point.
- At full size only its right foot is at sword height; the blaster reaches its body. At half size its legs come lower
  if the game scales its hit boxes with its mesh, which is not checked yet.
- When it dies it keeps its last pose (it has no physics for a ragdoll), then dissolves as the Cocoon does. It drops
  nothing.
- As for the Lion: no quest event runs for it, it unlocks no album entry, it should not come back from a save, the rows
  stay in memory until the game exits, and only your game has it.

The log lines, in `UE4SS.log` unless marked:

| Line | What it answers |
| --- | --- |
| `tables: 5/5 found: CharacterTable=0x...` | The 5 tables the Gardener's rows go into, found, with the addresses sent to the native part |
| `gardener rows: 13/13 added through SB's AddRow 0x14417ba30, 0 refused` (`coop-link.log`) | The native part added every row |
| `gardener rows by SB's lookups: CharacterTable 50010-50012 3/3, SkillTable 5001010-5001012 3/3, stance 500101 1/1` (`coop-link.log`) | The game's own lookups by ID find its three CharacterTable rows, its three skills and its stance |
| `rows read back through FindRow: 13/13 authored rows, 279 fields as written (102 differ from the template row)` | Every field the native part wrote reads as written |
| `rows already in (13/13; ...): not added again` | A later `coop gardener fight` in the same game run |
| `spawn 50010: CreateActor returned; body CH_M_NA_01_BluePrint_C 25.9 m from EVE, ...; controller SBAIController; EventSpawnId 0` | The body is in the world, with its controller and its spawn key (0) |
| `gardener 1: mesh yaw set to -90 (was 0)` | Its mesh turned to face EVE, or why the call failed |
| `gardener 1 (50010): mesh yaw 0, not -90 (the game turned it back): set again` | The game turned the mesh back, and the mod turned it again |
| `gardener 1 (50010): 25.9 m, xyz ..., speed 0, skill yes, ...` | Once a second while it lives, the same fields as the Lion's line |
| `gardener 1 (50010) dead after 210 s (InteractionState 3, no controller); body gone after 16.0 s` | Its death and its body's despawn |
| `gardener 1 spawn count: before 6, alive 7, after death 6` | The game's spawn counter before the spawn, while it lived and after |

A refusal names its reason in `coop-link.log` (`gardener rows refused <row>: <why>; <n>/13 added`) and ends with a
`STOP:` line in `UE4SS.log`. A refusal of the Gardener's rows leaves the Lion's batch alone, and the other way round.
See [internals/cut-enemies.md](internals/cut-enemies.md#the-cut-gardener) for how the rows are made.

## Cut enemy: `coop tendril fight`

The Tendril, Naytiba 6 of the [viewer](#cut-enemy-preview-coop-leviathan-coop-gardener-and-coop-tendril), was cut
early. Its files keep a test mesh with no material, a blueprint, an animation blueprint and 42 animations, but no table
row and no skill presentation (Show) for any of them. `coop tendril fight` adds the 107 rows it needs to the game's
tables in memory, as a batch of their own next to the [Lion's](#cut-boss-coop-lion) and the
[Gardener's](#cut-enemy-coop-gardener-fight), builds the 12 Shows its attacks and its death play, also in memory, and
spawns it as an enemy to fight. It is a test command, left out of the usage line, and it has not run in game yet. Its
lines go to `UE4SS.log` as `[StellarCoop][TD]`; the native part's go to `coop-link.log` as `tendril rows ...`.

- `coop tendril fight` spawns the Tendril (row `M_TendrilC`, 50060) 8 m in front of EVE, facing her. The first time in a
  game run it asks the native part to add the rows and waits for the answer, 30 s at most. Each time it reads the 107
  rows back and builds the Shows first, and a value that differs or a Show it cannot build stops it with no spawn. It
  runs only on a [co-op save](playing-with-a-friend.md#co-op-saves).
- `coop tendril fight rows` adds the rows, reads them back and builds the Shows, with no spawn. Any save.

The spawn first puts away a viewer display and the free camera. While a command waits for its rows or its body, another
`coop tendril fight` answers that it is busy. Every other `coop tendril` word is the viewer's.

What to expect:

- It walks on its hands and feet, its head about 1.4 m up, and strikes with the four chains on its head. Its skeleton
  faces sideways compared with its blueprint, so the mod turns its mesh by 90 degrees once it spawns (and again if the
  game turns it back), and gives it the Hydra's tentacle material, as `coop tendril skin hydra` does in the viewer.
- It has 64960 HP, 3720 shield and an attack power of 600 (the Gigas's numbers) and rank Boss, so the boss bar shows
  once it targets EVE. The game has no text for its name and shows `<M_TendrilC>`; the mod writes `Tendril` there.
- It has 11 attacks, each one of its own animations: two sweeps, two lashes and two diagonal swings with one chain, a
  chop with both chains that lands 6.6 m ahead, a spin, and three combos (Rush, four hits, the last two slamming down
  5.8 and 7.5 m ahead; Whip, three hits; Trace, two). Each hit strikes anyone in an arc in front of it, 4 to 7.5 m
  deep, while its chains strike. Guard, parry and perfect parry work on every hit, as on the Lion.
- It walks at 2 m/s, runs at 4 m/s and turns toward EVE at the start of each attack.
- EVE's hits play its knock-back animation. It never goes groggy, falls or flies: the game's animation sets for those
  states name animations it does not have.
- When it dies it plays its death animation (6 s), then dissolves as the Cocoon does. It drops nothing.
- As for the Lion: no quest event runs for it, it unlocks no album entry, it should not come back from a save, the rows
  and the Shows stay in memory until the game exits, and only your game has it.

The log lines, in `UE4SS.log` unless marked:

| Line | What it answers |
| --- | --- |
| `tables: 11/11 found: CharacterTable=0x...` | The 11 tables the Tendril's rows go into, found, with the addresses sent to the native part |
| `tendril rows: 107/107 added through SB's AddRow 0x14417ba30, 0 refused` (`coop-link.log`) | The native part added every row |
| `tendril rows by SB's lookups: CharacterTable 50060 1/1, SkillTable 5006000-5006010 11/11, stance 500600 1/1` (`coop-link.log`) | The game's own lookups by ID find its CharacterTable row, its 11 skills and its stance |
| `rows read back through FindRow: 107/107 authored rows, 1281 fields as written (997 differ from the template row)` | Every field the native part wrote reads as written |
| `shows: 12/12 ready (12 made, 0 found built), each with its own anim key on its clip and found by the path its steps name` | The Shows are built and the game can find them; after a Lua reload, `0 made, 12 found built` |
| `not ready: M_TendrilC_SwingLeft: no anim key of its own: no spawn` | A Show (or its package, `/Game/Art/Show/StellarCoop/Tendril`) could not be built, and why |
| `spawn 50060: CreateActor returned; body CH_M_NA_06_Blueprint_C 8.1 m from EVE, ...; controller SBAIController; EventSpawnId 0` | The body is in the world, with its controller and its spawn key (0) |
| `tendril 1: mesh yaw set to 0 (was -90)` | Its mesh turned to face its front |
| `tendril 1: material MI_M_NA_09_V03_Tentacle on its 1 slots` | The Hydra's material on its mesh, or why not |
| `boss name: <M_TendrilC> -> Tendril` | The boss bar's name set |
| `shows: M_TendrilC_Chop gone: built again` | The game dropped a Show while the Tendril lived, and the mod built it again |
| `tendril 1 (50060): 8.1 m, xyz ..., speed 0, skill yes, anim alpha 1.00/0.00, ...` | Once a second while it lives, the same fields as the Lion's line; `anim alpha` above 0 while a skill runs means its animation plays |
| `tendril 1 (50060) dead after 95 s (InteractionState 3, no controller); body gone after 22.0 s` | Its death and its body's despawn |
| `tendril 1 spawn count: before 6, alive 7, after death 6` | The game's spawn counter before the spawn, while it lived and after |

A refusal names its reason in `coop-link.log` (`tendril rows refused <row>: <why>; <n>/107 added`) and ends with a
`STOP:` line in `UE4SS.log`. A refusal of one batch leaves the others alone. See
[internals/cut-enemies.md](internals/cut-enemies.md#the-cut-tendril) for how the rows and the Shows are made.
