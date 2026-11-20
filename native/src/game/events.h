// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// When the ghost's features may call the game; the events a pose carries (what her game played: a sound, an effect,
// a trail) and the sender's side of them: the Outbox that puts them in the pose's event slots and the asset keys their
// names travel under. No Windows types: tests/native/game/events_test.cpp checks it on the build machine. game/codec.h
// writes and reads an event slot's bytes (put_event, get_event).
#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>
#include <unordered_map>

#include "game/travel.h"    // kInGame, kPlaying
#include "link/pose_cap.h" // kPoseCaps, kPoseCapCount

namespace coop::pose {

// A pose's event slots, each kEventBytes on the wire (game/codec.h); at most kMaxAssetKeys asset keys per sender in a
// link session; kNoPart: an event placed relative to part 0, not attached to a part.
constexpr size_t kEventSlots = 4, kEventBytes = 19, kMaxAssetKeys = 4096;
constexpr uint8_t kNoPart = 0xff;
enum class Kind : uint8_t { none, sound, niagara, cascade, decal, trail_on, trail_off };
// One event. Wire (game/codec.h's put_event): kind, serial, asset (u16), part, value[2], translation (3 i16 in cm),
// rotation (6 bytes, the codec's smallest three); an empty slot is 19 zero bytes. asset: its key, 1 to kMaxAssetKeys
// (AssetKeys). part kNoPart: placed relative to part 0; else attached to that part with that offset (no socket on the
// wire). value: a sound's volume and pitch in 1/64 steps; Niagara and Cascade a uniform scale in 1/32 steps and 0;
// else 0 0. place: rotation xyzw, translation xyz. serial: a new event in the slot (Outbox).
struct Event {
  Kind kind = Kind::none;
  uint8_t serial = 0, part = kNoPart;
  uint16_t asset = 0;
  uint8_t value[2] = {};
  float place[7] = {};
};

// The sender's events on their way into the pose's slots: at most kWaiting wait, a waiting event older than kWaitUs is
// dropped. A slot frees once its event rode in at least kHoldPoses filled poses and kHoldUs plus one send interval
// passed since it was placed: link/core.h's send_binary gives a member on the lowest pose cap (20 a second) a pose at
// most each 1000 / 20 - kPoseSlackMs ms, so she gets a pose that carries it. Each new event in a slot takes the slot's
// serial + 1 (1 to 255, then 1 again). Game thread; no allocation.
constexpr uint64_t kWaitUs = 100'000, kHoldUs = 1'000'000 / kPoseCaps[kPoseCapCount - 1];
constexpr uint32_t kHoldPoses = 2;
class Outbox {
public:
  static constexpr size_t kWaiting = 8;
  // An event at now: waiting, or false (counted in dropped()) when kWaiting already wait.
  bool push(const Event &e, uint64_t now_us) {
    if (count_ == kWaiting) {
      ++dropped_;
      return false;
    }
    waiting_[(first_ + count_++) % kWaiting] = {e, now_us};
    return true;
  }
  // The pose about to be encoded at now: its slots (kEventSlots) written. In order: the slots held long enough free,
  // the waits past kWaitUs are dropped (counted), the oldest waits take the free slots. every_us: the stream's send
  // interval.
  void fill(Event *slots, uint64_t now_us, uint64_t every_us) {
    for (Held &h : held_)
      if (h.event.kind != Kind::none && h.poses >= kHoldPoses && now_us >= h.placed + kHoldUs + every_us)
        h.event = Event();
    for (; count_ && now_us > waiting_[first_].at + kWaitUs; first_ = (first_ + 1) % kWaiting, --count_)
      ++dropped_;
    for (Held &h : held_) {
      if (h.event.kind == Kind::none && count_) {
        h.serial = h.serial == 255 ? 1 : uint8_t(h.serial + 1);
        h.event = waiting_[first_].event;
        h.event.serial = h.serial;
        h.placed = now_us;
        h.poses = 0;
        first_ = (first_ + 1) % kWaiting;
        --count_;
      }
      h.poses += h.event.kind != Kind::none;
    }
    for (size_t k = 0; k < kEventSlots; ++k)
      slots[k] = held_[k].event;
  }
  uint64_t dropped() const { return dropped_; }

private:
  struct Waiting {
    Event event;
    uint64_t at = 0;
  };
  struct Held {
    Event event;
    uint64_t placed = 0;
    uint32_t poses = 0;
    uint8_t serial = 0;
  };
  Waiting waiting_[kWaiting];
  Held held_[kEventSlots];
  size_t first_ = 0, count_ = 0;
  uint64_t dropped_ = 0;
};

// The sender's asset keys for one link session. known(): the k of an object already seen (its address, its class and
// attenuation, its index and serial, so a freed and reused address is unknown), 0 for none. The game thread then
// resolves its paths once (words: what its SBA line carries after k) and calls add(), which gives the k those words
// already have, else the next one from 1 (fresh). A k is never reused until clear() (a new link session); past
// kMaxAssetKeys add() gives 0 (counted in full()). An asset collected after a map change and loaded again keeps its k:
// its words name it. The object cache holds kObjects, the oldest given up first. Game thread.
class AssetKeys {
public:
  static constexpr size_t kObjects = 512;
  uint16_t known(Kind kind, uint64_t asset, uint64_t a, uint64_t b, int32_t index, int32_t serial) const {
    const Object o{kind, asset, a, b, index, serial, 0};
    for (const Object &x : objects_)
      if (x.k && x.same(o))
        return x.k;
    return 0;
  }
  uint16_t add(Kind kind, uint64_t asset, uint64_t a, uint64_t b, int32_t index, int32_t serial,
               std::string_view words, bool &fresh) {
    fresh = false;
    uint16_t k = 0;
    if (auto it = words_.find(std::string(words)); it != words_.end()) {
      k = it->second;
    } else if (words_.size() == kMaxAssetKeys) {
      ++full_;
      return 0;
    } else {
      k = uint16_t(words_.size() + 1);
      words_.emplace(words, k);
      fresh = true;
    }
    if (!known(kind, asset, a, b, index, serial)) {
      objects_[next_] = {kind, asset, a, b, index, serial, k};
      next_ = (next_ + 1) % kObjects;
    }
    return k;
  }
  void clear() {
    words_.clear();
    objects_.fill(Object());
    next_ = 0;
  }
  uint64_t full() const { return full_; }

private:
  struct Object {
    Kind kind = Kind::none;
    uint64_t asset = 0, a = 0, b = 0;
    int32_t index = 0, serial = 0;
    uint16_t k = 0; // 0: an empty entry.
    bool same(const Object &o) const {
      return kind == o.kind && asset == o.asset && a == o.a && b == o.b && index == o.index && serial == o.serial;
    }
  };
  std::unordered_map<std::string, uint16_t> words_;
  std::array<Object, kObjects> objects_{};
  size_t next_ = 0;
  uint64_t full_ = 0;
};

// The game thread may call SB for the ghost's features when lion_gate is open (net mode 0, no logic task in flight),
// the client is in game (flow travel::kInGame) and playing (phase travel::kPlaying) and the caller is not SB's logic
// thread. These are world_in_game()'s conditions without its write of world_engine.caster.
inline bool game_calls_ok(bool gate_open, int32_t flow, int32_t phase, bool logic_thread) {
  return gate_open && flow == travel::kInGame && phase == travel::kPlaying && !logic_thread;
}

} // namespace coop::pose
