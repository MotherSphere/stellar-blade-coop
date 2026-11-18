// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// lobby/preset.h on the build machine: the match loadout's call order, the slots it empties, refusals and read-back.
#include "lobby/preset.h"

#include <cassert>
#include <cstdio>
#include <string>
#include <vector>

using namespace coop::preset;

// One string per call; held, equip and matches answer as the slots below say.
struct FakeG {
  std::vector<std::string> calls;
  bool no_row = false, mismatch_once = true;
  void say(const char *what, int a = -1, uint32_t offset = 0) {
    char text[40];
    if (a < 0)
      std::snprintf(text, sizeof text, "%s", what);
    else if (!offset)
      std::snprintf(text, sizeof text, "%s %d", what, a);
    else
      std::snprintf(text, sizeof text, "%s %d 0x%x", what, a, unsigned(offset));
    calls.push_back(text);
  }
  bool row() { say("row"); return !no_row; }
  void skills_out() { say("out"); }
  void level(int type, uint32_t offset) { say("level", type, offset); }
  void clear() { say("clear"); }
  void recovery() { say("recovery"); }
  void achievements() { say("achievements"); }
  void skills_in() { say("in"); }
  void items(bool bullets) { say(bullets ? "bullets" : "items"); }
  void unequip(int slot) { say("unequip", slot); }
  std::string held(int slot) { return slot == 9 ? "BS_102" : slot == 5 ? "Sword_A" : ""; }
  bool equip(int slot, uint32_t offset) { say("equip", slot, offset); return slot != 4; }
  void charge() { say("charge"); }
  bool matches(int slot, uint32_t) {
    if (slot == 2 && mismatch_once)
      return mismatch_once = false;
    return true;
  }
};

int main() {
  static_assert(sizeof(kPreset) == 15 && kTries == 3 && kLevels[3].type == 5 && kLevels[3].offset == 0x28 &&
                kEquips[5].slot == 7 && kEquips[5].offset == 0xc8 && kSlotsOut[10] == 17);
  FakeG g;
  Pass p = apply(g);
  const std::vector<std::string> want = {
      "row", "out", "level 4 0x14", "level 1 0x18", "level 2 0x1c", "level 5 0x28", "level 3 0x20", "level 6 0x24",
      "clear", "recovery", "achievements", "in", "items", "unequip 6", "unequip 7", "unequip 9", "equip 1 0x98",
      "equip 2 0xa0", "equip 3 0xa8", "equip 4 0xb0", "equip 6 0xc0", "equip 7 0xc8", "bullets", "charge"};
  assert(g.calls == want && p.row && p.refused == 1 && p.mismatched == 1);
  FakeG none; none.no_row = true;
  assert(!apply(none).row && none.calls == std::vector<std::string>{"row"});
  std::puts("game_preset_test: ok");
  return 0;
}
