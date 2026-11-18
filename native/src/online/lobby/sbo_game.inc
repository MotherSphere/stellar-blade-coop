// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The SBO lobby (game/sbo.h) on the game thread: the hook in the ZoneEvent action's slot +0x88, which counts the
// recruiter's Join, the steps of the entry, the warp and the return, the arrival watch, C2's load edge, and what they
// hand the worker.

namespace coop::pose {
namespace {
// sbo on: the co-op saves' copies (decision 9) run for this game run.
std::atomic<bool> sbo_copies{false};

// ---- The co-op saves' copies before each of SB's saves (game/rotation.h, decision 9), the game thread's half ----
// Each frame while sbo on asked for them: SB's save manager found as its save call finds it (a pass with any pointer
// on the way implausible does nothing), its queue's count watched. Once it falls to 0, SB's last write is complete and
// no other has started, so in that same call: one stat per co-op slot, and for a slot whose .sav changed since the
// look before, SB's Backup\StellarBladeCoop0N_Old.sav read whole (the save as it was before that write) and handed to
// the worker, which writes the copy. Under its own SEH latch: the first fault ends the copies for the run.
std::atomic<bool> sbo_faulted{false};
std::atomic<uint64_t> sbo_fault_code{0}, sbo_fault_rva{0}, sbo_fault_address{0};
// The account's save folder with its backslash, set once by the worker (sbo_files) and never freed.
std::atomic<const std::wstring *> sbo_folder{nullptr};
// R9: the entry's E3 copied this slot's .sav itself, so the next fall makes no copy of it. Read and cleared at each fall.
std::atomic<bool> sbo_skip[twins::kSlots];
// The hand-over, one per slot: the game thread fills sbo_old (empty when the read failed) only while sbo_old_ready is
// false, then sets it; the worker takes the bytes and clears it.
std::string sbo_old[twins::kSlots];
std::atomic<bool> sbo_old_ready[twins::kSlots];
rotation::QueueWatch sbo_queue;
twins::Stat sbo_seen[twins::kSlots]; // Each co-op .sav at the last look.
bool sbo_looked = false;             // The first look, at the copies' first pass, makes no copy.

// The UTC time as WinFs::backup_dir stamps its folders: YYYYMMDDTHHMMSSZ. Both threads'.
std::string sbo_utc() {
  SYSTEMTIME t;
  GetSystemTime(&t);
  char stamp[24];
  std::snprintf(stamp, sizeof stamp, "%04u%02u%02uT%02u%02u%02uZ", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute,
                t.wSecond);
  return stamp;
}

twins::Stat sbo_stat(const std::wstring &path) {
  WIN32_FILE_ATTRIBUTE_DATA a;
  if (!GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &a) || (a.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY))
    return {};
  return {true, (uint64_t(a.nFileSizeHigh) << 32) | a.nFileSizeLow,
          (uint64_t(a.ftLastWriteTime.dwHighDateTime) << 32) | a.ftLastWriteTime.dwLowDateTime};
}
// Out of line: clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) void sbo_copy_body() {
  const std::wstring *folder = sbo_folder;
  const uintptr_t world = at<uintptr_t>(base + (sbo::kWorldContext - game::kImageBase));
  const uintptr_t instance = game::plausible(world) ? at<uintptr_t>(world + sbo::kGameInstance) : 0;
  const uintptr_t manager = game::plausible(instance) ? at<uintptr_t>(instance + sbo::kSaveManager) : 0;
  if (!folder || !game::plausible(manager))
    return;
  const bool fell = sbo_queue.fell(at<uint32_t>(manager + sbo::kQueue));
  if (sbo_looked && !fell)
    return;
  for (int n = 0; n < twins::kSlots; ++n) {
    const std::string twin = twins::twin_name(n); // ASCII: widened as is.
    const twins::Stat now = sbo_stat(*folder + std::wstring(twin.begin(), twin.end()));
    const bool skip = sbo_looked && sbo_skip[n].exchange(false);
    if (sbo_looked && !skip && rotation::rewritten(sbo_seen[n], now)) {
      if (sbo_old_ready[n]) // The worker has not taken the last one yet: this look waits for the next fall.
        continue;
      const std::string old = twin.substr(0, twin.size() - 4) + "_Old.sav";
      bool exists = false;
      sbo_old[n] = read_file(*folder + L"Backup\\" + std::wstring(old.begin(), old.end()), exists, twins::kMaxSave + 1);
      sbo_old_ready[n] = true;
    }
    sbo_seen[n] = now;
  }
  sbo_looked = true;
}
void sbo_copy_tick() {
  __try {
    sbo_copy_body();
  } __except (fault_filter(GetExceptionInformation(), sbo_fault_code, sbo_fault_rva, sbo_fault_address)) {
    sbo_faulted = true;
  }
}

