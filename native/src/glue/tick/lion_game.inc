// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The Lion's rows, the Gardener's and the Tendril's (lion/rows.h's batches), the game thread's calls ----
// SB's functions on the pinned build (the Lion study, plan A): InitializeStruct through the row struct's vtable +0x2a8
// and CopyScriptStruct (0x1429d8830), as AddRow itself calls them; FName's MakeWithNumber with FNAME_Add (the photo
// pause's kMakeName); a table's row by name, through its RowMap (+0x30, GetRowMap's own lea at vtable +0x280) and
// that TMap's find 0x140e8c5f0, and its ID map's row name (FUN_141a2ce50), both read-only; AddRow through the table's
// vtable slot +0x2b0, once lion/rows.h saw it hold 0x14417ba30. Not SB's FindRow (FUN_141aa8760): it is
// FindRow<FSBCharacterTableProperty>, null for a table whose row struct is no child of that struct, as the other 9
// tables' are not (FSBTablePropertyBase's other children); the TMap find is its untyped second half. For the read-back,
// the registry's own lookups by ID: FUN_141a9de20 (CharacterTable), FUN_141a9d900 (SkillTable) and FUN_141a2cef0 (a
// stance's row name, the registry's table 10), on the registry at fight::kTables +0x20, read and never made (its getter
// allocates when null). All of them run in coop_tick only while the gate holds: the build pinned, coop off not on, the
// cached net mode 0 and no logic task in flight (logic +0x5c0 == 0, as stage 3b's force target waits for it), so no
// logic task starts and reads a map AddRow grows before our call returns, and SB's game-thread HUD reads CharacterTable
// on this thread only. A shut gate tries again at the next frame and gives up after lion::kGateTicks frames, with why.
// Each batch has its own ask, answer and Builder (a RowsJob); the gate, the block, the spawn counter and the SEH latch
// are shared: the first fault in SB's table calls ends every batch's calls for the run (whichever batch ran into it)
// and leaves the rest of the mod running.
constexpr uint64_t kCopyStruct = 0x1429d8830, kMapFind = 0x140e8c5f0, kIdName = 0x141a2ce50,
                   kCharacterById = 0x141a9de20, kSkillById = 0x141a9d900, kStanceName = 0x141a2cef0;
constexpr size_t kInitializeSlot = 0x2a8;
// RowMap, a TMap<FName, uint8 *>: its TSet's elements first, 0x18 bytes each ({FName, row, hash next, hash index}).
constexpr size_t kRowMap = 0x30, kRowPair = 0x18, kPairRow = 8;
constexpr int32_t kStanceTable = 10;
constexpr size_t kSpawnCount = 0x198; // The spawn manager's counter (fight::kSpawnManager's +0x198), for the log.
constexpr uint64_t kLionCountMs = 250;
using Initialize = void (*)(void *row_struct, void *row, int32_t count);
using CopyStruct = void (*)(void *row_struct, void *dest, const void *src, int32_t count);
using MapFind = int32_t *(*)(const void *map, int32_t *index, uint64_t name); // The FName by value; *index -1: absent.
using IdName = uint64_t *(*)(void *table, uint64_t *out, int32_t id);         // *out 0 when the ID is free.
using AddRow = void (*)(void *table, uint64_t name, const void *row);
using RowById = void *(*)(void *registry, uint64_t unused, int32_t id);
using StanceName = uint64_t *(*)(void *registry, uint64_t *out, int32_t table, int32_t id);

static_assert(lion::kTableCount == kLionTableCount, "the rows requests name each of lion/rows.h's tables");
// One batch's ask and answer. The worker's side: the ask, its number and the 15 tables, taken by the game thread with
// try_lock only. What the game thread did, for the worker: the answer (lion::pack, with the asks finished), the
// read-back (character, skills and stance counts, a byte each) and the frames the waiting ask waited. The game thread's
// own: the rows added so far, the ask being served and its tables, the asks finished.
struct RowsJob {
  explicit RowsJob(const lion::Batch &b) : batch(b), builder(b) {}
  const lion::Batch &batch;
  std::mutex m;
  uint32_t asked = 0;
  uint64_t ask_tables[lion::kTableCount] = {};
  std::atomic<uint64_t> word{0};
  std::atomic<uint32_t> read{0}, ticks{0};
  lion::Builder builder;
  uint64_t tables[lion::kTableCount] = {};
  uint32_t taken = 0, done = 0, waited = 0;
  bool pending = false;
};
// In link/protocol.h's kRowWords order: Request::batch indexes it.
RowsJob lion_job{lion::kLion}, gardener_job{lion::kGardener}, tendril_job{lion::kTendril};
RowsJob *const kJobs[] = {&lion_job, &gardener_job, &tendril_job};
static_assert(sizeof kJobs / sizeof kJobs[0] == kRowWordCount, "a job for each rows request word");
// Shared: the spawn manager's counter (INT64_MIN until read) and the latch.
std::atomic<int64_t> lion_spawns{INT64_MIN};
std::atomic<bool> lion_faulted{false};
std::atomic<uint64_t> lion_fault_code{0}, lion_fault_rva{0}, lion_fault_address{0};
uint64_t lion_next_count = 0;
alignas(16) uint8_t lion_block[lion::kBlock]; // Where each row is built for AddRow; never destroyed (lion/rows.h).

