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
//
// The loopback (coop loopback <delay> <jitter> <loss %>, Phase 3): the whole ghost pipeline on one PC. After the same
// probe, the game thread reads EVE every 50 ms and encodes her pose (pose_codec.h); the worker sends it into the delay
// line (pose_stream.h) and hands what comes out back; the game thread decodes it into the playback and writes the
// playback's pose for each frame into the puppet, as the mirror does. Phase 4 swaps the delay line for Steam.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX // std::min and std::max in pose_stream.h.
#include <windows.h>

#include <array>
#include <atomic>
#include <cstdio>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "pose_codec.h"
#include "pose_engine.h"
#include "pose_stream.h"
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
// Loopback: on and its settings, from the worker (never both with the mirror); the table generation it runs on.
std::atomic<bool> loopback_on{false};
std::atomic<uint32_t> loopback_delay{0}, loopback_jitter{0}, loopback_loss{0};
std::atomic<uint32_t> loopback_epoch{0}; // Bumped by every settings change: the playback's clock starts again.
std::atomic<uint64_t> loopback_generation{0};

// A Session with the pose stream's memory, all sized by the worker for its table: the playback, EVE's pose as read
// for sending, and the pose drawn this frame.
struct Live : Session {
  Table layout; // What the codec reads (pose_table.h): the mirror table's generation and EVE's parts.
  Playback playback;
  std::vector<uint8_t> capture, draw;
  float capture_root[10] = {}, draw_root[10] = {};
  explicit Live(Mirror t) : Session(std::move(t)) {
    layout.generation = table.generation;
    layout.eve = table.eve;
    playback.reset(ring.bytes());
    capture.assign(ring.bytes(), 0);
    draw.assign(ring.bytes(), 0);
  }
};

// An encoded pose on its way: bytes (sized kMaxPose once, by the worker, before the engine goes on; only swapped after
// that), its size, and when it was read (outgoing) or received (incoming), in µs.
struct Message {
  std::vector<uint8_t> data;
  size_t size = 0;
  uint64_t time = 0;
};
constexpr size_t kInbox = 8;

// Hand-over, guarded by m: the worker's newest session (or a withdrawal) for the game thread, and the game thread's
// result lines for the worker to log; the newest encoded pose for the worker (out_fresh), and the poses the worker got
// back for the game thread.
std::mutex m;
std::unique_ptr<Live> incoming;
bool incoming_set = false;
std::vector<std::string> outbox;
Message out_mid;
bool out_fresh = false;
std::array<Message, kInbox> inbox;
size_t inbox_count = 0;

// Game thread only.
std::unique_ptr<Live> session;
std::vector<std::string> pending; // Results not handed over yet (the lock was busy, or the worker had not read them).
LARGE_INTEGER frequency{}, last_call{};
uint64_t last_frame = 0, checked_generation = 0, next_capture = 0;
int checked_mode = 0;
uint32_t sequence = 0; // Of the poses sent: never restarts in a run, so a pose still in flight is always the older.
uint32_t seen_epoch = 0;
float stamp = 1; // The mailbox's scale Z: the engine default is 1, our stamps run from 2 up.
Message out_back;
bool out_ready = false; // out_back holds a pose the worker has not been handed yet.
std::array<Message, kInbox> game_inbox;
size_t game_inbox_count = 0;
constexpr uint64_t kSendUs = 50'000; // 20 poses a second (N4).

// Worker only: the encoded pose taken from the game thread, and the loopback's delay line.
Message worker_out;
DelayLine delay_line;
bool buffers_ready = false;
// GFrameCounter (PHASE2-RE.md): incremented once per frame by FEngineLoop::Tick, and on some loading paths; compare
// "different from the last call", never "last + 1".
constexpr uint32_t kFrameCounterRva = 0x706b508;

// Cost counters, game thread writes, worker reads and resets every 60 s.
std::atomic<uint64_t> window_ticks{0}, window_us{0}, window_max_us{0}, window_max_gap_us{0}, window_long_gaps{0},
    window_recorded{0}, window_written{0}, window_record_refused{0}, window_write_refused{0};