// ---- The entry (design-lobby 3.3 E1 to E7), the warp (E9), the return (3.5, R4 to R9) and coop sbo seq ----
// One job at a time, sbo enter, warp, leave or seq, SB's own reload, C1 or C2, handed between the threads by sbo_step:
// the worker fills sbo_job and sets one of the game thread's steps; the game thread runs it, writes what it found and
// sets one of the worker's steps. Neither touches the job while the other holds it. The game thread's steps run in
// coop_tick under their own SEH latch: the first fault ends these jobs for the run, and the worker ends the job. seq
// has a latch of its own (L15-R2): its fault ends seq only.
enum class SboStep : uint8_t {
  idle,
  e1, e3, e4, e5, e9, r4, r6, r7, seq,                     // The game thread's.
  e2, e3_copy, e6, warped, stopped, reloading, returned    // The worker's.
};
constexpr bool sbo_game_step(SboStep s) { return s >= SboStep::e1 && s <= SboStep::seq; }
struct SboJob {
  // The worker's, at the ask.
  bool coop = false;            // enter, leave: saves=coop (R10).
  uint64_t manager_lua = 0;     // enter: SB's save manager as Lua read it.
  sbo::Record record{};         // warp, C1: the record's state.
  uint64_t zone = 0, point = 0; // warp: the zone's and the start point's FNames, index | number << 32.
  uint64_t sequence = 0;        // seq: the asked alias FName, index | number << 32; compared, never handed to SB.
  const char *word = "";        // R4 to R8: the job's word in the log (leave, sb, title or load).
  SboFs *fs = nullptr;          // R4: the account's files, for the restore's put and read-back.
  bool title = false;           // R4 as C1: the file's NewGameCreateTime decides too (title_action).
  int64_t created = 0;          // C1: the record's NewGameCreateTime.
  // The game thread's answers.
  sbo::Why why = sbo::Why::none; // stopped, warped: why it stopped, none for a warp made.
  int slot = -1, difficulty = 0; // E1: the slot entered (+0x54) and T; R4 to R8: the record's.
  bool skip = false, queued = false; // E3 set slot's skip-once flag; E4's save was queued.
  std::string bytes;             // E3: the .sav before the save (pre); from E5: after it (session); R4: the session
                                 // copy.
  twins::Stat stat;              // E5: the .sav's stat at its read. R4: the record's.
  std::vector<std::string> lines; // For the log, said by the worker at its next step.
  sbo::Title action{};           // R4: what C1 decided (close_stale closes with why stale).
  bool reloaded = false;         // R6's call returned 1: the reload is under way.
  // The game thread's own between E4 and E5, and R4's wait for the queue.
  uint64_t manager = 0, last_save = 0, saved_at = 0;
  sbo::SaveWait wait;
  // R7's: the watch, its start and the four fields as last logged (+0x2f98, +0xa00, +0x875, +0x2f9c).
  sbo::ReloadWatch watch;
  uint64_t reload_at = 0;
  int32_t seen[4] = {-1, -1, -1, -1};
};
std::atomic<SboStep> sbo_step{SboStep::idle};
SboJob sbo_job;
std::atomic<bool> sbo_step_faulted{false};
std::atomic<uint8_t> sbo_fault_step{0}; // The game step that faulted, for the log.
std::atomic<uint64_t> sbo_step_fault_code{0}, sbo_step_fault_rva{0}, sbo_step_fault_address{0};
std::atomic<bool> sbo_seq_faulted{false}; // seq's own latch: leave, SB's reload and C1 keep running after its fault.
std::atomic<uint64_t> sbo_seq_fault_code{0}, sbo_seq_fault_rva{0}, sbo_seq_fault_address{0};
uint64_t sbo_seq_names[4] = {}; // sbo::kSequences' FNames, made once on the game thread.
sbo::Arrival sbo_arrival; // The game thread's: E9 starts its 60 s, the arrival watch below steps it.

using DifficultyOf = uint8_t (*)(uint64_t alias);
using IsType5 = uint8_t (*)(void *client);
using CurrentZoneRow = uint8_t *(*)(const uint64_t *zone);
using SaveCall = void (*)(void *client, uint8_t keep, uint8_t notice, FStringArg *a, FStringArg *b, int32_t zero);
using WorldRow = uint8_t *(*)(void *tables, uint64_t unused, const void *name);
using UrlWarp = uint8_t (*)(void *client, const void *url, uint8_t net, const uint64_t *zone, const uint64_t *point,
                            uint8_t arg6, uint8_t arg7, uint8_t arg8);
using SetDifficulty = void (*)(void *client, uint32_t type, uint8_t reload);
using ReloadSave = uint8_t (*)(void *client, uint64_t, uint64_t, uint8_t difficulty, uint8_t, uint8_t);
using OneArg = void (*)(void *object);
sbo::ArrivalReads sbo_arrival_reads(uintptr_t client, uintptr_t &logic, uintptr_t &fsb); // Below, with the watch.

uintptr_t sbo_global(uint64_t where) { return at<uintptr_t>(base + (where - game::kImageBase)); }
// SB's save manager as 0x141ce8050 reaches it, or 0 when a pointer on the way is implausible.
uintptr_t sbo_manager() {
  const uintptr_t world = sbo_global(sbo::kWorldContext);
  const uintptr_t instance = game::plausible(world) ? at<uintptr_t>(world + sbo::kGameInstance) : 0;
  const uintptr_t manager = game::plausible(instance) ? at<uintptr_t>(instance + sbo::kSaveManager) : 0;
  return game::plausible(manager) ? manager : 0;
}
// The guards' reads, in one frame. SB's functions are called only with the tables set: the type-5 test and the zone
// row reach them through a getter (0x141a98e30) that allocates when they are not, so without them logic reads false
// (SB could not save either).
sbo::Reads sbo_reads(uintptr_t client) {
  sbo::Reads r;
  r.coop = sbo_job.coop;
  r.manager_lua = sbo_job.manager_lua;
  r.manager = sbo_manager();
  if (r.manager)
    r.queue = at<uint32_t>(r.manager + sbo::kQueue);
  if (!game::plausible(client))
    return r;
  r.slot = at<int32_t>(client + slot::kEntered);
  r.flow = at<int32_t>(client + travel::kFlow);
  r.phase = at<int32_t>(client + travel::kPhase);
  r.warp = at<uint8_t>(client + travel::kWarp);
  r.camp = at<uint8_t>(client + travel::kAsked);
  r.reload = at<uint8_t>(client + slot::kReloading);
  r.no_save = at<int32_t>(client + sbo::kNoSave);
  r.bc = at<uint8_t>(client + sbo::kBc);
  r.bc_preset = at<uint8_t>(client + sbo::kBcPreset);
  const uintptr_t world = sbo_global(travel::kWorldAt);
  if (!game::plausible(sbo_global(travel::kTablesAt)) || !game::plausible(world))
    return r;
  r.type5 = game_function<IsType5>(sbo::kIsType5)(reinterpret_cast<void *>(client)) != 0;
  const uint64_t zone = at<uint64_t>(client + sbo::kZone); // A copy, as 0x141ce8050 passes its local.
  if (const uint8_t *row = game_function<CurrentZoneRow>(sbo::kCurrentZoneRow)(&zone))
    r.zone_nosave = row[sbo::kZoneType] == 3 || row[sbo::kZoneType] == 6;
  const uintptr_t actors = at<uintptr_t>(world + travel::kActors);
  r.logic = game::plausible(actors) && game_function<FindFsb>(kFindFsb)(reinterpret_cast<void *>(actors),
                                                                       at<int32_t>(client + slot::kPlayerGuid));
  return r;
}
// game/twins.h's stat and read on the game thread, in the account's folder, for Convert::read_whole.
struct SboGameFs {
  const std::wstring &folder;
  std::wstring path(const std::string &name) const { return folder + std::wstring(name.begin(), name.end()); }
  twins::Stat stat(const std::string &name) { return sbo_stat(path(name)); }
  bool read(const std::string &name, std::string &out, size_t max) {
    bool exists = false;
    out = read_file(path(name), exists, max + 1);
    return exists && out.size() <= max;
  }
};
// Co-op slot n's .sav read whole with the game's check, in this call (the manager's queue read 0 just before it): why
// not, or empty. The line gives the bytes and the ms the open, read and close took.
std::string sbo_read_save(int n, const std::string &step, std::string &bytes, twins::Stat &stat) {
  SboGameFs fs{*sbo_folder.load()};
  const uint64_t start = GetTickCount64();
  const std::string why = twins::Convert::read_whole(fs, twins::twin_name(n), bytes, stat, true);
  char text[200];
  std::snprintf(text, sizeof text, "sbo %s: read %s, %zu bytes in %llu ms%s%s", step.c_str(),
                twins::twin_name(n).c_str(), bytes.size(), static_cast<unsigned long long>(GetTickCount64() - start),
                why.empty() ? "" : ": ", why.c_str());
  sbo_job.lines.push_back(text);
  return why;
}
SboStep sbo_stop(sbo::Why why) {
  sbo_job.why = why;
  return SboStep::stopped;
}

