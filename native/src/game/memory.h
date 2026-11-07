// The game image's base and globals block, and the two helpers every read of game memory goes through: plausible()
// for a pointer before it reaches a read, get() for a value inside a block already read. Offsets are for Stellar
// Blade's Steam build 26123051.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>

namespace coop::game {

constexpr uint64_t kImageBase = 0x140000000;
constexpr uint64_t kGlobals = 0x1470373e8; // The net-mode cache; +0x18 the const store, +0x28 the rule manager.
// SB's globals block, 0x50 bytes in one read: +0 the registry (spawn singleton and pause tags), +8 the world, +0x18
// logic, +0x20 the net-mode cache (kGlobals), +0x30 the client, +0x38 the const store, +0x48 the rule manager. Each
// sits where its getter reads it (0x141a98bc0, 0x141a98b50, 0x141a98a30, 0x141a989b0, 0x141a987d0, 0x141a986c0,
// 0x141a98530); the linker orders them per build, so offsets from kGlobals hold only for the const store and the rule
// manager.
constexpr uint64_t kGlobalsBlock = 0x1470373c8;

// A user-space, 8-aligned address, as every game object is. Nothing else reaches the reader.
inline bool plausible(uint64_t p) { return p >= 0x10000 && p < 0x7fffffff0000 && !(p & 7); }

template <class T> T get(const uint8_t *block, size_t offset) {
  T value;
  std::memcpy(&value, block + offset, sizeof value);
  return value;
}

} // namespace coop::game