std::atomic<int> last_refusal{0}; // An Io value, for the counter line.
// The loopback's, the same way (the worker's own two included).
std::atomic<uint64_t> window_sent{0}, window_sent_bytes{0}, window_clamped{0}, window_capture_refused{0},
    window_line_lost{0}, window_inbox_full{0}, window_rejected{0}, window_poses{0}, window_stale{0}, window_missing{0},
    window_stalls{0}, window_steps{0}, window_drawn{0}, window_extrapolated{0}, window_drawn_written{0},
    window_drawn_refused{0};
std::atomic<int64_t> window_lag_us{0}, window_behind_us{0};
std::atomic<const char *> last_reject{"none"}; // decode_pose's reason.

// The encoded pose to the worker (m held): replaces one it has not taken yet, which the receiver counts missing.
void give_out() {
  std::swap(out_back, out_mid);
  out_fresh = true;
  out_ready = false;
}

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
  const Mirror &table = session->table;
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

// EVE now: her main mesh's world transform and her leaders' local poses, back to back.
Io read_eve(float *root, uint8_t *bones) {
  const Mirror &table = session->table;
  if (!published(objects, table.eve[0]))
    return Io::gone;
  read_world(static_cast<uintptr_t>(table.eve[0].object), root);
  size_t offset = 0;
  for (size_t i = 0; i < table.eve.size(); ++i) {
    if (!table.eve[i].leader)
      continue;
    probing_part = static_cast<int>(i);
    Io r = read_leader(objects, table.eve[i], bones + offset);
    probing_part = -1;
    if (r != Io::ok)
      return r;
    offset += size_t(table.eve[i].bones) * kTransformBytes;
  }
  return Io::ok;
}

// A pose into the puppet's leaders and the mailbox; true when every write passed its checks.
bool write_puppet(const uint8_t *bones, const float *root) {
  const Mirror &table = session->table;
  size_t offset = 0;
  bool all = true;
  for (size_t i = 0; i < table.puppet.size(); ++i) {
    if (!table.puppet[i].leader)
      continue;
    probing_part = static_cast<int>(i);
    Io r = write_leader(objects, table.puppet[i], bones + offset);
    probing_part = -1;
    if (r != Io::ok) {
      all = false;
      last_refusal = static_cast<int>(r);
    }
    offset += size_t(table.puppet[i].bones) * kTransformBytes;
  }
  stamp = stamp >= 1e6f ? 2.f : stamp + 1.f;
  if (write_mailbox(objects, table.mailbox, table.mailbox_class, table.puppet[0], root, stamp) != Io::ok) {
    all = false;
    last_refusal = static_cast<int>(Io::gone);
  }
  return all;
}

// Records EVE's frame now into the ring (at most every kMinSpacingUs, so the ring always covers 2 s).
void record(uint64_t now_us) {
  Ring &ring = session->ring;
  uint64_t newest = ring.newest();
  if (newest && now_us - newest < Ring::kMinSpacingUs)
    return;
  Ring::Frame &f = ring.begin(now_us);
  Io r = read_eve(f.root, f.bones.data());
  if (r != Io::ok) {
    ++window_record_refused;
    last_refusal = static_cast<int>(r);
    ring.cancel();
    return;
  }
  ring.commit();
  ++window_recorded;
}

// Plays the frame from the delay ago into the puppet's leaders and the mailbox.
void play_back(uint64_t now_us, uint32_t delay_ms) {
  const Ring::Frame *play = session->ring.at_delay(now_us, uint64_t(delay_ms) * 1000);
  if (play) // Else not enough history yet, or a gap in recording.
    ++(write_puppet(play->bones.data(), play->root) ? window_written : window_write_refused);
}

