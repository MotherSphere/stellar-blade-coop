// The native pose path's Windows side. coop_tick runs on the game thread, called once per frame by the Lua loop; the
// worker thread (steam_link.cpp) calls worker_poll. They share only atomics and a mutex the game thread never waits on
// (try_lock: a busy lock skips the hand-over until the next frame). Every engine read runs under SEH; the first fault
// latches the feature off for the run and is logged with its code and RVA.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <atomic>
#include <cstdio>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "pose_engine.h"
#include "pose_tick.h"

namespace coop::pose {
namespace {
uintptr_t base = 0, objects = 0;
std::atomic<bool> engine_on{false}, blocked{false}, probe_asked{false}, faulted{false};
std::string engine_reason = "not checked yet"; // Worker only.
std::atomic<uint64_t> ticks{0}, doubles{0};
std::atomic<uint64_t> fault_code{0}, fault_rva{0}, fault_address{0};
std::atomic<int> probing_part{-1}; // The part being probed, for the fault line.

// Hand-over, guarded by m: the worker's newest table (or a withdrawal) for the game thread, and the game thread's
// result lines for the worker to log.
std::mutex m;
std::unique_ptr<Table> incoming;
bool incoming_set = false;
std::vector<std::string> outbox;

// Game thread only.
std::unique_ptr<Table> table;
std::vector<std::string> pending; // Results not handed over yet (the lock was busy, or the worker had not read them).
LARGE_INTEGER frequency{}, last_call{};
uint64_t last_frame = 0;
// GFrameCounter (PHASE2-RE.md): incremented once per frame by FEngineLoop::Tick, and on some loading paths; compare
// "different from the last call", never "last + 1".
constexpr uint32_t kFrameCounterRva = 0x706b508;

// Cost counters, game thread writes, worker reads and resets every 60 s.
std::atomic<uint64_t> window_ticks{0}, window_us{0}, window_max_us{0}, window_max_gap_us{0}, window_long_gaps{0};

uint64_t micros_between(LARGE_INTEGER a, LARGE_INTEGER b) {
  return frequency.QuadPart ? uint64_t((b.QuadPart - a.QuadPart) * 1000000 / frequency.QuadPart) : 0;
}
void raise_max(std::atomic<uint64_t> &slot, uint64_t value) {
  uint64_t seen = slot.load();
  while (value > seen && !slot.compare_exchange_weak(seen, value))
    ;
}

void probe() {
  if (!table) {
    pending.push_back("probe: no component table (spawn the puppet with coop puppet)");
    return;
  }
  int ok = 0, leaders = 0;
  for (size_t i = 0; i < table->eve.size(); ++i) {
    if (!table->eve[i].leader)
      continue;
    ++leaders;
    probing_part = static_cast<int>(i);
    ProbeResult r = probe_pair(objects, table->eve[i], table->puppet[i]);
    probing_part = -1;
    char line[320];
    std::snprintf(line, sizeof line,
                  "probe part %d (%u bones): %s (eve count %d, puppet count %d, first difference %u; after CopyPose: "
                  "refresh %u, gate pointer %s, gate count %d, anim tasks 0x%llx 0x%llx)",
                  static_cast<int>(i), table->eve[i].bones, describe(r.kind), r.eve_count_seen, r.puppet_count_seen,
                  r.first_difference, r.refresh, r.gate_pointer ? "set" : "null", r.gate_count,
                  static_cast<unsigned long long>(r.task), static_cast<unsigned long long>(r.task2));
    pending.push_back(line);
    ok += r.kind == ProbeResult::ok;
  }
  char line[96];
  wsprintfA(line, "probe: %d of %d leader parts offsets_ok (table %d)", ok, leaders,
            static_cast<int>(table->generation));
  pending.push_back(line);
}

void game_tick() {
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  // A second call in the same engine frame (two Lua loops after a hot reload, say): run once per frame.
  uint64_t frame = at<uint64_t>(base + kFrameCounterRva);
  if (last_call.QuadPart && frame == last_frame) {
    ++doubles;
    return;
  }
  last_frame = frame;
  if (last_call.QuadPart) {
    uint64_t gap = micros_between(last_call, now);
    raise_max(window_max_gap_us, gap);
    if (gap > 100000)
      ++window_long_gaps;
  }
  last_call = now;
  ++ticks;
  if (m.try_lock()) { // Nothing allocates under the lock: swaps only. The worker frees what it gets back.
    if (incoming_set) {
      table.swap(incoming);
      incoming_set = false;
    }
    if (outbox.empty())
      outbox.swap(pending);
    m.unlock();
  }
  if (probe_asked.exchange(false))
    probe();
  LARGE_INTEGER done;
  QueryPerformanceCounter(&done);
  uint64_t us = micros_between(now, done);
  window_ticks++;
  window_us += us;
  raise_max(window_max_us, us);
}

extern "C" IMAGE_DOS_HEADER __ImageBase; // This DLL: every instruction the native tick runs is ours.
int fault_filter(EXCEPTION_POINTERS *info) {
  auto *record = info->ExceptionRecord;
  fault_code = record->ExceptionCode;
  fault_rva = reinterpret_cast<uintptr_t>(record->ExceptionAddress) - reinterpret_cast<uintptr_t>(&__ImageBase);
  if (record->NumberParameters >= 2) // Access violations: the address read or written.
    fault_address = record->ExceptionInformation[1];
  return EXCEPTION_EXECUTE_HANDLER;
}
void guarded_tick() {
  __try {
    game_tick();
  } __except (fault_filter(GetExceptionInformation())) {
    faulted = true;
    engine_on = false;
  }
}

std::string read_file(const std::wstring &path, bool &exists) {
  // Shared for delete too: Lua removes and renames these files while the worker may be reading them.
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  exists = f != INVALID_HANDLE_VALUE;
  if (!exists)
    return {};
  std::string text;
  char buffer[4096];
  DWORD n = 0;
  while (text.size() < (1 << 16) && ReadFile(f, buffer, sizeof buffer, &n, nullptr) && n)
    text.append(buffer, n);
  CloseHandle(f);
  return text;
}

// Worker-thread memory of what it last handed over.
std::string last_session_text, last_table_text = "\x01"; // Never equal to a real file at first.
bool pin_checked = false, fault_logged = false;
uint64_t next_poll = 0, next_counters = 0;

void pin_inner(std::string &reason) { reason = check_build(base); }
// __try may not hold objects with destructors itself, so the string lives in pin_inner.
bool pin(std::string &reason) {
  __try {
    pin_inner(reason);
    return true;
  } __except (EXCEPTION_EXECUTE_HANDLER) {
    return false;
  }
}
} // namespace

void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event) {
  if (!pin_checked) {
    pin_checked = true;
    QueryPerformanceFrequency(&frequency);
    base = reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
    std::string reason;
    if (!pin(reason))
      reason = "fault while reading the exe header";
    objects = base + kObjectsRva; // Before engine_on: the game thread reads it once the engine is on.
    engine_reason = reason.empty() ? "pinned build 24463856" : reason;
    engine_on = reason.empty();
    event(std::string("engine ") + (engine_on ? "on: " : "off: ") + engine_reason);
  }
  if (faulted && !fault_logged) {
    fault_logged = true;
    char text[160];
    char text_part[32] = "";
    if (probing_part >= 0)
      std::snprintf(text_part, sizeof text_part, " probing part %d", probing_part.load());
    std::snprintf(text, sizeof text, "engine off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx%s",
                  static_cast<unsigned long long>(fault_code.load()), static_cast<unsigned long long>(fault_rva.load()),
                  static_cast<unsigned long long>(fault_address.load()), text_part);
    engine_reason = text;
    event(text);
  }
  if (now_ms < next_poll)
    return;
  next_poll = now_ms + 250;
  bool exists = false;
  std::string token = read_file(folder + L"coop-session.txt", exists);
  if (exists && token != last_session_text) { // A new Lua load: what an older one published is stale.
    last_session_text = token;
    last_table_text = "\x01";
    {
      std::lock_guard<std::mutex> lock(m);
      incoming.reset();
      incoming_set = true;
    }
    event("new Lua session: component table dropped");
  }
  std::string text = read_file(folder + L"coop-components.txt", exists);
  if (!exists)
    text.clear();
  if (text != last_table_text) {
    last_table_text = text;
    std::unique_ptr<Table> parsed;
    if (!text.empty()) {
      if (auto t = parse_table(text))
        parsed = std::make_unique<Table>(*t);
      else
        event("component table refused: malformed");
    }
    if (parsed)
      event("component table " + std::to_string(parsed->generation) + ": " + std::to_string(parsed->eve.size()) +
            " parts");
    else if (text.empty())
      event("component table withdrawn");
    std::lock_guard<std::mutex> lock(m);
    incoming = std::move(parsed); // Frees what the game thread swapped back last time.
    incoming_set = true;
  }
  {
    std::vector<std::string> lines;
    {
      std::lock_guard<std::mutex> lock(m);
      lines.swap(outbox);
    }
    for (auto &line : lines)
      event(line);
  }
  if (now_ms >= next_counters) {
    bool first = next_counters == 0;
    next_counters = now_ms + 60000;
    uint64_t n = window_ticks.exchange(0), us = window_us.exchange(0), max_us = window_max_us.exchange(0),
             max_gap = window_max_gap_us.exchange(0), long_gaps = window_long_gaps.exchange(0);
    if (!first && n) {
      char line[200];
      std::snprintf(line, sizeof line, "native tick, last 60 s: %llu ticks, mean %llu us, max %llu us, max gap %llu ms, %llu gaps over 100 ms, %llu doubles",
                static_cast<unsigned long long>(n), static_cast<unsigned long long>(us / n),
                static_cast<unsigned long long>(max_us), static_cast<unsigned long long>(max_gap / 1000),
                static_cast<unsigned long long>(long_gaps), static_cast<unsigned long long>(doubles.load()));
      event(line);
    }
  }
}

void ask_probe() { probe_asked = true; }
void block() {
  blocked = true;
  engine_on = false;
}

std::string status() {
  std::string s = std::string("engine=") + (engine_on ? "on" : "off");
  if (blocked)
    s += " reason=coop_off";
  else if (!engine_on)
    s += " reason=" + engine_reason;
  for (char &c : s)
    if (c == '\n' || c == '\r')
      c = ' ';
  return s; // Stable between events: the tick counts change every frame and go into the 60 s counter line instead.
}
} // namespace coop::pose

// Called by Lua once per frame (package.loadlib(dll, "coop_tick")), in lua_CFunction's shape: the Lua state is
// ignored and nothing is returned to Lua. Never throws, never waits.
extern "C" __declspec(dllexport) int coop_tick(void *) noexcept {
  using namespace coop::pose;
  if (engine_on && !blocked)
    guarded_tick();
  return 0;
}
