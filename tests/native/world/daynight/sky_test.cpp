// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// world/daynight/sky.h on the build machine: the hour from UTC, the sun and moon path, the light factors and the env
// writer.
#include "world/daynight/sky.h"

#include <cassert>
#include <cmath>
#include <cstring>
#include <string>
#include <vector>

using namespace coop::sky;

namespace {
bool near(double a, double b, double eps = 1e-4) { return std::fabs(a - b) <= eps; }
constexpr uint64_t kBase = 1763380800000ULL; // 2025-11-17 12:00:00 UTC.
template <class T> void put(uintptr_t base, size_t off, T v) {
  std::memcpy(reinterpret_cast<void *>(base + off), &v, sizeof v);
}
template <class T> T get(uintptr_t base, size_t off) {
  T v;
  std::memcpy(&v, reinterpret_cast<const void *>(base + off), sizeof v);
  return v;
}
} // namespace

int main() {
  // 1. The clock: midnight at :02, sunrise at :12, noon at :32, sunset at :52, under 24 just before the wrap.
  assert(near(hour_at(kBase + 120000), 0) && near(hour_at(kBase + 720000), 4) && near(hour_at(kBase + 1920000), 12));
  assert(near(hour_at(kBase + 3120000), 20) && near(hour_at(kBase + 3600000 + 120000), 0));
  assert(hour_at(kBase + 119999) < 24 && near(hour_at(kBase + 119999), 23.9999933, 1e-6));
  assert(hour_at(0) >= 0 && hour_at(0) < 24 && near(hour_at(0), 23.2)); // Before :02 of the epoch's first hour.
  // 2. The ramps.
  assert(near(ramp(13, 8, 18), 0.5) && ramp(7, 8, 18) == 0 && ramp(19, 8, 18) == 1 && near(ramp(-8, -4, -12), 0.5));
  // 3. Noon on a map whose noon heading is 0: full sun along heading 0, every factor 1.
  Light a = light_at(12, 8, 0);
  assert(near(a.el, 65) && near(a.le, 65) && near(a.ly, 0) && a.k == 1 && !a.moon && a.amb == 1 && a.eve == 1);
  assert(a.ev == 0 && a.tint[0] == 1 && a.tint[1] == 1 && a.tint[2] == 1 && a.glow == 1);
  assert(near(a.dir[0], 0.42262) && near(a.dir[1], 0) && near(a.dir[2], -0.90631));
  // 4. Sunrise and sunset: on the horizon, light off (under hz 8), headings 270 and 90.
  Light r = light_at(4, 8, 0), s = light_at(20, 8, 0);
  assert(near(r.el, 0) && r.k == 0 && near(r.ly, 270) && near(s.el, 0) && s.k == 0 && near(s.ly, 90));
  // 5. Midnight: the moon 30 degrees up opposite the sun, darker night factors, cold colour.
  Light m = light_at(0, 8, 0);
  assert(m.moon && near(m.el, -30) && near(m.le, 30) && near(m.ly, 0) && near(m.k, 0.15) && near(m.amb, 0.2));
  assert(near(m.eve, 0.5) && near(m.fog, 0.15) && m.glow == 0 && near(m.ev, -1.0));
  assert(near(m.tint[0], 0.70) && near(m.tint[1], 0.80) && near(m.tint[2], 1.00));
  assert(near(m.dir[0], 0.86603) && near(m.dir[1], 0) && near(m.dir[2], -0.5));
  // 6. Mid-morning on a map whose noon heading is 100: el 65 sin(pi/4), heading 100 - 45.
  Light b = light_at(8, 8, 100);
  assert(near(b.el, 45.9619) && near(b.ly, 55));
  // 7. Dusk colour: warm at hz, half-way at hz + 7.5, white from hz + 15.
  float t[3];
  sun_tint(8, 8, t);
  assert(near(t[0], 1) && near(t[1], 0.55) && near(t[2], 0.30));
  sun_tint(15.5, 8, t);
  assert(near(t[1], 0.775) && near(t[2], 0.65));
  sun_tint(23, 8, t);
  assert(t[0] == 1 && t[1] == 1 && t[2] == 1);

  // A fake WorldSettings whose env array holds three elements: 0 sunlit with its own exposure bias, 1 covered (a cave),
  // 2 sunlit without the bias override bit.
  std::vector<uint8_t> settings_mem(0x2100), array_mem(3 * kStride);
  const uintptr_t ws = reinterpret_cast<uintptr_t>(settings_mem.data());
  const uintptr_t e0 = reinterpret_cast<uintptr_t>(array_mem.data()), e1 = e0 + kStride, e2 = e1 + kStride;
  put<uint64_t>(ws, kArray, e0);
  put<int32_t>(ws, kNum, 3);
  put<uint64_t>(e0, kVolume, 0x1000), put<uint64_t>(e0, kData, 0x2000), put<float>(e0, kSun, 18);
  for (int i = 0; i < 3; ++i)
    put<float>(e0, kColor + 4 * i, 1);
  put<float>(e0, kSky, 4), put<float>(e0, kEve, 2), put<float>(e0, kEveSub, 1);
  put<float>(e0, kFog, 0.5f), put<float>(e0, kFog + 4, 0.4f), put<float>(e0, kFog + 8, 0.3f);
  put<float>(e0, kGlow, 1), put<float>(e0, kGlow + 4, 0.8f), put<float>(e0, kGlow + 8, 0.6f);
  put<float>(e0, kBias, -1), put<uint8_t>(e0, kBiasBits, kBiasBit), put<float>(e0, kDir + 8, -1);
  put<uint64_t>(e1, kVolume, 0x1001), put<uint64_t>(e1, kData, 0x2001), put<float>(e1, kSun, 0);
  put<float>(e1, kSky, 0.5f), put<float>(e1, kEve, 1), put<float>(e1, kEveSub, 1), put<float>(e1, kDir + 8, -1);
  put<uint64_t>(e2, kVolume, 0x1002), put<uint64_t>(e2, kData, 0x2002), put<float>(e2, kSun, 10);
  put<float>(e2, kSky, 1), put<float>(e2, kBias, 0.7f);
  const Want cyc{Mode::cycle, 0, 8, 0};
  const uint64_t noon = kBase + 1920000, midnight = kBase + 120000;
  const uintptr_t world = 0xAAAA;
  static Sky sky; // Its cache is 256 entries: kept off the stack as the DLL keeps it in a global.

  // 8. Noon: the direction in every element, the sun's values in the sunlit ones, the covered one left alone.
  assert(sky.pass(world, ws, cyc, noon) == State::cycle && sky.elements() == 3 && sky.sunlit() == 2 && sky.holding());
  assert(near(get<float>(e0, kDir), 0.42262) && near(get<float>(e1, kDir + 8), -0.90631) && get<float>(e0, kSun) == 18);
  assert(get<float>(e1, kSun) == 0 && get<float>(e1, kSky) == 0.5f && near(get<float>(e2, kBias), 0.7));
  // 9. Midnight: moon light, darker sky and EVE, dim fog, no glow, one EV down where the preset sets its bias.
  sky.pass(world, ws, cyc, midnight);
  assert(near(get<float>(e0, kSun), 2.7) && near(get<float>(e0, kColor), 0.70) && near(get<float>(e0, kSky), 0.8));
  assert(near(get<float>(e0, kEve), 1.0) && near(get<float>(e0, kEveSub), 0.5) && near(get<float>(e0, kFog), 0.075));
  assert(get<float>(e0, kGlow) == 0 && near(get<float>(e0, kBias), -2) && near(get<float>(e2, kSun), 1.5));
  assert(near(get<float>(e2, kBias), 0.7) && !(get<uint8_t>(e2, kBiasBits) & kBiasBit) && get<float>(e1, kSky) == 0.5f);
  // 10. Restore: every original back, the direction of the covered element too; off then writes nothing.
  sky.restore();
  assert(get<float>(e0, kSun) == 18 && get<float>(e0, kSky) == 4 && near(get<float>(e0, kBias), -1));
  assert(get<float>(e1, kDir + 8) == -1 && !sky.holding());
  put<float>(e0, kSun, 3);
  assert(sky.pass(world, ws, Want{}, midnight) == State::off && get<float>(e0, kSun) == 3);
  put<float>(e0, kSun, 18);
  // 11. A re-copy by SB (the original back) is written again; a value matching neither is read again as new.
  sky.pass(world, ws, cyc, midnight);
  put<float>(e0, kSun, 18);
  sky.pass(world, ws, cyc, midnight);
  assert(near(get<float>(e0, kSun), 2.7));
  put<float>(e0, kSun, 5);
  sky.pass(world, ws, cyc, midnight);
  assert(near(get<float>(e0, kSun), 0.75));
  // 12. Review Focus 4: another world at the same addresses. Its element holds 0.75, the value the old cache last
  //     wrote: the cache is gone, so 0.75 is read as this element's original (a kept cache would have written 5 at
  //     noon).
  put<float>(e0, kSun, 0.75f);
  sky.pass(0xBBBB, ws, cyc, noon);
  assert(near(get<float>(e0, kSun), 0.75));
  // 13. Review Focus 5: SB's forced settings: nothing written while they hold; a restore then still puts the array
  //     back.
  sky.pass(0xBBBB, ws, cyc, midnight);
  assert(near(get<float>(e0, kSun), 0.1125));
  put<uint8_t>(ws, kForcedFlag, 1), put<uint64_t>(ws, kForced, 0x5000), put<float>(e0, kSun, 9);
  assert(sky.pass(0xBBBB, ws, cyc, noon) == State::forced && get<float>(e0, kSun) == 9);
  put<float>(e0, kSun, 0.1125f);
  sky.restore();
  assert(near(get<float>(e0, kSun), 0.75));
  put<uint8_t>(ws, kForcedFlag, 0); // An off asked while SB's forced settings hold puts the array back too.
  assert(sky.pass(0xBBBB, ws, cyc, midnight) == State::cycle && near(get<float>(e0, kSun), 0.1125));
  put<uint8_t>(ws, kForcedFlag, 1);
  assert(sky.pass(0xBBBB, ws, Want{}, noon) == State::off && near(get<float>(e0, kSun), 0.75) && !sky.holding());
  put<uint8_t>(ws, kForcedFlag, 0);
  // 14. Gated blend, too many elements, no world, an empty array.
  put<uint8_t>(ws, kGated, 1);
  assert(sky.pass(0xBBBB, ws, cyc, noon) == State::gated);
  put<uint8_t>(ws, kGated, 0);
  put<int32_t>(ws, kNum, 257);
  assert(sky.pass(0xBBBB, ws, cyc, noon) == State::full);
  put<int32_t>(ws, kNum, 3);
  assert(sky.pass(0, 0, cyc, noon) == State::waiting && !sky.holding());
  put<int32_t>(ws, kNum, 0);
  assert(sky.pass(0xCCCC, ws, cyc, noon) == State::cycle && sky.elements() == 0);
  put<int32_t>(ws, kNum, 3);
  // 15. Pinned and held: minute 0 at noon gives midnight. A hold keeps the hour the pass before it drew: a pinned
  //     midnight stays midnight at the clock's noon (Night Operation's photo mode); after the clock, the clock's hour.
  assert(sky.pass(0xCCCC, ws, Want{Mode::pinned, 0, 8, 0}, noon) == State::pinned && near(sky.light().el, -30));
  assert(sky.pass(0xCCCC, ws, Want{Mode::held, 0, 8, 0}, noon) == State::held && near(sky.light().el, -30));
  assert(sky.pass(0xCCCC, ws, Want{Mode::held, 0, 8, 0}, midnight) == State::held && near(sky.light().el, -30));
  assert(sky.pass(0xCCCC, ws, cyc, noon) == State::cycle && near(sky.light().el, 65));
  assert(sky.pass(0xCCCC, ws, Want{Mode::held, 0, 8, 0}, noon) == State::held && near(sky.light().el, 65));
  assert(sky.pass(0xCCCC, ws, Want{Mode::held, 0, 8, 0}, midnight) == State::held && near(sky.light().el, 65));
  sky.pass(0, 0, Want{}, 0); // An off between them (the DLL's off pass): the hold that follows starts at the clock.
  assert(sky.pass(0xCCCC, ws, Want{Mode::pinned, 0, 8, 0}, noon) == State::pinned);
  sky.pass(0, 0, Want{}, 0);
  assert(sky.pass(0xCCCC, ws, Want{Mode::held, 0, 8, 0}, noon) == State::held && near(sky.light().el, 65));
  // 16. The status line; the main view's read-back says whether EVE stands in env sunlight. The hour and the light's
  //     angles keep a 250 ms pass's step (about 0.02 degree): 3 real seconds after 13:00, h 13.02 and ly 11.475.
  assert(line(State::cycle, light_at(12, 8, 0), 114, 20, true) ==
         "sky=cycle h=12.0000 el=65.0 le=65.000 ly=0.000 k=1.000 moon=0 amb=1.000 eve=1.000 ev=0.00 "
         "tint=1.00,1.00,1.00 n=114 lit=20 seen=1");
  const std::string later = line(State::cycle, light_at(13 + 3.0 / 150, 8, 0), 0, 0, false);
  assert(later.find(" h=13.0200 el=63.7 le=63.701 ly=11.475 ") != std::string::npos);
  assert(!sky.seen());
  put<uint8_t>(ws, kViewFlag, 1), put<float>(ws, kViewSun, 3);
  sky.pass(0xCCCC, ws, cyc, noon);
  assert(sky.seen());
  // 17. An element SB moved in its array keeps its originals (no compounding); one that left is forgotten.
  put<float>(e2, kSun, 10); // Neither its cached original nor what was written: read again as new.
  sky.pass(0xCCCC, ws, cyc, midnight);
  assert(near(get<float>(e2, kSun), 1.5));
  std::vector<uint8_t> moved(2 * kStride);
  std::memcpy(moved.data(), array_mem.data() + kStride, 2 * kStride); // Element 0 removed: 1 and 2 shift down.
  put<uint64_t>(ws, kArray, reinterpret_cast<uintptr_t>(moved.data()));
  put<int32_t>(ws, kNum, 2);
  assert(sky.pass(0xCCCC, ws, cyc, midnight) == State::cycle && sky.elements() == 2 && sky.sunlit() == 1);
  assert(near(get<float>(reinterpret_cast<uintptr_t>(moved.data()) + kStride, kSun), 1.5));
  sky.restore();
  assert(get<float>(reinterpret_cast<uintptr_t>(moved.data()) + kStride, kSun) == 10);
  // 18. The array watch: moved() is false right after a pass and true once the array's data pointer or count differs
  //     from what that pass read (SB registered or dropped a volume between two passes); the next pass clears it, a
  //     forced pass too. The overlay's count reaches overlay() and is never written.
  put<uint64_t>(ws, kArray, e0);
  put<int32_t>(ws, kNum, 3);
  put<float>(e0, kSun, 18), put<float>(e0, kSky, 4);
  assert(sky.pass(0xDDDD, ws, cyc, midnight) == State::cycle && near(get<float>(e0, kSun), 2.7));
  assert(sky.settings() == ws && sky.world() == 0xDDDD && !sky.moved(e0, 3) && sky.moved(e0, 2) && sky.moved(e1, 3));
  put<int32_t>(ws, kNum, 2);
  assert(sky.pass(0xDDDD, ws, cyc, midnight) == State::cycle && sky.elements() == 2 && !sky.moved(e0, 2));
  put<int32_t>(ws, kNum, 3), put<uint8_t>(ws, kForcedFlag, 1), put<uint64_t>(ws, kForced, 0x5000);
  assert(sky.pass(0xDDDD, ws, cyc, midnight) == State::forced && !sky.moved(e0, 3));
  put<uint8_t>(ws, kForcedFlag, 0), put<uint64_t>(ws, kForced, 0);
  assert(sky.overlay() == 0);
  put<int32_t>(ws, kOverlayNum, 2);
  sky.pass(0xDDDD, ws, cyc, midnight);
  assert(sky.overlay() == 2 && get<int32_t>(ws, kOverlayNum) == 2);
  put<int32_t>(ws, kOverlayNum, 0);
  assert(sky.pass(0, 0, Want{}, 0) == State::off && sky.settings() == 0 && sky.world() == 0);
  assert(std::string(word(State::gated)) == "gated" && std::string(word(State::refused)) == "refused");
  // 19. A hold released after 300 s glides from the held hour's light (18:00) to the clock's (20:00) over 2000 ms: a
  //     pass each 16 ms frame, no step above one frame's share (1.5 times the mean), the target exact at its end. A
  //     second change at 1000 ms (noon pinned) starts from the mix with no step.
  put<uint64_t>(ws, kArray, e0), put<int32_t>(ws, kNum, 3), put<float>(e0, kSun, 18), put<float>(e2, kSun, 10);
  const uint64_t six = kBase + 2820000, t0 = six + 300000;
  const float share = 1.5f * 18 * 16 / 2000 + 1e-4f;
  assert(sky.pass(0xF000, ws, cyc, six) == State::cycle && get<float>(e0, kSun) == 18 && !sky.gliding());
  sky.pass(0xF000, ws, Want{Mode::held, 0, 8, 0}, six);
  assert(sky.pass(0xF000, ws, Want{Mode::held, 0, 8, 0}, t0) == State::held && get<float>(e0, kSun) == 18);
  sky.pass(0xF000, ws, cyc, t0);
  assert(sky.gliding() && get<float>(e0, kSun) == 18);
  float last = 18;
  for (uint64_t ms = 16; ms < 1000; ms += 16) {
    sky.pass(0xF000, ws, cyc, t0 + ms);
    const float v = get<float>(e0, kSun);
    assert(sky.gliding() && v < last && last - v <= share);
    last = v;
  }
  const Want noon_pin{Mode::pinned, 720, 8, 0};
  sky.pass(0xF000, ws, noon_pin, t0 + 1000);
  assert(sky.gliding() && std::fabs(get<float>(e0, kSun) - last) < 1e-5f);
  for (uint64_t ms = 1016; ms < 3000; ms += 16) {
    sky.pass(0xF000, ws, noon_pin, t0 + ms);
    const float v = get<float>(e0, kSun);
    assert(sky.gliding() && v >= last && v - last <= share);
    last = v;
  }
  sky.pass(0xF000, ws, noon_pin, t0 + 3000);
  assert(!sky.gliding() && get<float>(e0, kSun) == 18);
  // 20. An off 1000 ms into a glide: the originals back in that pass, nothing held; the mix never read as an original.
  sky.pass(0xF000, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 4000);
  sky.pass(0xF000, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 5000);
  assert(sky.gliding() && near(get<float>(e0, kSun), 9));
  assert(sky.pass(0xF000, ws, Want{}, t0 + 5000) == State::off && get<float>(e0, kSun) == 18);
  assert(!sky.holding() && !sky.gliding());
  // 21. The direction stays a unit vector, also from 20:20 (el -3.92, the sun's) to 20:21 (el -4.11, the moon's,
  //     nearly opposite). Exactly opposite directions give the target's at the midpoint.
  sky.pass(0xF000, ws, Want{Mode::pinned, 1220, 8, 0}, t0 + 6000); // After an off: one step.
  assert(!sky.gliding() && !light_at(1220 / 60.0, 8, 0).moon && light_at(1221 / 60.0, 8, 0).moon);
  for (uint64_t ms = 0; ms <= 2000; ms += 16) {
    sky.pass(0xF000, ws, Want{Mode::pinned, 1221, 8, 0}, t0 + 7000 + ms);
    for (const uintptr_t e : {e0, e1}) {
      const double x = get<float>(e, kDir), y = get<float>(e, kDir + 4), z = get<float>(e, kDir + 8);
      assert(std::isfinite(x) && std::isfinite(y) && std::isfinite(z));
      assert(near(std::sqrt(x * x + y * y + z * z), 1, 1e-5));
    }
  }
  const float east[3] = {1, 0, 0}, west[3] = {-1, 0, 0};
  float out[3];
  glide_dir(east, west, 0.5, out);
  assert(out[0] == -1 && out[1] == 0 && out[2] == 0);
  glide_dir(east, west, 0.25, out);
  assert(near(out[0], 1));
  // 22. The light the status line prints during a glide (18:00 to 20:00 pinned): mixed factors and el; le and ly from
  //     the mixed direction; h the old draw's under the midpoint, the new one's from it. light() is the target.
  a = light_at(18, 8, 0), b = light_at(20, 8, 0); // Sections 3 and 6 are done with them.
  sky.pass(0xF000, ws, Want{Mode::pinned, 1080, 8, 0}, t0 + 10000);
  sky.pass(0xF000, ws, Want{Mode::pinned, 1080, 8, 0}, t0 + 13000);
  assert(!sky.gliding() && near(sky.drawn().k, a.k));
  sky.pass(0xF000, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 14000);
  sky.pass(0xF000, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 14999);
  assert(near(sky.drawn().hour, 18) && sky.drawn().el > b.el && sky.drawn().el < a.el && near(sky.light().hour, 20));
  sky.pass(0xF000, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 15000);
  const Light d = sky.drawn();
  assert(near(d.hour, 20) && near(d.el, (a.el + b.el) / 2) && near(d.k, (a.k + b.k) / 2));
  assert(near(d.amb, (a.amb + b.amb) / 2));
  assert(near(d.eve, (a.eve + b.eve) / 2) && near(d.ev, (a.ev + b.ev) / 2));
  assert(near(d.tint[2], (a.tint[2] + b.tint[2]) / 2));
  assert(near(d.le, std::asin(-d.dir[2]) * 180 / kPi));
  assert(near(d.ly, std::fmod(std::atan2(d.dir[1], d.dir[0]) * 180 / kPi + 360, 360)));
  // 23. Review Focus 3 and 4: another world ends a glide (its first pass writes its hour at once); so does a clock
  //     that steps back. An element that comes during a glide gets the new hour at once.
  sky.pass(0xF000, ws, noon_pin, t0 + 20000);
  assert(sky.gliding());
  put<float>(e0, kSun, 18);
  assert(sky.pass(0xF100, ws, noon_pin, t0 + 20500) == State::pinned && !sky.gliding() && get<float>(e0, kSun) == 18);
  sky.pass(0xF100, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 21000);
  assert(sky.gliding());
  sky.pass(0xF100, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 20000); // The PC clock went back 1 s.
  assert(!sky.gliding() && get<float>(e0, kSun) == 0);
  put<int32_t>(ws, kNum, 2);
  sky.pass(0xF100, ws, Want{Mode::pinned, 0, 8, 0}, t0 + 22000);
  put<int32_t>(ws, kNum, 3), put<float>(e2, kSun, 10);
  sky.pass(0xF100, ws, Want{Mode::pinned, 0, 8, 0}, t0 + 23000);
  assert(sky.gliding() && near(get<float>(e0, kSun), 1.35) && near(get<float>(e2, kSun), 1.5));
  // 24. A change of draw with no element (a hall's empty array) glides the light the status line prints. A change seen
  //     under SB's forced settings glides once they end, from what the elements hold. A forced pass ends a running
  //     glide (gliding() false: no pass each frame while forced) and the first pass after it glides again.
  put<int32_t>(ws, kNum, 0);
  sky.pass(0xF200, ws, Want{Mode::pinned, 1080, 8, 0}, t0 + 30000);
  sky.pass(0xF200, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 31000);
  sky.pass(0xF200, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 32000);
  assert(sky.gliding() && sky.elements() == 0 && near(sky.drawn().k, (a.k + b.k) / 2));
  put<int32_t>(ws, kNum, 3), put<float>(e0, kSun, 18);
  sky.pass(0xF200, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 34000); // Read as new: 20:00 at once.
  assert(!sky.gliding() && get<float>(e0, kSun) == 0);
  put<uint8_t>(ws, kForcedFlag, 1), put<uint64_t>(ws, kForced, 0x5000);
  assert(sky.pass(0xF200, ws, noon_pin, t0 + 36000) == State::forced && !sky.gliding() && get<float>(e0, kSun) == 0);
  put<uint8_t>(ws, kForcedFlag, 0), put<uint64_t>(ws, kForced, 0);
  sky.pass(0xF200, ws, noon_pin, t0 + 37000);
  assert(sky.gliding() && get<float>(e0, kSun) == 0);
  sky.pass(0xF200, ws, noon_pin, t0 + 38000);
  assert(near(get<float>(e0, kSun), 9));
  sky.pass(0xF200, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 40000);
  assert(sky.gliding());
  put<uint8_t>(ws, kForcedFlag, 1), put<uint64_t>(ws, kForced, 0x5000);
  assert(sky.pass(0xF200, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 40500) == State::forced && !sky.gliding());
  put<uint8_t>(ws, kForcedFlag, 0), put<uint64_t>(ws, kForced, 0);
  sky.pass(0xF200, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 50000);
  assert(sky.gliding() && near(get<float>(e0, kSun), 9)); // From what the element held when forced came.
  // 25. A world whose passes all stopped before the elements (SB's forced settings on arrival) draws a change at once:
  //     the printed light never glides from the last world's (k 0.5 here). A waiting array stops a running glide like
  //     a forced pass; the first pass after it glides on from what the elements hold.
  put<uint8_t>(ws, kForcedFlag, 1), put<uint64_t>(ws, kForced, 0x5000), put<float>(e0, kSun, 18);
  assert(sky.pass(0xF300, ws, Want{Mode::pinned, 1080, 8, 0}, t0 + 60000) == State::forced);
  sky.pass(0xF300, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 60100);
  put<uint8_t>(ws, kForcedFlag, 0), put<uint64_t>(ws, kForced, 0);
  assert(sky.pass(0xF300, ws, Want{Mode::pinned, 1200, 8, 0}, t0 + 60200) == State::pinned && !sky.gliding());
  assert(near(sky.drawn().k, b.k) && near(sky.drawn().hour, 20) && get<float>(e0, kSun) == 0);
  sky.pass(0xF300, ws, noon_pin, t0 + 61000);
  sky.pass(0xF300, ws, noon_pin, t0 + 62000);
  assert(sky.gliding() && near(get<float>(e0, kSun), 9));
  put<uint64_t>(ws, kArray, 0);
  assert(sky.pass(0xF300, ws, noon_pin, t0 + 62500) == State::waiting && !sky.gliding());
  put<uint64_t>(ws, kArray, e0);
  sky.pass(0xF300, ws, noon_pin, t0 + 70000);
  assert(sky.gliding() && near(get<float>(e0, kSun), 9));
  return 0;
}
