// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The camps this save has activated, the game thread's read (game/camps.h) ----
// Every 250 ms the guard over the globals the list's own getters reach (read, never called: they allocate when null),
// the client in game and no warp, respawn or logic task in flight; then, when game/camps.h's Schedule says so, SB's
// list for each travel type, the camp EVE respawns at, and the names as SB's name pool spells them. Out of line under
// its own SEH latch: the first fault ends the read for the run, and the status line says activated=none:fault. The
// line goes to the worker under camps_m, which the game thread takes with try_lock only.
using CampList = void (*)(void *zones, const uint64_t *region, uint32_t type, void *out, bool all);
using FreeMemory = void (*)(void *data);
using EnvRow = const uint8_t *(*)(void *registry, uint64_t unused, uint64_t name);
struct NameArray { // A TArray<FName> as SB's list fills it.
  uint64_t *data = nullptr;
  int32_t num = 0, max = 0;
};
std::atomic<bool> camps_faulted{false};
std::atomic<uint64_t> camps_fault_code{0}, camps_fault_rva{0}, camps_fault_address{0};
std::mutex camps_m;
std::string camps_text; // The worker's copy, under camps_m: empty before the first check.
// The game thread's: the line of the last check, and its copy for the worker until a free lock takes it.
camps::Schedule camps_schedule;
uint64_t camps_next = 0;
std::string camps_made, camps_out;
bool camps_pending = false;
void camps_set(std::string w) {
  if (w == camps_made)
    return;
  camps_made = std::move(w);
  camps_out = camps_made; // Copied here, so only a swap happens under the lock.
  camps_pending = true;
}

// One FName as text, read from SB's name pool (fight/pilot.h's fname), or empty.
std::string camps_name(uint64_t name) {
  char text[128];
  size_t n = 0;
  const auto read = [](uint64_t at, void *out, size_t size) {
    std::memcpy(out, reinterpret_cast<const void *>(at), size);
    return true;
  };
  return pilot::fname(read, base + (pilot::kNamePool - game::kImageBase), uint32_t(name), uint32_t(name >> 32), text,
                      sizeof text, n)
             ? std::string(text, n)
             : std::string();
}
__declspec(noinline) void camps_body(uint64_t now) {
  const auto global = [](uint64_t where) { return at<uintptr_t>(base + (where - game::kImageBase)); };
  const auto read = [](uint64_t at, void *out, size_t size) {
    std::memcpy(out, reinterpret_cast<const void *>(at), size);
    return true;
  };
  camps::Reads r;
  r.client = global(travel::kClientAt);
  r.world = global(travel::kWorldAt);
  r.tables = global(travel::kTablesAt);
  r.malloc = global(camps::kMallocAt);
  if (game::plausible(r.world))
    r.zones = at<uintptr_t>(r.world + camps::kZones), r.respawn = at<int32_t>(r.world + travel::kRespawn);
  if (game::plausible(r.tables))
    r.tables_list = at<uintptr_t>(r.tables + travel::kTablesList);
  if (game::plausible(r.client)) {
    r.flow = at<int32_t>(r.client + travel::kFlow);
    r.phase = at<int32_t>(r.client + travel::kPhase);
    r.warp = at<uint8_t>(r.client + travel::kWarp);
    r.asked = at<uint8_t>(r.client + travel::kAsked);
    r.waits = at<uint8_t>(r.client + travel::kWaits);
  }
  r.logic = pilot::logic_busy(read, base);
  const camps::Why why = camps::refuse(r);
  if (why == camps::Why::busy)
    return;
  if (why != camps::Why::none) {
    camps_schedule.drop();
    camps_set(camps::line(why, {}, {}));
    return;
  }
  if (!camps_schedule.due_at(now, r.zones))
    return;
  const uint64_t none = at<uint32_t>(base + (quest::kNoneName - game::kImageBase)); // NAME_None, number 0.
  const auto list = game_function<CampList>(camps::kCampList);
  const auto free_memory = game_function<FreeMemory>(camps::kFree);
  std::vector<std::string> names;
  bool sane = true;
  for (const uint8_t type : camps::kTypes) {
    NameArray a;
    list(reinterpret_cast<void *>(r.zones), &none, type, &a, false);
    sane = sane && a.num >= 0 && a.num <= a.max && a.num <= camps::kMaxCamps;
    for (int32_t i = 0; sane && i < a.num; ++i)
      names.push_back(camps_name(a.data[i]));
    if (a.data)
      free_memory(a.data);
  }
  if (!sane) {
    camps_schedule.drop();
    camps_set(camps::line(camps::Why::unread, {}, {}));
    return;
  }
  std::string rested; // The camp EVE respawns at: her FSBActor's camp row, then its TargetCamp.
  const uintptr_t actors = at<uintptr_t>(r.world + travel::kActors);
  const uint32_t guid = at<uint32_t>(r.client + travel::kGuid);
  if (game::plausible(actors) && guid) {
    const uintptr_t fsb = reinterpret_cast<uintptr_t>(
        game_function<FindFsb>(kFindFsb)(reinterpret_cast<void *>(actors), static_cast<int32_t>(guid)));
    const uint64_t row = game::plausible(fsb) ? at<uint64_t>(fsb + camps::kRestedRow) : none;
    if (row != none) {
      const uint8_t *env = game_function<EnvRow>(camps::kEnvRow)(reinterpret_cast<void *>(r.tables_list), 0, row);
      if (env && game::plausible(reinterpret_cast<uintptr_t>(env)))
        rested = camps_name(at<uint64_t>(reinterpret_cast<uintptr_t>(env) + camps::kTargetCamp));
    }
  }
  camps_schedule.read(now, r.zones);
  camps_set(camps::line(camps::Why::none, names, rested));
}
void camps_tick() {
  const uint64_t now = GetTickCount64();
  if (now >= camps_next) {
    camps_next = now + camps::kCheckMs;
    __try {
      camps_body(now);
    } __except (fault_filter(GetExceptionInformation(), camps_fault_code, camps_fault_rva, camps_fault_address)) {
      camps_faulted = true; // camps_status() then says activated=none:fault.
    }
  }
  if (camps_pending && camps_m.try_lock()) {
    camps_text.swap(camps_out);
    camps_m.unlock();
    camps_pending = false;
  }
}
} // namespace
} // namespace coop::pose