// One game step, out of line for the latch. Returns the next step (the same one while E5 waits).
__declspec(noinline) SboStep sbo_step_body(SboStep step) {
  const uintptr_t client = sbo_global(travel::kClientAt);
  const uint64_t now = GetTickCount64();
  char text[240];
  switch (step) {
  case SboStep::e1: { // The guards in one frame, then T.
    const sbo::Reads r = sbo_reads(client);
    sbo_job.why = sbo::entry_guard(r);
    sbo_job.slot = r.slot;
    if (sbo_job.why == sbo::Why::none)
      sbo_job.difficulty = game_function<DifficultyOf>(sbo::kDifficultyOf)(at<uint64_t>(client + sbo::kDifficultyAlias));
    std::snprintf(text, sizeof text,
                  "sbo enter E1: slot %d, flow %d, phase 0x%x, queue %u, manager 0x%llx (Lua's 0x%llx), difficulty "
                  "%d: %s",
                  r.slot, r.flow, unsigned(r.phase), r.queue, static_cast<unsigned long long>(r.manager),
                  static_cast<unsigned long long>(r.manager_lua), sbo_job.difficulty, sbo::why_name(sbo_job.why));
    sbo_job.lines.push_back(text);
    return SboStep::e2;
  }
  case SboStep::e3: { // The .sav before the save, read in one call while the queue reads 0.
    const uintptr_t manager = sbo_manager();
    if (!manager || manager != sbo_job.manager_lua)
      return sbo_stop(sbo::Why::manager);
    if (at<uint32_t>(manager + sbo::kQueue))
      return sbo_stop(sbo::Why::queue);
    if (!sbo_read_save(sbo_job.slot, "enter E3", sbo_job.bytes, sbo_job.stat).empty())
      return sbo_stop(sbo::Why::saveread);
    sbo_skip[sbo_job.slot] = true; // R9: E3's copy stands for the next fall's of this slot.
    sbo_job.skip = true;
    return SboStep::e3_copy;
  }
  case SboStep::e4: { // SB's full save, asked as the camp asks it, with the queue 0 before and 1 after.
    const uintptr_t manager = sbo_manager();
    if (!manager || manager != sbo_job.manager_lua)
      return sbo_stop(sbo::Why::manager);
    const uint32_t before = at<uint32_t>(manager + sbo::kQueue);
    if (before)
      return sbo_stop(sbo::Why::queue);
    if (!game::plausible(client))
      return sbo_stop(sbo::Why::slot);
    sbo_job.manager = manager;
    sbo_job.last_save = at<uint64_t>(manager + sbo::kLastSave);
    FStringArg empty_a{}, empty_b{};
    game_function<SaveCall>(sbo::kSave)(reinterpret_cast<void *>(client), 0, 0, &empty_a, &empty_b, 0);
    const uint32_t after = at<uint32_t>(manager + sbo::kQueue);
    std::snprintf(text, sizeof text, "sbo enter E4: manager 0x%llx (Lua's 0x%llx), queue %u before the save call, %u "
                                     "after it",
                  static_cast<unsigned long long>(manager), static_cast<unsigned long long>(sbo_job.manager_lua),
                  before, after);
    sbo_job.lines.push_back(text);
    if (const sbo::Why why = sbo::queued(after); why != sbo::Why::none)
      return sbo_stop(why);
    sbo_job.queued = true;
    sbo_job.saved_at = now;
    sbo_job.wait.start(now);
    return SboStep::e5;
  }
  case SboStep::e5: { // Each frame until the queue reads 0 again (30 s at most), then the .sav read in that call.
    const uintptr_t manager = sbo_manager();
    if (manager != sbo_job.manager)
      return sbo_stop(sbo::Why::manager);
    const uint32_t queue = at<uint32_t>(manager + sbo::kQueue);
    const sbo::SaveWait::Step s = sbo_job.wait.step(queue, now);
    if (s == sbo::SaveWait::Step::wait)
      return SboStep::e5;
    const bool moved = at<uint64_t>(manager + sbo::kLastSave) != sbo_job.last_save;
    std::snprintf(text, sizeof text, "sbo enter E5: queue %u, +0x60 %s, %llu ms after the save call", queue,
                  moved ? "moved" : "unchanged", static_cast<unsigned long long>(now - sbo_job.saved_at));
    sbo_job.lines.push_back(text);
    if (s == sbo::SaveWait::Step::timeout)
      return sbo_stop(sbo::Why::timeout);
    std::string session;
    twins::Stat stat;
    const bool check = sbo_read_save(sbo_job.slot, "enter E5", session, stat).empty();
    if (const sbo::Why why = sbo::saved(check, session == sbo_job.bytes, moved); why != sbo::Why::none)
      return sbo_stop(why);
    sbo_job.bytes = std::move(session);
    sbo_job.stat = stat;
    return SboStep::e6;
  }
  case SboStep::e9: { // The URL warp into the type-5 zone, with the guards read in this frame.
    const sbo::Reads r = sbo_reads(client);
    const uintptr_t tables = sbo_global(travel::kTablesAt);
    const uintptr_t zones = game::plausible(tables) ? at<uintptr_t>(tables + travel::kTablesList) : 0;
    uint8_t *zone_row = nullptr;
    if (game::plausible(client) && game::plausible(zones)) {
      zone_row = static_cast<uint8_t *>(
          game_function<ZoneRow>(sbo::kZoneRow)(reinterpret_cast<void *>(zones), 0, sbo_job.zone)); // fight_game's.
      if (zone_row && !zone_row[8]) { // The row's first use, as 0x141ce4230 makes it.
        zone_row[8] = 1;
        const auto init = *reinterpret_cast<void (**)(void *)>(*reinterpret_cast<uintptr_t *>(zone_row) + 0x20);
        init(zone_row);
      }
    }
    sbo_job.why = sbo::warp_guard(r, sbo_job.record, zone_row != nullptr, zone_row ? zone_row[sbo::kZoneType] : 0);
    const uint8_t *world_row =
        sbo_job.why == sbo::Why::none
            ? game_function<WorldRow>(sbo::kWorldRow)(reinterpret_cast<void *>(tables), 0, zone_row + sbo::kZoneWorld)
            : nullptr;
    if (sbo_job.why == sbo::Why::none && !world_row)
      sbo_job.why = sbo::Why::zone;
    uint8_t ret = 0, after = 0;
    if (sbo_job.why == sbo::Why::none) {
      ret = game_function<UrlWarp>(sbo::kUrlWarp)(reinterpret_cast<void *>(client), world_row + sbo::kWorldUrl, 0,
                                                  &sbo_job.zone, &sbo_job.point, 1, 1, 0);
      after = at<uint8_t>(client + slot::kReloading); // 1: the warp itself asked SB's reload.
      if (ret == 1) { // As the type-5 entries do right after their warp: no diary write. No difficulty change in
                      // game: SB turns one outside a type-5 zone into its reload 0x141cf2610 (run 2026-11-12).
        *reinterpret_cast<uint8_t *>(client + sbo::kSkipDiary) = 1;
        sbo_arrival.warped(now);
      } else {
        sbo_job.why = sbo::Why::game;
      }
    }
    std::snprintf(text, sizeof text, "sbo warp: zone %u:%u, start point %u:%u, record %s, zone row %s, type %u, "
                                     "call %s: %s, +0x2f9c %u after it",
                  uint32_t(sbo_job.zone), uint32_t(sbo_job.zone >> 32), uint32_t(sbo_job.point),
                  uint32_t(sbo_job.point >> 32), sbo::record_name(sbo_job.record), zone_row ? "found" : "not found",
                  zone_row ? unsigned(zone_row[sbo::kZoneType]) : 0u, world_row ? (ret ? "1" : "0") : "not made",
                  sbo::why_name(sbo_job.why), unsigned(after));
    sbo_job.lines.push_back(text);
    return SboStep::warped;
  }
  case SboStep::seq: { // coop sbo seq: one of the four rows on our EVE's actor id (client +0x58), by our own FName.
    for (size_t k = 0; k < std::size(sbo_seq_names); ++k)
      if (!sbo_seq_names[k]) { // Made once, as sbo_preset_name is.
        const std::string_view alias = sbo::kSequences[k];
        const std::wstring wide(alias.begin(), alias.end());
        const NameView name{wide.c_str(), uint32_t(wide.size()), false};
        game_function<MakeName>(kMakeName)(&sbo_seq_names[k], &name, 1, 0); // 1: FNAME_Add.
      }
    const int k = sbo::seq_pick(sbo_job.sequence, sbo_seq_names);
    // The call reaches the world's and the tables' getters, which allocate while their global is 0.
    const uintptr_t world = sbo_global(travel::kWorldAt);
    const bool ready =
        game::plausible(client) && game::plausible(world) && game::plausible(sbo_global(travel::kTablesAt));
    const int32_t id = game::plausible(client) ? at<int32_t>(client + slot::kPlayerGuid) : -1;
    sbo_job.why = k < 0 ? sbo::Why::guard : !ready ? sbo::Why::world : sbo::Why::none;
    if (sbo_job.why == sbo::Why::none)
      game_function<RunZoneEvent>(sbo::kRunZoneEvent)(reinterpret_cast<void *>(world), id, &sbo_seq_names[k], 0);
    std::snprintf(text, sizeof text, "sbo seq: sequence %u:%u (%s) on actor id %d: %s", uint32_t(sbo_job.sequence),
                  uint32_t(sbo_job.sequence >> 32), k < 0 ? "not one of the four" : sbo::kSequences[k], id,
                  k < 0    ? "not called"
                  : !ready ? "not called, the world, its tables or the client are not made yet"
                           : "called");
    sbo_job.lines.push_back(text);
    return SboStep::stopped;
  }
  case SboStep::r4: { // R4 (and C1's): with the queue at 0, the .sav against the record's stat and the session copy.
    const uintptr_t manager = sbo_manager();
    const uint32_t queue = manager ? at<uint32_t>(manager + sbo::kQueue) : 1; // Not reached: not idle.
    const sbo::SaveWait::Step s = sbo_job.wait.step(queue, now);
    const std::string step_name = sbo_job.word + std::string(sbo_job.title ? " C1" : " R4");
    if (s == sbo::SaveWait::Step::wait)
      return SboStep::r4;
    if (s == sbo::SaveWait::Step::timeout) { // L5-R3: "manager 0" is SB's save manager not reached at all.
      std::snprintf(text, sizeof text, "sbo %s: the save queue did not read 0 within 30 s (manager 0x%llx, queue %s)",
                    step_name.c_str(), static_cast<unsigned long long>(manager),
                    manager ? std::to_string(queue).c_str() : "not read");
      sbo_job.lines.push_back(text);
      return sbo_stop(sbo::Why::timeout);
    }
    const int n = sbo_job.slot;
    const std::string name = twins::twin_name(n);
    const bool same = twins::same(sbo_job.stat, SboGameFs{*sbo_folder.load()}.stat(name));
    sbo::Title action = same ? sbo::Title::close_same : sbo::Title::restore;
    std::string file;
    if (sbo_job.title || !same) { // C1 reads the file's NewGameCreateTime even when the stat is the record's.
      twins::Stat stat;
      if (!sbo_read_save(n, step_name, file, stat).empty())
        return sbo_stop(sbo::Why::restore);
      if (sbo_job.title)
        action = sbo::title_action(sbo_job.record, sbo::same_new_game(file, sbo_job.created), same);
    }
    const bool put =
        action == sbo::Title::restore && sbo::restore_action(same, file != sbo_job.bytes) == sbo::Restore::put;
    // The file the put replaces (read above whenever put holds), kept first in the slot's rotation folder as
    // <UTC>-replaced.sav: no copy, no put, so a wrong restore can be undone by hand.
    std::string kept;
    const bool restored = put && sbo::restore_session(*sbo_job.fs, n, sbo_utc(), file, sbo_job.bytes, kept);
    const std::string result =
        restored ? "it was copied into the rotation folder as " + kept +
                       ", then the session copy was put back and reads back the same"
        : put && sbo_job.bytes.empty() ? "the session copy could not be read, so nothing was written"
        : put && kept.empty() ? "it could not be copied into the rotation folder first, so nothing was written"
        : put ? "it was copied into the rotation folder as " + kept +
                    ", then the session copy could not be put back or reads back different"
        : action == sbo::Title::close_stale ? "another save is in the slot, so nothing was written"
                                            : "it holds the session save, so nothing was written";
    std::snprintf(text, sizeof text, "sbo %s: %s %s the record's stat; %s", step_name.c_str(), name.c_str(),
                  same ? "has" : "moved from", result.c_str());
    sbo_job.lines.push_back(text);
    if (put && !restored)
      return sbo_stop(sbo::Why::restore);
    sbo_job.action = action;
    return sbo_job.title ? SboStep::returned : SboStep::r6;
  }
  case SboStep::r6: { // R6's guard, then SB's reload in the same frame.
    const sbo::Reads e = sbo_reads(client);
    sbo::ReturnReads r;
    r.coop = e.coop, r.logic = e.logic, r.flow = e.flow, r.slot = e.slot, r.record_slot = sbo_job.slot;
    r.phase = e.phase, r.reload = e.reload, r.bc = e.bc, r.warp = e.warp, r.camp = e.camp;
    if (game::plausible(client)) {
      r.a3fc8 = at<uint8_t>(client + sbo::kNoReturnA);
      r.a2f9f = at<uint8_t>(client + sbo::kNoReturnB);
    }
    sbo_job.why = sbo::return_guard(r);
    const auto t = uint8_t(sbo_job.difficulty);
    uint8_t al = 0;
    if (sbo_job.why == sbo::Why::none) {
      void *const c = reinterpret_cast<void *>(client);
      al = game_function<ReloadSave>(sbo::kReloadSave)(c, 0, 0, t, 0, 0); // T rides +0x2fe8 (0x141cd9d7b).
      if (!al) // Nothing started: the player stays, on T.
        sbo_job.why = sbo::Why::guard;
    }
    std::snprintf(text, sizeof text,
                  "sbo %s R6: flow %d, phase 0x%x, slot %d (the record's %d), coop %d, logic %d, +0x2f9c %u, +0x3fc8 "
                  "%u, +0x2f9f %u, +0x3688 %u, +0xa20 %u, +0xb60 %u; difficulty %u, reload call %s: %s",
                  sbo_job.word, r.flow, unsigned(r.phase), r.slot, r.record_slot, r.coop, r.logic, r.reload, r.a3fc8,
                  r.a2f9f, r.bc, r.warp, r.camp, t,
                  sbo::return_guard(r) == sbo::Why::none ? (al ? "1" : "0") : "not made", sbo::why_name(sbo_job.why));
    sbo_job.lines.push_back(text);
    if (sbo_job.why != sbo::Why::none)
      return SboStep::stopped;
    sbo_job.reloaded = true;
    sbo_job.watch.start(now);
    sbo_job.reload_at = now;
    return SboStep::reloading;
  }
  case SboStep::r7: { // R7 each frame, each change of the reload's fields logged; R8 once it is done.
    uintptr_t logic = 0, fsb = 0;
    const sbo::ArrivalReads a = sbo_arrival_reads(client, logic, fsb);
    int32_t seen[4] = {-1, -1, -1, -1}; // -1: the client is not readable.
    if (game::plausible(client)) {
      seen[0] = at<int32_t>(client + sbo::kReloadStep);
      seen[1] = at<int32_t>(client + travel::kFlow);
      seen[2] = at<uint8_t>(client + sbo::kSaveApplied);
      seen[3] = at<uint8_t>(client + slot::kReloading);
    }
    static const char *const kFields[] = {"+0x2f98", "+0xa00", "+0x875", "+0x2f9c"};
    for (int k = 0; k < 4; ++k)
      if (seen[k] != sbo_job.seen[k]) {
        std::snprintf(text, sizeof text, "sbo %s R7: %s reads %d, %llu ms into the watch", sbo_job.word,
                      kFields[k], seen[k], static_cast<unsigned long long>(now - sbo_job.reload_at));
        sbo_job.lines.push_back(text);
        sbo_job.seen[k] = seen[k];
      }
    const sbo::ReloadWatch::Step s = sbo_job.watch.step(seen[3] ? 1 : 0, a.flow, a.phase, a.logic, now);
    if (s == sbo::ReloadWatch::Step::wait)
      return SboStep::r7;
    if (s == sbo::ReloadWatch::Step::timeout)
      return sbo_stop(sbo::Why::timeout);
    // R8: SB's difficulty back to T when the load left another, with E10a's effect reset on our EVE.
    const uint8_t was = game_function<DifficultyOf>(sbo::kDifficultyOf)(at<uint64_t>(client + sbo::kDifficultyAlias));
    if (was != sbo_job.difficulty) {
      game_function<SetDifficulty>(sbo::kSetDifficulty)(reinterpret_cast<void *>(client), uint32_t(sbo_job.difficulty),
                                                        0);
      game_function<OneArg>(sbo::kEffectsReset)(reinterpret_cast<void *>(logic));
    }
    std::snprintf(text, sizeof text, "sbo %s R8: difficulty %u%s%d", sbo_job.word, unsigned(was),
                  was != sbo_job.difficulty ? ", set to the record's " : " is the record's ", sbo_job.difficulty);
    sbo_job.lines.push_back(text);
    return SboStep::returned;
  }
  default:
    return step;
  }
}
// Each frame while a game step waits, on the pinned build. After coop off only C1 runs (L5-R1): any other job is
// handed back stopped, why off, with nothing read or called.
void sbo_step_tick() {
  const SboStep step = sbo_step;
  if (!sbo_game_step(step))
    return;
  if (blocked && !sbo_job.title) {
    sbo_job.why = sbo::Why::off;
    sbo_step = SboStep::stopped;
    return;
  }
  if (step == SboStep::seq) { // L15-R2: its own latch; the worker logs the fault and refuses later seq asks.
    __try {
      sbo_step = sbo_step_body(step);
    } __except (fault_filter(GetExceptionInformation(), sbo_seq_fault_code, sbo_seq_fault_rva, sbo_seq_fault_address)) {
      sbo_seq_faulted = true;
      sbo_job.why = sbo::Why::game;
      sbo_step = SboStep::stopped;
    }
    return;
  }
  __try {
    sbo_step = sbo_step_body(step);
  } __except (fault_filter(GetExceptionInformation(), sbo_step_fault_code, sbo_step_fault_rva,
                           sbo_step_fault_address)) {
    sbo_fault_step = uint8_t(step);
    sbo_step_faulted = true;
  }
}

