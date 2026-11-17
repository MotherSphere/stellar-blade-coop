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
#include <cstdint>

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

} // namespace coop::sky
