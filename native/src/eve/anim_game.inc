// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
using PlayByPath = int32_t (*)(void *character, int32_t slot, const FStringArg *path, int32_t *guid_out,
                               const int32_t *guid, float start, float end, float rate, float blend_in, float blend_out,
                               float input_blend, uint8_t loop, int32_t loops, float priority, uint8_t stop_on_input,
                               uint8_t b16, uint8_t hold, FStringArg *s18, float w19, FStringArg *s20, float w21,
                               FStringArg *s22, float w23, FStringArg *s24, uint64_t p25, FStringArg *s26, uint64_t p27,
                               uint8_t b28, float f29, int32_t i30, uint8_t b31);
using StopAnim = void (*)(void *character, int32_t slot, float blend_out, uint64_t name, uint8_t force);
// game/anim.h's feet: FUN_142111440(character, 0) and FUN_1421119c0(character, key, on, blend, -1, 0, 0, priority), as
// SB's stop calls them.
using FootIkAllowed = uint8_t (*)(void *character, uint8_t which);
using SetFootIk = void (*)(void *character, const FStringArg *key, uint8_t on, float blend, float blend_off, float f6,
                           uint8_t b7, float priority);
// The worker's ask (a play or a stop) and its number, taken by the game thread with try_lock only.
struct AnimAsk {
  uint32_t id = 0;
  bool stop = false, loop = false, ride = false;
  anim::Path path;
};
std::mutex anim_m;
uint32_t anim_asked = 0;
AnimAsk anim_ask;
// What the game thread did, for the worker and the status line (anim::Track's word, ret, peak in thousandths, held
// ms), the worker's new-Lua-load ask, and the latch.
std::atomic<uint64_t> anim_word{0};
std::atomic<int32_t> anim_ret{0};
std::atomic<uint32_t> anim_peak{0};
std::atomic<uint64_t> anim_held{0};
std::atomic<uint32_t> anim_feet_word{0}; // The last anim::Feet (low byte) and a count of them above it.
std::atomic<bool> anim_drop{false}, anim_faulted{false};
std::atomic<uint64_t> anim_fault_code{0}, anim_fault_rva{0}, anim_fault_address{0};
// The game thread's own: the ask taken, the track, the character played on (with its object item's index and serial)
// and the next watch.
uint32_t anim_taken = 0;
AnimAsk anim_now;
anim::Track anim_track;
uint64_t anim_ch = 0, anim_next = 0;
int32_t anim_index = 0, anim_serial = 0;

