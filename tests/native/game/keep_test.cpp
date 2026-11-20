// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/keep.h on the build machine: the path rule (object and class paths under /Game/ and /Engine/, nothing else),
// the list (each path asked once, a bad one refused, kMaxPaths at most, the batch of what came since the last look,
// the counts once a batch settles), coop-keep.txt's lines (70 at once, the same text again adding nothing, a bad line
// counted) and the status field.
#include "game/keep.h"

#include <cassert>
#include <cstdio>
#include <string>

using namespace coop::keep;

int main() {
  // 1. The path rule.
  assert(path_ok("/Game/GameDesign/Level/Theater/NPC/XionExtraEngineer/Theater/Q.Q"));
  assert(path_ok("/Game/GameDesign/Level/ZoneEventActor/BP_Destruction_Box_01.BP_Destruction_Box_01_C"));
  assert(path_ok("/Engine/EngineFonts/Roboto.Roboto"));
  for (const char *bad : {"/Game/A/B", "/Game/A/B.C", "/Other/A/B.B", "Game/A/B.B", "/Game/A/B.B_X", "/Game/A B/C.C",
                          "/Game/A/B.B;x", ""})
    assert(!path_ok(bad));
  const std::string n(100, 'a');
  assert(!path_ok("/Game/" + n + "." + n));
  // 2. Each path once, a bad one refused (Review Focus 8); the batch since the last look; the counts.
  List l;
  assert(l.add("/Game/A/B.B") == Add::added && l.add("/Game/A/B.B") == Add::again && l.add("/Game/A/B") == Add::bad);
  assert(l.add("/Game/A/C.C_C") == Add::added && l.asked() == 2);
  int first = -1;
  assert(l.batch(first) == 2 && first == 0 && l.path(1) == "/Game/A/C.C_C");
  assert(l.batch(first) == 0 && first == 2);
  assert(line(l) == "keep=2 0 0");
  l.settle(2, 1);
  assert(line(l) == "keep=2 2 1" && l.settled() == 2 && l.in() == 1);
  assert(l.add("/Game/A/D.D") == Add::added && l.batch(first) == 1 && first == 2);
  // 3. kMaxPaths at most; a path already in stays "again" when full. In a file, a new path past the limit counts as
  //    refused (the log line names both causes), one already in does not.
  for (int i = l.asked(); i < kMaxPaths; ++i)
    assert(l.add("/Game/N/P" + std::to_string(i) + ".P" + std::to_string(i)) == Add::added);
  assert(l.add("/Game/N/Q.Q") == Add::full && l.asked() == kMaxPaths && l.add("/Game/A/B.B") == Add::again);
  assert(l.add_lines("/Game/N/Q.Q\n/Game/A/B.B\n") == 1 && l.asked() == kMaxPaths);
  // 4. coop-keep.txt (Lua writes the whole list each time it grows): 70 lines added in one take, the same text again
  //    adds nothing, '\r' and empty lines are skipped, a bad line is counted as refused; one batch takes them all.
  List f;
  std::string text;
  for (int i = 0; i < 70; ++i)
    text += "/Game/M/P" + std::to_string(i) + ".P" + std::to_string(i) + "\n";
  assert(text.size() < kFileBytes && f.add_lines(text) == 0 && f.asked() == 70);
  assert(f.add_lines(text) == 0 && f.asked() == 70);
  assert(f.add_lines("/Game/X/Y.Y\r\n\n/Game/bad\n") == 1 && f.asked() == 71);
  assert(f.batch(first) == 71 && first == 0 && f.path(70) == "/Game/X/Y.Y");
  std::puts("keep_test ok");
  return 0;
}
