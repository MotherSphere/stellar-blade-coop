// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
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
     warp_fault_logged = false, zone_fault_logged = false;
int pad_logged = kPadUnread; // pad_seen as last logged.
int front_logged = -1; // Whether the game's window was in front, as last logged; -1 before the first pass.
// The follow's travel: its fault, the last ask, watch and globals logged, and the alias of the last ask (with its
// number), for the call's log line.
bool travel_fault_logged = false, travel_globals_logged = false;
bool camps_fault_logged = false; // The activated camps' read (camps_game.inc): its fault.
bool camp_text_fault_logged = false; // Matrix XIII's camp names (camp_text_game.inc): their fault.
bool uidev_fault_logged = false;     // SB's input device read (pad_game.inc): its fault.
// The New Game+ read (cycle_game.inc): its fault and its first read out of range.
bool cycle_fault_logged = false, cycle_odd_logged = false;
// Her drone (online/partner/drone_game.inc): its fault and the actor coop-drone.txt names (~0 before the first write).
bool drone_fault_logged = false;
uint64_t drone_written = ~uint64_t(0);
std::string fault_where(uint64_t rva); // fight_worker_shared.inc's, after this part: the drone's fault line.
// Her sounds and world effects (online/partner/sound_game.inc): their faults; sound_worker.inc's pass, after this part.
bool sounds_fault_logged = false, worldfx_fault_logged = false;
bool faces_fault_logged = false; // Her face and shape keys (online/partner/pose_game.inc): their fault.
bool push_fault_logged = false;  // Enemies out of a shown ghost (fight/enemies/push_game.inc): its fault.
void sound_pass(bool sounds);
uint32_t travel_logged = 0, travel_watch_logged = 0, travel_alias_ask = 0;
std::string travel_alias;
uint64_t next_poll = 0, next_counters = 0;
uint64_t vitals_reads = 0, vitals_max_us = 0; // local_vitals()'s, for the 60 s line.
// The gap lines: at most kGapLines between two 60 s lines, which count every gap anyway, so a long load (each of its
// frames a gap) cannot fill the log. vkd3d-proton writes its new pipelines to vkd3d-proton.cache.write beside the
// game's exe (under Proton; no such file on Windows): its size at the last gap line, or at the worker's first pass.
// A save load, its warp and a hall's arrival logged 25 gaps in 64 s; 600 at most fit a minute.
constexpr int kGapLines = 200;
int gap_lines = 0;
std::wstring cache_path;
uint64_t cache_bytes = 0;

void log_gap(const Gap &g) {
  if (gap_lines > kGapLines)
    return;
  if (gap_lines++ == kGapLines) {
    say("gap lines: " + std::to_string(kGapLines) + " since the last native tick line, no more until the next one");
    return;
  }
  const twins::Stat cache = sbo_stat(cache_path);
  int64_t grew = -1;
  if (cache.exists) { // A smaller file is a new one: all of it is new.
    grew = int64_t(cache.size >= cache_bytes ? cache.size - cache_bytes : cache.size);
    cache_bytes = cache.size;
  }
  say(gap_line(g.filetime, g.gap_us, g.frame, g.tick_us, grew));
}
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
// EVE's capture (Lua's file) and the wire text sent for it. Each *_text is the file or message as last taken; "\x01" is
// never equal to a real one, so the next one is taken whatever it is.
Table capture;
std::string session_text, capture_text = "\x01", sent_table;
const char kPeer[] = "peer";
// One per ghost slot (link/peer.h's Peer::slot), with its own files (game/core.h's slot_file): the remote table from
// the wire and its text, written to the slot's coop-remote file (count times so far, by its source; unwritten: the
// write failed, Lua had the file open, and is tried again at each pass); the ghost Lua built for it from the slot's
// coop-display file, as last taken; renewal_us: when its last new ghost was taken. The loopback and the replay feed
// slot 0 only.
struct Remote {
  Table table;
  Display display;
  std::string text, display_text = "\x01";
  bool unwritten = false;
  uint64_t count = 0, renewal_us = 0;
  const char *source = kPeer;
};
std::array<Remote, kMaxRemote> remotes;
void (*peer_send)(const uint8_t *, size_t, bool) = nullptr; // Set by peer() each pass, before peer_on can be true.
uint8_t peer_slots = 0;   // The slots linked as peer() last had them (none while off).
TableResend table_resend; // Our table's resends to the linked members, all at once.
// Link::pose_cap() as peer() last had it (60, the highest send_rate: none): the send interval is under it and the rate.
uint32_t link_cap = 60;
// Night Operation probe (Phase 6): read-only, its own latch (pinned && !blocked), so a pose fault leaves it running.
bool pinned = false, nightop_on = false;
// pinned for the game thread's pause, pilot, quest, revive and travel calls; each keeps its own *_faulted latch.
std::atomic<bool> game_pinned{false};
nightop::Poller poller;
uint64_t nightop_next = 0;
size_t nightop_bytes = 0;
constexpr size_t kProbeCap = 4 << 20; // About 30 min of lines at 10 a second (a field flickering every sample).
// A slot's file in the mod folder (its name is ASCII), and the slot for the log lines: none for slot 0, whose lines
// read as they did with one friend.
std::wstring slot_path(const char *stem, size_t slot) {
  const std::string name = slot_file(stem, slot);
  return dir + std::wstring(name.begin(), name.end());
}
std::string slot_tag(size_t slot) { return slot ? " in slot " + std::to_string(slot) : std::string(); }
// ReadProcessMemory fails on unmapped memory instead of faulting, and never trips a guard page.
bool rpm(uint64_t address, void *out, size_t n) {
  SIZE_T got = 0;
  return ReadProcessMemory(GetCurrentProcess(), reinterpret_cast<LPCVOID>(address), out, n, &got) && got == n;
}
// The shared fight's worker side (fight/enemies/engine.h's Worker), with channel 2 as the last fight_pass gave it.
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

