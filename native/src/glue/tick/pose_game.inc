// Part of glue/tick.cpp, one translation unit with it (see there).
// The ghost's pose path, the game thread's half: the shared state, EVE's read and encode, the ghost's write, coop_tick's body.

namespace coop::pose {
namespace {
uintptr_t base = 0, objects = 0;
std::atomic<bool> engine_on{false}, blocked{false}, faulted{false};
std::string engine_reason = "not checked yet"; // Worker only.
std::atomic<uint64_t> ticks{0}, doubles{0};
std::atomic<uint64_t> fault_code{0}, fault_rva{0}, fault_address{0};
std::atomic<int> current_part{-1}; // The part being read or written, for the fault line.
// Effects' own latch (ROADMAP 4.8): the game thread turns them off at their first fault, the worker logs it once.
std::atomic<bool> effects_on{true};
std::atomic<uint64_t> fx_fault_code{0}, fx_fault_rva{0}, fx_fault_address{0};
std::atomic<int> fx_fault_part{-1};
// The XInput pads (coop_pad): the worker loads XInputGetState once, the game thread polls it. pad_seen is the game
// thread's last read for the worker's log: the slots connected as bits, kPadUnread before the first poll, kPadMissing
// when System32 has no XInput.
using XInputGetStateFn = DWORD(WINAPI *)(DWORD, XINPUT_STATE *);
std::atomic<XInputGetStateFn> xinput_get{nullptr};
constexpr int kPadUnread = -1, kPadMissing = -2;
std::atomic<int> pad_seen{kPadUnread};

// What the worker asks the game thread to send: EVE's pose while the loopback runs (with its settings), while a
// recording is made or while a friend is linked.
std::atomic<bool> loopback_on{false}, record_on{false}, peer_on{false};
std::atomic<uint32_t> loopback_delay{0}, loopback_jitter{0}, loopback_loss{0};
std::atomic<uint32_t> loopback_epoch{0}; // Bumped by every settings change: the playback's clock starts again.

size_t leader_bytes(const Table &t) {
  size_t bytes = 0;
  for (const Part &p : t.eve)
    bytes += p.leader ? size_t(p.bones) * kTransformBytes : 0;
  return bytes;
}

// What the worker hands the game thread, all sized off the game thread: EVE's capture table with her pose as read for
// sending; the remote table (the layout poses arrive in) with the playback and the pose drawn this frame; and the
// ghost Lua built for the remote table, drawn only when it is of the remote generation.
struct Live {
  Table capture, remote;
  Display display;
  Playback playback;
  std::vector<uint8_t> capture_bones, draw;
  float capture_root[10] = {}, draw_root[10] = {};
  bool refusal_logged = false; // Game thread: only the first refused write on this ghost is logged.
  bool ghost_gone = false;      // Game thread: Lua destroyed this ghost; nothing is drawn until its display is dropped.
  // Her effect slots as read for sending; the ghost's drawn this frame, and as last written into its boxes.
  Effect capture_fx[kEffectSlots], draw_fx[kEffectSlots], fx_drawn[kEffectSlots];
  KeyedEncoder encoder; // Her keyframe and the byte budget: a new Live starts with a keyframe.
  KeyedDecoder decoder; // The remote keyframe held: a new Live waits for the next one (250 ms at most).
  Live(Table c, Table r, Display d) : capture(std::move(c)), remote(std::move(r)), display(std::move(d)) {
    capture_bones.assign(leader_bytes(capture), 0);
    encoder.reset(pose_size(capture));
    decoder.reset(pose_size(remote));
    playback.reset(leader_bytes(remote));
    draw.assign(leader_bytes(remote), 0);
    for (Effect &e : fx_drawn)
      e.asset = 0xff; // No slot's: the first frame drawn writes every box.
  }
  bool drawn() const { return display.generation && display.generation == remote.generation; }
};

// An encoded pose on its way: bytes (sized kMaxPose once, by the worker, before the engine goes on; only swapped after
// that), its size, and when it was read (outgoing) or received (incoming), in µs.
struct Message {
  std::vector<uint8_t> data;
  size_t size = 0;
  uint64_t time = 0;
};
constexpr size_t kInbox = 24; // 400 ms of poses at 60 a second.

// Hand-over, guarded by m: the worker's newest Live (or a withdrawal) for the game thread, and the game thread's
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
uint64_t last_frame = 0, next_capture = 0;
uint32_t sequence = 0; // Of the poses sent: never restarts in a run, so a pose still in flight is always the older.
uint32_t seen_epoch = 0;
float stamp = 1; // The mailbox's scale Z: the engine default is 1, our stamps run from 2 up.
float fx_stamp = 1; // Its scale X, the same way: bumped by each frame that wrote an effect box.
// Her effect slots across reads: never restarts in a run either, so a new Live (her friend's outfit, a new ghost)
// does not send an effect still playing as a new instance; a slot no longer matched is freed at the next read.
EffectState fx_state;
EffectCounts fx_counts; // The effect read's, moved into the window counters after each read.
Message out_back;
bool out_ready = false; // out_back holds a pose the worker has not been handed yet.
std::array<Message, kInbox> game_inbox;
size_t game_inbox_count = 0;
// The send interval: 20 poses a second (N4) until coop-state.txt says otherwise (send_rate, 10 to 60; Lua's default is
// 60). The worker stores it, the game thread reads it.
std::atomic<uint64_t> send_us{50'000};
// GFrameCounter (PHASE2-RE.md): incremented once per frame by FEngineLoop::Tick, and on some loading paths; compare
// "different from the last call", never "last + 1".
constexpr uint32_t kFrameCounterRva = 0x706b508;

// Same-place enemies' SBE goes to her (the pilot capture's, below): the poses give up kSbeBytesPerSecond of their
// budget meanwhile. Game thread.
bool pilot_sending = false;

// Cost counters, game thread writes, worker reads and resets every 60 s.
std::atomic<uint64_t> window_ticks{0}, window_us{0}, window_max_us{0}, window_max_gap_us{0}, window_long_gaps{0};
// The stream's, the same way (the worker's own among them).
std::atomic<uint64_t> window_sent{0}, window_sent_bytes{0}, window_clamped{0}, window_capture_refused{0},
    window_line_lost{0}, window_inbox_full{0}, window_tables_in{0}, window_tables_refused{0}, window_rejected{0},
    window_foreign{0}, window_malformed{0}, window_poses{0}, window_stale{0}, window_missing{0}, window_stalls{0},
    window_steps{0}, window_drawn{0}, window_extrapolated{0}, window_drawn_written{0}, window_drawn_refused{0},
    window_keyframes{0}, window_deltas{0}, window_delta_bytes{0}, window_held{0}, window_keyless{0};
std::atomic<uint64_t> window_fx_started{0}, window_fx_over{0}, window_fx_unlisted{0}, window_fx_written{0};
std::atomic<int64_t> window_lag_us{0}, window_behind_us{0};
std::atomic<int> last_refusal{0};              // An Io value, for the counter line.
std::atomic<const char *> last_reject{"none"}; // decode_pose's reason.

// The encoded pose to the worker (m held): replaces one it has not taken yet, which the receiver counts missing; but a
// keyframe not taken yet stays and a delta, which names it, is dropped instead (keeps_waiting).
void give_out() {
  out_ready = false;
  if (out_fresh && keeps_waiting(out_mid.data.data(), out_mid.size, out_back.data.data(), out_back.size))
    return;
  std::swap(out_back, out_mid);
  out_fresh = true;
}

uint64_t micros_between(LARGE_INTEGER a, LARGE_INTEGER b) {
  return frequency.QuadPart ? uint64_t((b.QuadPart - a.QuadPart) * 1000000 / frequency.QuadPart) : 0;
}
uint64_t micros_now(LARGE_INTEGER now) {
  return frequency.QuadPart ? uint64_t(now.QuadPart / frequency.QuadPart * 1000000 +
                                       now.QuadPart % frequency.QuadPart * 1000000 / frequency.QuadPart)
                            : 0;
}
uint64_t clock_us() {
  LARGE_INTEGER now;
  QueryPerformanceCounter(&now);
  return micros_now(now);
}
void raise_max(std::atomic<uint64_t> &slot, uint64_t value) {
  uint64_t seen = slot.load();
  while (value > seen && !slot.compare_exchange_weak(seen, value))
    ;
}

extern "C" IMAGE_DOS_HEADER __ImageBase; // This DLL: every instruction the native tick runs is ours.
// A fault's code, offset in this DLL and address into the latch's own fields.
int fault_filter(EXCEPTION_POINTERS *info, std::atomic<uint64_t> &code, std::atomic<uint64_t> &rva,
                 std::atomic<uint64_t> &address) {
  auto *exception = info->ExceptionRecord;
  if (passed_on(exception->ExceptionCode)) // UE's fatal error or a stack overflow: the game's handlers take it.
    return EXCEPTION_CONTINUE_SEARCH;
  code = exception->ExceptionCode;
  rva = reinterpret_cast<uintptr_t>(exception->ExceptionAddress) - reinterpret_cast<uintptr_t>(&__ImageBase);
  if (exception->NumberParameters >= 2) // Access violations: the address read or written.
    address = exception->ExceptionInformation[1];
  return EXCEPTION_EXECUTE_HANDLER;
}

// EVE now: her main mesh's world transform and her leaders' local poses, back to back.
Io read_eve(const Table &capture, float *root, uint8_t *bones) {
  if (!published(objects, capture.eve[0]))
    return Io::gone;
  read_world(static_cast<uintptr_t>(capture.eve[0].object), root);
  size_t offset = 0;
  for (size_t i = 0; i < capture.eve.size(); ++i) {
    if (!capture.eve[i].leader)
      continue;
    current_part = static_cast<int>(i);
    Io r = read_leader(objects, capture.eve[i], bones + offset);
    current_part = -1;
    if (r != Io::ok)
      return r;
    offset += size_t(capture.eve[i].bones) * kTransformBytes;
  }
  return Io::ok;
}

// A write the gate refused: counted, and logged the first time on this ghost (part -1: the mailbox, -2: an effect box).
void refused(Live &live, int part, Io r) {
  last_refusal = static_cast<int>(r);
  if (live.refusal_logged)
    return;
  live.refusal_logged = true;
  char line[160];
  char what[24] = "mailbox";
  if (part == -2)
    std::snprintf(what, sizeof what, "effect box");
  else if (part >= 0)
    std::snprintf(what, sizeof what, "part %d", part);
  std::snprintf(line, sizeof line, "write refused: %s %s (table %llu)", what, describe(r),
                static_cast<unsigned long long>(live.remote.generation));
  pending.push_back(line);
}

// Effects under their own latch. clang-cl catches a fault only in a function the __try calls, never in code inlined
// into the __try's own frame, so the accesses stay out of line; the guarded functions hold plain data only.
__declspec(noinline) void effects_read(Live &live) {
  read_effects(objects, live.capture, fx_state, live.capture_fx, fx_counts);
}
// The boxes whose slot changed since last written; false when one was refused (written again next frame).
__declspec(noinline) bool effects_write(Live &live, uint64_t &written) {
  const Display &d = live.display;
  bool all = true;
  for (size_t n = 0; n < kEffectSlots; ++n) {
    const Effect &e = live.draw_fx[n], &was = live.fx_drawn[n];
    if (e.asset == was.asset && e.part == was.part && e.serial == was.serial &&
        !std::memcmp(e.place, was.place, sizeof e.place))
      continue;
    if (write_effect_box(objects, d.effects[n], d.mailbox_class, d.puppet[0], e) != Io::ok) {
      all = false;
      continue;
    }
    live.fx_drawn[n] = e;
    ++written;
  }
  return all;
}
// Her effects into capture_fx; the first fault empties them and turns effects off.
void guarded_effects_read(Live &live) {
  __try {
    effects_read(live);
  } __except (fault_filter(GetExceptionInformation(), fx_fault_code, fx_fault_rva, fx_fault_address)) {
    fx_fault_part = fx_counts.part;
    effects_on = false;
    for (Effect &e : live.capture_fx)
      e = Effect();
  }
  window_fx_started += fx_counts.started;
  window_fx_over += fx_counts.over;
  window_fx_unlisted += fx_counts.unlisted;
  fx_counts = EffectCounts();
}
// The drawn slots into the ghost's effect boxes, then a new fx_stamp when one was written, so Lua reads them. False
// when a box was refused or faulted.
bool guarded_effects_write(Live &live) {
  uint64_t written = 0;
  bool all = false;
  __try {
    all = effects_write(live, written);
  } __except (fault_filter(GetExceptionInformation(), fx_fault_code, fx_fault_rva, fx_fault_address)) {
    fx_fault_part = -1; // A box, not a part.
    effects_on = false;
  }
  if (written) {
    fx_stamp = fx_stamp >= 1e6f ? 2.f : fx_stamp + 1.f;
    window_fx_written += written;
  }
  return all;
}

// The pose drawn this frame into the ghost: each remote leader Lua built a part for, as it came or through its remap,
// then its effect boxes and the mailbox. True when every write passed its checks.
bool write_puppet(Live &live) {
  const Table &remote = live.remote;
  const Display &d = live.display;
  size_t offset = 0;
  bool all = true;
  for (size_t i = 0; i < remote.eve.size(); ++i) {
    if (!remote.eve[i].leader)
      continue;
    const Part &p = d.puppet[i];
    if (p.object) { // Else left out: its bytes are skipped.
      const uint8_t *bones = live.draw.data() + offset;
      current_part = static_cast<int>(i);
      Io r = d.remap[i].empty() ? write_leader(objects, p, bones)
                                : write_leader_mapped(objects, p, bones, d.remap[i].data(), remote.eve[i].bones);
      current_part = -1;
      if (r != Io::ok) {
        all = false;
        refused(live, static_cast<int>(i), r);
      }
    }
    offset += size_t(remote.eve[i].bones) * kTransformBytes;
  }
  if (effects_on && d.effects[0] && !guarded_effects_write(live)) {
    all = false;
    if (effects_on) // Refused, not faulted: a fault has its own line.
      refused(live, -2, Io::gone);
  }
  stamp = stamp >= 1e6f ? 2.f : stamp + 1.f;
  if (write_mailbox(objects, d.mailbox, d.mailbox_class, d.puppet[0], live.draw_root, fx_stamp, stamp) != Io::ok) {
    all = false;
    refused(live, -1, Io::gone);
  }
  return all;
}

// Each frame: EVE's pose every send interval while the byte budget allows, encoded as a keyframe or a delta for the
// worker, while it sends; the poses the worker got back, decoded with the remote table into the playback, once Lua
// built the ghost for it; the playback's pose for now, written into the ghost.
void stream(uint64_t now_us) {
  Live &live = *session;
  if (uint32_t epoch = loopback_epoch.load(); epoch != seen_epoch) {
    seen_epoch = epoch; // New settings: the poses in flight were dropped, and the old delay must not pass for a step.
    live.playback.clear();
  }
  const bool capture_due = (loopback_on || record_on || peer_on) && live.capture.generation && now_us >= next_capture;
  if (capture_due && !live.encoder.due(now_us, pilot_sending)) {
    ++window_held; // The byte budget is spent: read again next frame.
  } else if (capture_due) {
    Io r = read_eve(live.capture, live.capture_root, live.capture_bones.data());
    if (r == Io::ok) {
      uint64_t every = send_us.load(std::memory_order_relaxed);
      next_capture = (next_capture && now_us - next_capture < every ? next_capture : now_us) + every;
      if (effects_on && live.capture.fx.cls) // Only with effect lines: Lua sends none while effects are off.
        guarded_effects_read(live);
      else
        for (Effect &e : live.capture_fx)
          e = Effect();
      PoseHeader h;
      h.generation = live.capture.generation;
      h.publication = now_us;
      h.sequence = ++sequence;
      uint32_t clamped = 0;
      if (out_ready && out_back.size >= 3 && out_back.data[2] == 'P') // A keyframe the worker never got: overwritten.
        live.encoder.lose();
      size_t size = encode_pose(live.capture, h, live.capture_root, live.capture_bones.data(), live.capture_fx,
                                out_back.data.data(), clamped);
      size = out_back.size = live.encoder.encode(live.capture, out_back.data.data(), size, now_us);
      if (out_back.data[2] == 'D')
        ++window_deltas, window_delta_bytes += size;
      else
        ++window_keyframes;
      out_back.time = now_us;
      out_ready = true;
      if (m.try_lock()) { // At once, not at the next frame's hand-over: one frame less of delay.
        give_out();
        m.unlock();
      }
      ++window_sent;
      window_sent_bytes += size; // Not out_back.size: give_out() swapped another message in.
      window_clamped += clamped;
    } else {
      ++window_capture_refused; // Read again next frame.
      last_refusal = static_cast<int>(r);
    }
  }
  for (size_t i = 0; i < game_inbox_count; ++i) {
    if (!live.drawn()) { // No ghost for the remote table yet, or no remote table.
      ++window_foreign;
      continue;
    }
    Playback::Frame &f = live.playback.scratch();
    PoseHeader h;
    const Message &in = game_inbox[i];
    if (const char *why =
            live.decoder.decode(live.remote, in.data.data(), in.size, h, f.root, f.bones.data(), f.fx)) {
      if (!std::strcmp(why, "generation")) { // Of a table the ghost is not built on (yet): an outfit in flight.
        ++window_foreign;
      } else if (!std::strcmp(why, "key")) { // A delta whose keyframe was lost, or came before this Live.
        ++window_keyless;
      } else {
        ++window_rejected;
        last_reject = why;
      }
      continue;
    }
    f.sequence = h.sequence;
    f.publication = h.publication;
    live.playback.accept(in.time);
  }
  if (live.drawn() && !live.ghost_gone) {
    // Lua destroys the ghost (a level change, coop puppet, coop basesuit) and withdraws its display in the same frame,
    // but the worker reads that withdrawal only within 250 ms: a destroyed ghost is no refused write, just the end.
    if (!alive(objects, static_cast<uintptr_t>(live.display.puppet[0].object)))
      live.ghost_gone = true;
    else if (live.playback.sample(now_us, live.draw_root, live.draw.data(), live.draw_fx))
      ++(write_puppet(live) ? window_drawn_written : window_drawn_refused);
  }
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
  if (session)
    stream(micros_now(now));
  else
    window_foreign += game_inbox_count; // No table at all: nothing to decode them with.
  game_inbox_count = 0;
  LARGE_INTEGER done;
  QueryPerformanceCounter(&done);
  uint64_t us = micros_between(now, done);
  window_ticks++;
  window_us += us;
  raise_max(window_max_us, us);
}

void guarded_tick() {
  __try {
    game_tick();
  } __except (fault_filter(GetExceptionInformation(), fault_code, fault_rva, fault_address)) {
    faulted = true;
    engine_on = false;
  }
}
} // namespace
} // namespace coop::pose
