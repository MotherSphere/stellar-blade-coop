// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The bike (game/bike.h): its preload and SB's action gate, the game thread's calls ----
// The preload asks SB's streamable manager for the mesh and the riding clip in one request, as SB asks for EVE's custom
// animations, keeps the handle, reads its loaded flag every bike::kPollMs, then finds each asset in memory (a load that
// failed sets the flag too). It releases the handle when an asset is not in memory once the flag is set, at bike free,
// at a new load with another clip and at coop off.
// The gate turns game/bike.h's actions off on the player controller (fight/pilot.h's is_a: an SBPlayerController) with
// SB's own setter. It puts each kept state back at gate off, at a new Lua load and at coop off, unless the controller
// is gone. Every call runs in coop_tick on the pinned build, under its own SEH latch: the first fault ends the bike for
// the run after one try to put the actions back. The handle is then left as it is (a leaked reference only keeps the
// bike in memory).
struct SoftPath { // FSoftObjectPath: the asset's FName, then its sub-path FString (empty).
  uint64_t name;
  FStringArg sub;
};
static_assert(sizeof(SoftPath) == bike::kSoftPath);
struct PathsArg { // TArray<FSoftObjectPath> as the call takes it by value: data (GMalloc's), ArrayNum, ArrayMax.
  SoftPath *data;
  int32_t num, max;
};
using RequestAsyncLoad = void *(*)(uintptr_t manager, uintptr_t *handle_out, PathsArg *paths, uint64_t *delegate,
                                   int32_t priority, uint8_t manage, uint8_t stalled, FStringArg *debug_name);
using SetAction = void (*)(uintptr_t controller, uint64_t name, uint8_t state);
using FindAction = int32_t *(*)(uintptr_t map, int32_t *index, uint64_t name);
using ControllerCall = void (*)(uintptr_t controller);
using ControllerDelete = void (*)(uintptr_t controller, uint32_t flags);
using ResolveObject = uintptr_t (*)(const SoftPath *path);

// The worker's asks: a preload (a clip path) or a release (no path), numbered, taken by the game thread with try_lock
// only; the gate's wish, (its ask count << 1) | on, the last one only.
std::mutex bike_m;
uint32_t bike_load_asked = 0;
anim::Path bike_load_ask;
std::atomic<uint32_t> bike_gate_want{0};
// What the game thread did, for the worker and the status line (bike::Word packed), the load's time, the gate as last
// changed (handed over under bike_pub_m with try_lock); the latch.
std::atomic<uint32_t> bike_load_word{0}, bike_gate_word{0};
std::atomic<uint64_t> bike_load_ms{0};
std::mutex bike_pub_m;
bike::Gate bike_pub_gate;
std::atomic<bool> bike_faulted{false};
std::atomic<uint64_t> bike_fault_code{0}, bike_fault_rva{0}, bike_fault_address{0};
// The game thread's own: the asks taken (the last preload ask's path), the handle {object, reference controller}, its
// clip and start, the next read, the gate, its controller (with its object item's index and serial), the gated names
// as FNames (made once); a gate and its word not handed over yet.
uint32_t bike_load_taken = 0, bike_gate_taken = 0, bike_gate_next = 0;
anim::Path bike_load_now;
uintptr_t bike_handle[2] = {};
anim::Path bike_clip;
uint64_t bike_since = 0, bike_next = 0;
bike::Gate bike_gate;
uintptr_t bike_pc = 0;
int32_t bike_pc_index = 0, bike_pc_serial = 0;
uint64_t bike_names[bike::kGatedCount] = {};
bool bike_names_made = false, bike_gate_pending = false;
// The ride plays' clip lookups (bike::ride_next), written by anim_play through bike_ride_check, logged by the worker.
std::atomic<uint64_t> bike_ride_word{0};