// Bytes onto a file of the mod folder, shared for delete too (it may be read or moved while open); whether all went.
bool append_file(const wchar_t *name, const std::string &text) {
  HANDLE f = CreateFileW((dir + name).c_str(), FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                         nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return false;
  DWORD n = 0;
  const bool ok = WriteFile(f, text.data(), static_cast<DWORD>(text.size()), &n, nullptr) && n == text.size();
  CloseHandle(f);
  return ok;
}

// Her asset names per ghost slot (game/events.h's SBA lines): the lines taken this link session by key; how far the
// slot's coop-loaded file was read. Counted for the 60 s line: lines taken; lines refused (a bad line, no slot,
// another line for a key already named, the coop-names file not written); loaded lines taken; loaded lines refused (a
// bad line, a key the slot never named).
struct AssetNames {
  std::unordered_map<uint16_t, std::string> lines;
  uint64_t loaded_at = 0;
};
std::array<AssetNames, kMaxRemote> asset_names;
uint64_t names_in = 0, names_refused = 0, loaded_in = 0, loaded_refused = 0;
constexpr size_t kLoadedBytes = 64 << 10; // Read at most a pass: about 800 lines.

// A file's bytes from offset on, kLoadedBytes at most; size: the file's size, 0 when there is none.
std::string read_from(const std::wstring &path, uint64_t offset, uint64_t &size) {
  size = 0;
  HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
                         OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (f == INVALID_HANDLE_VALUE)
    return {};
  std::string text;
  LARGE_INTEGER bytes{}, at{};
  at.QuadPart = static_cast<LONGLONG>(offset);
  if (GetFileSizeEx(f, &bytes) && (size = static_cast<uint64_t>(bytes.QuadPart)) > offset &&
      SetFilePointerEx(f, at, nullptr, FILE_BEGIN)) {
    text.resize(static_cast<size_t>(std::min<uint64_t>(size - offset, kLoadedBytes)));
    DWORD n = 0;
    text.resize(ReadFile(f, text.data(), static_cast<DWORD>(text.size()), &n, nullptr) ? n : 0);
  }
  CloseHandle(f);
  return text;
}

// Every 250 ms: the slot's coop-loaded file from where it was last read, whole lines only, into the game thread's
// asset_loaded in place (no rebuild(), which would restart every playback); a later line for a key replaces the
// earlier one. A file shorter than that, or gone, was started again by Lua: the slot's loaded objects go and the file
// is read from 0.
void read_loaded(size_t slot) {
  AssetNames &names = asset_names[slot];
  if (names.lines.empty() && !names.loaded_at)
    return;
  const std::wstring path = slot_path("coop-loaded", slot);
  uint64_t size = 0;
  std::string text = read_from(path, names.loaded_at, size);
  const bool shorter = size < names.loaded_at;
  if (shorter) {
    names.loaded_at = 0;
    text = read_from(path, 0, size);
  }
  const size_t whole = text.rfind('\n') + 1; // 0 with no newline: a line still being written waits.
  text.resize(whole);
  names.loaded_at += whole;
  std::vector<Loaded> got;
  parse_loaded(text, got);
  loaded_refused += static_cast<uint64_t>(std::count(text.begin(), text.end(), '\n')) - got.size();
  std::vector<Named> named; // Each with the int parameters the slot's line for its key names.
  for (const Loaded &l : got) {
    const auto line = names.lines.find(l.k);
    const auto parsed = line == names.lines.end() ? std::nullopt : parse_asset_line(line->second);
    if (!parsed) {
      ++loaded_refused;
      continue;
    }
    Named &n = named.emplace_back();
    n.loaded = l;
    n.kind = parsed->kind;
    n.path[0] = parsed->asset;
    n.path[1] = parsed->a == "-" ? std::string() : parsed->a;
    n.path[2] = parsed->b == "-" ? std::string() : parsed->b;
    for (const Param &p : parsed->params) { // At most kMaxParams words of 1 to kMaxWord bytes (parse_asset_line).
      std::memcpy(n.param_name[n.params], p.name.data(), p.name.size());
      n.param_value[n.params++] = p.value;
    }
  }
  std::lock_guard<std::mutex> lock(m);
  if (shorter)
    asset_loaded[slot].clear();
  for (const Named &n : named)
    asset_loaded[slot].insert_or_assign(n.loaded.k, n);
  loaded_in += named.size();
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
  std::string text = stamp + coop::masked(line) + "\r\n"; // Masked as coop-link.log is: bug reports bring these too.
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

// The game thread's next Live from the worker's tables. Only when the capture generation, a slot's remote generation
// or a ghost changes: a new Live starts every ghost's playback again.
// ponytail: a new Live also forgets her keyframe, so her deltas are dropped as keyless until her next one: up to 250 ms
// frozen plus the playback's refill. A new capture generation (our outfit; hers in loopback) does so too while her
// table and ghost stay; carry the playback and the decoder across then, if T4 shows it.
// shortcut: a change on one slot rebuilds every ghost's playback (each waits up to 250 ms for a keyframe); hand over
// one slot at a time if the 3+ PC test shows the hitch.
void rebuild() {
  auto next = std::make_unique<Live>(capture);
  bool any = capture.generation;
  for (size_t k = 0; k < kMaxRemote; ++k) {
    const Remote &r = remotes[k];
    if (!r.table.generation)
      continue;
    next->remotes[k] =
        std::make_unique<Drawn>(r.table, r.display.generation == r.table.generation ? r.display : Display());
    any = true;
  }
  hand_over(any ? std::move(next) : nullptr);
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

void write_remote(size_t slot) {
  Remote &r = remotes[slot];
  if (r.unwritten && write_text(slot_path("coop-remote", slot), r.text)) {
    r.unwritten = false;
    ++r.count; // Lua reads the file again when the count in the status changes.
  }
}

// One note a run: value lines (game/table.h) left out of a table. They cost a colour, never the table.
void note_ignored(const Table &t) {
  static bool said = false;
  if (t.ignored && !said) {
    said = true;
    say(std::to_string(t.ignored) + " value lines ignored in a component table (said once a run)");
  }
}

// A table from the wire for a ghost slot: refused whole, or the same as the slot's (sent again), or its new remote
// table, in its canonical form for Lua. A new generation, or another layout under the same one, waits for Lua's new
// ghost; else it is a part hung elsewhere or shown or hidden, which Lua applies to the ghost it has.
void take_table(size_t slot, const uint8_t *data, size_t size) {
  ++window_tables_in;
  auto t = parse_table(std::string(reinterpret_cast<const char *>(data), size), false);
  if (!t) {
    ++window_tables_refused;
    say("remote table refused" + slot_tag(slot) + ": malformed");
    return;
  }
  note_ignored(*t);
  Remote &r = remotes[slot];
  std::string text = format_table(*t);
  if (text == r.text)
    return;
  bool renewed = t->generation != r.table.generation || !same_layout(*t, r.table);
  const char *source = replay.on() ? "replay" : loopback_on ? "loopback" : kPeer; // The sources exclude each other.
  // ROADMAP 4.7: one new ghost per 2 s from her at most (a LoadAsset hitch and new FNames each); her resend 5 s after
  // her last change brings the newest table later.
  uint64_t now = clock_us();
  if (renewed && source == kPeer && now - r.renewal_us < 2'000'000) {
    ++window_tables_refused;
    return;
  }
  if (renewed)
    r.renewal_us = now;
  r.table = std::move(*t);
  r.text = std::move(text);
  r.source = source;
  r.unwritten = true;
  write_remote(slot);
  say("remote table " + std::to_string(r.table.generation) + (renewed ? " from the " : " again from the ") + r.source +
      slot_tag(slot) + ": " + std::to_string(r.table.eve.size()) + " parts, map " + r.table.map);
  if (!renewed)
    return;
  r.display = Display();
  r.display_text = "\x01";
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

// The only way in, for one ghost slot: a table to take_table, a pose or a delta of this protocol to the game thread's
// inbox, an SBE from slot 0 to the drawn side, anything else counted. Same-place enemies run with the co-op partner
// only, who holds slot 0, so an SBE from another slot is dropped. Show lines are channel 2's text: hers come through
// pilot_pass, a recording's through replay_receive.
void wire_receive(size_t slot, const uint8_t *data, size_t size, uint64_t now_us) {
  if (size >= 3 && !std::memcmp(data, "SBE", 3)) {
    if (slot == 0)
      pilot_in(data, size);
  } else if (size >= 3 && !std::memcmp(data, "SBT", 3)) {
    take_table(slot, data, size);
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
    in.slot = static_cast<uint8_t>(slot);
  } else {
    ++window_malformed;
  }
}

// A slot's remote table is gone with its source (loopback off, replay off, her unlink or leave): so is her ghost.
void drop_remote(size_t slot) {
  Remote &r = remotes[slot];
  if (!r.table.generation)
    return;
  r.table = Table();
  r.text.clear();
  r.unwritten = false;
  r.display = Display();
  r.display_text = "\x01";
  DeleteFileW(slot_path("coop-remote", slot).c_str());
  rebuild();
}

// coop-components.txt, when it changed: EVE's capture, sent on whenever its wire form changes (a part hung elsewhere
// keeps the generation and the Live), with its next resend to the friend 5 s later (peer() starts over for a friend
// not linked yet); a new generation, or none, is a new Live.
void take_capture(uint64_t now_ms) {
  bool exists = false;
  std::string text = read_file(dir + L"coop-components.txt", exists, kMaxTable);
  if (text == capture_text)
    return;
  capture_text = text;
  Table t;
  if (!text.empty()) {
    if (auto got = parse_table(text, true)) {
      note_ignored(*got);
      t = std::move(*got);
    } else
      say("component table refused: malformed");
  }
  bool renewed = t.generation != capture.generation;
  if (fx_handover(capture, t)) {
    std::lock_guard<std::mutex> lock(m);
    fx_incoming = t.fx, fx_incoming_generation = t.generation, fx_incoming_set = true;
  }
  capture = std::move(t);
  std::string wire = capture.generation ? format_table(capture) : std::string();
  if (wire != sent_table) {
    sent_table = std::move(wire);
    if (!sent_table.empty()) {
      send_table();
      table_resend.changed(now_ms);
    }
  }
  if (!renewed)
    return;
  say(capture.generation ? "component table " + std::to_string(capture.generation) + ": " +
                               std::to_string(capture.eve.size()) + " parts"
                         : std::string("component table withdrawn"));
  rebuild();
}

// A slot's coop-display file, when it changed: the ghost Lua built for the slot's remote table, or none. Read only
// while the slot holds a table.
void take_display(size_t slot) {
  Remote &r = remotes[slot];
  bool exists = false;
  std::string text = read_file(slot_path("coop-display", slot), exists, kMaxTable);
  if (text == r.display_text)
    return;
  r.display_text = text;
  Display d;
  if (auto got = parse_display(text, r.table)) {
    d = std::move(*got);
    int leaders = 0, drawn = 0, mapped = 0;
    for (size_t i = 0; i < r.table.eve.size(); ++i) {
      leaders += r.table.eve[i].leader;
      drawn += d.puppet[i].object != 0;
      mapped += !d.remap[i].empty();
    }
    char line[200], boxes[32] = "";
    if (d.effects[0])
      std::snprintf(boxes, sizeof boxes, ", %zu effect boxes", kEffectSlots);
    std::snprintf(line, sizeof line, "ghost of table %llu%s drawn: %d of %d leaders (%d on a fallback mesh), %zu "
                  "bytes a pose%s", static_cast<unsigned long long>(d.generation), slot_tag(slot).c_str(), drawn,
                  leaders, mapped, pose_size(r.table), boxes);
    say(line);
  } else if (r.table.generation && text.rfind("display " + std::to_string(r.table.generation) + "\n", 0) == 0) {
    say("ghost of table " + std::to_string(r.table.generation) + slot_tag(slot) +
        " refused: its display file is malformed");
  } // Else none yet, or an older table's, which Lua replaces.
  if (!d.generation && !r.display.generation)
    return;
  r.display = std::move(d);
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
    wchar_t exe[MAX_PATH];
    const DWORD exe_length = GetModuleFileNameW(nullptr, exe, MAX_PATH);
    const std::wstring exe_path(exe, exe_length && exe_length < MAX_PATH ? exe_length : 0);
    if (const size_t slash = exe_path.find_last_of(L"\\/"); slash != std::wstring::npos) {
      cache_path = exe_path.substr(0, slash + 1) + L"vkd3d-proton.cache.write";
      cache_bytes = sbo_stat(cache_path).size; // The first gap line's growth: since this pass.
    }
    std::string reason;
    if (!pin(reason))
      reason = "fault while reading the exe header";
    objects = base + kObjectsRva; // Before engine_on: the game thread reads it once the engine is on.
    safe_read = rpm;              // The same: alive() reads a table's object through it, never directly.
    engine_reason = reason.empty() ? "pinned build 26123051" : reason;
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
  // Each change of the pads coop_pad sees through XInput, so a test's log says whether the pad is read; none while
  // the game's own controller events are the source (pad_worker.inc).
  if (const int seen = pad_seen; !pad_slate && seen != pad_logged) {
    pad_logged = seen;
    std::string line = "pad: no XInput pad";
    if (seen == kPadMissing)
      line = "pad: no XInput in System32: the controller works only through Slate's handler";
    else if (seen > 0) {
      line = "pad: XInput pads connected:";
      for (int slot = 0; slot < 4; ++slot)
        if (seen & (1 << slot))
          line += " " + std::to_string(slot);
    }
    event(line);
  }
  // Each change of the window in front, at every pass: an alt-tab or a screenshot tool taking the foreground shows in
  // the log next to the focus watchdog's lines. poll_pad's owner test, which it skips with neither XInput nor the hooks.
  DWORD owner = 0;
  if (const int front = GetWindowThreadProcessId(GetForegroundWindow(), &owner) && owner == GetCurrentProcessId();
      front != front_logged) {
    front_logged = front;
    event(front ? "window: the game is in front" : "window: another window is in front");
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
  if (zone_faulted && !zone_fault_logged) {
    zone_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "zone row read off for this run: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; the "
                  "vitals carry zone type 0",
                  static_cast<unsigned long long>(zone_fault_code.load()),
                  static_cast<unsigned long long>(zone_fault_rva.load()),
                  static_cast<unsigned long long>(zone_fault_address.load()));
    event(text);
  }
  { // The warp read's lines: the zone type's changes, the area's disagreements, each start of a zone reset.
    std::vector<std::string> lines;
    {
      std::lock_guard<std::mutex> lock(warp_text_m);
      lines.swap(warp_text.lines);
    }
    for (const std::string &line : lines)
      event(line);
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
  if (camps_faulted && !camps_fault_logged) {
    camps_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "camps read off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; coop travel probe and coop "
                  "mxiii leave refused until the game restarts",
                  static_cast<unsigned long long>(camps_fault_code.load()),
                  static_cast<unsigned long long>(camps_fault_rva.load()),
                  static_cast<unsigned long long>(camps_fault_address.load()));
    event(text);
  }
  if (camp_text_faulted && !camp_text_fault_logged) {
    camp_text_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "camp names off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; the Matrix XIII camps keep "
                  "the names they show until the game restarts",
                  static_cast<unsigned long long>(camp_text_fault_code.load()),
                  static_cast<unsigned long long>(camp_text_fault_rva.load()),
                  static_cast<unsigned long long>(camp_text_fault_address.load()));
    event(text);
  }
  if (uidev_faulted && !uidev_fault_logged) {
    uidev_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "input device read off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; no uidev line "
                  "until the game restarts",
                  static_cast<unsigned long long>(uidev_fault_code.load()),
                  static_cast<unsigned long long>(uidev_fault_rva.load()),
                  static_cast<unsigned long long>(uidev_fault_address.load()));
    event(text);
  }
  if (cycle_faulted && !cycle_fault_logged) {
    cycle_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "New Game+ read off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; the cycle line keeps "
                  "its last read until the game restarts",
                  static_cast<unsigned long long>(cycle_fault_code.load()),
                  static_cast<unsigned long long>(cycle_fault_rva.load()),
                  static_cast<unsigned long long>(cycle_fault_address.load()));
    event(text);
  }
  if (drone_faulted && !drone_fault_logged) {
    drone_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "drone off: fault 0x%08llx in %s reading 0x%llx; the ghost goes on without her drone",
                  static_cast<unsigned long long>(drone_fault_code.load()), fault_where(drone_fault_rva).c_str(),
                  static_cast<unsigned long long>(drone_fault_address.load()));
    event(text);
  }
  if (push_faulted && !push_fault_logged) {
    push_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "enemy contact off: fault 0x%08llx in %s reading 0x%llx; enemies go through the ghost again, the "
                  "ghost and the shared fight go on",
                  static_cast<unsigned long long>(push_fault_code.load()), fault_where(push_fault_rva).c_str(),
                  static_cast<unsigned long long>(push_fault_address.load()));
    event(text);
  }
  if (sounds_faulted && !sounds_fault_logged) {
    sounds_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "sounds off: fault 0x%08llx in %s reading 0x%llx; her sounds' slots go back, the ghost goes on "
                  "without them",
                  static_cast<unsigned long long>(sounds_fault_code.load()), fault_where(sounds_fault_rva).c_str(),
                  static_cast<unsigned long long>(sounds_fault_address.load()));
    event(text);
  }
  if (worldfx_faulted && !worldfx_fault_logged) {
    worldfx_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "world effects off: fault 0x%08llx in %s reading 0x%llx; their slots go back, the ghost goes on "
                  "without them",
                  static_cast<unsigned long long>(worldfx_fault_code.load()), fault_where(worldfx_fault_rva).c_str(),
                  static_cast<unsigned long long>(worldfx_fault_address.load()));
    event(text);
  }
  if (faces_faulted && !faces_fault_logged) {
    faces_fault_logged = true;
    char text[200];
    std::snprintf(text, sizeof text,
                  "faces off: fault 0x%08llx in %s reading 0x%llx; the ghost goes on without her face and shape keys",
                  static_cast<unsigned long long>(faces_fault_code.load()), fault_where(faces_fault_rva).c_str(),
                  static_cast<unsigned long long>(faces_fault_address.load()));
    event(text);
  }
  // coop-drone.txt for the capture, written only when the actor changes (none after coop off); a failed write is tried
  // again at the next pass.
  if (const uint64_t actor = blocked ? 0 : drone_actor.load(); actor != drone_written) {
    char text[40] = "drone none\n";
    if (actor)
      std::snprintf(text, sizeof text, "drone 0x%llx\n", static_cast<unsigned long long>(actor));
    if (write_text(dir + L"coop-drone.txt", text))
      drone_written = actor;
  }
  if (cycle_odd && !cycle_odd_logged) {
    cycle_odd_logged = true;
    char text[160];
    std::snprintf(text, sizeof text,
                  "New Game+ read refused: count %d, difficulty %d (0 to 99 and 0 to 2 expected); the cycle line keeps "
                  "its last good read",
                  int(cycle_odd_count.load()), int(cycle_odd_difficulty.load()));
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
    if ((done >> 24) & 1) // A spot warp: alias holds the place.
      event(why == travel::Why::none ? "travel spot call " + alias + " ret=" + std::to_string(done & 0xff) +
                                           " other=" + std::to_string((done >> 8) & 0xff)
                                     : std::string("travel spot refused: ") + travel::why_name(why));
    else
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
  for (size_t k = 0; k < kMaxRemote; ++k) {
    write_remote(k);
    if (remotes[k].table.generation && remotes[k].display.generation != remotes[k].table.generation)
      take_display(k); // At every pass while the ghost for the slot's remote table is awaited.
  }
  if (now_ms < next_poll)
    return;
  next_poll = now_ms + 250;
  bool exists = false;
  std::string token = read_file(folder + L"coop-session.txt", exists, kMaxTable);
  if (exists && token != session_text) { // A new Lua load: what an older one published is stale.
    session_text = token;
    capture = Table();
    for (Remote &r : remotes)
      r.display = Display(), r.display_text = "\x01";
    sent_table.clear();
    capture_text = "\x01";
    rebuild();
    ++freeze_unsure; // Our pause tag is removed unless it is still wanted.
    debug_asks.asked = 0; // And SB's developer gates go back to the game's values.
    anim_drop = true;     // And a clip an earlier load played on EVE stops.
    bike_want(false);     // And SB's actions an earlier load turned off for the bike come back.
    race_want_fields = race_want_tick = false; // And the race's kept values on EVE go back (online/modes/race/).
    event("new Lua session: capture and ghost dropped");
  }
  take_capture(now_ms);
  for (size_t k = 0; k < kMaxRemote; ++k) {
    if (remotes[k].table.generation)
      take_display(k);
    read_loaded(k);
  }
  // A missing or bad file keeps the previous values: Lua's put() removes the old file before it renames the new one in,
  // so the worker can find none in between.
  if (State now; parse_state(read_file(folder + L"coop-state.txt", exists, kMaxState), now)) {
    if (now.rate != lua.rate) {
      send_us = 1'000'000 / std::min(now.rate, link_cap);
      event("send rate " + std::to_string(now.rate) + " poses a second");
    }
    lua = now;
  }
  sound_pass(lua.sounds); // Her sounds' and world effects' slots, by their looks; back after a fault.
  push_wanted = lua.collide; // Enemies out of a shown ghost (fight/enemies/push_game.inc).
  {
    std::vector<std::string> lines;
    std::array<Gap, 8> long_gaps;
    size_t gap_n = 0;
    {
      std::lock_guard<std::mutex> lock(m);
      lines.swap(outbox);
      long_gaps = gaps;
      std::swap(gap_n, gap_count);
    }
    for (auto &line : lines)
      event(line);
    for (size_t i = 0; i < gap_n; ++i)
      log_gap(long_gaps[i]);
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
    const uint64_t mark = window_sound_mark.exchange(0), owner = window_sound_owner.exchange(0),
                   attach = window_sound_attach.exchange(0), other = window_sound_other.exchange(0),
                   sound_sent = window_sound_sent.exchange(0), waited = window_sound_dropped.exchange(0),
                   paths = window_sound_paths.exchange(0), left_out = window_sound_left_out.exchange(0),
                   keys = window_sound_keys.exchange(0), ring = window_sound_ring.exchange(0);
    const uint64_t played = window_play_played.exchange(0), play_far = window_play_far.exchange(0),
                   play_ghost = window_play_ghost.exchange(0), play_all = window_play_all.exchange(0),
                   play_scene = window_play_scene.exchange(0), play_hidden = window_play_hidden.exchange(0),
                   play_unnamed = window_play_unnamed.exchange(0), play_unloaded = window_play_unloaded.exchange(0),
                   play_looping = window_play_looping.exchange(0);
    const uint64_t fx_mark = window_worldfx_mark.exchange(0), fx_owner = window_worldfx_owner.exchange(0),
                   fx_attach = window_worldfx_attach.exchange(0), fx_other = window_worldfx_other.exchange(0),
                   fx_skipped = window_worldfx_attached.exchange(0), fx_sent = window_worldfx_sent.exchange(0),
                   fx_paths = window_worldfx_paths.exchange(0), fx_keys = window_worldfx_keys.exchange(0),
                   fx_played = window_worldfx_played.exchange(0), fx_unspawned = window_worldfx_unspawned.exchange(0),
                   fx_hidden = window_worldfx_hidden.exchange(0), fx_scene = window_worldfx_scene.exchange(0),
                   fx_unnamed = window_worldfx_unnamed.exchange(0), fx_unloaded = window_worldfx_unloaded.exchange(0);
    const uint64_t push_moves = window_push_moves.exchange(0), push_copies = window_push_copies.exchange(0),
                   push_refused = window_push_refused.exchange(0), push_held = window_push_held.exchange(0),
                   push_unread = window_push_unread.exchange(0), push_capped = window_push_capped.exchange(0);
    const uint64_t faces_read = window_faces_read.exchange(0), faces_clamped = window_faces_clamped.exchange(0),
                   faces_written = window_faces_written.exchange(0), faces_dirty = window_faces_dirty.exchange(0),
                   faces_refused = window_faces_refused.exchange(0);
    if (!first && vitals_reads) { // Eight ReadProcessMemory calls each; the cost under Proton is unmeasured.
      char line[96];
      std::snprintf(line, sizeof line, "vitals read, last 60 s: %llu reads, max %llu us",
                    static_cast<unsigned long long>(vitals_reads), static_cast<unsigned long long>(vitals_max_us));
      event(line);
    }
    vitals_reads = vitals_max_us = 0;
    gap_lines = 0;
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
                      "stream, last 60 s: %llu sent (%.1f a second, link cap %u, %llu bytes each, %.1f KB/s, %llu "
                      "values cut, %llu reads refused; %llu keyframes, %llu deltas of %llu bytes each, %llu frames "
                      "held for the byte budget), %llu lost on the line, %llu over the inbox; tables: %llu in, %llu refused; "
                      "poses: %llu received, %llu foreign, %llu malformed, %llu rejected (last: %s), %llu keyless, "
                      "%llu stale, %llu missing, %llu stalls, %llu clock steps, one way %.1f ms; %llu drawn, %llu past "
                      "the newest pose, %.1f ms behind it; %llu written, %llu not written (last: %s)",
                      static_cast<unsigned long long>(sent), sent / 60.0, unsigned(link_cap),
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
                      "effects, last 60 s: %llu started, %llu over %zu, %llu unlisted reads; %llu boxes written",
                      static_cast<unsigned long long>(fx_started), static_cast<unsigned long long>(fx_over),
                      kEffectSlots, static_cast<unsigned long long>(fx_unlisted),
                      static_cast<unsigned long long>(fx_written));
        event(line);
      }
      if (mark || owner || attach || other || sound_sent || waited || paths || left_out || keys || ring) {
        std::snprintf(line, sizeof line,
                      "sounds, last 60 s: captured %llu (mark %llu, owner %llu, attach %llu, other thread %llu), sent "
                      "%llu, %llu events dropped waiting for a slot, %llu paths refused, %llu params left out, %llu "
                      "over %zu keys, %llu events lost to a full ring",
                      static_cast<unsigned long long>(mark + owner + attach), static_cast<unsigned long long>(mark),
                      static_cast<unsigned long long>(owner), static_cast<unsigned long long>(attach),
                      static_cast<unsigned long long>(other), static_cast<unsigned long long>(sound_sent),
                      static_cast<unsigned long long>(waited), static_cast<unsigned long long>(paths),
                      static_cast<unsigned long long>(left_out), static_cast<unsigned long long>(keys),
                      kMaxAssetKeys, static_cast<unsigned long long>(ring));
        event(line);
      }
      if (played || play_far || play_ghost || play_all || play_scene || play_hidden || play_unnamed || play_unloaded ||
          play_looping) {
        std::snprintf(line, sizeof line,
                      "sounds played, last 60 s: %llu played, %llu far, %llu over a ghost's %zu, %llu over all %zu, "
                      "%llu in a scene, %llu from a hidden ghost, %llu without a name, %llu not loaded, %llu looping",
                      static_cast<unsigned long long>(played), static_cast<unsigned long long>(play_far),
                      static_cast<unsigned long long>(play_ghost), kPerGhost, static_cast<unsigned long long>(play_all),
                      kAll, static_cast<unsigned long long>(play_scene), static_cast<unsigned long long>(play_hidden),
                      static_cast<unsigned long long>(play_unnamed), static_cast<unsigned long long>(play_unloaded),
                      static_cast<unsigned long long>(play_looping));
        event(line);
      }
      if (fx_mark || fx_owner || fx_attach || fx_other || fx_skipped || fx_sent || fx_paths || fx_keys || fx_played ||
          fx_unspawned || fx_hidden || fx_scene || fx_unnamed || fx_unloaded) {
        std::snprintf(line, sizeof line,
                      "world effects, last 60 s: captured %llu (mark %llu, owner %llu, attach %llu, other thread "
                      "%llu), sent %llu, %llu attached skipped, %llu paths refused, %llu over %zu keys; played %llu, "
                      "%llu not spawned, %llu from a hidden ghost, %llu in a scene, %llu without a name, %llu not "
                      "loaded",
                      static_cast<unsigned long long>(fx_mark + fx_owner + fx_attach),
                      static_cast<unsigned long long>(fx_mark), static_cast<unsigned long long>(fx_owner),
                      static_cast<unsigned long long>(fx_attach), static_cast<unsigned long long>(fx_other),
                      static_cast<unsigned long long>(fx_sent), static_cast<unsigned long long>(fx_skipped),
                      static_cast<unsigned long long>(fx_paths), static_cast<unsigned long long>(fx_keys),
                      kMaxAssetKeys, static_cast<unsigned long long>(fx_played),
                      static_cast<unsigned long long>(fx_unspawned), static_cast<unsigned long long>(fx_hidden),
                      static_cast<unsigned long long>(fx_scene), static_cast<unsigned long long>(fx_unnamed),
                      static_cast<unsigned long long>(fx_unloaded));
        event(line);
      }
      if (faces_read || faces_clamped || faces_written || faces_dirty || faces_refused) {
        std::snprintf(line, sizeof line,
                      "faces, last 60 s: %llu parts read, %llu clamped, %llu written, %llu dirty calls, %llu refused",
                      static_cast<unsigned long long>(faces_read), static_cast<unsigned long long>(faces_clamped),
                      static_cast<unsigned long long>(faces_written), static_cast<unsigned long long>(faces_dirty),
                      static_cast<unsigned long long>(faces_refused));
        event(line);
      }
      if (push_moves || push_copies || push_refused || push_held || push_unread || push_capped) {
        std::snprintf(line, sizeof line,
                      "enemy contact, last 60 s: %llu pushes, %llu copies left alone, %llu refused by SB's rules, %llu "
                      "frames held (paused, scene, hidden), %llu not read, %llu over %zu a frame",
                      static_cast<unsigned long long>(push_moves), static_cast<unsigned long long>(push_copies),
                      static_cast<unsigned long long>(push_refused), static_cast<unsigned long long>(push_held),
                      static_cast<unsigned long long>(push_unread), static_cast<unsigned long long>(push_capped),
                      kPushLooks);
        event(line);
      }
      if (names_in || names_refused || loaded_in || loaded_refused) {
        std::snprintf(line, sizeof line,
                      "asset names, last 60 s: %llu taken, %llu refused; %llu loaded lines taken, %llu refused",
                      static_cast<unsigned long long>(names_in), static_cast<unsigned long long>(names_refused),
                      static_cast<unsigned long long>(loaded_in), static_cast<unsigned long long>(loaded_refused));
        event(line);
      }
    }
    names_in = names_refused = loaded_in = loaded_refused = 0;
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
  // The loopback and the replay are the single remote source they were with one friend: slot 0.
  auto receive = [now_us](const uint8_t *data, size_t size) { wire_receive(0, data, size, now_us); };
  auto replay_receive = [now_us](const uint8_t *data, size_t size) { // A recording also holds the show lines.
    if (size >= 3 && !std::memcmp(data, "SBF", 3))
      pilot_in(data, size);
    else
      wire_receive(0, data, size, now_us);
  };
  delay_line.deliver(now_us, receive);
  replay.deliver(now_us, replay_receive);
  return loopback_on || record_on || replay.on() || peer_on; // Every 5 ms only while something streams.
}

