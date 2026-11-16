// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The native tick's gap line (pose/core.h's gap_line), from fixed values: the UTC time of day out of a FILETIME, the
// gap in whole ms, the frame, the tick before it in hundredths of a ms, and vkd3d-proton.cache.write's growth when the
// file exists.
#include "pose/core.h"

#include <cassert>
#include <cstdio>
#include <string>

using coop::pose::gap_line;

int main() {
  // 2026-11-14T20:00:44.512Z, 100 ns ticks since 1601-01-01.
  constexpr uint64_t kAt = 134391600445120000;
  std::string line = gap_line(kAt, 312'400, 4818231, 50, 496);
  assert(line == "gap 20:00:44.512Z: 312 ms since the last native tick (frame 4818231), that tick took 0.05 ms; "
                 "vkd3d cache +496 bytes");
  // No cache file (Windows, or vkd3d-proton not in use): the field is left out.
  line = gap_line(kAt, 100'001, 7, 1'234, -1);
  assert(line == "gap 20:00:44.512Z: 100 ms since the last native tick (frame 7), that tick took 1.23 ms");
  // A file that did not grow says so.
  line = gap_line(kAt, 2'890'000, 1, 0, 0);
  assert(line == "gap 20:00:44.512Z: 2890 ms since the last native tick (frame 1), that tick took 0.00 ms; "
                 "vkd3d cache +0 bytes");
  // The last 100 ns of a day: the time of day, never the next day's.
  assert(gap_line(134391743999999999, 150'000, 2, 10, -1).rfind("gap 23:59:59.999Z: 150 ms", 0) == 0);
  // A frame counter past 32 bits keeps every digit.
  assert(gap_line(kAt, 150'000, 0x1'0000'0001, 10, -1).find("(frame 4294967297)") != std::string::npos);
  std::puts("gap_test: ok");
  return 0;
}