// ---- The arrival (design-lobby 2.2, E10) and the match loadout (online/lobby/preset.h) ----
// Each frame while the worker's record reads warping or arrived: the loader state and the rest of sbo::ArrivalReads,
// read in one frame; at an arrival, E10a and the preset pass, then the pass again on the next frames while a slot reads
// back different (kTries in all); 60 s after E9's warp with no arrival, a flag for the worker's late. Under its own SEH
// latch: the first fault ends the watch for the run. The lines go to the worker under sbo_said_m, which the game thread
// takes with try_lock only.
std::atomic<bool> sbo_watch{false};  // The worker's: the record reads warping or arrived.
std::atomic<bool> sbo_late{false};   // The game thread's, taken by the worker.
std::atomic<bool> sbo_type5{false};  // The last watched pass's 0x141cf7630, for the worker (R12).
std::atomic<uint32_t> sbo_arrivals{0}; // sbo_arrival.count(), set after each arrival's E10a and first pass.
std::atomic<uint64_t> sbo_zone_now{0}; // The last watched pass's client +0x68, index | number << 32.
std::atomic<int32_t> sbo_loader_now{0}; // The last watched pass's loader state.
std::atomic<bool> sbo_arrival_faulted{false};
std::atomic<uint64_t> sbo_arrival_fault_code{0}, sbo_arrival_fault_rva{0}, sbo_arrival_fault_address{0};
std::mutex sbo_said_m;
std::vector<std::string> sbo_said;   // Under sbo_said_m, for the worker's log.
std::vector<std::string> sbo_saying; // The game thread's, until a free lock moves them into sbo_said.
int sbo_try = 0;                     // The loadout's next try for the last arrival, 0 when none is due.
uint64_t sbo_preset_name = 0;        // FName "Preset_Eve_Max", made once.

