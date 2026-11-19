// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The day/night cycle (world/daynight/sky.h, world/daynight/daynight.lua's sky request), the game thread's writes
// ---- Every sky::kPassMs: SB's player controller (kController, FUN_142321EE0: GEngine's first local player's, null
// before one exists; it makes nothing), its GetWorld (virtual +0x158), the world's persistent level (+0x30) and the
// level's WorldSettings (+0x268), the reach of freeze_game.inc's FreezeGame::paused, each pointer checked. Then
// sky::Sky writes the hour's light into SB's env array there; SB's own blend does the per-frame work. Between two
// passes, while the array holds our values, each frame the same reach and the array's pointer and count read with plain
// reads.
// The worker's ask, packed: the mode, the pinned minute, the map's horizon and noon heading.
std::atomic<uint64_t> sky_want_word{0};
// What the game thread did, for the worker's line and log: world/daynight/sky.h's State, the worlds seen, the elements
// and the sunlit ones, whether EVE stands in env sunlight and the latch. The light the last pass drew sits under a
// mutex the game thread only try-locks, so the worker never prints a light torn between two passes.
std::atomic<uint8_t> sky_state{uint8_t(sky::State::off)};
std::atomic<uint32_t> sky_worlds{0};
std::atomic<int> sky_elements{0}, sky_sunlit{0}, sky_overlay{0};
std::atomic<bool> sky_seen{false}, sky_faulted{false};
std::mutex sky_drawn_m;
sky::Light sky_drawn_light{}; // Both under sky_drawn_m.
bool sky_drawn_set = false;
std::atomic<uint64_t> sky_fault_code{0}, sky_fault_rva{0}, sky_fault_address{0};
// The game thread's.
sky::Sky sky_writer; // Two caches of 256 elements: a global, never on the stack.
uint64_t sky_next_ms = 0;
uintptr_t sky_last_world = 0;

uint64_t sky_pack(const sky::Want &w) {
  return uint64_t(w.mode) | uint64_t(w.minute) << 8 | uint64_t(w.hz) << 24 | uint64_t(w.heading) << 32;
}
sky::Want sky_unpack(uint64_t v) {
  sky::Want w;
  w.mode = sky::Mode(v & 0xff);
  w.minute = uint16_t(v >> 8);
  w.hz = uint8_t(v >> 24);
  w.heading = uint16_t(v >> 32);
  return w;
}
// The PC's UTC clock in ms since 1970: every SBO player's sky follows it.
uint64_t utc_ms() {
  FILETIME ft;
  GetSystemTimePreciseAsFileTime(&ft);
  const uint64_t t = uint64_t(ft.dwHighDateTime) << 32 | ft.dwLowDateTime; // 100 ns since 1601.
  return (t - 116444736000000000ULL) / 10000;
}

// SB's player controller, its world and that world's WorldSettings, each pointer checked: 0 for a missing link.
void sky_reach(uintptr_t &world, uintptr_t &settings) {
  const uintptr_t pc = game_function<Controller>(kController)();
  world = game::plausible(pc) ? reinterpret_cast<GetWorld>(at<uintptr_t>(at<uintptr_t>(pc) + kGetWorld))(pc) : 0;
  const uintptr_t level = game::plausible(world) ? at<uintptr_t>(world + kLevel) : 0;
  settings = game::plausible(level) ? at<uintptr_t>(level + kWorldSettings) : 0;
  if (!game::plausible(settings))
    settings = 0;
}

__declspec(noinline) void sky_body(const sky::Want &want) {
  uintptr_t world = 0, settings = 0;
  sky_reach(world, settings);
  const sky::State s = sky_writer.pass(world, settings, want, utc_ms());
  sky_elements = sky_writer.elements();
  sky_sunlit = sky_writer.sunlit();
  sky_overlay = sky_writer.overlay();
  sky_seen = sky_writer.seen();
  sky_state = uint8_t(s);
  if (world && world != sky_last_world) { // Last: the worker's line for a new world reads this pass's numbers.
    sky_last_world = world;
    ++sky_worlds;
  }
}
bool sky_holding() { return sky_writer.holding(); }
// Between two passes, while the array holds our values: did SB change it since the last pass (a volume registered,
// DESIGN 5.2)? Only when the frame reaches the last pass's world and WorldSettings, which that world's level holds, so
// plain reads: no safe_read, which is ReadProcessMemory on the pinned build (a wineserver round trip a read). Another
// world waits for the next pass. Out of line: sky_tick's __try catches a fault only in a function it calls.
__declspec(noinline) bool sky_moved() {
  uintptr_t world = 0, settings = 0;
  sky_reach(world, settings);
  return settings && world == sky_writer.world() && settings == sky_writer.settings() &&
         sky_writer.moved(at<uintptr_t>(settings + sky::kArray), at<int32_t>(settings + sky::kNum));
}
// Each frame one clock read; while the array holds our values, the watch too (two SB calls, six reads). A pass each
// kPassMs, in the frame the array changed, or each frame while a glide runs on our array. A map with no element glides
// its printed light at the kPassMs passes. coop off asks for SB's light back: tick.cpp calls this after it only
// while the array still holds our values. The first fault latches the cycle off for the run, after one try to put
// SB's values back.
void sky_tick() {
  const uint64_t now = clock_us() / 1000;
  const bool due = now >= sky_next_ms;
  if (!due && !sky_writer.holding()) // Between passes only our own array is watched.
    return;
  if (due)
    sky_next_ms = sky_next_ms + sky::kPassMs > now ? sky_next_ms + sky::kPassMs : now + sky::kPassMs;
  sky::Want want = sky_unpack(sky_want_word);
  if (blocked)
    want.mode = sky::Mode::off;
  if (want.mode == sky::Mode::off && !sky_writer.holding()) { // Nothing of ours in SB's array: no engine access.
    sky_writer.pass(0, 0, want, 0); // No world: it reads no memory, it only forgets a hold's hour.
    sky_state = uint8_t(sky::State::off);
    return;
  }
  __try {
    if (due || sky_writer.gliding() || sky_moved())
      sky_body(want);
  } __except (fault_filter(GetExceptionInformation(), sky_fault_code, sky_fault_rva, sky_fault_address)) {
    sky_faulted = true;
  }
  if (!sky_faulted) { // Outside the __try: a fault never leaves the mutex held. A busy lock skips one copy.
    if (sky_drawn_m.try_lock()) {
      sky_drawn_light = sky_writer.drawn();
      sky_drawn_set = true;
      sky_drawn_m.unlock();
    }
    return;
  }
  __try {
    sky_writer.restore();
  } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
  }
  sky_state = uint8_t(sky::State::fault);
}
} // namespace
} // namespace coop::pose
