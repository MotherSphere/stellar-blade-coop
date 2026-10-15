// Night Operation probe (Phase 6): the worker's read-only view of the game's rule manager, world, logic, net-mode cache
// and spawn registry, turned into nightop-probe.txt lines and one verdict 60 s after the rule request. It never touches
// a game pointer itself: every access goes through a read function (ReadProcessMemory on the worker, which fails rather
// than faults; a fake image in tests/nightop_probe_test.cpp), and only after plausible() accepted the pointer. Every
// count is range-checked before it sizes a read. No Windows types.
// Offsets are for Stellar Blade's Steam build 24463856 (night-operation/STUDY.md, PHASE10-DESK-RE.md); the caller polls
// only a pinned build.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

namespace coop::nightop {

constexpr uint64_t kImageBase = 0x140000000;
constexpr uint64_t kGlobals = 0x147032528; // 0x50 bytes in one read: +0 net-mode cache, +0x28 rule manager
                                           // (0x147032550), +0x30 spawn singleton, +0x40 logic, +0x48 world.
constexpr uint64_t kSampleMs = 100, kLineMs = 1000, kVerdictMs = 60000;

// A user-space, 8-aligned address, as every game object is. Nothing else reaches the reader.
inline bool plausible(uint64_t p) { return p >= 0x10000 && p < 0x7fffffff0000 && !(p & 7); }

// One poll. A global of 0 prints its group as none; a non-zero one whose *_ok is false was implausible or unreadable
// and prints ?. No strings: sampling formats nothing.
struct Sample {
  bool ok = false; // The globals block was read; nothing else is without it.
  uint64_t net = 0, mgr = 0, spawn = 0, logic = 0, world = 0;
  bool net_ok = false, mgr_ok = false, p0_ok = false, timers_ok = false, world_ok = false, actors_ok = false,
       logic_ok = false, spawn_ok = false; // spawn_ok: the three hops read and the count in 0..100000.
  // Rule manager: the rule alias (FName index, number), state, wait or run time, lives, the player map's num and free
  // count and its element 0, the zone-event timers (count, up to 3 values) and now.
  uint32_t alias[2] = {};
  int32_t state = 0, lives = 0, num = 0, free_count = 0, timers = 0;
  float time = 0, now = 0, timer[3] = {};
  uint64_t p0 = 0;
  int32_t p0_fields[5] = {}; // +8, +0xC, +0x20, +0x24, +0x28.
  // World: the RunEvent gate fields +0x34, +0x74, +0x320; the actor manager's count and player index.
  uint8_t world34 = 0;
  uint32_t world74 = 0, world320 = 0;
  int32_t actors = 0, actor_player = 0;
  // Logic: a turn counter, the current zone FName, the +0x5b1 flag, and the task handle at +0x5c0, non-zero once the
  // rule job runs on SB's logic thread.
  uint32_t turn = 0, zone[2] = {};
  uint8_t b5b1 = 0;
  uint64_t task = 0;
  int32_t net_mode = 0;
  int64_t spawnreg = 0; // Registered spawn points: r+0x60 minus r+0x8c.
};

template <class T> T get(const uint8_t *block, size_t offset) {
  T value;
  std::memcpy(&value, block + offset, sizeof value);
  return value;
}

// At most 11 reads: globals, manager, element 0, timers, world, actor manager, logic, net, and the spawn chain's three.
// read(address, out, n) returns false when the memory is unreadable.
template <class Read> Sample sample(uint64_t base, Read &&read) {
  Sample s;
  uint8_t b[0x5c8]; // The largest block, logic's.
  if (!read(base + (kGlobals - kImageBase), b, 0x50))
    return s;
  s.ok = true;
  s.net = get<uint64_t>(b, 0);
  s.mgr = get<uint64_t>(b, 0x28);
  s.spawn = get<uint64_t>(b, 0x30);
  s.logic = get<uint64_t>(b, 0x40);
  s.world = get<uint64_t>(b, 0x48);
  // n bytes at pointer + offset, once the pointer itself is plausible.
  auto follow = [&read](uint64_t pointer, uint64_t offset, void *out, size_t n) {
    return plausible(pointer) && read(pointer + offset, out, n);
  };
  if (s.mgr && (s.mgr_ok = follow(s.mgr, 0, b, 0x88))) {
    s.alias[0] = get<uint32_t>(b, 8);
    s.alias[1] = get<uint32_t>(b, 0xc);
    s.state = get<int32_t>(b, 0x10);
    s.time = get<float>(b, 0x14);
    s.lives = get<int32_t>(b, 0x18);
    s.num = get<int32_t>(b, 0x28);
    s.free_count = get<int32_t>(b, 0x54);
    s.timers = get<int32_t>(b, 0x78);
    s.now = get<float>(b, 0x80);
    uint64_t element = get<uint64_t>(b, 0x20), values = get<uint64_t>(b, 0x70);
    if (s.timers >= 0 && s.timers <= 3)
      s.timers_ok = !s.timers || follow(values, 0, s.timer, 4 * size_t(s.timers));
    if (s.num >= 1 && s.num <= 64 && (s.p0_ok = follow(element, 0, b, 0x40))) {
      s.p0 = get<uint64_t>(b, 0);
      const size_t at[5] = {8, 0xc, 0x20, 0x24, 0x28};
      for (int i = 0; i < 5; ++i)
        s.p0_fields[i] = get<int32_t>(b, at[i]);
    }
  }
  if (s.world && (s.world_ok = follow(s.world, 0, b, 0x328))) {
    s.world34 = b[0x34];
    s.world74 = get<uint32_t>(b, 0x74);
    s.world320 = get<uint32_t>(b, 0x320);
    if ((s.actors_ok = follow(get<uint64_t>(b, 0xc8), 0, b, 0x40))) {
      s.actors = get<int32_t>(b, 0x30);
      s.actor_player = get<int32_t>(b, 0x3c);
    }
  }
  if (s.logic && (s.logic_ok = follow(s.logic, 0, b, 0x5c8))) {
    s.turn = get<uint32_t>(b, 0x14);
    s.zone[0] = get<uint32_t>(b, 0x598);
    s.zone[1] = get<uint32_t>(b, 0x59c);
    s.b5b1 = b[0x5b1];
    s.task = get<uint64_t>(b, 0x5c0);
  }
  if (s.net && (s.net_ok = follow(s.net, 0, b, 0x18)))
    s.net_mode = get<int32_t>(b, 0x14);
  uint64_t hop = 0, registry = 0; // r = *(*(*(spawn global) + 0x58) + 0x28).
  if (s.spawn && follow(s.spawn, 0x58, &hop, 8) && follow(hop, 0x28, &registry, 8) && follow(registry, 0, b, 0x90)) {
    s.spawnreg = int64_t(get<int32_t>(b, 0x60)) - get<int32_t>(b, 0x8c); // 64 bits: hostile i32s cannot overflow.
    s.spawn_ok = s.spawnreg >= 0 && s.spawnreg <= 100000;
  }
  return s;
}

inline std::string f2(float v) {
  char text[64]; // FLT_MAX is 39 digits.
  std::snprintf(text, sizeof text, "%.2f", double(v));
  return text;
}
inline std::string fname(const uint32_t *name) { return std::to_string(name[0]) + ":" + std::to_string(name[1]); }

// The rule's player count, or -1 unless 0 <= free <= num <= 64.
inline int players(const Sample &s) {
  return 0 <= s.free_count && s.free_count <= s.num && s.num <= 64 ? s.num - s.free_count : -1;
}

// The part of a line whose change writes a line at once.
inline std::string fixed(const Sample &s, bool threaded) {
  if (!s.ok)
    return "globals=?";
  std::string t;
  if (!s.mgr)
    t = "mgr=none";
  else if (!s.mgr_ok)
    t = "rule=? state=? lives=? players=? p0=? timers=?";
  else {
    int n = players(s);
    t = "rule=" + fname(s.alias) + " state=" + std::to_string(s.state) + " lives=" + std::to_string(s.lives) +
        " players=" + (n < 0 ? "?" : std::to_string(n)) + " p0=";
    if (!s.num)
      t += "-";
    else if (!s.p0_ok)
      t += "?";
    else {
      char hex[24];
      std::snprintf(hex, sizeof hex, "%llx", static_cast<unsigned long long>(s.p0));
      t += hex;
      for (int32_t v : s.p0_fields)
        t += "," + std::to_string(v);
    }
    t += " timers=" + (s.timers >= 0 && s.timers <= 3 ? std::to_string(s.timers)
                                                       : "?(" + std::to_string(s.timers) + ")");
  }
  t += !s.world      ? " world=none"
       : !s.world_ok ? " world=? actors=?"
                     : " world=" + std::to_string(s.world34) + "," + std::to_string(s.world74) + "," +
                           std::to_string(s.world320) + " actors=" +
                           (s.actors_ok ? std::to_string(s.actors) + "/" + std::to_string(s.actor_player) : "?");
  t += !s.logic      ? " logic=none"
       : !s.logic_ok ? " b5b1=? zone=?"
                     : " b5b1=" + std::to_string(s.b5b1) + " zone=" + fname(s.zone);
  t += std::string(" threaded=") + (threaded ? "yes" : "no");
  t += !s.net ? " net=none" : !s.net_ok ? " net=?" : " net=" + std::to_string(s.net_mode);
  t += !s.spawn ? " spawnreg=none" : !s.spawn_ok ? " spawnreg=?" : " spawnreg=" + std::to_string(s.spawnreg);
  return t;
}

// The part after " | ": it changes every frame, so it is written only with a state line.
inline std::string moving(const Sample &s) {
  if (!s.ok)
    return "globals=?";
  std::string t;
  if (!s.mgr)
    t = "mgr=none";
  else if (!s.mgr_ok)
    t = "time=? now=? timer=?";
  else {
    t = "time=" + f2(s.time) + " now=" + f2(s.now) + " timer=";
    if (!s.timers_ok)
      t += "?";
    else if (!s.timers)
      t += "-";
    else
      for (int i = 0; i < s.timers; ++i)
        t += (i ? "/" : "") + f2(s.timer[i]);
  }
  t += !s.logic ? " logic=none" : !s.logic_ok ? " turn=?" : " turn=" + std::to_string(s.turn);
  return t;
}

// Samples to file lines and the verdict. Worker-only, so no lock.
class Poller {
public:
  // t = 0, and the next step writes a line. The rule latch, the verdict and threaded last for the game run.
  void start(uint64_t now_ms) {
    start_ms_ = now_ms;
    fixed_.clear();
    count_ = -1;
  }
  // Arms the verdict for now + 60 s; false when a rule was already asked this run.
  bool rule(uint64_t now_ms) {
    if (asked_)
      return false;
    asked_ = true;
    rule_ms_ = now_ms;
    return true;
  }
  bool rule_asked() const { return asked_; }