using FsbState = int32_t (*)(void *fsb, int32_t state);
using PresetRow = const uint8_t *(*)(void *tables, uint64_t unused, const uint64_t *name);
using FindBucket = void *(*)(void *singleton, int32_t type, int32_t guid);
using TableRow = uint8_t *(*)(void *rows, uint8_t none, uint64_t alias);
using ChangeLevel = void (*)(void *logic, uint32_t type, int32_t level, uint8_t, uint8_t);
using RemoveSkill = void (*)(void *logic, int32_t id);
using AcquireSkill = void (*)(void *logic, int32_t id, uint8_t free, uint8_t);
using Complete = void (*)(void *achievements, uint32_t id, uint32_t value, uint32_t, uint8_t, uint8_t, uint8_t, uint8_t);
using AddItem = void (*)(void *bucket, uint64_t alias, int32_t amount, int32_t level, uint8_t, uint8_t, void *, uint8_t,
                         uint8_t, uint8_t, void *, uint8_t, int32_t, uint64_t, uint8_t, uint8_t);
using Unequip = void (*)(void *logic, int32_t slot);
using SlotFind = int32_t *(*)(void *map, int32_t *index, int32_t slot);
using FromBucket = uint8_t (*)(void *bucket, const uint64_t *alias, void *item);
using ItemCopy = void *(*)(void *out, const void *item);
using EquipItem = void (*)(void *logic, uint32_t slot, void *item, uint8_t);

