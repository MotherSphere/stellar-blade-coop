// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- Same-place enemies: the owner's capture (fight/pilot.h's Capturer), the game thread's read half ----
// SB's two read-only lookups by GUID (stage 3a's allowlist, PHASE11-STAGE3 3.4): FSBActorManager::FindActor, an
// ActorGUID's FSBActor (it logs, and so allocates, only when its two maps disagree), and the registry's character of
// an FSBActor's FGuid (none when pending kill or not an ASBCharacter).
constexpr uint64_t kFindFsb = 0x141aace90, kFindCharacter = 0x14201b1e0;
using FindFsb = void *(*)(void *manager, int32_t guid);
using FindCharacter = void *(*)(void *map, const int32_t *guid);
constexpr uint64_t kSbeUs = 1'000'000 / pilot::kSbeHz;
constexpr size_t kPilotLines = 64;
struct PilotLine {
  pilot::ShowLine line;
  bool peer = false; // For her: the table was on (same_place, her side on). Else the probe's alone.
};
// The worker's asks and what the game thread did.
std::atomic<bool> pilot_faulted{false}, pilot_probe{false};
// coop fight pilot test: how far the drawn side goes (PilotTest), for the game thread's Driver; back to replay (all of
// it) at each coop fight on.
std::atomic<uint8_t> pilot_test{uint8_t(PilotTest::replay)};
std::atomic<uint64_t> pilot_fault_code{0}, pilot_fault_rva{0}, pilot_fault_address{0};
std::atomic<uint32_t> pilot_owned{0}; // The pairs the last frame would capture.
// The game thread's.
pilot::Capturer capturer;
fight::PilotTable pilot_table;
fight::StreamFlags pilot_stream; // The drawn copies' word back (the write half's): none yet.
fight::Told pilot_told; // What the lines so far were told under: a change tells every Show again.
uint64_t next_sbe = 0, pilot_lost_here = 0;
uint64_t pilot_runs_here = 0, pilot_us_here = 0, pilot_max_us_here = 0;
fight::Ring<PilotLine, kPilotLines> pilot_waiting; // Lines a busy lock kept here.
uint8_t sbe_back[pilot::kMaxSbe];
size_t sbe_back_size = 0;
bool sbe_back_peer = false;
// Handed over under pilot_m, which the game thread takes with try_lock only and holds for copies of our own memory.
std::mutex pilot_m;
fight::Ring<PilotLine, kPilotLines> pilot_lines;
uint8_t pilot_sbe[pilot::kMaxSbe];
size_t pilot_sbe_size = 0;
bool pilot_sbe_peer = false;
pilot::Capturer::Counts pilot_counts;
uint64_t pilot_lost = 0, pilot_runs = 0, pilot_us = 0, pilot_max_us = 0;
// The drawn side's. Hers (SBE messages, parsed show lines) come from the worker under pilot_m, and the game thread
// moves them to its own rings at its hand-over; what its Driver did goes back the same way.
struct SbeIn {
  uint8_t data[pilot::kMaxSbe];
  size_t size = 0;
};
constexpr size_t kSbeIn = 8; // About 250 ms of her SBE: the game thread takes them every frame.
fight::Ring<SbeIn, kSbeIn> pilot_sbe_in, pilot_sbe_here;
fight::Ring<pilot::ShowLine, kPilotLines> pilot_lines_in, pilot_lines_here;
pilot::Driver driver;               // The game thread's, with the engine frame it last drove in.
uint64_t drive_frame = UINT64_MAX;
uint64_t drive_runs_here = 0, drive_us_here = 0, drive_max_us_here = 0; // Its frames holding a copy, and their cost.
pilot::Driver::Counts drive_counts; // Under pilot_m, as are the four below.
uint64_t drive_runs = 0, drive_us = 0, drive_max_us = 0; // The drawn side's frames that held a copy, and their cost.
fight::Event pilot_events[pilot::Driver::kEvents]; // The Driver's event lines, for the worker's log.
size_t pilot_events_n = 0;
uint64_t drive_add_max_us = 0;
std::atomic<bool> drift_reset{false}; // The worker's ask: the drift probe's maxima start again.
// Stage 3b's take-over (fight/pilot.h's Taker), the game thread's: its notes and counts go to the worker under pilot_m.
pilot::Taker taker;
std::atomic<bool> pilot_target_ask{false}; // coop fight pilot test target, for the next frame.
std::atomic<uint32_t> pilot_drawn{0};      // The pairs the last frame drew.
char taker_notes[pilot::Taker::kNotes][pilot::Taker::kNoteBytes];
size_t taker_notes_n = 0;
pilot::Taker::Counts take_counts;

