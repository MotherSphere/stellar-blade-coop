// Part of glue/tick.cpp, one translation unit with it (see there).
// The shared fight's worker side: the gates, same-place enemies' asks and pass, the spawn filter's hook and fight_pass;
// and the rows' asks and log (lion/rows.h's two batches), whose game-thread calls share the take-over's gate.

namespace coop::pose {

namespace {
// Why the shared fight may not run now, or empty: the pinned build, before coop off, on a co-op save (a save loaded
// from the co-op copies, or the slot the game entered is the one StellarCoopSlot.txt names: slot=coop). Off a co-op
// save the reason starts with fight::kNoCoopSave, which coop fight on waits out.
std::string fight_gate(int marker) {
  if (!pinned)
    return engine_reason;
  if (blocked)
    return "coop off";
  const std::string where = slot::line(loaded_slot(), marker, lua.world, saves_now());
  return where.rfind("slot=coop ", 0) == 0 ? std::string() : std::string(fight::kNoCoopSave) + " (" + where + ")";
}

// Where a fault (fault_filter's rva) was: in an SB call, its address as the decompiles name it; in this DLL, its
// offset; else (ntdll under ApplyStat's heap, say) the address itself.
std::string fault_where(uint64_t rva) {
  const uint64_t at_address = rva + reinterpret_cast<uintptr_t>(&__ImageBase);
  char where[64];
  if (at_address - base < kSizeOfImage)
    std::snprintf(where, sizeof where, "the game at 0x%llx",
                  static_cast<unsigned long long>(at_address - base + game::kImageBase));
  else if (fault_in_dll(rva))
    std::snprintf(where, sizeof where, "StellarCoop.dll+0x%llx", static_cast<unsigned long long>(rva));
  else
    std::snprintf(where, sizeof where, "0x%llx (another module)", static_cast<unsigned long long>(at_address));
  return where;
}

// coop fight pilot probe|on|off|status|test <how far>|test target|test exec. probe: while on, same-place enemies' lines
// this side sends go to coop-fight.log; on: our same_place on now (the co-op menu's row; as host, the guest hears it),
// and a pilot off lifted; off: the probe off and same-place enemies off on this side until the next coop fight on,
// probe, record or replay, or pilot on (each drawn copy goes back to the game, and the host tells her); status: the
// pilot line, and the stats lines at the next pass; test: how far the drawn side goes from now on, until coop fight on;
// test target: SB's force target once, on the first enemy this side owns (fight/pilot.h's Taker::test); test exec: the
// first frozen copy this side draws loses its balance at the job's next turn, so it can be taken down
// (Engine::exec_test); test bstart|phase|finish|summon: stage 5's solo probes at the job's next turn, only while a
// replay runs (Engine::boss_test).
bool pilot_stats_now = false;
std::string ask_pilot(const coop::Request &request) {
  switch (request.pilot) {
  case PilotAsk::off: {
    const bool probe = pilot_probe.exchange(false);
    fight_engine.pilot_off(true);
    return std::string("same-place enemies off until the next coop fight on (every drawn copy goes back to the "
                       "game)") +
           (probe ? "; pilot probe off" : "");
  }
  case PilotAsk::status: pilot_stats_now = true; return "same-place enemies: " + pilot_status();
  default: break;
  }
  const char *what = request.pilot == PilotAsk::test     ? "pilot test"
                     : request.pilot == PilotAsk::target ? "pilot test target"
                     : request.pilot == PilotAsk::exec   ? "pilot test exec"
                     : request.pilot == PilotAsk::bstart ? "pilot test bstart"
                     : request.pilot == PilotAsk::phase  ? "pilot test phase"
                     : request.pilot == PilotAsk::finish ? "pilot test finish"
                     : request.pilot == PilotAsk::summon ? "pilot test summon"
                     : request.pilot == PilotAsk::on     ? "pilot on"
                                                         : "pilot probe";
  if (!pinned)
    return std::string(what) + " refused: " + engine_reason;
  if (blocked)
    return std::string(what) + " refused: coop off";
  if (pilot_faulted)
    return std::string(what) + " refused: same-place enemies stopped for this run (a fault)";
  if (request.pilot == PilotAsk::on) {
    fight_engine.same_place(true);
    fight_engine.pilot_off(false);
    return "same-place enemies on: as host, for both games once the shared fight runs; as guest, the host's setting "
           "decides";
  }
  if (request.pilot == PilotAsk::target) {
    pilot_target_ask = true;
    return "pilot test target: the game's force target on the first enemy this side owns, toward our EVE, at the next "
           "frame (only in net mode 0 with no logic task in flight); coop-link.log says what it did, then the enemy's "
           "target, aggro level and detect result each time they change for a second";
  }
  if (request.pilot == PilotAsk::exec) {
    fight_engine.exec_test();
    return "pilot test exec: at the job's next turn, the first frozen copy this side draws loses its balance; take it "
           "down while it is groggy. coop-link.log says what the job did (fight pilot test exec ...), then fight exec "
           "lines for the takedown and pilot released and converged lines for the copy";
  }
  if (request.pilot >= PilotAsk::bstart) {
    static const char *const kSay[] = {
        ("the frozen boss copy nearest our EVE gets the host's boss start (SetBattleMode, once while it stays in "
         "battle mode, which it leaves 10 s later: no host repeats it); coop-link.log says its battle mode, "
         "first-time latch, on-battle flag, states 30 and 39 and AI task before, then each change for 1 s (fight "
         "pilot test bstart ...). From the next coop fight replay until coop fight on, boss copies get no "
         "BattleMode_5s"),
        ("the frozen boss copy nearest our EVE gets its first phase row it lacks, then 5 s later the dispel of its "
         "floor, as the host's phase lines would bring them; coop-link.log says each line, stat 107 and the rows the "
         "game took (fight pilot test phase ...)"),
        ("the frozen boss copy nearest our EVE is held at 1 HP for 10 s, then gets the host's HP back; hit it once "
         "only after a line shows state27=1. coop-link.log says each change of its HP, DeathReady, FinishReady and "
         "states 27 and 3 (fight pilot test finish ...)"),
        ("a DollHead summon 3 m ahead of our EVE under key 4026531841:0, with its row's effects and our freeze "
         "(removed at once if the game refuses it); coop-link.log says each change for 10 s (fight pilot test summon "
         "...); it goes 3 s later, or at coop fight off")};
    if (!fight_worker.replaying())
      return std::string(what) + " refused: only while coop fight replay runs";
    fight_engine.boss_test(request.pilot);
    return std::string(what) + ": at the job's next turn, " +
           kSay[uint8_t(request.pilot) - uint8_t(PilotAsk::bstart)];
  }
  if (request.pilot == PilotAsk::test) {
    static const char *const kSay[] = {
        "our freeze only (the copies stand still and play their own animations)",
        ("our freeze and their movement component out of the game's manager, nothing written (the drift lines say "
         "how far the game still moves them)"),
        "our freeze, the movement component out, root, speed and velocity from the stream, no Show replayed",
        "all of it (freeze, movement component, root, speed, velocity and Show replay)"};
    pilot_test = uint8_t(request.test);
    return std::string("pilot test: the copies this side draws get ") + kSay[uint8_t(request.test)] +
           " until coop fight on; coop record with coop fight record as host, then coop replay with coop fight "
           "replay, plays them from a recording";
  }
  if (pilot_probe.exchange(true))
    return "pilot probe is already on";
  return "pilot probe on: the SBE and show lines of the enemies this side owns, the lines it takes from her and how it "
         "drives the copies it draws go to coop-fight.log (a line a second each) while the shared fight runs (alone: "
         "coop fight record, as host)";
}

// Same-place enemies' output at each worker pass: the newest SBE and the show lines the game thread captured. Those
// for her go to her while the shared fight runs on (SBE on channel 1 unreliable, the lines on channel 2 reliable) and
// into a recording being made (coop record). Her show lines among this pass's channel 2 lines go to the drawn side.
// While same-place enemies run (PHASE11-STAGE3 7 rule 13), and at once for coop fight pilot status, coop-fight.log
// gets a stats line a second (the pilot line, the capture's counts, the bytes a second both ways) and the drawn side's
// counts when they moved. With the probe, also each line out and in, and the stats line carries the newest SBE. A
// fault is logged once.
bool pilot_fault_logged = false;
uint64_t pilot_drive_seen = 0; // The drawn side's counts as the last line had them (summed): no line while still.
uint64_t pilot_next_line = 0, pilot_unsent = 0, pilot_bytes_out = 0, pilot_bytes_said = 0, pilot_line_ms = 0;
fight::Ring<PilotLine, kPilotLines> pilot_taken;
uint8_t pilot_last_sbe[pilot::kMaxSbe]; // The newest SBE since the probe's last line, for its next one.
size_t pilot_last_size = 0;
bool pilot_last_out = false;
void pilot_pass(uint64_t now_ms, bool linked, const std::vector<std::string> &lines,
                bool (*send)(const std::string &, bool)) {
  if (pilot_faulted && !pilot_fault_logged) {
    pilot_fault_logged = true;
    char text[400];
    std::snprintf(text, sizeof text,
                  "same-place enemies fault 0x%08llx in %s reading 0x%llx: their capture and drive stop for this run, "
                  "%s; the ghost, the link and the shared fight go on",
                  static_cast<unsigned long long>(pilot_fault_code.load()), fault_where(pilot_fault_rva).c_str(),
                  static_cast<unsigned long long>(pilot_fault_address.load()),
                  fault_in_dll(pilot_fault_rva)
                      ? "the drawn copies are put back and let go"
                      : "the drawn copies are let go, and those the drive moved keep their movement component off "
                        "and our speed override until they leave the map (a fault outside StellarCoop.dll gets no "
                        "second call)");
    say(text);
  }
  uint8_t sbe[pilot::kMaxSbe];
  size_t sbe_size = 0;
  bool sbe_peer = false;
  const bool sharing = fight_worker.sharing(), probe = pilot_probe;
  for (const std::string &text : lines)
    if (fight::pilot_line(text)) {
      pilot_in(reinterpret_cast<const uint8_t *>(text.data()), text.size());
      if (probe)
        trace_fight("pilot in " + text);
    }
  pilot::Capturer::Counts counts;
  pilot::Driver::Counts drive;
  fight::Event events[pilot::Driver::kEvents];
  size_t events_n = 0;
  char notes[pilot::Taker::kNotes][pilot::Taker::kNoteBytes];
  size_t notes_n = 0;
  pilot::Taker::Counts take;
  uint64_t lost = 0, runs = 0, us = 0, max_us = 0, add_us = 0, frames = 0, frame_us = 0, frame_max_us = 0;
  {
    std::lock_guard<std::mutex> lock(pilot_m);
    pilot_lines.move_to(pilot_taken);
    std::memcpy(sbe, pilot_sbe, pilot_sbe_size);
    std::swap(sbe_size, pilot_sbe_size);
    sbe_peer = pilot_sbe_peer;
    counts = pilot_counts, lost = pilot_lost, runs = pilot_runs, us = pilot_us, max_us = pilot_max_us;
    drive = drive_counts, add_us = drive_add_max_us;
    frames = drive_runs, frame_us = drive_us, frame_max_us = drive_max_us;
    std::copy(pilot_events, pilot_events + pilot_events_n, events);
    std::swap(events_n, pilot_events_n);
    std::memcpy(notes, taker_notes, sizeof notes);
    std::swap(notes_n, taker_notes_n);
    take = take_counts;
  }
  for (size_t i = 0; i < events_n; ++i) // One line each: a copy released, converged or snapped.
    say("pilot " + fight::line(events[i]));
  for (size_t i = 0; i < notes_n; ++i) // A take-over done or refused; the target test's lines.
    say(std::string("pilot ") + notes[i]);
  const auto record = [](const uint8_t *data, size_t size) {
    if (recorder && !recorder->add(data, size))
      say(stop_record("full", clock_us()));
  };
  if (sbe_size && sbe_peer) {
    if (sharing && peer_on && peer_send)
      peer_send(sbe, sbe_size, false), pilot_bytes_out += sbe_size;
    record(sbe, sbe_size);
  }
  if (sbe_size) {
    std::memcpy(pilot_last_sbe, sbe, sbe_size);
    pilot_last_size = sbe_size, pilot_last_out = sbe_peer && sharing && peer_on;
  }
  for (PilotLine l; pilot_taken.pop(l);) {
    const std::string text = pilot::format(l.line);
    const bool out = l.peer && sharing && linked && send(text, true);
    pilot_unsent += l.peer && sharing && linked && !out;
    pilot_bytes_out += out ? text.size() : 0;
    if (l.peer)
      record(reinterpret_cast<const uint8_t *>(text.data()), text.size());
    if (probe)
      trace_fight((out ? "pilot out " : "pilot ") + text);
  }
  const bool now = std::exchange(pilot_stats_now, false);
  if (!now && (now_ms < pilot_next_line || (!probe && !fight_worker.piloting())))
    return;
  pilot_next_line = now_ms + 1000;
  using u = unsigned long long;
  // The rate since the last line, or "-" for the first line after a gap (the first one, or piloting again): never an
  // average over the gap.
  const uint64_t ms = now_ms - pilot_line_ms, bytes = pilot_bytes_in + pilot_bytes_out;
  char rate[24] = "-";
  if (ms && ms <= 2000)
    std::snprintf(rate, sizeof rate, "%llu", u((bytes - pilot_bytes_said) * 1000 / ms));
  pilot_line_ms = now_ms;
  char tail[640];
  std::snprintf(tail, sizeof tail,
                "; %llu captures (mean %llu us, max %llu us), %llu enemies sent, %llu not found, %llu Show assets "
                "unnamed, %llu players odd, %llu cut, %llu waiting for an id, %llu without context; %llu shows, %llu "
                "show-set, %llu show-stop, %llu lost, %llu unsent; %llu taken over (%llu force targets, %llu frames "
                "put off, %llu refused, %llu of them copy not found, %llu notes lost); %llu B in and out, %s B/s",
                u(counts.captures), u(runs ? us / runs : 0), u(max_us), u(counts.entries), u(counts.unresolved),
                u(counts.unnamed), u(counts.odd), u(counts.cut), u(counts.waited), u(counts.no_context),
                u(counts.shows), u(counts.sets), u(counts.stops), u(lost), u(pilot_unsent), u(take.taken),
                u(take.targeted), u(take.waited), u(take.refused), u(take.gone), u(take.notes_lost), u(bytes), rate);
  pilot_bytes_said = bytes;
  if (!probe)
    trace_fight("pilot stats: " + pilot_status() + tail);
  else if (pilot_last_size)
    trace_fight((pilot_last_out ? "pilot out " : "pilot ") + pilot::sbe_text(pilot_last_sbe, pilot_last_size) + tail);
  else
    trace_fight(std::string("pilot probe: no SBE in the last second: ") +
                (pilot_owned ? "the enemies this side owns were not found"
                             : "no enemy this side owns (only coop fight on or record pairs enemies)") + tail);
  pilot_last_size = 0;
  const uint64_t moved = drive.frames + drive.unresolved + drive.sbe + drive.sbe_refused + drive.lines +
                         drive.lines_refused + drive.not_drawn + pilot_in_bad + pilot_in_lost;
  if (moved == pilot_drive_seen && !now)
    return;
  pilot_drive_seen = moved;
  char line[1280];
  std::snprintf(line, sizeof line,
                "pilot drawn: %llu copy frames driven, %llu not found, %llu movement components taken out of the "
                "game's manager (%llu found back in it, %llu refused), %llu released, %llu converged, %llu snaps, "
                "drift up to %.1f cm/s and %.1f deg/s; SBE entries %llu taken, %llu refused; show lines %llu queued, "
                "%llu refused, %llu unreadable, %llu over the queue; %llu Shows replayed (%llu late, %llu missing, %llu "
                "without a stage, %llu without context; AddShow up to %llu us), %llu deduped, %llu show-set, %llu "
                "show-stop, %llu naming no replay, %llu for a copy not driven; %llu event lines lost; game thread "
                "%llu us a frame (mean, %llu frames), max %llu us",
                u(drive.frames), u(drive.unresolved), u(drive.cmc_out), u(drive.cmc_reenabled), u(drive.cmc_refused),
                u(drive.released), u(drive.converged), u(drive.snaps), drive.drift_cm, drive.drift_deg, u(drive.sbe),
                u(drive.sbe_refused), u(drive.lines), u(drive.lines_refused), u(pilot_in_bad), u(pilot_in_lost),
                u(drive.shows), u(drive.late), u(drive.missing), u(drive.no_handle), u(drive.no_context), u(add_us),
                u(drive.deduped), u(drive.sets), u(drive.stops), u(drive.unknown), u(drive.not_drawn),
                u(drive.events_lost), u(frames ? frame_us / frames : 0), u(frames), u(frame_max_us));
  trace_fight(line);
  drift_reset = true; // The drift maxima are the last second's from here.
}
} // namespace

std::string ask_fight(const coop::Request &request, int marker) {
  if (request.fight == Fight::pilot)
    return ask_pilot(request);
  // A refused on leaves a running test as it is.
  if (request.fight == Fight::on && fight_worker.mode() == Fight::none) {
    pilot_test = uint8_t(PilotTest::replay);
    fight_engine.calm(false);
  }
  FightIo io;
  return fight_worker.ask(request, [marker] { return fight_gate(marker); }, io);
}

std::string fight_status() { return fight_worker.detail(); }

// coop-status.txt's pilot line: "pilot=refused why=<why>" off the pinned build or after coop off, "pilot=stopped" after
// the pilot's latch, else the shared fight's word (Worker::pilot: "on piloted=<n>", to which " owned=<n> drawn=<n>"
// is added, "off why=<word>" or "stopped"),
// with " probe=on" while the probe runs and " test=<freeze|cmc|drive>" while a test holds the drawn side back, before
// the why (the last field: engine reasons have spaces).
std::string pilot_status() {
  if (!game_pinned)
    return "pilot=refused why=" + engine_reason;
  if (blocked)
    return "pilot=refused why=coop off";
  if (pilot_faulted)
    return "pilot=stopped";
  static const char *const kTests[] = {"freeze", "cmc", "drive", "replay"};
  std::string word = fight_worker.pilot(), why;
  if (const size_t at = word.find(" why="); at != std::string::npos)
    why = word.substr(at), word.resize(at);
  if (word.rfind("on ", 0) == 0) // The pairs whose AI runs here (captured) and those drawn, as of the last frame.
    word += " owned=" + std::to_string(pilot_owned.load()) + " drawn=" + std::to_string(pilot_drawn.load());
  const uint8_t test = pilot_test;
  return "pilot=" + word + (pilot_probe ? " probe=on" : "") +
         (test < uint8_t(PilotTest::replay) ? std::string(" test=") + kTests[test] : std::string()) + why;
}

namespace {
// ---- The spawn filter (spawn_filter=on, the guest's) ----
// SB's SpawnRequest vtable (.rdata 0x145c10018) holds its destructor, then Execute (0x141c10a90) in the slot at
// 0x145c10020. RequestSpawn (FUN_141c1ca40) calls Execute directly only while the slot holds it, and through the slot
// otherwise; the consumer of its delayed queue (FUN_141c1cd20) always calls through the slot; neither has a CFG check.
// So one aligned 8-byte store into the slot routes both call sites through filter_execute from then on, and no
// instruction byte of the game changes. The worker makes it once a run, by a compare-and-swap from Execute only, and
// undoes it at coop off and after a fault in the hook, by a compare-and-swap from our hook only: another mod's value
// is never overwritten. The DLL is pinned (never unloaded), so a thread still inside the hook after the undo is safe.
constexpr uint64_t kSpawnSlot = 0x145c10020, kExecute = 0x141c10a90, kRowByName = 0x141a9a780;
// SpawnRequest: its row's name (an FName, +0x28) and the SpawnIndex byte Execute passes NewActor (+0x30); the
// EventSpawnTable row: the EventSpawnId Execute passes NewActor (+0x10).
constexpr size_t kRequestName = 0x28, kRequestIndex = 0x30, kRowSpawnId = 0x10;
using Execute = void *(*)(void *request);
// The table holder (DAT_147032510, which the getter FUN_141a97f20 returns; never called here, since it makes one when
// none is made), an unused argument and the row's name: the EventSpawnTable row, or null. It runs the row's lazy init,
// as Execute's own first call does.
using RowByName = void *(*)(void *holder, uint64_t unused, const void *name);
enum class Filter : uint8_t { untried, on, refused, off };
Filter filter_state = Filter::untried; // The worker's.
std::atomic<bool> filter_faulted{false};
std::atomic<uint64_t> filter_fault_code{0}, filter_fault_rva{0}, filter_fault_address{0};
bool filter_fault_logged = false;
// The keys the hook refused, for the worker's log: a ring of 16 entries, each the low 24 bits of its push number + 1
// << 40 | spawnId << 8 | index, so the worker skips an entry not written yet (a slot still 0 too) or already written
// over.
constexpr uint64_t kFilterRing = 16;
std::atomic<uint64_t> filter_ring[kFilterRing] = {}, filter_pushed{0};
uint64_t filter_read = 0, filter_unlogged = 0; // The worker's.
// The keys the log named while the gate stays open (the worker's): SB asks again for a refused spawn after its
// interval, so each key is named once and later refusals show only in the stats line's count.
// ponytail: kMaxKeys names at most; past that, new keys count as not listed.
std::vector<uint64_t> filter_named;

// The request's key as Execute finds it (spawnId << 8 | index), or 0 when its row is not found. Out of line, since
// clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) uint64_t filter_key_body(const uint8_t *request) {
  void *const holder = *reinterpret_cast<void *const *>(base + (fight::kTables - game::kImageBase));
  const auto *row = holder ? static_cast<const uint8_t *>(
                                 game_function<RowByName>(kRowByName)(holder, 0, request + kRequestName))
                           : nullptr;
  if (!row)
    return 0;
  uint32_t id = 0;
  std::memcpy(&id, row + kRowSpawnId, sizeof id);
  return uint64_t(id) << 8 | request[kRequestIndex];
}
// Under the filter's own latch: after its first fault every request goes straight to Execute, and the worker swaps
// the slot back.
uint64_t filter_key(const uint8_t *request) {
  __try {
    return filter_key_body(request);
  } __except (fault_filter(GetExceptionInformation(), filter_fault_code, filter_fault_rva, filter_fault_address)) {
    filter_faulted = true;
    return 0;
  }
}
// The slot's target once swapped, on whichever thread SB spawns from: Execute, as SB would call it, unless the gate is
// open (fight::Engine::filtering: the guest's session asked with filter, or coop fight spawn probe) and the engine's
// table holds the request's key. That request gets null, which every caller takes (the immediate path returns it,
// the delayed one ignores it), and is counted and pushed for the log. Execute reads RCX only, so a one-argument hook
// forwards all it needs; it runs outside the guard, so a fault inside the game's own code is never taken for ours.
void *filter_execute(void *request) {
  const auto execute = game_function<Execute>(kExecute);
  if (filter_faulted || !fight_engine.filtering())
    return execute(request);
  fight::BlockTable &table = fight_engine.blocks();
  ++table.seen;
  const uint64_t key = filter_key(static_cast<const uint8_t *>(request));
  if (!key || !table.has(uint32_t(key >> 8), uint8_t(key)))
    return execute(request);
  ++table.refused;
  const uint64_t n = filter_pushed.fetch_add(1);
  filter_ring[n % kFilterRing] = ((n + 1) & 0xffffff) << 40 | key;
  return nullptr;
}
// The slot's address in the game, as the decompiles name it, and what a value in it points at.
const char kSlotName[] = "0x145c10020";
std::string slot_value(uint64_t value) {
  char text[64];
  if (value - base < kSizeOfImage)
    std::snprintf(text, sizeof text, "0x%llx in the game",
                  static_cast<unsigned long long>(value - base + game::kImageBase));
  else
    std::snprintf(text, sizeof text, "0x%llx outside the game", static_cast<unsigned long long>(value));
  return text;
}
// The compare-and-swap of a slot (its address as the decompiles name it) from from to to, its page writable for the
// store only: what the slot held (from when the swap was made), or false when the page's protection would not change.
bool swap_slot(uint64_t at, uint64_t from, uint64_t to, uint64_t &held) {
  void *const slot = reinterpret_cast<void *>(base + (at - game::kImageBase));
  DWORD old = 0;
  if (!VirtualProtect(slot, sizeof(uint64_t), PAGE_READWRITE, &old))
    return false;
  held = static_cast<uint64_t>(InterlockedCompareExchange64(static_cast<volatile LONG64 *>(slot),
                                                            static_cast<LONG64>(to), static_cast<LONG64>(from)));
  VirtualProtect(slot, sizeof(uint64_t), old, &old);
  return true;
}
uint64_t execute_address() { return base + (kExecute - game::kImageBase); }
uint64_t hook_address() { return reinterpret_cast<uintptr_t>(&filter_execute); }
// Once a run, on the worker thread, when the gate first opens on the pinned build before coop off and before a fault
// of the hook: the slot swapped from Execute to the hook. A slot that holds anything else (another mod's hook) is
// refused and never written.
void filter_install() {
  const uint64_t execute = execute_address();
  uint64_t held = *reinterpret_cast<const volatile uint64_t *>(base + (kSpawnSlot - game::kImageBase));
  const bool slot_ok = held == execute, page_ok = slot_ok && swap_slot(kSpawnSlot, execute, hook_address(), held);
  const bool on = page_ok && held == execute;
  filter_state = on ? Filter::on : Filter::refused;
  fight_engine.blocks().installed = on;
  if (on)
    say(std::string("spawn filter on: ") + kSlotName + " swapped from the game's Execute to our filter");
  else if (slot_ok && !page_ok)
    say("spawn filter refused: the page of " + std::string(kSlotName) + " would not become writable (error " +
        std::to_string(GetLastError()) + "); every spawn goes on as without the filter");
  else
    say("spawn filter refused: " + std::string(kSlotName) + " holds " + slot_value(held) +
        ", not the game's Execute (another mod's hook?); left as it is, every spawn goes on as without the filter");
}
// The slot back to Execute by a compare-and-swap from our hook only, at coop off and after a fault of the hook. If the
// swap cannot be made, the hook stays and passes every request on: the gate is shut at coop off, and the latch after
// a fault.
void filter_undo(const char *why) {
  if (filter_state != Filter::on)
    return;
  filter_state = Filter::off;
  fight_engine.blocks().installed = false;
  uint64_t held = 0;
  if (!swap_slot(kSpawnSlot, hook_address(), execute_address(), held))
    say(std::string("spawn filter off (") + why + "): the page of " + kSlotName +
        " would not become writable; our filter stays in it and passes every spawn on");
  else if (held == hook_address())
    say(std::string("spawn filter off (") + why + "): " + kSlotName + " holds the game's Execute again");
  else
    say(std::string("spawn filter off (") + why + "): " + kSlotName + " holds " + slot_value(held) +
        ", left as it is");
}
// Each fight pass, on the worker thread: the hook's fault said once (and the slot swapped back), the swap when the
// gate first opens, and the keys the hook refused since the last pass that the log has not named yet.
void filter_pass() {
  if (filter_faulted && !filter_fault_logged) {
    filter_fault_logged = true;
    char text[300];
    std::snprintf(text, sizeof text, "spawn filter fault 0x%08llx in %s reading 0x%llx: off for this run",
                  static_cast<unsigned long long>(filter_fault_code.load()), fault_where(filter_fault_rva).c_str(),
                  static_cast<unsigned long long>(filter_fault_address.load()));
    say(text);
    filter_undo("a fault");
  }
  const bool gate = fight_engine.filtering();
  if (filter_state == Filter::untried && pinned && !blocked && !filter_faulted && gate)
    filter_install();
  if (!gate)
    filter_named.clear();
  const uint64_t pushed = filter_pushed;
  if (pushed - filter_read > kFilterRing)
    filter_unlogged += pushed - filter_read - kFilterRing, filter_read = pushed - kFilterRing;
  for (; filter_read < pushed; ++filter_read) {
    const uint64_t entry = filter_ring[filter_read % kFilterRing], key = entry & 0xffffffffffull;
    if (entry >> 40 != ((filter_read + 1) & 0xffffff)) {
      ++filter_unlogged;
      continue;
    }
    if (std::find(filter_named.begin(), filter_named.end(), key) != filter_named.end())
      continue;
    if (filter_named.size() == fight::kMaxKeys) {
      ++filter_unlogged;
      continue;
    }
    filter_named.push_back(key);
    say("spawn filter refused " + std::to_string(uint32_t(key >> 8)) + ":" + std::to_string(key & 0xff));
  }
  if (filter_unlogged)
    say("spawn filter: " + std::to_string(std::exchange(filter_unlogged, 0)) + " more refused, not listed");
}
} // namespace

