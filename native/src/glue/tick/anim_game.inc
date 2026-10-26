// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- coop emote's clips on EVE (game/anim.h), the game thread's calls ----
// SB's by-path custom animation play FUN_1420b31d0, in the shape the MovingTarget animation calls it (0x1420909c3):
// the character, slot 0, the path (a const FString&), the FGuid out, a zero FGuid, the scalars of anim::Play, bytes 15
// to 17 (stop at input, 16, hold at the end) 0, five empty FStrings with 0 weights between them, 0, 0, 0.0, 0, 0. And
// SB's stop FUN_1420addc0(character, slot, blend out, the clip's FName, force 1). Our EVE is the pawn of the player
// controller SB's getter gives (kController, the photo pause's), checked to be a live ASBCharacter (fight/pilot.h's
// live and is_a); every read goes through safe_read. The watch reads slot 0 every anim::kWatchMs while ours plays,
// after checking she is still the live object played on. All of it runs in coop_tick on the pinned build, under its
// own SEH latch: the first fault ends the native clips for the run (after one try to stop ours) and Lua falls back to
// the montage. A new Lua load and coop off stop ours.
struct FStringArg { // An FString as the call reads it: data, ArrayNum (with the null), ArrayMax.
  const char16_t *data;
  int32_t num, max;
};
using PlayByPath = int32_t (*)(void *character, int32_t slot, const FStringArg *path, int32_t *guid_out,
                               const int32_t *guid, float start, float end, float rate, float blend_in, float blend_out,
                               float input_blend, uint8_t loop, int32_t loops, float priority, uint8_t stop_on_input,
                               uint8_t b16, uint8_t hold, FStringArg *s18, float w19, FStringArg *s20, float w21,
                               FStringArg *s22, float w23, FStringArg *s24, uint64_t p25, FStringArg *s26, uint64_t p27,
                               uint8_t b28, float f29, int32_t i30, uint8_t b31);
using StopAnim = void (*)(void *character, int32_t slot, float blend_out, uint64_t name, uint8_t force);
// The worker's ask (a play or a stop) and its number, taken by the game thread with try_lock only.
struct AnimAsk {
  uint32_t id = 0;
  bool stop = false, loop = false;
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
std::atomic<bool> anim_drop{false}, anim_faulted{false};
std::atomic<uint64_t> anim_fault_code{0}, anim_fault_rva{0}, anim_fault_address{0};
// The game thread's own: the ask taken, the track, the character played on (with its object item's index and serial)
// and the next watch.
uint32_t anim_taken = 0;
AnimAsk anim_now;
anim::Track anim_track;
uint64_t anim_ch = 0, anim_next = 0;
int32_t anim_index = 0, anim_serial = 0;

bool anim_read(uint64_t address, void *out, size_t n) { return safe_read(address, out, n); }
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
// Our EVE: the player controller's pawn, the actor Lua's UEHelpers.GetPlayer gives, when it is a live ASBCharacter;
// else 0. index and serial take her object item's.
constexpr size_t kPawn = 0x2f8; // AController::Pawn, as execK2_GetPawn (0x144723570) reads it.
uint64_t anim_eve(int32_t &index, int32_t &serial) {
  const uint64_t pc = game_function<Controller>(kController)();
  uint64_t ch = 0, cls = 0;
  return game::plausible(pc) && anim_read(pc + kPawn, &ch, sizeof ch) && game::plausible(ch) &&
                 anim_read(base + (pilot::kCharacterClassAt - game::kImageBase), &cls, sizeof cls) &&
                 pilot::live(anim_read, objects, ch, &index, &serial) && pilot::is_a(anim_read, ch, cls)
             ? ch
             : 0;
}
// The character played on, still the same live object.
bool anim_alive() {
  int32_t index = 0, serial = 0;
  return anim_ch && pilot::live(anim_read, objects, anim_ch, &index, &serial) && index == anim_index &&
         serial == anim_serial;
}
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
  FStringArg path{anim_now.path.chars, anim_now.path.num, anim_now.path.num};
  FStringArg empty[5] = {};
  int32_t out[4] = {};
  const int32_t zero[4] = {};
  const anim::Play p = anim::play(anim_now.loop);
  const int32_t ret = game_function<PlayByPath>(anim::kPlayByPath)(
      reinterpret_cast<void *>(ch), 0, &path, out, zero, p.start, p.end, p.rate, p.blend_in, p.blend_out,
      p.input_blend, p.loop, p.loops, p.priority, 0, 0, 0, &empty[0], 0.f, &empty[1], 0.f, &empty[2], 0.f, &empty[3],
      0, &empty[4], 0, 0, 0.f, 0, 0);
  uint64_t name = 0;
  anim_read(slots + anim::kSlotName, &name, sizeof name);
  anim_ch = ch, anim_index = index, anim_serial = serial;
  anim_track.played(anim_now.id, ret, out, name, now);
}
// The watch, then (stop) ours blended out while slot 0 still holds it. A slot that took no weight is freed at once,
// whatever was asked.
__declspec(noinline) void anim_watch(bool stop, anim::Why why, uint64_t now) {
  anim::Slot s;
  const bool alive = anim_alive() && anim_slot(anim_ch, s);
  const bool stale = anim_track.watch(alive, s, now);
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
// and run, ours stopped at a new Lua load and at coop off, the watch every anim::kWatchMs. The first fault closes the
// latch, after one try to stop ours.
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
  if (!got && !anim_track.live())
    return;
  const uint64_t was = anim_track.word();
  __try {
    if (got && !anim_now.stop && blocked)
      anim_track.refused(anim_now.id, anim::Why::off);
    else if (got && !anim_now.stop)
      anim_play(now);
    else if (got || drop || blocked)
      anim_watch(true, blocked ? anim::Why::off : drop ? anim::Why::session : anim::Why::none, now);
    else if (now >= anim_next)
      anim_watch(false, anim::Why::none, now);
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