void sbo_tell(const char *line) { sbo_saying.emplace_back(line); }
void sbo_said_flush() {
  if (sbo_saying.empty())
    return;
  std::unique_lock<std::mutex> lock(sbo_said_m, std::try_to_lock);
  if (!lock)
    return;
  for (std::string &line : sbo_saying)
    sbo_said.push_back(std::move(line));
  sbo_saying.clear();
}

// E10's reads in one frame, with our logic actor (0x141ad7cf0 on the logic singleton, by client +0x58) and its FSB.
// SB's functions are called only with the tables, the world and the logic singleton set.
sbo::ArrivalReads sbo_arrival_reads(uintptr_t client, uintptr_t &logic, uintptr_t &fsb) {
  sbo::ArrivalReads r;
  logic = fsb = 0;
  const uintptr_t loader = sbo_global(sbo::kLoader);
  if (game::plausible(loader))
    r.loader = at<int32_t>(loader + sbo::kLoaderState);
  if (!game::plausible(client))
    return r;
  r.flow = at<int32_t>(client + travel::kFlow);
  r.phase = at<int32_t>(client + travel::kPhase);
  const uintptr_t singleton = sbo_global(pilot::kLogicSingletonAt);
  if (!game::plausible(sbo_global(travel::kTablesAt)) || !game::plausible(sbo_global(travel::kWorldAt)) ||
      !game::plausible(singleton))
    return r;
  r.type5 = game_function<IsType5>(sbo::kIsType5)(reinterpret_cast<void *>(client)) != 0;
  logic = reinterpret_cast<uintptr_t>(game_function<FindActor>(kFindActor)(reinterpret_cast<void *>(singleton),
                                                                           at<int32_t>(client + slot::kPlayerGuid)));
  fsb = game::plausible(logic) ? at<uintptr_t>(logic + sbo::kLogicFsb) : 0;
  r.logic = game::plausible(fsb);
  r.state2f = r.logic && game_function<FsbState>(sbo::kFsbState)(reinterpret_cast<void *>(fsb), sbo::kState2f) != 0;
  return r;
}

