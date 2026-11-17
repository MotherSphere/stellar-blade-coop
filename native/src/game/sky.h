// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The day/night cycle's clock and light, free of Windows, tested by tests/native/game/sky_test.cpp. One real hour is
// one game day, shared by every player through UTC: hour = 24 * (((t - 120 s) mod 3600 s) / 3600 s), so midnight falls
// at :02 past each real hour, sunrise (04:00) at :12, noon at :32 and sunset (20:00) at :52. The sun runs two sine
// arcs: by day (04:00 to 20:00) p = (hour - 4) / 16, elevation 65 sin(pi p), heading H + 180 (p - 0.5); by night
// q = ((hour - 20) mod 24) / 8, elevation -30 sin(pi q), heading H + 90 + 180 q. H is the map's noon heading. Under
// -4 degrees the moon, the point opposite the sun, is the light. Every dawn and dusk ramp runs on the sun's elevation,
// so it is the same on every PC.
#pragma once

#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

namespace coop::sky {

constexpr double kPeak = 65, kDeep = 30; // The sun's noon peak and midnight depth, degrees.
constexpr double kMoon = 0.15, kNightSky = 0.2, kNightEve = 0.5, kNightFog = 0.15, kNightEv = -1.0; // Full night.
constexpr double kPi = 3.14159265358979323846;

// The hour of the shared game day, in [0, 24).
inline double hour_at(uint64_t utc_ms) {
  int64_t ms = (static_cast<int64_t>(utc_ms) - 120000) % 3600000;
  if (ms < 0)
    ms += 3600000;
  return 24.0 * static_cast<double>(ms) / 3600000.0;
}

// Smoothstep: 0 at a, 1 at b, either way round.
inline double ramp(double x, double a, double b) {
  double t = (x - a) / (b - a);
  t = t < 0 ? 0 : t > 1 ? 1 : t;
  return t * t * (3 - 2 * t);
}

// The sun's colour: warm (1.00, 0.55, 0.30) at the horizon hz, white from hz + 15 degrees up.
inline void sun_tint(double el, int hz, float out[3]) {
  const double w = ramp(el, hz, hz + 15.0);
  out[0] = 1.0f;
  out[1] = static_cast<float>(0.55 + 0.45 * w);
  out[2] = static_cast<float>(0.30 + 0.70 * w);
}

struct Light {
  double hour, el, le, ly, k, amb, eve, fog, glow, ev; // el: the sun's signed elevation; le, ly: the light's.
  float tint[3];
  float dir[3]; // The light's travel vector (cos le cos ly, cos le sin ly, -sin le).
  bool moon;    // The moon is the light: the sun is under -4 degrees.
};

inline Light light_at(double hour, int hz, int heading) {
  Light l{};
  l.hour = hour;
  double yaw;
  if (hour >= 4 && hour < 20) {
    const double p = (hour - 4) / 16;
    l.el = kPeak * std::sin(kPi * p);
    yaw = heading + 180 * (p - 0.5);
  } else {
    const double q = std::fmod(hour - 20 + 24, 24) / 8;
    l.el = -kDeep * std::sin(kPi * q);
    yaw = heading + 90 + 180 * q;
  }
  const double sun = ramp(l.el, hz, hz + 10.0);
  l.moon = l.el < -4;
  if (l.moon) {
    l.le = -l.el;
    l.ly = std::fmod(yaw + 180 + 720, 360);
    l.k = kMoon * ramp(l.el, -4, -12);
    l.tint[0] = 0.70f;
    l.tint[1] = 0.80f;
    l.tint[2] = 1.00f;
  } else {
    l.le = l.el;
    l.ly = std::fmod(yaw + 720, 360);
    l.k = sun;
    sun_tint(l.el, hz, l.tint);
  }
  const double n = 1 - ramp(l.el, -12, 6);
  l.amb = 1 - (1 - kNightSky) * n;
  l.eve = 1 - (1 - kNightEve) * n;
  l.fog = 1 - (1 - kNightFog) * n;
  l.glow = sun;
  l.ev = kNightEv * n;
  const double le = l.le * kPi / 180, ly = l.ly * kPi / 180;
  l.dir[0] = static_cast<float>(std::cos(le) * std::cos(ly));
  l.dir[1] = static_cast<float>(std::cos(le) * std::sin(ly));
  l.dir[2] = static_cast<float>(-std::sin(le));
  return l;
}

// SB's env settings on AWorldSettings, read in UWorld::AddPostProcessingSettings 0x1446A36C0 (WorldSettings from
// UWorld+0x30 then ULevel+0x268; +0x1420 the env-active byte and +0x1430 the main view's blended copy, written each
// frame) and in the blend FUN_1446B00A0 (array data +0x2E0, Num +0x2E8 int32, stride 0xB30; forced byte +0x2F0 with
// its settings pointer +0x2F8, which skips the array; the bUse-gated blend byte +0x2018; each element's volume +0x18
// whose vtable +0x6C0 gives its weight, data pointer +0x20). The blend reads the array afresh each frame, so a value
// written into an element is what SB draws from the next frame on. Build 26123051.
constexpr size_t kArray = 0x2E0, kNum = 0x2E8, kForcedFlag = 0x2F0, kForced = 0x2F8, kGated = 0x2018;
constexpr size_t kViewFlag = 0x1420, kViewSun = 0x14A0; // +0x1430 copy + kSun.
// One element (FSBEnvControlSettings), its fields summed by FUN_1444F60D0: Direction_Sun +0x4C, Color_Sun +0x5C,
// Intensity_Sun +0x70, Intensity_SkyLight +0x180, Intensity_Character +0x1D8 and Sub +0x20C, FogInscatteringColor
// +0x254, DirectionalInscatteringColor +0x2AC; PostProcessData at +0x430 applied by FUN_1445031D0, whose
// AutoExposureBias (+0x33C, so +0x76C) counts only with bit 0x02 of its override byte +0xB (+0x43B).
constexpr size_t kStride = 0xB30, kVolume = 0x18, kData = 0x20, kDir = 0x4C, kColor = 0x5C, kSun = 0x70, kSky = 0x180;
constexpr size_t kEve = 0x1D8, kEveSub = 0x20C, kFog = 0x254, kGlow = 0x2AC, kBiasBits = 0x43B, kBias = 0x76C;
constexpr uint8_t kBiasBit = 0x02;
constexpr int kMaxElements = 256; // The largest array in the map dump holds 114.
constexpr uint64_t kPassMs = 100; // The sun moves 0.01 degree in that time.

enum class Mode : uint8_t { off, cycle, pinned, held };
struct Want {
  Mode mode = Mode::off;
  uint16_t minute = 0; // Pinned: the minute of the game day.
  uint8_t hz = 8;      // The map's horizon, degrees.
  uint16_t heading = 0; // The map's noon heading, degrees.
};
enum class State : uint8_t { off, cycle, pinned, held, waiting, forced, scene, gated, full, fault, refused };

inline const char *word(State s) {
  static const char *const words[] = {"off",   "cycle", "pinned", "held",  "waiting", "forced",
                                      "scene", "gated", "full",   "fault", "refused"};
  return words[static_cast<int>(s)];
}

// The status line's sky= row, no newline. Adding 0.0 prints a negative zero as 0. h, le and ly carry what Lua turns
// with each 250 ms (the light moves about 0.02 degree, a SkyCreator's sky 0.025): coarser, they would move in visible
// steps (0.1 degree every 1.2 s, 0.15 every 1.5 s).
inline std::string line(State s, const Light &l, int n, int lit, bool seen) {
  char b[256];
  std::snprintf(b, sizeof b,
                "sky=%s h=%.4f el=%.1f le=%.3f ly=%.3f k=%.3f moon=%d amb=%.3f eve=%.3f ev=%.2f tint=%.2f,%.2f,%.2f "
                "n=%d lit=%d seen=%d",
                word(s), l.hour + 0.0, l.el + 0.0, l.le + 0.0, l.ly + 0.0, l.k + 0.0, l.moon ? 1 : 0, l.amb + 0.0,
                l.eve + 0.0, l.ev + 0.0, l.tint[0] + 0.0, l.tint[1] + 0.0, l.tint[2] + 0.0, n, lit, seen ? 1 : 0);
  return b;
}

// Writes the light of the hour into every element of SB's env array from the originals it read there, so SB's own
// blend does the per-frame work. Memory is reached by address: the caller runs it under its own fault guard. scene:
// SB plays a cutscene or a talk scene (its theater), whose env volumes must draw SB's own light.
class Sky {
public:
  State pass(uintptr_t world, uintptr_t settings, const Want &want, uint64_t utc_ms, bool scene = false) {
    elements_ = sunlit_ = 0;
    if (want.mode != Mode::held)
      held_ = false;
    double hour = hour_at(utc_ms);
    if (want.mode == Mode::pinned)
      hour = want.minute / 60.0;
    else if (want.mode == Mode::held) {
      if (!held_) { // The hour drawn when the hold came: a pinned one (Night Operation, a test) stays, not the clock's.
        held_hour_ = last_ == Mode::pinned ? light_.hour : hour;
        held_ = true;
      }
      hour = held_hour_;
    }
    last_ = want.mode;
    light_ = light_at(hour, want.hz, want.heading);
    if (settings == 0 || world != world_ || settings != settings_) { // The old array died with its world.
      drop();
      world_ = world;
      settings_ = settings;
    }
    seen_ = settings && rd<uint8_t>(settings + kViewFlag) != 0 && rd<float>(settings + kViewSun) > 0;
    if (want.mode == Mode::off) { // Even under SB's forced settings: the array is ours to put back.
      restore();
      return State::off;
    }
    if (scene) { // The scene's CutScene_ and Dialogue_ volumes blend from the array: SB's values until it ends.
      restore();
      return State::scene;
    }
    if (settings == 0)
      return State::waiting;
    if (rd<uint8_t>(settings + kForcedFlag) != 0 && rd<uint64_t>(settings + kForced) != 0)
      return State::forced; // SB draws its forced block, not the array: leave the array as it is.
    if (rd<uint8_t>(settings + kGated) != 0) {
      restore();
      return State::gated;
    }
    const int32_t n = rd<int32_t>(settings + kNum);
    const uintptr_t array = rd<uintptr_t>(settings + kArray);
    if (n > kMaxElements) {
      restore();
      return State::full;
    }
    if (n < 0 || (n > 0 && array == 0))
      return State::waiting;
    const Entry *old = cache_[cur_];
    Entry *next = cache_[cur_ ^ 1];
    for (int i = 0; i < n; ++i) {
      const uintptr_t e = array + static_cast<uintptr_t>(i) * kStride;
      Entry &c = next[i];
      const Entry *was = find(old, count_, i, rd<uint64_t>(e + kVolume), rd<uint64_t>(e + kData));
      const float now = rd<float>(e + kSun);
      if (was && (now == was->sun || now == was->wrote_sun))
        c = *was;
      else
        read(c, e); // New, or SB copied other values in: these are its originals now.
      write(c, e);
      sunlit_ += c.lit;
    }
    cur_ ^= 1;
    count_ = elements_ = n;
    holding_ = n > 0;
    return want.mode == Mode::cycle ? State::cycle : want.mode == Mode::pinned ? State::pinned : State::held;
  }

