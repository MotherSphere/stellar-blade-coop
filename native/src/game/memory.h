// The game image's base and globals block, and the two helpers every read of game memory goes through: plausible()
// for a pointer before it reaches a read, get() for a value inside a block already read. Offsets are for Stellar
// Blade's Steam build 24463856.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace coop::game {

constexpr uint64_t kImageBase = 0x140000000;
constexpr uint64_t kGlobals = 0x147032528; // 0x50 bytes in one read: +0 net-mode cache, +0x28 rule manager
                                           // (0x147032550), +0x30 spawn singleton, +0x40 logic, +0x48 world.

// A user-space, 8-aligned address, as every game object is. Nothing else reaches the reader.
inline bool plausible(uint64_t p) { return p >= 0x10000 && p < 0x7fffffff0000 && !(p & 7); }

template <class T> T get(const uint8_t *block, size_t offset) {
  T value;
  std::memcpy(&value, block + offset, sizeof value);
  return value;
}

} // namespace coop::game