bool bike_holding() { return bike_handle[1] || bike_gate.is_on(); }
// The worker's: the gate's wish for the game thread, one more ask, on or off.
void bike_want(bool on) {
  const uint32_t was = bike_gate_want;
  bike_gate_want = ((was >> 1) + 1) << 1 | (on ? 1 : 0);
}
void bike_set_load(bike::Load s, bike::Why w) {
  bike_load_word = bike::pack(bike::next(bike_load_word, uint8_t(s), w));
}
void bike_set_gate(bike::Why w) {
  bike_gate_next = bike::pack(bike::next(bike_gate_next, bike_gate.is_on() ? 1 : 0, w));
  bike_gate_pending = true;
}
void bike_publish() {
  if (bike_gate_pending && bike_pub_m.try_lock()) {
    bike_pub_gate = bike_gate;
    bike_gate_word = bike_gate_next; // In the lock: the worker reads the gate that goes with this word.
    bike_gate_pending = false;
    bike_pub_m.unlock();
  }
}

// FName's MakeWithNumber of text: FNAME_Add (1) for a path, FNAME_Find (0) for an action name (none when SB never made
// it); 0 for NAME_None. lion/rows.h's split_number gives SB's own split of a trailing number.
uint64_t bike_name(const char *text, int find_type) {
  wchar_t wide[anim::kMaxPath + 1];
  const size_t len = std::strlen(text);
  if (!len || len > anim::kMaxPath)
    return 0;
  const lion::NameParts p = lion::split_number(text);
  for (size_t k = 0; k < p.len; ++k)
    wide[k] = wchar_t(uint8_t(text[k]));
  wide[p.len] = 0;
  const NameView view{wide, uint32_t(p.len), false};
  uint64_t out = 0;
  game_function<MakeName>(kMakeName)(&out, &view, find_type, p.number);
  return uint32_t(out) && uint32_t(out) != at<uint32_t>(base + (world::kNoneName - game::kImageBase)) ? out : 0;
}
// A path's chars as bike_name takes them: num counts the null, which comes along.
void bike_text(const anim::Path &p, char (&out)[anim::kMaxPath + 1]) {
  out[0] = 0;
  for (int32_t k = 0; k < p.num; ++k)
    out[k] = char(p.chars[k]);
}
// The object at an object path while it is in memory, else 0: SB's FSoftObjectPath::ResolveObject finds and never
// loads (game/bike.h).
uintptr_t bike_find(const char *path) {
  const SoftPath soft{bike_name(path, 1), {}};
  return soft.name ? game_function<ResolveObject>(bike::kResolveObject)(&soft) : 0;
}
// anim_play's, before SB's by-path call for a ride: was the clip in memory, for the worker's line.
void bike_ride_check(const anim::Path &clip) {
  char text[anim::kMaxPath + 1];
  bike_text(clip, text);
  bike_ride_word = bike::ride_next(bike_ride_word, bike_find(text) != 0);
}