  // Every element of the current array this cache knows gets its originals back once, where it still holds the value
  // written last or its original; then nothing is held.
  void restore() {
    const int32_t n = settings_ ? rd<int32_t>(settings_ + kNum) : 0;
    const uintptr_t array = settings_ ? rd<uintptr_t>(settings_ + kArray) : 0;
    for (int i = 0; array && count_ && i < n && i < kMaxElements; ++i) {
      const uintptr_t e = array + static_cast<uintptr_t>(i) * kStride;
      const Entry *c = find(cache_[cur_], count_, i, rd<uint64_t>(e + kVolume), rd<uint64_t>(e + kData));
      const float now = c ? rd<float>(e + kSun) : 0;
      if (!c || (now != c->sun && now != c->wrote_sun))
        continue;
      wr3(e + kDir, c->dir);
      if (!c->lit)
        continue;
      wr(e + kSun, c->sun);
      wr3(e + kColor, c->color);
      wr(e + kSky, c->sky);
      wr(e + kEve, c->eve);
      wr(e + kEveSub, c->eve_sub);
      wr3(e + kFog, c->fog);
      wr3(e + kGlow, c->glow);
      if (c->bias_bits & kBiasBit)
        wr(e + kBias, c->bias);
    }
    drop();
  }

  bool holding() const { return holding_; }
  int elements() const { return elements_; }
  int sunlit() const { return sunlit_; }
  bool seen() const { return seen_; }
  const Light &light() const { return light_; }

private:
  struct Entry {
    uint64_t volume, data;
    float sun, color[3], sky, eve, eve_sub, fog[3], glow[3], bias, dir[3], wrote_sun;
    uint8_t bias_bits;
    bool lit;
  };

