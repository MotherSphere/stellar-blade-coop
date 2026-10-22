// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The synced photo mode's pause (game/photo_freeze.h) ----
// SB's on the pinned build (FEATURE-PARITY.md 6.2): the pause-tag function photo mode pauses with, the player
// controller getter it pauses through, and FName's MakeWithNumber (FUN_142938380, which SB calls for "PhotoMode"; our
// name has no number suffix, so ParseNumber's 0 goes as it is). The set's singleton is fight/engine.h's kPauseAt.
constexpr uint64_t kPauseTag = 0x1422aafe0, kController = 0x14231c710, kMakeName = 0x142938380;
// FUN_1422ab320's reads, null-checked here: the controller's GetWorld (virtual +0x158), the world's persistent level,
// the level's WorldSettings, and their PauserPlayerState.
constexpr size_t kGetWorld = 0x158, kLevel = 0x30, kWorldSettings = 0x268, kPauser = 0x20b0;
struct NameView { // FUN_142938380's name: its characters, their count, and whether any needs more than 7 bits.
  const wchar_t *text;
  uint32_t len;
  bool wide;
};
static_assert(sizeof(NameView) == 16 && offsetof(NameView, len) == 8 && offsetof(NameView, wide) == 12);
using PauseTag = void (*)(bool add, const uint64_t *name, bool notify);
using Controller = uintptr_t (*)();
using MakeName = uint64_t *(*)(uint64_t *out, const NameView *name, int find_type, uint32_t number);
using GetWorld = uintptr_t (*)(uintptr_t controller);

// The worker's asks, and what the game thread did, for its log.
std::atomic<bool> freeze_sync{false}, freeze_held{false}, freeze_faulted{false};
std::atomic<uint32_t> freeze_test{0};   // The running coop freeze's number, 0 when none.
std::atomic<uint32_t> freeze_unsure{0}; // Bumped at each Lua load.
std::atomic<uint64_t> freeze_reapplied{0}, freeze_dropped{0};
std::atomic<uint64_t> freeze_fault_code{0}, freeze_fault_rva{0}, freeze_fault_address{0};
// The game thread's.
photo::Freeze freeze;
uint64_t freeze_name = 0; // FName "StellarCoopFreeze" (ComparisonIndex, Number), made once.
uint32_t freeze_unsure_seen = 0;

struct FreezeGame {
  uintptr_t controller() { return game_function<Controller>(kController)(); }
  bool ready() {
    return at<uint64_t>(base + (game::kGlobals + fight::kPauseAt - game::kImageBase)) && controller();
  }
  void tag(bool add) { game_function<PauseTag>(kPauseTag)(add, &freeze_name, true); }
  bool paused() {
    const uintptr_t pc = controller();
    const uintptr_t world = pc ? reinterpret_cast<GetWorld>(at<uintptr_t>(at<uintptr_t>(pc) + kGetWorld))(pc) : 0;
    const uintptr_t level = world ? at<uintptr_t>(world + kLevel) : 0;
    const uintptr_t settings = level ? at<uintptr_t>(level + kWorldSettings) : 0;
    return !settings || at<uintptr_t>(settings + kPauser) != 0;
  }
};
// Each tick: nothing while no pause is asked or held. coop off (blocked) asks for none, so a held tag goes.
__declspec(noinline) void freeze_body() {
  if (const uint32_t n = freeze_unsure; n != freeze_unsure_seen) {
    freeze_unsure_seen = n;
    freeze.unsure();
  }
  const bool sync = freeze_sync && !blocked;
  const uint32_t test = blocked ? 0 : freeze_test.load();
  if (!sync && !test && !freeze.held())
    return;
  if (!freeze_name) {
    const NameView name{L"StellarCoopFreeze", 17, false};
    game_function<MakeName>(kMakeName)(&freeze_name, &name, 1, 0); // 1: FNAME_Add.
    if (!freeze_name) {                                             // "None": never a tag of ours.
      freeze_faulted = true;
      return;
    }
  }
  FreezeGame g;
  freeze.step(g, sync, test, clock_us() / 1000);
  freeze_held = freeze.held();
  freeze_reapplied = freeze.reapplied, freeze_dropped = freeze.dropped;
}
__declspec(noinline) void freeze_release() {
  FreezeGame g;
  if (g.ready())
    g.tag(false);
}
// The first fault turns the pause off for the run (the worker logs it and says so on screen), after one try to remove
// our tag, so a pause never outlives the latch while SB still takes the call.
void guarded_freeze() {
  __try {
    freeze_body();
  } __except (fault_filter(GetExceptionInformation(), freeze_fault_code, freeze_fault_rva, freeze_fault_address)) {
    freeze_faulted = true;
  }
  if (!freeze_faulted)
    return;
  if (freeze_name) { // Even unheld: a fault inside an add may come after our tag went into SB's set.
    __try {
      freeze_release();
    } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
    }
  }
  freeze_held = false;
}
} // namespace
} // namespace coop::pose