// lion/rows.h's Game: its reads (only the tables' headers) through safe_read (ReadProcessMemory on the pinned build),
// so an address Lua got wrong is refused, never a fault; plain writes into our block; SB's functions.
struct WinLionGame {
  uintptr_t registry = 0;
  bool read(uint64_t address, void *out, size_t n) { return safe_read(address, out, n); }
  void write(uint64_t address, const void *in, size_t n) { std::memcpy(reinterpret_cast<void *>(address), in, n); }
  uint64_t name(const char *text, size_t len, uint32_t number) {
    wchar_t wide[128];
    len = std::min(len, sizeof wide / sizeof wide[0] - 1);
    for (size_t k = 0; k < len; ++k)
      wide[k] = wchar_t(uint8_t(text[k]));
    wide[len] = 0;
    const NameView view{wide, uint32_t(len), false};
    uint64_t out = 0;
    game_function<MakeName>(kMakeName)(&out, &view, 1, number); // 1: FNAME_Add.
    return out;
  }
  uint64_t find(uint64_t table, uint64_t name) {
    int32_t index = -1;
    game_function<MapFind>(kMapFind)(reinterpret_cast<const void *>(table + kRowMap), &index, name);
    return index < 0 ? 0 : at<uintptr_t>(at<uintptr_t>(table + kRowMap) + uint64_t(index) * kRowPair + kPairRow);
  }
  uint64_t id_name(uint64_t table, uint32_t id) {
    uint64_t out = 0;
    game_function<IdName>(kIdName)(reinterpret_cast<void *>(table), &out, int32_t(id));
    return out;
  }
  void construct(uint64_t row_struct, uint64_t row) {
    const auto init = reinterpret_cast<Initialize>(at<uintptr_t>(at<uintptr_t>(row_struct) + kInitializeSlot));
    init(reinterpret_cast<void *>(row_struct), reinterpret_cast<void *>(row), 1);
  }
  void copy(uint64_t row_struct, uint64_t dest, uint64_t src) {
    game_function<CopyStruct>(kCopyStruct)(reinterpret_cast<void *>(row_struct), reinterpret_cast<void *>(dest),
                                           reinterpret_cast<const void *>(src), 1);
  }
  void add(uint64_t add_row, uint64_t table, uint64_t name, uint64_t row) {
    reinterpret_cast<AddRow>(add_row)(reinterpret_cast<void *>(table), name, reinterpret_cast<const void *>(row));
  }
  uint64_t character(uint32_t id) { return by_id(kCharacterById, id); }
  uint64_t skill(uint32_t id) { return by_id(kSkillById, id); }
  uint64_t stance(uint32_t id) {
    uint64_t out = 0;
    if (registry)
      game_function<StanceName>(kStanceName)(reinterpret_cast<void *>(registry), &out, kStanceTable, int32_t(id));
    return out;
  }
  uint64_t by_id(uint64_t fn, uint32_t id) {
    return registry ? reinterpret_cast<uintptr_t>(
                          game_function<RowById>(fn)(reinterpret_cast<void *>(registry), 0, int32_t(id)))
                    : 0;
  }
};