// The loopback, each frame: EVE's pose every 50 ms, encoded for the worker; the poses the worker got back, decoded
// into the playback; the playback's pose for now, written into the puppet.
void stream(uint64_t now_us) {
  Live &live = *session;
  if (uint32_t epoch = loopback_epoch.load(); epoch != seen_epoch) {
    seen_epoch = epoch; // New settings: the poses in flight were dropped, and the old delay must not pass for a step.
    live.playback.clear();
  }
  if (now_us >= next_capture) {
    Io r = read_eve(live.capture_root, live.capture.data());
    if (r == Io::ok) {
      next_capture = (next_capture && now_us - next_capture < kSendUs ? next_capture : now_us) + kSendUs;
      PoseHeader h;
      h.generation = live.table.generation;
      h.publication = now_us;
      h.sequence = ++sequence;
      uint32_t clamped = 0;
      out_back.size =
          encode_pose(live.layout, h, live.capture_root, live.capture.data(), out_back.data.data(), clamped);
      out_back.time = now_us;
      out_ready = true;
      if (m.try_lock()) { // At once, not at the next frame's hand-over: one frame less of delay.
        give_out();
        m.unlock();
      }
      ++window_sent;
      window_sent_bytes += out_back.size;
      window_clamped += clamped;
    } else {
      ++window_capture_refused; // Read again next frame.
      last_refusal = static_cast<int>(r);
    }
  }
  for (size_t i = 0; i < game_inbox_count; ++i) {
    Playback::Frame &f = live.playback.scratch();
    PoseHeader h;
    const Message &in = game_inbox[i];
    if (const char *why = decode_pose(live.layout, in.data.data(), in.size, h, f.root, f.bones.data())) {
      ++window_rejected;
      last_reject = why;
      continue;
    }
    f.sequence = h.sequence;
    f.publication = h.publication;
    live.playback.accept(in.time);
  }
  if (live.playback.sample(now_us, live.draw_root, live.draw.data()))
    ++(write_puppet(live.draw.data(), live.draw_root) ? window_drawn_written : window_drawn_refused);
  Playback::Stats s = live.playback.take();
  window_poses += s.poses;
  window_stale += s.stale;
  window_missing += s.lost;
  window_stalls += s.stalls;
  window_steps += s.steps;
  window_drawn += s.drawn;
  window_extrapolated += s.extrapolated;
  window_lag_us += int64_t(s.lag_ms * 1000);
  window_behind_us += int64_t(s.behind_ms * 1000);
}

// Starts the mirror (mode 1) or the loopback (mode 2) on the current table, once its probe passed.
void start(int mode, uint32_t delay, uint64_t generation) {
  char line[200];
  const char *name = mode == 1 ? "mirror" : "loopback";
  size_t pose_bytes = pose_size(session->layout);
  if (mode == 2 && !pose_bytes) {
    std::snprintf(line, sizeof line, "loopback refused on table %llu: one pose would be over %zu bytes",
                  static_cast<unsigned long long>(generation), kMaxPose);
  } else if (!probe(false)) {
    std::snprintf(line, sizeof line, "%s refused on this table: the probe above failed; Lua keeps copying", name);
  } else if (mode == 1) {
    session->ring.clear(); // Never play back a moment from before this start.
    mirror_generation = generation;
    std::snprintf(line, sizeof line, "mirror on: %u ms behind, table %llu", delay,
                  static_cast<unsigned long long>(generation));
  } else {
    session->playback.clear(); // A new stream: the clock starts again.
    seen_epoch = loopback_epoch.load();
    next_capture = 0;
    loopback_generation = generation;
    std::snprintf(line, sizeof line, "loopback on: %u ms one way, %u ms jitter, %u %% segment loss, table %llu, %zu "
                  "bytes a pose", loopback_delay.load(), loopback_jitter.load(), loopback_loss.load(),
                  static_cast<unsigned long long>(generation), pose_bytes);
  }
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
      session.swap(incoming);
      incoming_set = false;
    }
    if (outbox.empty())
      outbox.swap(pending);
    if (out_ready) // A pose whose own hand-over found the lock busy.
      give_out();
    if (inbox_count) { // game_inbox_count is 0: every tick ends by emptying it.
      inbox.swap(game_inbox);
      std::swap(inbox_count, game_inbox_count);
    }
    m.unlock();
  }
  if (probe_asked.exchange(false)) {
    if (session)
      probe(true);
    else
      pending.push_back("probe: no component table (spawn the puppet with coop puppet)");
  }
  uint32_t delay = mirror_ms.load();
  int mode = !session ? 0 : delay ? 1 : loopback_on ? 2 : 0; // The worker never asks for both.
  uint64_t generation = session ? session->table.generation : 0;
  if (mode != 1)
    mirror_generation = 0;
  if (mode != 2)
    loopback_generation = 0;
  if (!mode) {
    checked_generation = 0;
  } else if ((mode == 1 ? mirror_generation : loopback_generation).load() != generation) {
    // A new table (or a new request): Lua still copied this frame, so the probe checks this table first, once.
    if (checked_generation != generation || checked_mode != mode) {
      checked_generation = generation;
      checked_mode = mode;
      start(mode, delay, generation);
    }
  } else if (mode == 1) {
    uint64_t now_us = micros_now(now);
    record(now_us);
    play_back(now_us, delay);
  } else {
    stream(micros_now(now));
  }
  game_inbox_count = 0; // Poses the loopback did not run for are dropped.
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
    loopback_generation = 0;
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