// The TSharedPtr's end, as SB's own code drops one: the strong count down, at 0 DestroyObject, then the weak count
// down, at 0 the deleting destructor.
void bike_release() {
  const uintptr_t ctrl = bike_handle[1];
  bike_handle[0] = bike_handle[1] = 0;
  if (!ctrl)
    return;
  const uintptr_t vtable = at<uintptr_t>(ctrl);
  if (_InterlockedDecrement(reinterpret_cast<volatile long *>(ctrl + bike::kStrong)) != 0)
    return;
  reinterpret_cast<ControllerCall>(at<uintptr_t>(vtable))(ctrl);
  if (_InterlockedDecrement(reinterpret_cast<volatile long *>(ctrl + bike::kWeak)) == 0)
    reinterpret_cast<ControllerDelete>(at<uintptr_t>(vtable + 8))(ctrl, 1);
}
// Out of line, since clang-cl catches a fault only in a function the __try calls. A release, or a new request for the
// mesh and clip: the paths' array from GMalloc, handed to SB with the call.
__declspec(noinline) void bike_load(uint64_t now) {
  const bool held = bike_handle[1];
  bike_release();
  bike_clip = bike_load_now;
  if (!bike_clip.num) {
    if (held || bike::Load(bike::unpack(bike_load_word).state) != bike::Load::off)
      bike_set_load(bike::Load::off, bike::Why::none);
    return;
  }
  const uintptr_t engine = at<uintptr_t>(base + (bike::kEngineAt - game::kImageBase));
  const uintptr_t manager = game::plausible(engine) ? at<uintptr_t>(engine + bike::kAssetManager) : 0;
  if (!game::plausible(manager))
    return bike_set_load(bike::Load::failed, bike::Why::manager);
  char clip[anim::kMaxPath + 1];
  bike_text(bike_clip, clip);
  const uint64_t mesh_name = bike_name(bike::kMesh, 1), clip_name = bike_name(clip, 1);
  if (!mesh_name || !clip_name)
    return bike_set_load(bike::Load::failed, bike::Why::name);
  const uintptr_t gmalloc = at<uintptr_t>(base + (kGMalloc - game::kImageBase));
  auto *paths = game::plausible(gmalloc)
                    ? static_cast<SoftPath *>(reinterpret_cast<Malloc>(at<uintptr_t>(at<uintptr_t>(gmalloc) +
                                                                                      kMallocSlot))(
                          reinterpret_cast<void *>(gmalloc), 2 * sizeof(SoftPath), 0))
                    : nullptr;
  if (!paths)
    return bike_set_load(bike::Load::failed, bike::Why::memory);
  paths[0] = SoftPath{mesh_name, {}}, paths[1] = SoftPath{clip_name, {}};
  PathsArg array{paths, 2, 2};
  uint64_t delegate[2] = {};
  FStringArg debug_name{};
  uintptr_t out[2] = {};
  bike_since = now;
  game_function<RequestAsyncLoad>(bike::kRequestAsyncLoad)(manager + bike::kStreamable, out, &array, delegate,
                                                           bike::kPriority, 0, 0, &debug_name);
  bike_handle[0] = out[0], bike_handle[1] = out[1];
  if (!out[0] || !out[1]) {
    bike_release();
    return bike_set_load(bike::Load::failed, bike::Why::game);
  }
  bike_next = now; // Assets already in memory complete inside the call: the first read is now.
  bike_set_load(bike::Load::loading, bike::Why::none);
}
// The loaded flag, while it loads, then each asset in memory: CompleteLoad sets the flag for a path that did not load
// too.
__declspec(noinline) void bike_poll(uint64_t now) {
  bike_next = now + bike::kPollMs;
  if (at<uint8_t>(bike_handle[0] + bike::kCanceled)) {
    bike_release();
    return bike_set_load(bike::Load::failed, bike::Why::canceled);
  }
  if (!at<uint8_t>(bike_handle[0] + bike::kLoaded))
    return;
  bike_load_ms = now - bike_since;
  char clip[anim::kMaxPath + 1];
  bike_text(bike_clip, clip);
  const bike::Why missing = !bike_find(bike::kMesh) ? bike::Why::missing_mesh
                            : !bike_find(clip)       ? bike::Why::missing_clip
                                                     : bike::Why::none;
  if (missing != bike::Why::none)
    bike_release();
  bike_set_load(missing == bike::Why::none ? bike::Load::ready : bike::Load::failed, missing);
}