void bike_ride_check(const anim::Path &clip); // vehicles/bike/bike_game.inc's: was the ride's clip in memory.
// Slot 0 of ch, through safe_read: false when ch has no slot.
bool anim_slot(uint64_t ch, anim::Slot &s, uint64_t *slots = nullptr) {
  int32_t count = 0;
  uint64_t at = 0;
  uint8_t bytes[anim::kSlotRead];
  if (!anim_read(ch + anim::kSlotCount, &count, sizeof count) || count < 1 ||
      !anim_read(ch + anim::kSlots, &at, sizeof at) || !game::plausible(at) ||
      !anim_read(at + anim::kSlotWeight, bytes, sizeof bytes))
    return false;
  s = anim::slot(bytes);
  if (slots)
    *slots = at;
  return true;
}
bool anim_is_eve(uint64_t object) {
  uint64_t cls = 0;
  return anim_read(base + (pilot::kCharacterClassAt - game::kImageBase), &cls, sizeof cls) &&
         pilot::is_a(anim_read, object, cls);
}
// Our EVE: the player controller's pawn, the actor Lua's UEHelpers.GetPlayer gives, when it is a live ASBCharacter;
// else 0. index and serial take her object item's.
uint64_t anim_eve(int32_t &index, int32_t &serial) {
  return anim::eve(anim_read, anim_live, anim_is_eve, game_function<Controller>(kController)(), index, serial);
}
// The character played on, still the same live object.
bool anim_alive() { return anim::alive(anim_live, anim_ch, anim_index, anim_serial); }
// Out of line, since clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) void anim_play(uint64_t now) {
  int32_t index = 0, serial = 0;
  const uint64_t ch = anim_eve(index, serial);
  anim::Slot before;
  uint64_t slots = 0;
  if (!ch)
    return anim_track.refused(anim_now.id, anim::Why::eve);
  if (!anim_slot(ch, before, &slots))
    return anim_track.refused(anim_now.id, anim::Why::slots);
  if (anim_now.ride)
    bike_ride_check(anim_now.path);
  FStringArg path{anim_now.path.chars, anim_now.path.num, anim_now.path.num};
  FStringArg empty[5] = {};
  int32_t out[4] = {};
  const int32_t zero[4] = {};
  const anim::Play p = anim::play(anim_now.loop, anim_now.ride);
  const int32_t ret = game_function<PlayByPath>(anim::kPlayByPath)(
      reinterpret_cast<void *>(ch), 0, &path, out, zero, p.start, p.end, p.rate, p.blend_in, p.blend_out,
      p.input_blend, p.loop, p.loops, p.priority, 0, 0, p.hold, &empty[0], 0.f, &empty[1], 0.f, &empty[2], 0.f,
      &empty[3], 0, &empty[4], 0, 0, 0.f, p.foot_ik, 0);
  uint64_t name = 0;
  anim_read(slots + anim::kSlotName, &name, sizeof name);
  anim_ch = ch, anim_index = index, anim_serial = serial;
  anim_track.played(anim_now.id, ret, out, name, now, anim_now.ride);
}
// The ride's foot IK, once its play is over (game/anim.h's feet): on the live EVE played on, as SB's stop does.
__declspec(noinline) void anim_feet() {
  if (!anim_track.owes_feet())
    return;
  anim_track.paid_feet();
  anim::Slot s;
  uint64_t slots = 0;
  uint8_t on = 0;
  int32_t type = 0;
  const bool alive = anim_alive() && anim_read(anim_ch + anim::kFootIkOn, &on, sizeof on) &&
                     anim_slot(anim_ch, s, &slots) && anim_read(slots + anim::kSlotFootIk, &type, sizeof type);
  void *const ch = reinterpret_cast<void *>(anim_ch);
  const bool allowed = alive && !on && game_function<FootIkAllowed>(anim::kFootIkAllowed)(ch, 0) == 1;
  const anim::Feet f = anim::feet(alive, on, s.playing, type, allowed);
  if (f == anim::Feet::on) {
    const FStringArg key{anim::kFootIkKey, int32_t(sizeof anim::kFootIkKey / sizeof(char16_t)),
                         int32_t(sizeof anim::kFootIkKey / sizeof(char16_t))};
    game_function<SetFootIk>(anim::kSetFootIk)(ch, &key, 1, anim::play(false).blend_out, -1.f, 0.f, 0, 100.f);
  } else if (f == anim::Feet::later) {
    *reinterpret_cast<volatile uint8_t *>(anim_ch + anim::kFootIkLater) = 1;
  }
  anim_feet_word = ((anim_feet_word >> 8) + 1) << 8 | uint32_t(f);
}
// The watch, then (stop) ours blended out while slot 0 still holds it. A slot that took no weight is freed at once,
// whatever was asked.
__declspec(noinline) void anim_watch(bool stop, anim::Why why, uint64_t now) {
  anim::Slot s;
  const bool alive = anim_alive() && anim_slot(anim_ch, s);
  // The photo pause's read (FUN_1422b0af0's PauserPlayerState), only while the no-weight clock runs: a paused world
  // does not tick her, so her weight cannot move.
  const bool paused = alive && anim_track.live() && anim_track.peak() <= 0 && FreezeGame().paused();
  const bool stale = anim_track.watch(alive, s, now, paused);
  if (!stale && !(stop && anim_track.live()))
    return;
  game_function<StopAnim>(anim::kStop)(reinterpret_cast<void *>(anim_ch), 0, stale ? 0.f : anim::play(false).blend_out,
                                       anim_track.name(), 1);
  anim_track.stopped(now, why);
}
void anim_publish() {
  anim_ret = anim_track.ret();
  anim_peak = uint32_t(anim_track.peak() * 1000);
  anim_held = anim_track.held();
  anim_word = anim_track.word(); // Last: the worker reads the others once the word changed.
}
// Each frame on the pinned build until the latch, while coop off has not come or ours still plays: a new ask taken
// and run (ours stopped first when it still plays), ours stopped at a new Lua load and at coop off, the watch every
// anim::kWatchMs, then the ride's foot IK once its play is over. The first fault closes the latch, after one try to
// stop ours.
void anim_tick() {
  const uint64_t now = GetTickCount64();
  bool got = false;
  if (anim_m.try_lock()) {
    if ((got = anim_asked != anim_taken)) {
      anim_taken = anim_asked;
      anim_now = anim_ask;
    }
    anim_m.unlock();
  }
  const bool drop = anim_drop.exchange(false);
  anim::Why why = anim::Why::none;
  const anim::Act act = anim::act(got, anim_now.stop, blocked, drop, anim_track.live(), now, anim_next, why);
  if (act == anim::Act::none)
    return;
  const uint64_t was = anim_track.word();
  __try {
    if (anim::stop_first(act, anim_track.live()))
      anim_watch(true, why, now);
    if (act == anim::Act::refuse)
      anim_track.refused(anim_now.id, why);
    else if (act == anim::Act::play)
      anim_play(now);
    else
      anim_watch(act == anim::Act::stop, why, now);
    anim_feet();
  } __except (fault_filter(GetExceptionInformation(), anim_fault_code, anim_fault_rva, anim_fault_address)) {
    anim_faulted = true;
  }
  if (anim_track.live() && now >= anim_next)
    anim_next = now + anim::kWatchMs;
  if (anim_faulted) {
    __try {
      if (anim_track.live() && anim_alive()) // Only on the live object played on: never a stale pointer.
        game_function<StopAnim>(anim::kStop)(reinterpret_cast<void *>(anim_ch), 0, 0.f, anim_track.name(), 1);
    } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
    }
    anim_track.faulted();
  }
  if (anim_track.word() != was)
    anim_publish();
}
} // namespace
} // namespace coop::pose
