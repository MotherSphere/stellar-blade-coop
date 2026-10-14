// The native pose path's logic, free of Windows: the component table Lua publishes, and the ring of EVE's past poses
// the delayed mirror plays back. Engine memory access lives in pose_engine.h; tests/pose_core_test.cpp checks this file
// on the build machine.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <optional>
#include <string>
#include <vector>

#include "link_protocol.h" // number(), split()

namespace coop::pose {

constexpr size_t kMaxParts = 16, kMaxBones = 1024, kTransformBytes = 48; // FTransform: rotation, translation, scale.

// One skeletal mesh component, as Lua saw it when it published the table.
struct Part {
  uint64_t object = 0, cls = 0, mesh = 0;
  uint32_t bones = 0;
  bool leader = false; // Leaders own their pose; followers copy a leader (SetMasterPoseComponent).
};

// EVE's parts and the puppet's, index for index, plus the mailbox (N17): a scene component of the puppet that nothing
// ever moves, whose relative location and rotation the native mirror writes and Lua reads back each frame. It cannot be
// the puppet's root itself: K2_SetWorldLocationAndRotation does nothing when the value equals the root's own relative
// fields (PHASE2-RE.md).
struct Table {
  uint64_t generation = 0, mailbox = 0, mailbox_class = 0;
  std::vector<Part> eve, puppet;
};

inline bool hex(const std::string &text, uint64_t &out) {
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

// Lua's table file:
//   generation <n>
//   mailbox 0x<object> 0x<class>
//   part eve|puppet <index> 0x<object> 0x<class> 0x<mesh> <bones> <leader 0|1>
// Part 0 is the main mesh on both sides: the mirror records EVE's and places the puppet's through the mailbox.
// Every part index from 0 up to the count, for both sides, same bones and leader flags side by side.
inline std::optional<Table> parse_table(const std::string &text) {
  Table t;
  bool has_generation = false;
  std::vector<std::pair<size_t, Part>> eve, puppet;
  size_t at = 0;
  while (at < text.size()) {
    size_t end = text.find('\n', at);
    std::string line = text.substr(at, end == std::string::npos ? std::string::npos : end - at);
    at = end == std::string::npos ? text.size() : end + 1;
    if (!line.empty() && line.back() == '\r')
      line.pop_back();
    if (line.empty())
      continue;
    std::string f[8];
    uint64_t index = 0, bones = 0, leader = 0;
    Part p;
    if (split(line, f, 2, nullptr) && f[0] == "generation" && number(f[1], t.generation)) {
      has_generation = true;
    } else if (split(line, f, 3, nullptr) && f[0] == "mailbox" && hex(f[1], t.mailbox) && hex(f[2], t.mailbox_class)) {
    } else if (split(line, f, 8, nullptr) && f[0] == "part" && (f[1] == "eve" || f[1] == "puppet") &&
               number(f[2], index) && index < kMaxParts && hex(f[3], p.object) && hex(f[4], p.cls) &&
               hex(f[5], p.mesh) && number(f[6], bones) && bones <= kMaxBones && number(f[7], leader) && leader <= 1 &&
               p.object && p.cls && p.mesh) {
      p.bones = static_cast<uint32_t>(bones);
      p.leader = leader == 1;
      (f[1] == "eve" ? eve : puppet).push_back({static_cast<size_t>(index), p});
    } else {
      return std::nullopt;
    }
  }
  if (!has_generation || !t.mailbox || !t.mailbox_class || eve.empty() || eve.size() != puppet.size())
    return std::nullopt;
  t.eve.resize(eve.size());
  t.puppet.resize(puppet.size());
  std::vector<bool> seen_eve(eve.size()), seen_puppet(puppet.size());
  for (auto &[i, p] : eve) {
    if (i >= eve.size() || seen_eve[i])
      return std::nullopt;
    seen_eve[i] = true;
    t.eve[i] = p;
  }
  for (auto &[i, p] : puppet) {
    if (i >= puppet.size() || seen_puppet[i])
      return std::nullopt;
    seen_puppet[i] = true;
    t.puppet[i] = p;
  }
  for (size_t i = 0; i < t.eve.size(); ++i)
    if (t.eve[i].bones != t.puppet[i].bones || t.eve[i].leader != t.puppet[i].leader)
      return std::nullopt;
  return t;
}

// EVE's recent frames for the delayed mirror: a fixed pool, allocated when the table changes, never on a plain frame.
// Each frame holds the actor root transform (10 floats: rotation xyzw, translation xyz, scale xyz) and the raw local
// bone transforms of every leader part, back to back.
class Ring {
public:
  static constexpr size_t kFrames = 512;          // 2 s at the recording cap below.
  static constexpr uint64_t kMinSpacingUs = 3'900; // Record at most ~256 times a second, whatever the frame rate.
  static constexpr uint64_t kKeepUs = 2'000'000;

  // Sizes the pool for a table: the byte count of all leader bones. Drops every stored frame.
  void reset(const Table &t) {
    bytes_ = 0;
    for (auto &p : t.eve)
      if (p.leader)
        bytes_ += size_t(p.bones) * kTransformBytes;
    for (auto &f : frames_) {
      f.time = 0;
      f.used = false;
      f.bones.assign(bytes_, 0);
    }
    next_ = 0;
  }
  size_t bytes() const { return bytes_; }

  // The slot to fill for the frame at 'now' (µs, monotonic); commit() makes it visible.
  struct Frame {
    uint64_t time = 0;
    bool used = false;
    float root[10] = {};
    std::vector<uint8_t> bones;
  };
  Frame &begin(uint64_t now) {
    Frame &f = frames_[next_];
    f.time = now;
    f.used = false;
    return f;
  }
  void commit() {
    frames_[next_].used = true;
    next_ = (next_ + 1) % kFrames;
  }
  void cancel() {} // begin() without commit(): the slot stays unused and is reused next frame.
  // Forgets every frame (the mirror restarts): no allocation.
  void clear() {
    for (auto &f : frames_)
      f.used = false;
  }
  uint64_t newest() const { // The time of the newest frame, or 0.
    uint64_t t = 0;
    for (auto &f : frames_)
      if (f.used && f.time > t)
        t = f.time;
    return t;
  }

  // The newest frame at or before now - delay, or none when the ring does not reach that far back yet, or when that
  // frame is over kStaleUs older than the target (a gap in recording: never play an old moment back).
  static constexpr uint64_t kStaleUs = 200'000;
  const Frame *at_delay(uint64_t now, uint64_t delay_us) const {
    if (delay_us > kKeepUs || delay_us > now)
      return nullptr;
    uint64_t target = now - delay_us;
    const Frame *best = nullptr;
    for (auto &f : frames_)
      if (f.used && f.time <= target && (!best || f.time > best->time))
        best = &f;
    return best && target - best->time <= kStaleUs ? best : nullptr;
  }

private:
  Frame frames_[kFrames];
  size_t next_ = 0, bytes_ = 0;
};

// What the worker hands the game thread for one table: the table and a ring already sized for it, so the game thread
// never allocates.
struct Session {
  Table table;
  Ring ring;
  explicit Session(Table t) : table(std::move(t)) { ring.reset(table); }
};

} // namespace coop::pose
