// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The pose stream's two ends, free of Windows (tests/native/game/stream_test.cpp drives them with simulated time):
// DelayLine stands in for Steam in loopback (Phase 3): the worker sends each encoded pose into it and gets it back after
// a delay, with jitter and loss. Playback is the receiving side: the sister repository's RemoteEves clock and
// AvatarView.interpolate, ported, drawing the remote EVE 1.5 send intervals behind her newest pose.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <deque>
#include <limits>
#include <utility>
#include <vector>

#include "game/core.h"   // kTransformBytes, Effect, Free, kMaxParts
#include "game/events.h" // Event, kEventSlots

namespace coop::pose {

// A FIFO line (one SDR route does not reorder): each message is due delay ± jitter after it was sent, never before
// the one sent ahead of it. Loss is drawn per 1200-byte segment, as SDR fragments a message, and one lost segment loses
// the message. Worker thread.
class DelayLine {
public:
  static constexpr size_t kSegment = 1200;
  struct Settings {
    uint32_t delay_ms = 0, jitter_ms = 0, loss_percent = 0;
  };
  // New settings drop every message in flight.
  void set(Settings s, uint64_t seed) {
    s_ = s;
    rng_ = seed | 1;
    queue_.clear();
    last_due_ = 0;
  }
  // A message sent at now (µs): queued, or false when the loss model dropped it. A reliable message (the table, which
  // Steam would resend until acknowledged) is never lost, but still waits its turn behind the poses sent before it.
  bool send(const uint8_t *data, size_t size, uint64_t now, bool reliable = false) {
    for (size_t segment = 0; !reliable && segment < (size + kSegment - 1) / kSegment; ++segment)
      if (next() % 100 < s_.loss_percent)
        return false;
    uint64_t jitter = uint64_t(s_.jitter_ms) * 1000, late = uint64_t(s_.delay_ms) * 1000 + jitter;
    uint64_t early = jitter ? next() % (2 * jitter + 1) : 0;
    uint64_t due = std::max(now + (late > early ? late - early : 0), last_due_); // delay ± jitter, never below 0.
    last_due_ = due;
    queue_.emplace_back(due, std::vector<uint8_t>(data, data + size));
    return true;
  }
  // Each message due at now to f(data, size), oldest first.
  template <class F> void deliver(uint64_t now, F &&f) {
    while (!queue_.empty() && queue_.front().first <= now) {
      f(queue_.front().second.data(), queue_.front().second.size());
      queue_.pop_front();
    }
  }
  size_t queued() const { return queue_.size(); }

private:
  uint64_t next() { // xorshift64
    rng_ ^= rng_ << 13;
    rng_ ^= rng_ >> 7;
    rng_ ^= rng_ << 17;
    return rng_;
  }
  Settings s_;
  uint64_t rng_ = 1, last_due_ = 0;
  std::deque<std::pair<uint64_t, std::vector<uint8_t>>> queue_;
};

// One transform blended between a and b: nlerp for the rotation (xyzw at 0, b taken on a's side), lerp for the
// translation (at t) and the scale (at s). alpha above 1 extrapolates.
inline void blend_transform(const float *a, const float *b, float alpha, float *out, int t, int s) {
  float dot = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3], sign = dot < 0 ? -1.f : 1.f, norm = 0;
  for (int k = 0; k < 4; ++k) {
    out[k] = a[k] + alpha * (sign * b[k] - a[k]);
    norm += out[k] * out[k];
  }
  norm = std::sqrt(norm);
  for (int k = 0; k < 4; ++k)
    out[k] = norm > 1e-6f ? out[k] / norm : (k == 3 ? 1.f : 0.f);
  for (int k = 0; k < 3; ++k) {
    out[t + k] = a[t + k] + alpha * (b[t + k] - a[t + k]);
    out[s + k] = a[s + k] + alpha * (b[s + k] - a[s + k]);
  }
}