// coop lion's and coop gardener fight's rows (Lua's lion rows and gardener rows requests): the 14 tables' addresses
// for the game thread, which adds that batch's rows at the first frame its gate holds. An ask it has not taken yet is
// replaced. Refused off the pinned build, after coop off and after the rows' fault; once every row of a batch is in,
// nothing more is asked of it (the rows stay for the game run).
std::string ask_rows(const coop::Request &request) {
  RowsJob &j = *kJobs[request.batch < kRowWordCount ? request.batch : 0];
  const std::string word = j.batch.word, n = std::to_string(j.batch.count);
  if (!game_pinned || blocked || lion_faulted)
    return word + " rows refused: " +
           (blocked        ? std::string("coop off")
            : lion_faulted ? std::string("the rows stopped for this run (a fault)")
                           : engine_reason);
  uint32_t asks = 0;
  if (lion::unpack(j.word, asks).state == lion::State::rows)
    return word + " rows already in: " + n + "/" + n + ", not added again";
  {
    std::lock_guard<std::mutex> lock(j.m);
    ++j.asked;
    std::copy(request.tables.begin(), request.tables.end(), j.ask_tables);
  }
  return word + " rows asked: the game thread adds " + n +
         " rows through SB's AddRow at the first frame with net mode 0 and no logic task in flight (at most " +
         std::to_string(lion::kGateTicks) + " frames)";
}