// The gate's reads: the cached net mode (0 standalone) and the logic task in flight, both through SB's globals block.
lion::Why lion_gate(uint32_t &mode) {
  const uintptr_t net = at<uintptr_t>(base + (game::kGlobals + fight::kNetAt - game::kImageBase));
  const uintptr_t logic = at<uintptr_t>(base + (game::kGlobals + fight::kLogicAt - game::kImageBase));
  if (!game::plausible(net) || !game::plausible(logic))
    return lion::Why::unread;
  mode = at<uint32_t>(net + fight::kNetMode);
  if (mode != 0)
    return lion::Why::net;
  return at<uint64_t>(logic + fight::kTask) ? lion::Why::busy : lion::Why::none;
}
// One try at a job's ask: the gate, then (open) every row of its batch not added yet and SB's lookups of them. Out of
// line, since clang-cl catches a fault only in a function the __try calls. why: the gate's, or none once the rows ran.
__declspec(noinline) lion::Answer lion_body(RowsJob &j, lion::Why &why, uint32_t &mode) {
  why = lion_gate(mode);
  if (why != lion::Why::none)
    return lion::Answer();
  WinLionGame g;
  const lion::Answer a = j.builder.run(g, base, j.tables, reinterpret_cast<uintptr_t>(static_cast<void *>(lion_block)));
  if (a.state == lion::State::rows) {
    const uintptr_t holder = at<uintptr_t>(base + (fight::kTables - game::kImageBase));
    g.registry = game::plausible(holder) ? at<uintptr_t>(holder + fight::kTablesAt) : 0;
    if (!game::plausible(g.registry))
      g.registry = 0;
    const lion::Builder::ReadBack b = j.builder.read_back(g, j.tables);
    j.read = uint32_t(b.character) | uint32_t(b.skills) << 8 | uint32_t(b.stance) << 16;
  }
  return a;
}
// The spawn manager's counter, for the log only: through safe_read, so a bad read leaves the last value and never
// reaches the latch that gates the rows.
void lion_count() {
  uint64_t manager = 0;
  int32_t n = 0;
  if (safe_read(base + (fight::kSpawnManager - game::kImageBase), &manager, 8) && game::plausible(manager) &&
      safe_read(manager + kSpawnCount, &n, 4))
    lion_spawns = n;
}
// ---- The Shock Bolt's lists (lion/shock.h), once the lion rows batch is in ----
// SB's functions for them on the pinned build: the registry's stance row by name (FUN_141a9cd20, read-only, the lookup
// the stance change itself makes), SB's grow of an 8-byte TArray (FUN_140e47f00), the const store's key hash
// (FUN_14117c1f0) and GMalloc (the FMalloc whose pointer is at 0x14706b500: Malloc at vtable +0x10, Realloc at +0x20).
// Run in the same game-thread call as the batch's last AddRow, so inside the gate that call checked, under a latch of
// its own: a fault there leaves every batch's rows as they are and only turns the Shock Bolt off for the run.
constexpr uint64_t kStanceByName = 0x141a9cd20, kGrowNames = 0x140e47f00, kConstHash = 0x14117c1f0,
                   kGMalloc = 0x14706b500;
