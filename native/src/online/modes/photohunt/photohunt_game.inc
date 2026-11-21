// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The photo hunt's photo check (online/modes/photohunt/photohunt.h), the game thread's calls ----
// The worker hands over Lua's arm with an ask number; each frame the game thread takes a new one with try_lock only,
// then runs photohunt::tick over the reads and calls below, out of line under its own latch. It hands its answer back
// with try_lock only (a frame that misses the lock hands it at the next). Never called: the getters of the globals it
// reads (FUN_141add5a0 the photo manager, FUN_141a987d0 the client, FUN_141a98e30 the tables, FUN_141a98bc0 the
// registry), which allocate when their global is null; the check runs only with all four set, so its own calls of the
// photo manager's and the registry's getters find them. The first fault ends the photo checks for the run. Nothing
// runs after coop off (glue/tick.cpp's guard).
using PhotoRowOf = void *(*)(void *tables_list, uint64_t unused, uint64_t name);
using PhotoRowInit = void (*)(void *row);
using PhotoCheck = int32_t (*)(void *photo_ui, void *row, uint64_t *screen);
std::atomic<bool> photohunt_faulted{false};
std::atomic<uint64_t> photohunt_fault_code{0}, photohunt_fault_rva{0}, photohunt_fault_address{0};
std::mutex photohunt_m; // The worker's arm and its count, the game thread's answer.
photohunt::Arm photohunt_asked;
uint32_t photohunt_asks = 0;
photohunt::Answer photohunt_out;
// The worker's own: the last arm it handed over (ask 0: none, or photohunt off), for the status line.
photohunt::Arm photohunt_sent;
// The game thread's own.
uint32_t photohunt_taken = 0;
photohunt::Arm photohunt_arm;
photohunt::Watch photohunt_watch;
photohunt::Answer photohunt_answer;
bool photohunt_dirty = false;

// The worker: a new arm for the game thread (an empty one disarms), at the next frame.
void photohunt_hand(const photohunt::Arm &arm) {
  photohunt_sent = arm;
  std::lock_guard<std::mutex> lock(photohunt_m);
  photohunt_asked = arm;
  ++photohunt_asks;
}

// photohunt::tick's game. Every read is a pointer the game made, checked plausible before it is followed.
struct PhotoGame {
  static uintptr_t global(uint64_t address) { return at<uintptr_t>(base + (address - game::kImageBase)); }
  // SB's photo manager (FUN_141add5a0's global 0x147037440, fight::kPhotoMode): IsSelfieMode's test (FUN_14266d5d0),
  // the byte +0x38 set and the int +0x48 at 2.
  bool selfie() const {
    const uintptr_t manager = global(fight::kPhotoMode);
    return game::plausible(manager) && at<uint8_t>(manager + fight::kPhotoActive) &&
           at<int32_t>(manager + fight::kPhotoCamera) == fight::kSelfie;
  }
  // The photo UI's node: SB's finder FUN_141fc93f0 (devinfo::kFindUi) on the client's UI manager (client global
  // 0x1470373f8, its +0x48, devinfo::kManager), with the photo UI's type.
  uintptr_t find() const {
    const uintptr_t client = global(devinfo::kClientAt);
    const uintptr_t manager = game::plausible(client) ? at<uintptr_t>(client + devinfo::kManager) : 0;
    if (!game::plausible(manager))
      return 0;
    return reinterpret_cast<uintptr_t>(
        game_function<FindUi>(devinfo::kFindUi)(reinterpret_cast<void *>(manager), photohunt::kUiType));
  }
  uintptr_t ptr(uintptr_t p) const { return game::plausible(p) ? at<uintptr_t>(p) : 0; }
  uint8_t byte(uintptr_t p) const { return p >= 0x10000 ? at<uint8_t>(p) : 0; }
  uintptr_t image(uint64_t address) const { return base + (address - game::kImageBase); }
  // The row of a name: FUN_141f24370 on *(*(0x1470373b0) + 0x20) (travel::kTablesAt, photohunt::kTablesList); 0 with
  // no tables.
  uintptr_t row(uint64_t name) const {
    const uintptr_t tables = global(travel::kTablesAt);
    const uintptr_t list = game::plausible(tables) ? at<uintptr_t>(tables + photohunt::kTablesList) : 0;
    if (!game::plausible(list))
      return 0;
    const uintptr_t row = reinterpret_cast<uintptr_t>(
        game_function<PhotoRowOf>(photohunt::kRowOf)(reinterpret_cast<void *>(list), 0, name));
    return game::plausible(row) ? row : 0;
  }
  // The row's lazy init, as SB's tick makes it (0x141f0e324 to 0x141f0e32e): its byte +8 set to 1, then its vfunc
  // +0x20. The part's only game write.
  void init(uintptr_t row) const {
    *reinterpret_cast<uint8_t *>(row + photohunt::kRowInit) = 1;
    const uintptr_t vtable = at<uintptr_t>(row);
    reinterpret_cast<PhotoRowInit>(at<uintptr_t>(vtable + photohunt::kRowInitSlot))(reinterpret_cast<void *>(row));
  }
  // SB's check FUN_141f0d7a0; 0 without the registry (global 0x1470373c8, travel::kRegistryAt), which its getter
  // FUN_141a98bc0 would make, or without the photo manager.
  int32_t check(uintptr_t ui, uintptr_t row) const {
    if (!game::plausible(global(travel::kRegistryAt)) || !game::plausible(global(fight::kPhotoMode)))
      return 0;
    uint64_t screen = 0;
    return game_function<PhotoCheck>(photohunt::kCheck)(reinterpret_cast<void *>(ui), reinterpret_cast<void *>(row),
                                                         &screen);
  }
};

// One frame's reads and calls. Out of line, since clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) bool photohunt_step() {
  PhotoGame g;
  return photohunt::tick(g, photohunt_arm, photohunt_watch, photohunt_answer);
}
void photohunt_tick() {
  if (photohunt_m.try_lock()) {
    if (photohunt_asks != photohunt_taken) {
      photohunt_taken = photohunt_asks;
      photohunt_arm = photohunt_asked;
      photohunt_answer = photohunt::start(photohunt_arm, photohunt_watch);
      photohunt_dirty = true;
    }
    if (photohunt_dirty) {
      photohunt_out = photohunt_answer;
      photohunt_dirty = false;
    }
    photohunt_m.unlock();
  }
  if (!photohunt_arm.ask)
    return;
  __try {
    if (photohunt_step())
      photohunt_dirty = true;
  } __except (fault_filter(GetExceptionInformation(), photohunt_fault_code, photohunt_fault_rva,
                           photohunt_fault_address)) {
    photohunt_faulted = true;
  }
}
} // namespace
} // namespace coop::pose