// The receiving side for one remote EVE: her recent poses by publication time (the sender's clock), drawn at
// now - floor - interval - max(interval / 2, spread). The clock floor is the least arrival minus publication (transit
// plus the clock offset between the two machines): it drops to any lower lag at once and otherwise rises 1 ms a second,
// so it follows drift both ways; a lag that stays 250 ms above it for 5 s (a clock step) moves it to the least lag of
// those 5 s at once. After kSilentMs without a pose the old poses are dropped, so she never slides across the gap. The
// spread is the recent peak of lag above the floor (jitter), decaying 10 ms a second and capped at 250 ms: without
// jitter she is drawn 1.5 intervals back, as in the sister repository; with jitter far enough back that a late pose is
// still ahead of her. Between two poses the pose is interpolated; past the newest it is extrapolated at most half an
// interval. Game thread; reset() allocates and runs on the worker (with the Live), so no frame ever allocates.
class Playback {
public:
  static constexpr size_t kFrames = 24; // 400 ms of poses at 60 a second (8 were 400 ms at 20).
  static constexpr double kIntervalCapMs = 1000, kStepMs = 250, kWindowMs = 5000, kSilentMs = 3000, kSpreadDecay = 0.01;
  struct Frame {
    uint32_t sequence = 0;
    uint64_t publication = 0; // µs, the sender's clock.
    float root[10] = {};
    std::vector<uint8_t> bones;
    Effect fx[kEffectSlots];
    Free free[kMaxParts]; // The free parts' blocks in table order; the rest stay hidden.
    Event events[kEventSlots];
  };
  // Counts since the last take(), for the counter line.
  struct Stats {
    uint64_t poses = 0, stale = 0, lost = 0, stalls = 0, steps = 0, drawn = 0, extrapolated = 0;
    double lag_ms = 0, behind_ms = 0; // Sums over poses and over drawn frames.
  };