constexpr size_t kMallocSlot = 0x10, kReallocSlot = 0x20;
using StanceByName = void *(*)(void *registry, uint64_t unused, uint64_t name); // The FName by value.
using GrowNames = void (*)(void *array);
using ConstHash = uint32_t (*)(const wchar_t *text);
using Malloc = void *(*)(void *gmalloc, size_t n, uint32_t alignment); // Alignment 0: the default.
using Realloc = void *(*)(void *gmalloc, void *p, size_t n, uint32_t alignment);
std::atomic<uint64_t> shock_word{0}; // lion/shock.h's pack, 0 until the run.
std::atomic<bool> shock_faulted{false};
std::atomic<uint64_t> shock_fault_code{0}, shock_fault_rva{0}, shock_fault_address{0};
bool shock_ran = false;
// lion/shock.h's Game: lion/rows.h's (reads through safe_read, the registry), its writes now into SB's own arrays.
struct WinShockGame : WinLionGame {
  uint64_t stance_row(uint64_t name) {
    return registry ? reinterpret_cast<uintptr_t>(game_function<StanceByName>(kStanceByName)(
                          reinterpret_cast<void *>(registry), 0, name))
                    : 0;
  }
  void grow(uint64_t array) { game_function<GrowNames>(kGrowNames)(reinterpret_cast<void *>(array)); }
  uint32_t hash(const char *text) {
    wchar_t wide[64];
    size_t k = 0;
    for (; text[k] && k + 1 < sizeof wide / sizeof wide[0]; ++k)
      wide[k] = wchar_t(uint8_t(text[k]));
    wide[k] = 0;
    return game_function<ConstHash>(kConstHash)(wide);
  }
  uintptr_t gmalloc() {
    const uintptr_t m = at<uintptr_t>(base + (kGMalloc - game::kImageBase));
    return game::plausible(m) ? m : 0;
  }
  uint64_t malloc(size_t n) {
    const uintptr_t m = gmalloc();
    return m ? reinterpret_cast<uintptr_t>(reinterpret_cast<Malloc>(at<uintptr_t>(at<uintptr_t>(m) + kMallocSlot))(
                   reinterpret_cast<void *>(m), n, 0))
             : 0;
  }
  uint64_t realloc(uint64_t p, size_t n) {
    const uintptr_t m = gmalloc();
    return m ? reinterpret_cast<uintptr_t>(reinterpret_cast<Realloc>(at<uintptr_t>(at<uintptr_t>(m) + kReallocSlot))(
                   reinterpret_cast<void *>(m), reinterpret_cast<void *>(p), n, 0))
             : 0;
  }
};
// Out of line, as lion_body is, for the __try below.
__declspec(noinline) lion::ShockAnswer shock_body() {
  WinShockGame g;
  const uintptr_t holder = at<uintptr_t>(base + (fight::kTables - game::kImageBase));
  g.registry = game::plausible(holder) ? at<uintptr_t>(holder + fight::kTablesAt) : 0;
  if (!game::plausible(g.registry))
    g.registry = 0;
  return lion::shock(g, base);
}
// The one run, published before the lion line says rows (lion_finish follows it), so whoever reads rows reads this.
void shock_step() {
  shock_ran = true;
  lion::ShockAnswer a;
  __try {
    a = shock_body();
  } __except (fault_filter(GetExceptionInformation(), shock_fault_code, shock_fault_rva, shock_fault_address)) {
    shock_faulted = true;
  }
  if (shock_faulted)
    a = lion::ShockAnswer(), a.state = lion::ShockState::fault;
  shock_word = lion::pack(a);
}
void lion_finish(RowsJob &j, lion::Answer a) {
  j.pending = false;
  a.added = uint8_t(j.builder.count());
  j.word = lion::pack(a, ++j.done);
}
// One job each frame: a new ask taken, a waiting one tried (refused at once after coop off, and after kGateTicks shut
// frames). A fault in the rows' calls closes the latch and answers this ask and every other waiting one with it.
void rows_step(RowsJob &j) {
  bool got = false;
  if (j.m.try_lock()) {
    if ((got = j.asked != j.taken)) {
      j.taken = j.asked;
      std::memcpy(j.tables, j.ask_tables, sizeof j.tables);
    }
    j.m.unlock();
  }
  if (got)
    j.pending = true, j.waited = 0;
  if (!j.pending)
    return;
  lion::Answer a;
  if (blocked) {
    a.state = lion::State::refused, a.why = lion::Why::off, a.row = uint8_t(j.batch.count);
    lion_finish(j, a);
    return;
  }
  lion::Why why = lion::Why::none;
  uint32_t mode = 0;
  __try {
    a = lion_body(j, why, mode);
  } __except (fault_filter(GetExceptionInformation(), lion_fault_code, lion_fault_rva, lion_fault_address)) {
    lion_faulted = true;
  }
  if (lion_faulted) {
    for (RowsJob *k : kJobs)
      if (k->pending) {
        a = lion::Answer(), a.state = lion::State::fault;
        lion_finish(*k, a);
      }
    return;
  }
  if (why == lion::Why::none) {
    if (&j == &lion_job && a.state == lion::State::rows && !shock_ran)
      shock_step();
    lion_finish(j, a);
  } else if (++j.waited >= lion::kGateTicks) {
    a = lion::Answer(), a.state = lion::State::refused, a.why = why, a.row = uint8_t(j.batch.count);
    a.detail = mode & 0xffffff;
    lion_finish(j, a);
  } else {
    a = lion::Answer(), a.state = lion::State::waiting, a.why = why, a.added = uint8_t(j.builder.count());
    j.ticks = j.waited;
    j.word = lion::pack(a, j.done);
  }
}
// Each frame on the pinned build until the latch: each batch's job in turn, and once a first ask came the spawn
// manager's counter every 250 ms.
void lion_tick() {
  for (RowsJob *j : kJobs)
    if (!lion_faulted)
      rows_step(*j);
  bool asked = false;
  for (const RowsJob *j : kJobs)
    asked = asked || j->taken;
  if (const uint64_t now = GetTickCount64(); asked && !blocked && now >= lion_next_count) {
    lion_next_count = now + kLionCountMs;
    lion_count();
  }
}
} // namespace
} // namespace coop::pose