// The drawn side's calls (stage 3a's allowlist, PHASE11-STAGE3 3.5 and 3.6, M3-3 and M3-12), on the game thread only,
// under the pilot latch: SB's Show handle API, the sequence SB's own skill presentation runs (FUN_142284a30 a new stage
// and its handle, FUN_142285010 SetMainActor, FUN_1422853e0 AddShow, and the setters FUN_142285200 SetStep,
// FUN_142285270 SetRate and FUN_1422852f0 Stop, keyed by that handle), and SB's own SetComponentTickEnabled of its
// movement component (pilot::kCmcTick, 142158f40, vtable slot 0x350), called only once fight/pilot.h checked the
// component's vtable and that slot. The root's MoveComponent is called through the root's vtable (+0x4a0), as SB's
// SetActorLocation calls it. Never SB's SetLocation or 142277990, never the engine base 140f32a70, never a write to
// APawn::LastControlInputVector.
constexpr uint64_t kNewHandle = 0x142284a30, kSetMainActor = 0x142285010, kAddShow = 0x1422853e0,
                   kSetStep = 0x142285200, kSetRate = 0x142285270, kStopShow = 0x1422852f0;
struct FString { // UE's: the characters with their NUL, and that count twice (no slack).
  const wchar_t *data;
  int32_t num, max;
};
using NewHandle = int32_t *(*)(void *reg, int32_t *out, uint8_t release_when_done);
using SetMainActor = void (*)(void *reg, const int32_t *handle, const void *actor_guid);
using AddShow = int32_t (*)(void *reg, const int32_t *handle, const FString *path, uint8_t as_given, float rate,
                            float delay, uint8_t step_gate, uint8_t b4d);
using SetStep = void (*)(void *reg, const int32_t *handle, int32_t slot, int32_t step, uint8_t jump);
using SetRate = void (*)(void *reg, const int32_t *handle, int32_t slot, float rate);
using StopShow = void (*)(void *reg, const int32_t *handle, float blend_out);
using CmcTick = void (*)(void *cmc, uint8_t on);
using MoveComponent = uint8_t (*)(void *root, const float *delta, const float *quat, uint8_t sweep, void *hit,
                                  uint32_t flags, uint8_t teleport);
uint64_t pilot_add_max_us = 0; // The game thread's: AddShow's longest call (a Show's first load is synchronous).
// Stage 3b's call (PHASE11-STAGE3 3.8, M3-4), on the game thread only, under the pilot latch: SB's force target,
// FUN_141a36010(the copy's FSBActor + 0x710, our EVE's FSBActor, unused, the hold in XMM3), which fight/pilot.h's Taker
// makes only with the cached net mode 0 and no logic task in flight (logic + 0x5c0 == 0): in net mode 3 its senders
// become ServerRequest_ActorAdd/RemoveTargetedByEnemy, which the mod never sends.
constexpr uint64_t kForceTarget = 0x141a36010;
using ForceTarget = void (*)(void *ai, void *target, uint64_t unused, float hold);