namespace {
// Each worker pass: one line for each answer the game thread finished for a batch (the R2 line, and with every row
// in the R3 line of SB's own lookups), and the rows' fault once, by the batch that ran into it or first answered it.
uint32_t rows_logged[kRowWordCount] = {};
bool lion_fault_logged = false;
void lion_pass() {
  for (size_t k = 0; k < kRowWordCount; ++k) {
    const RowsJob &j = *kJobs[k];
    uint32_t asks = 0;
    const lion::Answer a = lion::unpack(j.word, asks);
    if (asks == rows_logged[k])
      continue;
    rows_logged[k] = asks;
    if (a.state == lion::State::fault) {
      if (std::exchange(lion_fault_logged, true))
        continue;
      char text[300];
      std::snprintf(text, sizeof text,
                    "%s rows off: fault 0x%08llx in %s reading 0x%llx after %u of %u rows; no rows of either batch "
                    "until the game restarts",
                    j.batch.word, static_cast<unsigned long long>(lion_fault_code.load()),
                    fault_where(lion_fault_rva).c_str(), static_cast<unsigned long long>(lion_fault_address.load()),
                    unsigned(a.added), unsigned(j.batch.count));
      say(text);
      continue;
    }
    say(lion::describe(j.batch, a));
    if (a.state == lion::State::rows) {
      const uint32_t r = j.read;
      say(lion::describe_read(j.batch, {uint8_t(r), uint8_t(r >> 8), uint8_t(r >> 16)}));
    }
  }
}
} // namespace