// online/lobby/preset.h's G on our EVE: SB's functions with the applier's argument lists. Each pass is made fresh with
// the frame's reads.
struct SboPresetGame {
  uintptr_t tables, singleton, logic, fsb;
  int32_t guid;
  uintptr_t rows = 0, row_at = 0, bucket = 0;
  uint32_t none = 0;
  std::vector<std::pair<int, uint64_t>> refused; // Each Equip refusal: its slot and the row's alias, for the log.

  bool is_none(uint64_t name) const { return uint32_t(name) == none && !(name >> 32); }
  // A table row by alias, given its first use as SB's callers do (byte +8, then vfunc +0x20), or null.
  uintptr_t table_row(uint64_t function, uint64_t alias) const {
    uint8_t *row = game_function<TableRow>(function)(reinterpret_cast<void *>(rows), 0, alias);
    if (row && !row[8]) {
      row[8] = 1;
      (*reinterpret_cast<void (**)(void *)>(*reinterpret_cast<uintptr_t *>(row) + 0x20))(row);
    }
    return reinterpret_cast<uintptr_t>(row);
  }
  // Each alias of one of the row's lists that is not None, with its index.
  template <class F> void each(uint32_t list, F f) const {
    const uintptr_t data = at<uintptr_t>(row_at + list);
    const int32_t count = at<int32_t>(row_at + list + 8);
    for (int32_t k = 0; k < count; ++k)
      if (const uint64_t alias = at<uint64_t>(data + 8 * uint64_t(k)); !is_none(alias))
        f(k, alias);
  }
  bool slot_alias(int slot, uint64_t &alias) const {
    int32_t index = -1;
    game_function<SlotFind>(preset::kSlotFind)(reinterpret_cast<void *>(fsb + preset::kEquipped), &index, slot);
    if (index < 0)
      return false;
    alias = at<uint64_t>(at<uintptr_t>(fsb + preset::kEquipped) + uint64_t(index) * preset::kSlotElement +
                         preset::kSlotAlias);
    return true;
  }
  void *ptr(uintptr_t p) const { return reinterpret_cast<void *>(p); }

  bool row() {
    rows = at<uintptr_t>(tables + travel::kTablesList);
    none = at<uint32_t>(base + (preset::kNoneIndex - game::kImageBase));
    if (!game::plausible(rows) || !sbo_preset_name)
      return false;
    row_at = reinterpret_cast<uintptr_t>(game_function<PresetRow>(preset::kRow)(ptr(tables), 0, &sbo_preset_name));
    if (!row_at)
      return false;
    bucket = reinterpret_cast<uintptr_t>(game_function<FindBucket>(preset::kBucket)(ptr(singleton), 1, guid));
    return true;
  }
  void skills_out() {
    const uintptr_t component = at<uintptr_t>(fsb + preset::kSkills);
    if (!game::plausible(component))
      return;
    const uintptr_t set = component + preset::kSkillSet, data = at<uintptr_t>(set);
    const uintptr_t bits = at<uintptr_t>(set + 0x20) ? at<uintptr_t>(set + 0x20) : set + 0x10;
    std::vector<uint64_t> aliases; // Copied first: RemoveSkill takes each one out of this set.
    for (int32_t i = 0, n = std::min(at<int32_t>(set + 0x28), 4096); i < n; ++i)
      if (at<uint32_t>(bits + 4 * uint64_t(i >> 5)) >> (i & 31) & 1)
        aliases.push_back(at<uint64_t>(data + 0x10 * uint64_t(i)));
    for (const uint64_t alias : aliases)
      if (const uintptr_t skill = is_none(alias) ? 0 : table_row(preset::kSkillRow, alias);
          skill && at<uint8_t>(skill + preset::kOnCreated) != 1) // The 7 AcquisitionOnCreated skills stay.
        game_function<RemoveSkill>(preset::kRemoveSkill)(ptr(logic), at<int32_t>(skill + preset::kId));
  }
  void level(int type, uint32_t offset) {
    game_function<ChangeLevel>(preset::kChangeLevel)(ptr(logic), uint32_t(type), at<int32_t>(row_at + offset), 0, 1);
  }
  void clear() {
    if (bucket)
      game_function<OneArg>(preset::kClear)(ptr(bucket));
  }
  void recovery() { game_function<OneArg>(preset::kRecovery)(ptr(logic)); }
  void achievements() {
    const uintptr_t list = at<uintptr_t>(fsb + preset::kAchievements);
    each(preset::kAchievementList, [&](int32_t, uint64_t alias) {
      if (const uintptr_t a = table_row(preset::kAchievementRow, alias); a && list)
        game_function<Complete>(preset::kComplete)(ptr(list), at<uint32_t>(a + preset::kId),
                                                   at<uint32_t>(a + preset::kAchievementValue), 0, 1, 0, 0, 0);
    });
  }
  void skills_in() {
    each(preset::kSkillList, [&](int32_t, uint64_t alias) {
      if (const uintptr_t skill = table_row(preset::kSkillRow, alias))
        game_function<AcquireSkill>(preset::kAcquireSkill)(ptr(logic), at<int32_t>(skill + preset::kId), 1, 0);
    });
  }
  void items(bool bullets) {
    if (!bucket)
      return;
    const uintptr_t amounts = at<uintptr_t>(row_at + preset::kAmounts), levels = at<uintptr_t>(row_at + preset::kLevelsList);
    const int32_t amount_count = at<int32_t>(row_at + preset::kAmounts + 8);
    const int32_t level_count = at<int32_t>(row_at + preset::kLevelsList + 8);
    each(preset::kItemList, [&](int32_t k, uint64_t alias) {
      const uintptr_t item = table_row(preset::kItemRow, alias);
      if (!item || (at<uint8_t>(item + preset::kCategory) == preset::kBullet) != bullets)
        return;
      const int32_t amount = k < amount_count ? at<int32_t>(amounts + 4 * uint64_t(k)) : 0;
      const int32_t level = k < level_count ? at<int32_t>(levels + 4 * uint64_t(k)) : 1;
      game_function<AddItem>(preset::kAddItem)(ptr(bucket), alias, amount, level, 0, 0, nullptr, 1, 0, 0, nullptr, 0,
                                               0, 0, 0, 0);
    });
  }
  void unequip(int slot) { game_function<Unequip>(preset::kUnequip)(ptr(logic), slot); }
  std::string held(int slot) const {
    uint64_t alias = 0;
    return slot_alias(slot, alias) ? camps_name(alias) : std::string();
  }
  // The row's item for the slot from the bucket into a record made and destroyed with SB's own functions, as the
  // applier's later blocks do (0x141c251f7, 0x141c25246); its copy goes to Equip, which destroys it on every path.
  bool equip(int slot, uint32_t offset) {
    const uint64_t alias = at<uint64_t>(row_at + offset);
    bool found = false;
    if (bucket && !is_none(alias)) {
      alignas(16) uint8_t item[preset::kItemSize], copy[preset::kItemSize];
      game_function<OneArg>(preset::kItemMake)(item);
      found = game_function<FromBucket>(preset::kFromBucket)(ptr(bucket), &alias, item) != 0;
      if (found) {
        unequip(slot);
        game_function<EquipItem>(preset::kEquipItem)(ptr(logic), uint32_t(slot),
                                                     game_function<ItemCopy>(preset::kItemCopy)(copy, item), 0);
      }
      game_function<OneArg>(preset::kItemFree)(item);
    }
    if (!found)
      refused.emplace_back(slot, alias);
    return found;
  }
  void charge() { game_function<OneArg>(preset::kCharge)(ptr(logic)); }
  bool matches(int slot, uint32_t offset) const {
    uint64_t alias = 0;
    return slot_alias(slot, alias) && alias == at<uint64_t>(row_at + offset);
  }
};

