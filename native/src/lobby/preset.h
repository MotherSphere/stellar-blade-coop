// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The match loadout (design 10.1, L3-entry-return.md 6.1 E10b): SB's preset Preset_Eve_Max put on our EVE with SB's
// own functions, in the order of SB's preset applier FUN_141c247f0 with two steps of the mod's around it: the
// acquirable skills removed first, and before the equip loop, the protector slots and the slots holding an item with
// a lasting effect emptied. lobby/sbo_game.inc's G makes the calls with the applier's argument lists;
// tests/native/lobby/preset_test.cpp checks the order on the build machine. Offsets are into the preset's row, for
// Stellar Blade's Steam build 26123051.
#pragma once

#include <cstdint>
#include <string>

namespace coop::preset {

constexpr char kPreset[] = "Preset_Eve_Max";
// ChangeLevel's type and the row's level field, in the applier's order (0x141c248f8 to 0x141c24975).
struct Level {
  int type;
  uint32_t offset;
};
constexpr Level kLevels[6] = {{4, 0x14}, {1, 0x18}, {2, 0x1c}, {5, 0x28}, {3, 0x20}, {6, 0x24}};
// The equip loop's slots and the row's alias fields (0x141c24cd9 onward).
struct Equip {
  int slot;
  uint32_t offset;
};
constexpr Equip kEquips[6] = {{1, 0x98}, {2, 0xa0}, {3, 0xa8}, {4, 0xb0}, {6, 0xc0}, {7, 0xc8}};
// Emptied first: both protector slots (Equip refuses an exospine whose tag the other slot's holds). Then each of these
// slots, the loop never fills, when its item is one of the aliases whose effect lasts while it is worn.
constexpr int kFirstOut[2] = {6, 7};
constexpr int kSlotsOut[11] = {5, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17};
constexpr const char *kOutAliases[4] = {"BS_102", "BS_Nikke_01", "Hair_Nikke_01", "Earring_018"};
// Equip returns nothing: a slot read back different makes the glue run the pass again, on the next frame, this many
// times in all.
constexpr int kTries = 3;

// SB's functions the glue's G calls, each with the argument list of its call site in the applier (L3-entry-return.md
// 6.1): the preset's row (tables, unused, &FName; 0x141c24868) and our item bucket (logic singleton, 1, GUID);
// AcquisitionSkillTable, AchievementTable and ItemTable rows (*(tables + 0x20), is None, FName by value);
// RemoveSkill, ChangeLevel (logic, type, level, 0, 1), the bucket's clear, RecoveryItems, the achievement's completion
// (FSB +0x2670, ID, row +0x74, 0, 1, 0, 0, 0), AcquireSkill (logic, ID, 1, 0), AddItem (bucket, FName by value,
// amount, level, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0), Unequip (logic, slot), the equipped map's find (map, &index,
// slot), the bucket's item by alias into an item record, the record's copy, Equip (logic, slot, copy, 0), the record's
// constructor and destructor, and ChargeItems. kNoneIndex: the comparison index SB tests an FName against for None.
constexpr uint64_t kRow = 0x141bd4930, kBucket = 0x141ad8490, kSkillRow = 0x141a9da80, kAchievementRow = 0x141a9ccc0,
                   kItemRow = 0x141a9f680, kRemoveSkill = 0x141bbd000, kChangeLevel = 0x141bbac90,
                   kClear = 0x141bdb600, kRecovery = 0x141bb84f0, kComplete = 0x141a33860,
                   kAcquireSkill = 0x141bbc8d0, kAddItem = 0x141bdbc20, kUnequip = 0x141bb7c60,
                   kSlotFind = 0x141a9aa60, kFromBucket = 0x141bdffd0, kItemCopy = 0x141a87c50,
                   kEquipItem = 0x141bb6fe0, kItemMake = 0x141a2d260, kItemFree = 0x141a2d3b0,
                   kCharge = 0x141bb88a0, kNoneIndex = 0x147017b00;
// FSB +0x2668: the acquired-skill component, its alias set at +0x58 (a TSet<FName>: elements of 0x10 bytes, the
// allocation bits inline at set +0x10 or at *(set +0x20), their count at set +0x28). FSB +0x2670: the achievements.
// FSB +0x3e8: the equipped map, slot to item record, elements of 0x160 bytes with the item's alias at +0x28.
constexpr uint32_t kSkills = 0x2668, kSkillSet = 0x58, kAchievements = 0x2670, kEquipped = 0x3e8,
                   kSlotElement = 0x160, kSlotAlias = 0x28;
// The row's lists (data, count +8): achievements, skills, items and the items' parallel amounts and levels. A table
// row's ID +0x10, an achievement's value +0x74, AcquisitionOnCreated +0x4a, an item's Category +0x70 (13 Bullet).
// An item record (FSBItemInstance) is 0x150 bytes.
constexpr uint32_t kAchievementList = 0x48, kSkillList = 0x38, kItemList = 0x68, kAmounts = 0x78, kLevelsList = 0x88,
                   kId = 0x10, kAchievementValue = 0x74, kOnCreated = 0x4a, kCategory = 0x70, kBullet = 13,
                   kItemSize = 0x150;
// row: the preset's row was found (nothing else ran without it). refused: equip slots whose item was not in the
// bucket. mismatched: the other equip slots that read back different from the row.
struct Pass {
  bool row = false;
  int refused = 0;
  int mismatched = 0;
};

// One pass over G: bool row(), void skills_out(), void level(type, offset), void clear(), void recovery(), void
// achievements(), void skills_in(), void items(bool bullets), void unequip(slot), std::string held(slot), bool
// equip(slot, offset), void charge(), bool matches(slot, offset).
template <class G> Pass apply(G &g) {
  Pass p;
  if (!(p.row = g.row()))
    return p;
  g.skills_out();
  for (const Level &l : kLevels)
    g.level(l.type, l.offset);
  g.clear();
  g.recovery();
  g.achievements();
  g.skills_in();
  g.items(false);
  for (const int slot : kFirstOut)
    g.unequip(slot);
  for (const int slot : kSlotsOut) {
    const std::string alias = g.held(slot);
    for (const char *out : kOutAliases)
      if (alias == out) {
        g.unequip(slot);
        break;
      }
  }
  bool refused[6] = {};
  for (int i = 0; i < 6; ++i)
    if (!g.equip(kEquips[i].slot, kEquips[i].offset))
      refused[i] = true, ++p.refused;
  g.items(true);
  g.charge();
  for (int i = 0; i < 6; ++i)
    if (!refused[i] && !g.matches(kEquips[i].slot, kEquips[i].offset))
      ++p.mismatched;
  return p;
}

} // namespace coop::preset