bool fight_pass(uint64_t now_ms, bool linked, bool hosting, int marker, const std::vector<std::string> &lines,
                bool (*send)(const std::string &, bool), coop::Life mate) {
  fight_send = send;
  lion_pass(); // The rows' answers, logged here at every pass whatever the fight does.
  if (fight_faulted && !fight_fault_logged) {
    fight_fault_logged = true;
    char text[400];
    const uint64_t left = fight_floors_left;
    std::snprintf(text, sizeof text, "shared fight fault 0x%08llx in %s reading 0x%llx: the ghost and the link go on%s",
                  static_cast<unsigned long long>(fight_fault_code.load()), fault_where(fight_fault_rva).c_str(),
                  static_cast<unsigned long long>(fight_fault_address.load()),
                  left ? ("; " + std::to_string(left) +
                          " of our changes on enemies (1 HP floors, two-player scaling, frozen copies) stay until "
                          "their enemies leave the map")
                             .c_str()
                       : "");
    say(text);
  }
  FightIo io;
  // Our photo mode pauses it (pinned build). Two or three reads, so every kGateMs, not at every 5 ms pass: SB's logic
  // stands still meanwhile anyway.
  static bool photo = false;
  static uint64_t next_photo = 0;
  if (now_ms >= next_photo)
    next_photo = now_ms + fight::kGateMs, photo = pinned && !blocked && fight::photo_mode(base, rpm);
  fight_worker.pass(now_ms, linked, hosting, lua.world, lines, [marker] { return fight_gate(marker); }, io, photo,
                    mate);
  filter_pass();
  pilot_pass(now_ms, linked, lines, send);
  return fight_engine.on();
}

} // namespace coop::pose