// One watched frame, out of line for the latch.
__declspec(noinline) void sbo_arrival_body() {
  const uint64_t now = GetTickCount64();
  const uintptr_t client = sbo_global(travel::kClientAt);
  uintptr_t logic = 0, fsb = 0;
  const sbo::ArrivalReads r = sbo_arrival_reads(client, logic, fsb);
  const uint64_t zone = game::plausible(client) ? at<uint64_t>(client + sbo::kZone) : 0;
  sbo_type5 = r.type5;
  sbo_loader_now = r.loader;
  sbo_zone_now = zone;
  char text[200];
  const bool arrived = sbo_arrival.step(r, now);
  if (arrived) { // E10a, as FSBPostLoadGame runs it.
    game_function<OneArg>(sbo::kEffectsReset)(reinterpret_cast<void *>(logic));
    std::snprintf(text, sizeof text, "sbo: arrived (zone %u:%u, loader %d)", uint32_t(zone), uint32_t(zone >> 32),
                  r.loader);
    sbo_tell(text);
    sbo_try = 1;
  }
  if (sbo_try && sbo::arrival_ready(r)) { // E10b.
    if (!sbo_preset_name) {
      wchar_t wide[sizeof preset::kPreset];
      for (size_t k = 0; k < sizeof wide / sizeof wide[0]; ++k)
        wide[k] = wchar_t(preset::kPreset[k]);
      const NameView name{wide, uint32_t(sizeof preset::kPreset - 1), false};
      game_function<MakeName>(kMakeName)(&sbo_preset_name, &name, 1, 0); // 1: FNAME_Add.
    }
    SboPresetGame g{sbo_global(travel::kTablesAt), sbo_global(pilot::kLogicSingletonAt), logic, fsb,
                    at<int32_t>(client + slot::kPlayerGuid)};
    const preset::Pass p = preset::apply(g);
    if (!p.row) {
      sbo_tell("sbo: loadout: no Preset_Eve_Max row in SB's tables, so EVE keeps her own build");
      sbo_try = 0;
    } else {
      std::snprintf(text, sizeof text, "sbo: loadout: %d refused, %d not as the preset, try %d of %d", p.refused,
                    p.mismatched, sbo_try, preset::kTries);
      sbo_tell(text);
      for (const auto &[slot, alias] : g.refused) {
        const std::string name = !g.bucket ? "no inventory found" : g.is_none(alias) ? "the preset names None" :
                                 camps_name(alias) + " is not in the inventory";
        std::snprintf(text, sizeof text, "sbo: loadout: Equip refused slot %d (%s)", slot, name.c_str());
        sbo_tell(text);
      }
      sbo_try = p.mismatched && sbo_try < preset::kTries ? sbo_try + 1 : 0;
    }
  }
  if (arrived) // For the worker's arrived: after E10a and the first pass.
    sbo_arrivals = sbo_arrival.count();
  if (sbo_arrival.overdue(now))
    sbo_late = true;
}
// C2's load edge (ruling R12): the client in game and playing with our logic actor present, after a frame where that
// did not all hold. Counted for the worker, with that frame's type-5 test written first.
std::atomic<uint32_t> sbo_loads{0};
std::atomic<bool> sbo_load_type5{false};
bool sbo_in_game = false;
__declspec(noinline) void sbo_load_body() {
  const uintptr_t client = sbo_global(travel::kClientAt);
  if (!game::plausible(client) || at<int32_t>(client + travel::kFlow) != travel::kInGame ||
      at<int32_t>(client + travel::kPhase) != travel::kPlaying) {
    sbo_in_game = false;
    return;
  }
  if (sbo_in_game)
    return;
  uintptr_t logic = 0, fsb = 0;
  const sbo::ArrivalReads r = sbo_arrival_reads(client, logic, fsb);
  if (!r.logic)
    return;
  sbo_in_game = true;
  sbo_load_type5 = r.type5;
  ++sbo_loads;
}

// Each frame on the pinned build before coop off: the load edge; the watch only while the record reads warping or
// arrived. The lines go out after the body, a faulted one's included.
void sbo_arrival_tick() {
  __try {
    sbo_load_body();
    if (sbo_watch)
      sbo_arrival_body();
    else
      sbo_try = 0;
  } __except (fault_filter(GetExceptionInformation(), sbo_arrival_fault_code, sbo_arrival_fault_rva,
                           sbo_arrival_fault_address)) {
    sbo_arrival_faulted = true;
  }
  sbo_said_flush();
}
} // namespace
} // namespace coop::pose