void hand_over(std::unique_ptr<Live> next) {
  std::lock_guard<std::mutex> lock(m);
  incoming = std::move(next); // Frees what the game thread swapped back last time.
  incoming_set = true;
}
} // namespace

void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event) {
  if (!pin_checked) {
    pin_checked = true;
    QueryPerformanceFrequency(&frequency);
    for (Message *each : {&out_mid, &out_back, &worker_out})
      each->data.resize(kMaxPose); // Before the engine goes on: the game thread only swaps them.
    for (auto &each : inbox)
      each.data.resize(kMaxPose);
    for (auto &each : game_inbox)
      each.data.resize(kMaxPose);
    buffers_ready = true;
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
    std::unique_ptr<Live> next;
    if (!text.empty()) {
      if (auto t = parse_table(text))
        next = std::make_unique<Live>(std::move(*t)); // Sized here, off the game thread.
      else
        event("component table refused: malformed");
    }
    if (next)
      event("component table " + std::to_string(next->table.generation) + ": " +
            std::to_string(next->table.eve.size()) + " parts");
    else if (text.empty())
      event("component table withdrawn");
    hand_over(std::move(next));
    delay_line.flush(); // Poses in flight belong to the old table.
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
    uint64_t sent = window_sent.exchange(0), sent_bytes = window_sent_bytes.exchange(0),
             clamped = window_clamped.exchange(0), capture_refused = window_capture_refused.exchange(0),
             line_lost = window_line_lost.exchange(0), inbox_full = window_inbox_full.exchange(0),
             rejected = window_rejected.exchange(0), poses = window_poses.exchange(0), stale = window_stale.exchange(0),
             missing = window_missing.exchange(0), stalls = window_stalls.exchange(0),
             steps = window_steps.exchange(0), drawn = window_drawn.exchange(0),
             extrapolated = window_extrapolated.exchange(0), drawn_written = window_drawn_written.exchange(0),
             drawn_refused = window_drawn_refused.exchange(0);
    int64_t lag_us = window_lag_us.exchange(0), behind_us = window_behind_us.exchange(0);
    if (!first && n) {
      char line[640];
      int at = std::snprintf(line, sizeof line,
                             "native tick, last 60 s: %llu ticks, mean %llu us, max %llu us, max gap %llu ms, %llu gaps "
                             "over 100 ms, %llu doubles",
                             static_cast<unsigned long long>(n), static_cast<unsigned long long>(us / n),
                             static_cast<unsigned long long>(max_us), static_cast<unsigned long long>(max_gap / 1000),
                             static_cast<unsigned long long>(long_gaps), static_cast<unsigned long long>(doubles.load()));
      if (recorded || record_refused || written || write_refused)
        std::snprintf(line + at, sizeof line - size_t(at),
                      "; mirror: %llu recorded, %llu written, %llu not recorded, %llu not written (last: %s)",
                      static_cast<unsigned long long>(recorded), static_cast<unsigned long long>(written),
                      static_cast<unsigned long long>(record_refused), static_cast<unsigned long long>(write_refused),
                      describe(static_cast<Io>(last_refusal.load())));
      event(line);
      if (sent || capture_refused || poses || rejected || drawn) {
        std::snprintf(line, sizeof line,
                      "loopback, last 60 s: %llu sent (%.1f a second, %llu bytes each, %.1f KB/s, %llu values cut, "
                      "%llu reads refused), %llu lost on the line, %llu over the inbox, %llu received, %llu rejected "
                      "(last: %s), %llu stale, %llu missing, %llu stalls, %llu clock steps, one way %.1f ms; %llu drawn, "
                      "%llu past the newest pose, %.1f ms behind it; %llu written, %llu not written (last: %s)",
                      static_cast<unsigned long long>(sent), sent / 60.0,
                      static_cast<unsigned long long>(sent ? sent_bytes / sent : 0), sent_bytes / 60.0 / 1024,
                      static_cast<unsigned long long>(clamped), static_cast<unsigned long long>(capture_refused),
                      static_cast<unsigned long long>(line_lost), static_cast<unsigned long long>(inbox_full),
                      static_cast<unsigned long long>(poses), static_cast<unsigned long long>(rejected),
                      last_reject.load(), static_cast<unsigned long long>(stale),
                      static_cast<unsigned long long>(missing), static_cast<unsigned long long>(stalls),
                      static_cast<unsigned long long>(steps), poses ? lag_us / 1000.0 / double(poses) : 0.0, static_cast<unsigned long long>(drawn),
                      static_cast<unsigned long long>(extrapolated), drawn ? behind_us / 1000.0 / double(drawn) : 0.0,
                      static_cast<unsigned long long>(drawn_written), static_cast<unsigned long long>(drawn_refused),
                      describe(static_cast<Io>(last_refusal.load())));
        event(line);
      }
    }
  }
}

