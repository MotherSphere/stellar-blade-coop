// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// What other modules' parts read of group/camps_game.inc, cut from it whole and in order.
// tick.cpp includes this file right before it.
namespace coop::pose {
namespace {
// One FName as text, read from SB's name pool (game/pilot.h's fname), or empty.
std::string camps_name(uint64_t name) {
  char text[128];
  size_t n = 0;
  const auto read = [](uint64_t at, void *out, size_t size) {
    std::memcpy(out, reinterpret_cast<const void *>(at), size);
    return true;
  };
  return pilot::fname(read, base + (pilot::kNamePool - game::kImageBase), uint32_t(name), uint32_t(name >> 32), text,
                      sizeof text, n)
             ? std::string(text, n)
             : std::string();
}
} // namespace
} // namespace coop::pose