  template <class T> static T rd(uintptr_t a) {
    T v;
    std::memcpy(&v, reinterpret_cast<const void *>(a), sizeof v);
    return v;
  }
  static void wr(uintptr_t a, double v) {
    const float f = static_cast<float>(v);
    std::memcpy(reinterpret_cast<void *>(a), &f, sizeof f);
  }
  static void wr3(uintptr_t a, const float v[3]) { std::memcpy(reinterpret_cast<void *>(a), v, 3 * sizeof(float)); }
  static void rd3(uintptr_t a, float v[3]) { std::memcpy(v, reinterpret_cast<const void *>(a), 3 * sizeof(float)); }

  // The entry of element i: where it was last pass, else anywhere (SB moved it), else none.
  static const Entry *find(const Entry *old, int n, int i, uint64_t volume, uint64_t data) {
    if (i < n && old[i].volume == volume && old[i].data == data)
      return &old[i];
    for (int k = 0; k < n; ++k)
      if (old[k].volume == volume && old[k].data == data)
        return &old[k];
    return nullptr;
  }

  static void read(Entry &c, uintptr_t e) {
    c.volume = rd<uint64_t>(e + kVolume);
    c.data = rd<uint64_t>(e + kData);
    c.sun = c.wrote_sun = rd<float>(e + kSun);
    rd3(e + kColor, c.color);
    c.sky = rd<float>(e + kSky);
    c.eve = rd<float>(e + kEve);
    c.eve_sub = rd<float>(e + kEveSub);
    rd3(e + kFog, c.fog);
    rd3(e + kGlow, c.glow);
    c.bias = rd<float>(e + kBias);
    rd3(e + kDir, c.dir);
    c.bias_bits = rd<uint8_t>(e + kBiasBits);
    c.lit = c.sun > 0; // A covered element (cave, room) gets only the direction, which changes nothing there.
  }

