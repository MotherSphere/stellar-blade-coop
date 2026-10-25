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
// SB reads CharacterTable, SkillTable and CharacterStanceTable by ID through maps that only its own AddRow fills (the
// table's vtable slot +0x2b0), so every row goes in through that call, on the game thread with no logic task in flight
// (glue/tick/lion_game.inc's gate: no lock guards the tables). For each row not added yet, in order: the table must be
// SB's UDataTable with its row struct of the size the SDK gives; the new name must be free in RowMap and the new ID
// free in the table's ID map; the template is found by name; then the row is built in a block the glue owns
// (InitializeStruct, CopyScriptStruct from the template, the ID at +0x10, the patches) and handed to AddRow, which
// removes any row of that name, copies ours into its own allocation and fills the ID and index maps. The first refusal
// stops the run before any later row, and the CharacterTable rows come last, so NewActor finds 50020 only once every
// other row is in. A row is added once a run: a later run skips it, so AddRow's RemoveRow never frees a row a Lion
// still reads.
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

// The 12 tables, in coop::kLionTables' order (link/protocol.h): Lua's lion rows request names each with its address.
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
  effect
};
constexpr size_t kTableCount = 12;
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
// The Lion's own rows: 222 in all (character 2, appearance 1, dead 1, stance 2, anim 2, command 21, skill 21, step
// 80, move 61, filter 25, result 5, effect 1), 2991 fields. 2087 of them set a field the template row held, 894 of
// those to the value it held (the Lion's value is the same); the other 904 fill fields it left empty. From the
// offline reader's dumps of the 12 tables, the Lion Shows, the Large blueprint and its CH_M_NA_02_LionC_Collision,
// the pak listing, the Dumper-7 SDK (stellar-sdk-647527f) and the Lion's animation points (lion-points.json).
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
    {"EffectTable", 0x588, true, {0x578}}, // SBEffectTableProperty
};
constexpr Patch kPatches[] = {
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
};
constexpr Row kRecipe[] = {
    {Table::effect, "M_LionC_PhaseRoar", "M_Scarlet_CounterLinkStart", 5002000, 0, 7},
    {Table::result, "M_LionC_Result_Light", "M_Behemoth_ScratchLeft_Parry1", 500200000, 7, 14},
    {Table::result, "M_LionC_Result_Strong", "M_Behemoth_ScratchLeft_Parry1", 500200001, 21, 14},
    {Table::result, "M_LionC_Result_KnockDown", "M_Behemoth_ScratchLeft_Parry1", 500200002, 35, 14},
    {Table::result, "M_LionC_Result_Guard", "M_Behemoth_ScratchLeft_Parry1", 500200003, 49, 4},
    {Table::result, "M_LionC_Result_Parry", "M_Behemoth_ScratchLeft_Parry1", 500200004, 53, 3},
    {Table::filter, "M_LionC_HitArea", "M_Behemoth_HitArea", 5002000, 56, 6},
    {Table::filter, "M_LionC_Roar_HitArea", "M_Behemoth_HitArea", 5002001, 62, 8},
    {Table::filter, "M_LionC_ClawAttackLeft_Target", "M_Behemoth_HitArea", 5002002, 70, 8},
    {Table::filter, "M_LionC_ClawAttackRight_Target", "M_Behemoth_HitArea", 5002003, 78, 8},
    {Table::filter, "M_LionC_ClawAttackChaseLeft_Target", "M_Behemoth_HitArea", 5002004, 86, 9},
    {Table::filter, "M_LionC_ClawAttackChaseRight_Target", "M_Behemoth_HitArea", 5002005, 95, 10},
    {Table::filter, "M_LionC_TurnAttackLeft_Target", "M_Behemoth_HitArea", 5002006, 105, 9},
    {Table::filter, "M_LionC_TurnAttackRight_Target", "M_Behemoth_HitArea", 5002007, 114, 9},
    {Table::filter, "M_LionC_RunAttackLeft_Target", "M_Behemoth_HitArea", 5002008, 123, 10},
    {Table::filter, "M_LionC_RunAttackRight_Target", "M_Behemoth_HitArea", 5002009, 133, 10},
    {Table::filter, "M_LionC_JumpAttackLow_Target", "M_Behemoth_HitArea", 5002010, 143, 9},
    {Table::filter, "M_LionC_JumpAttackLow_HitArea", "M_Behemoth_HitArea", 5002011, 152, 8},
    {Table::filter, "M_LionC_JumpAttackHigh_Target", "M_Behemoth_HitArea", 5002012, 160, 9},
    {Table::filter, "M_LionC_JumpAttackHigh_HitArea", "M_Behemoth_HitArea", 5002013, 169, 8},
    {Table::filter, "M_LionC_BackJumpToAttack_Target", "M_Behemoth_HitArea", 5002014, 177, 9},
    {Table::filter, "M_LionC_AttackToBackJump_Target", "M_Behemoth_HitArea", 5002015, 186, 8},
    {Table::filter, "M_LionC_Roar_Target", "M_Behemoth_HitArea", 5002016, 194, 8},
    {Table::filter, "M_LionC_SideStepLeft_Target", "M_Behemoth_HitArea", 5002017, 202, 9},
    {Table::filter, "M_LionC_SideStepRight_Target", "M_Behemoth_HitArea", 5002018, 211, 9},
    {Table::filter, "M_LionC_ClawAttackChain_Target", "M_Behemoth_HitArea", 5002019, 220, 8},
    {Table::filter, "M_LionC_ClawAttackChain2_Target", "M_Behemoth_HitArea", 5002020, 228, 8},
    {Table::filter, "M_LionC_MoveAttackChain_Target", "M_Behemoth_HitArea", 5002021, 236, 8},
    {Table::filter, "M_LionC_RushAttack_Target", "M_Behemoth_HitArea", 5002022, 244, 9},
    {Table::filter, "M_LionC_DashAttackChain_Target", "M_Behemoth_HitArea", 5002023, 253, 8},
    {Table::filter, "M_LionC_DashAttackChain_HitArea", "M_Behemoth_HitArea", 5002024, 261, 8},
    {Table::move, "M_LionC_ClawAttackLeft_Turn", "M_Behemoth_ScratchLeft_Move2", 5002000, 269, 16},
    {Table::move, "M_LionC_ClawAttackRight_Turn", "M_Behemoth_ScratchLeft_Move2", 5002001, 285, 16},
    {Table::move, "M_LionC_ClawAttackChaseLeft_Move1", "M_Behemoth_ScratchLeft_Move2", 5002002, 301, 18},
    {Table::move, "M_LionC_ClawAttackChaseLeft_Move2", "M_Behemoth_ScratchLeft_Move2", 5002003, 319, 17},
    {Table::move, "M_LionC_ClawAttackChaseLeft_Move3", "M_Behemoth_ScratchLeft_Move2", 5002004, 336, 14},
    {Table::move, "M_LionC_ClawAttackChaseRight_Move1", "M_Behemoth_ScratchLeft_Move2", 5002005, 350, 17},
    {Table::move, "M_LionC_ClawAttackChaseRight_Move2", "M_Behemoth_ScratchLeft_Move2", 5002006, 367, 17},
    {Table::move, "M_LionC_ClawAttackChaseRight_Move3", "M_Behemoth_ScratchLeft_Move2", 5002007, 384, 17},
    {Table::move, "M_LionC_TurnAttackLeft_Turn", "M_Behemoth_ScratchLeft_Move2", 5002008, 401, 18},
    {Table::move, "M_LionC_TurnAttackRight_Turn", "M_Behemoth_ScratchLeft_Move2", 5002009, 419, 18},
    {Table::move, "M_LionC_RunAttackLeft_Move1", "M_Behemoth_ScratchLeft_Move2", 5002010, 437, 17},
    {Table::move, "M_LionC_RunAttackLeft_Move2", "M_Behemoth_ScratchLeft_Move2", 5002011, 454, 17},
    {Table::move, "M_LionC_RunAttackLeft_Move3", "M_Behemoth_ScratchLeft_Move2", 5002012, 471, 17},
    {Table::move, "M_LionC_RunAttackRight_Move1", "M_Behemoth_ScratchLeft_Move2", 5002013, 488, 17},
    {Table::move, "M_LionC_RunAttackRight_Move2", "M_Behemoth_ScratchLeft_Move2", 5002014, 505, 17},
    {Table::move, "M_LionC_RunAttackRight_Move3", "M_Behemoth_ScratchLeft_Move2", 5002015, 522, 17},
    {Table::move, "M_LionC_JumpAttackLow_Move1", "M_Behemoth_ScratchLeft_Move2", 5002016, 539, 18},
    {Table::move, "M_LionC_JumpAttackHigh_Turn", "M_Behemoth_ScratchLeft_Move2", 5002017, 557, 16},
    {Table::move, "M_LionC_JumpAttackHigh_Move2", "M_Behemoth_ScratchLeft_Move2", 5002018, 573, 17},
    {Table::move, "M_LionC_JumpAttackHigh_Move3", "M_Behemoth_ScratchLeft_Move2", 5002019, 590, 17},
    {Table::move, "M_LionC_BackJumpToAttack_Turn", "M_Behemoth_ScratchLeft_Move2", 5002020, 607, 18},
    {Table::move, "M_LionC_AttackToBackJump_Turn", "M_Behemoth_ScratchLeft_Move2", 5002021, 625, 16},
    {Table::move, "M_LionC_AttackToBackJump_Move3", "M_Behemoth_ScratchLeft_Move2", 5002022, 641, 14},
    {Table::move, "M_LionC_Roar_Turn", "M_Behemoth_ScratchLeft_Move2", 5002023, 655, 16},
    {Table::move, "M_LionC_Roar_Move3", "M_Behemoth_ScratchLeft_Move2", 5002024, 671, 14},
    {Table::move, "M_LionC_SideStepLeft_Move1", "M_Behemoth_ScratchLeft_Move2", 5002025, 685, 15},
    {Table::move, "M_LionC_SideStepRight_Move1", "M_Behemoth_ScratchLeft_Move2", 5002026, 700, 15},
    {Table::move, "M_LionC_ClawAttackChain_Move1", "M_Behemoth_ScratchLeft_Move2", 5002027, 715, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move2", "M_Behemoth_ScratchLeft_Move2", 5002028, 732, 16},
    {Table::move, "M_LionC_ClawAttackChain_Move3", "M_Behemoth_ScratchLeft_Move2", 5002029, 748, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move4", "M_Behemoth_ScratchLeft_Move2", 5002030, 765, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move5", "M_Behemoth_ScratchLeft_Move2", 5002031, 782, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move6", "M_Behemoth_ScratchLeft_Move2", 5002032, 799, 17},
    {Table::move, "M_LionC_ClawAttackChain_Move7", "M_Behemoth_ScratchLeft_Move2", 5002033, 816, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move1", "M_Behemoth_ScratchLeft_Move2", 5002034, 833, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move2", "M_Behemoth_ScratchLeft_Move2", 5002035, 850, 16},
    {Table::move, "M_LionC_ClawAttackChain2_Move4", "M_Behemoth_ScratchLeft_Move2", 5002036, 866, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move5", "M_Behemoth_ScratchLeft_Move2", 5002037, 883, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move6", "M_Behemoth_ScratchLeft_Move2", 5002038, 900, 17},
    {Table::move, "M_LionC_ClawAttackChain2_Move7", "M_Behemoth_ScratchLeft_Move2", 5002039, 917, 16},
    {Table::move, "M_LionC_ClawAttackChain2_Move8", "M_Behemoth_ScratchLeft_Move2", 5002040, 933, 16},
    {Table::move, "M_LionC_ClawAttackChain2_Move9", "M_Behemoth_ScratchLeft_Move2", 5002041, 949, 14},
    {Table::move, "M_LionC_MoveAttackChain_Move1", "M_Behemoth_ScratchLeft_Move2", 5002042, 963, 15},
    {Table::move, "M_LionC_MoveAttackChain_Move3", "M_Behemoth_ScratchLeft_Move2", 5002043, 978, 17},
    {Table::move, "M_LionC_MoveAttackChain_Move4", "M_Behemoth_ScratchLeft_Move2", 5002044, 995, 17},
    {Table::move, "M_LionC_MoveAttackChain_Move5", "M_Behemoth_ScratchLeft_Move2", 5002045, 1012, 17},
    {Table::move, "M_LionC_MoveAttackChain_Move6", "M_Behemoth_ScratchLeft_Move2", 5002046, 1029, 17},
    {Table::move, "M_LionC_RushAttack_Move1", "M_Behemoth_ScratchLeft_Move2", 5002047, 1046, 18},
    {Table::move, "M_LionC_RushAttack_Move2", "M_Behemoth_ScratchLeft_Move2", 5002048, 1064, 17},
    {Table::move, "M_LionC_RushAttack_Move3", "M_Behemoth_ScratchLeft_Move2", 5002049, 1081, 17},
    {Table::move, "M_LionC_DashAttackChain_Move1", "M_Behemoth_ScratchLeft_Move2", 5002050, 1098, 15},
    {Table::move, "M_LionC_DashAttackChain_Move2", "M_Behemoth_ScratchLeft_Move2", 5002051, 1113, 16},
    {Table::move, "M_LionC_DashAttackChain_Move3", "M_Behemoth_ScratchLeft_Move2", 5002052, 1129, 16},
    {Table::move, "M_LionC_DashAttackChain_Move4", "M_Behemoth_ScratchLeft_Move2", 5002053, 1145, 16},
    {Table::move, "M_LionC_DashAttackChain_Move5", "M_Behemoth_ScratchLeft_Move2", 5002054, 1161, 17},
    {Table::move, "M_LionC_DashAttackChain_Move6", "M_Behemoth_ScratchLeft_Move2", 5002055, 1178, 17},
    {Table::move, "M_LionC_DashAttackChain_Move7", "M_Behemoth_ScratchLeft_Move2", 5002056, 1195, 17},
    {Table::move, "M_LionC_DashAttackChain_Move8", "M_Behemoth_ScratchLeft_Move2", 5002057, 1212, 17},
    {Table::move, "M_LionC_DashAttackChain_Move9", "M_Behemoth_ScratchLeft_Move2", 5002058, 1229, 17},
    {Table::move, "M_LionC_RoarPhaseChange_Turn", "M_Behemoth_ScratchLeft_Move2", 5002059, 1246, 16},
    {Table::move, "M_LionC_RoarPhaseChange_Move3", "M_Behemoth_ScratchLeft_Move2", 5002060, 1262, 14},
    {Table::step, "M_LionC_ClawAttackLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200002, 1276, 8},
    {Table::step, "M_LionC_ClawAttackLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200003, 1284, 25},
    {Table::step, "M_LionC_ClawAttackLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200004, 1309, 5},
    {Table::skill, "M_LionC_ClawAttackLeft", "M_Behemoth_ScratchLeft", 5002000, 1314, 13},
    {Table::step, "M_LionC_ClawAttackRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200102, 1327, 8},
    {Table::step, "M_LionC_ClawAttackRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200103, 1335, 25},
    {Table::step, "M_LionC_ClawAttackRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200104, 1360, 5},
    {Table::skill, "M_LionC_ClawAttackRight", "M_Behemoth_ScratchLeft", 5002001, 1365, 13},
    {Table::step, "M_LionC_ClawAttackChaseLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200202, 1378, 8},
    {Table::step, "M_LionC_ClawAttackChaseLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200203, 1386, 25},
    {Table::step, "M_LionC_ClawAttackChaseLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200204, 1411, 5},
    {Table::skill, "M_LionC_ClawAttackChaseLeft", "M_Behemoth_ScratchLeft", 5002002, 1416, 14},
    {Table::step, "M_LionC_ClawAttackChaseRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200302, 1430, 8},
    {Table::step, "M_LionC_ClawAttackChaseRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200303, 1438, 25},
    {Table::step, "M_LionC_ClawAttackChaseRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200304, 1463, 5},
    {Table::skill, "M_LionC_ClawAttackChaseRight", "M_Behemoth_ScratchLeft", 5002003, 1468, 14},
    {Table::step, "M_LionC_TurnAttackLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200402, 1482, 8},
    {Table::step, "M_LionC_TurnAttackLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200403, 1490, 25},
    {Table::step, "M_LionC_TurnAttackLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200404, 1515, 5},
    {Table::skill, "M_LionC_TurnAttackLeft", "M_Behemoth_ScratchLeft", 5002004, 1520, 13},
    {Table::step, "M_LionC_TurnAttackRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200502, 1533, 8},
    {Table::step, "M_LionC_TurnAttackRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200503, 1541, 25},
    {Table::step, "M_LionC_TurnAttackRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200504, 1566, 5},
    {Table::skill, "M_LionC_TurnAttackRight", "M_Behemoth_ScratchLeft", 5002005, 1571, 13},
    {Table::step, "M_LionC_RunAttackLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200602, 1584, 8},
    {Table::step, "M_LionC_RunAttackLeft_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200603, 1592, 25},
    {Table::step, "M_LionC_RunAttackLeft_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200604, 1617, 5},
    {Table::skill, "M_LionC_RunAttackLeft", "M_Behemoth_ScratchLeft", 5002006, 1622, 14},
    {Table::step, "M_LionC_RunAttackRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200702, 1636, 8},
    {Table::step, "M_LionC_RunAttackRight_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200703, 1644, 25},
    {Table::step, "M_LionC_RunAttackRight_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200704, 1669, 5},
    {Table::skill, "M_LionC_RunAttackRight", "M_Behemoth_ScratchLeft", 5002007, 1674, 14},
    {Table::step, "M_LionC_JumpAttackLow_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200802, 1688, 8},
    {Table::step, "M_LionC_JumpAttackLow_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200803, 1696, 24},
    {Table::step, "M_LionC_JumpAttackLow_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200804, 1720, 5},
    {Table::skill, "M_LionC_JumpAttackLow", "M_Behemoth_ScratchLeft", 5002008, 1725, 14},
    {Table::step, "M_LionC_JumpAttackHigh_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500200902, 1739, 11},
    {Table::step, "M_LionC_JumpAttackHigh_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500200903, 1750, 19},
    {Table::step, "M_LionC_JumpAttackHigh_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500200904, 1769, 5},
    {Table::skill, "M_LionC_JumpAttackHigh", "M_Behemoth_ScratchLeft", 5002009, 1774, 14},
    {Table::step, "M_LionC_BackJumpToAttack_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201002, 1788, 8},
    {Table::step, "M_LionC_BackJumpToAttack_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201003, 1796, 25},
    {Table::step, "M_LionC_BackJumpToAttack_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201004, 1821, 5},
    {Table::skill, "M_LionC_BackJumpToAttack", "M_Behemoth_ScratchLeft", 5002010, 1826, 13},
    {Table::step, "M_LionC_AttackToBackJump_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201102, 1839, 8},
    {Table::step, "M_LionC_AttackToBackJump_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201103, 1847, 25},
    {Table::step, "M_LionC_AttackToBackJump_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201104, 1872, 5},
    {Table::skill, "M_LionC_AttackToBackJump", "M_Behemoth_ScratchLeft", 5002011, 1877, 14},
    {Table::step, "M_LionC_Roar_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201202, 1891, 12},
    {Table::step, "M_LionC_Roar_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201203, 1903, 19},
    {Table::step, "M_LionC_Roar_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201204, 1922, 5},
    {Table::skill, "M_LionC_Roar", "M_Behemoth_ScratchLeft", 5002012, 1927, 13},
    {Table::step, "M_LionC_SideStepLeft_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201302, 1940, 7},
    {Table::skill, "M_LionC_SideStepLeft", "M_Behemoth_ScratchLeft", 5002013, 1947, 14},
    {Table::step, "M_LionC_SideStepRight_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201402, 1961, 7},
    {Table::skill, "M_LionC_SideStepRight", "M_Behemoth_ScratchLeft", 5002014, 1968, 14},
    {Table::step, "M_LionC_ClawAttackChain_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201502, 1982, 8},
    {Table::step, "M_LionC_ClawAttackChain_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201503, 1990, 24},
    {Table::step, "M_LionC_ClawAttackChain_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201504, 2014, 6},
    {Table::step, "M_LionC_ClawAttackChain_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500201505, 2020, 24},
    {Table::step, "M_LionC_ClawAttackChain_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500201506, 2044, 6},
    {Table::step, "M_LionC_ClawAttackChain_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500201507, 2050, 25},
    {Table::step, "M_LionC_ClawAttackChain_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201508, 2075, 5},
    {Table::skill, "M_LionC_ClawAttackChain", "M_Behemoth_ScratchLeft", 5002015, 2080, 14},
    {Table::step, "M_LionC_ClawAttackChain2_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201602, 2094, 8},
    {Table::step, "M_LionC_ClawAttackChain2_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201603, 2102, 24},
    {Table::step, "M_LionC_ClawAttackChain2_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201604, 2126, 6},
    {Table::step, "M_LionC_ClawAttackChain2_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500201605, 2132, 24},
    {Table::step, "M_LionC_ClawAttackChain2_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500201606, 2156, 6},
    {Table::step, "M_LionC_ClawAttackChain2_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500201607, 2162, 24},
    {Table::step, "M_LionC_ClawAttackChain2_Cast4", "M_Behemoth_ScratchLeft_Finish1", 500201608, 2186, 6},
    {Table::step, "M_LionC_ClawAttackChain2_Hit4", "M_Behemoth_ScratchLeft_Finish1", 500201609, 2192, 25},
    {Table::step, "M_LionC_ClawAttackChain2_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201610, 2217, 5},
    {Table::skill, "M_LionC_ClawAttackChain2", "M_Behemoth_ScratchLeft", 5002016, 2222, 14},
    {Table::step, "M_LionC_MoveAttackChain_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201702, 2236, 8},
    {Table::step, "M_LionC_MoveAttackChain_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201703, 2244, 24},
    {Table::step, "M_LionC_MoveAttackChain_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201704, 2268, 6},
    {Table::step, "M_LionC_MoveAttackChain_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500201705, 2274, 24},
    {Table::step, "M_LionC_MoveAttackChain_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500201706, 2298, 6},
    {Table::step, "M_LionC_MoveAttackChain_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500201707, 2304, 25},
    {Table::step, "M_LionC_MoveAttackChain_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201708, 2329, 5},
    {Table::skill, "M_LionC_MoveAttackChain", "M_Behemoth_ScratchLeft", 5002017, 2334, 14},
    {Table::step, "M_LionC_RushAttack_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201802, 2348, 8},
    {Table::step, "M_LionC_RushAttack_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201803, 2356, 6},
    {Table::step, "M_LionC_RushAttack_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201804, 2362, 25},
    {Table::step, "M_LionC_RushAttack_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201805, 2387, 5},
    {Table::skill, "M_LionC_RushAttack", "M_Behemoth_ScratchLeft", 5002018, 2392, 14},
    {Table::step, "M_LionC_DashAttackChain_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500201902, 2406, 8},
    {Table::step, "M_LionC_DashAttackChain_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500201903, 2414, 23},
    {Table::step, "M_LionC_DashAttackChain_Cast2", "M_Behemoth_ScratchLeft_Finish1", 500201904, 2437, 6},
    {Table::step, "M_LionC_DashAttackChain_Hit2", "M_Behemoth_ScratchLeft_Finish1", 500201905, 2443, 23},
    {Table::step, "M_LionC_DashAttackChain_Cast3", "M_Behemoth_ScratchLeft_Finish1", 500201906, 2466, 6},
    {Table::step, "M_LionC_DashAttackChain_Hit3", "M_Behemoth_ScratchLeft_Finish1", 500201907, 2472, 23},
    {Table::step, "M_LionC_DashAttackChain_Cast4", "M_Behemoth_ScratchLeft_Finish1", 500201908, 2495, 6},
    {Table::step, "M_LionC_DashAttackChain_Hit4", "M_Behemoth_ScratchLeft_Finish1", 500201909, 2501, 24},
    {Table::step, "M_LionC_DashAttackChain_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500201910, 2525, 5},
    {Table::skill, "M_LionC_DashAttackChain", "M_Behemoth_ScratchLeft", 5002019, 2530, 14},
    {Table::step, "M_LionC_RoarPhaseChange_Cast1", "M_Behemoth_ScratchLeft_Finish1", 500202002, 2544, 13},
    {Table::step, "M_LionC_RoarPhaseChange_Hit1", "M_Behemoth_ScratchLeft_Finish1", 500202003, 2557, 19},
    {Table::step, "M_LionC_RoarPhaseChange_Finish1", "M_Behemoth_ScratchLeft_Finish1", 500202004, 2576, 5},
    {Table::skill, "M_LionC_RoarPhaseChange", "M_Behemoth_ScratchLeft", 5002020, 2581, 13},
    {Table::command, "M_LionC_ClawAttackLeft", "M_Behemoth_ScratchLeft", 5002000, 2594, 6},
    {Table::command, "M_LionC_ClawAttackRight", "M_Behemoth_ScratchLeft", 5002001, 2600, 6},
    {Table::command, "M_LionC_ClawAttackChaseLeft", "M_Behemoth_ScratchLeft", 5002002, 2606, 6},
    {Table::command, "M_LionC_ClawAttackChaseRight", "M_Behemoth_ScratchLeft", 5002003, 2612, 6},
    {Table::command, "M_LionC_TurnAttackLeft", "M_Behemoth_ScratchLeft", 5002004, 2618, 6},
    {Table::command, "M_LionC_TurnAttackRight", "M_Behemoth_ScratchLeft", 5002005, 2624, 6},
    {Table::command, "M_LionC_RunAttackLeft", "M_Behemoth_ScratchLeft", 5002006, 2630, 6},
    {Table::command, "M_LionC_RunAttackRight", "M_Behemoth_ScratchLeft", 5002007, 2636, 6},
    {Table::command, "M_LionC_JumpAttackLow", "M_Behemoth_ScratchLeft", 5002008, 2642, 6},
    {Table::command, "M_LionC_JumpAttackHigh", "M_Behemoth_ScratchLeft", 5002009, 2648, 6},
    {Table::command, "M_LionC_BackJumpToAttack", "M_Behemoth_ScratchLeft", 5002010, 2654, 6},
    {Table::command, "M_LionC_AttackToBackJump", "M_Behemoth_ScratchLeft", 5002011, 2660, 6},
    {Table::command, "M_LionC_Roar", "M_Behemoth_ScratchLeft", 5002012, 2666, 6},
    {Table::command, "M_LionC_SideStepLeft", "M_Behemoth_ScratchLeft", 5002013, 2672, 6},
    {Table::command, "M_LionC_SideStepRight", "M_Behemoth_ScratchLeft", 5002014, 2678, 6},
    {Table::command, "M_LionC_ClawAttackChain", "M_Behemoth_ScratchLeft", 5002015, 2684, 6},
    {Table::command, "M_LionC_ClawAttackChain2", "M_Behemoth_ScratchLeft", 5002016, 2690, 6},
    {Table::command, "M_LionC_MoveAttackChain", "M_Behemoth_ScratchLeft", 5002017, 2696, 6},
    {Table::command, "M_LionC_RushAttack", "M_Behemoth_ScratchLeft", 5002018, 2702, 6},
    {Table::command, "M_LionC_DashAttackChain", "M_Behemoth_ScratchLeft", 5002019, 2708, 6},
    {Table::command, "M_LionC_RoarPhaseChange", "M_Behemoth_ScratchLeft", 5002020, 2714, 6},
    {Table::anim, "M_LionC_Peaceful", "M_Behemoth_Battle", 500200, 2720, 45},
    {Table::anim, "M_LionC_Battle", "M_Behemoth_Battle", 500201, 2765, 45},
    {Table::stance, "M_LionC_Default", "M_Behemoth_Default", 500200, 2810, 19},
    {Table::stance, "M_LionC_Phase2", "M_Behemoth_Default", 500201, 2829, 23},
    {Table::dead, "M_LionC", "M_Behemoth", 0, 2852, 27},
    {Table::appearance, "M_LionC", "M_Behemoth", 50020, 2879, 2},
    {Table::character, "M_LionC_Lurker", "M_Behemoth", 50021, 2881, 55},
    {Table::character, "M_LionC", "M_Behemoth", 50020, 2936, 55},
};
// ---- End of the generated part ----

constexpr size_t kRows = sizeof kRecipe / sizeof kRecipe[0];

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
  uint8_t row = 0;     // refused: the row it stopped at, kRows for the gate or coop off.
  uint32_t detail = 0; // size: the size read (24 bits); net: the net mode read.
};
static_assert(kRows < 256, "a row index fits a byte");
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

// The rows of one table kind in the recipe.
inline uint32_t rows_of(Table t) {
  uint32_t n = 0;
  for (const Row &r : kRecipe)
    n += r.table == t;
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
  // One run over the recipe (see the top of this file). tables: the 12 tables' addresses as Lua found them, in Table's
  // order; block: kBlock bytes of the glue's, 16-aligned; base: SB's image base. Runs every row not added yet and
  // stops at the first refusal.
  template <class Game> Answer run(Game &g, uint64_t base, const uint64_t (&tables)[kTableCount], uint64_t block) {
    Answer a;
    a.state = State::refused;
    uint64_t structs[kTableCount] = {}, add_row = base + (kAddRow - kImageBase);
    for (size_t t = 0; t < kTableCount; ++t) { // Every table before any row: a wrong address adds nothing.
      uint64_t vtable = 0, slot = 0;
      int32_t size = 0;
      a.row = first_row(Table(t));
      if (!g.read(tables[t], &vtable, 8) || vtable != base + (kTableVtable - kImageBase) ||
          !g.read(vtable + kAddRowSlot, &slot, 8) || slot != add_row ||
          !g.read(tables[t] + kRowStruct, &structs[t], 8) || !structs[t])
        return a.why = Why::table, a.added = uint8_t(count_), a;
      if (!g.read(structs[t] + kPropertiesSize, &size, 4) || uint32_t(size) != kTables[t].size)
        return a.why = Why::size, a.detail = uint32_t(size) & 0xffffff, a.added = uint8_t(count_), a;
    }
    for (size_t i = 0; i < kRows; ++i) {
      if (added_[i])
        continue;
      a.row = uint8_t(i);
      const Row &r = kRecipe[i];
      const TableInfo &info = kTables[size_t(r.table)];
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
        if (const Why why = patch(g, block, kPatches[p], pool, block + kBlock); why != Why::none)
          return a.why = why, a.added = uint8_t(count_), a;
      g.add(add_row, table, name, block);
      added_[i] = true;
      ++count_;
    }
    a.state = State::rows, a.why = Why::none, a.row = 0, a.added = uint8_t(count_);
    return a;
  }

  // What SB's own lookups by ID give back for our rows (glue's R3 log line, the status's char=, skills= and stance=):
  // how many of the CharacterTable and SkillTable rows its registry lookups find as the row of our name, and how many
  // stance IDs give our row name.
  struct ReadBack {
    uint8_t character = 0, skills = 0, stance = 0;
  };
  template <class Game> static ReadBack read_back(Game &g, const uint64_t (&tables)[kTableCount]) {
    ReadBack b;
    for (const Row &r : kRecipe) {
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
  static uint8_t first_row(Table t) {
    for (size_t i = 0; i < kRows; ++i)
      if (kRecipe[i].table == t)
        return uint8_t(i);
    return uint8_t(kRows);
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
  bool added_[kRows] = {};
  uint32_t count_ = 0;
};

// coop-status.txt's lion line (cut/lion.lua reads it), from the answer word, the read-back, the frames an ask waited,
// the spawn manager's counter and, after the latch, where the fault was:
//   lion=off
//   lion=waiting added=<n>/<N> asks=<a> spawns=<s> why=<busy|net|unread> ticks=<t>
//   lion=rows added=<N>/<N> asks=<a> spawns=<s> char=<k>/<n> skills=<k>/<n> stance=<k>/<n>
//   lion=refused added=<n>/<N> asks=<a> spawns=<s> why=<word> table=<Table|-> row=<Row|->[ detail=<value>]
//   lion=fault added=<n>/<N> asks=<a> spawns=<s> where=<text, maybe with spaces>
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
inline std::string status_line(const Status &s) {
  uint32_t asks = 0;
  const Answer a = unpack(s.word, asks);
  if (a.state == State::off)
    return "lion=off";
  static const char *const kStates[] = {"off", "waiting", "rows", "refused", "fault"};
  std::string line = std::string("lion=") + kStates[size_t(a.state)] + " added=" + std::to_string(a.added) + "/" +
                     std::to_string(kRows) + " asks=" + std::to_string(asks) +
                     " spawns=" + (s.spawns_read ? std::to_string(s.spawns) : std::string("?"));
  const auto count = [](uint32_t k, Table t) { return std::to_string(k) + "/" + std::to_string(rows_of(t)); };
  if (a.state == State::waiting)
    line += std::string(" why=") + why_word(a.why) + " ticks=" + std::to_string(s.ticks);
  else if (a.state == State::rows)
    line += " char=" + count(s.read.character, Table::character) + " skills=" + count(s.read.skills, Table::skill) +
            " stance=" + count(s.read.stance, Table::stance);
  else if (a.state == State::refused) {
    const bool row = a.row < kRows;
    line += std::string(" why=") + why_word(a.why) +
            " table=" + (row ? kTables[size_t(kRecipe[a.row].table)].name : "-") +
            " row=" + (row ? kRecipe[a.row].name : "-");
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
// The log line for an answer (coop-link.log), as the test campaign's R2 reads it.
inline std::string describe(const Answer &a) {
  const std::string added = std::to_string(a.added) + "/" + std::to_string(kRows);
  if (a.state == State::rows)
    return "lion rows: " + added + " added through SB's AddRow 0x14417ba30, 0 refused";
  if (a.state != State::refused)
    return "lion rows: " + added + " added";
  const bool row = a.row < kRows;
  const Row &r = kRecipe[row ? a.row : 0];
  char why[160];
  switch (a.why) {
  case Why::table: std::snprintf(why, sizeof why, "%s is not SB's UDataTable", kTables[size_t(r.table)].name); break;
  case Why::size:
    std::snprintf(why, sizeof why, "%s's row size 0x%x not 0x%x", kTables[size_t(r.table)].name, unsigned(a.detail),
                  unsigned(kTables[size_t(r.table)].size));
    break;
  case Why::fname: std::snprintf(why, sizeof why, "the game made no FName"); break;
  case Why::name:
    std::snprintf(why, sizeof why, "a row of that name is already in %s", kTables[size_t(r.table)].name);
    break;
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
  return std::string("lion rows refused ") + (row ? r.name : "-") + ": " + why + "; " + added + " added";
}
// The log line for the read-back (the campaign's R3): the IDs asked of each lookup and how many gave our row.
inline std::string describe_read(const Builder::ReadBack &b) {
  const auto ids = [](Table t) {
    uint32_t low = UINT32_MAX, high = 0;
    for (const Row &r : kRecipe)
      if (r.table == t)
        low = r.id < low ? r.id : low, high = r.id > high ? r.id : high;
    return low == high ? std::to_string(low) : std::to_string(low) + "-" + std::to_string(high);
  };
  const auto count = [](uint32_t k, Table t) { return std::to_string(k) + "/" + std::to_string(rows_of(t)); };
  return "lion rows by SB's lookups: CharacterTable " + ids(Table::character) + " " +
         count(b.character, Table::character) + ", SkillTable " + ids(Table::skill) + " " +
         count(b.skills, Table::skill) + ", stance " + ids(Table::stance) + " " + count(b.stance, Table::stance);
}

} // namespace coop::lion
