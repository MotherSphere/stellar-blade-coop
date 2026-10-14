// The native pose path's Windows side. coop_tick runs on the game thread, called once per frame by the Lua loop; the
// worker thread (steam_link.cpp) calls worker_poll. They share only atomics and a mutex the game thread never waits on
// (try_lock: a busy lock skips the hand-over until the next frame; only swaps happen under it, never allocations).
// Every engine access runs under SEH; the first fault latches the feature off for the run and is logged with its code,
// the DLL offset, the address and the part.
//
// The delayed mirror (coop mirror <ms>): on each new component table it first probes every leader pair right after
// Lua's CopyPose (Lua keeps copying until this side reports the mirror on for that table). Once the probe passes, each
// frame records EVE's main mesh world transform and her leaders' local poses into the session's ring, plays back the
// frame from <ms> ago into the puppet's leaders behind CopyPose's own gate, and writes the main mesh transform into
// the mailbox, which Lua reads back to place the puppet.
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
std::atomic<int> probing_part{-1}; // The part being read or written, for the fault line.

// Mirror: requested delay (0 off) from the worker; the table generation it runs on (0 none) for the status.
std::atomic<uint32_t> mirror_ms{0};
std::atomic<uint64_t> mirror_generation{0};

// Hand-over, guarded by m: the worker's newest session (or a withdrawal) for the game thread, and the game thread's
// result lines for the worker to log.
std::mutex m;
std::unique_ptr<Session> incoming;
bool incoming_set = false;
std::vector<std::string> outbox;

// Game thread only.
std::unique_ptr<Session> session;
std::vector<std::string> pending; // Results not handed over yet (the lock was busy, or the worker had not read them).
LARGE_INTEGER frequency{}, last_call{};
uint64_t last_frame = 0, checked_generation = 0;
float stamp = 1; // The mailbox's scale Z: the engine default is 1, our stamps run from 2 up.
// GFrameCounter (PHASE2-RE.md): incremented once per frame by FEngineLoop::Tick, and on some loading paths; compare
// "different from the last call", never "last + 1".
constexpr uint32_t kFrameCounterRva = 0x706b508;

// Cost counters, game thread writes, worker reads and resets every 60 s.
std::atomic<uint64_t> window_ticks{0}, window_us{0}, window_max_us{0}, window_max_gap_us{0}, window_long_gaps{0},
    window_recorded{0}, window_written{0}, window_record_refused{0}, window_write_refused{0};
std::atomic<int> last_refusal{0}; // An Io value, for the counter line.

uint64_t micros_between(LARGE_INTEGER a, LARGE_INTEGER b) {
  return frequency.QuadPart ? uint64_t((b.QuadPart - a.QuadPart) * 1000000 / frequency.QuadPart) : 0;
}
uint64_t micros_now(LARGE_INTEGER now) {
  return frequency.QuadPart ? uint64_t(now.QuadPart / frequency.QuadPart * 1000000 +
                                       now.QuadPart % frequency.QuadPart * 1000000 / frequency.QuadPart)
                            : 0;
}
void raise_max(std::atomic<uint64_t> &slot, uint64_t value) {
  uint64_t seen = slot.load();
  while (value > seen && !slot.compare_exchange_weak(seen, value))
    ;
}

// Probes every leader pair; true when all are offsets_ok. Lines go to pending (all of them when verbose, else only
// the failures and the summary).
bool probe(bool verbose) {
  const Table &table = session->table;
  int ok = 0, leaders = 0;
  for (size_t i = 0; i < table.eve.size(); ++i) {
    if (!table.eve[i].leader)
      continue;
    ++leaders;
    probing_part = static_cast<int>(i);
    ProbeResult r = probe_pair(objects, table.eve[i], table.puppet[i]);
    probing_part = -1;
    ok += r.kind == ProbeResult::ok;
    if (!verbose && r.kind == ProbeResult::ok)
      continue;
    char line[320];
    std::snprintf(line, sizeof line,
                  "probe part %d (%u bones): %s (eve count %d, puppet count %d, first difference %u; after CopyPose: "
                  "refresh %u, gate pointer %s, gate count %d, anim tasks 0x%llx 0x%llx)",
                  static_cast<int>(i), table.eve[i].bones, describe(r.kind), r.eve_count_seen, r.puppet_count_seen,
                  r.first_difference, r.refresh, r.gate_pointer ? "set" : "null", r.gate_count,
                  static_cast<unsigned long long>(r.task), static_cast<unsigned long long>(r.task2));
    pending.push_back(line);
  }
  char line[96];
  std::snprintf(line, sizeof line, "probe: %d of %d leader parts offsets_ok (table %llu)", ok, leaders,
                static_cast<unsigned long long>(table.generation));
  pending.push_back(line);
  return leaders > 0 && ok == leaders;
}

// Records EVE's frame now into the ring (at most every kMinSpacingUs, so the ring always covers 2 s).
void record(uint64_t now_us) {
  const Table &table = session->table;
  Ring &ring = session->ring;
  if (!published(objects, table.eve[0])) {
    ++window_record_refused;
    last_refusal = static_cast<int>(Io::gone);
    return;
  }
  uint64_t newest = ring.newest();
  if (newest && now_us - newest < Ring::kMinSpacingUs)
    return;
  Ring::Frame &f = ring.begin(now_us);
  read_world(static_cast<uintptr_t>(table.eve[0].object), f.root);
  size_t offset = 0;
  for (size_t i = 0; i < table.eve.size(); ++i) {
    if (!table.eve[i].leader)
      continue;
    probing_part = static_cast<int>(i);
    Io r = read_leader(objects, table.eve[i], f.bones.data() + offset);
    probing_part = -1;
    if (r != Io::ok) {
      ++window_record_refused;
      last_refusal = static_cast<int>(r);
      ring.cancel();
      return;
    }
    offset += size_t(table.eve[i].bones) * kTransformBytes;
  }
  ring.commit();
  ++window_recorded;
}