// fight/pilot.h's Game: plain reads and writes (a fault is the latch's), the two lookups, and the drawn side's calls.
struct PilotGame {
  struct Handle { // A stage handle as SB's functions take it.
    int32_t w[4];
    explicit Handle(const uint8_t *h) { std::memcpy(w, h, sizeof w); }
  };
  bool read(uint64_t address, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(address), n);
    return true;
  }
  void write(uint64_t address, const void *in, size_t n) { std::memcpy(reinterpret_cast<void *>(address), in, n); }
  uint64_t fsb(uint64_t manager, uint32_t guid) {
    return reinterpret_cast<uintptr_t>(
        game_function<FindFsb>(kFindFsb)(reinterpret_cast<void *>(manager), static_cast<int32_t>(guid)));
  }
  uint64_t character(uint64_t map, const int32_t *guid) {
    return reinterpret_cast<uintptr_t>(
        game_function<FindCharacter>(kFindCharacter)(reinterpret_cast<void *>(map), guid));
  }
  void cmc(uint64_t cmc, bool on) { game_function<CmcTick>(pilot::kCmcTick)(reinterpret_cast<void *>(cmc), on); }
  void move(uint64_t fn, uint64_t root, const float *delta, const float *quat) {
    alignas(16) float q[4] = {quat[0], quat[1], quat[2], quat[3]}; // SB passes an aligned FQuat.
    const float d[3] = {delta[0], delta[1], delta[2]};
    reinterpret_cast<MoveComponent>(fn)(reinterpret_cast<void *>(root), d, q, 0, nullptr, 0, 1); // Teleport.
  }
  bool handle(uint64_t reg, uint8_t *out) {
    int32_t h[4] = {};
    game_function<NewHandle>(kNewHandle)(reinterpret_cast<void *>(reg), h, 1);
    std::memcpy(out, h, sizeof h);
    return h[0] || h[1] || h[2] || h[3];
  }
  void main_actor(uint64_t reg, const uint8_t *h, uint64_t guid) {
    game_function<SetMainActor>(kSetMainActor)(reinterpret_cast<void *>(reg), Handle(h).w,
                                               reinterpret_cast<const void *>(guid));
  }
  int32_t add(uint64_t reg, const uint8_t *h, const char *path, size_t len, uint8_t form, float rate, uint8_t gate,
              uint8_t b4d) {
    static wchar_t text[pilot::kMaxPath + 1]; // The game thread's alone; AddShow copies it.
    len = std::min(len, pilot::kMaxPath);
    for (size_t k = 0; k < len; ++k)
      text[k] = wchar_t(uint8_t(path[k]));
    text[len] = 0;
    const FString s{text, int32_t(len + 1), int32_t(len + 1)};
    const uint64_t start = clock_us();
    const int32_t slot = game_function<AddShow>(kAddShow)(reinterpret_cast<void *>(reg), Handle(h).w, &s, form, rate,
                                                          0.f, gate, b4d);
    pilot_add_max_us = std::max(pilot_add_max_us, clock_us() - start);
    return slot;
  }
  void step(uint64_t reg, const uint8_t *h, int32_t slot, int32_t step) {
    game_function<SetStep>(kSetStep)(reinterpret_cast<void *>(reg), Handle(h).w, slot, step, 1);
  }
  void rate(uint64_t reg, const uint8_t *h, int32_t slot, float rate) {
    game_function<SetRate>(kSetRate)(reinterpret_cast<void *>(reg), Handle(h).w, slot, rate);
  }
  void stop(uint64_t reg, const uint8_t *h) {
    game_function<StopShow>(kStopShow)(reinterpret_cast<void *>(reg), Handle(h).w, 0.f);
  }
  void target(uint64_t ai, uint64_t eve) {
    game_function<ForceTarget>(kForceTarget)(reinterpret_cast<void *>(ai), reinterpret_cast<void *>(eve), 0,
                                             pilot::kTargetHold);
  }
};
// Each frame: the newest table; every kSbeUs while this side owns pairs (and the table is on, or the probe runs), one
// capture; once an engine frame the drawn copies and the take-overs; then what it made handed to the worker when the
// lock is free (else at a later frame: the newest SBE, every line kept in order).
__declspec(noinline) void pilot_body() {
  const uint64_t start = clock_us();
  fight_mail.table(pilot_table, pilot_stream); // Busy: the table as it was.
  const fight::PilotTable &t = pilot_table;
  const bool fresh = !blocked && fight::fresh(t, start / 1000, fight_engine.latched()), peer = t.on;
  if (pilot_told.forget(t))
    capturer.clear();
  pilot::Owned owned[fight::kMaxPairs];
  const size_t n = fresh && (peer || pilot_probe) ? fight::owned(t, owned) : 0;
  pilot_owned = uint32_t(n);
  if (!n)
    pilot_sending = false;
  if (n && start >= next_sbe) {
    next_sbe = (next_sbe && start - next_sbe < kSbeUs ? next_sbe : start) + kSbeUs;
    PilotGame g;
    const size_t size = capturer.capture(
        g, base, t.gen, owned, n, start, sbe_back,
        [peer](const pilot::ShowLine &l) {
          if (pilot_waiting.push(PilotLine{l, peer}))
            return true;
          ++pilot_lost_here;
          return false;
        },
        [](const uint8_t *h) { return driver.made(h); }); // Our replays on a pair just taken over: never told (R35).
    if (size)
      sbe_back_size = size, sbe_back_peer = peer;
    pilot_sending = peer && size;
    const uint64_t took = clock_us() - start;
    ++pilot_runs_here, pilot_us_here += took, pilot_max_us_here = std::max(pilot_max_us_here, took);
  }
  // The drawn side, once an engine frame (game_tick's rule): the copies this side draws (none once the table is off or
  // stale, or after coop off: each is put back), hers as the last hand-over brought it, every copy driven at the
  // ghost's draw time and the lines due played.
  if (const uint64_t frame = at<uint64_t>(base + kFrameCounterRva); frame != drive_frame) {
    drive_frame = frame;
    if (drift_reset.exchange(false))
      driver.counts.drift_cm = driver.counts.drift_deg = 0;
    pilot::Row rows[fight::kMaxPairs];
    PilotGame g;
    driver.limit(PilotTest(pilot_test.load()));
    const size_t drawn = fresh ? fight::drawn(t, rows) : 0;
    pilot_drawn = uint32_t(drawn);
    driver.rows(g, base, t.gen, t.side, rows, drawn);
    // A pair this side now owns at a new epoch, its copy put back by rows() just above: SB's force target toward our
    // EVE (PHASE11-STAGE3 3.8); the take-overs it refused go back to the job for its own-no.
    if (pilot_target_ask.exchange(false))
      taker.test();
    taker.step(g, base, t.gen, fresh ? owned : nullptr, n, t.on, start / 1000);
    taker.refused(pilot_stream.untaken, pilot_stream.untaken_oe, pilot_stream.untaken_count);
    // Where her ghost's main mesh was last drawn in our world, for the host's nearer rule (stage 3b); none before its
    // first pose (a drawn root's scale is never 0).
    pilot_stream.her_ok = session && session->drawn() && !session->ghost_gone && session->draw_root[7] > 0;
    if (pilot_stream.her_ok)
      std::copy(session->draw_root + 4, session->draw_root + 7, pilot_stream.her);
    const double now_ms = start / 1000.0,
                 draw = session ? session->playback.display_ms(now_ms) : std::numeric_limits<double>::quiet_NaN();
    for (SbeIn m; pilot_sbe_here.pop(m);)
      driver.sbe(m.data, m.size);
    for (pilot::ShowLine l; pilot_lines_here.pop(l);)
      driver.line(l, draw);
    driver.draw(g, base, now_ms, draw);
    driver.flags(pilot_stream.battle, pilot_stream.count, pilot_stream.refused, pilot_stream.refused_count,
                 pilot_stream.skill, pilot_stream.skill_count, pilot_stream.exec, pilot_stream.exec_count);
    if (driver.holding()) { // From the frame's start, the capture included (PHASE11-STAGE3 5: under 0.5 ms a frame).
      const uint64_t took = clock_us() - start;
      ++drive_runs_here, drive_us_here += took, drive_max_us_here = std::max(drive_max_us_here, took);
    }
  }
  if (!pilot_m.try_lock())
    return;
  pilot_waiting.move_to(pilot_lines);
  if (sbe_back_size) {
    std::memcpy(pilot_sbe, sbe_back, sbe_back_size);
    pilot_sbe_size = sbe_back_size, pilot_sbe_peer = sbe_back_peer;
    sbe_back_size = 0;
  }
  pilot_counts = capturer.counts;
  pilot_lost = pilot_lost_here, pilot_runs = pilot_runs_here, pilot_us = pilot_us_here;
  pilot_max_us = pilot_max_us_here;
  pilot_sbe_in.move_to(pilot_sbe_here);
  pilot_lines_in.move_to(pilot_lines_here);
  driver.events([](const fight::Event &e) {
    return pilot_events_n < pilot::Driver::kEvents && (pilot_events[pilot_events_n++] = e, true);
  });
  drive_counts = driver.counts, drive_add_max_us = pilot_add_max_us;
  drive_runs = drive_runs_here, drive_us = drive_us_here, drive_max_us = drive_max_us_here;
  taker.notes([](const char *text) {
    if (taker_notes_n < pilot::Taker::kNotes)
      std::snprintf(taker_notes[taker_notes_n++], pilot::Taker::kNoteBytes, "%s", text);
    else
      ++taker.counts.notes_lost;
  });
  take_counts = taker.counts;
  pilot_m.unlock();
}
__declspec(noinline) void pilot_put_back() {
  PilotGame g;
  driver.fault(g, base);
}
// The first fault stops the capture and the drive for the run and asks the job to let every frozen copy go
// (Engine::stop_pilot). When the fault was in this DLL (one of our reads, so the game's state is whole) every drawn
// copy is put back once: its replays stopped, its movement component and speed override back. After a fault in the
// game's code or another module's (an SB call broken half way, which a second call could hang) nothing more is called,
// as lift_after_fault does for the shared fight: what the drive changed stays until those enemies leave the map.
void guarded_pilot() {
  __try {
    pilot_body();
  } __except (fault_filter(GetExceptionInformation(), pilot_fault_code, pilot_fault_rva, pilot_fault_address)) {
    pilot_faulted = true;
    pilot_sending = false;
    taker.fault();
    fight_engine.stop_pilot();
  }
  if (!pilot_faulted || !fault_in_dll(pilot_fault_rva))
    return;
  __try { // Once: coop_tick calls nothing here after a fault. A fault in it leaves the rest as it is.
    pilot_put_back();
  } __except (passed_on(GetExceptionCode()) ? EXCEPTION_CONTINUE_SEARCH : EXCEPTION_EXECUTE_HANDLER) {
  }
}
} // namespace
} // namespace coop::pose
