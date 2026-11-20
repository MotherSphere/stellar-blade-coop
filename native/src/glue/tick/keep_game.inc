// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The keep (game/keep.h): SB's async loader holds what SBO uses, the game thread's calls ----
// Lua writes every object path a module uses at a talk, an arrival or a screen to coop-keep.txt (core/keep.lua); the
// worker adds the file's lines to the list. Every keep::kPollMs the game thread asks SB's streamable manager for the
// paths added since its last look, in one request at priority 100 as the bike's preload asks (bike_game.inc). It
// keeps the handle. Once a handle's loaded flag is set it finds each of its paths in memory (a find, never a load)
// and settles the batch. The handles are never released: they keep the assets from the garbage collector for the game
// run, so nothing loads them on the game thread later. Every call runs in coop_tick on the pinned build before coop
// off, under its own SEH latch: the first fault ends the keep for the run and leaves the handles as they are (a leaked
// reference only keeps the assets in memory, as the bike's fault path).
std::string fault_where(uint64_t rva); // fight_worker_shared.inc's, after this part.
// The list: the worker adds under keep_m; the game thread takes its batches and settles them with try_lock only.
std::mutex keep_m;
keep::List keep_list;
bool keep_told = false, keep_fault_logged = false; // The worker's.
std::atomic<bool> keep_faulted{false};
std::atomic<uint64_t> keep_fault_code{0}, keep_fault_rva{0}, keep_fault_address{0};
// The game thread's own: a slot a batch (a batch holds one path at least), its handle {object, reference controller},
// its first path and count, whether it settled; each path's chars, copied out of the list under the lock; the counts
// settled but not yet handed to the list (paths, in memory); the next look.
uintptr_t keep_handles[keep::kMaxPaths][2];
int keep_first[keep::kMaxPaths], keep_count[keep::kMaxPaths], keep_batches = 0;
bool keep_done[keep::kMaxPaths];
char keep_text[keep::kMaxPaths][keep::kMaxPath + 1];
int keep_owed[2] = {};
uint64_t keep_next = 0;

// One request for a new batch's paths: the paths' array from GMalloc, handed to SB with the call. SB drops a path whose
// name is none and cancels a list left empty (game/bike.h): no handle, so the batch settles at once with none in, as
// it does with no asset manager or no memory.
void keep_request(int first, int count) {
  const uintptr_t engine = at<uintptr_t>(base + (bike::kEngineAt - game::kImageBase));
  const uintptr_t manager = game::plausible(engine) ? at<uintptr_t>(engine + bike::kAssetManager) : 0;
  const uintptr_t gmalloc = at<uintptr_t>(base + (kGMalloc - game::kImageBase));
  auto *paths = game::plausible(manager) && game::plausible(gmalloc)
                    ? static_cast<SoftPath *>(reinterpret_cast<Malloc>(at<uintptr_t>(at<uintptr_t>(gmalloc) +
                                                                                      kMallocSlot))(
                          reinterpret_cast<void *>(gmalloc), size_t(count) * sizeof(SoftPath), 0))
                    : nullptr;
  uintptr_t out[2] = {};
  if (paths) {
    for (int k = 0; k < count; ++k)
      paths[k] = SoftPath{bike_name(keep_text[first + k], 1), {}};
    PathsArg array{paths, count, count};
    uint64_t delegate[2] = {};
    FStringArg debug_name{};
    game_function<RequestAsyncLoad>(bike::kRequestAsyncLoad)(manager + bike::kStreamable, out, &array, delegate,
                                                             bike::kPriority, 0, 0, &debug_name);
  }
  if (!out[0] || !out[1]) {
    keep_owed[0] += count;
    return;
  }
  const int b = keep_batches++;
  keep_handles[b][0] = out[0], keep_handles[b][1] = out[1];
  keep_first[b] = first, keep_count[b] = count, keep_done[b] = false;
}
// Out of line, since clang-cl catches a fault only in a function the __try calls. A new batch's request, then each
// batch not settled: canceled, none in; loaded (CompleteLoad sets the flag for a path that did not load too), the
// batch's paths found in memory.
__declspec(noinline) void keep_step(int first, int count) {
  if (count)
    keep_request(first, count);
  for (int b = 0; b < keep_batches; ++b) {
    if (keep_done[b])
      continue;
    const bool canceled = at<uint8_t>(keep_handles[b][0] + bike::kCanceled);
    if (!canceled && !at<uint8_t>(keep_handles[b][0] + bike::kLoaded))
      continue;
    int in = 0;
    if (!canceled)
      for (int i = keep_first[b]; i < keep_first[b] + keep_count[b]; ++i)
        in += bike_find(keep_text[i]) != 0;
    keep_done[b] = true;
    keep_owed[0] += keep_count[b], keep_owed[1] += in;
  }
}
// Each frame on the pinned build before coop off until the latch; a look every keep::kPollMs. A busy lock waits a
// look: the new paths stay in the list, the settled counts in keep_owed.
void keep_tick(uint64_t now) {
  if (now < keep_next)
    return;
  keep_next = now + keep::kPollMs;
  int first = 0, count = 0;
  if (keep_m.try_lock()) {
    keep_list.settle(keep_owed[0], keep_owed[1]);
    keep_owed[0] = keep_owed[1] = 0;
    count = keep_list.batch(first);
    for (int i = first; i < first + count; ++i)
      std::memcpy(keep_text[i], keep_list.path(i).c_str(), keep_list.path(i).size() + 1);
    keep_m.unlock();
  }
  __try {
    keep_step(first, count);
  } __except (fault_filter(GetExceptionInformation(), keep_fault_code, keep_fault_rva, keep_fault_address)) {
    keep_faulted = true;
  }
}
} // namespace

// coop-keep.txt's lines into the list (glue/steam.cpp takes the file at each pass). Lua writes the whole list each
// time it grows, so the paths already in are no-ops. A refused line is said once a run.
std::string keep_take(const std::string &text) {
  int refused = 0;
  {
    std::lock_guard<std::mutex> lock(keep_m);
    refused = keep_list.add_lines(text);
  }
  if (!refused || keep_told)
    return "";
  keep_told = true;
  return "keep: " + std::to_string(refused) + " paths refused (not an object path, or 128 kept already); said once";
}
// Every pass: the keep's fault once, else empty.
std::string keep_pass() {
  if (!keep_faulted || keep_fault_logged)
    return "";
  keep_fault_logged = true;
  char text[200];
  std::snprintf(text, sizeof text, "keep fault 0x%08llx in %s reading 0x%llx: the keep off for the run",
                static_cast<unsigned long long>(keep_fault_code.load()), fault_where(keep_fault_rva).c_str(),
                static_cast<unsigned long long>(keep_fault_address.load()));
  return text;
}
} // namespace coop::pose
