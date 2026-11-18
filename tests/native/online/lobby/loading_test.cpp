// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// online/lobby/loading.h on the build machine: over a copy of SB's auto list, every entry of tag Load (5) gets lifetime
// 0 and nothing else changes; a count out of range touches nothing.
#include "online/lobby/loading.h"

#include <array>
#include <cassert>
#include <cstring>

using namespace coop::loading;

namespace {
float life(const uint8_t *list, int i) {
  float f;
  std::memcpy(&f, list + i * kEntry + kLife, sizeof f);
  return f;
}
} // namespace

int main() {
  static_assert(kUiManager == 0x1470375a8 && kAutoList == 0x3b0 && kAutoCount == 0x3b8 && kEntry == 0x40 &&
                kLife == 0x14 && kTag == 0x2c && kLoad == 5 && kMaxEntries == 64);
  std::array<uint8_t, 3 * kEntry> list{};
  for (int i = 0; i < 3; ++i) {
    const float ten = 10.0f;
    std::memcpy(list.data() + i * kEntry + kLife, &ten, sizeof ten);
    list[i * kEntry + 0x10] = 1;                  // Ready: its start fade is over.
    list[i * kEntry + kTag] = i == 1 ? 0 : kLoad; // Entry 1 is SB's own (tag None).
  }
  const std::array<uint8_t, 3 * kEntry> before = list;
  assert(lift(list.data(), -1) == -1 && lift(list.data(), kMaxEntries + 1) == -1 && list == before);
  assert(lift(list.data(), 0) == 0 && list == before);
  assert(lift(list.data(), 3) == 2);
  assert(life(list.data(), 0) == 0.0f && life(list.data(), 1) == 10.0f && life(list.data(), 2) == 0.0f);
  for (size_t b = 0; b < list.size(); ++b) // Only the two lifetimes changed.
    if (list[b] != before[b])
      assert(b % kEntry >= kLife && b % kEntry < kLife + 4 && b / kEntry != 1);
  assert(lift(list.data(), 3) == 2); // Again: the same entries, still 0.
  return 0;
}