void peer(uint8_t slots, uint64_t now_ms, void (*send)(const uint8_t *, size_t, bool), uint32_t cap) {
  peer_send = send;
  if (cap != link_cap) { // Logged by the link, with its reason.
    link_cap = cap;
    send_us = 1'000'000 / std::min(lua.rate, cap);
  }
  bool on = slots && peer_open(), was = peer_on.exchange(on);
  if (was != on)
    say(on ? "peer linked: poses and tables go over Steam" : "peer unlinked");
  // A slot whose bit is clear keeps no member's table: she left, or a loopback or replay took over. Her table can only
  // have come while her bit was set: the link hands channel 1 on from members past the handshake only, in the tick
  // that runs before this call.
  const uint8_t bits = on ? slots : 0, added = static_cast<uint8_t>(bits & ~peer_slots);
  peer_slots = bits;
  for (size_t k = 0; k < kMaxRemote; ++k)
    if (!(bits >> k & 1) && remotes[k].source == kPeer)
      drop_remote(k);
  if (!on)
    return;
  // At once to a new member, whatever take_capture or peer_receive planned while she was not linked (a capture change
  // in the pass that completes the handshake went before her), and so to every member: one table goes to all.
  if (added)
    table_resend = TableResend();
  // At once, then 5, 10, 20, 40 and 60 s apart (game/table.h TableResend). To them only: never looped back or recorded.
  if (!sent_table.empty() && table_resend.due(now_ms))
    send(reinterpret_cast<const uint8_t *>(sent_table.data()), sent_table.size(), true);
}