  // The lines due now, each "<t> <text>" with t in seconds since start: the state line when the fixed part changed or
  // a second passed, one line per timer that rose by more than 1 (a re-arm), and the verdict once, at the rule + 60 s.
  std::vector<std::string> step(const Sample &s, uint64_t now_ms) {
    std::vector<std::string> lines;
    char t[32];
    std::snprintf(t, sizeof t, "%.1f ", (double(now_ms) - double(start_ms_)) / 1000);
    threaded_ = threaded_ || (s.logic_ok && s.task);
    std::string f = fixed(s, threaded_);
    if (f != fixed_ || now_ms >= line_ms_ + kLineMs) {
      lines.push_back(t + f + " | " + moving(s));
      fixed_ = f;
      line_ms_ = now_ms;
    }
    // Only samples after the rule request count, and only with the alias set: SB's logic thread can tear a read, so a
    // latch takes the alias and its other fields from the same sample.
    bool seen = asked_ && s.mgr_ok && s.alias[0];
    int count = s.mgr_ok && s.timers_ok ? s.timers : -1;
    if (count == count_)
      for (int i = 0; i < count; ++i)
        if (s.timer[i] - timer_[i] > 1.0f) { // Never true for NaN.
          lines.push_back(t + ("timer" + std::to_string(i)) + " re-armed " + f2(timer_[i]) + "->" + f2(s.timer[i]));
          rearms_ += seen;
        }
    count_ = count;
    std::memcpy(timer_, s.timer, sizeof timer_);
    mgr_ = mgr_ || (asked_ && s.mgr);
    if (seen) {
      int n = players(s);
      alias_ = true;
      active_ = active_ || s.state >= 1;
      running_ = running_ || s.state == 2;
      player_ = player_ || ((s.state == 1 || s.state == 2) && n >= 1);
      refused_ = refused_ || (s.state == 1 && n >= 1 && s.time <= 0);
      row_ = row_ || (s.state == 1 && s.timers_ok && s.timers == 3 && s.time > 0 && s.time <= 5.01f &&
                      s.timer[0] > 0 && s.timer[0] <= 15.01f);
    }
    if (asked_ && !told_ && now_ms >= rule_ms_ + kVerdictMs) {
      told_ = true;
      lines.push_back(t + verdict());
    }
    return lines;
  }

private:
  // G1-G5 of the probe: the rule set (alias), started (state 1 with the row's wait and timer), held EVE (players),
  // ran (state 2: RuleStart found the row) and fired its timed zone events (re-arms).
  std::string verdict() const {
    return std::string("verdict 60 s after the rule request: G1=") +
           (alias_ ? "yes (alias set)" : "unknown (alias unchanged; G7 tells for CreateActor)") + " G2=" +
           (!mgr_      ? "not reached (no manager)"
            : !alias_  ? "not reached (alias unchanged)"
            : !active_ ? "no (alias set, state 0)"
            : row_     ? "yes (wait 5, timer 15: the row's values)"
                       : "yes (row values not seen)") +
           " G3=" + (player_ ? "yes" : active_ ? "no (state 1, players 0)" : "not reached") + " G4=" +
           (running_ ? "yes" : refused_ ? "no (wait ran out in state 1: RuleStart refused the row)" : "not reached") +
           " G5=" +
           (rearms_ ? "yes (" + std::to_string(rearms_) + " re-arms)"
            : active_ ? "no (timers never re-armed)"
                      : "not reached") +
           " threaded=" + (threaded_ ? "yes" : "no");
  }

  uint64_t start_ms_ = 0, line_ms_ = 0, rule_ms_ = 0;
  std::string fixed_; // The last state line's fixed part.
  int count_ = -1;    // The previous sample's timer count, -1 when unreadable.
  float timer_[3] = {};
  bool threaded_ = false, asked_ = false, told_ = false;
  // Verdict latches.
  bool mgr_ = false, alias_ = false, active_ = false, running_ = false, player_ = false, refused_ = false, row_ = false;
  int rearms_ = 0;
};

} // namespace coop::nightop