// game/bike.h's Gate's game: SB's find and setter on the gate's controller.
struct BikeGateGame {
  uintptr_t pc;
  int value(size_t i) {
    if (!bike_names[i])
      return bike::kNoName;
    int32_t index = -1;
    game_function<FindAction>(bike::kFindAction)(pc + bike::kActionMap, &index, bike_names[i]);
    return index < 0 ? bike::kAbsent
                     : at<uint8_t>(at<uintptr_t>(pc + bike::kActionMap) + uint64_t(index) * bike::kActionStride +
                                   bike::kActionValue);
  }
  void set(size_t i, uint8_t state) { game_function<SetAction>(bike::kSetAction)(pc, bike_names[i], state); }
};
__declspec(noinline) void bike_gate_on() {
  const uintptr_t pc = game_function<Controller>(kController)();
  uint64_t cls = 0;
  int32_t index = 0, serial = 0;
  if (!pc || !anim_read(base + (bike::kControllerClassAt - game::kImageBase), &cls, sizeof cls) ||
      !pilot::is_a(anim_read, pc, cls) || !anim_live(pc, &index, &serial))
    return bike_set_gate(bike::Why::controller);
  if (!bike_names_made) {
    for (size_t i = 0; i < bike::kGatedCount; ++i)
      bike_names[i] = bike_name(bike::kGated[i], 0);
    bike_names_made = true;
  }
  BikeGateGame g{pc};
  bike_gate.on(g);
  bike_pc = pc, bike_pc_index = index, bike_pc_serial = serial;
  bike_set_gate(bike::Why::none);
}
__declspec(noinline) void bike_gate_off(bike::Why why) {
  if (!anim::alive(anim_live, bike_pc, bike_pc_index, bike_pc_serial)) {
    bike_gate.gone();
    return bike_set_gate(bike::Why::gone);
  }
  BikeGateGame g{bike_pc};
  bike_gate.off(g);
  bike_set_gate(why);
}

// Each frame on the pinned build until the latch, while coop off has not come or something is still held: the gate's
// last wish (off after coop off), a preload ask taken (a release after coop off), the loaded flag every bike::kPollMs
// while it loads. The first fault closes the latch, after one try to put the actions back when the gate is on:
// bike_gate_off logs it (back, or the controller gone); a fault in it is logged as such.
void bike_tick() {
  const uint64_t now = GetTickCount64();
  const uint32_t want = bike_gate_want;
  const bool gate_asked = want != bike_gate_taken;
  bike_gate_taken = want;
  bool load_asked = false;
  if (bike_m.try_lock()) {
    if ((load_asked = bike_load_asked != bike_load_taken)) {
      bike_load_taken = bike_load_asked;
      bike_load_now = bike_load_ask;
    }
    bike_m.unlock();
  }
  // The same clip asked again while it is held (a new Lua load asks again): nothing to do.
  const bool same = load_asked && bike_load_now.num && bike_handle[1] && bike_load_now.num == bike_clip.num &&
                    std::memcmp(bike_load_now.chars, bike_clip.chars, sizeof(char16_t) * size_t(bike_clip.num)) == 0;
  __try {
    if (blocked && bike_gate.is_on())
      bike_gate_off(bike::Why::off);
    else if (gate_asked && !blocked && bool(want & 1) != bike_gate.is_on())
      want & 1 ? bike_gate_on() : bike_gate_off(bike::Why::none);
    if (blocked && bike_handle[1]) {
      bike_release();
      bike_set_load(bike::Load::off, bike::Why::off);
    } else if (load_asked && !blocked && !same) {
      bike_load(now);
    }
    if (bike::Load(bike::unpack(bike_load_word).state) == bike::Load::loading && bike_handle[1] && now >= bike_next)
      bike_poll(now);
  } __except (fault_filter(GetExceptionInformation(), bike_fault_code, bike_fault_rva, bike_fault_address)) {
    bike_faulted = true;
  }
  if (bike_faulted) {
    bool again = false;
    __try {
      if (bike_gate.is_on())
        bike_gate_off(bike::Why::none);
    } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
      again = true;
    }
    bike_gate.gone();
    if (again)
      bike_set_gate(bike::Why::fault);
    bike_handle[0] = bike_handle[1] = 0;
    bike_set_load(bike::Load::fault, bike::Why::none);
  }
  bike_publish();
}
} // namespace
} // namespace coop::pose