void table_again() { table_resend = TableResend(); }

std::vector<std::string> asset_lines(bool linked) {
  std::vector<std::string> lines;
  {
    std::lock_guard<std::mutex> lock(m);
    lines.swap(asset_named);
  }
  // A solo test hears the loopback ghost; a replay stays silent (names are not recorded). Not in a link session: our
  // keys in slot 0 would refuse the same keys of the member whose names it holds, after the loopback too.
  if (loopback_on && !linked)
    for (const std::string &line : lines)
      asset_line_in(0, line);
  return lines;
}

// Into the slot's table by key (take_name) and its coop-names file as "name <k> ...". asset_slot_reset() empties the
// table when the slot's member changes.
void asset_line_in(size_t slot, const std::string &line) {
  const Taken taken = slot < kMaxRemote ? take_name(asset_names[slot].lines, line) : Taken::refused;
  if (taken == Taken::refused)
    ++names_refused;
  if (taken != Taken::fresh)
    return;
  const std::string name = slot_file("coop-names", slot);
  if (append_file(std::wstring(name.begin(), name.end()).c_str(), "name" + line.substr(asset_tag().size()) + "\n"))
    ++names_in;
  else
    ++names_refused;
}

void asset_keys_clear() {
  std::lock_guard<std::mutex> lock(m);
  asset_named.clear();
  asset_keys_reset = true;
}

