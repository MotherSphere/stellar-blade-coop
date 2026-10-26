// Part of glue/tick.cpp, one translation unit with it (see there).
// The worker thread's side of the pose path: the files shared with Lua, the logs, the wire in and out, the tables, worker_poll and the loopback, record, replay and Night Operation asks.

namespace coop::pose {

// At most about max bytes of the file (read on in 4 KB steps while under it): Lua's files and the remote table are
// under 64 KB, a recording under 25 MiB, so a longer file reads past its cap and is refused by its parser.
std::string read_file(const std::wstring &path, bool &exists, size_t max) {
  // Shared for delete too: Lua removes and renames these files while the worker may be reading them.
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  exists = f != INVALID_HANDLE_VALUE;
  if (!exists)
    return {};
  std::string text;
  char buffer[4096];
  DWORD n = 0;
  while (text.size() < max && ReadFile(f, buffer, sizeof buffer, &n, nullptr) && n)
    text.append(buffer, n);
  CloseHandle(f);
  return text;
}

namespace {
// Worker thread only from here.
std::function<void(const std::string &)> say = [](const std::string &) {}; // worker_poll's event, once it ran.
std::wstring dir;                                                            // The mod folder.
bool pin_checked = false, fault_logged = false, fx_fault_logged = false, buffers_ready = false,
     warp_fault_logged = false;
int pad_logged = kPadUnread; // pad_seen as last logged.
// The follow's travel: its fault, the last ask, watch and globals logged, and the alias of the last ask (with its
// number), for the call's log line.
bool travel_fault_logged = false, travel_globals_logged = false;
uint32_t travel_logged = 0, travel_watch_logged = 0, travel_alias_ask = 0;
std::string travel_alias;
uint64_t next_poll = 0, next_counters = 0;
uint64_t vitals_reads = 0, vitals_max_us = 0; // local_vitals()'s, for the 60 s line.
State lua; // coop-state.txt as last read: a save loaded, the send rate, the synced photo mode's fields.
uint64_t freeze_until = 0; // When the running coop freeze ends (GetTickCount64 ms); 0: none.
uint32_t freeze_tests = 0; // coop freeze holds asked this run: each one's number.
uint64_t freeze_reapplied_seen = 0, freeze_dropped_seen = 0;
bool freeze_fault_logged = false;
Message worker_out; // The encoded pose taken from the game thread.
DelayLine delay_line;
Replay replay;
std::unique_ptr<Recorder> recorder; // While coop record runs: reserved at its start, freed at its stop.
uint64_t record_start_us = 0;
constexpr uint64_t kRecordUs = 120'000'000;
// EVE's capture (Lua's file) and the wire text sent for it; the remote table (from the wire) and its text, written
// to coop-remote.txt (remote_count times so far, by its source); the ghost Lua built for it. Each *_text is the file or
// message as last taken; "\x01" is never equal to a real one, so the next one is taken whatever it is.
Table capture, remote;
Display display;
std::string session_text, capture_text = "\x01", sent_table, remote_text, display_text = "\x01";
bool remote_unwritten = false; // The write failed (Lua had the file open): tried again at each pass.
uint64_t remote_count = 0;
const char kPeer[] = "peer";
const char *remote_source = "loopback";
void (*peer_send)(const uint8_t *, size_t, bool) = nullptr; // Set by peer() each pass, before peer_on can be true.
uint64_t next_table_ms = 0, last_renewal_us = 0;
// Night Operation probe (Phase 6): read-only, its own latch (pinned && !blocked), so a pose fault leaves it running.
bool pinned = false, nightop_on = false;
// pinned for the game thread's pause, pilot, quest, revive and travel calls; each keeps its own *_faulted latch.
std::atomic<bool> game_pinned{false};
nightop::Poller poller;
uint64_t nightop_next = 0;
size_t nightop_bytes = 0;
constexpr size_t kProbeCap = 4 << 20; // About 30 min of lines at 10 a second (a field flickering every sample).
// ReadProcessMemory fails on unmapped memory instead of faulting, and never trips a guard page.
bool rpm(uint64_t address, void *out, size_t n) {
  SIZE_T got = 0;
  return ReadProcessMemory(GetCurrentProcess(), reinterpret_cast<LPCVOID>(address), out, n, &got) && got == n;
}
// The shared fight's worker side (fight/engine.h's Worker), with channel 2 as the last fight_pass gave it.
fight::Worker fight_worker{fight_engine, fight_mail};
bool (*fight_send)(const std::string &, bool) = nullptr;
bool fight_fault_logged = false;
void trace_fight(const std::string &line);
struct FightIo {
  bool send(const std::string &line, bool reliable) { return fight_send && fight_send(line, reliable); }
  void say(const std::string &line) { pose::say(line); }
  void trace(const std::string &line) { trace_fight(line); }
  bool save(const std::string &text) { return write_text(dir + L"coop-fight-record.txt", text); }
  std::string load(bool &exists) { return read_file(dir + L"coop-fight-record.txt", exists, fight::kMaxRecording + 1); }
};

// Bytes onto a file of the mod folder, shared for delete too (it may be read or moved while open).
void append_file(const wchar_t *name, const std::string &text) {
  HANDLE f = CreateFileW((dir + name).c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                         nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return;
  DWORD n = 0;
  WriteFile(f, text.data(), static_cast<DWORD>(text.size()), &n, nullptr);
  CloseHandle(f);
}

// One line onto nightop-probe.txt. Past 4 MB a last line says so and the poller stops for the run.
void append_probe(const std::string &line) {
  if (!nightop_on)
    return; // Capped earlier in this step: its other lines go nowhere.
  std::string text = line + "\r\n";
  if (nightop_bytes + text.size() > kProbeCap) {
    text = "capped at 4 MB: the poller stops\r\n";
    nightop_on = false;
    nightop_bytes = kProbeCap; // ask_nightop refuses to start it again.
    say("nightop poller off: nightop-probe.txt capped at 4 MB");
  } else {
    nightop_bytes += text.size();
  }
  append_file(L"nightop-probe.txt", text);
}

// A line onto one of the mod folder's own logs, stamped in UTC like coop-link.log, whose 1 MB it would fill:
// coop-fight.log (the shared fight Worker's trace: its probe actors and stats lines) and coop-quests.log (the shared
// quests'). Past 4 MB a last line says what goes on (tail) and the run's later ones go nowhere.
constexpr size_t kTraceCap = 4 << 20; // About 2 h of the fight's stats lines each second, or a probe's half hour.
struct Trace {
  const wchar_t *file;
  const char *who, *name, *tail;
  size_t bytes = 0;
};
Trace fight_trace{L"coop-fight.log", "fight", "coop-fight.log", "the shared fight's events go on in coop-link.log"};
Trace quest_trace{L"coop-quests.log", "quests", "coop-quests.log",
                  "the shared quests' on and off lines go on in coop-link.log"};
void trace(Trace &log, const std::string &line) {
  if (log.bytes >= kTraceCap)
    return;
  SYSTEMTIME t;
  GetSystemTime(&t);
  char stamp[32];
  wsprintfA(stamp, "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ ", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond,
            t.wMilliseconds);
  std::string text = stamp + line + "\r\n";
  if (log.bytes + text.size() > kTraceCap) {
    text = std::string(stamp) + "capped at 4 MB: " + log.tail + "\r\n";
    log.bytes = kTraceCap;
    say(std::string(log.who) + ": " + log.name + " capped at 4 MB for this run");
  } else {
    log.bytes += text.size();
  }
  append_file(log.file, text);
}
void trace_fight(const std::string &line) { trace(fight_trace, line); }

// Every worker pass while on: a sample each 100 ms, its lines into the file, the verdict into the log as well.
void poll_nightop(uint64_t now_ms) {
  if (blocked) {
    nightop_on = false;
    say("nightop poller off: coop off");
    return;
  }
  if (now_ms < nightop_next)
    return;
  nightop_next = now_ms + nightop::kSampleMs;
  for (const std::string &line : poller.step(nightop::sample(base, rpm), now_ms)) {
    append_probe(line);
    size_t text = line.find(' ') + 1; // After "<t> ".
    if (!line.compare(text, 8, "verdict "))
      say("nightop " + line.substr(text));
  }
}

// One remote source at a time: a loopback or replay started by hand takes over from her until it is off.
// engine_on also means the inbox buffers are sized.
bool peer_open() { return engine_on && !blocked && !loopback_on && !replay.on(); }

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

// The game thread's next Live from the worker's tables. Only when the capture generation, the remote generation or
// the ghost changes: a new Live starts the ghost's playback again.
// ponytail: a new Live also forgets her keyframe, so her deltas are dropped as keyless until her next one: up to 250 ms
// frozen plus the playback's refill. A new capture generation (our outfit; hers in loopback) does so too while her
// table and ghost stay; carry the playback and the decoder across then, if T4 shows it.
void rebuild() {
  std::unique_ptr<Live> next;
  if (capture.generation || remote.generation)
    next = std::make_unique<Live>(capture, remote, display.generation == remote.generation ? display : Display());
  hand_over(std::move(next));
}

// Ends the recording: written to coop-record.bin when it holds a pose (else an older good one stays), then freed.
std::string stop_record(const char *why, uint64_t now_us) {
  record_on = false;
  const record::Rules &r = recorder->rules();
  bool written = r.poses && write_text(dir + L"coop-record.bin", recorder->bytes());
  char line[200];
  std::snprintf(line, sizeof line, "record stopped: %zu poses, %zu tables, %.1f MB, %.0f s (%s); %s", r.poses,
                r.tables, double(recorder->bytes().size()) / (1 << 20), double(now_us - record_start_us) / 1e6, why,
                written ? "written to coop-record.bin" : r.poses ? "coop-record.bin not written" : "nothing written");
  recorder.reset();
  return line;
}

// The only way out: into the loopback's delay line while it runs (a table reliable: never lost), to the linked friend
// (a table reliable), and into the recording while one is made.
void wire_send(const uint8_t *data, size_t size, bool reliable, uint64_t now_us) {
  if (loopback_on && !delay_line.send(data, size, now_us, reliable))
    ++window_line_lost;
  if (peer_on && peer_send)
    peer_send(data, size, reliable);
  if (recorder && !recorder->add(data, size))
    say(stop_record("full", now_us));
}
void send_table() {
  wire_send(reinterpret_cast<const uint8_t *>(sent_table.data()), sent_table.size(), true, clock_us());
}

void write_remote() {
  if (remote_unwritten && write_text(dir + L"coop-remote.txt", remote_text)) {
    remote_unwritten = false;
    ++remote_count; // Lua reads the file again when the count in the status changes.
  }
}

// A table from the wire: refused whole, or the same as the remote one (sent again), or the new remote table, in its
// canonical form for Lua. A new generation, or another layout under the same one, waits for Lua's new ghost; else it
// is a part hung elsewhere or shown or hidden, which Lua applies to the ghost it has.
void take_table(const uint8_t *data, size_t size) {
  ++window_tables_in;
  auto t = parse_table(std::string(reinterpret_cast<const char *>(data), size), false);
  if (!t) {
    ++window_tables_refused;
    say("remote table refused: malformed");
    return;
  }
  std::string text = format_table(*t);
  if (text == remote_text)
    return;
  bool renewed = t->generation != remote.generation || !same_layout(*t, remote);
  const char *source = replay.on() ? "replay" : loopback_on ? "loopback" : kPeer; // The sources exclude each other.
  // ROADMAP 4.7: one new ghost per 2 s from her at most (a LoadAsset hitch and new FNames each); her resend every 5 s
  // brings the newest table later.
  uint64_t now = clock_us();
  if (renewed && source == kPeer && now - last_renewal_us < 2'000'000) {
    ++window_tables_refused;
    return;
  }
  if (renewed)
    last_renewal_us = now;
  remote = std::move(*t);
  remote_text = std::move(text);
  remote_source = source;
  remote_unwritten = true;
  write_remote();
  say("remote table " + std::to_string(remote.generation) + (renewed ? " from the " : " again from the ") +
      remote_source + ": " + std::to_string(remote.eve.size()) + " parts, map " + remote.map);
  if (!renewed)
    return;
  display = Display();
  display_text = "\x01";
  rebuild();
}

// Hers for the drawn side, from her (channel 1's SBE, channel 2's show lines) or from a replayed recording: an SBE as
// it came, a show line parsed here (parse_show allocates: the worker's), both for the game thread under pilot_m. Full
// rings drop the newest, counted.
uint64_t pilot_in_lost = 0, pilot_in_bad = 0, pilot_bytes_in = 0;
void pilot_in(const uint8_t *data, size_t size) {
  pilot_bytes_in += size;
  if (size >= 3 && !std::memcmp(data, "SBE", 3)) {
    SbeIn m;
    if (size > sizeof m.data) {
      ++pilot_in_bad;
      return;
    }
    std::memcpy(m.data, data, size);
    m.size = size;
    std::lock_guard<std::mutex> lock(pilot_m);
    pilot_in_lost += !pilot_sbe_in.push(m);
    return;
  }
  const pilot::ShowLine l = pilot::parse_show(reinterpret_cast<const char *>(data), size);
  if (l.kind == pilot::Kind::invalid) {
    ++pilot_in_bad;
    return;
  }
  std::lock_guard<std::mutex> lock(pilot_m);
  pilot_in_lost += !pilot_lines_in.push(l);
}

// The only way in: a table to take_table, a pose or a delta of this protocol to the game thread's inbox, an SBE to the
// drawn side, anything else counted. Show lines are channel 2's text: hers come through pilot_pass, a recording's
// through replay_receive.
void wire_receive(const uint8_t *data, size_t size, uint64_t now_us) {
  if (size >= 3 && !std::memcmp(data, "SBE", 3)) {
    pilot_in(data, size);
  } else if (size >= 3 && !std::memcmp(data, "SBT", 3)) {
    take_table(data, size);
  } else if (size >= kPoseHeader && size <= kMaxPose && data[0] == 'S' && data[1] == 'B' &&
             (data[2] == 'P' || data[2] == 'D') && data[3] == kProtocol) {
    std::lock_guard<std::mutex> lock(m);
    if (inbox_count == kInbox) {
      ++window_inbox_full;
      return;
    }
    Message &in = inbox[inbox_count++];
    std::memcpy(in.data.data(), data, size);
    in.size = size;
    in.time = now_us;
  } else {
    ++window_malformed;
  }
}

// The remote table is gone with its source (loopback off, replay off, her unlink): so is the ghost.
void drop_remote() {
  if (!remote.generation)
    return;
  remote = Table();
  remote_text.clear();
  remote_unwritten = false;
  display = Display();
  display_text = "\x01";
  DeleteFileW((dir + L"coop-remote.txt").c_str());
  rebuild();
}

// coop-components.txt, when it changed: EVE's capture, sent on whenever its wire form changes (a part hung elsewhere
// keeps the generation and the Live); a new generation, or none, is a new Live.
void take_capture() {
  bool exists = false;
  std::string text = read_file(dir + L"coop-components.txt", exists, kMaxTable);
  if (text == capture_text)
    return;
  capture_text = text;
  Table t;
  if (!text.empty()) {
    if (auto got = parse_table(text, true))
      t = std::move(*got);
    else
      say("component table refused: malformed");
  }
  bool renewed = t.generation != capture.generation;
  capture = std::move(t);
  std::string wire = capture.generation ? format_table(capture) : std::string();
  if (wire != sent_table) {
    sent_table = std::move(wire);
    if (!sent_table.empty())
      send_table();
  }
  if (!renewed)
    return;
  say(capture.generation ? "component table " + std::to_string(capture.generation) + ": " +
                               std::to_string(capture.eve.size()) + " parts"
                         : std::string("component table withdrawn"));
  rebuild();
}

// coop-display.txt, when it changed: the ghost Lua built for the remote table, or none.
void take_display() {
  bool exists = false;
  std::string text = read_file(dir + L"coop-display.txt", exists, kMaxTable);
  if (text == display_text)
    return;
  display_text = text;
  Display d;
  if (auto got = parse_display(text, remote)) {
    d = std::move(*got);
    int leaders = 0, drawn = 0, mapped = 0;
    for (size_t i = 0; i < remote.eve.size(); ++i) {
      leaders += remote.eve[i].leader;
      drawn += d.puppet[i].object != 0;
      mapped += !d.remap[i].empty();
    }
    char line[180];
    std::snprintf(line, sizeof line, "ghost of table %llu drawn: %d of %d leaders (%d on a fallback mesh), %zu bytes "
                  "a pose%s", static_cast<unsigned long long>(d.generation), drawn, leaders, mapped, pose_size(remote),
                  d.effects[0] ? ", 4 effect boxes" : "");
    say(line);
  } else if (remote.generation && text.rfind("display " + std::to_string(remote.generation) + "\n", 0) == 0) {
    say("ghost of table " + std::to_string(remote.generation) + " refused: its display file is malformed");
  } // Else none yet, or an older table's, which Lua replaces.
  if (!d.generation && !display.generation)
    return;
  display = std::move(d);
  rebuild();
}
} // namespace

void worker_poll(const std::wstring &folder, uint64_t now_ms, const std::function<void(const std::string &)> &event) {
  if (!pin_checked) {
    pin_checked = true;
    say = event;
    dir = folder;
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
    safe_read = rpm;              // The same: alive() reads a table's object through it, never directly.
    engine_reason = reason.empty() ? "pinned build 24463856" : reason;
    engine_on = reason.empty();
    pinned = reason.empty();
    if (pinned) // Before any fight on: SB's image base and our jobs' vtable.
      fight_engine.init(base, &kJobVtable);
    game_pinned = pinned; // After base: the game thread's calls need it.
    event(std::string("engine ") + (engine_on ? "on: " : "off: ") + engine_reason);
    // XInput for coop_pad, from System32 only: the game's folder holds another tool's xinput1_3.dll proxy.
    HMODULE xinput = LoadLibraryExW(L"xinput1_4.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!xinput)
      xinput = LoadLibraryExW(L"xinput9_1_0.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (const FARPROC get = xinput ? GetProcAddress(xinput, "XInputGetState") : nullptr)
      xinput_get = reinterpret_cast<XInputGetStateFn>(reinterpret_cast<void *>(get));
    else
      pad_seen = kPadMissing;
  }
  // Each change of the pads coop_pad sees, so a test's log says whether the pad is read.
  if (const int seen = pad_seen; seen != pad_logged) {
    pad_logged = seen;
    std::string line = "pad: no XInput pad";
    if (seen == kPadMissing)
      line = "pad: no XInput in System32: no controller in the co-op menu";
    else if (seen > 0) {
      line = "pad: XInput pads connected:";
      for (int slot = 0; slot < 4; ++slot)
        if (seen & (1 << slot))
          line += " " + std::to_string(slot);
    }
    event(line);
  }
  if (faulted && !fault_logged) {
    fault_logged = true;
    char text[160];
    char text_part[32] = "";
    if (current_part >= 0)
      std::snprintf(text_part, sizeof text_part, " at part %d", current_part.load());
    std::snprintf(text, sizeof text, "engine off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx%s",
                  static_cast<unsigned long long>(fault_code.load()), static_cast<unsigned long long>(fault_rva.load()),
                  static_cast<unsigned long long>(fault_address.load()), text_part);
    engine_reason = text;
    event(text);
  }
  if (!effects_on && !fx_fault_logged) { // Only a fault turns them off.
    fx_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "effects off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx (part %d); the ghost goes on "
                  "without effects until the game restarts",
                  static_cast<unsigned long long>(fx_fault_code.load()),
                  static_cast<unsigned long long>(fx_fault_rva.load()),
                  static_cast<unsigned long long>(fx_fault_address.load()), fx_fault_part.load());
    event(text);
  }
  if (warp_faulted && !warp_fault_logged) {
    warp_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "warp read off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; no revive by the friend "
                  "until the game restarts",
                  static_cast<unsigned long long>(warp_fault_code.load()),
                  static_cast<unsigned long long>(warp_fault_rva.load()),
                  static_cast<unsigned long long>(warp_fault_address.load()));
    event(text);
  }
  if (travel_faulted && !travel_fault_logged) {
    travel_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "travel off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; no travel to the host until "
                  "the game restarts",
                  static_cast<unsigned long long>(travel_fault_code.load()),
                  static_cast<unsigned long long>(travel_fault_rva.load()),
                  static_cast<unsigned long long>(travel_fault_address.load()));
    event(text);
  }
  if (travel_globals_read && !travel_globals_logged) { // Once: what the request carries at +0x3c and +0x48.
    travel_globals_logged = true;
    char text[120];
    std::snprintf(text, sizeof text, "travel: the request's +0x3c and +0x48 bytes: %016llx %016llx %016llx",
                  static_cast<unsigned long long>(travel_globals[0].load()),
                  static_cast<unsigned long long>(travel_globals[1].load()),
                  static_cast<unsigned long long>(travel_globals[2].load()));
    event(text);
  }
  if (const uint64_t done = travel_done; uint32_t(done >> 32) != travel_logged) { // One line per ask handled.
    travel_logged = uint32_t(done >> 32);
    const auto why = travel::Why((done >> 16) & 0xff);
    const std::string alias = travel_logged == travel_alias_ask ? travel_alias : std::string("?");
    event(why == travel::Why::none
              ? "travel call " + alias + " ret=" + std::to_string(done & 0xff) +
                    " other_world=" + std::to_string((done >> 8) & 0xff)
              : "travel refused " + alias + ": " + travel::why_name(why));
  }
  if (const uint32_t w = uint32_t(travel_watched); w != travel_watch_logged) { // And one per state the watch reaches.
    travel_watch_logged = w;
    event("travel=" + travel::state_text(travel::State(w >> 8), travel::Why(w & 0xff)));
  }
  if (nightop_on)
    poll_nightop(now_ms);
  write_remote();
  if (remote.generation && display.generation != remote.generation)
    take_display(); // At every pass while the ghost for the remote table is awaited.
  if (now_ms < next_poll)
    return;
  next_poll = now_ms + 250;
  bool exists = false;
  std::string token = read_file(folder + L"coop-session.txt", exists, kMaxTable);
  if (exists && token != session_text) { // A new Lua load: what an older one published is stale.
    session_text = token;
    capture = Table();
    display = Display();
    sent_table.clear();
    capture_text = display_text = "\x01";
    rebuild();
    ++freeze_unsure; // Our pause tag is removed unless it is still wanted.
    debug_asks.asked = 0; // And SB's developer gates go back to the game's values.
    anim_drop = true;     // And a clip an earlier load played on EVE stops.
    event("new Lua session: capture and ghost dropped");
  }
  take_capture();
  take_display();
  // A missing or bad file keeps the previous values: Lua's put() removes the old file before it renames the new one in,
  // so the worker can find none in between.
  if (State now; parse_state(read_file(folder + L"coop-state.txt", exists, kMaxState), now)) {
    if (now.rate != lua.rate) {
      send_us = 1'000'000 / now.rate;
      event("send rate " + std::to_string(now.rate) + " poses a second");
    }
    lua = now;
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
    uint64_t sent = window_sent.exchange(0), sent_bytes = window_sent_bytes.exchange(0),
             clamped = window_clamped.exchange(0), capture_refused = window_capture_refused.exchange(0),
             line_lost = window_line_lost.exchange(0), inbox_full = window_inbox_full.exchange(0),
             tables_in = window_tables_in.exchange(0), tables_refused = window_tables_refused.exchange(0),
             rejected = window_rejected.exchange(0), foreign = window_foreign.exchange(0),
             malformed = window_malformed.exchange(0), poses = window_poses.exchange(0),
             stale = window_stale.exchange(0), missing = window_missing.exchange(0), stalls = window_stalls.exchange(0),
             steps = window_steps.exchange(0), drawn = window_drawn.exchange(0),
             extrapolated = window_extrapolated.exchange(0), drawn_written = window_drawn_written.exchange(0),
             drawn_refused = window_drawn_refused.exchange(0), keyframes = window_keyframes.exchange(0),
             deltas = window_deltas.exchange(0), delta_bytes = window_delta_bytes.exchange(0),
             held = window_held.exchange(0), keyless = window_keyless.exchange(0);
    int64_t lag_us = window_lag_us.exchange(0), behind_us = window_behind_us.exchange(0);
    uint64_t fx_started = window_fx_started.exchange(0), fx_over = window_fx_over.exchange(0),
             fx_unlisted = window_fx_unlisted.exchange(0), fx_written = window_fx_written.exchange(0);
    if (!first && vitals_reads) { // Eight ReadProcessMemory calls each; the cost under Proton is unmeasured.
      char line[96];
      std::snprintf(line, sizeof line, "vitals read, last 60 s: %llu reads, max %llu us",
                    static_cast<unsigned long long>(vitals_reads), static_cast<unsigned long long>(vitals_max_us));
      event(line);
    }
    vitals_reads = vitals_max_us = 0;
    if (!first && n) {
      char line[1100];
      std::snprintf(line, sizeof line,
                    "native tick, last 60 s: %llu ticks, mean %llu us, max %llu us, max gap %llu ms, %llu gaps over "
                    "100 ms, %llu doubles",
                    static_cast<unsigned long long>(n), static_cast<unsigned long long>(us / n),
                    static_cast<unsigned long long>(max_us), static_cast<unsigned long long>(max_gap / 1000),
                    static_cast<unsigned long long>(long_gaps), static_cast<unsigned long long>(doubles.load()));
      event(line);
      if (sent || capture_refused || tables_in || poses || rejected || foreign || malformed || drawn || keyless) {
        std::snprintf(line, sizeof line,
                      "stream, last 60 s: %llu sent (%.1f a second, %llu bytes each, %.1f KB/s, %llu values cut, "
                      "%llu reads refused; %llu keyframes, %llu deltas of %llu bytes each, %llu frames held for the "
                      "byte budget), %llu lost on the line, %llu over the inbox; tables: %llu in, %llu refused; "
                      "poses: %llu received, %llu foreign, %llu malformed, %llu rejected (last: %s), %llu keyless, "
                      "%llu stale, %llu missing, %llu stalls, %llu clock steps, one way %.1f ms; %llu drawn, %llu past "
                      "the newest pose, %.1f ms behind it; %llu written, %llu not written (last: %s)",
                      static_cast<unsigned long long>(sent), sent / 60.0,
                      static_cast<unsigned long long>(sent ? sent_bytes / sent : 0), sent_bytes / 60.0 / 1024,
                      static_cast<unsigned long long>(clamped), static_cast<unsigned long long>(capture_refused),
                      static_cast<unsigned long long>(keyframes), static_cast<unsigned long long>(deltas),
                      static_cast<unsigned long long>(deltas ? delta_bytes / deltas : 0),
                      static_cast<unsigned long long>(held),
                      static_cast<unsigned long long>(line_lost), static_cast<unsigned long long>(inbox_full),
                      static_cast<unsigned long long>(tables_in), static_cast<unsigned long long>(tables_refused),
                      static_cast<unsigned long long>(poses), static_cast<unsigned long long>(foreign),
                      static_cast<unsigned long long>(malformed), static_cast<unsigned long long>(rejected),
                      last_reject.load(), static_cast<unsigned long long>(keyless),
                      static_cast<unsigned long long>(stale),
                      static_cast<unsigned long long>(missing), static_cast<unsigned long long>(stalls),
                      static_cast<unsigned long long>(steps), poses ? lag_us / 1000.0 / double(poses) : 0.0,
                      static_cast<unsigned long long>(drawn), static_cast<unsigned long long>(extrapolated),
                      drawn ? behind_us / 1000.0 / double(drawn) : 0.0, static_cast<unsigned long long>(drawn_written),
                      static_cast<unsigned long long>(drawn_refused), describe(static_cast<Io>(last_refusal.load())));
        event(line);
      }
      if (fx_started || fx_over || fx_unlisted || fx_written) {
        std::snprintf(line, sizeof line,
                      "effects, last 60 s: %llu started, %llu over 4, %llu unlisted reads; %llu boxes written",
                      static_cast<unsigned long long>(fx_started), static_cast<unsigned long long>(fx_over),
                      static_cast<unsigned long long>(fx_unlisted), static_cast<unsigned long long>(fx_written));
        event(line);
      }
    }
  }
}

State lua_state() { return lua; }

bool worker_stream() {
  if (!buffers_ready)
    return false;
  uint64_t now_us = clock_us();
  {
    std::lock_guard<std::mutex> lock(m);
    if (out_fresh) {
      std::swap(out_mid, worker_out);
      out_fresh = false;
    }
  }
  if (worker_out.size) {
    wire_send(worker_out.data.data(), worker_out.size, false, now_us);
    worker_out.size = 0;
  }
  if (recorder && (blocked || now_us - record_start_us >= kRecordUs))
    say(stop_record(blocked ? "coop off" : "120 s", now_us));
  if (blocked && replay.on())
    replay.stop();
  auto receive = [now_us](const uint8_t *data, size_t size) { wire_receive(data, size, now_us); };
  auto replay_receive = [now_us](const uint8_t *data, size_t size) { // A recording also holds the show lines.
    if (size >= 3 && !std::memcmp(data, "SBF", 3))
      pilot_in(data, size);
    else
      wire_receive(data, size, now_us);
  };
  delay_line.deliver(now_us, receive);
  replay.deliver(now_us, replay_receive);
  return loopback_on || record_on || replay.on() || peer_on; // Every 5 ms only while something streams.
}

void peer(bool linked, uint64_t now_ms, void (*send)(const uint8_t *, size_t, bool)) {
  peer_send = send;
  bool on = linked && peer_open(), was = peer_on.exchange(on);
  if (was != on)
    say(on ? "peer linked: poses and tables go over Steam" : "peer unlinked");
  if (was && !on && remote_source == kPeer)
    drop_remote(); // She left, or a loopback or replay took over.
  if (!on) {
    next_table_ms = 0;
    return;
  }
  // At once, then every 5 s: heals a table lost with a broken session, sent before her accept, or refused as too soon.
  // To her only: never looped back or recorded. She ignores an identical text.
  if (now_ms >= next_table_ms && !sent_table.empty()) {
    send(reinterpret_cast<const uint8_t *>(sent_table.data()), sent_table.size(), true);
    next_table_ms = now_ms + 5000;
  }
}

// Gated on peer_open, not peer_on: a table that follows the accept in the tick that completes the handshake comes
// before this pass's peer(), and the link already checked the handshake.
void peer_receive(const uint8_t *data, size_t size) {
  if (peer_open())
    wire_receive(data, size, clock_us());
}

std::string ask_loopback(bool on, uint32_t delay_ms, uint32_t jitter_ms, uint32_t loss_percent) {
  if (!on) { // Off works even with the engine off (after a fault).
    if (!loopback_on.exchange(false))
      return "loopback is not on";
    delay_line.set({}, 1);
    drop_remote();
    return "loopback off: the ghost goes";
  }
  if (!engine_on)
    return "loopback not started: " + status();
  if (replay.on())
    return "loopback not started while the replay runs: coop replay off first";
  LARGE_INTEGER seed;
  QueryPerformanceCounter(&seed);
  delay_line.set({delay_ms, jitter_ms, loss_percent}, uint64_t(seed.QuadPart));
  loopback_delay = delay_ms;
  loopback_jitter = jitter_ms;
  loopback_loss = loss_percent;
  ++loopback_epoch;
  bool was_on = loopback_on.exchange(true);
  if (!sent_table.empty())
    send_table(); // set() dropped what was in flight, the table with it.
  char text[200];
  std::snprintf(text, sizeof text, "loopback %s: %u ms one way, %u ms jitter, %u %% segment loss%s",
                was_on ? "settings changed" : "on", delay_ms, jitter_ms, loss_percent,
                sent_table.empty() ? ", waiting for her capture (coop puppet)" : "");
  return text;
}

std::string ask_record(bool on) {
  if (!on)
    return recorder ? stop_record("coop record off", clock_us()) : "record is not on";
  if (!engine_on)
    return "record not started: " + status();
  if (recorder)
    return "record is already on";
  if (sent_table.empty())
    return "record refused: no capture";
  recorder = std::make_unique<Recorder>();
  recorder->start(sent_table);
  record_start_us = clock_us();
  record_on = true;
  return "record on: her poses into coop-record.bin for up to 120 s (or 25 MiB), until coop record off";
}

std::string ask_replay(bool on) {
  if (!on) {
    if (!replay.on())
      return "replay is not on";
    replay.stop();
    drop_remote();
    return "replay off: the ghost goes";
  }
  if (!engine_on)
    return "replay not started: " + status();
  if (loopback_on)
    return "replay not started while the loopback runs: coop loopback off first";
  if (replay.on())
    return "replay is already on";
  bool exists = false;
  std::string file = read_file(dir + L"coop-record.bin", exists, kMaxRecording + 1);
  if (!exists)
    return "replay refused: no coop-record.bin (coop record makes one)";
  Recording r;
  if (const char *why = parse_recording(std::move(file), r))
    return std::string("replay refused: coop-record.bin fails its check (") + why + ")";
  char text[200];
  std::snprintf(text, sizeof text,
                "replay on: %zu poses, %zu tables, %zu SBE and %zu show lines, %.1f s a loop, until coop replay off",
                r.poses, r.tables, r.sbe, r.shows, double(r.end - r.first) / 1e6);
  replay.start(std::move(r), clock_us());
  return text;
}

std::string ask_nightop(bool rule, uint64_t now_ms) {
  if (!pinned) // The offsets are this build's: another one is never read.
    return "nightop poller off: " + engine_reason;
  std::string text;
  if (!nightop_on) {
    if (nightop_bytes >= kProbeCap)
      return "nightop poller off: nightop-probe.txt capped at 4 MB";
    uint64_t start_us = clock_us();
    nightop::Sample s = nightop::sample(base, rpm);
    DWORD error = GetLastError(); // The globals read is the first and, when it fails, the only one.
    uint64_t took_us = clock_us() - start_us;
    if (!s.ok)
      return "nightop poller off: ReadProcessMemory failed (error " + std::to_string(error) + ")";
    poller.start(now_ms);
    nightop_on = true;
    nightop_next = now_ms + nightop::kSampleMs;
    char head[160];
    std::snprintf(head, sizeof head, "nightop probe, StellarCoop %s, base 0x%llx; t = seconds since this line",
                  token(STELLARCOOP_VERSION).c_str(), static_cast<unsigned long long>(base));
    append_probe(head);
    for (const std::string &line : poller.step(s, now_ms))
      append_probe(line);
    // Every sample costs about this: above about 5 ms (wineserver reading through ptrace, which stops the game),
    // kSampleMs goes to 250.
    text = "nightop poller on: nightop-probe.txt every 100 ms; first sample " + std::to_string(took_us) +
           " us; spawn registry " + (s.spawn_ok ? std::to_string(s.spawnreg) : std::string("?"));
  } else if (!rule) {
    return "nightop poller already on";
  }
  if (rule) {
    if (!text.empty())
      text += "; ";
    text += poller.rule(now_ms) ? "nightop rule request: verdict in 60 s"
                                : "nightop rule already asked this run: no second verdict";
  }
  return text;
}

} // namespace coop::pose
