// The Lion boss's table rows (coop lion, the Lion study's plan A made native), free of Windows:
// tests/native/lion/rows_test.cpp checks it on the build machine against fake memory. The cut Naytiba CH_M_NA_02 ships
// its blueprint, meshes, clips, collision data and 41 Shows but no table row, so SB cannot spawn it. These are the rows
// it lacks, every one authored for the Lion by the generator (the generated part below says what each holds): 21 skills
// with their commands and 80 steps (the 15 of the first kit, the claw chain and the rush of phase 1, the second claw
// chain, the move chain, the dash chain and the phase-2 roar of phase 2), 61 moves timed on its clips' own travel
// (those toward EVE stop short of her), 23 target filters sized to its reach, 5 hit results, 2 anim sets, 2 stances
// (phase 1, and phase 2 at HP under 60%), the effect that runs the phase-2 roar, the dead and appearance rows, and two
// CharacterTable rows, M_LionC (50020) with the Skulling test tree and M_LionC_Lurker (50021) with the Lesser Lurker's:
// both trees pick skills by their AISkillFlag, never by command name. Each row starts as a copy of a shipped row of its
// table (the template: SB's CopyScriptStruct needs a valid row of the struct), and the patches set every field that
// template holds, some of them to the template's own value where the Lion's is the same. The rows live in memory for
// the game run; nothing is written to disk and no shipped row changes.
//
// The same batch carries, first, the rows of the cut items the Night Operation shop sells (nightop/shop.lua asks for
// them before a buy): the ItemTable rows of the Burst Stimpack (300013, over SB's own consumable HP2Burst_Potion) and
// the Beta Stimpack (300014), the Beta Stimpack's ItemConsumableTable row (1032) and the SkillTable row both play,
// P_Eve_Sword_Normal_Buff_1 (6000101), which HP2Burst_Potion names and SB never shipped. Each is a near copy of a
// shipped row (its own template, which the generator reads from the dump): the health potion's item, HP2Burst_Potion
// and the health potion's drinking skill, with the few fields that make it the cut item.
//
// After them come EVE's cut Tachy Mode ChainSpin (coop chainspin, cut/chainspin.lua), near copies too: the SkillTable
// row P_Eve_Tachy_Skill_ChainSpin1_1 (1004500, ChainStab1's row starting its own steps), its 9 steps (100450001 to
// 100450009, ChainStab1's steps with the timing, moves and hit area of the Tachy NPC's version, which play the NPC's
// shipped Show of EVE's own ChainSpin clip and take SB's shipped ChainSpin moves) and the EffectTable row
// P_Eve_Tachy_Skill_ChainSpin1_Use (1004500), whose UseSkill action starts the skill while EVE is in Tachy Mode.
//
// A second batch, the cut Gardener's (coop gardener fight, cut/gardener.lua; kGardenerRecipe), goes in on its own ask,
// so a refusal in one batch never stops another: 13 near copies of shipped rows (the 3 steps of its ToxicBeam, its 3
// skills and their commands, a stance that never moves and 3 CharacterTable rows over M_Maelstrom: M_Gardener 50010,
// M_Gardener_Skulling 50011 and the half-scale M_Gardener_Half 50012). A third, the cut Tendril's (coop tendril fight,
// cut/tendril.lua; kTendrilRecipe), is authored as the Lion's: 107 rows over the Lion's templates (11 skills on its own
// clips with their commands and 45 steps, 28 target filters, 5 hit results, its turn toward EVE, 2 anim sets, a
// stance, the dead and appearance rows and M_TendrilC 50060). Its steps and its death name Shows no pak holds, which
// cut/tendril.lua builds in memory before a spawn. A fourth, the Shock Bolt's (kBoltRecipe), holds the 4 rows of EVE's
// cut ammo the Night Operation shop sells, and only a Shock Bolt buy asks for it (nightop/shop.lua through
// cut/lion.lua), so these rows never stand in front of the Lion's: ItemTable Bullet_Shock (32, over Bullet_Scatter),
// the SkillTable row its consumable plays, P_Eve_Gun_ShootShockSlug1_1 (1003401, Scatter's skill on SB's shipped Shock
// steps), the projectile those steps fire, ProjectileTable P_Eve_Gun_ShootShockSlug1_Projectile1 (1010051, the normal
// slug's), and its hit result with SB's shock stun (SkillResultTable 100200801). What makes the ammo selectable and the
// gun fire it is no row: lion/shock.h grows two lists in place once these rows are in. A fifth, Matrix XIII's
// (kMxiiiRecipe, written by hand below the generated part with its own patches), holds the 2 rows the cut dungeon's
// first zone lacks for SB's camp travel (coop mxiii, cut/mxiii.lua): ZoneCampTable DLC02_10_Camp_01 (280001, a copy of
// ME01_Camp_03 never shown on the world map) and ZoneEnvSpawnTable DLC02_10_EnvS_900 (2800032900, a copy of the
// DLC02_10 camp kit's DLC02_10_EnvS_425, in Zone_DLC02_10, whose TargetCamp names that camp), in the two zone tables
// only it writes. A Batch names its rows, its patches and the word its status line, log lines and request start with
// ("lion", "gardener", "tendril", "bolt", "mxiii": coop-status.txt's shock line is lion/shock.h's); every batch shares
// the table checks, the block and the rules below, and each keeps its own Builder.
//
// SB reads CharacterTable, SkillTable and CharacterStanceTable by ID through maps that only its own AddRow fills (the
// table's vtable slot +0x2b0), so every row goes in through that call, on the game thread with no logic task in flight
// (glue/tick/lion_game.inc's gate: no lock guards the tables). For each row not added yet, in order: the table must be
// SB's UDataTable with its row struct of the size the SDK gives; the new name must be free in RowMap and the new ID
// free in the table's ID map; the template is found by name; then the row is built in a block the glue owns
// (InitializeStruct, CopyScriptStruct from the template, the ID at +0x10, the patches) and handed to AddRow, which
// removes any row of that name, copies ours into its own allocation and fills the ID and index maps. The first refusal
// stops the run before any later row of its batch, and each batch's CharacterTable rows come last, so NewActor finds
// 50020 (or 50010, 50060) only once every other row of its batch is in. A row is added once a run: a later run skips
// it, so AddRow's RemoveRow never frees a row a Lion (or a Gardener, a Tendril) still reads.
//
// SB parses a row's JSON strings (StartEffect, AttackCollisionGroupArray, AttackerEffectWhenDead, a hit result's
// effects...) into Transient arrays the first time it uses the row (row +8 is 0 until then; every lookup site sets it
// and calls the row's vtable +0x20). The copy carries the template's flag and parsed arrays, so the block's flag goes
// back to 0 and its Transient arrays to empty: AddRow's copy then reads as a freshly loaded row, and SB parses our
// strings on its own copy. The 4 tables the Lion's own moves, filters, results and effect need (CharacterMoveTable,
// TargetFilterTable, SkillResultTable, EffectTable) derive from the same FSBTablePropertyBase, with its flag at +8;
// that SB's lookups of their rows run the same lazy init was not traced, and resetting a flag the struct does not use
// changes nothing.
//
// The block's strings and arrays point at its pool (UTF-16 text, FName and FString arrays), which AddRow's copy
// duplicates into SB's allocations. The block is never destroyed: the next row's InitializeStruct writes over it.
// ponytail: each row's copy of the template's strings and arrays leaks inside the block's history, a few KB a game run;
// destroying the block would free our pool through SB's allocator instead.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

