// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The native pose path's shared pieces, free of Windows: its limits, one skeletal mesh component as Lua names it, one
// effect slot, one free part's block, the hex addresses Lua writes, the ghost slots' file names and the native tick's
// gap line. The component table is in game/table.h, engine memory access in game/partner/engine.h.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <string>
#include <string_view>

#include "link/protocol.h" // number() and kProtocol, for the table's grammar; kMaxRemote

namespace coop::pose {

constexpr size_t kMaxParts = 32, kMaxBones = 1024, kTransformBytes = 48; // FTransform: rotation, translation, scale.
// A pose carries 6 effect slots of 15 bytes (game/codec.h); an asset is an index into Lua's list of systems, 1 to
// kMaxEffectAssets: the first kFixedEffects are online/partner/capture.lua's Capture.EFFECTS, which both sides compile
// in, and the rest the table's fx lines name by path (game/table.h).
constexpr size_t kEffectSlots = 6, kEffectBytes = 15, kFixedEffects = 19, kMaxEffectAssets = 64;
// A free part's block in a pose: the world transform's 24 bytes (game/codec.h) and the state byte.
constexpr size_t kFreeBytes = 25;

// One effect slot, asset 0 for none: the table part it hangs on, a serial the sender bumps for each new instance in the
// slot, and its transform relative to that part (rotation xyzw, translation xyz). Here, not in game/codec.h: the
// playback holds slots and the engine reads them.
struct Effect {
  uint8_t asset = 0, part = 0, serial = 0;
  float place[7] = {};
};

// A free part's block (her drone): its place relative to part 0 (rotation xyzw, translation xyz, scale xyz) and its
// state, bit 7 shown this pose and bits 0-6 the light step (intensity = step x 4, 0 off). Hidden travels as zeros.
struct Free {
  float place[10] = {};
  uint8_t state = 0;
};

// One skeletal mesh component, as Lua saw it when it published its table.
struct Part {
  uint64_t object = 0, cls = 0, mesh = 0;
  uint32_t bones = 0;
  bool leader = false; // Leaders own their pose; followers copy a leader (SetMasterPoseComponent).
  bool free = false;   // A leader after part 0 hung from nothing, placed by the pose's free block.
};

// One ghost slot per other member of a match lobby, 0 to kMaxRemote - 1 (link/peer.h's Peer::slot). Each has its own
// files in the mod folder: slot 0 keeps the co-op names (coop-remote.txt), slot k from 1 adds -<k> (coop-remote-3.txt).
using coop::kMaxRemote;
inline std::string slot_file(std::string_view stem, size_t slot) {
  return std::string(stem) + (slot ? "-" + std::to_string(slot) : std::string()) + ".txt";
}

// The game thread's pose inbox (online/partner/pose_game.inc), one for all the ghost slots: 400 ms of poses at 60 a
// second from each other member of a match lobby. When it is full, the worker drops the newest pose (wire_receive).
constexpr size_t kInbox = 24 * kMaxRemote;

// The worker's line for one gap over 100 ms between two native ticks (online/partner/pose_game.inc's game_tick): when
// it ended, in UTC (filetime: a FILETIME, 100 ns ticks since 1601-01-01), how long it was, the engine frame it ended
// in, how long the coop_tick before it took, and how much vkd3d-proton.cache.write grew since the last gap line
// (cache_grew < 0: no such file, so no field). tests/native/online/partner/gap_test.cpp checks it.
inline std::string gap_line(uint64_t filetime, uint64_t gap_us, uint64_t frame, uint64_t tick_us, int64_t cache_grew) {
  // 1601-01-01 begins at midnight, and FILETIME has no leap seconds.
  const uint64_t ms = filetime / 10'000 % 86'400'000;
  char line[160];
  int n = std::snprintf(line, sizeof line,
                        "gap %02u:%02u:%02u.%03uZ: %llu ms since the last native tick (frame %llu), that tick took "
                        "%.2f ms",
                        unsigned(ms / 3'600'000), unsigned(ms / 60'000 % 60), unsigned(ms / 1'000 % 60),
                        unsigned(ms % 1'000), static_cast<unsigned long long>(gap_us / 1'000),
                        static_cast<unsigned long long>(frame), tick_us / 1'000.0);
  if (cache_grew >= 0)
    std::snprintf(line + n, sizeof line - size_t(n), "; vkd3d cache +%lld bytes", static_cast<long long>(cache_grew));
  return line;
}

inline bool hex(std::string_view text, uint64_t &out) {
  if (text.size() < 3 || text.size() > 18 || text[0] != '0' || (text[1] != 'x' && text[1] != 'X'))
    return false;
  uint64_t value = 0;
  for (size_t i = 2; i < text.size(); ++i) {
    char c = text[i];
    int digit = c >= '0' && c <= '9' ? c - '0' : c >= 'a' && c <= 'f' ? c - 'a' + 10 : c >= 'A' && c <= 'F' ? c - 'A' + 10 : -1;
    if (digit < 0)
      return false;
    value = value << 4 | static_cast<uint64_t>(digit);
  }
  out = value;
  return true;
}

} // namespace coop::pose
