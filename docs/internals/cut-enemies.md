# Cut enemies: how they are added

The cut stimpacks, the ChainSpin, the Shock Bolt, Matrix XIII, the Night Operation shop and Lily's signal use the row
batches of `lion/rows.h` too, which [The cut Lion](#the-cut-lion) describes. The commands are in
[Cut enemies](../cut-enemies.md).

## The cut Lion

`coop lion` spawns the cut Naytiba 02, the Lion, as an enemy to fight (plan A of the Lion study). In its first test
(0.6.0-beta.1) it spawned, moved and hit EVE, but stayed in its idle pose. Its assets ship in
`/Game/Art/Character/Monster/CH_M_NA_02/`: the blueprint `CH_M_NA_02_BluePrint_Large`, the mesh with its fur cloth, 138
animations on the Behemoth's skeleton (`CH_M_NA_46_Skeleton`), hit and attack collision data and 41 Shows. No table row
names it. Six files do the work: `cut/enemy.lua` (the Lua flow, which [the Gardener](#the-cut-gardener) and [the
Tendril](#the-cut-tendril) share), `cut/lion.lua` (the Lion's spec and its own parts), `cut/lion_rows.lua` (the rows as
Lua reads them back), `lion/rows.h` (the rows and their build, free of Windows, tested on the build machine),
`lion/shock.h` (the Shock Bolt's two lists, also free of Windows) and `glue/tick/lion_game.inc` (the game's calls).
The rows of one request form a batch: `lion/rows.h` holds six, the lion rows batch below, the Gardener's, the
Tendril's, the Shock Bolt's (see [The cut Shock Bolt](night-operation-shop.md#the-cut-shock-bolt)), Matrix XIII's (see
[The cut Matrix XIII dungeon](matrix-xiii.md)) and the Night Operation shop's (see
[The Night Operation shop screen](night-operation-shop.md#the-night-operation-shop-screen)), each with its own request word, answer and status
line.

### The rows

The native part adds 237 rows to 14 tables: 222 are the Lion's own, and before them come 4 for the cut stimpacks of the
Night Operation shop (see [The cut stimpacks](night-operation-shop.md#the-cut-stimpacks)) and 11 for EVE's cut Tachy Mode ChainSpin (see
[The cut ChainSpin](cut-eve.md#the-cut-chainspin)). A generator kept outside the repository writes
every field of the Lion's rows from the Lion's assets and from offline measurements of its clips. A shipped row of each
table is only the struct the game copies (`CopyScriptStruct`) before the patches: the recipe sets every field that row
holds, to the Lion's value or to empty. For 894 of the 2087 fields the template holds, the Lion's value is the
template's own (the Behemoth's 180 degrees a second turn, 900 cm/s run and 1.5 s getup time, among others), so the patch
writes that value back. These template rows are Behemoth rows, and a Scarlet effect for the effect row. The one Behemoth
asset a Lion row names is the sound set `CSS_MON_46_BEHEMOTH`: the pak listing holds no sound set for the Lion, and its
blueprint names none.

- Stats, in both CharacterTable rows: 160000 HP, 3300 shield, 14 stamina, 960 physical and range attack, 110 shield
  attack. The Great Desert elites (Behemoth, Stalker, Abaddon) have 170500 HP, 3500 shield, 15 stamina and 840 to 1050
  attack; the Lion has a little less, as a boss with melee attacks only. Its target filter radius (190 cm) and rule-move
  block radius (240 cm) fit the Large blueprint's 150 cm capsule. Rank Elite, difficulty group MonsterElite (the same
  numbers as the Great Desert groups), actor type BossMonster, no reward. Zero stamina applies `M_LinkAttackDelay_10`,
  `Groggy`, `SkillCancel`, `BlockSkill` and `M_StaminaRecoverReady`, as on Stalker and Abaddon; EVE's link attack needs
  the target groggy. Detection is the shipped `M_DetectCommon20m360` (360 degrees, 20 m). The link flag is `Common`:
  EVE's generic link Show plays the Lion's own `Hit_Sword_Normal_LinkAttack1` on it. `Name` stays empty, since
  CharacterStringTable has no Lion text (see the spawn below).
- 21 skills (IDs 5002000 to 5002020), their 21 commands and 80 steps (a skill's ID times 100, plus 2 to 10). Each skill
  plays one Lion Show and follows that Show's steps one for one, in count and in duration: at each new step of the chain
  the game moves the playing Show to its next stage and never matches the Show's step IDs (`FSBSkillPresentationObject`
  queues each step row and reads its ID only for its log). The first 15 are the kit of 0.6.0-beta.1. The others are the
  Lion Shows with a clip that the kit left out: `ClawAttackChain` (three claws), `ClawAttackChain2` (four claws and a
  full turn), `MoveAttackChain` (three claws on the move), `RushAttack` (a leap, then a claw), `DashAttackChain` (four
  pounces over three clips) and `RoarPhaseChange` (the roar Show again, for phase 2).
- A Hit step is the Show step in which the striking claw, paw or jaw peaks. No Lion clip has a hit notify, so the
  striking point and its speed peak come from the decoded clips; their forward kinematics match the socket tracks the
  game bakes for 21 Lion clips within 0.14 cm on the clips' key frames, and up to 28 cm off between keys on fast hand
  frames. On every claw attack the `NS_Lion_ClawTrail_01` particle starts within 0.05 s of the Show's hit step. Six hits
  peak 0.017 to 0.074 s before their step, two of them claws (AttackToBackJump's first hit and MoveAttackChain's third),
  and the generator lists them. A claw strikes through `Mon_Lion_Attack_L_Arm_Collision` or `R_Arm`, a landing through
  `RL_Arm` (both arms). The roar and the dash chain hit through a target filter, since the collision data tracks no
  socket for the dash clips. Five result rows hold the game's own reaction Shows, effects and knockbacks: light (0.5 s
  stun), strong (0.8 s), knockdown (1.5 s), guard and parry. A perfect parry on a skill's last hit goes to the shipped
  step `M_Common_Result_ParryJust_Center`, which plays the Lion's `Result_Hit_JustParry`. EVE can neither parry nor
  guard the roars and the high jump, as with the Behemoth's, and the game's action assist checks them 0.066 s before the
  hit.
- 61 moves (CharacterMoveTable rows). Every Lion clip is in place: the root never moves, and each clip starts and ends
  on the idle pose. The travel the game has to give the Lion comes from each clip's planted feet, and in the air from
  the pelvis keeping its take-off velocity. On the Behemoth's own clips the planted feet give the distances and times of
  its move rows (its ScratchLeft finish: 146 cm over 0.22 to 0.58 s, against the row's 143 cm from 0.2 to 0.6 s); the
  flight estimate does not (its JumpAttackHigh hit step comes out at 1106.6 cm forward and 341.8 cm right against 427 cm
  of rows, its SmashBackflip finish at -1164.9 cm against -1588). A step that travels 30 cm or more gets one move over
  the time its feet move. 24 of these come from planted feet; 29 spend half their time or more in the clip's flight
  windows and are flight estimates, which the generator marks. The other 8 only turn the Lion.
- A move that heads toward where its skill expects EVE (within 60 degrees) goes along the line to her and stops short of
  her: `MovePositionType_InsideTargetOrSelf` with `MoveDirectionAxis_SelfToTarget`, the shape of the shipped lunges of
  Elder phase 2, Scarlet, Raven and Tachy. It goes its clip's length, or less when EVE is nearer, and stops
  `LimitApproachDistance` short of her: where the next strike lands at its peak, rounded down to 10 cm so the strike
  never lands short (150 cm for the low jump's paws, 800 cm for the high jump's, which land 8 m ahead of the root
  inside the clip; the paws reach 893 cm during that hit). That these moves stop short comes from the shipped rows
  (Scarlet's Airspin: 2000 cm with a 200 cm limit), not from the game's code. 43 moves are of this kind;
  the other 10 keep their travel along the Lion's own axes (the side steps, steps and jumps back or sideways, the roars'
  step forward). The side steps keep only their sideways travel (14.2 and 15.9 m), as the forward part is the method's
  error there. BackJumpToAttack has no move: its first step's travel is the net of two opposite flight estimates (-924
  cm, then +740 cm), and the clip spins the body about the root.
- A skill whose travel up to its first hit heads 30 degrees or more off its front looks for EVE there and keeps its
  heading while it moves, as its clip turns the body: RunAttackLeft and RunAttackRight at 80 degrees to the side,
  ClawAttackChaseRight at 40. In every other skill the moves turn the Lion toward EVE, and its first step does so on its
  own when that step has no move: at once for the turn attacks and the back jump, whose clips start with the body turned
  90 or 180 degrees away, else over that step.
- 23 target filters. A skill's range is the reach of its first hit toward where it expects EVE (the striking socket's
  farthest point that way during the hit step, at the mesh's 1.5 scale) plus what its moves close before that hit: a
  move toward EVE its whole length, any other its part toward her, negative when it goes away. The sum is multiplied by
  0.61: the Behemoth's ScratchLeft filter is 300 cm for a claw reach of 440 cm and a move of 53 cm before it. The low
  jump finds EVE within 490 cm, the high jump within 12.6 m, the run attacks within 520 and 550 cm, BackJumpToAttack
  only within 110 cm, as its claw comes down at its own front paws. The turn attacks look behind a side, the back jump
  behind, the roar in a 120-degree arc up to 7 m ahead. Each way the moves take the Lion 3 m or more gets the shortest
  shipped space check (`Valid_Move_*`) that covers it, or the longest of that way when none does (the side steps' 14.2
  and 15.9 m, and the high jump and three chains that go past 18 m forward).
- A skill with a move toward EVE before its first hit only starts when she stands past that move's stop: its filter's
  `NearDistance` is the stop plus 30 cm (the shortest travel that gets a move), rounded up to 10 cm. Seven skills get
  one: the low jump 180 cm, the high jump 830 cm, RushAttack 310 cm, the chasing claws 440 and 230 cm, the run attacks
  130 and 140 cm. Without it a skill could start with EVE inside the stop, and the lunge would hold or step back while
  the strike passed her. SB's own monster skills set no `NearDistance` beside such a limit (none of the 12 whose first
  such move has one, of 200 or 300 cm), and their ranges reach at least that far; the Lion's leaps stop farther out (up
  to 8 m). Where the stop plus 30 cm passes the skill's range (ClawAttackChain, ClawAttackChain2 and DashAttackChain,
  whose first strikes land at 360 to 430 cm against ranges of 340 to 440 cm), the moves before the first hit get no
  limit and go up to EVE, as the first such move does in 74 of SB's 86 monster skills that have one, and the filter
  keeps no `NearDistance`.
- Two anim sets (500200 and 500201) name the Lion's run clips and its `Result_*` reactions, and no shield break, which
  the Lion has no clip for.
- Two stances. `M_LionC_Default` (500200, phase 1) lists 17 commands; `M_LionC_Phase2` (500201) lists all 21. Both walk
  at 200 cm/s, the battle blend space's walk sample, and run at 900, the Behemoth's pace, and turn at 180 degrees a
  second, as the Behemoth does in both its phases (the Raven keeps its 360 in phase 2 too). At the Large scale the run
  clip strides about 1550 cm/s, past the blend space's last sample (600), so any boss pace slides its feet; 900 slides
  less than 600. Phase 2 is the Raven's data-only switch: the CharacterTable rows list it in `StanceAliasArray`, and it
  takes over at HP under 60% (Priority 10, Condition HP, UnderRate, 60). Its start restores the shield and applies
  `M_LionC_PhaseRoar`, an effect whose action uses the skill `M_LionC_RoarPhaseChange` (`EffectAction_UseSkill`, as the
  shipped `M_Scarlet_CounterLinkStart` does). That skill's AISkillFlag is `PhaseChange`, which neither tree picks. The
  first phase has no `MinimumHP_60p`: had the switch failed, that floor would hold the Lion at 60% HP for good.
- The dead row (the Lion's death Show for every kind of kill, then the `M_LionA_Despawn` dissolve) and the appearance
  row (50020, the Large blueprint).
- Two CharacterTable rows, added last: `M_LionC` (50020, the tree `M_Skulling_AI_Test`) and `M_LionC_Lurker` (50021,
  `M_LesserLurker_AI`). Both trees pick skills by their AISkillFlag (MeleeAttack), not by name, which leaves out the
  side steps (MoveAttack) and the phase-2 roar.

The generator writes the data part of `lion/rows.h` and the whole of `cut/lion_rows.lua` from the offline reader's dumps
of the tables, the Lion Shows and the collision data, the pak listing, the SDK and the clip measurements. It refuses a
taken ID or name (in any case, as the game compares names), a missing template, a field the SDK does not place where its
patch writes, and a template value the recipe does not set. It also refuses a value naming a Behemoth row or asset other
than the sound set, and a reference that lands on no Lion or shipped row: steps, skills, commands, stances, moves,
target filters, results, anim sets, effects (also inside JSON effect strings), Shows, clips, blueprint, tree and sound
set. Steps must match their Show's steps, each Hit step must hold its striking peak (0.1 s early or 0.05 s late at
most), and each collision group must exist with every socket tracked for the clip playing. A move toward where its skill
expects EVE must stop short of her, a skill whose move before its first hit stops short of her needs a range that starts
30 cm or more past that stop and ends past its start, a skill that looks for EVE off its front may not turn toward her
while it moves, no range may pass its first hit's reach plus what its moves close, and each way the moves take the Lion
3 m or more needs a space check that way, no shorter than that travel while a longer one ships. Anim sets must name
clips of the Lion's folder, and no stance may hold HP at 60%. Each link flag must pick EVE link steps whose Shows play a
clip the Lion has, and no move may travel over 17 m.

The game reads CharacterTable, SkillTable and CharacterStanceTable by ID, through maps that only its own AddRow fills
(the table's vtable slot `+0x2b0`, `0x14417ba30`). UE4SS's Lua `AddRow` is a raw RowMap insert that those maps miss, and
its `RemoveRow` frees a row they may still point to, so the mod calls neither on a game table. Lua finds the tables
the batch's rows go into by their fixed paths (`/Game/Local/Data/<table>.<table>`) and sends their addresses in one
request, for the Lion its 14:

```
lion rows CharacterTable=0x<address> CharacterAppearanceTable=0x<address> CharacterDeadTable=0x<address>
CharacterStanceTable=0x<address> CharacterAnimSetTable=0x<address> SkillCommandTable=0x<address>
SkillTable=0x<address> SkillActiveStepTable=0x<address> CharacterMoveTable=0x<address>
TargetFilterTable=0x<address> SkillResultTable=0x<address> EffectTable=0x<address> ItemTable=0x<address>
ItemConsumableTable=0x<address>
```

It is one line in `coop-request.txt`. The native part knows 37 tables (`kLionTables`, the 14 above, then
ProjectileTable, ZoneCampTable, ZoneEnvSpawnTable, ShopTable, ShopItemTable, ZoneTriggerTable, QuestTable,
QuestTaskGroupTable, QuestTaskTable, LevelTargetFilter, TheaterSelectDataTable, then Matrix XIII's EventSpawnTable,
EventItemTable, ZoneEventTable, EventEnvControlTable, WorldTransitionTable, EventZoneWarpTable and EffectVolumeTable,
then ConditionTable and ConditionGroupTable for Lily's menu in Matrix XIII, then AlbumTable, AchievementTable and
PuzzleStringArrayTable for its records);
a request names 1 to 37 of them, each once, in any order, and the others stay 0, which a batch that writes that table
refuses as no UDataTable. So a table no row of the batch uses, not loaded at that moment, stops nothing. A request
naming all 37 would take 1204 bytes at most with the 12 hex digits Lua's `%x` gives the highest plausible address and
its line end (1352 with 16 digits); the native part reads up to 2048 bytes of that file.
Each address has 1 to 16 hex digits, is plausible and is 8-aligned; anything else gets `unknown request`. No console
word reaches an address. The native part trusts none before it checks the table's vtable (`0x146402e10`), its AddRow
slot and its row size.

The game thread adds the rows in `coop_tick` only while the cached net mode is 0 and no logic task is in flight (logic
`+0x5c0` is 0, the same check as same-place enemies' force target): no lock guards the tables, and the logic thread
reads them. A shut gate tries again at the next frame and refuses after 300 frames. For each row not added yet, the
native part initializes a block of its own from the row struct, copies the template row into it (CopyScriptStruct),
writes the ID and the patches, resets the game's lazy-init flag (row `+8`) and the arrays the game parses from the row's
JSON strings, then calls AddRow through the table's vtable with the new name. A row goes in once a game run and never
again, so AddRow's own RemoveRow never frees a row that a living Lion reads. The first refusal stops the run before any
later row. The CharacterTable rows come last, so a refused run leaves no Lion to spawn; asking again skips the rows
already in. These calls run under their own SEH latch.

Then the native part reads the rows back through the game's own lookups by ID and writes the `lion=` line of
`coop-status.txt`:

```
lion=off
lion=waiting added=<n>/237 asks=<a> spawns=<s> why=<busy|net|unread> ticks=<t>
lion=rows added=237/237 asks=<a> spawns=<s> char=<k>/2 skills=<k>/23 stance=<k>/2
lion=refused added=<n>/237 asks=<a> spawns=<s> why=<word> table=<table|-> row=<row|->[ detail=<value>]
lion=fault added=<n>/237 asks=<a> spawns=<s> where=<text>
```

`asks` counts the answers; Lua waits for it to grow. `spawns` is the logic thread's spawn manager counter (`0x147032590`
`+0x198`), read every 250 ms once a first request came, `?` until then. It is read through ReadProcessMemory, outside
the SEH latch, so a bad read leaves the last value and never stops the rows. It moves whenever any enemy spawns or goes,
so `core/link.lua` leaves the line (and the Gardener's `gardener=`, the Tendril's `tendril=` and the Shock Bolt's
`bolt=`) out of its change log and `cut/enemy.lua` logs what it reads. Lua then reads every row back through `FindRow`
by field name (independent of the SDK's offsets): the ID and each of the 3178 fields the patches write, from
`cut/lion_rows.lua`, which the generator writes with `lion/rows.h` (the Lua test checks the two agree). 2156 of those
values differ from the template row's, so reading them back shows the patches landed; the other 1022 restate a value
the template holds, which a read-back cannot tell from the copy. It spawns only when every value matches and the line
says `char=2/2 skills=23/23 stance=2/2`. The
read-back runs in one frame, once per `coop lion`; how long that takes in game was not measured.

### The spawn

The spawn is one call, `nightop/run.lua`'s, with key 0:
`ServerRequest_CreateActor(<charId>, <location>, (0, <yaw>, 0), false, true, 0, 0, 0, None, false)`. Cheat on lets it
take any CharacterTable ID at any place. The charId is fixed in code: 50020, or 50021 after `coop lion brain lurker`;
`coop lion control` spawns 50110 (M_Antlion). The place is 10 m ahead of EVE and 1 m up, facing her. Key 0 is
EventSpawnId 0, as the game's own summons spawn. The body is the new character of the Large blueprint's class nearest
the spot, looked for at 0.3, 1, 2, 3.5 and 5 s among the SBCharacters of EVE's world from the engine's class hash
(`GetAllActorsOfClass`), or with `FindAllOf` of the class, which walks every object, where this UE4SS cannot use the
class hash. Up to 0.6.0-beta.3 every look walked. A body with no controller that reads `InteractionState` 0 gets its
default one 1.5 s after the call (`SpawnDefaultController`). Its death is read from `InteractionState` and
`Controller`: a value other than 0 with no controller. Every body of this spawn reads `InteractionState` 1
(executable) from its first second, in battle or not (the Lion's and the Antlion's follow lines, 2026-10-23), until its
death reads 3 (every death logged). For these bodies 1 is the standing state, not a sign of the fight, so
`nightop/run.lua` counts 0 and 1 as standing; a Night Operation run that counted 0 alone found none of its monsters
(2026-10-28). The Lion code (`cut/enemy.lua`) still adopts a body only at 0 and still reads any other value with no
controller as a death. That holds because these bodies had a controller from the spawn on (`controller SBAIController`
on 2026-10-23); a state-1 body without one would never be adopted and would read as dead. Which game code sets 1 was
not traced. The game can send a Lion body far away and reuse it for the next spawn (a Lion 466 m away
came back on 2026-10-23), so a body that stood more than 100 m from the spot at the call and stands within 30 m of it
after counts as the new one; its old follow line ends as recycled.

While a Lion lives, the follow line also carries what the first test lacked: the body's place, the speed its blend space
reads (`GetSBSpeedForAnimGraph`), whether a skill runs (`IsRunningSkill`) and the two custom anim alphas the animation
blueprint blends a Show's clip by (`GetCurrentCustomAnimAlpha(0)` and `(1)`). Nothing looks the Shows or their clips up:
a `StaticFindObject` of one took about 30 ms in game, a 50 ms frame each second (2026-10-24). One more check runs once a
second. The boss name (`cut/enemy.lua`'s, for any spec that names one) looks for the live `TextBlock_BossName` (under
`/Engine/Transient`; `FindAllOf` again at most every 10 s while none is held) and sets it to `Lion` where it reads
`<M_LionC>`. The game writes that block once per boss bind (`FText::FromStringTable` on the row's `Name`), so the check
puts the name back after each bind.

`coop lion intro` first plays `Mon_LionC_Scene01_Appearance` (13 s, the clip of the cut boss intro
`DesertedCity_LionBossIntro`) on a display copy: `race/doro.lua`'s plain actor with the `CH_M_NA_02_Large` mesh at the
blueprint's scale (1.5), on EVE's feet at the spot, facing her. At the clip's end the Lion spawns where the copy's bone
0 stands, at the spot's height. When that is more than 20 m from the spot, it spawns at the spot. The copy goes as soon
as the body shows, before the body's controller is checked, so the two never stand together. A map change during the
entrance spawns nothing. The clip does not play on the Lion itself: `CH_M_NA_02_AnimBP` has no slot node, so a montage
would not show; a single-node clip would replace the anim instance the game plays the Lion's skills on while its AI
runs. The copy is in no file, so a Lua reload during its 13 s leaves it until the map changes.

### What stays out

- Quests: a key-0 actor has no EventSpawn row, so no EventOnSpawning, EventOnBattle or EventOnDead runs. The one Lion
  quest task in the game's data, `EQ_DownTown_Quest_05_T01`, goes through spawn point 71, not an alias. Quest or
  condition tasks that count kills by tribe or actor type were not checked.
- Saves: an actor with no EventSpawn row is not in zone storage, so a save should not bring a Lion back (not checked in
  game). The rows are never written anywhere. The command spawns only on a co-op save.
- Achievements: a kill by EVE counts for the two Kill rows that take any enemy (`Kill_Character` and
  `Trophy_KillCharacter`), as any Naytiba kill does. It unlocks no album entry. On a boss bind and a boss kill, the game
  hands the row name to an achievement container through obfuscated code; whether that keeps anything was not
  established.
- Co-op: shared enemies pair by spawn key, and a key-0 actor has none, so the Lion stays in the game of the player who
  typed the command. Sharing one would need a key range of its own, a host spawn through `NewActor` in the shared
  fight's job, a guest rule in same spawns, a `kBosses` row and a protocol bump.

### Open questions

Only the game can settle these:

- whether the game's lookups by ID see the rows and the read-back matches on this build;
- whether the stance's command list builds the Lion's command set and `M_Skulling_AI_Test` runs on it;
- why the Lion stays in its idle pose: the game never plays its Shows on that body, the Shows play and their clips do
  not load, or the clips load and the animation blueprint does not blend them in (the follow line's skill flag and anim
  alphas narrow it down, and `coop lion control` tells the spawn call from the rows);
- whether the Lion walks to EVE or stands while she moves around it (the follow line now logs its place);
- where the lock-on marker sits, whether its feet meet the ground and whether its hit sounds play;
- what a key-0 death does to the spawn manager's counter;
- each AddRow runs the game's table-changed handling over the whole table, so 220 of them in one frame may cause a short
  hitch, not measured;
- whether the game's lookups of the 4 tables new to the rows (moves, target filters, results, effects) run the same
  lazy init as the other 8;
- whether `EffectAction_UseSkill` fires from a stance's start effect, so that the phase-2 roar plays (every shipped use
  comes from one of EVE's steps), and what it does when the Lion is in the middle of another skill;
- whether the moves mostly in the air (29 of the 61, a ballistic estimate) carry the Lion as far as its clips show,
  and whether a move with `MoveTransformType_None` turns the Lion at once for the turn attacks, whose clips start with
  the body turned;
- whether an `InsideTargetOrSelf` move stops `LimitApproachDistance` short of EVE as the shipped lunges suggest, what
  it does when she already stands closer than that, and whether the high jump, whose paws land 8 m ahead of the root
  inside the clip, still passes over an EVE nearer than that;
- how far each skill's range lets EVE stand before the Lion uses it, and whether 160000 HP makes a fight of the right
  length.

## The cut Gardener

`coop gardener fight` spawns the cut Naytiba 1, the Gardener (`CH_M_NA_01`), as an enemy. The game ships its
blueprint (`CH_M_NA_01_BluePrint`), mesh, 25 animations, three skill Shows, its projectile class and much of its cut
level's data: 9 skills with their commands and 43 steps (SingleShot and MultipleShot, each in four versions, and one
aimed at a marked ally), 37 projectile rows that all fire its own shell from the socket `SC_Shot`, a stance, two anim
sets and its appearance (`M_Gardener`, 50010), dead and detection rows. It lacks a CharacterTable row and a behaviour
tree. `cut/gardener.lua` holds its spec for `cut/enemy.lua`, the flow it shares with the Lion; its rows are the second
batch of `lion/rows.h` (`kGardenerRecipe`) and `cut/lion_rows.lua` (`R.GARDENER`), from the same generator.

### Its rows

The 13 rows are near copies: each is a shipped row with every field it holds restated and a few changed (279 fields,
102 of them changed).

- No shipped tree picks a skill flagged `Pattern1` or `Pattern2`, so the three skills are copies flagged
  `MeleeAttack`, which the flag trees (`M_Tentacle_AI`, `M_Skulling_AI_Test`) pick: `M_GardenerC_SingleShot`
  (5001010, a copy of `M_Gardener_SingleShot_4`, whose shells land on EVE, up to 3 m around her, and 15 and 18 m ahead
  of her), `M_GardenerC_MultipleShot` (5001011, of `M_Gardener_MultipleShot_1`: three volleys, cool time 10 s) and
  `M_GardenerC_ToxicBeam` (5001012, cool time 15 s). The first two start the shipped steps, whose durations equal their
  Shows' steps (1.3, 0.2 and 2.16 s; seven steps over 4.4 s). Each has a command row of the same name and ID.
- `M_Gardener_ToxicBeam` is a Show with one animation (5.33 s of `Mon_Gardener_S_03_Toxic_Beam`) and no step array, and
  no row names it. Three new steps play it: `Cast1` (500100043, 1.86 s, where most of the clip's beam notifies
  start), `Hit1` (500100044, 0.2 s, a copy of the shipped SingleShot hit step with 8 of the Gardener's own shells,
  which land from EVE to 15 m ahead of her over 0.7 s) and `Finish1` (500100045, 3.34 s): 5.4 s in all, the Show's
  length. Whether the game
  plays a Show with no step array across three table steps is not known.
- The stance `M_GardenerC_Default` (500101) lists the three commands and sets every walk and run speed to 0: the
  Gardener's run blend spaces hold one idle sample, so any move would slide the tower. It keeps the shipped anim sets
  and its turn rate (100 degrees a second); every cast step turns it toward EVE in 0.3 s.
- Three CharacterTable rows copy `M_Maelstrom`, the one boss that stays put (boss bar, Elite rank, its size fields):
  `M_Gardener` (50010) and `M_Gardener_Half` (50012, `MeshScale` 0.5) run `M_Tentacle_AI`, the flag tree made for
  monsters that never walk; `M_Gardener_Skulling` (50011) runs the Lion's `M_Skulling_AI_Test`. They take the
  Behemoth's HP (37840) and shield (1455), the shipped dead, appearance and detection rows, the Cocoon's despawn
  dissolve, the Maelstrom's sound set and the album's name key (`Char_M_Gardener_AlbumName`) for the boss bar. Their
  effects are rank Elite, a fixed location and a rule-move block (it never moves), immunity to the reactions it has no
  animation for and the Cocoon's two Show tags, no monster warp and immunity to back hits; the Maelstrom's own
  effects, its three weak points, its death effect and its link flag are gone.

The generator checks these rows with the Lion's batch (no name or ID of one meets the other) and against the dumps:
every shell the three skills' steps fire is a projectile row whose class, target filter, hit result, arrival effects
and landing marker exist, each skill's steps last as long as its Show (ToxicBeam's as long as all of it), the stance
lists exactly the three commands at speed 0, the name key is in `CharacterStringTable`, and no weak point names a group
missing from the collision data the blueprint uses (`CH_M_NA_02_Lion_Collision`: the Gardener's data started as a copy
of the Lion prototype's).

### Its batch in the native part

The Gardener's rows go in on their own request, `gardener rows <Table>=0x<address> ...`, with the same 20 table words as
the Lion's (`Request::batch` says which batch). Each batch has its own ask, answer word and builder (a `RowsJob` in
`glue/tick/lion_game.inc`) and its own line in `coop-status.txt`, `gardener=` in the `lion=` line's format with its own
counts (`added=<n>/13`, `char=<k>/3 skills=<k>/3 stance=<k>/1`). The gate, the block each row is built in, the spawn
counter and the SEH latch are shared: one fault ends every batch's calls for the game run, and every batch whose rows
are not all in then reads `fault`, also one that was never asked or whose ask the game thread had not taken (its `asks`
count unchanged; Lua's wait takes a `fault` line as the end either way). A batch checks only the tables its rows go
into, so a refusal in one leaves the other alone. This is a local request: the link protocol did not change.

No batch has a latch of its own, because no part of a batch's call stays clear of what the other batches use. The gate
reads the game's globals. Every row is built in the one block through the game's FName table, CopyScriptStruct and
allocator. AddRow writes tables that several batches write. From the recipes in `native/src/lion/rows.h`: ItemTable
gets lion, bolt and shop rows; SkillTable gets lion, gardener, tendril and bolt rows; SkillResultTable gets lion,
tendril and bolt rows; CharacterTable, CharacterStanceTable, SkillCommandTable and SkillActiveStepTable get rows from
all three Naytibas; five more tables get lion and tendril rows. The read-back runs the game's lookups over those same
tables. Only ProjectileTable (bolt), EffectTable and ItemConsumableTable (lion), ShopTable and ShopItemTable (shop) and
Matrix XIII's three zone tables have a single batch writing them, and those rows still go through the same block and
calls. A fault anywhere in that call may leave shared state half written, so it stops every batch. The status lines
are built by the worker from what the game thread published and make no engine call. The Shock Bolt's list growth
writes nothing a batch writes, and keeps its own latch ([The cut Shock Bolt](night-operation-shop.md#the-cut-shock-bolt)).

### Its spawn

`cut/gardener.lua` spawns 50010 (50012 with `half`, 50011 with `skulling`) through the Lion's call, 25 m ahead of EVE
(12.5 m at half size) and 7.5 m above her feet: the blueprint's capsule half-height (700 cm) plus 50 cm, so the capsule
never starts underground. The body is the new `CH_M_NA_01_BluePrint_C` nearest the spot. Its skeleton faces +Y (its
head at (0, 242, 1278) cm in the reference pose) where the game's monsters face +X, and the blueprint adds no turn, so
once found the body's mesh gets a relative yaw of -90 degrees (`K2_SetRelativeRotation`), which brings its front and
`SC_Shot` toward EVE. The follow line reads that yaw once a second and sets it again if the game turned it back.
`coop gardener fight intro` plays `Mon_Gardener_C_Appear` on a display copy of `CH_M_NA_01` turned the same way. No
Hide or UnHide plays: no Show plays those clips, and a clip on the real mesh would replace the anim instance the game
plays its skills on.

### Open questions

Beyond the Lion's:

- whether a Hit step fires every shell of its list or picks one, and whether the shells show in flight (their class's
  Niagara and particle components name no asset);
- whether `MeshScale` scales the capsule, the bones and the hit boxes or the mesh alone, and the hit boxes' heights in
  its idle pose (from the reference pose, only the right foot box is at melee height at scale 1);
- whether the game resets the mesh's relative yaw (the follow line says so if it does);
- what the Tentacle tree's `MoveToHome` does for an actor with no spawn path, and what its battle-start Show, another
  skeleton's clip, does on the Gardener;
- how the flag pick chooses among the three skills, and whether EVE can walk into the tower (only its capsule blocks);
- how the Cocoon's despawn dissolve applies to a mesh with two materials, and whether the English game shows
  "Gardener" on the bar.

## The cut Tendril

`coop tendril fight` spawns the cut Naytiba 6, the Tendril (`CH_M_NA_06`), as an enemy. The game ships a test mesh
(`CH_M_NA_06_test`, 166 bones, its one material slot empty), its skeleton, its physics asset, its blueprint
(`CH_M_NA_06_Blueprint`, which borrows the Gigas's collision data `CH_M_NA_05_Gorilla_Collision`), an animation
blueprint built on the game's custom anim nodes (`SBAnimInstance` with three `SBAnimGraphNode_SequenceBlendedPlayer`)
and 42 clips. No table row names it and no Show plays any of its clips. `cut/tendril.lua` holds its spec for
`cut/enemy.lua` and builds its Shows in memory; its rows are the third batch of `lion/rows.h` (`kTendrilRecipe`) and
`cut/lion_rows.lua` (`R.TENDRIL`, the Shows in `R.TENDRIL_SHOWS`), from the same generator.

### Its rows

107 rows, authored as the Lion's are: every field stated over the Lion's template rows (1281 fields, 997 of them set to
a value other than the template's).

- 11 skills (5006000 to 5006010), their commands and 45 steps. Each skill plays one Tendril clip from its first step
  to its end: `SwingLeft` and `SwingRight` (`M_Tendril_SwingAttack_L`, `_R`), `WhipLeft` and `WhipRight`
  (`M_Tendril_WhipAttack_L`, `_R`), `DiagonalLeft` and `DiagonalRight` (`M_Tendril_DiagonalAttack_L`, `_R`), `Chop`
  (`M_Tendril_ChopAttack`), `Spin` (`M_Tendrill_TurnAttack`), `Rush` (`M_Tendril_RushAttack`, four hits), `Whip`
  (`M_Tendril_WhipAttack`, three hits) and `Trace` (`M_Tendril_TraceAttackSlow`, two hits). All are flagged
  `MeleeAttack`, which the Skulling test tree picks, with cool times of 4 to 20 s.
- The steps follow the clip: a Cast step up to each hit, the Hit step, and a Finish step to the clip's end, so a
  skill's steps last as long as its clip. Its first step turns the Tendril toward EVE in 0.3 s (the one move,
  `M_TendrilC_Turn`). The Tendril strikes with the four chains on its head (`Bone_Chain_L01`, `L02`, `R01`, `R02`),
  which every attack clip animates. A Hit step is a window of the clip where the chains' last bones move at 2500 cm/s
  or more, 250 cm or more out from the root and no more than 2 m above it. The generator measures them in the clips
  decoded offline (`tendril_points.py`, forward kinematics on the bone tracks); the 17 hits strike 4 to 7.5 m out.
- Each Hit step hits by area (`HitDetectionType` TargetFilter, as the Lion's slams): a 3D arc 2 m high over the reach
  and the arc of the chain ends during its window, 400 to 750 cm deep and 60 to 340 degrees wide. The collision data
  the blueprint borrows tracks no Tendril clip, so a hit through its attack groups would not follow the chains. Every
  arc covers the front, since the first step turned the Tendril toward EVE. A skill's range is its first hit's reach
  straight ahead times the Lion's calibration (0.61): 240 to 400 cm.
- 5 hit results, the Lion's values under the Tendril's names (light, strong, knockdown, guard, parry). A perfect parry
  on a skill's last hit goes to the shipped step `M_Common_Result_ParryJust_Center`, which plays `Custom_Anim1` of the
  anim set: its `Parry` clip.
- Two anim sets (500600 and 500601) with its own clips: its one blend space (`IdleRun_BS_Peaceful`: idle, walk and run
  at 0, 200 and 400 cm/s), `LockOn_BS` in battle, `Run_Start` and `Run_End`, its one hit clip
  (`Result_Hit_KnockBack`, 1.5 s) in every hit slot, its groggy, knock-down and airborne clips, and `Parry` for both
  just-parry slots.
- The stance `M_TendrilC_Default` (500600): the 11 commands, walk 200 and run 400 cm/s (the blend space's samples),
  turn 180 degrees a second. The game's generic Groggy, Down and Airborne anim sets name blend spaces and clips its
  folder lacks (`Groggy_BS`, `Down_BS`, `Result_State_KnockDown_S_Fw` where it has `Result_State_KnockDown_Fw_S`), so
  the Tendril is immune to those states (`M_Common_ImmuneAbnormal`) and its stance names its battle set for them.
- The dead row plays its `Dead` clip (6 s) for every kind of kill, then the Cocoon's dissolve; the appearance row
  (50060) names its blueprint.
- `M_TendrilC` (50060), last: the Gigas's (`M_GorillaB`) numbers (64960 HP, 3720 shield, 600 attack, rank Boss, the
  `MonsterAlpha` difficulty group, actor type BossMonster for the boss bar) and sound set (`CSS_MON_05_Gigas`: none
  ships for the Tendril), the Lion's sizes at the ratio of their capsules (90 against 150 cm: a 110 cm target filter
  radius), the Skulling test tree, no link flag (EVE's link Shows play a target clip it lacks) and no `Name`.

The generator checks these rows with the other two batches (no name or ID of one meets another) and against the dumps:
every reference lands, each skill's steps last as long as its clip, every hit holds a strike and its arc covers the
front, the anim sets name clips of its folder, the stance lists its commands, the template Show has one anim key and
nothing else, and the blueprint turns its mesh as the measurements and `cut/tendril.lua` expect.

### Its Shows

A step names its Show in `ShowPath`. No pak holds a Show of a Tendril clip, so after the read-back and before the
spawn `cut/tendril.lua` builds the 12 the rows name, one per skill and one for its death, in a package of the mod's own,
`/Game/Art/Show/StellarCoop/Tendril`. The package is made once a game run by `StaticConstructObject` with no outer, as
UE's `CreatePackage` makes one: the outer passed is the invalid object of the lookup that missed it, whose null pointer
UE4SS hands on. Each Show is a copy of the Gardener's one-clip Show `M_Gardener_ToxicBeam`, made by
`StaticConstructObject` with that Show as its template, of its class, in that package, named after the skill
(`M_TendrilC_Chop`...). The package and the Shows go in the root set, so the game never collects them, and no shipped
package is held in memory by them: a Show of the paks that the game drops while its package stays could no longer load.
UE copies the template's properties and gives the copy its own anim key (`SBShowAnimKey_0`). The script then sets that
key's clip (`/Game/Art/Character/Monster/CH_M_NA_06/Animation/<clip>`, an absolute path), its lengths and the Show's
end time, with no step array, and reads each one back: the key must be the copy's own (its outer is the copy), every
value as written, and `/Game/Art/Show/StellarCoop/Tendril.<name>` must find the copy.

That path is the one the game loads. The steps' `ShowPath` is `StellarCoop/Tendril.<name>`. The game's Show loaders
(`0x1422853e0` and the six others that use the same `/Game/Art/Show/` string) put `/Game/Art/Show/` in front of it, keep
a path that already has an extension as it is (`0x14202c500` appends `.<last word>` only when there is none) and call
`StaticLoadObject` (`0x142b920d0`), synchronously. `StaticLoadObject` finds a package already in memory, then the object
in it, before it reads any file, so it returns the copy; no pak holds a package of that name, which the generator
checks. A Show with no step array plays across the whole chain of steps its first step starts, as the game's own flash
grenade and fishing skills do.

A Lua reload finds the package and the Shows already built and sets the Shows again. Once a second while a Tendril
lives, a Show that is gone (the root set flag did not hold) is built again, and the log says so.

### Its batch in the native part

The Tendril's rows go in on their own request, `tendril rows <Table>=0x<address> ...`, with their own job, answer and
`tendril=` line in the `lion=` line's format (`added=<n>/107`, `char=<k>/1 skills=<k>/11 stance=<k>/1`). The gate, the
block, the spawn counter and the SEH latch are shared with the other two batches. This is a local request: the link
protocol did not change.

### Its spawn

`cut/tendril.lua` spawns 50060 through the Lion's call, 8 m ahead of EVE (out of its strikes' reach) and 1 m above her
middle, facing her. The body is the new `CH_M_NA_06_Blueprint_C` nearest the spot. Its skeleton faces +X (its head is
in front of its pelvis, and a planted foot slides toward -X in its walk clip), while its blueprint turns the mesh -90
degrees as for a skeleton facing +Y, so once found the body's mesh gets a relative yaw of 0, and again if the game
turns it back. Its one material slot is empty, so the mesh takes the Hydra's tentacle material, as `coop tendril skin
hydra` does in the viewer. The boss bar reads `<M_TendrilC>` (no Tendril text in CharacterStringTable), and
`cut/enemy.lua` writes `Tendril` there as it writes `Lion` for the Lion. There is no entrance: none of its clips is one.

### Open questions

Beyond the Lion's:

- whether `StaticConstructObject` in UE4SS 3.0.1 makes the package with no outer and passes the template and the
  root set flag through, and whether the copy gets its own anim key;
- whether the game plays a Show built at run time, and a Show with no step array across the three to nine steps of a
  skill;
- whether the chains strike where the areas reach, and whether 2 m is the right height for the arcs;
- whether EVE's sword reaches it through the Gigas's hurt boxes, which sit on `Bip001` bones the Tendril shares;
- how the Hydra's material looks on the Tendril's mesh, and which hit sounds the Gigas's sound set gives.
