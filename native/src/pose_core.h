// The native pose path's shared pieces, free of Windows: its limits, one skeletal mesh component as Lua names it, one
// effect slot, and the hex addresses Lua writes. The component table is in pose_table.h, engine memory access in
// pose_engine.h.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string_view>

#include "link_protocol.h" // number() and kProtocol, for the table's grammar

namespace coop::pose {

constexpr size_t kMaxParts = 16, kMaxBones = 1024, kTransformBytes = 48; // FTransform: rotation, translation, scale.
// A pose carries 4 effect slots of 15 bytes (pose_codec.h); an asset is an index into Lua's list of systems, 1 to 32.
constexpr size_t kEffectSlots = 4, kEffectBytes = 15, kMaxEffectAssets = 32;

// One effect slot, asset 0 for none: the table part it hangs on, a serial the sender bumps for each new instance in the
// slot, and its transform relative to that part (rotation xyzw, translation xyz). Here, not in pose_codec.h: the
// playback holds slots and the engine reads them.
struct Effect {
  uint8_t asset = 0, part = 0, serial = 0;
  float place[7] = {};
};

// One skeletal mesh component, as Lua saw it when it published its table.
struct Part {
  uint64_t object = 0, cls = 0, mesh = 0;
  uint32_t bones = 0;
  bool leader = false; // Leaders own their pose; followers copy a leader (SetMasterPoseComponent).
};

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
