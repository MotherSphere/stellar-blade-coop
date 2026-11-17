// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// game/sky.h on the build machine: the hour from UTC, the sun and moon path and the light factors.
#include "game/sky.h"

#include <cassert>
#include <cmath>

using namespace coop::sky;

namespace {
bool near(double a, double b, double eps = 1e-4) { return std::fabs(a - b) <= eps; }
constexpr uint64_t kBase = 1763380800000ULL; // 2025-11-17 12:00:00 UTC.
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
  return 0;
}