// A reset slot's coop-names file starts again with a head line, "book <n>", n new at each reset of the run (the Steam
// worker removes a previous run's files when it starts, glue/steam.cpp). Lua reads the file from its last offset: the
// head tells it the file was started again even when the new one is already longer than that offset (core/link.lua's
// names()).
uint64_t asset_books = 0;
void asset_slot_reset(size_t slot) {
  if (slot >= kMaxRemote || dir.empty()) // dir: worker_poll's first pass ran (never the game's own folder).
    return;
  asset_names[slot] = AssetNames();
  DeleteFileW(slot_path("coop-names", slot).c_str());
  const std::string name = slot_file("coop-names", slot);
  append_file(std::wstring(name.begin(), name.end()).c_str(), "book " + std::to_string(++asset_books) + "\n");
  DeleteFileW(slot_path("coop-loaded", slot).c_str());
  std::lock_guard<std::mutex> lock(m);
  asset_loaded[slot].clear();
}

// Gated on peer_open, not peer_on: a table that follows the accept in the tick that completes the handshake comes
// before this pass's peer(), and the link already checked the handshake.
void peer_receive(size_t slot, const uint8_t *data, size_t size) {
  if (slot >= kMaxRemote || !peer_open())
    return;
  if (size >= 3 && (!std::memcmp(data, "SBP", 3) || !std::memcmp(data, "SBD", 3)))
    table_resend.heard(GetTickCount64()); // peer()'s clock. Her poses back after a gap: she may have lost our table.
  wire_receive(slot, data, size, clock_us());
}

std::string ask_loopback(bool on, uint32_t delay_ms, uint32_t jitter_ms, uint32_t loss_percent) {
  if (!on) { // Off works even with the engine off (after a fault).
    if (!loopback_on.exchange(false))
      return "loopback is not on";
    delay_line.set({}, 1);
    drop_remote(0);
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
    drop_remote(0);
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