// Plays the frame from the delay ago into the puppet's leaders and the mailbox.
void play_back(uint64_t now_us, uint32_t delay_ms) {
  const Table &table = session->table;
  const Ring::Frame *play = session->ring.at_delay(now_us, uint64_t(delay_ms) * 1000);
  if (!play)
    return; // Not enough history yet, or a gap in recording.
  size_t offset = 0;
  bool all = true;
  for (size_t i = 0; i < table.puppet.size(); ++i) {
    if (!table.puppet[i].leader)
      continue;
    probing_part = static_cast<int>(i);
    Io r = write_leader(objects, table.puppet[i], play->bones.data() + offset);
    probing_part = -1;
    if (r != Io::ok) {
      all = false;
      last_refusal = static_cast<int>(r);
    }
    offset += size_t(table.puppet[i].bones) * kTransformBytes;
  }
  stamp = stamp >= 1e6f ? 2.f : stamp + 1.f;
  if (write_mailbox(objects, table.mailbox, table.mailbox_class, table.puppet[0], play->root, stamp) != Io::ok) {
    all = false;
    last_refusal = static_cast<int>(Io::gone);
  }
  ++(all ? window_written : window_write_refused);
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
      session.swap(incoming);
      incoming_set = false;
    }
    if (outbox.empty())
      outbox.swap(pending);
    m.unlock();
  }
  if (probe_asked.exchange(false)) {
    if (session)
      probe(true);
    else
      pending.push_back("probe: no component table (spawn the puppet with coop puppet)");
  }
  uint32_t delay = mirror_ms.load();
  uint64_t generation = session ? session->table.generation : 0;
  if (!delay || !session) {
    mirror_generation = 0;
    checked_generation = 0;
  } else if (mirror_generation != generation) {
    // A new table (or a new request): Lua still copied this frame, so the probe checks this table first, once.
    if (checked_generation != generation) {
      checked_generation = generation;
      if (probe(false)) {
        session->ring.clear(); // Never play back a moment from before this start.
        mirror_generation = generation;
        char line[96];
        std::snprintf(line, sizeof line, "mirror on: %u ms behind, table %llu", delay,
                      static_cast<unsigned long long>(generation));
        pending.push_back(line);
      } else {
        pending.push_back("mirror refused on this table: the probe above failed; Lua keeps copying");
      }
    }
  } else {
    uint64_t now_us = micros_now(now);
    record(now_us);
    play_back(now_us, delay);
  }
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
    mirror_generation = 0;
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

void hand_over(std::unique_ptr<Session> next) {
  std::lock_guard<std::mutex> lock(m);
  incoming = std::move(next); // Frees what the game thread swapped back last time.
  incoming_set = true;
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
      std::snprintf(text_part, sizeof text_part, " at part %d", probing_part.load());
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
    hand_over(nullptr);
    event("new Lua session: component table dropped");
  }
  std::string text = read_file(folder + L"coop-components.txt", exists);
  if (!exists)
    text.clear();
  if (text != last_table_text) {
    last_table_text = text;
    std::unique_ptr<Session> next;
    if (!text.empty()) {
      if (auto t = parse_table(text))
        next = std::make_unique<Session>(std::move(*t)); // The ring is sized here, off the game thread.
      else
        event("component table refused: malformed");
    }
    if (next)
      event("component table " + std::to_string(next->table.generation) + ": " +
            std::to_string(next->table.eve.size()) + " parts");
    else if (text.empty())
      event("component table withdrawn");
    hand_over(std::move(next));
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
             max_gap = window_max_gap_us.exchange(0), long_gaps = window_long_gaps.exchange(0),
             recorded = window_recorded.exchange(0), written = window_written.exchange(0),
             record_refused = window_record_refused.exchange(0), write_refused = window_write_refused.exchange(0);
    if (!first && n) {
      char line[320];
      std::snprintf(line, sizeof line,
                    "native tick, last 60 s: %llu ticks, mean %llu us, max %llu us, max gap %llu ms, %llu gaps over "
                    "100 ms, %llu doubles; mirror: %llu recorded, %llu written, %llu not recorded, %llu not written "
                    "(last: %s)",
                    static_cast<unsigned long long>(n), static_cast<unsigned long long>(us / n),
                    static_cast<unsigned long long>(max_us), static_cast<unsigned long long>(max_gap / 1000),
                    static_cast<unsigned long long>(long_gaps), static_cast<unsigned long long>(doubles.load()),
                    static_cast<unsigned long long>(recorded), static_cast<unsigned long long>(written),
                    static_cast<unsigned long long>(record_refused), static_cast<unsigned long long>(write_refused),
                    describe(static_cast<Io>(last_refusal.load())));
      event(line);
    }
  }
}

void ask_probe() { probe_asked = true; }
void ask_mirror(uint32_t ms) { mirror_ms = ms; }
void block() {
  blocked = true;
  engine_on = false;
  mirror_ms = 0;
  mirror_generation = 0;
}

std::string status() {
  std::string s = std::string("engine=") + (engine_on ? "on" : "off");
  if (blocked)
    s += " reason=coop_off";
  else if (!engine_on)
    s += " reason=" + engine_reason;
  uint32_t delay = mirror_ms.load();
  uint64_t generation = mirror_generation.load();
  if (engine_on && delay)
    s += generation ? " mirror=on " + std::to_string(delay) + " table " + std::to_string(generation)
                    : std::string(" mirror=waiting");
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