  void write(Entry &c, uintptr_t e) const {
    const Light &l = light_;
    wr3(e + kDir, l.dir);
    if (!c.lit)
      return;
    c.wrote_sun = static_cast<float>(c.sun * l.k);
    wr(e + kSun, c.wrote_sun); // 0 culls the light (FUN_1430FA210): no sunlight through the ground at night.
    for (int i = 0; i < 3; ++i) {
      wr(e + kColor + 4 * i, c.color[i] * l.tint[i]);
      wr(e + kFog + 4 * i, c.fog[i] * l.fog);
      wr(e + kGlow + 4 * i, c.glow[i] * l.glow);
    }
    wr(e + kSky, c.sky * l.amb);
    wr(e + kEve, c.eve * l.eve);
    wr(e + kEveSub, c.eve_sub * l.eve);
    if (c.bias_bits & kBiasBit)
      wr(e + kBias, c.bias + l.ev);
  }

  void drop() {
    count_ = 0;
    holding_ = false;
  }

  Entry cache_[2][kMaxElements]; // Last pass's entries and this pass's, swapped each pass: no heap.
  int cur_ = 0, count_ = 0, elements_ = 0, sunlit_ = 0;
  uintptr_t world_ = 0, settings_ = 0;
  Light light_{};
  Mode last_ = Mode::off; // The last pass's mode: light_ holds the hour it drew.
  double held_hour_ = 0;
  bool held_ = false, holding_ = false, seen_ = false;
};

} // namespace coop::sky