namespace coop::lion {

// SB's UDataTable vtable and its AddRow slot (the exe's EmptyTable, RemoveRow and AddRow at +0x2a0, +0x2a8, +0x2b0;
// UE4SS 3.0.1 computes them one slot off), the row struct (+0x28) and its PropertiesSize (UScriptStruct +0x58).
constexpr uint64_t kImageBase = 0x140000000, kTableVtable = 0x146402e10, kAddRow = 0x14417ba30;
constexpr size_t kAddRowSlot = 0x2b0, kRowStruct = 0x28, kPropertiesSize = 0x58;
// A row: its vtable, SB's lazy-init flag (a byte at +8: 0 until first used) and, in tables that have one, its ID.
constexpr size_t kInitFlag = 8, kIdAt = 0x10;
// The glue's block: the row at +0, the patches' strings and lists in the pool after it.
constexpr size_t kRowBytes = 0x1000, kPoolBytes = 0x1000, kBlock = kRowBytes + kPoolBytes;

// The 17 tables, in coop::kLionTables' order (link/protocol.h): Lua's rows requests (lion, gardener, tendril, bolt,
// mxiii) name each with its address. The generated kTables describes the first kGeneratedTables, kZoneTables the two
// zone tables after them, camp (ZoneCampTable) and env (ZoneEnvSpawnTable); table_info() reads either.
enum class Table : uint8_t {
  character,
  appearance,
  dead,
  stance,
  anim,
  command,
  skill,
  step,
  move,
  filter,
  result,
  effect,
  item,
  consumable,
  projectile,
  camp,
  env
};
constexpr size_t kTableCount = 17, kGeneratedTables = 15;
struct TableInfo {
  const char *name;       // The asset, /Game/Local/Data/<name>.<name>.
  uint32_t size;          // Its row struct's PropertiesSize.
  bool id;                // An ID at +0x10, which AddRow puts in the table's ID maps.
  uint16_t transient[25]; // The Transient TArrays SB's lazy init fills from the row's JSON strings; 0 ends the list.
};
// A patch writes one field of the copy: a float, an int32 or a byte (a bool or an enum's value), both held exactly in f
// (the generator keeps every int32 under 2^24), an FName, an FString (UTF-16 in the pool), or a TArray of FNames or of
// FStrings (items joined by '|' in text; empty text: an empty array).
enum class Kind : uint8_t { f32, i32, u8, name, string, names, strings };
struct Patch {
  uint16_t at;
  Kind kind;
  float f;
  const char *text;
};
struct Row {
  Table table;
  const char *name, *donor; // donor: the template row, the struct copied before the patches.
  uint32_t id;              // 0 in a table with no ID.
  uint16_t first, count;    // Its patches in kPatches.
};

// ---- Generated by ~/.claude/project-notes/stellar-blade-minecraft/tools/lion-rows/gen.py: do not edit by hand ----
// The Lion's own rows, the cut items' and EVE's Tachy ChainSpin's (SkillTable P_Eve_Sword_Normal_Buff_1,
// ItemConsumableTable Buff_HP2MP, ItemTable HP2Burst_Potion, ItemTable Buff_HP2MP, SkillActiveStepTable
// P_Eve_Tachy_Skill_ChainSpin1_1_Cast1, SkillActiveStepTable P_Eve_Tachy_Skill_ChainSpin1_1_Hit1,
// SkillActiveStepTable P_Eve_Tachy_Skill_ChainSpin1_1_Cast2, SkillActiveStepTable
// P_Eve_Tachy_Skill_ChainSpin1_1_Hit2, SkillActiveStepTable P_Eve_Tachy_Skill_ChainSpin1_1_Cast3,
// SkillActiveStepTable P_Eve_Tachy_Skill_ChainSpin1_1_Hit3, SkillActiveStepTable
// P_Eve_Tachy_Skill_ChainSpin1_1_Cast4, SkillActiveStepTable P_Eve_Tachy_Skill_ChainSpin1_1_Hit4,
// SkillActiveStepTable P_Eve_Tachy_Skill_ChainSpin1_1_Finish1, SkillTable P_Eve_Tachy_Skill_ChainSpin1_1,
// EffectTable P_Eve_Tachy_Skill_ChainSpin1_Use): 237 in all (character 2, appearance 1, dead 1, stance 2, anim 2,
// command 21, skill 23, step 89, move 61, filter 25, result 5, effect 2, item 2, consumable 1), 3178 fields. 2271
// of them set a field the template row held, 1022 of those to the value it held (the new row's value is the same:
// every field of a near copy but the few it changes); the other 907 fill fields it left empty. From the offline
// reader's dumps of the 15 tables, the Lion Shows, the ChainSpin Show, the Large blueprint and its
// CH_M_NA_02_LionC_Collision, the pak listing, the Dumper-7 SDK (stellar-sdk-647527f) and the Lion's animation
// points (lion-points.json).
// Hit steps that follow their Show where the striking peak sits just outside:
//   JumpAttackLow Hit1: the body peaks at 1.100 s, 0.030 s before its Hit step (1.130-1.230 s)
//   AttackToBackJump Hit1: the claw_R peaks at 1.133 s, 0.017 s before its Hit step (1.150-1.350 s)
//   MoveAttackChain Hit3: the claw_R peaks at 2.967 s, 0.033 s before its Hit step (3.000-3.100 s)
//   DashAttackChain Hit1: the jaw peaks at 1.467 s, 0.074 s before its Hit step (1.541-2.023 s)
//   DashAttackChain Hit2: the body peaks at 2.200 s, 0.026 s before its Hit step (2.226-2.849 s)
//   DashAttackChain Hit4: the body peaks at 3.667 s, 0.019 s before its Hit step (3.686-4.306 s)
// Where each skill looks for EVE (its target filter: the arc's centre, degrees right of the Lion's front, and range)
// and the space checks its moves need:
//   ClawAttackLeft: 0 within 360 cm; space none
//   ClawAttackRight: 0 within 360 cm; space none
//   ClawAttackChaseLeft: 0 within 490 cm; space Forward_700
//   ClawAttackChaseRight: -40 within 480 cm; space Forward_700, SideL_400_50
//   TurnAttackLeft: -110 within 320 cm; space none
//   TurnAttackRight: 110 within 320 cm; space none
//   RunAttackLeft: -80 within 550 cm; space SideL_1100
//   RunAttackRight: 80 within 520 cm; space SideR_1000_50
//   JumpAttackLow: 0 within 490 cm; space Forward_700
//   JumpAttackHigh: 0 within 1250 cm; space Forward_1800
//   BackJumpToAttack: 180 within 110 cm; space none
//   AttackToBackJump: 0 within 320 cm; space Back_1100
//   Roar: 0 within 700 cm; space none
//   SideStepLeft: 100 within 1420 cm; space SideL_1100
//   SideStepRight: -100 within 1590 cm; space SideR_1200_50
//   ClawAttackChain: 0 within 350 cm; space Forward_1800
//   ClawAttackChain2: 0 within 340 cm; space Forward_1800, SideR_700
//   MoveAttackChain: 0 within 330 cm; space Forward_1800
//   RushAttack: 0 within 730 cm; space Forward_1800
//   DashAttackChain: 0 within 440 cm; space Forward_1800
//   RoarPhaseChange: 0 within 8000 cm; space none
// The moves, from the clip's planted feet, or a ballistic estimate where the move's span is mostly in the air.
// A move toward EVE goes up to its length along the line to her and stops that far short of her:
//   M_LionC_ClawAttackLeft_Turn: turn toward EVE over the first step
//   M_LionC_ClawAttackRight_Turn: turn toward EVE over the first step
//   M_LionC_ClawAttackChaseLeft_Move1: up to 54 toward EVE, 410 short, 0.267-0.700 s (feet)
//   M_LionC_ClawAttackChaseLeft_Move2: up to 273 toward EVE, 410 short, 0.033-0.300 s (feet)
//   M_LionC_ClawAttackChaseLeft_Move3: 2 fwd, 81 right, 0.033-0.367 s (feet)
//   M_LionC_ClawAttackChaseRight_Move1: up to 66 toward EVE, 200 short, 0.400-0.700 s (feet)
//   M_LionC_ClawAttackChaseRight_Move2: up to 275 toward EVE, 200 short, 0.033-0.300 s (feet)
//   M_LionC_ClawAttackChaseRight_Move3: up to 195 toward EVE, 200 short, 0.033-0.333 s (in the air)
//   M_LionC_TurnAttackLeft_Turn: turn toward EVE at once
//   M_LionC_TurnAttackRight_Turn: turn toward EVE at once
//   M_LionC_RunAttackLeft_Move1: up to 143 toward EVE, 100 short, 0.600-0.833 s (feet)
//   M_LionC_RunAttackLeft_Move2: up to 602 toward EVE, 100 short, 0.037-0.437 s (in the air)
//   M_LionC_RunAttackLeft_Move3: up to 265 toward EVE, 100 short, 0.050-0.250 s (in the air)
//   M_LionC_RunAttackRight_Move1: up to 147 toward EVE, 110 short, 0.700-0.833 s (feet)
//   M_LionC_RunAttackRight_Move2: up to 545 toward EVE, 110 short, 0.037-0.437 s (in the air)
//   M_LionC_RunAttackRight_Move3: up to 252 toward EVE, 110 short, 0.050-0.383 s (in the air)
//   M_LionC_JumpAttackLow_Move1: up to 616 toward EVE, 150 short, 0.667-1.100 s (in the air)
//   M_LionC_JumpAttackHigh_Turn: turn toward EVE over the first step
//   M_LionC_JumpAttackHigh_Move2: up to 1154 toward EVE, 800 short, 0.073-0.640 s (in the air)
//   M_LionC_JumpAttackHigh_Move3: up to 899 toward EVE, 800 short, 0.033-0.333 s (in the air)
//   M_LionC_BackJumpToAttack_Turn: turn toward EVE at once
//   M_LionC_AttackToBackJump_Turn: turn toward EVE over the first step
//   M_LionC_AttackToBackJump_Move3: -1034 fwd, 59 right, 0.383-1.617 s (in the air)
//   M_LionC_Roar_Turn: turn toward EVE over the first step
//   M_LionC_Roar_Move3: 175 fwd, 5 right, 0.433-1.400 s (feet)
//   M_LionC_SideStepLeft_Move1: 0 fwd, -1419 right, 0.067-1.300 s (in the air)
//   M_LionC_SideStepRight_Move1: 0 fwd, 1589 right, 0.100-1.267 s (in the air)
//   M_LionC_ClawAttackChain_Move1: up to 40 toward EVE, 0 short, 0.333-0.767 s (feet)
//   M_LionC_ClawAttackChain_Move2: up to 95 toward EVE, 0 short, 0.050-0.250 s (feet)
//   M_LionC_ClawAttackChain_Move3: up to 43 toward EVE, 310 short, 0.033-0.100 s (feet)
//   M_LionC_ClawAttackChain_Move4: up to 32 toward EVE, 310 short, 0.033-0.200 s (in the air)
//   M_LionC_ClawAttackChain_Move5: up to 51 toward EVE, 440 short, 0.033-0.167 s (feet)
//   M_LionC_ClawAttackChain_Move6: up to 270 toward EVE, 440 short, 0.050-0.417 s (in the air)
//   M_LionC_ClawAttackChain_Move7: up to 600 toward EVE, 440 short, 0.050-0.650 s (in the air)
//   M_LionC_ClawAttackChain2_Move1: up to 38 toward EVE, 0 short, 0.333-0.767 s (feet)
//   M_LionC_ClawAttackChain2_Move2: up to 66 toward EVE, 0 short, 0.050-0.250 s (feet)
//   M_LionC_ClawAttackChain2_Move4: up to 54 toward EVE, 370 short, 0.033-0.200 s (feet)
//   M_LionC_ClawAttackChain2_Move5: up to 31 toward EVE, 550 short, 0.033-0.167 s (feet)
//   M_LionC_ClawAttackChain2_Move6: up to 225 toward EVE, 550 short, 0.083-0.417 s (in the air)
//   M_LionC_ClawAttackChain2_Move7: up to 845 toward EVE, 0 short, 0.083-1.083 s (feet)
//   M_LionC_ClawAttackChain2_Move8: up to 246 toward EVE, 0 short, 0.067-0.367 s (in the air)
//   M_LionC_ClawAttackChain2_Move9: 328 fwd, 669 right, 0.083-1.150 s (in the air)
//   M_LionC_MoveAttackChain_Move1: -59 fwd, -82 right, 0.667-0.900 s (in the air)
//   M_LionC_MoveAttackChain_Move3: up to 562 toward EVE, 200 short, 0.083-0.617 s (in the air)
//   M_LionC_MoveAttackChain_Move4: up to 169 toward EVE, 200 short, 0.033-0.200 s (feet)
//   M_LionC_MoveAttackChain_Move5: up to 1244 toward EVE, 340 short, 0.100-0.833 s (in the air)
//   M_LionC_MoveAttackChain_Move6: up to 45 toward EVE, 340 short, 0.033-0.100 s (feet)
//   M_LionC_RushAttack_Move1: up to 110 toward EVE, 280 short, 0.100-0.200 s (in the air)
//   M_LionC_RushAttack_Move2: up to 321 toward EVE, 280 short, 0.053-0.187 s (in the air)
//   M_LionC_RushAttack_Move3: up to 485 toward EVE, 280 short, 0.045-0.278 s (in the air)
//   M_LionC_DashAttackChain_Move1: -48 fwd, -116 right, 0.800-1.533 s (feet)
//   M_LionC_DashAttackChain_Move2: up to 326 toward EVE, 0 short, 0.092-0.492 s (in the air)
//   M_LionC_DashAttackChain_Move3: up to 381 toward EVE, 0 short, 0.044-0.210 s (feet)
//   M_LionC_DashAttackChain_Move4: up to 316 toward EVE, 0 short, 0.041-0.607 s (feet)
//   M_LionC_DashAttackChain_Move5: up to 118 toward EVE, 260 short, 0.051-0.284 s (feet)
//   M_LionC_DashAttackChain_Move6: up to 157 toward EVE, 260 short, 0.075-0.375 s (in the air)
//   M_LionC_DashAttackChain_Move7: up to 239 toward EVE, 200 short, 0.053-0.220 s (in the air)
//   M_LionC_DashAttackChain_Move8: up to 802 toward EVE, 200 short, 0.047-0.647 s (in the air)
//   M_LionC_DashAttackChain_Move9: up to 68 toward EVE, 200 short, 0.061-0.127 s (in the air)
//   M_LionC_RoarPhaseChange_Turn: turn toward EVE over the first step
//   M_LionC_RoarPhaseChange_Move3: 175 fwd, 5 right, 0.433-1.400 s (feet)
constexpr TableInfo kTables[kTableCount] = {
    {"CharacterTable", 0x548, true, {0x538}},              // SBCharacterTableProperty
    {"CharacterAppearanceTable", 0x158, true, {}},         // SBCharacterAppearanceTableProperty
    {"CharacterDeadTable", 0x2d0, false, {}},              // SBCharacterDeadTableProperty
    {"CharacterStanceTable", 0x220, true, {0x200, 0x210}}, // SBCharacterStanceTableProperty
    {"CharacterAnimSetTable", 0xc98, true, {}},            // SBCharacterAnimSetTableProperty
    {"SkillCommandTable", 0x100, true, {}},                // SBSkillCommandTableProperty
    {"SkillTable", 0x308, true, {0x2f8}},                  // SBSkillTableProperty
    // SBSkillActiveStepTableProperty
    {"SkillActiveStepTable", 0x390, true, {0x300, 0x310, 0x320, 0x330, 0x340, 0x350, 0x360, 0x370, 0x380}},
    {"CharacterMoveTable", 0x130, true, {}}, // SBCharacterMoveTableProperty
    {"TargetFilterTable", 0xb8, true, {}},   // SBSkillTargetFilterTableProperty
    // SBSkillResultTableProperty
    {"SkillResultTable", 0x4b0, true, {0x320, 0x330, 0x340, 0x350, 0x360, 0x370, 0x380, 0x390, 0x3a0,
                                       0x3b0, 0x3c0, 0x3d0, 0x3e0, 0x3f0, 0x400, 0x410, 0x420, 0x430,
                                       0x440, 0x450, 0x460, 0x470, 0x480, 0x490, 0x4a0}},
    {"EffectTable", 0x588, true, {0x578}},   // SBEffectTableProperty
    {"ItemTable", 0x1c0, true, {}},          // SBItemTableProperty
    {"ItemConsumableTable", 0x58, true, {}}, // SBItemConsumableTableProperty
    {"ProjectileTable", 0x398, true, {0x328, 0x338, 0x348, 0x358, 0x368, 0x378, 0x388}}, // SBProjectileTableProperty
};
constexpr Patch kPatches[] = {
    // P_Eve_Sword_Normal_Buff_1 (SkillTable, cut item)
    {0x070, Kind::i32, 1, nullptr},                              // HitLevel
    {0x074, Kind::u8, 5, nullptr},                               // AttributeType
    {0x0b4, Kind::name, 0, "Self"},                              // TargetFilterAlias
    {0x100, Kind::name, 0, "P_Eve_Sword_Normal_Potion_1_Cast1"}, // FirstSkillActiveAlias
    {0x124, Kind::f32, 0.2f, nullptr},                           // CoolTime
    {0x14c, Kind::u8, 1, nullptr},                               // Cancelable
    {0x189, Kind::u8, 1, nullptr},                               // bIgnoreAttackSpeedStat
    {0x2f0, Kind::name, 0, "Sys"},                               // FileSuffix
    // Buff_HP2MP (ItemConsumableTable, cut item)
    {0x014, Kind::name, 0, "CG_Item_ConsumeAllow_HP2MP"},                       // ConditionGroup
    {0x020, Kind::names, 0, "Item_Buff_HP2MP_ReduceHP|Item_Buff_HP2MP_GainMP"}, // EffectAliasArray
    {0x038, Kind::name, 0, "P_Eve_Sword_Normal_Buff_1"},                        // ConsumeSkillAlias
    // HP2Burst_Potion (ItemTable, cut item)
    {0x01c, Kind::i32, 5, nullptr},                           // InventoryPriority
    {0x030, Kind::string, 0, "Item_HP2Burst_Potion_Name"},    // Name
    {0x050, Kind::string, 0, "Item_HP2Burst_Potion_Fuction"}, // DescFunction
    {0x060, Kind::string, 0, "Item_HP2Burst_Potion_Content"}, // DescContent
    {0x070, Kind::u8, 5, nullptr},                            // Category
    {0x07c, Kind::u8, 1, nullptr},                            // Rarity
    {0x07d, Kind::u8, 1, nullptr},                            // SaveType
    {0x07e, Kind::u8, 0, nullptr},                            // IncludeDropPool
    {0x080, Kind::i32, 1000, nullptr},                        // StackAmount
    {0x084, Kind::i32, 999999, nullptr},                      // MaxAmount
    {0x08c, Kind::i32, 2, nullptr},                           // ChargeCount
    {0x090, Kind::u8, 0, nullptr},                            // ChargeOverrideActorStat
    {0x091, Kind::u8, 1, nullptr},                            // AbleBroken
    {0x092, Kind::u8, 1, nullptr},                            // AblePrice
    {0x093, Kind::u8, 1, nullptr},                            // AbleDrop
    {0x094, Kind::i32, 1, nullptr},                           // RequireLevel
    {0x098, Kind::string, 0, "/Game/Art/Item/BP_Item_HP2Burst_Potion.BP_Item_HP2Burst_Potion"}, // StudioAsset3D
    {0x0a8, Kind::string, 0, "/Game/Art/Item/BP_Item_HP2Burst_Potion.BP_Item_HP2Burst_Potion"}, // Asset3D
    {0x0c8, Kind::f32, 8.5f, nullptr},                                                          // AssetZOffset
    {0x0cc, Kind::f32, 1.0f, nullptr},                                                          // Asset3DScale
    {0x0d0, Kind::string, 0, "/Game/Art/UI/Texture/Item/Burst.Burst"},                          // Asset2D
    // GainAllowShowPath
    {0x108, Kind::string, 0, "SBShowData'/Game/Art/Show/Item/M_Item_GainAllow_Common_R.M_Item_GainAllow_Common_R'"},
    {0x14c, Kind::name, 0, "HP2Burst_Potion"}, // ConsumableAlias
    {0x18a, Kind::u8, 106, nullptr},           // ScanDisplayType
    {0x18c, Kind::name, 0, "Heal"},            // ScanDisplayGroup
    {0x1a4, Kind::u8, 1, nullptr},             // bMaintainNewGamePlus
    {0x1b4, Kind::name, 0, "Consume"},         // FileSuffix
    // Buff_HP2MP (ItemTable, cut item)
    {0x01c, Kind::i32, 6, nullptr},                                                       // InventoryPriority
    {0x030, Kind::string, 0, "Item_Buff_HP2MP_Name"},                                     // Name
    {0x050, Kind::string, 0, "Item_Buff_HP2MP_Function"},                                 // DescFunction
    {0x060, Kind::string, 0, "Item_Buff_HP2MP_Content"},                                  // DescContent
    {0x070, Kind::u8, 5, nullptr},                                                        // Category
    {0x07c, Kind::u8, 1, nullptr},                                                        // Rarity
    {0x07d, Kind::u8, 1, nullptr},                                                        // SaveType
    {0x07e, Kind::u8, 0, nullptr},                                                        // IncludeDropPool
    {0x080, Kind::i32, 1000, nullptr},                                                    // StackAmount
    {0x084, Kind::i32, 999999, nullptr},                                                  // MaxAmount
    {0x08c, Kind::i32, 2, nullptr},                                                       // ChargeCount
    {0x090, Kind::u8, 0, nullptr},                                                        // ChargeOverrideActorStat
    {0x091, Kind::u8, 1, nullptr},                                                        // AbleBroken
    {0x092, Kind::u8, 1, nullptr},                                                        // AblePrice
    {0x093, Kind::u8, 1, nullptr},                                                        // AbleDrop
    {0x094, Kind::i32, 1, nullptr},                                                       // RequireLevel
    {0x098, Kind::string, 0, "/Game/Art/Item/BP_Item_Potion_Large.BP_Item_Potion_Large"}, // StudioAsset3D
    {0x0a8, Kind::string, 0, "/Game/Art/Item/BP_Item_Potion_Large.BP_Item_Potion_Large"}, // Asset3D
    {0x0c8, Kind::f32, 8.5f, nullptr},                                                    // AssetZOffset
    {0x0cc, Kind::f32, 1.0f, nullptr},                                                    // Asset3DScale
    {0x0d0, Kind::string, 0, "/Game/Art/UI/Texture/Item/Buff_HP2MP.Buff_HP2MP"},          // Asset2D
    // GainAllowShowPath
    {0x108, Kind::string, 0, "SBShowData'/Game/Art/Show/Item/M_Item_GainAllow_Common_R.M_Item_GainAllow_Common_R'"},
    {0x14c, Kind::name, 0, "Buff_HP2MP"}, // ConsumableAlias
    {0x18a, Kind::u8, 106, nullptr},      // ScanDisplayType
    {0x18c, Kind::name, 0, "Heal"},       // ScanDisplayGroup
    {0x1a4, Kind::u8, 1, nullptr},        // bMaintainNewGamePlus
    {0x1b4, Kind::name, 0, "Consume"},    // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Cast1 (SkillActiveStepTable, Tachy ChainSpin)
    {0x018, Kind::f32, 0.5f, nullptr},                             // Duration
    {0x034, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"UseSkill_Step\"}, {\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_EveSkill\", "
     "\"CalculationValue\":2}]"},
    {0x120, Kind::string, 0, "[{\"Alias\":\"Check_EveSkill\"}]"},          // StartTargetEffect
    {0x130, Kind::u8, 1, nullptr},                                         // StopSelfMove
    {0x138, Kind::names, 0, ""},                                           // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_NPC_TachyNPC/Skill/N_TachyNPC_SwingChain"}, // ShowPath
    {0x1f9, Kind::u8, 1, nullptr},                                         // bLookAtTarget
    {0x2f8, Kind::name, 0, "Eve"},                                         // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Hit1 (SkillActiveStepTable, Tachy ChainSpin)
    {0x014, Kind::u8, 1, nullptr},                                  // Type
    {0x018, Kind::f32, 0.15f, nullptr},                             // Duration
    {0x020, Kind::f32, 0.25f, nullptr},                             // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                             // SkillShieldAttackDamageRate
    {0x030, Kind::u8, 1, nullptr},                                  // AvailableJustAction
    {0x034, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Cast2"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "P_Eve_Tachy_Skill_Chainstab1_1_Hit1"},  // SkillResultAlias
    {0x110, Kind::string, 0, "[{\"Alias\":\"UseSkill_Step\"}, {\"Alias\":\"BlockAction_Step\"}]"}, // StartSelfEffect
    {0x138, Kind::names, 0, "P_Eve_Tachy_Skill_ChainSpin1_Move1"},                                 // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                              // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                              // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                              // bRetargeting
    {0x1b4, Kind::name, 0, "P_Eve_Sword_1000_360_500_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Collision_WeaponAndRightArm\", \"DelayTime\":0}]"},
    {0x238, Kind::u8, 1, nullptr}, // bCritical
    {0x272, Kind::u8, 1, nullptr}, // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "Eve"}, // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Cast2 (SkillActiveStepTable, Tachy ChainSpin)
    {0x018, Kind::f32, 0.1f, nullptr},                                                             // Duration
    {0x034, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Hit2"},                                 // NextStepAlias
    {0x110, Kind::string, 0, "[{\"Alias\":\"UseSkill_Step\"}, {\"Alias\":\"BlockAction_Step\"}]"}, // StartSelfEffect
    {0x2f8, Kind::name, 0, "Eve"},                                                                 // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Hit2 (SkillActiveStepTable, Tachy ChainSpin)
    {0x014, Kind::u8, 1, nullptr},                                  // Type
    {0x018, Kind::f32, 0.1f, nullptr},                              // Duration
    {0x020, Kind::f32, 0.25f, nullptr},                             // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                             // SkillShieldAttackDamageRate
    {0x030, Kind::u8, 1, nullptr},                                  // AvailableJustAction
    {0x034, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Cast3"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "P_Eve_Tachy_Skill_Chainstab1_1_Hit2"},  // SkillResultAlias
    {0x110, Kind::string, 0, "[{\"Alias\":\"UseSkill_Step\"}, {\"Alias\":\"BlockAction_Step\"}]"}, // StartSelfEffect
    {0x1a4, Kind::u8, 1, nullptr},                              // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                              // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                              // bRetargeting
    {0x1b4, Kind::name, 0, "P_Eve_Sword_1000_360_500_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Collision_WeaponAndRightArm\", \"DelayTime\":0}]"},
    {0x238, Kind::u8, 1, nullptr}, // bCritical
    {0x272, Kind::u8, 1, nullptr}, // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "Eve"}, // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Cast3 (SkillActiveStepTable, Tachy ChainSpin)
    {0x018, Kind::f32, 0.15f, nullptr},                                                            // Duration
    {0x034, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Hit3"},                                 // NextStepAlias
    {0x110, Kind::string, 0, "[{\"Alias\":\"UseSkill_Step\"}, {\"Alias\":\"BlockAction_Step\"}]"}, // StartSelfEffect
    {0x2f8, Kind::name, 0, "Eve"},                                                                 // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Hit3 (SkillActiveStepTable, Tachy ChainSpin)
    {0x014, Kind::u8, 1, nullptr},                                  // Type
    {0x018, Kind::f32, 0.1f, nullptr},                              // Duration
    {0x020, Kind::f32, 0.25f, nullptr},                             // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                             // SkillShieldAttackDamageRate
    {0x030, Kind::u8, 1, nullptr},                                  // AvailableJustAction
    {0x034, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Cast4"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "P_Eve_Tachy_Skill_Chainstab1_1_Hit3"},  // SkillResultAlias
    {0x110, Kind::string, 0, "[{\"Alias\":\"UseSkill_Step\"}, {\"Alias\":\"BlockAction_Step\"}]"}, // StartSelfEffect
    {0x1a4, Kind::u8, 1, nullptr},                              // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                              // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                              // bRetargeting
    {0x1b4, Kind::name, 0, "P_Eve_Sword_1000_360_500_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Collision_WeaponAndRightArm\", \"DelayTime\":0}]"},
    {0x238, Kind::u8, 1, nullptr}, // bCritical
    {0x272, Kind::u8, 1, nullptr}, // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "Eve"}, // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Cast4 (SkillActiveStepTable, Tachy ChainSpin)
    {0x018, Kind::f32, 0.8f, nullptr},                                                             // Duration
    {0x034, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Hit4"},                                 // NextStepAlias
    {0x110, Kind::string, 0, "[{\"Alias\":\"UseSkill_Step\"}, {\"Alias\":\"BlockAction_Step\"}]"}, // StartSelfEffect
    {0x138, Kind::names, 0, "P_Eve_Tachy_Skill_ChainSpin1_Move2"},                                 // SelfMoveAliasArray
    {0x2f8, Kind::name, 0, "Eve"},                                                                 // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Hit4 (SkillActiveStepTable, Tachy ChainSpin)
    {0x014, Kind::u8, 1, nullptr},                                    // Type
    {0x018, Kind::f32, 0.1f, nullptr},                                // Duration
    {0x020, Kind::f32, 0.25f, nullptr},                               // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                               // SkillShieldAttackDamageRate
    {0x030, Kind::u8, 1, nullptr},                                    // AvailableJustAction
    {0x034, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Finish1"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "P_Eve_Tachy_Skill_Chainstab1_1_Hit5"},    // SkillResultAlias
    {0x110, Kind::string, 0, "[{\"Alias\":\"UseSkill_Step\"}, {\"Alias\":\"BlockAction_Step\"}]"}, // StartSelfEffect
    {0x1a4, Kind::u8, 1, nullptr},                              // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                              // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                              // bRetargeting
    {0x1b4, Kind::name, 0, "P_Eve_Sword_1000_360_500_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Collision_WeaponAndRightArm\", \"DelayTime\":0}]"},
    {0x238, Kind::u8, 1, nullptr}, // bCritical
    {0x2f8, Kind::name, 0, "Eve"}, // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1_Finish1 (SkillActiveStepTable, Tachy ChainSpin)
    {0x018, Kind::f32, 1.25f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"UseSkill_Step\", \"Time\":0.5}, {\"Alias\":\"BlockAction_Step\", \"Time\":0.5}, "
     "{\"Alias\":\"AddHitDefense_EveSkillDispel\"}]"},
    {0x239, Kind::u8, 1, nullptr}, // PostStep
    {0x240, Kind::u8, 1, nullptr}, // CanCutoff
    {0x241, Kind::u8, 1, nullptr}, // bStopWhenMoving
    {0x2f8, Kind::name, 0, "Eve"}, // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_1 (SkillTable, Tachy ChainSpin)
    {0x058, Kind::names, 0, ""},                                    // AchievementTags
    {0x06c, Kind::i32, 1, nullptr},                                 // StartDelayTick
    {0x070, Kind::i32, 3, nullptr},                                 // HitLevel
    {0x074, Kind::u8, 5, nullptr},                                  // AttributeType
    {0x075, Kind::u8, 1, nullptr},                                  // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                          // AISkillFlag
    {0x0b4, Kind::name, 0, "P_Eve_Sword_0500_180_500_Target"},      // TargetFilterAlias
    {0x0e8, Kind::string, 0, ""},                                   // FirstActiveStepByEffect
    {0x100, Kind::name, 0, "P_Eve_Tachy_Skill_ChainSpin1_1_Cast1"}, // FirstSkillActiveAlias
    {0x124, Kind::f32, 1.0f, nullptr},                              // CoolTime
    {0x140, Kind::f32, 6.0f, nullptr},                              // AttackDamageRate
    {0x144, Kind::f32, 6.0f, nullptr},                              // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                                  // Cancelable
    {0x14d, Kind::u8, 1, nullptr},                                  // ActiveSkillWhileCutoff
    {0x158, Kind::name, 0, "Step2"},                                // TargetDeadType
    {0x160, Kind::string, 0, "Hit/Result_Hit_Env"},                 // WorldObjectHitShow
    {0x170, Kind::u8, 1, nullptr},                                  // RotateInputDirection
    {0x172, Kind::u8, 1, nullptr},                                  // bSwitchBattleMode
    {0x175, Kind::u8, 1, nullptr},                                  // bDelayAutoLockOn
    {0x17c, Kind::name, 0, "None"},                                 // AcquisitionSkillAlias
    {0x189, Kind::u8, 1, nullptr},                                  // bIgnoreAttackSpeedStat
    {0x2f0, Kind::name, 0, "Eve"},                                  // FileSuffix
    // P_Eve_Tachy_Skill_ChainSpin1_Use (EffectTable, Tachy ChainSpin)
    {0x080, Kind::names, 0, "P_Eve_TachyMode"},                 // ConditionActive_CheckEffectAliasArray
    {0x184, Kind::f32, 1.0f, nullptr},                          // CalculationMultipleValue
    {0x198, Kind::u8, 2, nullptr},                              // LifeType
    {0x19c, Kind::f32, 0.1f, nullptr},                          // LifeTime
    {0x1b8, Kind::name, 0, "Self"},                             // ActiveTargetFilterAlias
    {0x2fc, Kind::u8, 69, nullptr},                             // Action1
    {0x300, Kind::string, 0, "P_Eve_Tachy_Skill_ChainSpin1_1"}, // ActionValue1
    {0x570, Kind::name, 0, "YE"},                               // FileSuffix
    // M_LionC_PhaseRoar
    {0x184, Kind::f32, 1.0f, nullptr},                   // CalculationMultipleValue
    {0x198, Kind::u8, 2, nullptr},                       // LifeType
    {0x19c, Kind::f32, 0.1f, nullptr},                   // LifeTime
    {0x1b8, Kind::name, 0, "Self"},                      // ActiveTargetFilterAlias
    {0x2fc, Kind::u8, 69, nullptr},                      // Action1
    {0x300, Kind::string, 0, "M_LionC_RoarPhaseChange"}, // ActionValue1
    {0x570, Kind::name, 0, "None"},                      // FileSuffix
    // M_LionC_Result_Light
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactSlash_Light\"}]"},
    {0x038, Kind::string, 0, "[{\"Alias\":\"HitStun\", \"Time\":0.5}]"}, // HitLevelResultTargetCommonEffect
    {0x058, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack"},        // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_050_100"},                          // HitLevelResultTargetCommonMoveAlias
    {0x0b8, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetDownShowPath
    {0x118, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetGroggyShowPath
    {0x178, Kind::string, 0, "Hit/Result_Hit_Airborne"},                 // ResultTargetAirborneShowPath
    // HitLevelResultTargetAirEffect
    {0x1b8, Kind::string, 0, "[{\"Alias\":\"HitAirBackward_Eve\"}, {\"Alias\":\"HitAirForward_Eve\"}]"},
    {0x238, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetSwimmingShowPath
    {0x250, Kind::name, 0, "Hit_Back_0"},                                // HitLevelResultTargetSwimmingMoveAlias
    // ResultTargetEventMovingEffect
    {0x2c8, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactSlash_Light\"}]"},
    {0x2d8, Kind::string, 0, "[{\"Alias\":\"HitStun\", \"Time\":0.5}]"}, // HitLevelResultTargetEventMovingEffect
    {0x2f8, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetEventMovingShowPath
    {0x318, Kind::name, 0, "None"},                                      // FileSuffix
    // M_LionC_Result_Strong
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactSlash_Strong\"}]"},
    {0x038, Kind::string, 0, "[{\"Alias\":\"HitStun\", \"Time\":0.8}]"}, // HitLevelResultTargetCommonEffect
    {0x058, Kind::string, 0, "Hit/Result_Hit_Stand_StrongAttack"},       // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_080_300"},                          // HitLevelResultTargetCommonMoveAlias
    {0x0b8, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetDownShowPath
    {0x118, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetGroggyShowPath
    {0x178, Kind::string, 0, "Hit/Result_Hit_Airborne"},                 // ResultTargetAirborneShowPath
    // HitLevelResultTargetAirEffect
    {0x1b8, Kind::string, 0, "[{\"Alias\":\"HitAirBackward_Eve\"}, {\"Alias\":\"HitAirForward_Eve\"}]"},
    {0x238, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetSwimmingShowPath
    {0x250, Kind::name, 0, "Hit_Back_0"},                                // HitLevelResultTargetSwimmingMoveAlias
    // ResultTargetEventMovingEffect
    {0x2c8, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactSlash_Strong\"}]"},
    {0x2d8, Kind::string, 0, "[{\"Alias\":\"HitStun\", \"Time\":0.8}]"},  // HitLevelResultTargetEventMovingEffect
    {0x2f8, Kind::string, 0, "Hit/Result_Hit_Stand_StrongAttack_NoAnim"}, // ResultTargetEventMovingShowPath
    {0x318, Kind::name, 0, "None"},                                       // FileSuffix
    // M_LionC_Result_KnockDown
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactBlunt_Strong\"}]"},
    // HitLevelResultTargetCommonEffect
    {0x038, Kind::string, 0,
     "[{\"Alias\":\"HitStun\", \"Time\":1.5}, {\"Alias\":\"KnockDownForward_Eve\"}, "
     "{\"Alias\":\"KnockDownBackward_Eve\"}]"},
    {0x058, Kind::string, 0, "Hit/Result_Hit_Stand_StrongAttack"},       // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_080_300"},                          // HitLevelResultTargetCommonMoveAlias
    {0x0b8, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetDownShowPath
    {0x118, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetGroggyShowPath
    {0x178, Kind::string, 0, "Hit/Result_Hit_Airborne"},                 // ResultTargetAirborneShowPath
    // HitLevelResultTargetAirEffect
    {0x1b8, Kind::string, 0, "[{\"Alias\":\"HitAirBackward_Eve\"}, {\"Alias\":\"HitAirForward_Eve\"}]"},
    {0x238, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetSwimmingShowPath
    {0x250, Kind::name, 0, "Hit_Back_0"},                                // HitLevelResultTargetSwimmingMoveAlias
    // ResultTargetEventMovingEffect
    {0x2c8, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactBlunt_Strong\"}]"},
    // HitLevelResultTargetEventMovingEffect
    {0x2d8, Kind::string, 0,
     "[{\"Alias\":\"HitStun\", \"Time\":1.5}, {\"Alias\":\"KnockDownForward_Eve\"}, "
     "{\"Alias\":\"KnockDownBackward_Eve\"}]"},
    {0x2f8, Kind::string, 0, "Hit/Result_Hit_Stand_StrongAttack_NoAnim"}, // ResultTargetEventMovingShowPath
    {0x318, Kind::name, 0, "None"},                                       // FileSuffix
    // M_LionC_Result_Guard
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0, "[{\"Alias\":\"SkillDamageWhenGuard_Melee\"}, {\"Alias\":\"BlockAction\", \"Time\":0.3}]"},
    {0x058, Kind::string, 0, "Result/Result_Guard_Back"}, // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_040_100"},           // HitLevelResultTargetCommonMoveAlias
    {0x318, Kind::name, 0, "None"},                       // FileSuffix
    // M_LionC_Result_Parry
    {0x058, Kind::string, 0, "Result/Result_Parry_Back"}, // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_020_150"},           // HitLevelResultTargetCommonMoveAlias
    {0x318, Kind::name, 0, "None"},                       // FileSuffix
    // M_LionC_HitArea
    {0x014, Kind::u8, 5, nullptr},        // TargetType
    {0x015, Kind::u8, 1, nullptr},        // bMultipleTargets
    {0x024, Kind::f32, 8000.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},        // SortType
    {0x03c, Kind::u8, 5, nullptr},        // TargetCheckShape
    {0x0b0, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_Roar_HitArea
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 700.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x030, Kind::f32, 200.0f, nullptr}, // ShapeForwardDistance
    {0x03c, Kind::u8, 7, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 300.0f, nullptr}, // TargetCheckValue1
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackLeft_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 360.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackRight_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 360.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChaseLeft_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x020, Kind::f32, 440.0f, nullptr}, // NearDistance
    {0x024, Kind::f32, 490.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChaseRight_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x020, Kind::f32, 230.0f, nullptr}, // NearDistance
    {0x024, Kind::f32, 480.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x044, Kind::f32, -40.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_TurnAttackLeft_Target
    {0x014, Kind::u8, 5, nullptr},        // TargetType
    {0x015, Kind::u8, 1, nullptr},        // bMultipleTargets
    {0x024, Kind::f32, 320.0f, nullptr},  // FarDistance
    {0x028, Kind::u8, 1, nullptr},        // SortType
    {0x03c, Kind::u8, 4, nullptr},        // TargetCheckShape
    {0x040, Kind::f32, 140.0f, nullptr},  // TargetCheckValue1
    {0x044, Kind::f32, -110.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 300.0f, nullptr},  // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_TurnAttackRight_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 320.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 140.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, 110.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RunAttackLeft_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x020, Kind::f32, 130.0f, nullptr}, // NearDistance
    {0x024, Kind::f32, 550.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x044, Kind::f32, -80.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RunAttackRight_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x020, Kind::f32, 140.0f, nullptr}, // NearDistance
    {0x024, Kind::f32, 520.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x044, Kind::f32, 80.0f, nullptr},  // TargetCheckValue2
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_JumpAttackLow_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x020, Kind::f32, 180.0f, nullptr}, // NearDistance
    {0x024, Kind::f32, 490.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_JumpAttackLow_HitArea
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 350.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x030, Kind::f32, 150.0f, nullptr}, // ShapeForwardDistance
    {0x03c, Kind::u8, 7, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 300.0f, nullptr}, // TargetCheckValue1
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_JumpAttackHigh_Target
    {0x014, Kind::u8, 5, nullptr},        // TargetType
    {0x015, Kind::u8, 1, nullptr},        // bMultipleTargets
    {0x020, Kind::f32, 830.0f, nullptr},  // NearDistance
    {0x024, Kind::f32, 1250.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},        // SortType
    {0x03c, Kind::u8, 4, nullptr},        // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},   // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr},  // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_JumpAttackHigh_HitArea
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 350.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x030, Kind::f32, 800.0f, nullptr}, // ShapeForwardDistance
    {0x03c, Kind::u8, 7, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 300.0f, nullptr}, // TargetCheckValue1
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_BackJumpToAttack_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 110.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 120.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, 180.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_AttackToBackJump_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 320.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_Roar_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 700.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 120.0f, nullptr}, // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_SideStepLeft_Target
    {0x014, Kind::u8, 5, nullptr},        // TargetType
    {0x015, Kind::u8, 1, nullptr},        // bMultipleTargets
    {0x024, Kind::f32, 1420.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},        // SortType
    {0x03c, Kind::u8, 4, nullptr},        // TargetCheckShape
    {0x040, Kind::f32, 100.0f, nullptr},  // TargetCheckValue1
    {0x044, Kind::f32, 100.0f, nullptr},  // TargetCheckValue2
    {0x048, Kind::f32, 300.0f, nullptr},  // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_SideStepRight_Target
    {0x014, Kind::u8, 5, nullptr},        // TargetType
    {0x015, Kind::u8, 1, nullptr},        // bMultipleTargets
    {0x024, Kind::f32, 1590.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},        // SortType
    {0x03c, Kind::u8, 4, nullptr},        // TargetCheckShape
    {0x040, Kind::f32, 100.0f, nullptr},  // TargetCheckValue1
    {0x044, Kind::f32, -100.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 300.0f, nullptr},  // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_ClawAttackChain_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 350.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain2_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 340.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_MoveAttackChain_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 330.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RushAttack_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x020, Kind::f32, 310.0f, nullptr}, // NearDistance
    {0x024, Kind::f32, 730.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 440.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_HitArea
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 450.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 120.0f, nullptr}, // TargetCheckValue1
    {0x048, Kind::f32, 300.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackLeft_Turn
    {0x014, Kind::i32, 100, nullptr},  // Priority
    {0x03a, Kind::u8, 0, nullptr},     // MoveType
    {0x060, Kind::u8, 2, nullptr},     // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.8f, nullptr}, // Time
    {0x094, Kind::f32, 0.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr}, // RightValue
    {0x0b8, Kind::f32, 0.8f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},     // RotationType
    {0x0cc, Kind::u8, 1, nullptr},     // bIndependentRotation
    {0x0f2, Kind::u8, 1, nullptr},     // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},     // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},     // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},     // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},    // FileSuffix
    // M_LionC_ClawAttackRight_Turn
    {0x014, Kind::i32, 100, nullptr},  // Priority
    {0x03a, Kind::u8, 0, nullptr},     // MoveType
    {0x060, Kind::u8, 2, nullptr},     // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.8f, nullptr}, // Time
    {0x094, Kind::f32, 0.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr}, // RightValue
    {0x0b8, Kind::f32, 0.8f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},     // RotationType
    {0x0cc, Kind::u8, 1, nullptr},     // bIndependentRotation
    {0x0f2, Kind::u8, 1, nullptr},     // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},     // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},     // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},     // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},    // FileSuffix
    // M_LionC_ClawAttackChaseLeft_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x080, Kind::f32, 0.267f, nullptr}, // MoveStartTime
    {0x084, Kind::f32, 0.7f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.7f, nullptr},   // Time
    {0x094, Kind::f32, 53.9f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 410.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.7f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChaseLeft_Move2
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.267f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.267f, nullptr}, // Time
    {0x094, Kind::f32, 272.6f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 410.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.267f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChaseLeft_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.334f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.334f, nullptr}, // Time
    {0x094, Kind::f32, 2.0f, nullptr},   // ForwardValue
    {0x098, Kind::f32, 81.0f, nullptr},  // RightValue
    {0x0b8, Kind::f32, 0.334f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChaseRight_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.4f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 0.3f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.3f, nullptr},   // Time
    {0x094, Kind::f32, 66.1f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 200.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChaseRight_Move2
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.267f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.267f, nullptr}, // Time
    {0x094, Kind::f32, 275.3f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 200.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChaseRight_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.3f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.3f, nullptr},   // Time
    {0x094, Kind::f32, 195.3f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 200.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_TurnAttackLeft_Turn
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 0, nullptr},       // MoveType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.1f, nullptr},   // Time
    {0x094, Kind::f32, 0.0f, nullptr},   // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.1f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0cc, Kind::u8, 1, nullptr},       // bIndependentRotation
    {0x0dc, Kind::f32, 360.0f, nullptr}, // RotationLeftLimitAngle
    {0x0e0, Kind::f32, 360.0f, nullptr}, // RotationRightLimitAngle
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_TurnAttackRight_Turn
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 0, nullptr},       // MoveType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.1f, nullptr},   // Time
    {0x094, Kind::f32, 0.0f, nullptr},   // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.1f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0cc, Kind::u8, 1, nullptr},       // bIndependentRotation
    {0x0dc, Kind::f32, 360.0f, nullptr}, // RotationLeftLimitAngle
    {0x0e0, Kind::f32, 360.0f, nullptr}, // RotationRightLimitAngle
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RunAttackLeft_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.6f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 0.233f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.233f, nullptr}, // Time
    {0x094, Kind::f32, 143.2f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 100.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RunAttackLeft_Move2
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.037f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.4f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.4f, nullptr},   // Time
    {0x094, Kind::f32, 602.5f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 100.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RunAttackLeft_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.05f, nullptr},  // StartDelayTime
    {0x084, Kind::f32, 0.2f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.2f, nullptr},   // Time
    {0x094, Kind::f32, 265.3f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 100.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RunAttackRight_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.7f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 0.133f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.133f, nullptr}, // Time
    {0x094, Kind::f32, 147.3f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 110.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RunAttackRight_Move2
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.037f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.4f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.4f, nullptr},   // Time
    {0x094, Kind::f32, 544.9f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 110.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RunAttackRight_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.05f, nullptr},  // StartDelayTime
    {0x084, Kind::f32, 0.333f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.333f, nullptr}, // Time
    {0x094, Kind::f32, 252.3f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 110.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 0, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_JumpAttackLow_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x080, Kind::f32, 0.667f, nullptr}, // MoveStartTime
    {0x084, Kind::f32, 1.1f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 1.13f, nullptr},  // Time
    {0x094, Kind::f32, 615.5f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 150.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 1.13f, nullptr},  // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_JumpAttackHigh_Turn
    {0x014, Kind::i32, 100, nullptr},   // Priority
    {0x03a, Kind::u8, 0, nullptr},      // MoveType
    {0x060, Kind::u8, 2, nullptr},      // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},  // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr},  // MoveEndTime
    {0x088, Kind::f32, 1.96f, nullptr}, // Time
    {0x094, Kind::f32, 0.0f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},  // RightValue
    {0x0b8, Kind::f32, 1.96f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},      // RotationType
    {0x0cc, Kind::u8, 1, nullptr},      // bIndependentRotation
    {0x0f2, Kind::u8, 1, nullptr},      // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},      // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},      // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},      // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},     // FileSuffix
    // M_LionC_JumpAttackHigh_Move2
    {0x014, Kind::i32, 100, nullptr},     // Priority
    {0x03a, Kind::u8, 6, nullptr},        // MoveType
    {0x03b, Kind::u8, 3, nullptr},        // PositionType
    {0x060, Kind::u8, 2, nullptr},        // PositionDirectionAxis
    {0x070, Kind::f32, 0.073f, nullptr},  // StartDelayTime
    {0x084, Kind::f32, 0.567f, nullptr},  // MoveEndTime
    {0x088, Kind::f32, 0.567f, nullptr},  // Time
    {0x094, Kind::f32, 1154.3f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},    // RightValue
    {0x0b0, Kind::f32, 800.0f, nullptr},  // LimitApproachDistance
    {0x0b8, Kind::f32, 0.567f, nullptr},  // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},        // RotationType
    {0x0f2, Kind::u8, 1, nullptr},        // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},        // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},        // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},        // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_JumpAttackHigh_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.3f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.3f, nullptr},   // Time
    {0x094, Kind::f32, 899.2f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 800.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.3f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_BackJumpToAttack_Turn
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 0, nullptr},       // MoveType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.1f, nullptr},   // Time
    {0x094, Kind::f32, 0.0f, nullptr},   // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.1f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0cc, Kind::u8, 1, nullptr},       // bIndependentRotation
    {0x0dc, Kind::f32, 360.0f, nullptr}, // RotationLeftLimitAngle
    {0x0e0, Kind::f32, 360.0f, nullptr}, // RotationRightLimitAngle
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_AttackToBackJump_Turn
    {0x014, Kind::i32, 100, nullptr},   // Priority
    {0x03a, Kind::u8, 0, nullptr},      // MoveType
    {0x060, Kind::u8, 2, nullptr},      // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},  // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr},  // MoveEndTime
    {0x088, Kind::f32, 1.15f, nullptr}, // Time
    {0x094, Kind::f32, 0.0f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},  // RightValue
    {0x0b8, Kind::f32, 1.15f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},      // RotationType
    {0x0cc, Kind::u8, 1, nullptr},      // bIndependentRotation
    {0x0f2, Kind::u8, 1, nullptr},      // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},      // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},      // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},      // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},     // FileSuffix
    // M_LionC_AttackToBackJump_Move3
    {0x014, Kind::i32, 100, nullptr},      // Priority
    {0x03a, Kind::u8, 6, nullptr},         // MoveType
    {0x070, Kind::f32, 0.383f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 1.234f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 1.234f, nullptr},   // Time
    {0x094, Kind::f32, -1034.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 59.0f, nullptr},    // RightValue
    {0x0b8, Kind::f32, 1.234f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},         // RotationType
    {0x0f2, Kind::u8, 1, nullptr},         // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},         // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},         // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},         // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},        // FileSuffix
    // M_LionC_Roar_Turn
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 0, nullptr},       // MoveType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 1.332f, nullptr}, // Time
    {0x094, Kind::f32, 0.0f, nullptr},   // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 1.332f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0cc, Kind::u8, 1, nullptr},       // bIndependentRotation
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_Roar_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x070, Kind::f32, 0.433f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.967f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.967f, nullptr}, // Time
    {0x094, Kind::f32, 175.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 5.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.967f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_SideStepLeft_Move1
    {0x014, Kind::i32, 100, nullptr},      // Priority
    {0x03a, Kind::u8, 6, nullptr},         // MoveType
    {0x070, Kind::f32, 0.0f, nullptr},     // StartDelayTime
    {0x080, Kind::f32, 0.067f, nullptr},   // MoveStartTime
    {0x084, Kind::f32, 1.3f, nullptr},     // MoveEndTime
    {0x088, Kind::f32, 2.0f, nullptr},     // Time
    {0x094, Kind::f32, 0.0f, nullptr},     // ForwardValue
    {0x098, Kind::f32, -1419.0f, nullptr}, // RightValue
    {0x0b8, Kind::f32, 2.0f, nullptr},     // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},         // RotationType
    {0x0f2, Kind::u8, 1, nullptr},         // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},         // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},         // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},         // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},        // FileSuffix
    // M_LionC_SideStepRight_Move1
    {0x014, Kind::i32, 100, nullptr},     // Priority
    {0x03a, Kind::u8, 6, nullptr},        // MoveType
    {0x070, Kind::f32, 0.0f, nullptr},    // StartDelayTime
    {0x080, Kind::f32, 0.1f, nullptr},    // MoveStartTime
    {0x084, Kind::f32, 1.267f, nullptr},  // MoveEndTime
    {0x088, Kind::f32, 2.0f, nullptr},    // Time
    {0x094, Kind::f32, 0.0f, nullptr},    // ForwardValue
    {0x098, Kind::f32, 1589.0f, nullptr}, // RightValue
    {0x0b8, Kind::f32, 2.0f, nullptr},    // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},        // RotationType
    {0x0f2, Kind::u8, 1, nullptr},        // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},        // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},        // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},        // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_ClawAttackChain_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x080, Kind::f32, 0.333f, nullptr}, // MoveStartTime
    {0x084, Kind::f32, 0.767f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.767f, nullptr}, // Time
    {0x094, Kind::f32, 39.8f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.767f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain_Move2
    {0x014, Kind::i32, 100, nullptr},   // Priority
    {0x03a, Kind::u8, 6, nullptr},      // MoveType
    {0x03b, Kind::u8, 3, nullptr},      // PositionType
    {0x060, Kind::u8, 2, nullptr},      // PositionDirectionAxis
    {0x070, Kind::f32, 0.05f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.2f, nullptr},  // MoveEndTime
    {0x088, Kind::f32, 0.2f, nullptr},  // Time
    {0x094, Kind::f32, 94.8f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},  // RightValue
    {0x0b8, Kind::f32, 0.2f, nullptr},  // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},      // RotationType
    {0x0f2, Kind::u8, 1, nullptr},      // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},      // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},      // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},      // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},     // FileSuffix
    // M_LionC_ClawAttackChain_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.067f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.067f, nullptr}, // Time
    {0x094, Kind::f32, 42.6f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 310.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.067f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain_Move4
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.167f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.167f, nullptr}, // Time
    {0x094, Kind::f32, 32.3f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 310.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.167f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain_Move5
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.134f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.134f, nullptr}, // Time
    {0x094, Kind::f32, 50.6f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 440.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.134f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain_Move6
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.05f, nullptr},  // StartDelayTime
    {0x084, Kind::f32, 0.367f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.367f, nullptr}, // Time
    {0x094, Kind::f32, 270.4f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 440.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.367f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain_Move7
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.05f, nullptr},  // StartDelayTime
    {0x084, Kind::f32, 0.6f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.6f, nullptr},   // Time
    {0x094, Kind::f32, 599.6f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 440.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.6f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain2_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x080, Kind::f32, 0.333f, nullptr}, // MoveStartTime
    {0x084, Kind::f32, 0.767f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.767f, nullptr}, // Time
    {0x094, Kind::f32, 38.0f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.767f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain2_Move2
    {0x014, Kind::i32, 100, nullptr},   // Priority
    {0x03a, Kind::u8, 6, nullptr},      // MoveType
    {0x03b, Kind::u8, 3, nullptr},      // PositionType
    {0x060, Kind::u8, 2, nullptr},      // PositionDirectionAxis
    {0x070, Kind::f32, 0.05f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.2f, nullptr},  // MoveEndTime
    {0x088, Kind::f32, 0.2f, nullptr},  // Time
    {0x094, Kind::f32, 66.2f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},  // RightValue
    {0x0b8, Kind::f32, 0.2f, nullptr},  // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},      // RotationType
    {0x0f2, Kind::u8, 1, nullptr},      // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},      // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},      // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},      // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},     // FileSuffix
    // M_LionC_ClawAttackChain2_Move4
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.167f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.167f, nullptr}, // Time
    {0x094, Kind::f32, 54.5f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 370.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.167f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain2_Move5
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.134f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.134f, nullptr}, // Time
    {0x094, Kind::f32, 31.4f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 550.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.134f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain2_Move6
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.083f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.334f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.334f, nullptr}, // Time
    {0x094, Kind::f32, 224.8f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 550.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.334f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain2_Move7
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.083f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 1.0f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 1.0f, nullptr},   // Time
    {0x094, Kind::f32, 844.9f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 1.0f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain2_Move8
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.067f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.3f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.3f, nullptr},   // Time
    {0x094, Kind::f32, 246.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.3f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackChain2_Move9
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x070, Kind::f32, 0.083f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 1.067f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 1.067f, nullptr}, // Time
    {0x094, Kind::f32, 328.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 669.0f, nullptr}, // RightValue
    {0x0b8, Kind::f32, 1.067f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_MoveAttackChain_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x080, Kind::f32, 0.667f, nullptr}, // MoveStartTime
    {0x084, Kind::f32, 0.9f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.9f, nullptr},   // Time
    {0x094, Kind::f32, -59.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, -82.0f, nullptr}, // RightValue
    {0x0b8, Kind::f32, 0.9f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_MoveAttackChain_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.083f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.534f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.534f, nullptr}, // Time
    {0x094, Kind::f32, 561.7f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 200.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.534f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_MoveAttackChain_Move4
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.167f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.167f, nullptr}, // Time
    {0x094, Kind::f32, 169.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 200.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.167f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_MoveAttackChain_Move5
    {0x014, Kind::i32, 100, nullptr},     // Priority
    {0x03a, Kind::u8, 6, nullptr},        // MoveType
    {0x03b, Kind::u8, 3, nullptr},        // PositionType
    {0x060, Kind::u8, 2, nullptr},        // PositionDirectionAxis
    {0x070, Kind::f32, 0.1f, nullptr},    // StartDelayTime
    {0x084, Kind::f32, 0.733f, nullptr},  // MoveEndTime
    {0x088, Kind::f32, 0.733f, nullptr},  // Time
    {0x094, Kind::f32, 1244.2f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},    // RightValue
    {0x0b0, Kind::f32, 340.0f, nullptr},  // LimitApproachDistance
    {0x0b8, Kind::f32, 0.733f, nullptr},  // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},        // RotationType
    {0x0f2, Kind::u8, 1, nullptr},        // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},        // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},        // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},        // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_MoveAttackChain_Move6
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.033f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.067f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.067f, nullptr}, // Time
    {0x094, Kind::f32, 45.1f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 340.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.067f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RushAttack_Move1
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x080, Kind::f32, 0.1f, nullptr},   // MoveStartTime
    {0x084, Kind::f32, 0.2f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.2f, nullptr},   // Time
    {0x094, Kind::f32, 110.1f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 280.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.2f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RushAttack_Move2
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.053f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.134f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.134f, nullptr}, // Time
    {0x094, Kind::f32, 320.7f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 280.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.134f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RushAttack_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.045f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.233f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.233f, nullptr}, // Time
    {0x094, Kind::f32, 485.3f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 280.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.233f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Move1
    {0x014, Kind::i32, 100, nullptr},     // Priority
    {0x03a, Kind::u8, 6, nullptr},        // MoveType
    {0x070, Kind::f32, 0.0f, nullptr},    // StartDelayTime
    {0x080, Kind::f32, 0.8f, nullptr},    // MoveStartTime
    {0x084, Kind::f32, 1.533f, nullptr},  // MoveEndTime
    {0x088, Kind::f32, 1.541f, nullptr},  // Time
    {0x094, Kind::f32, -48.0f, nullptr},  // ForwardValue
    {0x098, Kind::f32, -116.0f, nullptr}, // RightValue
    {0x0b8, Kind::f32, 1.541f, nullptr},  // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},        // RotationType
    {0x0f2, Kind::u8, 1, nullptr},        // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},        // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},        // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},        // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},       // FileSuffix
    // M_LionC_DashAttackChain_Move2
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.092f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.4f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.4f, nullptr},   // Time
    {0x094, Kind::f32, 326.5f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.4f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.044f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.166f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.166f, nullptr}, // Time
    {0x094, Kind::f32, 380.6f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.166f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Move4
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.041f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.566f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.566f, nullptr}, // Time
    {0x094, Kind::f32, 315.6f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.566f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Move5
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.051f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.233f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.233f, nullptr}, // Time
    {0x094, Kind::f32, 118.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 260.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.233f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Move6
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.075f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.3f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.3f, nullptr},   // Time
    {0x094, Kind::f32, 157.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 260.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.3f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Move7
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.053f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.167f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.167f, nullptr}, // Time
    {0x094, Kind::f32, 239.4f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 200.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.167f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Move8
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.047f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.6f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 0.6f, nullptr},   // Time
    {0x094, Kind::f32, 801.5f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 200.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.6f, nullptr},   // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_DashAttackChain_Move9
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x03b, Kind::u8, 3, nullptr},       // PositionType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.061f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.066f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.066f, nullptr}, // Time
    {0x094, Kind::f32, 68.5f, nullptr},  // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b0, Kind::f32, 200.0f, nullptr}, // LimitApproachDistance
    {0x0b8, Kind::f32, 0.066f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RoarPhaseChange_Turn
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 0, nullptr},       // MoveType
    {0x060, Kind::u8, 2, nullptr},       // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr},   // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr},   // MoveEndTime
    {0x088, Kind::f32, 1.332f, nullptr}, // Time
    {0x094, Kind::f32, 0.0f, nullptr},   // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 1.332f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0cc, Kind::u8, 1, nullptr},       // bIndependentRotation
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_RoarPhaseChange_Move3
    {0x014, Kind::i32, 100, nullptr},    // Priority
    {0x03a, Kind::u8, 6, nullptr},       // MoveType
    {0x070, Kind::f32, 0.433f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.967f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.967f, nullptr}, // Time
    {0x094, Kind::f32, 175.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 5.0f, nullptr},   // RightValue
    {0x0b8, Kind::f32, 0.967f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},       // RotationType
    {0x0f2, Kind::u8, 1, nullptr},       // bStopWhenClif
    {0x0f5, Kind::u8, 1, nullptr},       // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 1, nullptr},       // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},       // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},      // FileSuffix
    // M_LionC_ClawAttackLeft_Cast1
    {0x018, Kind::f32, 0.8f, nullptr},                     // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackLeft_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                            // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_ClawAttackLeft_Turn"},                   // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackLeft_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                           // FileSuffix
    // M_LionC_ClawAttackLeft_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.2f, nullptr},                          // Duration
    {0x01c, Kind::u8, 1, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackLeft_Finish1"},   // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},             // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},               // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackLeft_Finish1
    {0x018, Kind::f32, 2.067f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackLeft
    {0x070, Kind::i32, 1, nullptr},                          // HitLevel
    {0x074, Kind::u8, 5, nullptr},                           // AttributeType
    {0x075, Kind::u8, 1, nullptr},                           // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                   // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                           // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_LionC_ClawAttackLeft_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_ClawAttackLeft_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 3.0f, nullptr},                       // CoolTime
    {0x140, Kind::f32, 1.0f, nullptr},                       // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                       // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                           // Cancelable
    {0x172, Kind::u8, 1, nullptr},                           // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                          // FileSuffix
    // M_LionC_ClawAttackRight_Cast1
    {0x018, Kind::f32, 0.8f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackRight_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                             // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_ClawAttackRight_Turn"},                   // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackRight_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                            // FileSuffix
    // M_LionC_ClawAttackRight_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.2f, nullptr},                          // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackRight_Finish1"},  // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},             // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},               // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackRight_Finish1
    {0x018, Kind::f32, 2.067f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackRight
    {0x070, Kind::i32, 1, nullptr},                           // HitLevel
    {0x074, Kind::u8, 5, nullptr},                            // AttributeType
    {0x075, Kind::u8, 1, nullptr},                            // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                    // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                            // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_LionC_ClawAttackRight_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_ClawAttackRight_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 3.0f, nullptr},                        // CoolTime
    {0x140, Kind::f32, 1.0f, nullptr},                        // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                        // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                            // Cancelable
    {0x172, Kind::u8, 1, nullptr},                            // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_ClawAttackChaseLeft_Cast1
    {0x018, Kind::f32, 0.7f, nullptr},                          // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChaseLeft_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                                 // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChaseLeft_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackChaseLeft_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                                 // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                                // FileSuffix
    // M_LionC_ClawAttackChaseLeft_Hit1
    {0x014, Kind::u8, 1, nullptr},                                 // Type
    {0x018, Kind::f32, 0.3f, nullptr},                             // Duration
    {0x01c, Kind::u8, 1, nullptr},                                 // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                             // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                             // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                                 // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                                 // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                                 // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                                 // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChaseLeft_Finish1"}, // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"},    // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},                // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},                // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},                // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},                // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChaseLeft_Move2"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                                // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                                // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                                // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                    // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChaseLeft_Finish1
    {0x018, Kind::f32, 2.067f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChaseLeft_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                                // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                               // FileSuffix
    // M_LionC_ClawAttackChaseLeft
    {0x070, Kind::i32, 1, nullptr},                               // HitLevel
    {0x074, Kind::u8, 5, nullptr},                                // AttributeType
    {0x075, Kind::u8, 1, nullptr},                                // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                        // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                                // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_700"},            // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_ClawAttackChaseLeft_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_ClawAttackChaseLeft_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 8.0f, nullptr},                            // CoolTime
    {0x140, Kind::f32, 1.2f, nullptr},                            // AttackDamageRate
    {0x144, Kind::f32, 1.2f, nullptr},                            // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                                // Cancelable
    {0x172, Kind::u8, 1, nullptr},                                // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                               // FileSuffix
    // M_LionC_ClawAttackChaseRight_Cast1
    {0x018, Kind::f32, 0.7f, nullptr},                           // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChaseRight_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                                  // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChaseRight_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackChaseRight_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                                  // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                                 // FileSuffix
    // M_LionC_ClawAttackChaseRight_Hit1
    {0x014, Kind::u8, 1, nullptr},                                  // Type
    {0x018, Kind::f32, 0.3f, nullptr},                              // Duration
    {0x01c, Kind::u8, 2, nullptr},                                  // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                              // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                              // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                                  // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                                  // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                                  // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                                  // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChaseRight_Finish1"}, // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"},     // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},                 // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},                 // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},                 // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},                 // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChaseRight_Move2"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                                 // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                                 // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                                 // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                     // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChaseRight_Finish1
    {0x018, Kind::f32, 2.067f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChaseRight_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                                 // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                // FileSuffix
    // M_LionC_ClawAttackChaseRight
    {0x070, Kind::i32, 1, nullptr},                                            // HitLevel
    {0x074, Kind::u8, 5, nullptr},                                             // AttributeType
    {0x075, Kind::u8, 1, nullptr},                                             // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                                     // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                                             // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_700|Valid_Move_SideL_400_50"}, // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_ClawAttackChaseRight_Target"},             // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_ClawAttackChaseRight_Cast1"},              // FirstSkillActiveAlias
    {0x124, Kind::f32, 8.0f, nullptr},                                         // CoolTime
    {0x140, Kind::f32, 1.2f, nullptr},                                         // AttackDamageRate
    {0x144, Kind::f32, 1.2f, nullptr},                                         // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                                             // Cancelable
    {0x172, Kind::u8, 1, nullptr},                                             // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                                            // FileSuffix
    // M_LionC_TurnAttackLeft_Cast1
    {0x018, Kind::f32, 0.58f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_LionC_TurnAttackLeft_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                            // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_TurnAttackLeft_Turn"},                   // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_TurnAttackLeft_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                           // FileSuffix
    // M_LionC_TurnAttackLeft_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.32f, nullptr},                         // Duration
    {0x01c, Kind::u8, 1, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_TurnAttackLeft_Finish1"},   // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},             // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},               // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_TurnAttackLeft_Finish1
    {0x018, Kind::f32, 1.6f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_TurnAttackLeft
    {0x070, Kind::i32, 1, nullptr},                          // HitLevel
    {0x074, Kind::u8, 5, nullptr},                           // AttributeType
    {0x075, Kind::u8, 1, nullptr},                           // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                   // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                           // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_LionC_TurnAttackLeft_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_TurnAttackLeft_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 10.0f, nullptr},                      // CoolTime
    {0x140, Kind::f32, 1.0f, nullptr},                       // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                       // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                           // Cancelable
    {0x172, Kind::u8, 1, nullptr},                           // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                          // FileSuffix
    // M_LionC_TurnAttackRight_Cast1
    {0x018, Kind::f32, 0.58f, nullptr},                     // Duration
    {0x034, Kind::name, 0, "M_LionC_TurnAttackRight_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                             // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_TurnAttackRight_Turn"},                   // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_TurnAttackRight_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                            // FileSuffix
    // M_LionC_TurnAttackRight_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.32f, nullptr},                         // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_TurnAttackRight_Finish1"},  // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},             // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},               // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_TurnAttackRight_Finish1
    {0x018, Kind::f32, 1.6f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_TurnAttackRight
    {0x070, Kind::i32, 1, nullptr},                           // HitLevel
    {0x074, Kind::u8, 5, nullptr},                            // AttributeType
    {0x075, Kind::u8, 1, nullptr},                            // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                    // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                            // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_LionC_TurnAttackRight_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_TurnAttackRight_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 10.0f, nullptr},                       // CoolTime
    {0x140, Kind::f32, 1.0f, nullptr},                        // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                        // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                            // Cancelable
    {0x172, Kind::u8, 1, nullptr},                            // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_RunAttackLeft_Cast1
    {0x018, Kind::f32, 0.83f, nullptr},                   // Duration
    {0x034, Kind::name, 0, "M_LionC_RunAttackLeft_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                           // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_RunAttackLeft_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_RunAttackLeft_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                           // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                          // FileSuffix
    // M_LionC_RunAttackLeft_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.42f, nullptr},                         // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_RunAttackLeft_Finish1"},    // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_RunAttackLeft_Move2"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                          // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                          // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                          // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},              // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_RunAttackLeft_Finish1
    {0x018, Kind::f32, 1.68f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_RunAttackLeft_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                          // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                         // FileSuffix
    // M_LionC_RunAttackLeft
    {0x070, Kind::i32, 1, nullptr},                         // HitLevel
    {0x074, Kind::u8, 5, nullptr},                          // AttributeType
    {0x075, Kind::u8, 1, nullptr},                          // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                  // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                          // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_SideL_1100"},       // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_RunAttackLeft_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_RunAttackLeft_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 10.0f, nullptr},                     // CoolTime
    {0x140, Kind::f32, 1.3f, nullptr},                      // AttackDamageRate
    {0x144, Kind::f32, 1.3f, nullptr},                      // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                          // Cancelable
    {0x172, Kind::u8, 1, nullptr},                          // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                         // FileSuffix
    // M_LionC_RunAttackRight_Cast1
    {0x018, Kind::f32, 0.83f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_LionC_RunAttackRight_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                            // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_RunAttackRight_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_RunAttackRight_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                           // FileSuffix
    // M_LionC_RunAttackRight_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.42f, nullptr},                         // Duration
    {0x01c, Kind::u8, 1, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_RunAttackRight_Finish1"},   // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_RunAttackRight_Move2"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                           // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                           // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                           // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},               // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_RunAttackRight_Finish1
    {0x018, Kind::f32, 1.68f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_RunAttackRight_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                           // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                          // FileSuffix
    // M_LionC_RunAttackRight
    {0x070, Kind::i32, 1, nullptr},                          // HitLevel
    {0x074, Kind::u8, 5, nullptr},                           // AttributeType
    {0x075, Kind::u8, 1, nullptr},                           // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                   // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                           // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_SideR_1000_50"},     // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_RunAttackRight_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_RunAttackRight_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 10.0f, nullptr},                      // CoolTime
    {0x140, Kind::f32, 1.3f, nullptr},                       // AttackDamageRate
    {0x144, Kind::f32, 1.3f, nullptr},                       // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                           // Cancelable
    {0x172, Kind::u8, 1, nullptr},                           // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                          // FileSuffix
    // M_LionC_JumpAttackLow_Cast1
    {0x018, Kind::f32, 1.13f, nullptr},                   // Duration
    {0x034, Kind::name, 0, "M_LionC_JumpAttackLow_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                           // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_JumpAttackLow_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_JumpAttackLow_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                           // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                          // FileSuffix
    // M_LionC_JumpAttackLow_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.1f, nullptr},                          // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_JumpAttackLow_Finish1"},    // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                             // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                           // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                           // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                           // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_JumpAttackLow_HitArea"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                           // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                           // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                          // FileSuffix
    // M_LionC_JumpAttackLow_Finish1
    {0x018, Kind::f32, 0.97f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_JumpAttackLow
    {0x070, Kind::i32, 1, nullptr},                         // HitLevel
    {0x074, Kind::u8, 5, nullptr},                          // AttributeType
    {0x075, Kind::u8, 1, nullptr},                          // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                  // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                          // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_700"},      // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_JumpAttackLow_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_JumpAttackLow_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 12.0f, nullptr},                     // CoolTime
    {0x140, Kind::f32, 1.5f, nullptr},                      // AttackDamageRate
    {0x144, Kind::f32, 1.5f, nullptr},                      // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                          // Cancelable
    {0x172, Kind::u8, 1, nullptr},                          // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                         // FileSuffix
    // M_LionC_JumpAttackHigh_Cast1
    {0x018, Kind::f32, 1.96f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_LionC_JumpAttackHigh_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":4}, "
     "{\"Alias\":\"M_Common_ImmuneAbnormal_Step\"}, {\"Alias\":\"ImmuneStaminaDamage_Step\"}]"},
    {0x130, Kind::u8, 1, nullptr},                                            // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_JumpAttackHigh_Turn"},                   // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_JumpAttackHigh_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                            // CanCutoff
    {0x2ec, Kind::f32, 1.894f, nullptr},                                      // ActionAssistCheckDelay
    {0x2f0, Kind::f32, 0.03f, nullptr},                                       // ActionAssistActiveTime
    {0x2f4, Kind::f32, 0.1f, nullptr},                                        // ActionAssistCollisionPreCheckTime
    {0x2f8, Kind::name, 0, "None"},                                           // FileSuffix
    // M_LionC_JumpAttackHigh_Hit1
    {0x014, Kind::u8, 1, nullptr},                            // Type
    {0x018, Kind::f32, 0.64f, nullptr},                       // Duration
    {0x01c, Kind::u8, 3, nullptr},                            // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                        // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                        // SkillShieldAttackDamageRate
    {0x030, Kind::u8, 1, nullptr},                            // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_JumpAttackHigh_Finish1"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_KnockDown"},       // SkillResultAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":4}, "
     "{\"Alias\":\"M_Common_ImmuneAbnormal_Step\"}, {\"Alias\":\"ImmuneStaminaDamage_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_JumpAttackHigh_Move2"},  // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                            // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                            // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                            // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_JumpAttackHigh_HitArea"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                            // bIgnoreHitStop
    {0x2f0, Kind::f32, 0.03f, nullptr},                       // ActionAssistActiveTime
    {0x2f4, Kind::f32, 0.1f, nullptr},                        // ActionAssistCollisionPreCheckTime
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_JumpAttackHigh_Finish1
    {0x018, Kind::f32, 2.4f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_JumpAttackHigh_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                           // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                          // FileSuffix
    // M_LionC_JumpAttackHigh
    {0x070, Kind::i32, 1, nullptr},                          // HitLevel
    {0x074, Kind::u8, 5, nullptr},                           // AttributeType
    {0x075, Kind::u8, 1, nullptr},                           // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                   // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                           // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_1800"},      // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_JumpAttackHigh_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_JumpAttackHigh_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 25.0f, nullptr},                      // CoolTime
    {0x140, Kind::f32, 2.0f, nullptr},                       // AttackDamageRate
    {0x144, Kind::f32, 2.0f, nullptr},                       // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                           // Cancelable
    {0x172, Kind::u8, 1, nullptr},                           // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                          // FileSuffix
    // M_LionC_BackJumpToAttack_Cast1
    {0x018, Kind::f32, 1.2f, nullptr},                       // Duration
    {0x034, Kind::name, 0, "M_LionC_BackJumpToAttack_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                              // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_BackJumpToAttack_Turn"},                   // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_BackJumpToAttack_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                              // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                             // FileSuffix
    // M_LionC_BackJumpToAttack_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.1f, nullptr},                          // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_BackJumpToAttack_Finish1"}, // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},               // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_BackJumpToAttack_Finish1
    {0x018, Kind::f32, 0.9f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_BackJumpToAttack
    {0x070, Kind::i32, 1, nullptr},                            // HitLevel
    {0x074, Kind::u8, 5, nullptr},                             // AttributeType
    {0x075, Kind::u8, 1, nullptr},                             // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                     // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                             // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_LionC_BackJumpToAttack_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_BackJumpToAttack_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 30.0f, nullptr},                        // CoolTime
    {0x140, Kind::f32, 1.5f, nullptr},                         // AttackDamageRate
    {0x144, Kind::f32, 1.5f, nullptr},                         // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                             // Cancelable
    {0x172, Kind::u8, 1, nullptr},                             // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_AttackToBackJump_Cast1
    {0x018, Kind::f32, 1.15f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_LionC_AttackToBackJump_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                              // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_AttackToBackJump_Turn"},                   // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_AttackToBackJump_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                              // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                             // FileSuffix
    // M_LionC_AttackToBackJump_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.2f, nullptr},                          // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_AttackToBackJump_Finish1"}, // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},               // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_AttackToBackJump_Finish1
    {0x018, Kind::f32, 2.25f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_AttackToBackJump_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_AttackToBackJump
    {0x070, Kind::i32, 1, nullptr},                            // HitLevel
    {0x074, Kind::u8, 5, nullptr},                             // AttributeType
    {0x075, Kind::u8, 1, nullptr},                             // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                     // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                             // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Back_1100"},           // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_AttackToBackJump_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_AttackToBackJump_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 30.0f, nullptr},                        // CoolTime
    {0x140, Kind::f32, 1.5f, nullptr},                         // AttackDamageRate
    {0x144, Kind::f32, 1.5f, nullptr},                         // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                             // Cancelable
    {0x172, Kind::u8, 1, nullptr},                             // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_Roar_Cast1
    {0x018, Kind::f32, 1.332f, nullptr},         // Duration
    {0x034, Kind::name, 0, "M_LionC_Roar_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                  // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_Roar_Turn"},                   // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_Roar_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                  // CanCutoff
    {0x2e4, Kind::name, 0, "ActionAssist_3DArc_700_120"},           // ActionAssistTargetFilter
    {0x2ec, Kind::f32, 1.266f, nullptr},                            // ActionAssistCheckDelay
    {0x2f0, Kind::f32, 0.03f, nullptr},                             // ActionAssistActiveTime
    {0x2f4, Kind::f32, 0.1f, nullptr},                              // ActionAssistCollisionPreCheckTime
    {0x2f8, Kind::name, 0, "None"},                                 // FileSuffix
    // M_LionC_Roar_Hit1
    {0x014, Kind::u8, 1, nullptr},                      // Type
    {0x018, Kind::f32, 1.268f, nullptr},                // Duration
    {0x020, Kind::f32, 1.0f, nullptr},                  // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                  // SkillShieldAttackDamageRate
    {0x030, Kind::u8, 1, nullptr},                      // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_Roar_Finish1"},     // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_KnockDown"}, // SkillResultAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                          // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                        // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                        // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                        // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_Roar_HitArea"},       // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                        // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                        // bIgnoreHitStop
    {0x2e4, Kind::name, 0, "ActionAssist_3DArc_700_120"}, // ActionAssistTargetFilter
    {0x2f0, Kind::f32, 0.03f, nullptr},                   // ActionAssistActiveTime
    {0x2f4, Kind::f32, 0.1f, nullptr},                    // ActionAssistCollisionPreCheckTime
    {0x2f8, Kind::name, 0, "None"},                       // FileSuffix
    // M_LionC_Roar_Finish1
    {0x018, Kind::f32, 1.533f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_Roar_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                 // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                // FileSuffix
    // M_LionC_Roar
    {0x070, Kind::i32, 1, nullptr},                // HitLevel
    {0x074, Kind::u8, 5, nullptr},                 // AttributeType
    {0x075, Kind::u8, 1, nullptr},                 // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},         // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                 // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_LionC_Roar_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_Roar_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 40.0f, nullptr},            // CoolTime
    {0x140, Kind::f32, 2.5f, nullptr},             // AttackDamageRate
    {0x144, Kind::f32, 2.5f, nullptr},             // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                 // Cancelable
    {0x172, Kind::u8, 1, nullptr},                 // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                // FileSuffix
    // M_LionC_SideStepLeft_Cast1
    {0x018, Kind::f32, 2.0f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                          // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_SideStepLeft_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_SideStepLeft_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                          // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                         // FileSuffix
    // M_LionC_SideStepLeft
    {0x070, Kind::i32, 1, nullptr},                        // HitLevel
    {0x074, Kind::u8, 5, nullptr},                         // AttributeType
    {0x075, Kind::u8, 0, nullptr},                         // SkillType
    {0x080, Kind::name, 0, "MoveAttack"},                  // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                         // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_SideL_1100"},      // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_SideStepLeft_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_SideStepLeft_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 10.0f, nullptr},                    // CoolTime
    {0x140, Kind::f32, 0.0f, nullptr},                     // AttackDamageRate
    {0x144, Kind::f32, 0.0f, nullptr},                     // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                         // Cancelable
    {0x172, Kind::u8, 1, nullptr},                         // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                        // FileSuffix
    // M_LionC_SideStepRight_Cast1
    {0x018, Kind::f32, 2.0f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                           // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_SideStepRight_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_SideStepRight_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                           // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                          // FileSuffix
    // M_LionC_SideStepRight
    {0x070, Kind::i32, 1, nullptr},                         // HitLevel
    {0x074, Kind::u8, 5, nullptr},                          // AttributeType
    {0x075, Kind::u8, 0, nullptr},                          // SkillType
    {0x080, Kind::name, 0, "MoveAttack"},                   // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                          // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_SideR_1200_50"},    // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_SideStepRight_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_SideStepRight_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 10.0f, nullptr},                     // CoolTime
    {0x140, Kind::f32, 0.0f, nullptr},                      // AttackDamageRate
    {0x144, Kind::f32, 0.0f, nullptr},                      // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                          // Cancelable
    {0x172, Kind::u8, 1, nullptr},                          // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                         // FileSuffix
    // M_LionC_ClawAttackChain_Cast1
    {0x018, Kind::f32, 0.75f, nullptr},                     // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                             // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackChain_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                            // FileSuffix
    // M_LionC_ClawAttackChain_Hit1
    {0x014, Kind::u8, 1, nullptr},                           // Type
    {0x018, Kind::f32, 0.25f, nullptr},                      // Duration
    {0x01c, Kind::u8, 2, nullptr},                           // AttackDirection
    {0x020, Kind::f32, 0.3f, nullptr},                       // SkillAttackDamageRate
    {0x024, Kind::f32, 0.3f, nullptr},                       // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                           // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                           // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                           // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                           // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain_Cast2"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},      // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain_Move2"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                            // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                            // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                            // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChain_Cast2
    {0x018, Kind::f32, 0.1f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain_Hit2"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_ClawAttackChain_Hit2
    {0x014, Kind::u8, 1, nullptr},                           // Type
    {0x018, Kind::f32, 0.2f, nullptr},                       // Duration
    {0x01c, Kind::u8, 1, nullptr},                           // AttackDirection
    {0x020, Kind::f32, 0.3f, nullptr},                       // SkillAttackDamageRate
    {0x024, Kind::f32, 0.3f, nullptr},                       // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                           // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                           // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                           // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                           // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain_Cast3"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},      // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain_Move4"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                            // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                            // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                            // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChain_Cast3
    {0x018, Kind::f32, 0.15f, nullptr},                     // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain_Hit3"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain_Move5"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_ClawAttackChain_Hit3
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.4f, nullptr},                          // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 0.4f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 0.4f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain_Finish1"},  // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain_Move6"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                            // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                            // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                            // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChain_Finish1
    {0x018, Kind::f32, 3.417f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain_Move7"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_ClawAttackChain
    {0x070, Kind::i32, 1, nullptr},                           // HitLevel
    {0x074, Kind::u8, 5, nullptr},                            // AttributeType
    {0x075, Kind::u8, 1, nullptr},                            // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                    // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                            // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_1800"},       // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_ClawAttackChain_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_ClawAttackChain_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 15.0f, nullptr},                       // CoolTime
    {0x140, Kind::f32, 2.0f, nullptr},                        // AttackDamageRate
    {0x144, Kind::f32, 2.0f, nullptr},                        // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                            // Cancelable
    {0x172, Kind::u8, 1, nullptr},                            // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_ClawAttackChain2_Cast1
    {0x018, Kind::f32, 0.75f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain2_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                              // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain2_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackChain2_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                              // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                             // FileSuffix
    // M_LionC_ClawAttackChain2_Hit1
    {0x014, Kind::u8, 1, nullptr},                            // Type
    {0x018, Kind::f32, 0.25f, nullptr},                       // Duration
    {0x01c, Kind::u8, 2, nullptr},                            // AttackDirection
    {0x020, Kind::f32, 0.2f, nullptr},                        // SkillAttackDamageRate
    {0x024, Kind::f32, 0.2f, nullptr},                        // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                            // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                            // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                            // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                            // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain2_Cast2"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},           // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},           // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},       // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},           // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain2_Move2"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                 // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChain2_Cast2
    {0x018, Kind::f32, 0.1f, nullptr},                       // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain2_Hit2"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChain2_Hit2
    {0x014, Kind::u8, 1, nullptr},                            // Type
    {0x018, Kind::f32, 0.2f, nullptr},                        // Duration
    {0x01c, Kind::u8, 1, nullptr},                            // AttackDirection
    {0x020, Kind::f32, 0.2f, nullptr},                        // SkillAttackDamageRate
    {0x024, Kind::f32, 0.2f, nullptr},                        // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                            // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                            // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                            // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                            // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain2_Cast3"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},           // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},           // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},       // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},           // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain2_Move4"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                 // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChain2_Cast3
    {0x018, Kind::f32, 0.15f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain2_Hit3"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain2_Move5"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_ClawAttackChain2_Hit3
    {0x014, Kind::u8, 1, nullptr},                            // Type
    {0x018, Kind::f32, 0.4f, nullptr},                        // Duration
    {0x01c, Kind::u8, 2, nullptr},                            // AttackDirection
    {0x020, Kind::f32, 0.25f, nullptr},                       // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                       // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                            // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                            // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                            // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                            // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain2_Cast4"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},           // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},           // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},       // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},           // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain2_Move6"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                 // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChain2_Cast4
    {0x018, Kind::f32, 1.15f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain2_Hit4"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain2_Move7"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_ClawAttackChain2_Hit4
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.35f, nullptr},                         // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 0.35f, nullptr},                         // SkillAttackDamageRate
    {0x024, Kind::f32, 0.35f, nullptr},                         // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_ClawAttackChain2_Finish1"}, // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain2_Move8"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                 // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_ClawAttackChain2_Finish1
    {0x018, Kind::f32, 1.817f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_ClawAttackChain2_Move9"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_ClawAttackChain2
    {0x070, Kind::i32, 1, nullptr},                                          // HitLevel
    {0x074, Kind::u8, 5, nullptr},                                           // AttributeType
    {0x075, Kind::u8, 1, nullptr},                                           // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                                   // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                                           // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_1800|Valid_Move_SideR_700"}, // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_ClawAttackChain2_Target"},               // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_ClawAttackChain2_Cast1"},                // FirstSkillActiveAlias
    {0x124, Kind::f32, 20.0f, nullptr},                                      // CoolTime
    {0x140, Kind::f32, 3.0f, nullptr},                                       // AttackDamageRate
    {0x144, Kind::f32, 3.0f, nullptr},                                       // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                                           // Cancelable
    {0x172, Kind::u8, 1, nullptr},                                           // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                                          // FileSuffix
    // M_LionC_MoveAttackChain_Cast1
    {0x018, Kind::f32, 0.9f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_LionC_MoveAttackChain_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                             // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_MoveAttackChain_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_MoveAttackChain_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                            // FileSuffix
    // M_LionC_MoveAttackChain_Hit1
    {0x014, Kind::u8, 1, nullptr},                           // Type
    {0x018, Kind::f32, 0.25f, nullptr},                      // Duration
    {0x01c, Kind::u8, 2, nullptr},                           // AttackDirection
    {0x020, Kind::f32, 0.3f, nullptr},                       // SkillAttackDamageRate
    {0x024, Kind::f32, 0.3f, nullptr},                       // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                           // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                           // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                           // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                           // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_MoveAttackChain_Cast2"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},      // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},               // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"}, // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_MoveAttackChain_Cast2
    {0x018, Kind::f32, 0.65f, nullptr},                     // Duration
    {0x034, Kind::name, 0, "M_LionC_MoveAttackChain_Hit2"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_MoveAttackChain_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_MoveAttackChain_Hit2
    {0x014, Kind::u8, 1, nullptr},                           // Type
    {0x018, Kind::f32, 0.2f, nullptr},                       // Duration
    {0x01c, Kind::u8, 1, nullptr},                           // AttackDirection
    {0x020, Kind::f32, 0.3f, nullptr},                       // SkillAttackDamageRate
    {0x024, Kind::f32, 0.3f, nullptr},                       // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                           // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                           // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                           // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                           // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_MoveAttackChain_Cast3"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},         // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},      // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_MoveAttackChain_Move4"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                            // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                            // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                            // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_MoveAttackChain_Cast3
    {0x018, Kind::f32, 1.0f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_LionC_MoveAttackChain_Hit3"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_MoveAttackChain_Move5"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_MoveAttackChain_Hit3
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.1f, nullptr},                          // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 0.4f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 0.4f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_MoveAttackChain_Finish1"},  // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_MoveAttackChain_Move6"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                            // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                            // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                            // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},                // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_MoveAttackChain_Finish1
    {0x018, Kind::f32, 2.0f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_MoveAttackChain
    {0x070, Kind::i32, 1, nullptr},                           // HitLevel
    {0x074, Kind::u8, 5, nullptr},                            // AttributeType
    {0x075, Kind::u8, 1, nullptr},                            // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                    // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                            // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_1800"},       // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_MoveAttackChain_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_MoveAttackChain_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 18.0f, nullptr},                       // CoolTime
    {0x140, Kind::f32, 2.5f, nullptr},                        // AttackDamageRate
    {0x144, Kind::f32, 2.5f, nullptr},                        // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                            // Cancelable
    {0x172, Kind::u8, 1, nullptr},                            // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_RushAttack_Cast1
    {0x018, Kind::f32, 0.18f, nullptr},                 // Duration
    {0x034, Kind::name, 0, "M_LionC_RushAttack_Cast2"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                        // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_RushAttack_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_RushAttack_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                        // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                       // FileSuffix
    // M_LionC_RushAttack_Cast2
    {0x018, Kind::f32, 0.175f, nullptr},               // Duration
    {0x034, Kind::name, 0, "M_LionC_RushAttack_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_RushAttack_Move2"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                       // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                      // FileSuffix
    // M_LionC_RushAttack_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.345f, nullptr},                        // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_RushAttack_Finish1"},       // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_RushAttack_Move3"}, // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                       // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 2, nullptr},                       // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                       // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_HitArea"},           // OverrideTargetFilterAlias
    // AttackCollisionGroupArray
    {0x1c0, Kind::string, 0, "[{\"CollisionGroupName\":\"Mon_Lion_Attack_R_Arm_Collision\", \"DelayTime\":0}]"},
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x272, Kind::u8, 1, nullptr},  // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_RushAttack_Finish1
    {0x018, Kind::f32, 0.6f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_LionC_RushAttack
    {0x070, Kind::i32, 1, nullptr},                      // HitLevel
    {0x074, Kind::u8, 5, nullptr},                       // AttributeType
    {0x075, Kind::u8, 1, nullptr},                       // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},               // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                       // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_1800"},  // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_RushAttack_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_RushAttack_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 12.0f, nullptr},                  // CoolTime
    {0x140, Kind::f32, 1.5f, nullptr},                   // AttackDamageRate
    {0x144, Kind::f32, 1.5f, nullptr},                   // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                       // Cancelable
    {0x172, Kind::u8, 1, nullptr},                       // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                      // FileSuffix
    // M_LionC_DashAttackChain_Cast1
    {0x018, Kind::f32, 1.541f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_LionC_DashAttackChain_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                             // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move1"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_DashAttackChain_1"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                             // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                            // FileSuffix
    // M_LionC_DashAttackChain_Hit1
    {0x014, Kind::u8, 1, nullptr},                           // Type
    {0x018, Kind::f32, 0.482f, nullptr},                     // Duration
    {0x01c, Kind::u8, 3, nullptr},                           // AttackDirection
    {0x020, Kind::f32, 0.25f, nullptr},                      // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                      // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                           // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                           // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                           // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                           // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_DashAttackChain_Cast2"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},         // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},      // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move2"},  // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_DashAttackChain_HitArea"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                             // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                             // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_DashAttackChain_Cast2
    {0x018, Kind::f32, 0.203f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_LionC_DashAttackChain_Hit2"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_DashAttackChain_Hit2
    {0x014, Kind::u8, 1, nullptr},                           // Type
    {0x018, Kind::f32, 0.623f, nullptr},                     // Duration
    {0x01c, Kind::u8, 3, nullptr},                           // AttackDirection
    {0x020, Kind::f32, 0.25f, nullptr},                      // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                      // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                           // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                           // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                           // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                           // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_DashAttackChain_Cast3"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},         // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},      // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move4"},  // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_DashAttackChain_HitArea"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                             // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                             // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_DashAttackChain_Cast3
    {0x018, Kind::f32, 0.276f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_LionC_DashAttackChain_Hit3"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move5"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_DashAttackChain_Hit3
    {0x014, Kind::u8, 1, nullptr},                           // Type
    {0x018, Kind::f32, 0.355f, nullptr},                     // Duration
    {0x01c, Kind::u8, 3, nullptr},                           // AttackDirection
    {0x020, Kind::f32, 0.25f, nullptr},                      // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                      // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                           // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                           // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                           // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                           // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_DashAttackChain_Cast4"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},         // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"},      // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move6"},  // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_DashAttackChain_HitArea"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                             // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                             // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_DashAttackChain_Cast4
    {0x018, Kind::f32, 0.206f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_LionC_DashAttackChain_Hit4"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move7"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_DashAttackChain_Hit4
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.62f, nullptr},                         // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 0.25f, nullptr},                         // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                         // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_DashAttackChain_Finish1"},  // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_LionC_Result_Strong"},            // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_LionC_Result_Parry"},             // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_LionC_Result_Guard"},             // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move8"},  // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                             // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                             // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                             // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_DashAttackChain_HitArea"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                             // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                             // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                            // FileSuffix
    // M_LionC_DashAttackChain_Finish1
    {0x018, Kind::f32, 0.8f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_DashAttackChain_Move9"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_DashAttackChain
    {0x070, Kind::i32, 1, nullptr},                           // HitLevel
    {0x074, Kind::u8, 5, nullptr},                            // AttributeType
    {0x075, Kind::u8, 1, nullptr},                            // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                    // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                            // bCheckTargetExists
    {0x090, Kind::names, 0, "Valid_Move_Forward_1800"},       // CheckValidMoveAliasArray
    {0x0b4, Kind::name, 0, "M_LionC_DashAttackChain_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_DashAttackChain_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 25.0f, nullptr},                       // CoolTime
    {0x140, Kind::f32, 3.0f, nullptr},                        // AttackDamageRate
    {0x144, Kind::f32, 3.0f, nullptr},                        // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                            // Cancelable
    {0x172, Kind::u8, 1, nullptr},                            // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_RoarPhaseChange_Cast1
    {0x018, Kind::f32, 1.332f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_LionC_RoarPhaseChange_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":4}, "
     "{\"Alias\":\"FinalHPDamageReduceRate090_Step\"}, {\"Alias\":\"M_Common_ImmuneAbnormal_Skill\"}, "
     "{\"Alias\":\"ImmuneStaminaDamage_Skill\"}]"},
    {0x120, Kind::string, 0, "[{\"Alias\":\"P_Eve_BlockRangeMode_Skill\"}]"}, // StartTargetEffect
    {0x130, Kind::u8, 1, nullptr},                                            // StopSelfMove
    {0x138, Kind::names, 0, "M_LionC_RoarPhaseChange_Turn"},                  // SelfMoveAliasArray
    {0x160, Kind::name, 0, "CH_M_NA_02_Lion/Skill/M_LionC_Roar_1"},           // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                            // CanCutoff
    {0x2e4, Kind::name, 0, "ActionAssist_3DArc_700_120"},                     // ActionAssistTargetFilter
    {0x2ec, Kind::f32, 1.266f, nullptr},                                      // ActionAssistCheckDelay
    {0x2f0, Kind::f32, 0.03f, nullptr},                                       // ActionAssistActiveTime
    {0x2f4, Kind::f32, 0.1f, nullptr},                                        // ActionAssistCollisionPreCheckTime
    {0x2f8, Kind::name, 0, "None"},                                           // FileSuffix
    // M_LionC_RoarPhaseChange_Hit1
    {0x014, Kind::u8, 1, nullptr},                             // Type
    {0x018, Kind::f32, 1.268f, nullptr},                       // Duration
    {0x020, Kind::f32, 1.0f, nullptr},                         // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                         // SkillShieldAttackDamageRate
    {0x030, Kind::u8, 1, nullptr},                             // AvailableJustAction
    {0x034, Kind::name, 0, "M_LionC_RoarPhaseChange_Finish1"}, // NextStepAlias
    {0x0cc, Kind::name, 0, "M_LionC_Result_KnockDown"},        // SkillResultAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"ShowTag_AdditiveNoPlay_Step\"}, "
     "{\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":4}, "
     "{\"Alias\":\"FinalHPDamageReduceRate090_Step\"}, {\"Alias\":\"M_Common_ImmuneAbnormal_Skill\"}, "
     "{\"Alias\":\"ImmuneStaminaDamage_Skill\"}]"},
    {0x138, Kind::names, 0, ""},                          // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                        // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                        // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                        // bRetargeting
    {0x1b4, Kind::name, 0, "M_LionC_Roar_HitArea"},       // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                        // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                        // bIgnoreHitStop
    {0x2e4, Kind::name, 0, "ActionAssist_3DArc_700_120"}, // ActionAssistTargetFilter
    {0x2f0, Kind::f32, 0.03f, nullptr},                   // ActionAssistActiveTime
    {0x2f4, Kind::f32, 0.1f, nullptr},                    // ActionAssistCollisionPreCheckTime
    {0x2f8, Kind::name, 0, "None"},                       // FileSuffix
    // M_LionC_RoarPhaseChange_Finish1
    {0x018, Kind::f32, 1.533f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, "M_LionC_RoarPhaseChange_Move3"}, // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},                            // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_LionC_RoarPhaseChange
    {0x070, Kind::i32, 1, nullptr},                          // HitLevel
    {0x074, Kind::u8, 5, nullptr},                           // AttributeType
    {0x075, Kind::u8, 1, nullptr},                           // SkillType
    {0x080, Kind::name, 0, "PhaseChange"},                   // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                           // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_LionC_HitArea"},               // TargetFilterAlias
    {0x100, Kind::name, 0, "M_LionC_RoarPhaseChange_Cast1"}, // FirstSkillActiveAlias
    {0x124, Kind::f32, 5.0f, nullptr},                       // CoolTime
    {0x140, Kind::f32, 2.5f, nullptr},                       // AttackDamageRate
    {0x144, Kind::f32, 2.5f, nullptr},                       // ShieldAttackDamageRate
    {0x14c, Kind::u8, 0, nullptr},                           // Cancelable
    {0x172, Kind::u8, 1, nullptr},                           // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                          // FileSuffix
    // M_LionC_ClawAttackLeft
    {0x018, Kind::name, 0, "M_LionC_ClawAttackLeft"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                    // bJumping
    {0x04f, Kind::u8, 1, nullptr},                    // bFly
    {0x053, Kind::u8, 1, nullptr},                    // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                 // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                   // FileSuffix
    // M_LionC_ClawAttackRight
    {0x018, Kind::name, 0, "M_LionC_ClawAttackRight"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                     // bJumping
    {0x04f, Kind::u8, 1, nullptr},                     // bFly
    {0x053, Kind::u8, 1, nullptr},                     // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                  // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                    // FileSuffix
    // M_LionC_ClawAttackChaseLeft
    {0x018, Kind::name, 0, "M_LionC_ClawAttackChaseLeft"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                         // bJumping
    {0x04f, Kind::u8, 1, nullptr},                         // bFly
    {0x053, Kind::u8, 1, nullptr},                         // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                      // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                        // FileSuffix
    // M_LionC_ClawAttackChaseRight
    {0x018, Kind::name, 0, "M_LionC_ClawAttackChaseRight"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                          // bJumping
    {0x04f, Kind::u8, 1, nullptr},                          // bFly
    {0x053, Kind::u8, 1, nullptr},                          // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                       // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                         // FileSuffix
    // M_LionC_TurnAttackLeft
    {0x018, Kind::name, 0, "M_LionC_TurnAttackLeft"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                    // bJumping
    {0x04f, Kind::u8, 1, nullptr},                    // bFly
    {0x053, Kind::u8, 1, nullptr},                    // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                 // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                   // FileSuffix
    // M_LionC_TurnAttackRight
    {0x018, Kind::name, 0, "M_LionC_TurnAttackRight"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                     // bJumping
    {0x04f, Kind::u8, 1, nullptr},                     // bFly
    {0x053, Kind::u8, 1, nullptr},                     // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                  // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                    // FileSuffix
    // M_LionC_RunAttackLeft
    {0x018, Kind::name, 0, "M_LionC_RunAttackLeft"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                   // bJumping
    {0x04f, Kind::u8, 1, nullptr},                   // bFly
    {0x053, Kind::u8, 1, nullptr},                   // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                  // FileSuffix
    // M_LionC_RunAttackRight
    {0x018, Kind::name, 0, "M_LionC_RunAttackRight"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                    // bJumping
    {0x04f, Kind::u8, 1, nullptr},                    // bFly
    {0x053, Kind::u8, 1, nullptr},                    // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                 // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                   // FileSuffix
    // M_LionC_JumpAttackLow
    {0x018, Kind::name, 0, "M_LionC_JumpAttackLow"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                   // bJumping
    {0x04f, Kind::u8, 1, nullptr},                   // bFly
    {0x053, Kind::u8, 1, nullptr},                   // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                  // FileSuffix
    // M_LionC_JumpAttackHigh
    {0x018, Kind::name, 0, "M_LionC_JumpAttackHigh"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                    // bJumping
    {0x04f, Kind::u8, 1, nullptr},                    // bFly
    {0x053, Kind::u8, 1, nullptr},                    // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                 // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                   // FileSuffix
    // M_LionC_BackJumpToAttack
    {0x018, Kind::name, 0, "M_LionC_BackJumpToAttack"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                      // bJumping
    {0x04f, Kind::u8, 1, nullptr},                      // bFly
    {0x053, Kind::u8, 1, nullptr},                      // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                   // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_LionC_AttackToBackJump
    {0x018, Kind::name, 0, "M_LionC_AttackToBackJump"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                      // bJumping
    {0x04f, Kind::u8, 1, nullptr},                      // bFly
    {0x053, Kind::u8, 1, nullptr},                      // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                   // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_LionC_Roar
    {0x018, Kind::name, 0, "M_LionC_Roar"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},          // bJumping
    {0x04f, Kind::u8, 1, nullptr},          // bFly
    {0x053, Kind::u8, 1, nullptr},          // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},       // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},         // FileSuffix
    // M_LionC_SideStepLeft
    {0x018, Kind::name, 0, "M_LionC_SideStepLeft"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                  // bJumping
    {0x04f, Kind::u8, 1, nullptr},                  // bFly
    {0x053, Kind::u8, 1, nullptr},                  // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},               // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                 // FileSuffix
    // M_LionC_SideStepRight
    {0x018, Kind::name, 0, "M_LionC_SideStepRight"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                   // bJumping
    {0x04f, Kind::u8, 1, nullptr},                   // bFly
    {0x053, Kind::u8, 1, nullptr},                   // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                  // FileSuffix
    // M_LionC_ClawAttackChain
    {0x018, Kind::name, 0, "M_LionC_ClawAttackChain"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                     // bJumping
    {0x04f, Kind::u8, 1, nullptr},                     // bFly
    {0x053, Kind::u8, 1, nullptr},                     // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                  // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                    // FileSuffix
    // M_LionC_ClawAttackChain2
    {0x018, Kind::name, 0, "M_LionC_ClawAttackChain2"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                      // bJumping
    {0x04f, Kind::u8, 1, nullptr},                      // bFly
    {0x053, Kind::u8, 1, nullptr},                      // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                   // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_LionC_MoveAttackChain
    {0x018, Kind::name, 0, "M_LionC_MoveAttackChain"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                     // bJumping
    {0x04f, Kind::u8, 1, nullptr},                     // bFly
    {0x053, Kind::u8, 1, nullptr},                     // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                  // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                    // FileSuffix
    // M_LionC_RushAttack
    {0x018, Kind::name, 0, "M_LionC_RushAttack"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                // bJumping
    {0x04f, Kind::u8, 1, nullptr},                // bFly
    {0x053, Kind::u8, 1, nullptr},                // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},             // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},               // FileSuffix
    // M_LionC_DashAttackChain
    {0x018, Kind::name, 0, "M_LionC_DashAttackChain"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                     // bJumping
    {0x04f, Kind::u8, 1, nullptr},                     // bFly
    {0x053, Kind::u8, 1, nullptr},                     // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                  // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                    // FileSuffix
    // M_LionC_RoarPhaseChange
    {0x018, Kind::name, 0, "M_LionC_RoarPhaseChange"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                     // bJumping
    {0x04f, Kind::u8, 1, nullptr},                     // bFly
    {0x053, Kind::u8, 1, nullptr},                     // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                  // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                    // FileSuffix
    // M_LionC_Peaceful
    {0x018, Kind::string, 0, "Animation/BlendSpace/IdleRun_BS_Peaceful"}, // RunBlendSpace
    {0x028, Kind::string, 0, "Animation/BlendSpace/IdleRun_BS_Peaceful"}, // RunTiltBlendSpace
    {0x038, Kind::u8, 0, nullptr},                                        // IdleAnimType
    {0x0a0, Kind::string, 0, ""},                                         // LockOnRunBlendSpace
    {0x0f0, Kind::string, 0, "Animation/Result_State_Airborne_L"},        // Fall
    {0x270, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},             // RunToIdle_L
    {0x280, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},             // RunToIdle_R
    {0x290, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},             // RunToIdle
    {0x2d0, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},             // ShortMoveToIdle_L
    {0x2e0, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},             // ShortMoveToIdle_R
    {0x2f0, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},             // ShortMoveToIdle
    {0x330, Kind::string, 0, "Animation/Mon_Lion_B_Run_Start"},           // RunStart
    {0x340, Kind::string, 0, "Animation/Mon_Lion_B_Run_Start"},           // RunStartAfterEvade
    {0x350, Kind::string, 0, "Animation/Mon_B_Lion_Run_L_Turn"},          // RunTurn_L
    {0x360, Kind::string, 0, "Animation/Mon_B_Lion_Run_R_Turn"},          // RunTurn_R
    {0x370, Kind::string, 0, "Animation/Mon_B_Lion_Run_L_Turn"},          // WalkTurn_L
    {0x380, Kind::string, 0, "Animation/Mon_B_Lion_Run_R_Turn"},          // WalkTurn_R
    {0x970, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Rw"},   // Custom_HitStandLight1Left
    {0x980, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Lw"},   // Custom_HitStandLight1Right
    {0x990, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Dw"},   // Custom_HitStandLight1Back
    {0x9a0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Uw"},   // Custom_HitStandLight1Front
    {0x9b0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Lw"},      // Custom_HitStandLight2Left
    {0x9c0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Rw"},      // Custom_HitStandLight2Right
    {0x9e0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Bw"},      // Custom_HitStandLight2Front
    {0x9f0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Rw"},   // Custom_HitStandStrong1Left
    {0xa00, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Lw"},   // Custom_HitStandStrong1Right
    {0xa10, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Dw"},   // Custom_HitStandStrong1Back
    {0xa20, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Uw"},   // Custom_HitStandStrong1Front
    {0xa30, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Lw"},      // Custom_HitStandStrong2Left
    {0xa40, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Rw"},      // Custom_HitStandStrong2Right
    {0xa60, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Bw"},      // Custom_HitStandStrong2Front
    {0xa70, Kind::string, 0, "Animation/Result_State_Groggy_S"},          // Custom_Groggy_Start
    {0xa80, Kind::string, 0, "Animation/Result_State_Groggy_L"},          // Custom_Groggy_Loop
    {0xa90, Kind::string, 0, "Animation/Result_State_Groggy_E"},          // Custom_Groggy_End
    {0xaa0, Kind::string, 0, "Animation/Result_State_Airborne_L"},        // Custom_Airborne_Loop
    {0xab0, Kind::string, 0, "Animation/Result_State_KnockDown_S_Fw"},    // Custom_KnockDown_Start_Front
    {0xac0, Kind::string, 0, "Animation/Result_State_KnockDown_S_Bw"},    // Custom_KnockDown_Start_Back
    {0xad0, Kind::string, 0, "Animation/Result_State_KnockDown_L"},       // Custom_KnockDown_Loop
    {0xae0, Kind::string, 0, "Animation/Result_State_KnockDown_E"},       // Custom_KnockDown_End
    {0xb10, Kind::string, 0, "Animation/Hit_Sword_Normal_LinkAttack1"},   // Custom_HitSwordNormalLinkAttack1
    {0xb20, Kind::string, 0, "Animation/Hit_Sword_Normal_LinkAttack1"},   // Custom_HitSwordNormalFinishLinkAttack1
    {0xb50, Kind::string, 0, "Animation/Result_Hit_JustParry"},           // Custom_Anim1
    {0xb60, Kind::string, 0, "Animation/Result_Weak_S"},                  // Custom_Anim2
    {0xb70, Kind::string, 0, ""},                                         // Custom_Anim3
    {0xb80, Kind::string, 0, "Animation/Result_Hit_JustParry"},           // Custom_Anim4
    // M_LionC_Battle
    {0x018, Kind::string, 0, "Animation/BlendSpace/IdleRun_BS_"},       // RunBlendSpace
    {0x028, Kind::string, 0, "Animation/BlendSpace/IdleRun_BS_"},       // RunTiltBlendSpace
    {0x038, Kind::u8, 1, nullptr},                                      // IdleAnimType
    {0x0a0, Kind::string, 0, "Animation/Blendspace/LockOn_BS"},         // LockOnRunBlendSpace
    {0x0f0, Kind::string, 0, "Animation/Result_State_Airborne_L"},      // Fall
    {0x270, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},           // RunToIdle_L
    {0x280, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},           // RunToIdle_R
    {0x290, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},           // RunToIdle
    {0x2d0, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},           // ShortMoveToIdle_L
    {0x2e0, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},           // ShortMoveToIdle_R
    {0x2f0, Kind::string, 0, "Animation/Mon_Lion_B_Run_End"},           // ShortMoveToIdle
    {0x330, Kind::string, 0, "Animation/Mon_Lion_B_Run_Start"},         // RunStart
    {0x340, Kind::string, 0, "Animation/Mon_Lion_B_Run_Start"},         // RunStartAfterEvade
    {0x350, Kind::string, 0, "Animation/Mon_B_Lion_Run_L_Turn"},        // RunTurn_L
    {0x360, Kind::string, 0, "Animation/Mon_B_Lion_Run_R_Turn"},        // RunTurn_R
    {0x370, Kind::string, 0, "Animation/Mon_B_Lion_Run_L_Turn"},        // WalkTurn_L
    {0x380, Kind::string, 0, "Animation/Mon_B_Lion_Run_R_Turn"},        // WalkTurn_R
    {0x970, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Rw"}, // Custom_HitStandLight1Left
    {0x980, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Lw"}, // Custom_HitStandLight1Right
    {0x990, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Dw"}, // Custom_HitStandLight1Back
    {0x9a0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Uw"}, // Custom_HitStandLight1Front
    {0x9b0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Lw"},    // Custom_HitStandLight2Left
    {0x9c0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Rw"},    // Custom_HitStandLight2Right
    {0x9e0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Bw"},    // Custom_HitStandLight2Front
    {0x9f0, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Rw"}, // Custom_HitStandStrong1Left
    {0xa00, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Lw"}, // Custom_HitStandStrong1Right
    {0xa10, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Dw"}, // Custom_HitStandStrong1Back
    {0xa20, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Fw_Uw"}, // Custom_HitStandStrong1Front
    {0xa30, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Lw"},    // Custom_HitStandStrong2Left
    {0xa40, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Rw"},    // Custom_HitStandStrong2Right
    {0xa60, Kind::string, 0, "Animation/Result_Hit_Stand_Light_Bw"},    // Custom_HitStandStrong2Front
    {0xa70, Kind::string, 0, "Animation/Result_State_Groggy_S"},        // Custom_Groggy_Start
    {0xa80, Kind::string, 0, "Animation/Result_State_Groggy_L"},        // Custom_Groggy_Loop
    {0xa90, Kind::string, 0, "Animation/Result_State_Groggy_E"},        // Custom_Groggy_End
    {0xaa0, Kind::string, 0, "Animation/Result_State_Airborne_L"},      // Custom_Airborne_Loop
    {0xab0, Kind::string, 0, "Animation/Result_State_KnockDown_S_Fw"},  // Custom_KnockDown_Start_Front
    {0xac0, Kind::string, 0, "Animation/Result_State_KnockDown_S_Bw"},  // Custom_KnockDown_Start_Back
    {0xad0, Kind::string, 0, "Animation/Result_State_KnockDown_L"},     // Custom_KnockDown_Loop
    {0xae0, Kind::string, 0, "Animation/Result_State_KnockDown_E"},     // Custom_KnockDown_End
    {0xb10, Kind::string, 0, "Animation/Hit_Sword_Normal_LinkAttack1"}, // Custom_HitSwordNormalLinkAttack1
    {0xb20, Kind::string, 0, "Animation/Hit_Sword_Normal_LinkAttack1"}, // Custom_HitSwordNormalFinishLinkAttack1
    {0xb50, Kind::string, 0, "Animation/Result_Hit_JustParry"},         // Custom_Anim1
    {0xb60, Kind::string, 0, "Animation/Result_Weak_S"},                // Custom_Anim2
    {0xb70, Kind::string, 0, ""},                                       // Custom_Anim3
    {0xb80, Kind::string, 0, "Animation/Result_Hit_JustParry"},         // Custom_Anim4
    // M_LionC_Default
    {0x01a, Kind::u8, 1, nullptr}, // bDetectCloakingTarget
    {0x08d, Kind::u8, 1, nullptr}, // bInfiniteStance
    // CommandArray
    {0x090, Kind::names, 0,
     "M_LionC_ClawAttackLeft|M_LionC_ClawAttackRight|M_LionC_ClawAttackChaseLeft|M_LionC_ClawAttackChaseRight|"
     "M_LionC_TurnAttackLeft|M_LionC_TurnAttackRight|M_LionC_RunAttackLeft|M_LionC_RunAttackRight|"
     "M_LionC_JumpAttackLow|M_LionC_JumpAttackHigh|M_LionC_BackJumpToAttack|M_LionC_AttackToBackJump|M_LionC_Roar|"
     "M_LionC_SideStepLeft|M_LionC_SideStepRight|M_LionC_ClawAttackChain|M_LionC_RushAttack"},
    {0x0a8, Kind::f32, 200.0f, nullptr},                                            // WalkSpeed
    {0x0ac, Kind::f32, 900.0f, nullptr},                                            // RunSpeed
    {0x0b0, Kind::f32, 900.0f, nullptr},                                            // LockOnRunSpeed
    {0x0b4, Kind::f32, 200.0f, nullptr},                                            // LockOnWalkSpeed
    {0x0bc, Kind::f32, 180.0f, nullptr},                                            // RotateAnglePerSecond
    {0x110, Kind::string, 0, "[{\"Alias\":\"M_Common_HitProjectileCheckCount\"}]"}, // StartEffect
    {0x150, Kind::name, 0, "M_LionC_Peaceful"},                                     // AnimSet_Peaceful_UpperBody
    {0x158, Kind::name, 0, "M_LionC_Peaceful"},                                     // AnimSet_Peaceful_LowerBody
    {0x160, Kind::name, 0, "M_LionC_Battle"},                                       // AnimSet_Battle_UpperBody
    {0x168, Kind::name, 0, "M_LionC_Battle"},                                       // AnimSet_Battle_LowerBody
    {0x170, Kind::name, 0, "Groggy"},                                               // AnimSet_Groggy_UpperBody
    {0x178, Kind::name, 0, "Groggy"},                                               // AnimSet_Groggy_LowerBody
    {0x180, Kind::name, 0, "Down"},                                                 // AnimSet_Down_UpperBody
    {0x188, Kind::name, 0, "Down"},                                                 // AnimSet_Down_LowerBody
    {0x1a0, Kind::name, 0, "Airborne"},                                             // AnimSet_Airborne_UpperBody
    {0x1a8, Kind::name, 0, "Airborne"},                                             // AnimSet_Airborne_LowerBody
    // M_LionC_Phase2
    {0x014, Kind::i32, 10, nullptr}, // Priority
    {0x01a, Kind::u8, 1, nullptr},   // bDetectCloakingTarget
    {0x030, Kind::u8, 1, nullptr},   // Condition_ActorStat
    {0x031, Kind::u8, 2, nullptr},   // Condition_ActorStatCheck
    {0x034, Kind::i32, 60, nullptr}, // Condition_ActorStatCheckValue
    {0x08d, Kind::u8, 1, nullptr},   // bInfiniteStance
    // CommandArray
    {0x090, Kind::names, 0,
     "M_LionC_ClawAttackLeft|M_LionC_ClawAttackRight|M_LionC_ClawAttackChaseLeft|M_LionC_ClawAttackChaseRight|"
     "M_LionC_TurnAttackLeft|M_LionC_TurnAttackRight|M_LionC_RunAttackLeft|M_LionC_RunAttackRight|"
     "M_LionC_JumpAttackLow|M_LionC_JumpAttackHigh|M_LionC_BackJumpToAttack|M_LionC_AttackToBackJump|M_LionC_Roar|"
     "M_LionC_SideStepLeft|M_LionC_SideStepRight|M_LionC_ClawAttackChain|M_LionC_ClawAttackChain2|"
     "M_LionC_MoveAttackChain|M_LionC_RushAttack|M_LionC_DashAttackChain|M_LionC_RoarPhaseChange"},
    {0x0a8, Kind::f32, 200.0f, nullptr}, // WalkSpeed
    {0x0ac, Kind::f32, 900.0f, nullptr}, // RunSpeed
    {0x0b0, Kind::f32, 900.0f, nullptr}, // LockOnRunSpeed
    {0x0b4, Kind::f32, 200.0f, nullptr}, // LockOnWalkSpeed
    {0x0bc, Kind::f32, 180.0f, nullptr}, // RotateAnglePerSecond
    // StartEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"RecoverShield_100p\"}, {\"Alias\":\"M_LionC_PhaseRoar\"}, "
     "{\"Alias\":\"M_Common_HitProjectileCheckCount\"}]"},
    {0x150, Kind::name, 0, "M_LionC_Peaceful"}, // AnimSet_Peaceful_UpperBody
    {0x158, Kind::name, 0, "M_LionC_Peaceful"}, // AnimSet_Peaceful_LowerBody
    {0x160, Kind::name, 0, "M_LionC_Battle"},   // AnimSet_Battle_UpperBody
    {0x168, Kind::name, 0, "M_LionC_Battle"},   // AnimSet_Battle_LowerBody
    {0x170, Kind::name, 0, "Groggy"},           // AnimSet_Groggy_UpperBody
    {0x178, Kind::name, 0, "Groggy"},           // AnimSet_Groggy_LowerBody
    {0x180, Kind::name, 0, "Down"},             // AnimSet_Down_UpperBody
    {0x188, Kind::name, 0, "Down"},             // AnimSet_Down_LowerBody
    {0x1a0, Kind::name, 0, "Airborne"},         // AnimSet_Airborne_UpperBody
    {0x1a8, Kind::name, 0, "Airborne"},         // AnimSet_Airborne_LowerBody
    // M_LionC
    {0x010, Kind::strings, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},      // DefaultDeadShowArray
    {0x020, Kind::i32, 7000, nullptr},                                   // DefaultDeadRewardDelayTime
    {0x038, Kind::string, 0, "Dead/Dead_Monster_EffectType_Stand"},      // StandDeadShow
    {0x048, Kind::i32, 300, nullptr},                                    // StandDeadRewardDelayTime
    {0x058, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Step0DeadShow
    {0x068, Kind::i32, 7000, nullptr},                                   // Step0DeadRewardDelayTime
    {0x078, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Step1DeadShow
    {0x088, Kind::i32, 7000, nullptr},                                   // Step1DeadRewardDelayTime
    {0x098, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Step2DeadShow
    {0x0a8, Kind::i32, 7000, nullptr},                                   // Step2DeadRewardDelayTime
    {0x0b8, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Step3DeadShow
    {0x0c8, Kind::i32, 7000, nullptr},                                   // Step3DeadRewardDelayTime
    {0x0d8, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Explosion1DeadShow
    {0x0e8, Kind::i32, 7000, nullptr},                                   // Explosion1DeadRewardDelayTime
    {0x0f8, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Explosion2DeadShow
    {0x108, Kind::i32, 7000, nullptr},                                   // Explosion2DeadRewardDelayTime
    {0x118, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Custom1DeadShow
    {0x178, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Custom4DeadShow
    {0x188, Kind::i32, 7000, nullptr},                                   // Custom4DeadRewardDelayTime
    {0x1b8, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Custom6DeadShow
    {0x1c8, Kind::i32, 7000, nullptr},                                   // Custom6DeadRewardDelayTime
    {0x1d8, Kind::string, 0, "Dead/Dead_Monster_EffectType_ZoneEffect"}, // Custom7DeadShow
    {0x1f8, Kind::string, 0, "CH_M_NA_02_Lion/Basic/M_Lion_Dead"},       // Custom8DeadShow
    {0x208, Kind::i32, 7000, nullptr},                                   // Custom8DeadRewardDelayTime
    {0x258, Kind::string, 0, "Dead/Dead_Monster_StandCommon"},           // DownDeadShow
    {0x278, Kind::string, 0, "Dead/Dead_Monster_StandCommon"},           // AirborneDeadShow
    {0x298, Kind::string, 0, "Dead/Dead_Monster_StandCommon"},           // SwimmingDeadShow
    // M_LionC
    // CharacterAssetPath
    {0x014, Kind::name, 0, "/Game/Art/Character/Monster/CH_M_NA_02/BluePrints/CH_M_NA_02_BluePrint_Large"},
    {0x0e0, Kind::name, 0, "None"}, // AirborneToDownShowPath
    // M_LionC_Lurker
    {0x014, Kind::name, 0, "Elite"},     // Rank
    {0x020, Kind::string, 0, "M_LionC"}, // Type
    {0x030, Kind::name, 0, "Monster"},   // Tribe
    {0x060, Kind::names, 0, "Common"},   // LinkSkillRandomActiveStepFlagArray
    {0x070, Kind::name, 0, "Lion"},      // Flag
    {0x078, Kind::i32, 160000, nullptr}, // MaxHP
    {0x07c, Kind::i32, 3300, nullptr},   // MaxShield
    {0x080, Kind::i32, 14, nullptr},     // MaxStamina
    {0x084, Kind::f32, 960.0f, nullptr}, // PhysicAttackPower
    {0x088, Kind::f32, 960.0f, nullptr}, // RangeAttackPower
    {0x08c, Kind::f32, 110.0f, nullptr}, // ShieldAttackPower
    {0x090, Kind::f32, 1.0f, nullptr},   // StaminaAttackPower
    {0x094, Kind::f32, 5.0f, nullptr},   // ShieldBlock
    {0x09c, Kind::f32, 0.1f, nullptr},   // DamageReductionPerShieldBock
    {0x0d0, Kind::i32, 80, nullptr},     // GainTachyGaugeOnDead
    {0x0d4, Kind::i32, 1, nullptr},      // MoveSpeed
    {0x0d8, Kind::f32, 1.0f, nullptr},   // AttackSpeed
    {0x0e0, Kind::f32, 1.2f, nullptr},   // CriticalValueRate
    // EffectAliasWhenZeroStaminaArray
    {0x168, Kind::names, 0, "M_LinkAttackDelay_10|Groggy|SkillCancel|BlockSkill|M_StaminaRecoverReady"},
    {0x1f8, Kind::u8, 5, nullptr},                                      // WeightType
    {0x1fc, Kind::f32, 1.0f, nullptr},                                  // MeshScale
    {0x200, Kind::f32, 190.0f, nullptr},                                // TargetFilterRadius
    {0x204, Kind::f32, 300.0f, nullptr},                                // ProjectileTargetFilterRadius
    {0x208, Kind::f32, 240.0f, nullptr},                                // RuleMoveBlockAreaRadius
    {0x20c, Kind::f32, 800.0f, nullptr},                                // RuleMoveBlockAreaZHeight
    {0x210, Kind::f32, 60.0f, nullptr},                                 // RuleMoveBlockAreaOffsetX
    {0x21c, Kind::f32, 190.0f, nullptr},                                // RuleMoveBlockCheckRadius
    {0x220, Kind::names, 0, "Rank_Elite"},                              // DefaultEffectArray
    {0x270, Kind::name, 0, "MonsterElite"},                             // DifficultyStatGroupAlias
    {0x288, Kind::string, 0, "[{\"Alias\":\"BurstGauge_DeadElite\"}]"}, // AttackerEffectWhenDead
    {0x298, Kind::name, 0, "M_LionC"},                                  // DeadAlias
    {0x2a0, Kind::f32, 1.0f, nullptr},                                  // DespawnTimeAfterDeath
    {0x2a8, Kind::string, 0, "Despawn/M_LionA_Despawn"},                // DespawnShow
    {0x398, Kind::names, 0, "M_LionC_Phase2"},                          // StanceAliasArray
    {0x3a8, Kind::name, 0, "M_LionC_Default"},                          // DefaultStanceAlias
    {0x3b0, Kind::f32, 1.5f, nullptr},                                  // GetupTime
    {0x3bc, Kind::f32, 2.0f, nullptr},                                  // GroggyEndTime
    {0x3c0, Kind::names, 0, "DelayDeathInAir_Mob"},                     // JumpEffectArray
    {0x3e0, Kind::f32, 200.0f, nullptr},                                // VelocityWhenWallHitBounce
    {0x3e4, Kind::f32, 0.066f, nullptr},                                // VelocityDelayWhenWallHitBounce
    {0x3e8, Kind::string, 0, "/Game/GameDesign/Combat/BehaviorTree/Monster/M_LesserLurker_AI"}, // BehaviorTreeRes
    {0x3f8, Kind::name, 0, "M_DetectCommon20m360"},                                             // DefaultDetectAIAlias
    {0x400, Kind::name, 0, "M_DetectCommon20m360"},                                             // NarrowDetectAIAlias
    {0x410, Kind::f32, 200.0f, nullptr},                                                        // AIAuditorySenseRadius
    {0x414, Kind::f32, 1.0f, nullptr},   // AIAuditorySenseDecibel
    {0x418, Kind::f32, 5.0f, nullptr},   // AIAuditorySenseDuration
    {0x41c, Kind::u8, 4, nullptr},       // ActorType
    {0x420, Kind::name, 0, "M_LionC"},   // RefAppearance
    {0x428, Kind::i32, 1, nullptr},      // HitDefenseLevel
    {0x42c, Kind::f32, 120.0f, nullptr}, // BackSideHitAngle
    {0x470, Kind::u8, 1, nullptr},       // bDisableCollisionWhenDead
    {0x4ff, Kind::u8, 1, nullptr},       // bApplyDamageWhenPlayerAlive
    {0x500, Kind::u8, 1, nullptr},       // ScanDisplayType
    {0x508, Kind::string, 0, ""},        // Name
    // OverrideCharacterSoundSet
    {0x520, Kind::string, 0,
     "SBCharacterSoundSet'/Game/Sound/SoundAsset/CharacterSoundset/CSS_MON_46_BEHEMOTH.CSS_MON_46_BEHEMOTH'"},
    // M_LionC
    {0x014, Kind::name, 0, "Elite"},     // Rank
    {0x020, Kind::string, 0, "M_LionC"}, // Type
    {0x030, Kind::name, 0, "Monster"},   // Tribe
    {0x060, Kind::names, 0, "Common"},   // LinkSkillRandomActiveStepFlagArray
    {0x070, Kind::name, 0, "Lion"},      // Flag
    {0x078, Kind::i32, 160000, nullptr}, // MaxHP
    {0x07c, Kind::i32, 3300, nullptr},   // MaxShield
    {0x080, Kind::i32, 14, nullptr},     // MaxStamina
    {0x084, Kind::f32, 960.0f, nullptr}, // PhysicAttackPower
    {0x088, Kind::f32, 960.0f, nullptr}, // RangeAttackPower
    {0x08c, Kind::f32, 110.0f, nullptr}, // ShieldAttackPower
    {0x090, Kind::f32, 1.0f, nullptr},   // StaminaAttackPower
    {0x094, Kind::f32, 5.0f, nullptr},   // ShieldBlock
    {0x09c, Kind::f32, 0.1f, nullptr},   // DamageReductionPerShieldBock
    {0x0d0, Kind::i32, 80, nullptr},     // GainTachyGaugeOnDead
    {0x0d4, Kind::i32, 1, nullptr},      // MoveSpeed
    {0x0d8, Kind::f32, 1.0f, nullptr},   // AttackSpeed
    {0x0e0, Kind::f32, 1.2f, nullptr},   // CriticalValueRate
    // EffectAliasWhenZeroStaminaArray
    {0x168, Kind::names, 0, "M_LinkAttackDelay_10|Groggy|SkillCancel|BlockSkill|M_StaminaRecoverReady"},
    {0x1f8, Kind::u8, 5, nullptr},                                      // WeightType
    {0x1fc, Kind::f32, 1.0f, nullptr},                                  // MeshScale
    {0x200, Kind::f32, 190.0f, nullptr},                                // TargetFilterRadius
    {0x204, Kind::f32, 300.0f, nullptr},                                // ProjectileTargetFilterRadius
    {0x208, Kind::f32, 240.0f, nullptr},                                // RuleMoveBlockAreaRadius
    {0x20c, Kind::f32, 800.0f, nullptr},                                // RuleMoveBlockAreaZHeight
    {0x210, Kind::f32, 60.0f, nullptr},                                 // RuleMoveBlockAreaOffsetX
    {0x21c, Kind::f32, 190.0f, nullptr},                                // RuleMoveBlockCheckRadius
    {0x220, Kind::names, 0, "Rank_Elite"},                              // DefaultEffectArray
    {0x270, Kind::name, 0, "MonsterElite"},                             // DifficultyStatGroupAlias
    {0x288, Kind::string, 0, "[{\"Alias\":\"BurstGauge_DeadElite\"}]"}, // AttackerEffectWhenDead
    {0x298, Kind::name, 0, "M_LionC"},                                  // DeadAlias
    {0x2a0, Kind::f32, 1.0f, nullptr},                                  // DespawnTimeAfterDeath
    {0x2a8, Kind::string, 0, "Despawn/M_LionA_Despawn"},                // DespawnShow
    {0x398, Kind::names, 0, "M_LionC_Phase2"},                          // StanceAliasArray
    {0x3a8, Kind::name, 0, "M_LionC_Default"},                          // DefaultStanceAlias
    {0x3b0, Kind::f32, 1.5f, nullptr},                                  // GetupTime
    {0x3bc, Kind::f32, 2.0f, nullptr},                                  // GroggyEndTime
    {0x3c0, Kind::names, 0, "DelayDeathInAir_Mob"},                     // JumpEffectArray
    {0x3e0, Kind::f32, 200.0f, nullptr},                                // VelocityWhenWallHitBounce
    {0x3e4, Kind::f32, 0.066f, nullptr},                                // VelocityDelayWhenWallHitBounce
    {0x3e8, Kind::string, 0, "/Game/GameDesign/Combat/BehaviorTree/Monster/M_Skulling_AI_Test"}, // BehaviorTreeRes
    {0x3f8, Kind::name, 0, "M_DetectCommon20m360"},                                              // DefaultDetectAIAlias
    {0x400, Kind::name, 0, "M_DetectCommon20m360"},                                              // NarrowDetectAIAlias
    {0x410, Kind::f32, 200.0f, nullptr}, // AIAuditorySenseRadius
    {0x414, Kind::f32, 1.0f, nullptr},   // AIAuditorySenseDecibel
    {0x418, Kind::f32, 5.0f, nullptr},   // AIAuditorySenseDuration
    {0x41c, Kind::u8, 4, nullptr},       // ActorType
    {0x420, Kind::name, 0, "M_LionC"},   // RefAppearance
    {0x428, Kind::i32, 1, nullptr},      // HitDefenseLevel
    {0x42c, Kind::f32, 120.0f, nullptr}, // BackSideHitAngle
    {0x470, Kind::u8, 1, nullptr},       // bDisableCollisionWhenDead
    {0x4ff, Kind::u8, 1, nullptr},       // bApplyDamageWhenPlayerAlive
    {0x500, Kind::u8, 1, nullptr},       // ScanDisplayType
    {0x508, Kind::string, 0, ""},        // Name
    // OverrideCharacterSoundSet
    {0x520, Kind::string, 0,
     "SBCharacterSoundSet'/Game/Sound/SoundAsset/CharacterSoundset/CSS_MON_46_BEHEMOTH.CSS_MON_46_BEHEMOTH'"},
    // M_GardenerC_ToxicBeam_Cast1 (SkillActiveStepTable, Gardener)
    {0x018, Kind::f32, 1.86f, nullptr},                   // Duration
    {0x034, Kind::name, 0, "M_GardenerC_ToxicBeam_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x160, Kind::name, 0, "CH_M_NA_01_Gardener/Skill/M_Gardener_ToxicBeam"}, // ShowPath
    {0x1f9, Kind::u8, 1, nullptr},                                            // bLookAtTarget
    {0x1fc, Kind::f32, 0.3f, nullptr},                                        // LookAtTargetRotationTime
    {0x200, Kind::f32, 360.0f, nullptr},                                      // LookAtTargetLeftMaxAngle
    {0x204, Kind::f32, 360.0f, nullptr},                                      // LookAtTargetRightMaxAngle
    // M_GardenerC_ToxicBeam_Hit1 (SkillActiveStepTable, Gardener)
    {0x014, Kind::u8, 1, nullptr},                           // Type
    {0x018, Kind::f32, 0.2f, nullptr},                       // Duration
    {0x020, Kind::f32, 1.0f, nullptr},                       // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                       // SkillShieldAttackDamageRate
    {0x030, Kind::u8, 1, nullptr},                           // AvailableJustAction
    {0x034, Kind::name, 0, "M_GardenerC_ToxicBeam_Finish1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    // UsableNonTargetProjectileAliasArray
    {0x178, Kind::names, 0,
     "M_Gardener_SingleShot_Projectile1|M_Gardener_SingleShot_Projectile2|M_Gardener_MultipleShot_Projectile14|"
     "M_Gardener_MultipleShot_Projectile15|M_Gardener_MultipleShot_Projectile16|"
     "M_Gardener_MultipleShot_Projectile17|M_Gardener_MultipleShot_Projectile18|"
     "M_Gardener_MultipleShot_Projectile19"},
    // UsableTargetProjectileAliasArray
    {0x190, Kind::names, 0,
     "M_Gardener_SingleShot_Projectile1|M_Gardener_SingleShot_Projectile2|M_Gardener_MultipleShot_Projectile14|"
     "M_Gardener_MultipleShot_Projectile15|M_Gardener_MultipleShot_Projectile16|"
     "M_Gardener_MultipleShot_Projectile17|M_Gardener_MultipleShot_Projectile18|"
     "M_Gardener_MultipleShot_Projectile19"},
    {0x272, Kind::u8, 1, nullptr}, // bIgnoreHitStop
    // M_GardenerC_ToxicBeam_Finish1 (SkillActiveStepTable, Gardener)
    {0x018, Kind::f32, 3.34f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    // M_GardenerC_SingleShot (SkillTable, Gardener)
    {0x070, Kind::i32, 3, nullptr},                           // HitLevel
    {0x074, Kind::u8, 5, nullptr},                            // AttributeType
    {0x075, Kind::u8, 1, nullptr},                            // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                    // AISkillFlag
    {0x0b4, Kind::name, 0, "M_Gardener_SingleShot_1_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_Gardener_SingleShot_4_Cast1"},  // FirstSkillActiveAlias
    {0x140, Kind::f32, 2.5f, nullptr},                        // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                        // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                            // Cancelable
    {0x172, Kind::u8, 1, nullptr},                            // bSwitchBattleMode
    {0x2c8, Kind::u8, 1, nullptr},                            // bApplyOffScreenIndicator
    // M_GardenerC_MultipleShot (SkillTable, Gardener)
    {0x070, Kind::i32, 3, nullptr},                             // HitLevel
    {0x074, Kind::u8, 5, nullptr},                              // AttributeType
    {0x075, Kind::u8, 1, nullptr},                              // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                      // AISkillFlag
    {0x0b4, Kind::name, 0, "M_Gardener_MultipleShot_1_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_Gardener_MultipleShot_1_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 10.0f, nullptr},                         // CoolTime
    {0x140, Kind::f32, 2.5f, nullptr},                          // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                          // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                              // Cancelable
    {0x172, Kind::u8, 1, nullptr},                              // bSwitchBattleMode
    {0x2c8, Kind::u8, 1, nullptr},                              // bApplyOffScreenIndicator
    // M_GardenerC_ToxicBeam (SkillTable, Gardener)
    {0x070, Kind::i32, 3, nullptr},                           // HitLevel
    {0x074, Kind::u8, 5, nullptr},                            // AttributeType
    {0x075, Kind::u8, 1, nullptr},                            // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                    // AISkillFlag
    {0x0b4, Kind::name, 0, "M_Gardener_SingleShot_1_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_GardenerC_ToxicBeam_Cast1"},    // FirstSkillActiveAlias
    {0x124, Kind::f32, 15.0f, nullptr},                       // CoolTime
    {0x140, Kind::f32, 2.5f, nullptr},                        // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                        // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                            // Cancelable
    {0x172, Kind::u8, 1, nullptr},                            // bSwitchBattleMode
    {0x2c8, Kind::u8, 1, nullptr},                            // bApplyOffScreenIndicator
    // M_GardenerC_SingleShot (SkillCommandTable, Gardener)
    {0x018, Kind::name, 0, "M_GardenerC_SingleShot"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                    // bJumping
    {0x04f, Kind::u8, 1, nullptr},                    // bFly
    {0x053, Kind::u8, 1, nullptr},                    // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                 // AICommandActivationRate
    // M_GardenerC_MultipleShot (SkillCommandTable, Gardener)
    {0x018, Kind::name, 0, "M_GardenerC_MultipleShot"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                      // bJumping
    {0x04f, Kind::u8, 1, nullptr},                      // bFly
    {0x053, Kind::u8, 1, nullptr},                      // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                   // AICommandActivationRate
    // M_GardenerC_ToxicBeam (SkillCommandTable, Gardener)
    {0x018, Kind::name, 0, "M_GardenerC_ToxicBeam"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                   // bJumping
    {0x04f, Kind::u8, 1, nullptr},                   // bFly
    {0x053, Kind::u8, 1, nullptr},                   // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                // AICommandActivationRate
    // M_GardenerC_Default (CharacterStanceTable, Gardener)
    {0x01a, Kind::u8, 1, nullptr}, // bDetectCloakingTarget
    {0x08d, Kind::u8, 1, nullptr}, // bInfiniteStance
    {0x090, Kind::names, 0, "M_GardenerC_SingleShot|M_GardenerC_MultipleShot|M_GardenerC_ToxicBeam"}, // CommandArray
    {0x0a8, Kind::f32, 0.0f, nullptr},                                                                // WalkSpeed
    {0x0ac, Kind::f32, 0.0f, nullptr},                                                                // RunSpeed
    {0x0b0, Kind::f32, 0.0f, nullptr},                                                                // LockOnRunSpeed
    {0x0b4, Kind::f32, 0.0f, nullptr},                                                                // LockOnWalkSpeed
    {0x0bc, Kind::f32, 100.0f, nullptr},           // RotateAnglePerSecond
    {0x150, Kind::name, 0, "M_Gardener_Peaceful"}, // AnimSet_Peaceful_UpperBody
    {0x158, Kind::name, 0, "M_Gardener_Peaceful"}, // AnimSet_Peaceful_LowerBody
    {0x160, Kind::name, 0, "M_Gardener_Battle"},   // AnimSet_Battle_UpperBody
    {0x168, Kind::name, 0, "M_Gardener_Battle"},   // AnimSet_Battle_LowerBody
    {0x170, Kind::name, 0, "Groggy"},              // AnimSet_Groggy_UpperBody
    {0x178, Kind::name, 0, "Groggy"},              // AnimSet_Groggy_LowerBody
    {0x180, Kind::name, 0, "Down"},                // AnimSet_Down_UpperBody
    {0x188, Kind::name, 0, "Down"},                // AnimSet_Down_LowerBody
    {0x190, Kind::name, 0, "Dead"},                // AnimSet_Dead_UpperBody
    {0x198, Kind::name, 0, "Dead"},                // AnimSet_Dead_LowerBody
    {0x1a0, Kind::name, 0, "Airborne"},            // AnimSet_Airborne_UpperBody
    {0x1a8, Kind::name, 0, "Airborne"},            // AnimSet_Airborne_LowerBody
    // M_Gardener_Skulling (CharacterTable, Gardener)
    {0x014, Kind::name, 0, "Elite"},        // Rank
    {0x020, Kind::string, 0, "M_Gardener"}, // Type
    {0x030, Kind::name, 0, "Monster"},      // Tribe
    {0x050, Kind::names, 0, "Monster"},     // Tags
    {0x060, Kind::names, 0, ""},            // LinkSkillRandomActiveStepFlagArray
    {0x070, Kind::name, 0, "Gardener"},     // Flag
    {0x078, Kind::i32, 37840, nullptr},     // MaxHP
    {0x07c, Kind::i32, 1455, nullptr},      // MaxShield
    {0x084, Kind::f32, 930.0f, nullptr},    // PhysicAttackPower
    {0x088, Kind::f32, 930.0f, nullptr},    // RangeAttackPower
    {0x08c, Kind::f32, 120.0f, nullptr},    // ShieldAttackPower
    {0x090, Kind::f32, 1.0f, nullptr},      // StaminaAttackPower
    {0x094, Kind::f32, 5.0f, nullptr},      // ShieldBlock
    {0x09c, Kind::f32, 0.1f, nullptr},      // DamageReductionPerShieldBock
    {0x0d0, Kind::i32, 80, nullptr},        // GainTachyGaugeOnDead
    {0x0d4, Kind::i32, 1, nullptr},         // MoveSpeed
    {0x0d8, Kind::f32, 1.0f, nullptr},      // AttackSpeed
    {0x0e0, Kind::f32, 1.2f, nullptr},      // CriticalValueRate
    {0x148, Kind::names, 0, ""},            // EffectAliasWhenZeroHPArray
    {0x168, Kind::names, 0, "Groggy|SkillCancel|BlockSkill|M_StaminaRecoverReady"}, // EffectAliasWhenZeroStaminaArray
    {0x1f8, Kind::u8, 6, nullptr},                                                  // WeightType
    {0x1fc, Kind::f32, 1.0f, nullptr},                                              // MeshScale
    {0x200, Kind::f32, 291.0f, nullptr},                                            // TargetFilterRadius
    {0x204, Kind::f32, 300.0f, nullptr},                                            // ProjectileTargetFilterRadius
    {0x208, Kind::f32, 341.0f, nullptr},                                            // RuleMoveBlockAreaRadius
    {0x20c, Kind::f32, 1700.0f, nullptr},                                           // RuleMoveBlockAreaZHeight
    {0x21c, Kind::f32, 291.0f, nullptr},                                            // RuleMoveBlockCheckRadius
    // DefaultEffectArray
    {0x220, Kind::names, 0,
     "Rank_Elite|M_Common_FixedLocation|BlockRuleMove_Infinite|M_Common_ImmuneAbnormal|ShowTag_NoHitAni_Infinite|"
     "ShowTag_AdditiveNoPlay_Infinite|DisableMonsterWarp|M_Common_BackHitImmune"},
    {0x270, Kind::name, 0, "MonsterElite"},                             // DifficultyStatGroupAlias
    {0x288, Kind::string, 0, "[{\"Alias\":\"BurstGauge_DeadElite\"}]"}, // AttackerEffectWhenDead
    {0x298, Kind::name, 0, "M_Gardener"},                               // DeadAlias
    {0x2a0, Kind::f32, 1.0f, nullptr},                                  // DespawnTimeAfterDeath
    {0x2a8, Kind::string, 0, "Despawn/M_Cocoon_Despawn"},               // DespawnShow
    {0x2f8, Kind::name, 0, "None"},                                     // CollisionGroupName1
    {0x300, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge1
    {0x308, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero1
    {0x318, Kind::name, 0, "None"},                                     // CollisionGroupName2
    {0x320, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge2
    {0x328, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero2
    {0x338, Kind::name, 0, "None"},                                     // CollisionGroupName3
    {0x340, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge3
    {0x348, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero3
    {0x3a8, Kind::name, 0, "M_GardenerC_Default"},                      // DefaultStanceAlias
    {0x3b0, Kind::f32, 1.5f, nullptr},                                  // GetupTime
    {0x3bc, Kind::f32, 2.0f, nullptr},                                  // GroggyEndTime
    {0x3c0, Kind::names, 0, "DelayDeathInAir_Mob"},                     // JumpEffectArray
    {0x3e0, Kind::f32, 200.0f, nullptr},                                // VelocityWhenWallHitBounce
    {0x3e4, Kind::f32, 0.066f, nullptr},                                // VelocityDelayWhenWallHitBounce
    {0x3e8, Kind::string, 0, "/Game/GameDesign/Combat/BehaviorTree/Monster/M_Skulling_AI_Test"}, // BehaviorTreeRes
    {0x3f8, Kind::name, 0, "M_Gardener"},                                                        // DefaultDetectAIAlias
    {0x400, Kind::name, 0, "M_Gardener"},                                                        // NarrowDetectAIAlias
    {0x410, Kind::f32, 150.0f, nullptr},                   // AIAuditorySenseRadius
    {0x414, Kind::f32, 1.0f, nullptr},                     // AIAuditorySenseDecibel
    {0x418, Kind::f32, 5.0f, nullptr},                     // AIAuditorySenseDuration
    {0x41c, Kind::u8, 4, nullptr},                         // ActorType
    {0x420, Kind::name, 0, "M_Gardener"},                  // RefAppearance
    {0x428, Kind::i32, 1, nullptr},                        // HitDefenseLevel
    {0x42c, Kind::f32, 120.0f, nullptr},                   // BackSideHitAngle
    {0x470, Kind::u8, 1, nullptr},                         // bDisableCollisionWhenDead
    {0x4ff, Kind::u8, 1, nullptr},                         // bApplyDamageWhenPlayerAlive
    {0x500, Kind::u8, 1, nullptr},                         // ScanDisplayType
    {0x508, Kind::string, 0, "Char_M_Gardener_AlbumName"}, // Name
    // OverrideCharacterSoundSet
    {0x520, Kind::string, 0,
     "SBCharacterSoundSet'/Game/Sound/SoundAsset/CharacterSoundset/CSS_MON_36_MaelStrom.CSS_MON_36_MaelStrom'"},
    // M_Gardener_Half (CharacterTable, Gardener)
    {0x014, Kind::name, 0, "Elite"},        // Rank
    {0x020, Kind::string, 0, "M_Gardener"}, // Type
    {0x030, Kind::name, 0, "Monster"},      // Tribe
    {0x050, Kind::names, 0, "Monster"},     // Tags
    {0x060, Kind::names, 0, ""},            // LinkSkillRandomActiveStepFlagArray
    {0x070, Kind::name, 0, "Gardener"},     // Flag
    {0x078, Kind::i32, 37840, nullptr},     // MaxHP
    {0x07c, Kind::i32, 1455, nullptr},      // MaxShield
    {0x084, Kind::f32, 930.0f, nullptr},    // PhysicAttackPower
    {0x088, Kind::f32, 930.0f, nullptr},    // RangeAttackPower
    {0x08c, Kind::f32, 120.0f, nullptr},    // ShieldAttackPower
    {0x090, Kind::f32, 1.0f, nullptr},      // StaminaAttackPower
    {0x094, Kind::f32, 5.0f, nullptr},      // ShieldBlock
    {0x09c, Kind::f32, 0.1f, nullptr},      // DamageReductionPerShieldBock
    {0x0d0, Kind::i32, 80, nullptr},        // GainTachyGaugeOnDead
    {0x0d4, Kind::i32, 1, nullptr},         // MoveSpeed
    {0x0d8, Kind::f32, 1.0f, nullptr},      // AttackSpeed
    {0x0e0, Kind::f32, 1.2f, nullptr},      // CriticalValueRate
    {0x148, Kind::names, 0, ""},            // EffectAliasWhenZeroHPArray
    {0x168, Kind::names, 0, "Groggy|SkillCancel|BlockSkill|M_StaminaRecoverReady"}, // EffectAliasWhenZeroStaminaArray
    {0x1f8, Kind::u8, 6, nullptr},                                                  // WeightType
    {0x1fc, Kind::f32, 0.5f, nullptr},                                              // MeshScale
    {0x200, Kind::f32, 291.0f, nullptr},                                            // TargetFilterRadius
    {0x204, Kind::f32, 300.0f, nullptr},                                            // ProjectileTargetFilterRadius
    {0x208, Kind::f32, 341.0f, nullptr},                                            // RuleMoveBlockAreaRadius
    {0x20c, Kind::f32, 1700.0f, nullptr},                                           // RuleMoveBlockAreaZHeight
    {0x21c, Kind::f32, 291.0f, nullptr},                                            // RuleMoveBlockCheckRadius
    // DefaultEffectArray
    {0x220, Kind::names, 0,
     "Rank_Elite|M_Common_FixedLocation|BlockRuleMove_Infinite|M_Common_ImmuneAbnormal|ShowTag_NoHitAni_Infinite|"
     "ShowTag_AdditiveNoPlay_Infinite|DisableMonsterWarp|M_Common_BackHitImmune"},
    {0x270, Kind::name, 0, "MonsterElite"},                             // DifficultyStatGroupAlias
    {0x288, Kind::string, 0, "[{\"Alias\":\"BurstGauge_DeadElite\"}]"}, // AttackerEffectWhenDead
    {0x298, Kind::name, 0, "M_Gardener"},                               // DeadAlias
    {0x2a0, Kind::f32, 1.0f, nullptr},                                  // DespawnTimeAfterDeath
    {0x2a8, Kind::string, 0, "Despawn/M_Cocoon_Despawn"},               // DespawnShow
    {0x2f8, Kind::name, 0, "None"},                                     // CollisionGroupName1
    {0x300, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge1
    {0x308, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero1
    {0x318, Kind::name, 0, "None"},                                     // CollisionGroupName2
    {0x320, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge2
    {0x328, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero2
    {0x338, Kind::name, 0, "None"},                                     // CollisionGroupName3
    {0x340, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge3
    {0x348, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero3
    {0x3a8, Kind::name, 0, "M_GardenerC_Default"},                      // DefaultStanceAlias
    {0x3b0, Kind::f32, 1.5f, nullptr},                                  // GetupTime
    {0x3bc, Kind::f32, 2.0f, nullptr},                                  // GroggyEndTime
    {0x3c0, Kind::names, 0, "DelayDeathInAir_Mob"},                     // JumpEffectArray
    {0x3e0, Kind::f32, 200.0f, nullptr},                                // VelocityWhenWallHitBounce
    {0x3e4, Kind::f32, 0.066f, nullptr},                                // VelocityDelayWhenWallHitBounce
    {0x3e8, Kind::string, 0, "/Game/GameDesign/Combat/BehaviorTree/Monster/M_Tentacle_AI"}, // BehaviorTreeRes
    {0x3f8, Kind::name, 0, "M_Gardener"},                                                   // DefaultDetectAIAlias
    {0x400, Kind::name, 0, "M_Gardener"},                                                   // NarrowDetectAIAlias
    {0x410, Kind::f32, 150.0f, nullptr},                                                    // AIAuditorySenseRadius
    {0x414, Kind::f32, 1.0f, nullptr},                                                      // AIAuditorySenseDecibel
    {0x418, Kind::f32, 5.0f, nullptr},                                                      // AIAuditorySenseDuration
    {0x41c, Kind::u8, 4, nullptr},                                                          // ActorType
    {0x420, Kind::name, 0, "M_Gardener"},                                                   // RefAppearance
    {0x428, Kind::i32, 1, nullptr},                                                         // HitDefenseLevel
    {0x42c, Kind::f32, 120.0f, nullptr},                                                    // BackSideHitAngle
    {0x470, Kind::u8, 1, nullptr},                                                          // bDisableCollisionWhenDead
    {0x4ff, Kind::u8, 1, nullptr},                         // bApplyDamageWhenPlayerAlive
    {0x500, Kind::u8, 1, nullptr},                         // ScanDisplayType
    {0x508, Kind::string, 0, "Char_M_Gardener_AlbumName"}, // Name
    // OverrideCharacterSoundSet
    {0x520, Kind::string, 0,
     "SBCharacterSoundSet'/Game/Sound/SoundAsset/CharacterSoundset/CSS_MON_36_MaelStrom.CSS_MON_36_MaelStrom'"},
    // M_Gardener (CharacterTable, Gardener)
    {0x014, Kind::name, 0, "Elite"},        // Rank
    {0x020, Kind::string, 0, "M_Gardener"}, // Type
    {0x030, Kind::name, 0, "Monster"},      // Tribe
    {0x050, Kind::names, 0, "Monster"},     // Tags
    {0x060, Kind::names, 0, ""},            // LinkSkillRandomActiveStepFlagArray
    {0x070, Kind::name, 0, "Gardener"},     // Flag
    {0x078, Kind::i32, 37840, nullptr},     // MaxHP
    {0x07c, Kind::i32, 1455, nullptr},      // MaxShield
    {0x084, Kind::f32, 930.0f, nullptr},    // PhysicAttackPower
    {0x088, Kind::f32, 930.0f, nullptr},    // RangeAttackPower
    {0x08c, Kind::f32, 120.0f, nullptr},    // ShieldAttackPower
    {0x090, Kind::f32, 1.0f, nullptr},      // StaminaAttackPower
    {0x094, Kind::f32, 5.0f, nullptr},      // ShieldBlock
    {0x09c, Kind::f32, 0.1f, nullptr},      // DamageReductionPerShieldBock
    {0x0d0, Kind::i32, 80, nullptr},        // GainTachyGaugeOnDead
    {0x0d4, Kind::i32, 1, nullptr},         // MoveSpeed
    {0x0d8, Kind::f32, 1.0f, nullptr},      // AttackSpeed
    {0x0e0, Kind::f32, 1.2f, nullptr},      // CriticalValueRate
    {0x148, Kind::names, 0, ""},            // EffectAliasWhenZeroHPArray
    {0x168, Kind::names, 0, "Groggy|SkillCancel|BlockSkill|M_StaminaRecoverReady"}, // EffectAliasWhenZeroStaminaArray
    {0x1f8, Kind::u8, 6, nullptr},                                                  // WeightType
    {0x1fc, Kind::f32, 1.0f, nullptr},                                              // MeshScale
    {0x200, Kind::f32, 291.0f, nullptr},                                            // TargetFilterRadius
    {0x204, Kind::f32, 300.0f, nullptr},                                            // ProjectileTargetFilterRadius
    {0x208, Kind::f32, 341.0f, nullptr},                                            // RuleMoveBlockAreaRadius
    {0x20c, Kind::f32, 1700.0f, nullptr},                                           // RuleMoveBlockAreaZHeight
    {0x21c, Kind::f32, 291.0f, nullptr},                                            // RuleMoveBlockCheckRadius
    // DefaultEffectArray
    {0x220, Kind::names, 0,
     "Rank_Elite|M_Common_FixedLocation|BlockRuleMove_Infinite|M_Common_ImmuneAbnormal|ShowTag_NoHitAni_Infinite|"
     "ShowTag_AdditiveNoPlay_Infinite|DisableMonsterWarp|M_Common_BackHitImmune"},
    {0x270, Kind::name, 0, "MonsterElite"},                             // DifficultyStatGroupAlias
    {0x288, Kind::string, 0, "[{\"Alias\":\"BurstGauge_DeadElite\"}]"}, // AttackerEffectWhenDead
    {0x298, Kind::name, 0, "M_Gardener"},                               // DeadAlias
    {0x2a0, Kind::f32, 1.0f, nullptr},                                  // DespawnTimeAfterDeath
    {0x2a8, Kind::string, 0, "Despawn/M_Cocoon_Despawn"},               // DespawnShow
    {0x2f8, Kind::name, 0, "None"},                                     // CollisionGroupName1
    {0x300, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge1
    {0x308, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero1
    {0x318, Kind::name, 0, "None"},                                     // CollisionGroupName2
    {0x320, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge2
    {0x328, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero2
    {0x338, Kind::name, 0, "None"},                                     // CollisionGroupName3
    {0x340, Kind::f32, 0.0f, nullptr},                                  // CollisionGroupGauge3
    {0x348, Kind::names, 0, ""},                                        // EffectAliasArrayWhenCollisionGroupGaugeZero3
    {0x3a8, Kind::name, 0, "M_GardenerC_Default"},                      // DefaultStanceAlias
    {0x3b0, Kind::f32, 1.5f, nullptr},                                  // GetupTime
    {0x3bc, Kind::f32, 2.0f, nullptr},                                  // GroggyEndTime
    {0x3c0, Kind::names, 0, "DelayDeathInAir_Mob"},                     // JumpEffectArray
    {0x3e0, Kind::f32, 200.0f, nullptr},                                // VelocityWhenWallHitBounce
    {0x3e4, Kind::f32, 0.066f, nullptr},                                // VelocityDelayWhenWallHitBounce
    {0x3e8, Kind::string, 0, "/Game/GameDesign/Combat/BehaviorTree/Monster/M_Tentacle_AI"}, // BehaviorTreeRes
    {0x3f8, Kind::name, 0, "M_Gardener"},                                                   // DefaultDetectAIAlias
    {0x400, Kind::name, 0, "M_Gardener"},                                                   // NarrowDetectAIAlias
    {0x410, Kind::f32, 150.0f, nullptr},                                                    // AIAuditorySenseRadius
    {0x414, Kind::f32, 1.0f, nullptr},                                                      // AIAuditorySenseDecibel
    {0x418, Kind::f32, 5.0f, nullptr},                                                      // AIAuditorySenseDuration
    {0x41c, Kind::u8, 4, nullptr},                                                          // ActorType
    {0x420, Kind::name, 0, "M_Gardener"},                                                   // RefAppearance
    {0x428, Kind::i32, 1, nullptr},                                                         // HitDefenseLevel
    {0x42c, Kind::f32, 120.0f, nullptr},                                                    // BackSideHitAngle
    {0x470, Kind::u8, 1, nullptr},                                                          // bDisableCollisionWhenDead
    {0x4ff, Kind::u8, 1, nullptr},                         // bApplyDamageWhenPlayerAlive
    {0x500, Kind::u8, 1, nullptr},                         // ScanDisplayType
    {0x508, Kind::string, 0, "Char_M_Gardener_AlbumName"}, // Name
    // OverrideCharacterSoundSet
    {0x520, Kind::string, 0,
     "SBCharacterSoundSet'/Game/Sound/SoundAsset/CharacterSoundset/CSS_MON_36_MaelStrom.CSS_MON_36_MaelStrom'"},
    // M_TendrilC_Result_Light
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactSlash_Light\"}]"},
    {0x038, Kind::string, 0, "[{\"Alias\":\"HitStun\", \"Time\":0.5}]"}, // HitLevelResultTargetCommonEffect
    {0x058, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack"},        // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_050_100"},                          // HitLevelResultTargetCommonMoveAlias
    {0x0b8, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetDownShowPath
    {0x118, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetGroggyShowPath
    {0x178, Kind::string, 0, "Hit/Result_Hit_Airborne"},                 // ResultTargetAirborneShowPath
    // HitLevelResultTargetAirEffect
    {0x1b8, Kind::string, 0, "[{\"Alias\":\"HitAirBackward_Eve\"}, {\"Alias\":\"HitAirForward_Eve\"}]"},
    {0x238, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetSwimmingShowPath
    {0x250, Kind::name, 0, "Hit_Back_0"},                                // HitLevelResultTargetSwimmingMoveAlias
    // ResultTargetEventMovingEffect
    {0x2c8, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactSlash_Light\"}]"},
    {0x2d8, Kind::string, 0, "[{\"Alias\":\"HitStun\", \"Time\":0.5}]"}, // HitLevelResultTargetEventMovingEffect
    {0x2f8, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetEventMovingShowPath
    {0x318, Kind::name, 0, "None"},                                      // FileSuffix
    // M_TendrilC_Result_Strong
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactSlash_Strong\"}]"},
    {0x038, Kind::string, 0, "[{\"Alias\":\"HitStun\", \"Time\":0.8}]"}, // HitLevelResultTargetCommonEffect
    {0x058, Kind::string, 0, "Hit/Result_Hit_Stand_StrongAttack"},       // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_080_300"},                          // HitLevelResultTargetCommonMoveAlias
    {0x0b8, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetDownShowPath
    {0x118, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetGroggyShowPath
    {0x178, Kind::string, 0, "Hit/Result_Hit_Airborne"},                 // ResultTargetAirborneShowPath
    // HitLevelResultTargetAirEffect
    {0x1b8, Kind::string, 0, "[{\"Alias\":\"HitAirBackward_Eve\"}, {\"Alias\":\"HitAirForward_Eve\"}]"},
    {0x238, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetSwimmingShowPath
    {0x250, Kind::name, 0, "Hit_Back_0"},                                // HitLevelResultTargetSwimmingMoveAlias
    // ResultTargetEventMovingEffect
    {0x2c8, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactSlash_Strong\"}]"},
    {0x2d8, Kind::string, 0, "[{\"Alias\":\"HitStun\", \"Time\":0.8}]"},  // HitLevelResultTargetEventMovingEffect
    {0x2f8, Kind::string, 0, "Hit/Result_Hit_Stand_StrongAttack_NoAnim"}, // ResultTargetEventMovingShowPath
    {0x318, Kind::name, 0, "None"},                                       // FileSuffix
    // M_TendrilC_Result_KnockDown
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactBlunt_Strong\"}]"},
    // HitLevelResultTargetCommonEffect
    {0x038, Kind::string, 0,
     "[{\"Alias\":\"HitStun\", \"Time\":1.5}, {\"Alias\":\"KnockDownForward_Eve\"}, "
     "{\"Alias\":\"KnockDownBackward_Eve\"}]"},
    {0x058, Kind::string, 0, "Hit/Result_Hit_Stand_StrongAttack"},       // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_080_300"},                          // HitLevelResultTargetCommonMoveAlias
    {0x0b8, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetDownShowPath
    {0x118, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetGroggyShowPath
    {0x178, Kind::string, 0, "Hit/Result_Hit_Airborne"},                 // ResultTargetAirborneShowPath
    // HitLevelResultTargetAirEffect
    {0x1b8, Kind::string, 0, "[{\"Alias\":\"HitAirBackward_Eve\"}, {\"Alias\":\"HitAirForward_Eve\"}]"},
    {0x238, Kind::string, 0, "Hit/Result_Hit_Stand_LightAttack_NoAnim"}, // ResultTargetSwimmingShowPath
    {0x250, Kind::name, 0, "Hit_Back_0"},                                // HitLevelResultTargetSwimmingMoveAlias
    // ResultTargetEventMovingEffect
    {0x2c8, Kind::string, 0, "[{\"Alias\":\"SkillDamage_Melee\"}, {\"Alias\":\"HitImpactBlunt_Strong\"}]"},
    // HitLevelResultTargetEventMovingEffect
    {0x2d8, Kind::string, 0,
     "[{\"Alias\":\"HitStun\", \"Time\":1.5}, {\"Alias\":\"KnockDownForward_Eve\"}, "
     "{\"Alias\":\"KnockDownBackward_Eve\"}]"},
    {0x2f8, Kind::string, 0, "Hit/Result_Hit_Stand_StrongAttack_NoAnim"}, // ResultTargetEventMovingShowPath
    {0x318, Kind::name, 0, "None"},                                       // FileSuffix
    // M_TendrilC_Result_Guard
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0, "[{\"Alias\":\"SkillDamageWhenGuard_Melee\"}, {\"Alias\":\"BlockAction\", \"Time\":0.3}]"},
    {0x058, Kind::string, 0, "Result/Result_Guard_Back"}, // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_040_100"},           // HitLevelResultTargetCommonMoveAlias
    {0x318, Kind::name, 0, "None"},                       // FileSuffix
    // M_TendrilC_Result_Parry
    {0x058, Kind::string, 0, "Result/Result_Parry_Back"}, // ResultTargetCommonShowPath
    {0x070, Kind::name, 0, "Hit_Back_020_150"},           // HitLevelResultTargetCommonMoveAlias
    {0x318, Kind::name, 0, "None"},                       // FileSuffix
    // M_TendrilC_SwingLeft_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 420.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 150.0f, nullptr}, // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_SwingLeft_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 260.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_SwingRight_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 410.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 160.0f, nullptr}, // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_SwingRight_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 260.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_WhipLeft_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 470.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 160.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, -70.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_WhipLeft_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 280.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_WhipRight_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 510.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 130.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, 50.0f, nullptr},  // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_WhipRight_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 300.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_DiagonalLeft_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 400.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 140.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, -20.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_DiagonalLeft_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 240.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_DiagonalRight_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 400.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 190.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, 20.0f, nullptr},  // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_DiagonalRight_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 250.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Chop_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 660.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 60.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Chop_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 400.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Spin_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 400.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 340.0f, nullptr}, // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Spin_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 240.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 360.0f, nullptr}, // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Rush_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 480.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 160.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, -20.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Rush_HitArea2
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 530.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 200.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, 30.0f, nullptr},  // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Rush_HitArea3
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 580.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 60.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Rush_HitArea4
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 750.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 60.0f, nullptr},  // TargetCheckValue1
    {0x044, Kind::f32, -10.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Rush_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 270.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Whip_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 560.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 60.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Whip_HitArea2
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 530.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 210.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, -10.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Whip_HitArea3
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 580.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 200.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, -10.0f, nullptr}, // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Whip_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 340.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Trace_HitArea1
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 420.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 260.0f, nullptr}, // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Trace_HitArea2
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 430.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 200.0f, nullptr}, // TargetCheckValue1
    {0x044, Kind::f32, 60.0f, nullptr},  // TargetCheckValue2
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Trace_Target
    {0x014, Kind::u8, 5, nullptr},       // TargetType
    {0x015, Kind::u8, 1, nullptr},       // bMultipleTargets
    {0x024, Kind::f32, 250.0f, nullptr}, // FarDistance
    {0x028, Kind::u8, 1, nullptr},       // SortType
    {0x03c, Kind::u8, 4, nullptr},       // TargetCheckShape
    {0x040, Kind::f32, 90.0f, nullptr},  // TargetCheckValue1
    {0x048, Kind::f32, 200.0f, nullptr}, // TargetCheckValue3
    {0x0b0, Kind::name, 0, "None"},      // FileSuffix
    // M_TendrilC_Turn
    {0x014, Kind::i32, 100, nullptr},  // Priority
    {0x03a, Kind::u8, 0, nullptr},     // MoveType
    {0x060, Kind::u8, 2, nullptr},     // PositionDirectionAxis
    {0x070, Kind::f32, 0.0f, nullptr}, // StartDelayTime
    {0x084, Kind::f32, 0.0f, nullptr}, // MoveEndTime
    {0x088, Kind::f32, 0.3f, nullptr}, // Time
    {0x094, Kind::f32, 0.0f, nullptr}, // ForwardValue
    {0x098, Kind::f32, 0.0f, nullptr}, // RightValue
    {0x0b8, Kind::f32, 0.3f, nullptr}, // RotationEndTime
    {0x0bc, Kind::u8, 1, nullptr},     // RotationType
    {0x0cc, Kind::u8, 1, nullptr},     // bIndependentRotation
    {0x0f2, Kind::u8, 1, nullptr},     // bStopWhenClif
    {0x0f5, Kind::u8, 0, nullptr},     // bCheckRuleMoveBlockArea
    {0x0f6, Kind::u8, 0, nullptr},     // RuleMoveBlockAreaApplyToTarget
    {0x106, Kind::u8, 1, nullptr},     // bZeroVelocityWhenEnd
    {0x128, Kind::name, 0, "None"},    // FileSuffix
    // M_TendrilC_SwingLeft_Cast1
    {0x018, Kind::f32, 0.8667f, nullptr},                // Duration
    {0x034, Kind::name, 0, "M_TendrilC_SwingLeft_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                      // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                         // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_SwingLeft"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                      // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                     // FileSuffix
    // M_TendrilC_SwingLeft_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.4667f, nullptr},                       // Duration
    {0x01c, Kind::u8, 1, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_SwingLeft_Finish1"},     // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                             // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                           // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                           // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                           // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_SwingLeft_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                           // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                           // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                          // FileSuffix
    // M_TendrilC_SwingLeft_Finish1
    {0x018, Kind::f32, 1.2f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_SwingLeft
    {0x070, Kind::i32, 1, nullptr},                        // HitLevel
    {0x074, Kind::u8, 5, nullptr},                         // AttributeType
    {0x075, Kind::u8, 1, nullptr},                         // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                 // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                         // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_SwingLeft_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_SwingLeft_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 5.0f, nullptr},                     // CoolTime
    {0x140, Kind::f32, 1.0f, nullptr},                     // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                     // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                         // Cancelable
    {0x172, Kind::u8, 1, nullptr},                         // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                        // FileSuffix
    // M_TendrilC_SwingRight_Cast1
    {0x018, Kind::f32, 0.8f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_TendrilC_SwingRight_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                       // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                          // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_SwingRight"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                       // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                      // FileSuffix
    // M_TendrilC_SwingRight_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.4667f, nullptr},                       // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_SwingRight_Finish1"},    // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                              // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                            // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                            // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                            // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_SwingRight_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                            // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                            // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                           // FileSuffix
    // M_TendrilC_SwingRight_Finish1
    {0x018, Kind::f32, 1.0333f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_SwingRight
    {0x070, Kind::i32, 1, nullptr},                         // HitLevel
    {0x074, Kind::u8, 5, nullptr},                          // AttributeType
    {0x075, Kind::u8, 1, nullptr},                          // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                  // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                          // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_SwingRight_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_SwingRight_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 5.0f, nullptr},                      // CoolTime
    {0x140, Kind::f32, 1.0f, nullptr},                      // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                      // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                          // Cancelable
    {0x172, Kind::u8, 1, nullptr},                          // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                         // FileSuffix
    // M_TendrilC_WhipLeft_Cast1
    {0x018, Kind::f32, 0.3333f, nullptr},               // Duration
    {0x034, Kind::name, 0, "M_TendrilC_WhipLeft_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                     // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                        // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_WhipLeft"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                     // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                    // FileSuffix
    // M_TendrilC_WhipLeft_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.3333f, nullptr},                       // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_WhipLeft_Finish1"},      // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                            // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                          // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                          // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                          // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_WhipLeft_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                          // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                          // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                         // FileSuffix
    // M_TendrilC_WhipLeft_Finish1
    {0x018, Kind::f32, 1.3333f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_WhipLeft
    {0x070, Kind::i32, 1, nullptr},                       // HitLevel
    {0x074, Kind::u8, 5, nullptr},                        // AttributeType
    {0x075, Kind::u8, 1, nullptr},                        // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                        // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_WhipLeft_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_WhipLeft_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 4.0f, nullptr},                    // CoolTime
    {0x140, Kind::f32, 1.0f, nullptr},                    // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                    // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                        // Cancelable
    {0x172, Kind::u8, 1, nullptr},                        // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                       // FileSuffix
    // M_TendrilC_WhipRight_Cast1
    {0x018, Kind::f32, 0.4f, nullptr},                   // Duration
    {0x034, Kind::name, 0, "M_TendrilC_WhipRight_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                      // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                         // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_WhipRight"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                      // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                     // FileSuffix
    // M_TendrilC_WhipRight_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.3f, nullptr},                          // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_WhipRight_Finish1"},     // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                             // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                           // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                           // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                           // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_WhipRight_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                           // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                           // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                          // FileSuffix
    // M_TendrilC_WhipRight_Finish1
    {0x018, Kind::f32, 1.3f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_WhipRight
    {0x070, Kind::i32, 1, nullptr},                        // HitLevel
    {0x074, Kind::u8, 5, nullptr},                         // AttributeType
    {0x075, Kind::u8, 1, nullptr},                         // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                 // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                         // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_WhipRight_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_WhipRight_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 4.0f, nullptr},                     // CoolTime
    {0x140, Kind::f32, 1.0f, nullptr},                     // AttackDamageRate
    {0x144, Kind::f32, 1.0f, nullptr},                     // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                         // Cancelable
    {0x172, Kind::u8, 1, nullptr},                         // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                        // FileSuffix
    // M_TendrilC_DiagonalLeft_Cast1
    {0x018, Kind::f32, 1.0f, nullptr},                      // Duration
    {0x034, Kind::name, 0, "M_TendrilC_DiagonalLeft_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                         // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                            // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_DiagonalLeft"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                         // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                        // FileSuffix
    // M_TendrilC_DiagonalLeft_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.3667f, nullptr},                       // Duration
    {0x01c, Kind::u8, 1, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_DiagonalLeft_Finish1"},  // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                                // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                              // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                              // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                              // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_DiagonalLeft_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                              // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                              // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                             // FileSuffix
    // M_TendrilC_DiagonalLeft_Finish1
    {0x018, Kind::f32, 1.3333f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_DiagonalLeft
    {0x070, Kind::i32, 1, nullptr},                           // HitLevel
    {0x074, Kind::u8, 5, nullptr},                            // AttributeType
    {0x075, Kind::u8, 1, nullptr},                            // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                    // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                            // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_DiagonalLeft_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_DiagonalLeft_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 8.0f, nullptr},                        // CoolTime
    {0x140, Kind::f32, 1.2f, nullptr},                        // AttackDamageRate
    {0x144, Kind::f32, 1.2f, nullptr},                        // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                            // Cancelable
    {0x172, Kind::u8, 1, nullptr},                            // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                           // FileSuffix
    // M_TendrilC_DiagonalRight_Cast1
    {0x018, Kind::f32, 0.9333f, nullptr},                    // Duration
    {0x034, Kind::name, 0, "M_TendrilC_DiagonalRight_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                          // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                             // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_DiagonalRight"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                          // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                         // FileSuffix
    // M_TendrilC_DiagonalRight_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.4f, nullptr},                          // Duration
    {0x01c, Kind::u8, 2, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_DiagonalRight_Finish1"}, // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},          // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                                 // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                               // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                               // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                               // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_DiagonalRight_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                               // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                               // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                              // FileSuffix
    // M_TendrilC_DiagonalRight_Finish1
    {0x018, Kind::f32, 1.3667f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_DiagonalRight
    {0x070, Kind::i32, 1, nullptr},                            // HitLevel
    {0x074, Kind::u8, 5, nullptr},                             // AttributeType
    {0x075, Kind::u8, 1, nullptr},                             // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                     // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                             // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_DiagonalRight_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_DiagonalRight_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 8.0f, nullptr},                         // CoolTime
    {0x140, Kind::f32, 1.2f, nullptr},                         // AttackDamageRate
    {0x144, Kind::f32, 1.2f, nullptr},                         // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                             // Cancelable
    {0x172, Kind::u8, 1, nullptr},                             // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                            // FileSuffix
    // M_TendrilC_Chop_Cast1
    {0x018, Kind::f32, 1.9667f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Chop_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                 // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                    // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_Chop"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                 // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                // FileSuffix
    // M_TendrilC_Chop_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.3f, nullptr},                          // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Chop_Finish1"},          // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Strong"},         // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Chop_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Chop_Finish1
    {0x018, Kind::f32, 2.0667f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Chop
    {0x070, Kind::i32, 1, nullptr},                   // HitLevel
    {0x074, Kind::u8, 5, nullptr},                    // AttributeType
    {0x075, Kind::u8, 1, nullptr},                    // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},            // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                    // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_Chop_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_Chop_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 12.0f, nullptr},               // CoolTime
    {0x140, Kind::f32, 1.5f, nullptr},                // AttackDamageRate
    {0x144, Kind::f32, 1.5f, nullptr},                // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                    // Cancelable
    {0x172, Kind::u8, 1, nullptr},                    // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                   // FileSuffix
    // M_TendrilC_Spin_Cast1
    {0x018, Kind::f32, 1.9667f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Spin_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                 // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                    // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_Spin"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                 // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                // FileSuffix
    // M_TendrilC_Spin_Hit1
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.5667f, nullptr},                       // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 1.0f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 1.0f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Spin_Finish1"},          // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Strong"},         // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Spin_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Spin_Finish1
    {0x018, Kind::f32, 2.8667f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Spin
    {0x070, Kind::i32, 1, nullptr},                   // HitLevel
    {0x074, Kind::u8, 5, nullptr},                    // AttributeType
    {0x075, Kind::u8, 1, nullptr},                    // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},            // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                    // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_Spin_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_Spin_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 10.0f, nullptr},               // CoolTime
    {0x140, Kind::f32, 1.3f, nullptr},                // AttackDamageRate
    {0x144, Kind::f32, 1.3f, nullptr},                // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                    // Cancelable
    {0x172, Kind::u8, 1, nullptr},                    // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                   // FileSuffix
    // M_TendrilC_Rush_Cast1
    {0x018, Kind::f32, 0.6667f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Rush_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                 // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                    // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_Rush"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                 // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                // FileSuffix
    // M_TendrilC_Rush_Hit1
    {0x014, Kind::u8, 1, nullptr},                      // Type
    {0x018, Kind::f32, 0.2333f, nullptr},               // Duration
    {0x01c, Kind::u8, 3, nullptr},                      // AttackDirection
    {0x020, Kind::f32, 0.2f, nullptr},                  // SkillAttackDamageRate
    {0x024, Kind::f32, 0.2f, nullptr},                  // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                      // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                      // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                      // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                      // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Rush_Cast2"},    // NextStepAlias
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},  // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},  // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"}, // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},  // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Rush_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Rush_Cast2
    {0x018, Kind::f32, 0.2333f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Rush_Hit2"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Rush_Hit2
    {0x014, Kind::u8, 1, nullptr},                      // Type
    {0x018, Kind::f32, 0.4f, nullptr},                  // Duration
    {0x01c, Kind::u8, 3, nullptr},                      // AttackDirection
    {0x020, Kind::f32, 0.2f, nullptr},                  // SkillAttackDamageRate
    {0x024, Kind::f32, 0.2f, nullptr},                  // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                      // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                      // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                      // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                      // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Rush_Cast3"},    // NextStepAlias
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},  // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},  // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"}, // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},  // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Rush_HitArea2"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Rush_Cast3
    {0x018, Kind::f32, 1.2667f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Rush_Hit3"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Rush_Hit3
    {0x014, Kind::u8, 1, nullptr},                      // Type
    {0x018, Kind::f32, 0.1667f, nullptr},               // Duration
    {0x01c, Kind::u8, 3, nullptr},                      // AttackDirection
    {0x020, Kind::f32, 0.25f, nullptr},                 // SkillAttackDamageRate
    {0x024, Kind::f32, 0.25f, nullptr},                 // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                      // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                      // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                      // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                      // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Rush_Cast4"},    // NextStepAlias
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Strong"}, // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},  // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"}, // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},  // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Rush_HitArea3"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Rush_Cast4
    {0x018, Kind::f32, 0.1333f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Rush_Hit4"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Rush_Hit4
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.3f, nullptr},                          // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 0.35f, nullptr},                         // SkillAttackDamageRate
    {0x024, Kind::f32, 0.35f, nullptr},                         // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Rush_Finish1"},          // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_KnockDown"},      // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Rush_HitArea4"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Rush_Finish1
    {0x018, Kind::f32, 1.0667f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Rush
    {0x070, Kind::i32, 1, nullptr},                   // HitLevel
    {0x074, Kind::u8, 5, nullptr},                    // AttributeType
    {0x075, Kind::u8, 1, nullptr},                    // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},            // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                    // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_Rush_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_Rush_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 20.0f, nullptr},               // CoolTime
    {0x140, Kind::f32, 2.5f, nullptr},                // AttackDamageRate
    {0x144, Kind::f32, 2.5f, nullptr},                // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                    // Cancelable
    {0x172, Kind::u8, 1, nullptr},                    // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                   // FileSuffix
    // M_TendrilC_Whip_Cast1
    {0x018, Kind::f32, 0.8667f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Whip_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                 // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                    // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_Whip"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                 // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                // FileSuffix
    // M_TendrilC_Whip_Hit1
    {0x014, Kind::u8, 1, nullptr},                      // Type
    {0x018, Kind::f32, 0.1f, nullptr},                  // Duration
    {0x01c, Kind::u8, 3, nullptr},                      // AttackDirection
    {0x020, Kind::f32, 0.3f, nullptr},                  // SkillAttackDamageRate
    {0x024, Kind::f32, 0.3f, nullptr},                  // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                      // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                      // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                      // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                      // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Whip_Cast2"},    // NextStepAlias
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},  // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},  // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"}, // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},  // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Whip_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Whip_Cast2
    {0x018, Kind::f32, 0.7333f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Whip_Hit2"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Whip_Hit2
    {0x014, Kind::u8, 1, nullptr},                      // Type
    {0x018, Kind::f32, 0.5333f, nullptr},               // Duration
    {0x01c, Kind::u8, 3, nullptr},                      // AttackDirection
    {0x020, Kind::f32, 0.3f, nullptr},                  // SkillAttackDamageRate
    {0x024, Kind::f32, 0.3f, nullptr},                  // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                      // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                      // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                      // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                      // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Whip_Cast3"},    // NextStepAlias
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Strong"}, // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},  // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"}, // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},  // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Whip_HitArea2"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Whip_Cast3
    {0x018, Kind::f32, 1.1333f, nullptr},           // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Whip_Hit3"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Whip_Hit3
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.3f, nullptr},                          // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 0.4f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 0.4f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Whip_Finish1"},          // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Strong"},         // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                        // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                      // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                      // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                      // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Whip_HitArea3"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                      // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                      // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Whip_Finish1
    {0x018, Kind::f32, 1.4333f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Whip
    {0x070, Kind::i32, 1, nullptr},                   // HitLevel
    {0x074, Kind::u8, 5, nullptr},                    // AttributeType
    {0x075, Kind::u8, 1, nullptr},                    // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},            // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                    // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_Whip_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_Whip_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 15.0f, nullptr},               // CoolTime
    {0x140, Kind::f32, 2.0f, nullptr},                // AttackDamageRate
    {0x144, Kind::f32, 2.0f, nullptr},                // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                    // Cancelable
    {0x172, Kind::u8, 1, nullptr},                    // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                   // FileSuffix
    // M_TendrilC_Trace_Cast1
    {0x018, Kind::f32, 0.7f, nullptr},               // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Trace_Hit1"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x130, Kind::u8, 1, nullptr},                                  // StopSelfMove
    {0x138, Kind::names, 0, "M_TendrilC_Turn"},                     // SelfMoveAliasArray
    {0x160, Kind::name, 0, "StellarCoop/Tendril.M_TendrilC_Trace"}, // ShowPath
    {0x240, Kind::u8, 0, nullptr},                                  // CanCutoff
    {0x2f8, Kind::name, 0, "None"},                                 // FileSuffix
    // M_TendrilC_Trace_Hit1
    {0x014, Kind::u8, 1, nullptr},                      // Type
    {0x018, Kind::f32, 0.4f, nullptr},                  // Duration
    {0x01c, Kind::u8, 3, nullptr},                      // AttackDirection
    {0x020, Kind::f32, 0.5f, nullptr},                  // SkillAttackDamageRate
    {0x024, Kind::f32, 0.5f, nullptr},                  // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                      // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                      // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                      // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                      // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Trace_Cast2"},   // NextStepAlias
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Light"},  // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},  // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustEffect"}, // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},  // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                         // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                       // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                       // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                       // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Trace_HitArea1"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                       // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                       // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                      // FileSuffix
    // M_TendrilC_Trace_Cast2
    {0x018, Kind::f32, 0.6333f, nullptr},            // Duration
    {0x034, Kind::name, 0, "M_TendrilC_Trace_Hit2"}, // NextStepAlias
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 0, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Trace_Hit2
    {0x014, Kind::u8, 1, nullptr},                              // Type
    {0x018, Kind::f32, 0.4667f, nullptr},                       // Duration
    {0x01c, Kind::u8, 3, nullptr},                              // AttackDirection
    {0x020, Kind::f32, 0.5f, nullptr},                          // SkillAttackDamageRate
    {0x024, Kind::f32, 0.5f, nullptr},                          // SkillShieldAttackDamageRate
    {0x02c, Kind::u8, 1, nullptr},                              // AvailableParry
    {0x02e, Kind::u8, 1, nullptr},                              // AvailableGuard
    {0x02f, Kind::u8, 1, nullptr},                              // AvailableJustParry
    {0x030, Kind::u8, 1, nullptr},                              // AvailableJustAction
    {0x034, Kind::name, 0, "M_TendrilC_Trace_Finish1"},         // NextStepAlias
    {0x044, Kind::name, 0, "M_Common_Result_ParryJust_Center"}, // NextStepAliasWhenJustParry
    {0x0cc, Kind::name, 0, "M_TendrilC_Result_Strong"},         // SkillResultAlias
    {0x0d4, Kind::name, 0, "M_TendrilC_Result_Parry"},          // SkillResultAliasWhenParry
    {0x0dc, Kind::name, 0, "M_Common_ParryJustFX"},             // SkillResultAliasWhenJustParry
    {0x0f4, Kind::name, 0, "M_TendrilC_Result_Guard"},          // SkillResultAliasWhenGuard
    // StartSelfEffect
    {0x110, Kind::string, 0,
     "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"AddHitDefense_Step\", \"CalculationValue\":1}]"},
    {0x138, Kind::names, 0, ""},                         // SelfMoveAliasArray
    {0x1a4, Kind::u8, 1, nullptr},                       // bEveryFrameHitCheck
    {0x1a5, Kind::u8, 1, nullptr},                       // HitDetectionType
    {0x1b0, Kind::u8, 1, nullptr},                       // bRetargeting
    {0x1b4, Kind::name, 0, "M_TendrilC_Trace_HitArea2"}, // OverrideTargetFilterAlias
    {0x240, Kind::u8, 0, nullptr},                       // CanCutoff
    {0x272, Kind::u8, 1, nullptr},                       // bIgnoreHitStop
    {0x2f8, Kind::name, 0, "None"},                      // FileSuffix
    // M_TendrilC_Trace_Finish1
    {0x018, Kind::f32, 1.4f, nullptr}, // Duration
    // StartSelfEffect
    {0x110, Kind::string, 0, "[{\"Alias\":\"BlockAction_Step\"}, {\"Alias\":\"NoReactionSlug_Step\"}]"},
    {0x138, Kind::names, 0, ""},    // SelfMoveAliasArray
    {0x240, Kind::u8, 1, nullptr},  // CanCutoff
    {0x2f8, Kind::name, 0, "None"}, // FileSuffix
    // M_TendrilC_Trace
    {0x070, Kind::i32, 1, nullptr},                    // HitLevel
    {0x074, Kind::u8, 5, nullptr},                     // AttributeType
    {0x075, Kind::u8, 1, nullptr},                     // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},             // AISkillFlag
    {0x088, Kind::u8, 1, nullptr},                     // bCheckTargetExists
    {0x0b4, Kind::name, 0, "M_TendrilC_Trace_Target"}, // TargetFilterAlias
    {0x100, Kind::name, 0, "M_TendrilC_Trace_Cast1"},  // FirstSkillActiveAlias
    {0x124, Kind::f32, 12.0f, nullptr},                // CoolTime
    {0x140, Kind::f32, 1.5f, nullptr},                 // AttackDamageRate
    {0x144, Kind::f32, 1.5f, nullptr},                 // ShieldAttackDamageRate
    {0x14c, Kind::u8, 1, nullptr},                     // Cancelable
    {0x172, Kind::u8, 1, nullptr},                     // bSwitchBattleMode
    {0x2f0, Kind::name, 0, "None"},                    // FileSuffix
    // M_TendrilC_SwingLeft
    {0x018, Kind::name, 0, "M_TendrilC_SwingLeft"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                  // bJumping
    {0x04f, Kind::u8, 1, nullptr},                  // bFly
    {0x053, Kind::u8, 1, nullptr},                  // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},               // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                 // FileSuffix
    // M_TendrilC_SwingRight
    {0x018, Kind::name, 0, "M_TendrilC_SwingRight"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                   // bJumping
    {0x04f, Kind::u8, 1, nullptr},                   // bFly
    {0x053, Kind::u8, 1, nullptr},                   // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                  // FileSuffix
    // M_TendrilC_WhipLeft
    {0x018, Kind::name, 0, "M_TendrilC_WhipLeft"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                 // bJumping
    {0x04f, Kind::u8, 1, nullptr},                 // bFly
    {0x053, Kind::u8, 1, nullptr},                 // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},              // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                // FileSuffix
    // M_TendrilC_WhipRight
    {0x018, Kind::name, 0, "M_TendrilC_WhipRight"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                  // bJumping
    {0x04f, Kind::u8, 1, nullptr},                  // bFly
    {0x053, Kind::u8, 1, nullptr},                  // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},               // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                 // FileSuffix
    // M_TendrilC_DiagonalLeft
    {0x018, Kind::name, 0, "M_TendrilC_DiagonalLeft"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                     // bJumping
    {0x04f, Kind::u8, 1, nullptr},                     // bFly
    {0x053, Kind::u8, 1, nullptr},                     // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                  // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                    // FileSuffix
    // M_TendrilC_DiagonalRight
    {0x018, Kind::name, 0, "M_TendrilC_DiagonalRight"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},                      // bJumping
    {0x04f, Kind::u8, 1, nullptr},                      // bFly
    {0x053, Kind::u8, 1, nullptr},                      // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},                   // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},                     // FileSuffix
    // M_TendrilC_Chop
    {0x018, Kind::name, 0, "M_TendrilC_Chop"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},             // bJumping
    {0x04f, Kind::u8, 1, nullptr},             // bFly
    {0x053, Kind::u8, 1, nullptr},             // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},          // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},            // FileSuffix
    // M_TendrilC_Spin
    {0x018, Kind::name, 0, "M_TendrilC_Spin"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},             // bJumping
    {0x04f, Kind::u8, 1, nullptr},             // bFly
    {0x053, Kind::u8, 1, nullptr},             // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},          // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},            // FileSuffix
    // M_TendrilC_Rush
    {0x018, Kind::name, 0, "M_TendrilC_Rush"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},             // bJumping
    {0x04f, Kind::u8, 1, nullptr},             // bFly
    {0x053, Kind::u8, 1, nullptr},             // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},          // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},            // FileSuffix
    // M_TendrilC_Whip
    {0x018, Kind::name, 0, "M_TendrilC_Whip"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},             // bJumping
    {0x04f, Kind::u8, 1, nullptr},             // bFly
    {0x053, Kind::u8, 1, nullptr},             // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},          // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},            // FileSuffix
    // M_TendrilC_Trace
    {0x018, Kind::name, 0, "M_TendrilC_Trace"}, // SkillAlias
    {0x04a, Kind::u8, 1, nullptr},              // bJumping
    {0x04f, Kind::u8, 1, nullptr},              // bFly
    {0x053, Kind::u8, 1, nullptr},              // bEventMoving
    {0x0b4, Kind::i32, 100, nullptr},           // AICommandActivationRate
    {0x0f8, Kind::name, 0, "None"},             // FileSuffix
    // M_TendrilC_Peaceful
    {0x018, Kind::string, 0, "Animation/BlendSpace/IdleRun_BS_Peaceful"}, // RunBlendSpace
    {0x028, Kind::string, 0, "Animation/BlendSpace/IdleRun_BS_Peaceful"}, // RunTiltBlendSpace
    {0x038, Kind::u8, 0, nullptr},                                        // IdleAnimType
    {0x0a0, Kind::string, 0, ""},                                         // LockOnRunBlendSpace
    {0x0f0, Kind::string, 0, "Animation/Result_State_Airborne_L"},        // Fall
    {0x270, Kind::string, 0, "Animation/Run_End"},                        // RunToIdle_L
    {0x280, Kind::string, 0, "Animation/Run_End"},                        // RunToIdle_R
    {0x290, Kind::string, 0, "Animation/Run_End"},                        // RunToIdle
    {0x2d0, Kind::string, 0, "Animation/Run_End"},                        // ShortMoveToIdle_L
    {0x2e0, Kind::string, 0, "Animation/Run_End"},                        // ShortMoveToIdle_R
    {0x2f0, Kind::string, 0, "Animation/Run_End"},                        // ShortMoveToIdle
    {0x330, Kind::string, 0, "Animation/Run_Start"},                      // RunStart
    {0x340, Kind::string, 0, "Animation/Run_Start"},                      // RunStartAfterEvade
    {0x350, Kind::string, 0, ""},                                         // RunTurn_L
    {0x360, Kind::string, 0, ""},                                         // RunTurn_R
    {0x370, Kind::string, 0, ""},                                         // WalkTurn_L
    {0x380, Kind::string, 0, ""},                                         // WalkTurn_R
    {0x970, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight1Left
    {0x980, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight1Right
    {0x990, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight1Back
    {0x9a0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight1Front
    {0x9b0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight2Left
    {0x9c0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight2Right
    {0x9e0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight2Front
    {0x9f0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong1Left
    {0xa00, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong1Right
    {0xa10, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong1Back
    {0xa20, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong1Front
    {0xa30, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong2Left
    {0xa40, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong2Right
    {0xa60, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong2Front
    {0xa70, Kind::string, 0, "Animation/Result_State_Groggy_S"},          // Custom_Groggy_Start
    {0xa80, Kind::string, 0, "Animation/Result_State_Groggy_L"},          // Custom_Groggy_Loop
    {0xa90, Kind::string, 0, "Animation/Result_State_Groggy_E"},          // Custom_Groggy_End
    {0xaa0, Kind::string, 0, "Animation/Result_State_Airborne_L"},        // Custom_Airborne_Loop
    {0xab0, Kind::string, 0, "Animation/Result_State_KnockDown_Fw_S"},    // Custom_KnockDown_Start_Front
    {0xac0, Kind::string, 0, "Animation/Result_State_KnockDown_Bw_S"},    // Custom_KnockDown_Start_Back
    {0xad0, Kind::string, 0, "Animation/Result_State_KnockDown_Fw_L"},    // Custom_KnockDown_Loop
    {0xae0, Kind::string, 0, "Animation/Result_State_KnockDown_Fw_E"},    // Custom_KnockDown_End
    {0xb10, Kind::string, 0, ""},                                         // Custom_HitSwordNormalLinkAttack1
    {0xb20, Kind::string, 0, ""},                                         // Custom_HitSwordNormalFinishLinkAttack1
    {0xb50, Kind::string, 0, "Animation/Parry"},                          // Custom_Anim1
    {0xb60, Kind::string, 0, ""},                                         // Custom_Anim2
    {0xb70, Kind::string, 0, ""},                                         // Custom_Anim3
    {0xb80, Kind::string, 0, "Animation/Parry"},                          // Custom_Anim4
    // M_TendrilC_Battle
    {0x018, Kind::string, 0, "Animation/BlendSpace/IdleRun_BS_Peaceful"}, // RunBlendSpace
    {0x028, Kind::string, 0, "Animation/BlendSpace/IdleRun_BS_Peaceful"}, // RunTiltBlendSpace
    {0x038, Kind::u8, 1, nullptr},                                        // IdleAnimType
    {0x0a0, Kind::string, 0, "Animation/BlendSpace/LockOn_BS"},           // LockOnRunBlendSpace
    {0x0f0, Kind::string, 0, "Animation/Result_State_Airborne_L"},        // Fall
    {0x270, Kind::string, 0, "Animation/Run_End"},                        // RunToIdle_L
    {0x280, Kind::string, 0, "Animation/Run_End"},                        // RunToIdle_R
    {0x290, Kind::string, 0, "Animation/Run_End"},                        // RunToIdle
    {0x2d0, Kind::string, 0, "Animation/Run_End"},                        // ShortMoveToIdle_L
    {0x2e0, Kind::string, 0, "Animation/Run_End"},                        // ShortMoveToIdle_R
    {0x2f0, Kind::string, 0, "Animation/Run_End"},                        // ShortMoveToIdle
    {0x330, Kind::string, 0, "Animation/Run_Start"},                      // RunStart
    {0x340, Kind::string, 0, "Animation/Run_Start"},                      // RunStartAfterEvade
    {0x350, Kind::string, 0, ""},                                         // RunTurn_L
    {0x360, Kind::string, 0, ""},                                         // RunTurn_R
    {0x370, Kind::string, 0, ""},                                         // WalkTurn_L
    {0x380, Kind::string, 0, ""},                                         // WalkTurn_R
    {0x970, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight1Left
    {0x980, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight1Right
    {0x990, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight1Back
    {0x9a0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight1Front
    {0x9b0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight2Left
    {0x9c0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight2Right
    {0x9e0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandLight2Front
    {0x9f0, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong1Left
    {0xa00, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong1Right
    {0xa10, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong1Back
    {0xa20, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong1Front
    {0xa30, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong2Left
    {0xa40, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong2Right
    {0xa60, Kind::string, 0, "Animation/Result_Hit_KnockBack"},           // Custom_HitStandStrong2Front
    {0xa70, Kind::string, 0, "Animation/Result_State_Groggy_S"},          // Custom_Groggy_Start
    {0xa80, Kind::string, 0, "Animation/Result_State_Groggy_L"},          // Custom_Groggy_Loop
    {0xa90, Kind::string, 0, "Animation/Result_State_Groggy_E"},          // Custom_Groggy_End
    {0xaa0, Kind::string, 0, "Animation/Result_State_Airborne_L"},        // Custom_Airborne_Loop
    {0xab0, Kind::string, 0, "Animation/Result_State_KnockDown_Fw_S"},    // Custom_KnockDown_Start_Front
    {0xac0, Kind::string, 0, "Animation/Result_State_KnockDown_Bw_S"},    // Custom_KnockDown_Start_Back
    {0xad0, Kind::string, 0, "Animation/Result_State_KnockDown_Fw_L"},    // Custom_KnockDown_Loop
    {0xae0, Kind::string, 0, "Animation/Result_State_KnockDown_Fw_E"},    // Custom_KnockDown_End
    {0xb10, Kind::string, 0, ""},                                         // Custom_HitSwordNormalLinkAttack1
    {0xb20, Kind::string, 0, ""},                                         // Custom_HitSwordNormalFinishLinkAttack1
    {0xb50, Kind::string, 0, "Animation/Parry"},                          // Custom_Anim1
    {0xb60, Kind::string, 0, ""},                                         // Custom_Anim2
    {0xb70, Kind::string, 0, ""},                                         // Custom_Anim3
    {0xb80, Kind::string, 0, "Animation/Parry"},                          // Custom_Anim4
    // M_TendrilC_Default
    {0x01a, Kind::u8, 1, nullptr}, // bDetectCloakingTarget
    {0x08d, Kind::u8, 1, nullptr}, // bInfiniteStance
    // CommandArray
    {0x090, Kind::names, 0,
     "M_TendrilC_SwingLeft|M_TendrilC_SwingRight|M_TendrilC_WhipLeft|M_TendrilC_WhipRight|M_TendrilC_DiagonalLeft|"
     "M_TendrilC_DiagonalRight|M_TendrilC_Chop|M_TendrilC_Spin|M_TendrilC_Rush|M_TendrilC_Whip|M_TendrilC_Trace"},
    {0x0a8, Kind::f32, 200.0f, nullptr},                                            // WalkSpeed
    {0x0ac, Kind::f32, 400.0f, nullptr},                                            // RunSpeed
    {0x0b0, Kind::f32, 400.0f, nullptr},                                            // LockOnRunSpeed
    {0x0b4, Kind::f32, 200.0f, nullptr},                                            // LockOnWalkSpeed
    {0x0bc, Kind::f32, 180.0f, nullptr},                                            // RotateAnglePerSecond
    {0x110, Kind::string, 0, "[{\"Alias\":\"M_Common_HitProjectileCheckCount\"}]"}, // StartEffect
    {0x150, Kind::name, 0, "M_TendrilC_Peaceful"},                                  // AnimSet_Peaceful_UpperBody
    {0x158, Kind::name, 0, "M_TendrilC_Peaceful"},                                  // AnimSet_Peaceful_LowerBody
    {0x160, Kind::name, 0, "M_TendrilC_Battle"},                                    // AnimSet_Battle_UpperBody
    {0x168, Kind::name, 0, "M_TendrilC_Battle"},                                    // AnimSet_Battle_LowerBody
    {0x170, Kind::name, 0, "M_TendrilC_Battle"},                                    // AnimSet_Groggy_UpperBody
    {0x178, Kind::name, 0, "M_TendrilC_Battle"},                                    // AnimSet_Groggy_LowerBody
    {0x180, Kind::name, 0, "M_TendrilC_Battle"},                                    // AnimSet_Down_UpperBody
    {0x188, Kind::name, 0, "M_TendrilC_Battle"},                                    // AnimSet_Down_LowerBody
    {0x1a0, Kind::name, 0, "M_TendrilC_Battle"},                                    // AnimSet_Airborne_UpperBody
    {0x1a8, Kind::name, 0, "M_TendrilC_Battle"},                                    // AnimSet_Airborne_LowerBody
    // M_TendrilC
    {0x010, Kind::strings, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},    // DefaultDeadShowArray
    {0x020, Kind::i32, 6000, nullptr},                                   // DefaultDeadRewardDelayTime
    {0x038, Kind::string, 0, "Dead/Dead_Monster_EffectType_Stand"},      // StandDeadShow
    {0x048, Kind::i32, 300, nullptr},                                    // StandDeadRewardDelayTime
    {0x058, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Step0DeadShow
    {0x068, Kind::i32, 6000, nullptr},                                   // Step0DeadRewardDelayTime
    {0x078, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Step1DeadShow
    {0x088, Kind::i32, 6000, nullptr},                                   // Step1DeadRewardDelayTime
    {0x098, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Step2DeadShow
    {0x0a8, Kind::i32, 6000, nullptr},                                   // Step2DeadRewardDelayTime
    {0x0b8, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Step3DeadShow
    {0x0c8, Kind::i32, 6000, nullptr},                                   // Step3DeadRewardDelayTime
    {0x0d8, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Explosion1DeadShow
    {0x0e8, Kind::i32, 6000, nullptr},                                   // Explosion1DeadRewardDelayTime
    {0x0f8, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Explosion2DeadShow
    {0x108, Kind::i32, 6000, nullptr},                                   // Explosion2DeadRewardDelayTime
    {0x118, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Custom1DeadShow
    {0x178, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Custom4DeadShow
    {0x188, Kind::i32, 6000, nullptr},                                   // Custom4DeadRewardDelayTime
    {0x1b8, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Custom6DeadShow
    {0x1c8, Kind::i32, 6000, nullptr},                                   // Custom6DeadRewardDelayTime
    {0x1d8, Kind::string, 0, "Dead/Dead_Monster_EffectType_ZoneEffect"}, // Custom7DeadShow
    {0x1f8, Kind::string, 0, "StellarCoop/Tendril.M_TendrilC_Dead"},     // Custom8DeadShow
    {0x208, Kind::i32, 6000, nullptr},                                   // Custom8DeadRewardDelayTime
    {0x258, Kind::string, 0, "Dead/Dead_Monster_StandCommon"},           // DownDeadShow
    {0x278, Kind::string, 0, "Dead/Dead_Monster_StandCommon"},           // AirborneDeadShow
    {0x298, Kind::string, 0, "Dead/Dead_Monster_StandCommon"},           // SwimmingDeadShow
    // M_TendrilC
    // CharacterAssetPath
    {0x014, Kind::name, 0, "/Game/Art/Character/Monster/CH_M_NA_06/Blueprints/CH_M_NA_06_Blueprint"},
    {0x0e0, Kind::name, 0, "None"}, // AirborneToDownShowPath
    // M_TendrilC
    {0x014, Kind::name, 0, "Boss"},         // Rank
    {0x020, Kind::string, 0, "M_TendrilC"}, // Type
    {0x030, Kind::name, 0, "Monster"},      // Tribe
    {0x060, Kind::names, 0, ""},            // LinkSkillRandomActiveStepFlagArray
    {0x070, Kind::name, 0, "Tendril"},      // Flag
    {0x078, Kind::i32, 64960, nullptr},     // MaxHP
    {0x07c, Kind::i32, 3720, nullptr},      // MaxShield
    {0x080, Kind::i32, 12, nullptr},        // MaxStamina
    {0x084, Kind::f32, 600.0f, nullptr},    // PhysicAttackPower
    {0x088, Kind::f32, 600.0f, nullptr},    // RangeAttackPower
    {0x08c, Kind::f32, 103.0f, nullptr},    // ShieldAttackPower
    {0x090, Kind::f32, 1.0f, nullptr},      // StaminaAttackPower
    {0x094, Kind::f32, 5.0f, nullptr},      // ShieldBlock
    {0x09c, Kind::f32, 0.1f, nullptr},      // DamageReductionPerShieldBock
    {0x0d0, Kind::i32, 100, nullptr},       // GainTachyGaugeOnDead
    {0x0d4, Kind::i32, 1, nullptr},         // MoveSpeed
    {0x0d8, Kind::f32, 1.0f, nullptr},      // AttackSpeed
    {0x0e0, Kind::f32, 1.2f, nullptr},      // CriticalValueRate
    // EffectAliasWhenZeroStaminaArray
    {0x168, Kind::names, 0, "M_LinkAttackDelay_10|Groggy|SkillCancel|BlockSkill|M_StaminaRecoverReady"},
    {0x1f8, Kind::u8, 5, nullptr},                                      // WeightType
    {0x1fc, Kind::f32, 1.0f, nullptr},                                  // MeshScale
    {0x200, Kind::f32, 110.0f, nullptr},                                // TargetFilterRadius
    {0x204, Kind::f32, 180.0f, nullptr},                                // ProjectileTargetFilterRadius
    {0x208, Kind::f32, 140.0f, nullptr},                                // RuleMoveBlockAreaRadius
    {0x20c, Kind::f32, 800.0f, nullptr},                                // RuleMoveBlockAreaZHeight
    {0x210, Kind::f32, 30.0f, nullptr},                                 // RuleMoveBlockAreaOffsetX
    {0x21c, Kind::f32, 110.0f, nullptr},                                // RuleMoveBlockCheckRadius
    {0x220, Kind::names, 0, "Rank_Boss|M_Common_ImmuneAbnormal"},       // DefaultEffectArray
    {0x270, Kind::name, 0, "MonsterAlpha"},                             // DifficultyStatGroupAlias
    {0x288, Kind::string, 0, "[{\"Alias\":\"BurstGauge_DeadAlpha\"}]"}, // AttackerEffectWhenDead
    {0x298, Kind::name, 0, "M_TendrilC"},                               // DeadAlias
    {0x2a0, Kind::f32, 1.0f, nullptr},                                  // DespawnTimeAfterDeath
    {0x2a8, Kind::string, 0, "Despawn/M_Cocoon_Despawn"},               // DespawnShow
    {0x3a8, Kind::name, 0, "M_TendrilC_Default"},                       // DefaultStanceAlias
    {0x3b0, Kind::f32, 2.0f, nullptr},                                  // GetupTime
    {0x3bc, Kind::f32, 3.5f, nullptr},                                  // GroggyEndTime
    {0x3c0, Kind::names, 0, "DelayDeathInAir_Mob"},                     // JumpEffectArray
    {0x3e0, Kind::f32, 200.0f, nullptr},                                // VelocityWhenWallHitBounce
    {0x3e4, Kind::f32, 0.066f, nullptr},                                // VelocityDelayWhenWallHitBounce
    {0x3e8, Kind::string, 0, "/Game/GameDesign/Combat/BehaviorTree/Monster/M_Skulling_AI_Test"}, // BehaviorTreeRes
    {0x3f8, Kind::name, 0, "M_DetectCommon20m360"},                                              // DefaultDetectAIAlias
    {0x400, Kind::name, 0, "M_DetectCommon20m360"},                                              // NarrowDetectAIAlias
    {0x410, Kind::f32, 200.0f, nullptr},  // AIAuditorySenseRadius
    {0x414, Kind::f32, 1.0f, nullptr},    // AIAuditorySenseDecibel
    {0x418, Kind::f32, 5.0f, nullptr},    // AIAuditorySenseDuration
    {0x41c, Kind::u8, 4, nullptr},        // ActorType
    {0x420, Kind::name, 0, "M_TendrilC"}, // RefAppearance
    {0x428, Kind::i32, 1, nullptr},       // HitDefenseLevel
    {0x42c, Kind::f32, 120.0f, nullptr},  // BackSideHitAngle
    {0x470, Kind::u8, 1, nullptr},        // bDisableCollisionWhenDead
    {0x4ff, Kind::u8, 1, nullptr},        // bApplyDamageWhenPlayerAlive
    {0x500, Kind::u8, 1, nullptr},        // ScanDisplayType
    {0x508, Kind::string, 0, ""},         // Name
    // OverrideCharacterSoundSet
    {0x520, Kind::string, 0,
     "SBCharacterSoundSet'/Game/Sound/SoundAsset/CharacterSoundset/CSS_MON_05_Gigas.CSS_MON_05_Gigas'"},
    // Bullet_Shock (ItemTable, Shock Bolt)
    {0x01c, Kind::i32, 12, nullptr},                                                  // InventoryPriority
    {0x020, Kind::string, 0, "Item_Bullet_Shock_Name"},                               // NamePlural
    {0x030, Kind::string, 0, "Item_Bullet_Shock_Name"},                               // Name
    {0x050, Kind::string, 0, "Item_Bullet_Shock_Function"},                           // DescFunction
    {0x060, Kind::string, 0, "Item_Bullet_Shock_Content"},                            // DescContent
    {0x070, Kind::u8, 13, nullptr},                                                   // Category
    {0x07c, Kind::u8, 1, nullptr},                                                    // Rarity
    {0x07e, Kind::u8, 0, nullptr},                                                    // IncludeDropPool
    {0x080, Kind::i32, 1000, nullptr},                                                // StackAmount
    {0x084, Kind::i32, 30, nullptr},                                                  // MaxAmount
    {0x088, Kind::u8, 0, nullptr},                                                    // MaxAmountOverrideActorStat
    {0x090, Kind::u8, 0, nullptr},                                                    // ChargeOverrideActorStat
    {0x092, Kind::u8, 1, nullptr},                                                    // AblePrice
    {0x0a8, Kind::string, 0, "/Game/Art/Item/BP_Item_ammo_shock.BP_Item_ammo_shock"}, // Asset3D
    {0x0c8, Kind::f32, 11.5f, nullptr},                                               // AssetZOffset
    {0x0cc, Kind::f32, 1.0f, nullptr},                                                // Asset3DScale
    {0x0d0, Kind::string, 0, "Texture2D'/Game/Art/UI/Texture/HUD/bullet_icon_06.bullet_icon_06'"}, // Asset2D
    {0x13c, Kind::u8, 1, nullptr},                                                                 // AutoInteraction
    {0x14c, Kind::name, 0, "Bullet_Shock_Consume"},                                                // ConsumableAlias
    {0x180, Kind::name, 0, "Bullet_Shock"},                                                        // BulletAlias
    {0x18a, Kind::u8, 103, nullptr},                                                               // ScanDisplayType
    {0x18c, Kind::name, 0, "Ammo"},                                                                // ScanDisplayGroup
    {0x1a4, Kind::u8, 1, nullptr}, // bMaintainNewGamePlus
    // P_Eve_Gun_ShootShockSlug1_1 (SkillTable, Shock Bolt)
    {0x058, Kind::names, 0, ""},                                 // AchievementTags
    {0x070, Kind::i32, 3, nullptr},                              // HitLevel
    {0x074, Kind::u8, 5, nullptr},                               // AttributeType
    {0x075, Kind::u8, 2, nullptr},                               // SkillType
    {0x080, Kind::name, 0, "MeleeAttack"},                       // AISkillFlag
    {0x100, Kind::name, 0, "P_Eve_Gun_ShootShockSlug1_1_Cast1"}, // FirstSkillActiveAlias
    {0x124, Kind::f32, 1.0f, nullptr},                           // CoolTime
    {0x140, Kind::f32, 1.2f, nullptr},                           // AttackDamageRate
    {0x144, Kind::f32, 1.2f, nullptr},                           // ShieldAttackDamageRate
    {0x158, Kind::name, 0, "Custom6"},                           // TargetDeadType
    {0x160, Kind::string, 0, "Hit/Result_Hit_Env"},              // WorldObjectHitShow
    {0x17c, Kind::name, 0, "None"},                              // AcquisitionSkillAlias
    {0x187, Kind::u8, 1, nullptr},                               // ConditionEnd_RangedCombat
    {0x18c, Kind::name, 0, "None"},                              // ExpansionFromAcquisitionAlias1
    {0x194, Kind::u8, 0, nullptr},                               // ExpansionType1
    {0x198, Kind::string, 0, ""},                                // ExpansionValue1
    {0x2f0, Kind::name, 0, "Eve"},                               // FileSuffix
    // P_Eve_Gun_ShootShockSlug1_Projectile1 (ProjectileTable, Shock Bolt)
    // ResourcePath
    {0x018, Kind::string, 0, "/Game/Art/Character/PC/CH_P_EVE_01/Projectile/P_Eve_Gun_ShootShockSlug1_Projectile1"},
    {0x028, Kind::u8, 1, nullptr},                                        // bGroupProjectile
    {0x029, Kind::u8, 2, nullptr},                                        // LifeType
    {0x02c, Kind::f32, 0.5f, nullptr},                                    // LifeTime
    {0x030, Kind::u8, 1, nullptr},                                        // DestroyType
    {0x03c, Kind::f32, 1.0f, nullptr},                                    // AttackDamageRate
    {0x040, Kind::f32, 1.0f, nullptr},                                    // ShieldAttackDamageRate
    {0x04c, Kind::name, 0, "P_Eve_Gun_ShootAmmo1_Projectile_Target"},     // TargetFilterAlias
    {0x0c4, Kind::name, 0, "ShootNormal01"},                              // ZoneEventActorTriggerTag
    {0x0cc, Kind::name, 0, "P_Eve_Gun_ShootShockSlug1_Projectile1_Hit1"}, // SkillResultAliasWhenProjectileHit
    {0x0d4, Kind::name, 0, "P_Eve_Gun_ShootSlug1_Projectile1_Parry1"},    // SkillResultAliasWhenProjectileParry
    {0x0e4, Kind::name, 0, "P_Eve_Gun_ShootSlug1_Projectile1_Guard1"},    // SkillResultAliasWhenProjectileGuard
    {0x104, Kind::name, 0, "Custom6"},                                    // TargetDeadType
    {0x120, Kind::u8, 1, nullptr},                                        // AvailableParry
    {0x122, Kind::u8, 1, nullptr},                                        // AvailableGuard
    {0x125, Kind::u8, 1, nullptr},                                        // AvailableJustAction
    {0x12c, Kind::u8, 1, nullptr},                                        // bImpossibleReflect
    {0x16a, Kind::u8, 1, nullptr},                                        // bProjectileAttackPossible
    {0x16c, Kind::f32, 1.0f, nullptr},                                    // ProjectileAttackDamage
    {0x198, Kind::f32, 0.3f, nullptr},                                    // ZoneEventDestructionDelayMinTime
    {0x19c, Kind::f32, 0.3f, nullptr},                                    // ZoneEventDestructionDelayMaxTime
    {0x1a0, Kind::u8, 1, nullptr},                                        // bCheckShotPosition
    {0x1a4, Kind::name, 0, "Bip001-Head"},                                // CheckShotPositionSocketName
    {0x1b7, Kind::u8, 1, nullptr},                                        // StartTargetTransformType
    {0x1b8, Kind::name, 0, "SC_GunShoot_Up"},                             // StartTargetTransformName
    {0x1c0, Kind::u8, 1, nullptr},                                        // bStartTargetTransformRotation
    {0x1dd, Kind::u8, 3, nullptr},                                        // DestTarget
    {0x228, Kind::u8, 2, nullptr},                                        // DestTargetRelativeAxisType
    {0x238, Kind::f32, 50000.0f, nullptr},                                // StartToDestDirectionDistance
    {0x23c, Kind::f32, 20000.0f, nullptr},                                // Speed
    {0x248, Kind::f32, 20000.0f, nullptr},                                // MinSpeed
    {0x24c, Kind::f32, 20000.0f, nullptr},                                // MaxSpeed
    {0x298, Kind::f32, 100.0f, nullptr},                                  // Gravity
    {0x314, Kind::i32, 7, nullptr},                                       // PoolCount
    // P_Eve_Gun_ShootShockSlug1_Projectile1_Hit1 (SkillResultTable, Shock Bolt)
    // ResultSelfCommonEffect
    {0x018, Kind::string, 0,
     "[{\"Alias\":\"P_Protector_Shoot3_1_ForTest\"}, {\"Alias\":\"P_Protector_Shoot3_MK2_1_ForTest\"}]"},
    // ResultTargetCommonEffect
    {0x028, Kind::string, 0,
     "[{\"Alias\":\"Check_Dialogue\"}, {\"Alias\":\"SkillDamage_EveRange\"}, "
     "{\"Alias\":\"M_Common_HitProjectileCheck\"}, {\"Alias\":\"ShockSlugStun\"}]"},
    {0x038, Kind::string, 0, "[{\"Alias\":\"BlockMove_Slug\", \"Time\":0.2}]"}, // HitLevelResultTargetCommonEffect
    {0x058, Kind::string, 0, "Hit/Result_Hit_Projectile_Normal"},               // ResultTargetCommonShowPath
    {0x0b8, Kind::string, 0, "Hit/Result_Hit_Projectile_Normal_NoAnim"},        // ResultTargetDownShowPath
    {0x118, Kind::string, 0, "Hit/Result_Hit_Projectile_Normal_NoAnim"},        // ResultTargetGroggyShowPath
    {0x1d8, Kind::string, 0, "Hit/Result_Hit_Projectile_Normal_NoAnim"},        // ResultTargetAirShowPath
    {0x1f0, Kind::name, 0, "Hit_Air_010_300"},                                  // HitLevelResultTargetAirMoveAlias
    {0x238, Kind::string, 0, "Hit/Result_Hit_Projectile_Normal_NoAnim"},        // ResultTargetSwimmingShowPath
    {0x250, Kind::name, 0, "Hit_Back_0"},                                       // HitLevelResultTargetSwimmingMoveAlias
    // ResultSelfWeakpointHitEffect
    {0x298, Kind::string, 0, "[{\"Alias\":\"P_Protector_Shoot3_1\"}, {\"Alias\":\"P_Protector_Shoot3_MK2_1\"}]"},
    // ResultTargetWeakpointHitEffect
    {0x2a8, Kind::string, 0,
     "[{\"Alias\":\"Show_ResultHitWeakPoint\"},{\"Alias\":\"Show_ResultHitWeakPoint_Maelstrom\"}]"},
    {0x318, Kind::name, 0, "Eve"}, // FileSuffix
};
constexpr Row kRecipe[] = {
    {Table::skill, "P_Eve_Sword_Normal_Buff_1", "P_Eve_Sword_Normal_Potion_1", 6000101, 0, 8},
    {Table::consumable, "Buff_HP2MP", "HP2Burst_Potion", 1032, 8, 3},
    {Table::item, "HP2Burst_Potion", "HP_Potion", 300013, 11, 27},
    {Table::item, "Buff_HP2MP", "HP_Potion", 300014, 38, 27},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Cast1", "P_Eve_Tachy_Skill_Chainstab1_1_Cast1", 100450001, 65, 9},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Hit1", "P_Eve_Tachy_Skill_Chainstab1_1_Hit1", 100450002, 74, 17},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Cast2", "P_Eve_Tachy_Skill_Chainstab1_1_Cast2", 100450003, 91, 4},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Hit2", "P_Eve_Tachy_Skill_Chainstab1_1_Hit1", 100450004, 95, 16},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Cast3", "P_Eve_Tachy_Skill_Chainstab1_1_Cast2", 100450005, 111, 4},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Hit3", "P_Eve_Tachy_Skill_Chainstab1_1_Hit1", 100450006, 115, 16},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Cast4", "P_Eve_Tachy_Skill_Chainstab1_1_Cast2", 100450007, 131, 5},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Hit4", "P_Eve_Tachy_Skill_Chainstab1_1_Hit5", 100450008, 136, 15},
    {Table::step, "P_Eve_Tachy_Skill_ChainSpin1_1_Finish1", "P_Eve_Tachy_Skill_Chainstab1_1_Finish1", 100450009, 151,
     6},
    {Table::skill, "P_Eve_Tachy_Skill_ChainSpin1_1", "P_Eve_Tachy_Skill_ChainStab1_1", 1004500, 157, 22},
    {Table::effect, "P_Eve_Tachy_Skill_ChainSpin1_Use", "M_Scarlet_CounterLinkStart", 1004500, 179, 8},
    {Table::effect, "M_LionC_PhaseRoar", "M_Scarlet_CounterLinkStart", 5002000, 187, 7},
    {Table::result, "M_LionC_Result_Light", "M_Behemoth_ScratchLeft_Parry1", 500200000, 194, 14},
    {Table::result, "M_LionC_Result_Strong", "M_Behemoth_ScratchLeft_Parry1", 500200001, 208, 14},
    {Table::result, "M_LionC_Result_KnockDown", "M_Behemoth_ScratchLeft_Parry1", 500200002, 222, 14},
    {Table::result, "M_LionC_Result_Guard", "M_Behemoth_ScratchLeft_Parry1", 500200003, 236, 4},
    {Table::result, "M_LionC_Result_Parry", "M_Behemoth_ScratchLeft_Parry1", 500200004, 240, 3},
    {Table::filter, "M_LionC_HitArea", "M_Behemoth_HitArea", 5002000, 243, 6},
    {Table::filter, "M_LionC_Roar_HitArea", "M_Behemoth_HitArea", 5002001, 249, 8},
    {Table::filter, "M_LionC_ClawAttackLeft_Target", "M_Behemoth_HitArea", 5002002, 257, 8},
    {Table::filter, "M_LionC_ClawAttackRight_Target", "M_Behemoth_HitArea", 5002003, 265, 8},
    {Table::filter, "M_LionC_ClawAttackChaseLeft_Target", "M_Behemoth_HitArea", 5002004, 273, 9},
    {Table::filter, "M_LionC_ClawAttackChaseRight_Target", "M_Behemoth_HitArea", 5002005, 282, 10},
    {Table::filter, "M_LionC_TurnAttackLeft_Target", "M_Behemoth_HitArea", 5002006, 292, 9},
    {Table::filter, "M_LionC_TurnAttackRight_Target", "M_Behemoth_HitArea", 5002007, 301, 9},
    {Table::filter, "M_LionC_RunAttackLeft_Target", "M_Behemoth_HitArea", 5002008, 310, 10},
    {Table::filter, "M_LionC_RunAttackRight_Target", "M_Behemoth_HitArea", 5002009, 320, 10},
    {Table::filter, "M_LionC_JumpAttackLow_Target", "M_Behemoth_HitArea", 5002010, 330, 9},
    {Table::filter, "M_LionC_JumpAttackLow_HitArea", "M_Behemoth_HitArea", 5002011, 339, 8},
    {Table::filter, "M_LionC_JumpAttackHigh_Target", "M_Behemoth_HitArea", 5002012, 347, 9},
    {Table::filter, "M_LionC_JumpAttackHigh_HitArea", "M_Behemoth_HitArea", 5002013, 356, 8},
    {Table::filter, "M_LionC_BackJumpToAttack_Target", "M_Behemoth_HitArea", 5002014, 364, 9},
    {Table::filter, "M_LionC_AttackToBackJump_Target", "M_Behemoth_HitArea", 5002015, 373, 8},
    {Table::filter, "M_LionC_Roar_Target", "M_Behemoth_HitArea", 5002016, 381, 8},
    {Table::filter, "M_LionC_SideStepLeft_Target", "M_Behemoth_HitArea", 5002017, 389, 9},
    {Table::filter, "M_LionC_SideStepRight_Target", "M_Behemoth_HitArea", 5002018, 398, 9},
    {Table::filter, "M_LionC_ClawAttackChain_Target", "M_Behemoth_HitArea", 5002019, 407, 8},
    {Table::filter, "M_LionC_ClawAttackChain2_Target", "M_Behemoth_HitArea", 5002020, 415, 8},
    {Table::filter, "M_LionC_MoveAttackChain_Target", "M_Behemoth_HitArea", 5002021, 423, 8},
    {Table::filter, "M_LionC_RushAttack_Target", "M_Behemoth_HitArea", 5002022, 431, 9},
    {Table::filter, "M_LionC_DashAttackChain_Target", "M_Behemoth_HitArea", 5002023, 440, 8},
    {Table::filter, "M_LionC_DashAttackChain_HitArea", "M_Behemoth_HitArea", 5002024, 448, 8},
    {Table::move, "M_LionC_ClawAttackLeft_Turn", "M_Behemoth_ScratchLeft_Move2", 5002000, 456, 16},
    {Table::move, "M_LionC_ClawAttackRight_Turn", "M_Behemoth_ScratchLeft_Move2", 5002001, 472, 16},
    {Table::move, "M_LionC_ClawAttackChaseLeft_Move1", "M_Behemoth_ScratchLeft_Move2", 5002002, 488, 18},
    {Table::move, "M_LionC_ClawAttackChaseLeft_Move2", "M_Behemoth_ScratchLeft_Move2", 5002003, 506, 17},
    {Table::move, "M_LionC_ClawAttackChaseLeft_Move3", "M_Behemoth_ScratchLeft_Move2", 5002004, 523, 14},
    {Table::move, "M_LionC_ClawAttackChaseRight_Move1", "M_Behemoth_ScratchLeft_Move2", 5002005, 537, 17},
    {Table::move, "M_LionC_ClawAttackChaseRight_Move2", "M_Behemoth_ScratchLeft_Move2", 5002006, 554, 17},
    {Table::move, "M_LionC_ClawAttackChaseRight_Move3", "M_Behemoth_ScratchLeft_Move2", 5002007, 571, 17},
    {Table::move, "M_LionC_TurnAttackLeft_Turn", "M_Behemoth_ScratchLeft_Move2", 5002008, 588, 18},
    {Table::move, "M_LionC_TurnAttackRight_Turn", "M_Behemoth_ScratchLeft_Move2", 5002009, 606, 18},
    {Table::move, "M_LionC_RunAttackLeft_Move1", "M_Behemoth_ScratchLeft_Move2", 5002010, 624, 17},
    {Table::move, "M_LionC_RunAttackLeft_Move2", "M_Behemoth_ScratchLeft_Move2", 5002011, 641, 17},
    {Table::move, "M_LionC_RunAttackLeft_Move3", "M_Behemoth_ScratchLeft_Move2", 5002012, 658, 17},
    {Table::move, "M_LionC_RunAttackRight_Move1", "M_Behemoth_ScratchLeft_Move2", 5002013, 675, 17},
    {Table::move, "M_LionC_RunAttackRight_Move2", "M_Behemoth_ScratchLeft_Move2", 5002014, 692, 17},
    {Table::move, "M_LionC_RunAttackRight_Move3", "M_Behemoth_ScratchLeft_Move2", 5002015, 709, 17},
    {Table::move, "M_LionC_JumpAttackLow_Move1", "M_Behemoth_ScratchLeft_Move2", 5002016, 726, 18},
    {Table::move, "M_LionC_JumpAttackHigh_Turn", "M_Behemoth_ScratchLeft_Move2", 5002017, 744, 16},
    {Table::move, "M_LionC_JumpAttackHigh_Move2", "M_Behemoth_ScratchLeft_Move2", 5002018, 760, 17},
    {Table::move, "M_LionC_JumpAttackHigh_Move3", "M_Behemoth_ScratchLeft_Move2", 5002019, 777, 17},
    {Table::move, "M_LionC_BackJumpToAttack_Turn", "M_Behemoth_ScratchLeft_Move2", 5002020, 794, 18},
    {Table::move, "M_LionC_AttackToBackJump_Turn", "M_Behemoth_ScratchLeft_Move2", 5002021, 812, 16},
    {Table::move, "M_LionC_AttackToBackJump_Move3", "M_Behemoth_ScratchLeft_Move2", 5002022, 828, 14},
    {Table::move, "M_LionC_Roar_Turn", "M_Behemoth_ScratchLeft_Move2", 5002023, 842, 16},
    {Table::move, "M_LionC_Roar_Move3", "M_Behemoth_ScratchLeft_Move2", 5002024, 858, 14},
    {Table::move, "M_LionC_SideStepLeft_Move1", "M_Behemoth_ScratchLeft_Move2", 5002025, 872, 15},
    {Table::move, "M_LionC_SideStepRight_Move1", "M_Behemoth_ScratchLeft_Move2", 5002026, 887, 15},
    {Table::move, "M_LionC_ClawAttackChain_Move1", "M_Behemoth_ScratchLeft_Move2", 5002027, 902, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move2", "M_Behemoth_ScratchLeft_Move2", 5002028, 919, 16},
    {Table::move, "M_LionC_ClawAttackChain_Move3", "M_Behemoth_ScratchLeft_Move2", 5002029, 935, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move4", "M_Behemoth_ScratchLeft_Move2", 5002030, 952, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move5", "M_Behemoth_ScratchLeft_Move2", 5002031, 969, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move6", "M_Behemoth_ScratchLeft_Move2", 5002032, 986, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move7", "M_Behemoth_ScratchLeft_Move2", 5002033, 1003, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move1", "M_Behemoth_ScratchLeft_Move2", 5002034, 1020, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move2", "M_Behemoth_ScratchLeft_Move2", 5002035, 1037, 16},
    {Table::move, "M_LionC_ClawAttackChain2_Move4", "M_Behemoth_ScratchLeft_Move2", 5002036, 1053, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move5", "M_Behemoth_ScratchLeft_Move2", 5002037, 1070, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move6", "M_Behemoth_ScratchLeft_Move2", 5002038, 1087, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move7", "M_Behemoth_ScratchLeft_Move2", 5002039, 1104, 16},
    {Table::move, "M_LionC_ClawAttackChain2_Move8", "M_Behemoth_ScratchLeft_Move2", 5002040, 1120, 16},
    {Table::move, "M_LionC_ClawAttackChain2_Move9", "M_Behemoth_ScratchLeft_Move2", 5002041, 1136, 14},
    {Table::move, "M_LionC_MoveAttackChain_Move1", "M_Behemoth_ScratchLeft_Move2", 5002042, 1150, 15},
    {Table::move, "M_LionC_MoveAttackChain_Move3", "M_Behemoth_ScratchLeft_Move2", 5002043, 1165, 17},
    {Table::move, "M_LionC_MoveAttackChain_Move4", "M_Behemoth_ScratchLeft_Move2", 5002044, 1182, 17},
    {Table::move, "M_LionC_MoveAttackChain_Move5", "M_Behemoth_ScratchLeft_Move2", 5002045, 1199, 17},
    {Table::move, "M_LionC_MoveAttackChain_Move6", "M_Behemoth_ScratchLeft_Move2", 5002046, 1216, 17},
    {Table::move, "M_LionC_RushAttack_Move1", "M_Behemoth_ScratchLeft_Move2", 5002047, 1233, 18},
    {Table::move, "M_LionC_RushAttack_Move2", "M_Behemoth_ScratchLeft_Move2", 5002048, 1251, 17},
    {Table::move, "M_LionC_RushAttack_Move3", "M_Behemoth_ScratchLeft_Move2", 5002049, 1268, 17},
    {Table::move, "M_LionC_DashAttackChain_Move1", "M_Behemoth_ScratchLeft_Move2", 5002050, 1285, 15},
    {Table::move, "M_LionC_DashAttackChain_Move2", "M_Behemoth_ScratchLeft_Move2", 5002051, 1300, 16},
    {Table::move, "M_LionC_DashAttackChain_Move3", "M_Behemoth_ScratchLeft_Move2", 5002052, 1316, 16},
    {Table::move, "M_LionC_DashAttackChain_Move4", "M_Behemoth_ScratchLeft_Move2", 5002053, 1332, 16},
    {Table::move, "M_LionC_DashAttackChain_Move5", "M_Behemoth_ScratchLeft_Move2", 5002054, 1348, 17},
    {Table::move, "M_LionC_DashAttackChain_Move6", "M_Behemoth_ScratchLeft_Move2", 5002055, 1365, 17},
    {Table::move, "M_LionC_DashAttackChain_Move7", "M_Behemoth_ScratchLeft_Move2", 5002056, 1382, 17},
    {Table::move, "M_LionC_DashAttackChain_Move8", "M_Behemoth_ScratchLeft_Move2", 5002057, 1399, 17},
    {Table::move, "M_LionC_DashAttackChain_Move9", "M_Behemoth_ScratchLeft_Move2", 5002058, 1416, 17},
    {Table::move, "M_LionC_RoarPhaseChange_Turn", "M_Behemoth_ScratchLeft_Move2", 5002059, 1433, 16},
    {Table::move, "M_LionC_RoarPhaseChange_Move3", "M_Behemoth_ScratchLeft_Move2", 5002060, 1449, 14},
    {Table::step, "M_LionC_ClawAttackLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200002, 1463, 8},
    {Table::step, "M_LionC_ClawAttackLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200003, 1471, 25},
    {Table::step, "M_LionC_ClawAttackLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200004, 1496, 5},
    {Table::skill, "M_LionC_ClawAttackLeft", "M_Behemoth_ScratchLeft", 5002000, 1501, 13},
    {Table::step, "M_LionC_ClawAttackRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200102, 1514, 8},
    {Table::step, "M_LionC_ClawAttackRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200103, 1522, 25},
    {Table::step, "M_LionC_ClawAttackRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200104, 1547, 5},
    {Table::skill, "M_LionC_ClawAttackRight", "M_Behemoth_ScratchLeft", 5002001, 1552, 13},
    {Table::step, "M_LionC_ClawAttackChaseLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200202, 1565, 8},
    {Table::step, "M_LionC_ClawAttackChaseLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200203, 1573, 25},
    {Table::step, "M_LionC_ClawAttackChaseLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200204, 1598, 5},
    {Table::skill, "M_LionC_ClawAttackChaseLeft", "M_Behemoth_ScratchLeft", 5002002, 1603, 14},
    {Table::step, "M_LionC_ClawAttackChaseRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200302, 1617, 8},
    {Table::step, "M_LionC_ClawAttackChaseRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200303, 1625, 25},
    {Table::step, "M_LionC_ClawAttackChaseRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200304, 1650, 5},
    {Table::skill, "M_LionC_ClawAttackChaseRight", "M_Behemoth_ScratchLeft", 5002003, 1655, 14},
    {Table::step, "M_LionC_TurnAttackLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200402, 1669, 8},
    {Table::step, "M_LionC_TurnAttackLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200403, 1677, 25},
    {Table::step, "M_LionC_TurnAttackLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200404, 1702, 5},
    {Table::skill, "M_LionC_TurnAttackLeft", "M_Behemoth_ScratchLeft", 5002004, 1707, 13},
    {Table::step, "M_LionC_TurnAttackRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200502, 1720, 8},
    {Table::step, "M_LionC_TurnAttackRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200503, 1728, 25},
    {Table::step, "M_LionC_TurnAttackRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200504, 1753, 5},
    {Table::skill, "M_LionC_TurnAttackRight", "M_Behemoth_ScratchLeft", 5002005, 1758, 13},
    {Table::step, "M_LionC_RunAttackLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200602, 1771, 8},
    {Table::step, "M_LionC_RunAttackLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200603, 1779, 25},
    {Table::step, "M_LionC_RunAttackLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200604, 1804, 5},
    {Table::skill, "M_LionC_RunAttackLeft", "M_Behemoth_ScratchLeft", 5002006, 1809, 14},
    {Table::step, "M_LionC_RunAttackRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200702, 1823, 8},
    {Table::step, "M_LionC_RunAttackRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200703, 1831, 25},
    {Table::step, "M_LionC_RunAttackRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200704, 1856, 5},
    {Table::skill, "M_LionC_RunAttackRight", "M_Behemoth_ScratchLeft", 5002007, 1861, 14},
    {Table::step, "M_LionC_JumpAttackLow_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200802, 1875, 8},
    {Table::step, "M_LionC_JumpAttackLow_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200803, 1883, 24},
    {Table::step, "M_LionC_JumpAttackLow_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200804, 1907, 5},
    {Table::skill, "M_LionC_JumpAttackLow", "M_Behemoth_ScratchLeft", 5002008, 1912, 14},
    {Table::step, "M_LionC_JumpAttackHigh_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200902, 1926, 11},
    {Table::step, "M_LionC_JumpAttackHigh_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200903, 1937, 19},
    {Table::step, "M_LionC_JumpAttackHigh_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200904, 1956, 5},
    {Table::skill, "M_LionC_JumpAttackHigh", "M_Behemoth_ScratchLeft", 5002009, 1961, 14},
    {Table::step, "M_LionC_BackJumpToAttack_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201002, 1975, 8},
    {Table::step, "M_LionC_BackJumpToAttack_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201003, 1983, 25},
    {Table::step, "M_LionC_BackJumpToAttack_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201004, 2008, 5},
    {Table::skill, "M_LionC_BackJumpToAttack", "M_Behemoth_ScratchLeft", 5002010, 2013, 13},
    {Table::step, "M_LionC_AttackToBackJump_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201102, 2026, 8},
    {Table::step, "M_LionC_AttackToBackJump_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201103, 2034, 25},
    {Table::step, "M_LionC_AttackToBackJump_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201104, 2059, 5},
    {Table::skill, "M_LionC_AttackToBackJump", "M_Behemoth_ScratchLeft", 5002011, 2064, 14},
    {Table::step, "M_LionC_Roar_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201202, 2078, 12},
    {Table::step, "M_LionC_Roar_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201203, 2090, 19},
    {Table::step, "M_LionC_Roar_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201204, 2109, 5},
    {Table::skill, "M_LionC_Roar", "M_Behemoth_ScratchLeft", 5002012, 2114, 13},
    {Table::step, "M_LionC_SideStepLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201302, 2127, 7},
    {Table::skill, "M_LionC_SideStepLeft", "M_Behemoth_ScratchLeft", 5002013, 2134, 14},
    {Table::step, "M_LionC_SideStepRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201402, 2148, 7},
    {Table::skill, "M_LionC_SideStepRight", "M_Behemoth_ScratchLeft", 5002014, 2155, 14},
    {Table::step, "M_LionC_ClawAttackChain_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201502, 2169, 8},
    {Table::step, "M_LionC_ClawAttackChain_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201503, 2177, 24},
    {Table::step, "M_LionC_ClawAttackChain_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201504, 2201, 6},
    {Table::step, "M_LionC_ClawAttackChain_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500201505, 2207, 24},
    {Table::step, "M_LionC_ClawAttackChain_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500201506, 2231, 6},
    {Table::step, "M_LionC_ClawAttackChain_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500201507, 2237, 25},
    {Table::step, "M_LionC_ClawAttackChain_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201508, 2262, 5},
    {Table::skill, "M_LionC_ClawAttackChain", "M_Behemoth_ScratchLeft", 5002015, 2267, 14},
    {Table::step, "M_LionC_ClawAttackChain2_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201602, 2281, 8},
    {Table::step, "M_LionC_ClawAttackChain2_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201603, 2289, 24},
    {Table::step, "M_LionC_ClawAttackChain2_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201604, 2313, 6},
    {Table::step, "M_LionC_ClawAttackChain2_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500201605, 2319, 24},
    {Table::step, "M_LionC_ClawAttackChain2_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500201606, 2343, 6},
    {Table::step, "M_LionC_ClawAttackChain2_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500201607, 2349, 24},
    {Table::step, "M_LionC_ClawAttackChain2_Cast4", "M_Behemoth_ScratchLeft_Finish1", 500201608, 2373, 6},
    {Table::step, "M_LionC_ClawAttackChain2_Hit4", "M_Behemoth_ScratchLeft_Finish1", 500201609, 2379, 25},
    {Table::step, "M_LionC_ClawAttackChain2_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201610, 2404, 5},
    {Table::skill, "M_LionC_ClawAttackChain2", "M_Behemoth_ScratchLeft", 5002016, 2409, 14},
    {Table::step, "M_LionC_MoveAttackChain_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201702, 2423, 8},
    {Table::step, "M_LionC_MoveAttackChain_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201703, 2431, 24},
    {Table::step, "M_LionC_MoveAttackChain_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201704, 2455, 6},
    {Table::step, "M_LionC_MoveAttackChain_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500201705, 2461, 24},
    {Table::step, "M_LionC_MoveAttackChain_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500201706, 2485, 6},
    {Table::step, "M_LionC_MoveAttackChain_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500201707, 2491, 25},
    {Table::step, "M_LionC_MoveAttackChain_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201708, 2516, 5},
    {Table::skill, "M_LionC_MoveAttackChain", "M_Behemoth_ScratchLeft", 5002017, 2521, 14},
    {Table::step, "M_LionC_RushAttack_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201802, 2535, 8},
    {Table::step, "M_LionC_RushAttack_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201803, 2543, 6},
    {Table::step, "M_LionC_RushAttack_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201804, 2549, 25},
    {Table::step, "M_LionC_RushAttack_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201805, 2574, 5},
    {Table::skill, "M_LionC_RushAttack", "M_Behemoth_ScratchLeft", 5002018, 2579, 14},
    {Table::step, "M_LionC_DashAttackChain_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201902, 2593, 8},
    {Table::step, "M_LionC_DashAttackChain_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201903, 2601, 23},
    {Table::step, "M_LionC_DashAttackChain_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201904, 2624, 6},
    {Table::step, "M_LionC_DashAttackChain_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500201905, 2630, 23},
    {Table::step, "M_LionC_DashAttackChain_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500201906, 2653, 6},
    {Table::step, "M_LionC_DashAttackChain_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500201907, 2659, 23},
    {Table::step, "M_LionC_DashAttackChain_Cast4", "M_Behemoth_ScratchLeft_Finish1", 500201908, 2682, 6},
    {Table::step, "M_LionC_DashAttackChain_Hit4", "M_Behemoth_ScratchLeft_Finish1", 500201909, 2688, 24},
    {Table::step, "M_LionC_DashAttackChain_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201910, 2712, 5},
    {Table::skill, "M_LionC_DashAttackChain", "M_Behemoth_ScratchLeft", 5002019, 2717, 14},
    {Table::step, "M_LionC_RoarPhaseChange_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500202002, 2731, 13},
    {Table::step, "M_LionC_RoarPhaseChange_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500202003, 2744, 19},
    {Table::step, "M_LionC_RoarPhaseChange_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500202004, 2763, 5},
    {Table::skill, "M_LionC_RoarPhaseChange", "M_Behemoth_ScratchLeft", 5002020, 2768, 13},
    {Table::command, "M_LionC_ClawAttackLeft", "M_Behemoth_ScratchLeft", 5002000, 2781, 6},
    {Table::command, "M_LionC_ClawAttackRight", "M_Behemoth_ScratchLeft", 5002001, 2787, 6},
    {Table::command, "M_LionC_ClawAttackChaseLeft", "M_Behemoth_ScratchLeft", 5002002, 2793, 6},
    {Table::command, "M_LionC_ClawAttackChaseRight", "M_Behemoth_ScratchLeft", 5002003, 2799, 6},
    {Table::command, "M_LionC_TurnAttackLeft", "M_Behemoth_ScratchLeft", 5002004, 2805, 6},
    {Table::command, "M_LionC_TurnAttackRight", "M_Behemoth_ScratchLeft", 5002005, 2811, 6},
    {Table::command, "M_LionC_RunAttackLeft", "M_Behemoth_ScratchLeft", 5002006, 2817, 6},
    {Table::command, "M_LionC_RunAttackRight", "M_Behemoth_ScratchLeft", 5002007, 2823, 6},
    {Table::command, "M_LionC_JumpAttackLow", "M_Behemoth_ScratchLeft", 5002008, 2829, 6},
    {Table::command, "M_LionC_JumpAttackHigh", "M_Behemoth_ScratchLeft", 5002009, 2835, 6},
    {Table::command, "M_LionC_BackJumpToAttack", "M_Behemoth_ScratchLeft", 5002010, 2841, 6},
    {Table::command, "M_LionC_AttackToBackJump", "M_Behemoth_ScratchLeft", 5002011, 2847, 6},
    {Table::command, "M_LionC_Roar", "M_Behemoth_ScratchLeft", 5002012, 2853, 6},
    {Table::command, "M_LionC_SideStepLeft", "M_Behemoth_ScratchLeft", 5002013, 2859, 6},
    {Table::command, "M_LionC_SideStepRight", "M_Behemoth_ScratchLeft", 5002014, 2865, 6},
    {Table::command, "M_LionC_ClawAttackChain", "M_Behemoth_ScratchLeft", 5002015, 2871, 6},
    {Table::command, "M_LionC_ClawAttackChain2", "M_Behemoth_ScratchLeft", 5002016, 2877, 6},
    {Table::command, "M_LionC_MoveAttackChain", "M_Behemoth_ScratchLeft", 5002017, 2883, 6},
    {Table::command, "M_LionC_RushAttack", "M_Behemoth_ScratchLeft", 5002018, 2889, 6},
    {Table::command, "M_LionC_DashAttackChain", "M_Behemoth_ScratchLeft", 5002019, 2895, 6},
    {Table::command, "M_LionC_RoarPhaseChange", "M_Behemoth_ScratchLeft", 5002020, 2901, 6},
    {Table::anim, "M_LionC_Peaceful", "M_Behemoth_Battle", 500200, 2907, 45},
    {Table::anim, "M_LionC_Battle", "M_Behemoth_Battle", 500201, 2952, 45},
    {Table::stance, "M_LionC_Default", "M_Behemoth_Default", 500200, 2997, 19},
    {Table::stance, "M_LionC_Phase2", "M_Behemoth_Default", 500201, 3016, 23},
    {Table::dead, "M_LionC", "M_Behemoth", 0, 3039, 27},
    {Table::appearance, "M_LionC", "M_Behemoth", 50020, 3066, 2},
    {Table::character, "M_LionC_Lurker", "M_Behemoth", 50021, 3068, 55},
    {Table::character, "M_LionC", "M_Behemoth", 50020, 3123, 55},
};
// The Gardener's own batch (coop gardener fight), added on its own ask after its own checks: 13 near copies of
// shipped rows (character 3, stance 1, command 3, skill 3, step 3), 279 fields, 102 of them changed from the
// template's value. M_Gardener_Skulling (50011) with M_Skulling_AI_Test, M_Gardener_Half (50012) with
// M_Tentacle_AI, M_Gardener (50010) with M_Tentacle_AI. Its three skills run on the shipped steps of SingleShot_4
// and MultipleShot_1 and on ToxicBeam's three new steps.
constexpr Row kGardenerRecipe[] = {
    {Table::step, "M_GardenerC_ToxicBeam_Cast1", "M_Gardener_SingleShot_1_Cast1", 500100043, 3178, 8},
    {Table::step, "M_GardenerC_ToxicBeam_Hit1", "M_Gardener_SingleShot_1_Hit1", 500100044, 3186, 10},
    {Table::step, "M_GardenerC_ToxicBeam_Finish1", "M_Gardener_SingleShot_1_Finish1", 500100045, 3196, 2},
    {Table::skill, "M_GardenerC_SingleShot", "M_Gardener_SingleShot_4", 5001010, 3198, 11},
    {Table::skill, "M_GardenerC_MultipleShot", "M_Gardener_MultipleShot_1", 5001011, 3209, 12},
    {Table::skill, "M_GardenerC_ToxicBeam", "M_Gardener_SingleShot_1", 5001012, 3221, 12},
    {Table::command, "M_GardenerC_SingleShot", "M_Gardener_SingleShot_1", 5001010, 3233, 5},
    {Table::command, "M_GardenerC_MultipleShot", "M_Gardener_SingleShot_1", 5001011, 3238, 5},
    {Table::command, "M_GardenerC_ToxicBeam", "M_Gardener_SingleShot_1", 5001012, 3243, 5},
    {Table::stance, "M_GardenerC_Default", "M_Gardener_Default", 500101, 3248, 20},
    {Table::character, "M_Gardener_Skulling", "M_Maelstrom", 50011, 3268, 63},
    {Table::character, "M_Gardener_Half", "M_Maelstrom", 50012, 3331, 63},
    {Table::character, "M_Gardener", "M_Maelstrom", 50010, 3394, 63},
};
// The Tendril's own batch (coop tendril fight), added on its own ask after its own checks: 107 rows (character 1,
// appearance 1, dead 1, stance 1, anim 2, command 11, skill 11, step 45, move 1, filter 28, result 5), 1281 fields,
// every field authored over the Lion's template rows. M_TendrilC (50060) with M_Skulling_AI_Test. Its 11 skills
// play its own clips through Shows cut/tendril.lua builds in memory (copies of
// CH_M_NA_01_Gardener/Skill/M_Gardener_ToxicBeam in StellarCoop/Tendril, a package of its own); each Hit step is a
// window of the clip where its chain ends strike (2500 cm/s or faster, 250 cm or farther out) and hits by area, a
// 3D arc 200 cm high. Per skill, its range (straight ahead, the first hit's reach times 0.6087) and each hit: its
// time in the clip, its reach and its arc (degrees wide, around degrees right of the front):
//   SwingLeft: range 260 cm; 0.867-1.333 s 420 cm 150 around 0
//   SwingRight: range 260 cm; 0.800-1.267 s 410 cm 160 around 0
//   WhipLeft: range 280 cm; 0.333-0.667 s 470 cm 160 around -70
//   WhipRight: range 300 cm; 0.400-0.700 s 510 cm 130 around 50
//   DiagonalLeft: range 240 cm; 1.000-1.367 s 400 cm 140 around -20
//   DiagonalRight: range 250 cm; 0.933-1.333 s 400 cm 190 around 20
//   Chop: range 400 cm; 1.967-2.267 s 660 cm 60 around 0
//   Spin: range 240 cm; 1.967-2.533 s 400 cm 340 around 0
//   Rush: range 270 cm; 0.667-0.900 s 480 cm 160 around -20; 1.133-1.533 s 530 cm 200 around 30; 2.800-2.967 s 580 cm
//   60 around 0; 3.100-3.400 s 750 cm 60 around -10
//   Whip: range 340 cm; 0.867-0.967 s 560 cm 60 around 0; 1.700-2.233 s 530 cm 210 around -10; 3.367-3.667 s 580 cm
//   200 around -10
//   Trace: range 250 cm; 0.700-1.100 s 420 cm 260 around 0; 1.733-2.200 s 430 cm 200 around 60
constexpr Row kTendrilRecipe[] = {
    {Table::result, "M_TendrilC_Result_Light", "M_Behemoth_ScratchLeft_Parry1", 500600000, 3457, 14},
    {Table::result, "M_TendrilC_Result_Strong", "M_Behemoth_ScratchLeft_Parry1", 500600001, 3471, 14},
    {Table::result, "M_TendrilC_Result_KnockDown", "M_Behemoth_ScratchLeft_Parry1", 500600002, 3485, 14},
    {Table::result, "M_TendrilC_Result_Guard", "M_Behemoth_ScratchLeft_Parry1", 500600003, 3499, 4},
    {Table::result, "M_TendrilC_Result_Parry", "M_Behemoth_ScratchLeft_Parry1", 500600004, 3503, 3},
    {Table::filter, "M_TendrilC_SwingLeft_HitArea1", "M_Behemoth_HitArea", 5006000, 3506, 8},
    {Table::filter, "M_TendrilC_SwingLeft_Target", "M_Behemoth_HitArea", 5006001, 3514, 8},
    {Table::filter, "M_TendrilC_SwingRight_HitArea1", "M_Behemoth_HitArea", 5006002, 3522, 8},
    {Table::filter, "M_TendrilC_SwingRight_Target", "M_Behemoth_HitArea", 5006003, 3530, 8},
    {Table::filter, "M_TendrilC_WhipLeft_HitArea1", "M_Behemoth_HitArea", 5006004, 3538, 9},
    {Table::filter, "M_TendrilC_WhipLeft_Target", "M_Behemoth_HitArea", 5006005, 3547, 8},
    {Table::filter, "M_TendrilC_WhipRight_HitArea1", "M_Behemoth_HitArea", 5006006, 3555, 9},
    {Table::filter, "M_TendrilC_WhipRight_Target", "M_Behemoth_HitArea", 5006007, 3564, 8},
    {Table::filter, "M_TendrilC_DiagonalLeft_HitArea1", "M_Behemoth_HitArea", 5006008, 3572, 9},
    {Table::filter, "M_TendrilC_DiagonalLeft_Target", "M_Behemoth_HitArea", 5006009, 3581, 8},
    {Table::filter, "M_TendrilC_DiagonalRight_HitArea1", "M_Behemoth_HitArea", 5006010, 3589, 9},
    {Table::filter, "M_TendrilC_DiagonalRight_Target", "M_Behemoth_HitArea", 5006011, 3598, 8},
    {Table::filter, "M_TendrilC_Chop_HitArea1", "M_Behemoth_HitArea", 5006012, 3606, 8},
    {Table::filter, "M_TendrilC_Chop_Target", "M_Behemoth_HitArea", 5006013, 3614, 8},
    {Table::filter, "M_TendrilC_Spin_HitArea1", "M_Behemoth_HitArea", 5006014, 3622, 8},
    {Table::filter, "M_TendrilC_Spin_Target", "M_Behemoth_HitArea", 5006015, 3630, 8},
    {Table::filter, "M_TendrilC_Rush_HitArea1", "M_Behemoth_HitArea", 5006016, 3638, 9},
    {Table::filter, "M_TendrilC_Rush_HitArea2", "M_Behemoth_HitArea", 5006017, 3647, 9},
    {Table::filter, "M_TendrilC_Rush_HitArea3", "M_Behemoth_HitArea", 5006018, 3656, 8},
    {Table::filter, "M_TendrilC_Rush_HitArea4", "M_Behemoth_HitArea", 5006019, 3664, 9},
    {Table::filter, "M_TendrilC_Rush_Target", "M_Behemoth_HitArea", 5006020, 3673, 8},
    {Table::filter, "M_TendrilC_Whip_HitArea1", "M_Behemoth_HitArea", 5006021, 3681, 8},
    {Table::filter, "M_TendrilC_Whip_HitArea2", "M_Behemoth_HitArea", 5006022, 3689, 9},
    {Table::filter, "M_TendrilC_Whip_HitArea3", "M_Behemoth_HitArea", 5006023, 3698, 9},
    {Table::filter, "M_TendrilC_Whip_Target", "M_Behemoth_HitArea", 5006024, 3707, 8},
    {Table::filter, "M_TendrilC_Trace_HitArea1", "M_Behemoth_HitArea", 5006025, 3715, 8},
    {Table::filter, "M_TendrilC_Trace_HitArea2", "M_Behemoth_HitArea", 5006026, 3723, 9},
    {Table::filter, "M_TendrilC_Trace_Target", "M_Behemoth_HitArea", 5006027, 3732, 8},
    {Table::move, "M_TendrilC_Turn", "M_Behemoth_ScratchLeft_Move2", 5006000, 3740, 16},
    {Table::step, "M_TendrilC_SwingLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600002, 3756, 8},
    {Table::step, "M_TendrilC_SwingLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600003, 3764, 24},
    {Table::step, "M_TendrilC_SwingLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600004, 3788, 5},
    {Table::skill, "M_TendrilC_SwingLeft", "M_Behemoth_ScratchLeft", 5006000, 3793, 13},
    {Table::step, "M_TendrilC_SwingRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600102, 3806, 8},
    {Table::step, "M_TendrilC_SwingRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600103, 3814, 24},
    {Table::step, "M_TendrilC_SwingRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600104, 3838, 5},
    {Table::skill, "M_TendrilC_SwingRight", "M_Behemoth_ScratchLeft", 5006001, 3843, 13},
    {Table::step, "M_TendrilC_WhipLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600202, 3856, 8},
    {Table::step, "M_TendrilC_WhipLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600203, 3864, 24},
    {Table::step, "M_TendrilC_WhipLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600204, 3888, 5},
    {Table::skill, "M_TendrilC_WhipLeft", "M_Behemoth_ScratchLeft", 5006002, 3893, 13},
    {Table::step, "M_TendrilC_WhipRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600302, 3906, 8},
    {Table::step, "M_TendrilC_WhipRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600303, 3914, 24},
    {Table::step, "M_TendrilC_WhipRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600304, 3938, 5},
    {Table::skill, "M_TendrilC_WhipRight", "M_Behemoth_ScratchLeft", 5006003, 3943, 13},
    {Table::step, "M_TendrilC_DiagonalLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600402, 3956, 8},
    {Table::step, "M_TendrilC_DiagonalLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600403, 3964, 24},
    {Table::step, "M_TendrilC_DiagonalLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600404, 3988, 5},
    {Table::skill, "M_TendrilC_DiagonalLeft", "M_Behemoth_ScratchLeft", 5006004, 3993, 13},
    {Table::step, "M_TendrilC_DiagonalRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600502, 4006, 8},
    {Table::step, "M_TendrilC_DiagonalRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600503, 4014, 24},
    {Table::step, "M_TendrilC_DiagonalRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600504, 4038, 5},
    {Table::skill, "M_TendrilC_DiagonalRight", "M_Behemoth_ScratchLeft", 5006005, 4043, 13},
    {Table::step, "M_TendrilC_Chop_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600602, 4056, 8},
    {Table::step, "M_TendrilC_Chop_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600603, 4064, 24},
    {Table::step, "M_TendrilC_Chop_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600604, 4088, 5},
    {Table::skill, "M_TendrilC_Chop", "M_Behemoth_ScratchLeft", 5006006, 4093, 13},
    {Table::step, "M_TendrilC_Spin_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600702, 4106, 8},
    {Table::step, "M_TendrilC_Spin_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600703, 4114, 24},
    {Table::step, "M_TendrilC_Spin_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600704, 4138, 5},
    {Table::skill, "M_TendrilC_Spin", "M_Behemoth_ScratchLeft", 5006007, 4143, 13},
    {Table::step, "M_TendrilC_Rush_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600802, 4156, 8},
    {Table::step, "M_TendrilC_Rush_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600803, 4164, 23},
    {Table::step, "M_TendrilC_Rush_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500600804, 4187, 6},
    {Table::step, "M_TendrilC_Rush_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500600805, 4193, 23},
    {Table::step, "M_TendrilC_Rush_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500600806, 4216, 6},
    {Table::step, "M_TendrilC_Rush_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500600807, 4222, 23},
    {Table::step, "M_TendrilC_Rush_Cast4", "M_Behemoth_ScratchLeft_Finish1", 500600808, 4245, 6},
    {Table::step, "M_TendrilC_Rush_Hit4", "M_Behemoth_ScratchLeft_Finish1", 500600809, 4251, 24},
    {Table::step, "M_TendrilC_Rush_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600810, 4275, 5},
    {Table::skill, "M_TendrilC_Rush", "M_Behemoth_ScratchLeft", 5006008, 4280, 13},
    {Table::step, "M_TendrilC_Whip_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500600902, 4293, 8},
    {Table::step, "M_TendrilC_Whip_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500600903, 4301, 23},
    {Table::step, "M_TendrilC_Whip_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500600904, 4324, 6},
    {Table::step, "M_TendrilC_Whip_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500600905, 4330, 23},
    {Table::step, "M_TendrilC_Whip_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500600906, 4353, 6},
    {Table::step, "M_TendrilC_Whip_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500600907, 4359, 24},
    {Table::step, "M_TendrilC_Whip_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500600908, 4383, 5},
    {Table::skill, "M_TendrilC_Whip", "M_Behemoth_ScratchLeft", 5006009, 4388, 13},
    {Table::step, "M_TendrilC_Trace_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500601002, 4401, 8},
    {Table::step, "M_TendrilC_Trace_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500601003, 4409, 23},
    {Table::step, "M_TendrilC_Trace_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500601004, 4432, 6},
    {Table::step, "M_TendrilC_Trace_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500601005, 4438, 24},
    {Table::step, "M_TendrilC_Trace_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500601006, 4462, 5},
    {Table::skill, "M_TendrilC_Trace", "M_Behemoth_ScratchLeft", 5006010, 4467, 13},
    {Table::command, "M_TendrilC_SwingLeft", "M_Behemoth_ScratchLeft", 5006000, 4480, 6},
    {Table::command, "M_TendrilC_SwingRight", "M_Behemoth_ScratchLeft", 5006001, 4486, 6},
    {Table::command, "M_TendrilC_WhipLeft", "M_Behemoth_ScratchLeft", 5006002, 4492, 6},
    {Table::command, "M_TendrilC_WhipRight", "M_Behemoth_ScratchLeft", 5006003, 4498, 6},
    {Table::command, "M_TendrilC_DiagonalLeft", "M_Behemoth_ScratchLeft", 5006004, 4504, 6},
    {Table::command, "M_TendrilC_DiagonalRight", "M_Behemoth_ScratchLeft", 5006005, 4510, 6},
    {Table::command, "M_TendrilC_Chop", "M_Behemoth_ScratchLeft", 5006006, 4516, 6},
    {Table::command, "M_TendrilC_Spin", "M_Behemoth_ScratchLeft", 5006007, 4522, 6},
    {Table::command, "M_TendrilC_Rush", "M_Behemoth_ScratchLeft", 5006008, 4528, 6},
    {Table::command, "M_TendrilC_Whip", "M_Behemoth_ScratchLeft", 5006009, 4534, 6},
    {Table::command, "M_TendrilC_Trace", "M_Behemoth_ScratchLeft", 5006010, 4540, 6},
    {Table::anim, "M_TendrilC_Peaceful", "M_Behemoth_Battle", 500600, 4546, 45},
    {Table::anim, "M_TendrilC_Battle", "M_Behemoth_Battle", 500601, 4591, 45},
    {Table::stance, "M_TendrilC_Default", "M_Behemoth_Default", 500600, 4636, 19},
    {Table::dead, "M_TendrilC", "M_Behemoth", 0, 4655, 27},
    {Table::appearance, "M_TendrilC", "M_Behemoth", 50060, 4682, 2},
    {Table::character, "M_TendrilC", "M_Behemoth", 50060, 4684, 54},
};
// The Shock Bolt's own batch (the Night Operation shop's Shock Bolt), added on its own ask after its own checks: 4
// near copies of shipped rows (skill 1, result 1, item 1, projectile 1), 87 fields, 22 of them changed from the
// template's value. Only a Shock Bolt buy asks for it, so its rows never stand in front of the Lion's, and
// lion/shock.h grows the two lists the ammo needs once it is in.
constexpr Row kBoltRecipe[] = {
    {Table::item, "Bullet_Shock", "Bullet_Scatter", 32, 4738, 23},
    {Table::skill, "P_Eve_Gun_ShootShockSlug1_1", "P_Eve_Gun_ShootScatterSlug1_1", 1003401, 4761, 17},
    {Table::projectile, "P_Eve_Gun_ShootShockSlug1_Projectile1", "P_Eve_Gun_ShootSlug1_Projectile1", 1010051, 4778, 34},
    {Table::result, "P_Eve_Gun_ShootShockSlug1_Projectile1_Hit1", "P_Eve_Gun_ShootSlug1_Projectile1_Hit1", 100200801,
     4812, 13},
};
// ---- End of the generated part ----

// ---- Matrix XIII's batch (coop mxiii), written by hand: the generator holds no zone table ----
// Zone_DLC02_10 (ZoneTable 2800, world DLCMatrix13, whose map no pak ships: the zMXIII_P test pak adds it) has no camp,
// so SB's camp travel (game/travel.h) cannot reach it. These 2 rows give it one: the camp, then the ZoneEnvSpawnTable
// row whose TargetCamp names it, so that the camp's first env-spawn row leads to Zone_DLC02_10 and that zone's world.
// Free names and IDs in the build 24463856 dumps. Struct sizes and offsets from the SDK (stellar-sdk-647527f); neither
// struct has a Transient field.
constexpr TableInfo kZoneTables[] = {
    {"ZoneCampTable", 0xa8, true, {}},      // SBZoneCampTableProperty
    {"ZoneEnvSpawnTable", 0x508, true, {}}, // SBZoneEnvSpawnTableProperty
};
static_assert(sizeof kZoneTables / sizeof kZoneTables[0] == kTableCount - kGeneratedTables, "a zone table each");
static_assert(kTables[kGeneratedTables - 1].name && !kTables[kGeneratedTables].name,
              "the generated kTables fills the first kGeneratedTables entries only");
// A table's info: kTables' for the generated tables, kZoneTables' for the two after them.
constexpr const TableInfo &table_info(Table t) {
  return size_t(t) < kGeneratedTables ? kTables[size_t(t)] : kZoneTables[size_t(t) - kGeneratedTables];
}
// The camp is ME01_Camp_03 (a Matrix 11 FullCamp) with its world map display off; the env-spawn row is the DLC02_10
// camp kit's activation-only row DLC02_10_EnvS_425 (ZoneList Zone_DLC02_10) with its own actor name and the new camp.
constexpr Patch kMxiiiPatches[] = {
    // DLC02_10_Camp_01 (ZoneCampTable, Matrix XIII)
    {0x28, Kind::u8, 3, nullptr}, // CampType
    {0x6c, Kind::u8, 5, nullptr}, // CampDisplayType
    // DLC02_10_EnvS_900 (ZoneEnvSpawnTable, Matrix XIII)
    {0x30, Kind::name, 0, "DLC02_10_EnvS_900"}, // EnvActorName
    {0x270, Kind::name, 0, "DLC02_10_Camp_01"}, // TargetCamp
};
constexpr Row kMxiiiRecipe[] = {
    {Table::camp, "DLC02_10_Camp_01", "ME01_Camp_03", 280001, 0, 2},
    {Table::env, "DLC02_10_EnvS_900", "DLC02_10_EnvS_425", 2800032900u, 2, 2},
};

constexpr size_t kRows = sizeof kRecipe / sizeof kRecipe[0];
constexpr size_t kGardenerRows = sizeof kGardenerRecipe / sizeof kGardenerRecipe[0];
constexpr size_t kTendrilRows = sizeof kTendrilRecipe / sizeof kTendrilRecipe[0];
constexpr size_t kBoltRows = sizeof kBoltRecipe / sizeof kBoltRecipe[0];
constexpr size_t kMxiiiRows = sizeof kMxiiiRecipe / sizeof kMxiiiRecipe[0];
// A batch: its rows, the patches their first and count index (the generated kPatches unless said) and its word, which
// starts its status line, its log lines and Lua's request for it (link/protocol.h's kRowWords).
struct Batch {
  const char *word;
  const Row *rows;
  size_t count;
  const Patch *patches = kPatches;
};
constexpr Batch kLion{"lion", kRecipe, kRows}, kGardener{"gardener", kGardenerRecipe, kGardenerRows},
    kTendril{"tendril", kTendrilRecipe, kTendrilRows}, kBolt{"bolt", kBoltRecipe, kBoltRows},
    kMxiii{"mxiii", kMxiiiRecipe, kMxiiiRows, kMxiiiPatches};

// FName's own split of a trailing number (UE 4.26 ParseNumber), so our FNames equal those SB makes from the same text:
// "X_1" is "X" with the internal number 2; "X_04", "X_" and "X" keep their whole text and number 0.
struct NameParts {
  size_t len;
  uint32_t number;
};
inline NameParts split_number(const char *text) {
  const size_t len = std::strlen(text);
  size_t digits = 0;
  while (digits < len && text[len - 1 - digits] >= '0' && text[len - 1 - digits] <= '9')
    ++digits;
  const char *first = text + len - digits;
  if (!digits || digits == len || first[-1] != '_' || digits > 10 || (digits > 1 && *first == '0'))
    return {len, 0};
  uint64_t n = 0;
  for (size_t i = 0; i < digits; ++i)
    n = n * 10 + uint64_t(first[i] - '0');
  return n < 0x7fffffff ? NameParts{len - 1 - digits, uint32_t(n + 1)} : NameParts{len, 0};
}

// Why a run stopped. table: not SB's UDataTable (its vtable or AddRow slot); size: its row struct's size is not the
// SDK's; fname: no FName for a name; name: a row of the new name is already in the table; id: the new ID is taken;
// donor: the template row is missing; pool: the block's pool is full; busy, net, unread: the gate stayed shut for
// kGateTicks (a logic task in flight, the net mode not 0, no logic or net-mode global yet); off: coop off.
enum class Why : uint8_t { none, table, size, fname, name, id, donor, pool, busy, net, unread, off };
inline const char *why_word(Why w) {
  static const char *const kWords[] = {"none",  "table", "size", "fname", "name",   "id",
                                       "donor", "pool",  "busy", "net",   "unread", "coop_off"};
  return kWords[size_t(w)];
}
constexpr uint32_t kGateTicks = 300; // Frames an ask waits for the gate before it is refused.

// What the game thread did: nothing asked, an ask waiting for the gate, every row in, a refusal or the latch's fault.
enum class State : uint8_t { off, waiting, rows, refused, fault };
struct Answer {
  State state = State::off;
  Why why = Why::none;
  uint8_t added = 0;   // Rows in so far.
  uint8_t row = 0;     // refused: the row it stopped at, the batch's count for the gate or coop off.
  uint32_t detail = 0; // size: the size read (24 bits); net: the net mode read.
};
static_assert(kRows < 256 && kGardenerRows < 256 && kTendrilRows < 256 && kBoltRows < 256 && kMxiiiRows < 256,
              "a row index fits a byte");
// One word for the worker, so it never reads half an answer: detail 0-23, row 24-31, added 32-39, why 40-43, state
// 44-47, and the asks the game thread finished in 48-63.
inline uint64_t pack(const Answer &a, uint32_t asks) {
  return uint64_t(asks & 0xffff) << 48 | uint64_t(a.state) << 44 | uint64_t(a.why) << 40 | uint64_t(a.added) << 32 |
         uint64_t(a.row) << 24 | (a.detail & 0xffffff);
}
inline Answer unpack(uint64_t w, uint32_t &asks) {
  Answer a;
  asks = uint32_t(w >> 48);
  a.state = State((w >> 44) & 15), a.why = Why((w >> 40) & 15);
  a.added = uint8_t(w >> 32), a.row = uint8_t(w >> 24), a.detail = uint32_t(w & 0xffffff);
  return a;
}

// The rows of one table kind in a batch.
inline uint32_t rows_of(const Batch &b, Table t) {
  uint32_t n = 0;
  for (size_t i = 0; i < b.count; ++i)
    n += b.rows[i].table == t;
  return n;
}

// rows.h's Game: the glue's (glue/tick/lion_game.inc) or a test's. read (the tables' headers only, false when
// unmapped) and write (the block only); name(text, len, number): FName's MakeWithNumber with FNAME_Add, as a word
// (ComparisonIndex, then Number in the high half; 0 is None); find(table, name): the row by name in the table's
// RowMap, whatever its row struct (not SB's FindRow FUN_141aa8760, which knows CharacterTable's only), or 0;
// id_name(table, id): the row name the table's ID map holds for id (FUN_141a2ce50), or 0; construct(struct, row):
// InitializeStruct (the struct's vtable +0x2a8); copy(struct, dest, src): CopyScriptStruct; add(add_row, table, name,
// row): the AddRow the table's slot holds. For the read-back: character(id) and skill(id), SB's own row lookups by ID
// through its table registry (FUN_141a9de20, FUN_141a9d900), and stance(id), the stance's row name by ID
// (FUN_141a2cef0).
class Builder {
public:
  explicit Builder(const Batch &batch) : batch_(batch) {}
  // One run over the batch (see the top of this file). tables: the 17 tables' addresses as Lua found them, in Table's
  // order; block: kBlock bytes of the glue's, 16-aligned; base: SB's image base. Runs every row not added yet and
  // stops at the first refusal.
  template <class Game> Answer run(Game &g, uint64_t base, const uint64_t (&tables)[kTableCount], uint64_t block) {
    Answer a;
    a.state = State::refused;
    uint64_t structs[kTableCount] = {}, add_row = base + (kAddRow - kImageBase);
    // Every table the batch's rows go into before any row (a wrong address adds nothing); the others are never read.
    for (size_t t = 0; t < kTableCount; ++t) {
      uint64_t vtable = 0, slot = 0;
      int32_t size = 0;
      a.row = first_row(Table(t));
      if (a.row == batch_.count)
        continue;
      if (!g.read(tables[t], &vtable, 8) || vtable != base + (kTableVtable - kImageBase) ||
          !g.read(vtable + kAddRowSlot, &slot, 8) || slot != add_row ||
          !g.read(tables[t] + kRowStruct, &structs[t], 8) || !structs[t])
        return a.why = Why::table, a.added = uint8_t(count_), a;
      if (!g.read(structs[t] + kPropertiesSize, &size, 4) || uint32_t(size) != table_info(Table(t)).size)
        return a.why = Why::size, a.detail = uint32_t(size) & 0xffffff, a.added = uint8_t(count_), a;
    }
    for (size_t i = 0; i < batch_.count; ++i) {
      if (added_[i])
        continue;
      a.row = uint8_t(i);
      const Row &r = batch_.rows[i];
      const TableInfo &info = table_info(r.table);
      const uint64_t table = tables[size_t(r.table)], rs = structs[size_t(r.table)];
      const uint64_t name = make(g, r.name), donor_name = make(g, r.donor);
      if (!name || !donor_name)
        return a.why = Why::fname, a.added = uint8_t(count_), a;
      if (g.find(table, name))
        return a.why = Why::name, a.added = uint8_t(count_), a;
      if (info.id && g.id_name(table, r.id))
        return a.why = Why::id, a.added = uint8_t(count_), a;
      const uint64_t donor = g.find(table, donor_name);
      if (!donor)
        return a.why = Why::donor, a.added = uint8_t(count_), a;
      g.construct(rs, block);
      g.copy(rs, block, donor);
      const uint8_t fresh = 0;
      g.write(block + kInitFlag, &fresh, 1);
      if (info.id)
        g.write(block + kIdAt, &r.id, 4);
      static const uint8_t kEmpty[16] = {};
      for (uint16_t at : info.transient)
        if (at)
          g.write(block + at, kEmpty, sizeof kEmpty);
      uint64_t pool = block + kRowBytes;
      for (size_t p = r.first; p < size_t(r.first) + r.count; ++p)
        if (const Why why = patch(g, block, batch_.patches[p], pool, block + kBlock); why != Why::none)
          return a.why = why, a.added = uint8_t(count_), a;
      g.add(add_row, table, name, block);
      added_[i] = true;
      ++count_;
    }
    a.state = State::rows, a.why = Why::none, a.row = 0, a.added = uint8_t(count_);
    return a;
  }

  // What SB's own lookups by ID give back for the batch's rows (glue's R3 log line, the status's char=, skills= and
  // stance=): how many of the CharacterTable and SkillTable rows its registry lookups find as the row of our name, and
  // how many stance IDs give our row name.
  struct ReadBack {
    uint8_t character = 0, skills = 0, stance = 0;
  };
  template <class Game> ReadBack read_back(Game &g, const uint64_t (&tables)[kTableCount]) const {
    ReadBack b;
    for (size_t i = 0; i < batch_.count; ++i) {
      const Row &r = batch_.rows[i];
      const uint64_t name = make(g, r.name), table = tables[size_t(r.table)];
      if (r.table == Table::character)
        b.character += name && g.character(r.id) == g.find(table, name) && g.character(r.id);
      else if (r.table == Table::skill)
        b.skills += name && g.skill(r.id) == g.find(table, name) && g.skill(r.id);
      else if (r.table == Table::stance)
        b.stance += name && g.stance(r.id) == name;
    }
    return b;
  }

  bool added(size_t i) const { return added_[i]; }
  uint32_t count() const { return count_; }

private:
  uint8_t first_row(Table t) const {
    for (size_t i = 0; i < batch_.count; ++i)
      if (batch_.rows[i].table == t)
        return uint8_t(i);
    return uint8_t(batch_.count);
  }
  template <class Game> static uint64_t make(Game &g, const char *text) {
    const NameParts p = split_number(text);
    return g.name(text, p.len, p.number);
  }

public: // For the test's pool and FName cases, which the recipe's own data never reaches.
  // The pool's next 8-aligned n bytes, or 0 when they do not fit.
  static uint64_t take(uint64_t &pool, uint64_t end, size_t n) {
    const uint64_t at = (pool + 7) & ~uint64_t(7);
    if (at + n > end)
      return 0;
    pool = at + n;
    return at;
  }
  // An FString header {data, num, max} for text (its first len characters), its UTF-16 characters and NUL in the
  // pool; {0, 0, 0} when empty, as UE keeps an empty FString.
  template <class Game>
  static bool string(Game &g, const char *text, size_t len, uint64_t &pool, uint64_t end, uint8_t (&header)[16]) {
    std::memset(header, 0, sizeof header);
    if (!len)
      return true;
    const uint64_t at = take(pool, end, 2 * (len + 1));
    if (!at)
      return false;
    for (size_t k = 0; k <= len; ++k) {
      const uint16_t c = k < len ? uint8_t(text[k]) : 0;
      g.write(at + 2 * k, &c, 2);
    }
    const int32_t n = int32_t(len + 1);
    std::memcpy(header, &at, 8);
    std::memcpy(header + 8, &n, 4);
    std::memcpy(header + 12, &n, 4);
    return true;
  }
  template <class Game> static Why patch(Game &g, uint64_t row, const Patch &p, uint64_t &pool, uint64_t end) {
    if (p.kind == Kind::f32) {
      g.write(row + p.at, &p.f, 4);
      return Why::none;
    }
    if (p.kind == Kind::i32) {
      const int32_t v = int32_t(p.f);
      g.write(row + p.at, &v, 4);
      return Why::none;
    }
    if (p.kind == Kind::u8) {
      const uint8_t v = uint8_t(p.f);
      g.write(row + p.at, &v, 1);
      return Why::none;
    }
    if (p.kind == Kind::name) {
      const uint64_t name = make(g, p.text);
      if (!name && std::strcmp(p.text, "None") != 0)
        return Why::fname;
      g.write(row + p.at, &name, 8);
      return Why::none;
    }
    uint8_t header[16];
    if (p.kind == Kind::string) {
      if (!string(g, p.text, std::strlen(p.text), pool, end, header))
        return Why::pool;
      g.write(row + p.at, header, 16);
      return Why::none;
    }
    // A list: its items in the pool (8 bytes an FName, 16 an FString header), then the header over the field.
    int32_t n = *p.text != 0;
    for (const char *c = p.text; *c; ++c)
      n += *c == '|';
    const size_t item = p.kind == Kind::names ? 8 : 16;
    const uint64_t items = n ? take(pool, end, item * size_t(n)) : 0;
    if (n && !items)
      return Why::pool;
    const char *at = p.text;
    for (int32_t k = 0; k < n; ++k) {
      const char *bar = std::strchr(at, '|');
      const size_t len = bar ? size_t(bar - at) : std::strlen(at);
      if (p.kind == Kind::names) {
        char text[128];
        if (len >= sizeof text)
          return Why::fname;
        std::memcpy(text, at, len);
        text[len] = 0;
        const uint64_t name = make(g, text);
        if (!name)
          return Why::fname;
        g.write(items + 8 * uint64_t(k), &name, 8);
      } else {
        uint8_t s[16];
        if (!string(g, at, len, pool, end, s))
          return Why::pool;
        g.write(items + 16 * uint64_t(k), s, 16);
      }
      at = bar ? bar + 1 : at + len;
    }
    std::memset(header, 0, sizeof header);
    if (n) {
      std::memcpy(header, &items, 8);
      std::memcpy(header + 8, &n, 4);
      std::memcpy(header + 12, &n, 4);
    }
    g.write(row + p.at, header, 16);
    return Why::none;
  }

private:
  const Batch &batch_;
  bool added_[256] = {};
  uint32_t count_ = 0;
};

// coop-status.txt's line for a batch (cut/lion.lua reads lion= and bolt=, cut/gardener.lua gardener=, cut/tendril.lua
// tendril=, cut/mxiii.lua mxiii=), from its answer word, its read-back, the frames its ask waited, the spawn manager's
// counter and, after
// the latch, where the fault was:
//   <word>=off
//   <word>=waiting added=<n>/<N> asks=<a> spawns=<s> why=<busy|net|unread> ticks=<t>
//   <word>=rows added=<N>/<N> asks=<a> spawns=<s> char=<k>/<n> skills=<k>/<n> stance=<k>/<n>
//   <word>=refused added=<n>/<N> asks=<a> spawns=<s> why=<word> table=<Table|-> row=<Row|->[ detail=<value>]
//   <word>=fault added=<n>/<N> asks=<a> spawns=<s> where=<text, maybe with spaces>
// asks: the asks the game thread finished (a new answer when it grows); spawns: the int32 at the spawn manager's
// +0x198, "?" until read. detail: the size read as 0x<hex> (why=size) or the net mode read (why=net).
struct Status {
  uint64_t word = 0;
  Builder::ReadBack read;
  uint32_t ticks = 0;
  bool spawns_read = false;
  int32_t spawns = 0;
  std::string fault; // Where, once the latch closed.
};
inline std::string status_line(const Batch &b, const Status &s) {
  uint32_t asks = 0;
  const Answer a = unpack(s.word, asks);
  if (a.state == State::off)
    return std::string(b.word) + "=off";
  static const char *const kStates[] = {"off", "waiting", "rows", "refused", "fault"};
  std::string line = std::string(b.word) + "=" + kStates[size_t(a.state)] + " added=" + std::to_string(a.added) + "/" +
                     std::to_string(b.count) + " asks=" + std::to_string(asks) +
                     " spawns=" + (s.spawns_read ? std::to_string(s.spawns) : std::string("?"));
  const auto count = [&b](uint32_t k, Table t) { return std::to_string(k) + "/" + std::to_string(rows_of(b, t)); };
  if (a.state == State::waiting)
    line += std::string(" why=") + why_word(a.why) + " ticks=" + std::to_string(s.ticks);
  else if (a.state == State::rows)
    line += " char=" + count(s.read.character, Table::character) + " skills=" + count(s.read.skills, Table::skill) +
            " stance=" + count(s.read.stance, Table::stance);
  else if (a.state == State::refused) {
    const bool row = a.row < b.count;
    line += std::string(" why=") + why_word(a.why) +
            " table=" + (row ? table_info(b.rows[a.row].table).name : "-") +
            " row=" + (row ? b.rows[a.row].name : "-");
    char detail[24] = "";
    if (a.why == Why::size)
      std::snprintf(detail, sizeof detail, " detail=0x%x", unsigned(a.detail));
    else if (a.why == Why::net)
      std::snprintf(detail, sizeof detail, " detail=%u", unsigned(a.detail));
    line += detail;
  } else if (a.state == State::fault)
    line += " where=" + s.fault;
  return line;
}
// The log line for a batch's answer (coop-link.log), as the test campaign's R2 reads it.
inline std::string describe(const Batch &b, const Answer &a) {
  const std::string added = std::to_string(a.added) + "/" + std::to_string(b.count);
  if (a.state == State::rows)
    return std::string(b.word) + " rows: " + added + " added through SB's AddRow 0x14417ba30, 0 refused";
  if (a.state != State::refused)
    return std::string(b.word) + " rows: " + added + " added";
  const bool row = a.row < b.count;
  const Row &r = b.rows[row ? a.row : 0];
  const TableInfo &info = table_info(r.table);
  char why[160];
  switch (a.why) {
  case Why::table: std::snprintf(why, sizeof why, "%s is not SB's UDataTable", info.name); break;
  case Why::size:
    std::snprintf(why, sizeof why, "%s's row size 0x%x not 0x%x", info.name, unsigned(a.detail), unsigned(info.size));
    break;
  case Why::fname: std::snprintf(why, sizeof why, "the game made no FName"); break;
  case Why::name: std::snprintf(why, sizeof why, "a row of that name is already in %s", info.name); break;
  case Why::id: std::snprintf(why, sizeof why, "ID %u taken", unsigned(r.id)); break;
  case Why::donor: std::snprintf(why, sizeof why, "template %s missing", r.donor); break;
  case Why::pool: std::snprintf(why, sizeof why, "its strings overflow the pool"); break;
  case Why::busy: std::snprintf(why, sizeof why, "logic busy %u frames", unsigned(kGateTicks)); break;
  case Why::net:
    std::snprintf(why, sizeof why, "net mode %u for %u frames", unsigned(a.detail), unsigned(kGateTicks));
    break;
  case Why::unread:
    std::snprintf(why, sizeof why, "no logic or net-mode global for %u frames", unsigned(kGateTicks));
    break;
  case Why::off: std::snprintf(why, sizeof why, "coop off"); break;
  default: std::snprintf(why, sizeof why, "?"); break;
  }
  return std::string(b.word) + " rows refused " + (row ? r.name : "-") + ": " + why + "; " + added + " added";
}
// The log line for a batch's read-back (the campaign's R3): the IDs asked of each lookup and how many gave our row ("-"
// for a table the batch has no row in, as the bolt batch's CharacterTable and stance).
inline std::string describe_read(const Batch &batch, const Builder::ReadBack &b) {
  const auto ids = [&batch](Table t) {
    uint32_t low = UINT32_MAX, high = 0;
    for (size_t i = 0; i < batch.count; ++i)
      if (const Row &r = batch.rows[i]; r.table == t)
        low = r.id < low ? r.id : low, high = r.id > high ? r.id : high;
    if (low > high)
      return std::string("-");
    return low == high ? std::to_string(low) : std::to_string(low) + "-" + std::to_string(high);
  };
  const auto count = [&batch](uint32_t k, Table t) {
    return std::to_string(k) + "/" + std::to_string(rows_of(batch, t));
  };
  return std::string(batch.word) + " rows by SB's lookups: CharacterTable " + ids(Table::character) + " " +
         count(b.character, Table::character) + ", SkillTable " + ids(Table::skill) + " " +
         count(b.skills, Table::skill) + ", stance " + ids(Table::stance) + " " + count(b.stance, Table::stance);
}

} // namespace coop::lion