  void reset(size_t bone_bytes) {
    for (auto &f : frames_) {
      f.bones.assign(bone_bytes, 0);
      std::fill(f.free, f.free + kMaxParts, Free());
      std::fill(f.events, f.events + kEventSlots, Event());
    }
    scratch_.bones.assign(bone_bytes, 0);
    std::fill(scratch_.free, scratch_.free + kMaxParts, Free());
    std::fill(scratch_.events, scratch_.events + kEventSlots, Event());
    clear();
  }
  // Forgets every pose and the clock (a new stream); keeps the memory. The next sample() passes no event.
  void clear() {
    count_ = newest_ = 0;
    primed_ = false;
    std::fill(played_, played_ + kEventSlots, uint8_t(0)); // The Outbox's serials start at 1.
    floor_ = std::numeric_limits<double>::quiet_NaN();
    interval_ = 50;
    gap_at_ = 0;
    spread_ = 0;
    above_ = false;
  }
  // Decode the next pose into this, then accept() it.
  Frame &scratch() { return scratch_; }
  // The scratch pose arrived at arrival (µs, this machine's clock). False when it is not newer than the newest.
  bool accept(uint64_t arrival_us) {
    double arrival = arrival_us / 1000.0, publication = scratch_.publication / 1000.0;
    if (count_) {
      const Frame &newest = frames_[newest_];
      if (scratch_.sequence <= newest.sequence) {
        ++stats_.stale;
        return false;
      }
      if (arrival - last_arrival_ > kSilentMs)
        count_ = 0; // Counted below as a stall; the poses from before the silence are not blended with this one.
      stats_.lost += scratch_.sequence - newest.sequence - 1;
      // The median of the last 8 gaps: a steady skip (a match member's cap, every 2nd or 3rd pose) is the spacing she
      // gets, while one hole (a lost keyframe's 15 keyless deltas) does not lengthen it.
      double gap = publication - newest.publication / 1000.0;
      if (gap > 0 && gap < kIntervalCapMs) {
        gaps_[gap_at_++ % 8] = gap;
        double sorted[8];
        const size_t n = std::min<size_t>(gap_at_, 8);
        std::copy(gaps_, gaps_ + n, sorted);
        std::nth_element(sorted, sorted + n / 2, sorted + n);
        interval_ = interval_ * 0.9 + sorted[n / 2] * 0.1;
      }
      if (arrival - last_arrival_ > std::max(250.0, 3 * interval_))
        ++stats_.stalls;
    }
    double lag = arrival - publication;
    floor_ = std::isnan(floor_) ? lag : std::min(lag, floor_ + (arrival - last_arrival_) / 1000);
    if (lag > floor_ + kStepMs) { // Above the line: since when, and the least lag since then.
      if (!above_)
        above_ = true, above_since_ = arrival, lowest_ = lag;
      lowest_ = std::min(lowest_, lag);
      if (arrival - above_since_ >= kWindowMs) { // A clock step, not jitter.
        floor_ = lowest_, spread_ = 0, above_ = false;
        ++stats_.steps;
      }
    } else {
      above_ = false;
    }
    spread_ = std::min(kStepMs, std::max(lag - floor_, spread_ - (arrival - last_arrival_) * kSpreadDecay));
    last_arrival_ = arrival;
    newest_ = count_ ? (newest_ + 1) % kFrames : 0;
    std::swap(frames_[newest_], scratch_);
    count_ = std::min(count_ + 1, kFrames);
    ++stats_.poses;
    stats_.lag_ms += lag;
    return true;
  }
  // The pose to draw at now into root (10 floats), bones (the scratch's size), fx (kEffectSlots) and free (kMaxParts,
  // nullptr: none); false when there is none yet or the stream has been silent for kSilentMs. The effect slots are
  // held, never blended: the older pose's. A free block is blended when both poses show it, with the newer one's state;
  // else the newer one's is drawn as it is.
  bool sample(uint64_t now_us, float *root, uint8_t *bones, Effect *fx, Free *free = nullptr) {
    double now = now_us / 1000.0;
    if (!count_ || now - last_arrival_ > kSilentMs)
      return false;
    double at = display_ms(now);
    shown_ms_ = at;
    if (!primed_) { // A new playback: the events standing in its buffered poses were played before it, or never.
      for (size_t k = 0; k < count_; ++k)
        for (size_t n = 0; n < kEventSlots; ++n)
          played_[n] = frame(k).events[n].kind != Kind::none ? frame(k).events[n].serial : played_[n];
      passed_ = frames_[newest_].sequence;
      primed_ = true;
    }
    size_t b = newest_, a = (newest_ + kFrames - 1) % kFrames;
    if (count_ == 1)
      a = b;
    for (size_t k = 2; k < count_ && at < ms(a); ++k) {
      b = a;
      a = (a + kFrames - 1) % kFrames;
    }
    double span = ms(b) - ms(a);
    // At most half an interval past the newest pose, however far apart the last two are (a lost pose between them).
    float alpha = span > 0 ? float(std::clamp((at - ms(a)) / span, 0.0, 1 + interval_ / 2 / span)) : 1.f;
    const Frame &fa = frames_[a], &fb = frames_[b];
    blend_transform(fa.root, fb.root, alpha, root, 4, 7);
    for (size_t at_byte = 0; at_byte + kTransformBytes <= fa.bones.size(); at_byte += kTransformBytes) {
      float x[12], y[12], out[12];
      std::memcpy(x, fa.bones.data() + at_byte, sizeof x);
      std::memcpy(y, fb.bones.data() + at_byte, sizeof y);
      blend_transform(x, y, alpha, out, 4, 8);
      out[7] = out[11] = 0;
      std::memcpy(bones + at_byte, out, sizeof out);
    }
    std::copy(fa.fx, fa.fx + kEffectSlots, fx);
    for (size_t k = 0; free && k < kMaxParts; ++k) {
      free[k] = fb.free[k];
      if (fa.free[k].state & fb.free[k].state & 0x80)
        blend_transform(fa.free[k].place, fb.free[k].place, alpha, free[k].place, 4, 7);
    }
    ++stats_.drawn;
    stats_.extrapolated += at > ms(newest_);
    stats_.behind_ms += ms(newest_) - at;
    return true;
  }
  // The events of the poses the last sample() reached (publication at or before its display time) that no earlier
  // call passed, oldest pose first, into out (cap of them): each slot's serial once, so an event riding in several
  // poses plays once (a serial equal to the slot's last played one is skipped). Past cap, the rest wait for the next
  // call. Returns how many. The first sample() after reset() or clear() marks every buffered pose's events as played:
  // a restarted playback does not play again the events still standing in her slots.
  size_t passed(Event *out, size_t cap) {
    size_t n = 0;
    for (size_t k = 0; primed_ && k < count_; ++k) {
      const Frame &f = frame(k);
      if (f.sequence <= passed_)
        continue;
      if (f.publication / 1000.0 > shown_ms_)
        break;
      for (size_t s = 0; s < kEventSlots; ++s) {
        const Event &e = f.events[s];
        if (e.kind == Kind::none || e.serial == played_[s])
          continue;
        if (n == cap)
          return n;
        out[n++] = e;
        played_[s] = e.serial;
      }
      passed_ = f.sequence;
    }
    return n;
  }
  Stats take() { return std::exchange(stats_, Stats{}); }
  // The sender's time drawn at now (both in ms).
  double display_ms(double now) const { return now - floor_ - interval_ - std::max(interval_ / 2, spread_); }

private:
  double ms(size_t i) const { return frames_[i].publication / 1000.0; }
  const Frame &frame(size_t k) const { return frames_[(newest_ + kFrames + 1 - count_ + k) % kFrames]; } // k: 0 oldest
  Frame frames_[kFrames], scratch_;
  size_t count_ = 0, newest_ = 0;
  double floor_ = std::numeric_limits<double>::quiet_NaN(), interval_ = 50, spread_ = 0, last_arrival_ = 0;
  double gaps_[8] = {}; // The last publication gaps between accepted poses, for the interval's median.
  size_t gap_at_ = 0;
  bool above_ = false;
  double lowest_ = 0, above_since_ = 0;
  // Events: the last sample()'s display time, the newest sequence passed, each slot's last serial played. primed_: the
  // first sample of this playback marked what it found.
  double shown_ms_ = 0;
  uint32_t passed_ = 0;
  uint8_t played_[kEventSlots] = {};
  bool primed_ = false;
  Stats stats_;
};

} // namespace coop::pose