bool worker_stream() {
  if (!buffers_ready)
    return false;
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  uint64_t now_us = micros_now(now);
  bool on = loopback_on.load();
  {
    std::lock_guard<std::mutex> lock(m);
    if (out_fresh) {
      std::swap(out_mid, worker_out);
      out_fresh = false;
    }
  }
  if (worker_out.size) {
    if (on && !delay_line.send(worker_out.data.data(), worker_out.size, now_us))
      ++window_line_lost;
    worker_out.size = 0;
  }
  delay_line.deliver(now_us, [&](const uint8_t *data, size_t size) {
    std::lock_guard<std::mutex> lock(m);
    if (inbox_count == kInbox || size > kMaxPose) {
      ++window_inbox_full;
      return;
    }
    Message &in = inbox[inbox_count++];
    std::memcpy(in.data.data(), data, size);
    in.size = size;
    in.time = now_us;
  });
  return on && loopback_generation.load(); // Every 5 ms only while a stream actually runs.
}

void ask_probe() { probe_asked = true; }
std::string ask_mirror(uint32_t ms) {
  if (!ms) // Off works even with the engine off (after a fault), like the loopback's.
    return mirror_ms.exchange(0) ? "mirror off: Lua copies the pose again" : "mirror is not on";
  if (!engine_on)
    return "mirror not started: " + status();
  if (loopback_on)
    return "mirror not started while the loopback runs: coop loopback off first";
  mirror_ms = ms;
  return "mirror asked: " + std::to_string(ms) + " ms behind, after a probe of the current table";
}
std::string ask_loopback(bool on, uint32_t delay_ms, uint32_t jitter_ms, uint32_t loss_percent) {
  if (!on) {
    if (!loopback_on.exchange(false))
      return "loopback is not on";
    delay_line.set({}, 1);
    return "loopback off: Lua copies the pose again";
  }
  if (!engine_on)
    return "loopback not started: " + status();
  if (mirror_ms)
    return "loopback not started while the mirror runs: coop mirror off first";
  LARGE_INTEGER seed;
  QueryPerformanceCounter(&seed);
  delay_line.set({delay_ms, jitter_ms, loss_percent}, uint64_t(seed.QuadPart));
  loopback_delay = delay_ms;
  loopback_jitter = jitter_ms;
  loopback_loss = loss_percent;
  ++loopback_epoch;
  bool was_on = loopback_on.exchange(true);
  char text[160];
  std::snprintf(text, sizeof text, "loopback %s: %u ms one way, %u ms jitter, %u %% segment loss%s",
                was_on ? "settings changed" : "asked", delay_ms, jitter_ms, loss_percent,
                was_on ? "" : ", after a probe of the current table");
  return text;
}
bool driving() { return mirror_ms || loopback_on; }
void block() {
  blocked = true;
  engine_on = false;
  mirror_ms = 0;
  mirror_generation = 0;
  loopback_on = false;
  loopback_generation = 0;
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
  generation = loopback_generation.load();
  if (engine_on && loopback_on)
    s += generation ? " loopback=on " + std::to_string(loopback_delay) + " " + std::to_string(loopback_jitter) + " " +
                          std::to_string(loopback_loss) + " table " + std::to_string(generation)
                    : std::string(" loopback=waiting");
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
