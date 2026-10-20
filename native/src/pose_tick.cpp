// The native pose path's Windows side. coop_tick runs on the game thread, called once per frame by the Lua loop; the
// worker thread (steam_link.cpp) calls worker_poll and worker_stream. They share only atomics and a mutex the game
// thread never waits on (try_lock: a busy lock skips the hand-over until the next frame; only swaps happen under it,
// never allocations). Every engine access runs under SEH; the first fault latches the feature off for the run and is
// logged with its code, the DLL offset, the address and the part.
//
// The ghost (Phase 3b), one path whatever its source. Lua publishes EVE's capture (coop-components.txt); the worker
// sends it as the wire table (pose_table.h), and while the loopback runs, a recording is made or a friend is linked the
// game thread reads EVE every send interval (send_rate, within the byte budget) and encodes her pose as a keyframe or a
// delta against the last keyframe (pose_codec.h, protocol 9) for the worker to send. All that is sent goes through
// wire_send: into the loopback's delay line (pose_stream.h), into the recording (pose_record.h) and to the linked
// friend over Steam (Phase 4, steam_link.cpp). All that is received comes back through wire_receive, from the delay
// line, a replayed recording or the friend: a table is checked and handed to Lua as coop-remote.txt, Lua builds the
// ghost from it and names what it built in coop-display.txt; a pose (a keyframe, or a delta rebuilt on the held
// keyframe) is decoded with that table into the playback, whose pose for each frame the game thread writes into the
// ghost's leaders, and the main mesh's world transform into its mailbox for Lua to place it. With effect lines in her
// capture (protocol 6), her effects travel in the pose's four slots too, and the drawn slots go into the ghost's effect
// boxes; they have their own SEH latch, so a fault there turns effects off for the run and the ghost goes on.
//
// The Night Operation probe (Phase 6) is the worker's alone: on the nightop request it reads the rule manager and its
// neighbours through ReadProcessMemory (nightop_probe.h) into nightop-probe.txt, never touching a game pointer itself.
//
// The shared fight (Phase 11, fight_engine.h) runs inside SB: a static job of ours that SB's logic thread runs once a
// turn, armed by coop_tick on the game thread. Both run under the fight's own SEH latch, so after its first fault the
// ghost and the link go on. The job reaches the worker only through Mail (try_lock on the logic thread: it never waits,
// allocates or writes a file); the worker turns its lines into channel 2's text and its events into the log.
//
// The synced photo mode's pause (photo_freeze.h) is the game thread's too: while the friend's photo mode asks for it
// (the link's photo line) or coop freeze runs, coop_tick holds a pause tag of ours in SB's set through SB's own
// pause-tag function, under its own SEH latch, and releases it on every way out, coop off included.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX // std::min and std::max in pose_stream.h.
#include <windows.h>

#include <array>
#include <atomic>
#include <cstddef>
#include <cstdio>
#include <cstring>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "fight_engine.h"
#include "link_protocol.h"
#include "nightop_probe.h"
#include "photo_freeze.h"
#include "pose_codec.h"
#include "pose_engine.h"
#include "pose_record.h"
#include "pose_stream.h"
#include "pose_tick.h"
#include "save_slot.h"

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
  if (capture_due && !live.encoder.due(now_us)) {
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

// ---- The shared fight's job ----
// SB's own functions on the pinned build (PHASE11-DESIGN.md 4.7): SendJob from the game thread to arm and from inside
// our job to push it again (never with param_3 = 1); the actor lookup and ApplyStat only from inside our job.
constexpr uint64_t kSendJob = 0x141af3930, kFindActor = 0x141ad6ab0, kApplyStat = 0x141ba8720;
constexpr uint64_t kLogicThreadId = 0x1470634f0; // DAT_1470634f0: the logic worker's thread ID during its tick, else 0.
using SendJob = uint8_t (*)(void *, fight::Job *job, uint8_t unlocked_queue);
using FindActor = void *(*)(void *logic, int32_t guid);
using ApplyStat = void (*)(void *la, int32_t stat, uint64_t key, float delta, uint32_t, void *cause, uint32_t,
                           int32_t skill_guid, uint32_t, uint8_t notify, uint8_t ignore_nodamage);
template <class F> F game_function(uint64_t address) {
  return reinterpret_cast<F>(base + (address - nightop::kImageBase));
}

fight::Engine fight_engine; // Its ring of 8 jobs is never freed: SB's queue may hold one, and the DLL is pinned.
fight::Mail fight_mail;
std::atomic<bool> fight_faulted{false};
std::atomic<uint64_t> fight_fault_code{0}, fight_fault_rva{0}, fight_fault_address{0};
uint64_t sim_runs = 0, sim_us = 0, sim_max_us = 0; // The logic thread's.
bool fight_ticked = false;                         // The game thread's: the fight was on at the last coop_tick.

// fight_engine.h's Game: plain reads (a fault is the SEH guard's, and latches), SB's functions, and Mail.
struct WinGame {
  bool read(uint64_t address, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(address), n);
    return true;
  }
  uint64_t find(uint64_t logic, uint32_t guid) {
    return reinterpret_cast<uintptr_t>(
        game_function<FindActor>(kFindActor)(reinterpret_cast<void *>(logic), static_cast<int32_t>(guid)));
  }
  void apply(uint64_t la, int type, float delta, uint64_t cause, bool notify) {
    game_function<ApplyStat>(kApplyStat)(reinterpret_cast<void *>(la), type, 0, delta, 0,
                                         reinterpret_cast<void *>(cause), 0, 0, 0, notify, 1);
  }
  void push(fight::Job *job) { game_function<SendJob>(kSendJob)(nullptr, job, 0); }
  bool receive(fight::Message &m) { return fight_mail.receive(m); }
  void send(const fight::Message &m) { fight_mail.send(m); }
  void event(const fight::Event &e) { fight_mail.event(e); }
  void probe(const fight::Actor &a) { fight_mail.probe(a); }
};

// The logic thread's side for the worker: the engine's counts, our time in Simulate and the thread it ran on.
fight::Snapshot fight_snapshot() {
  fight::Snapshot s = fight_engine.snapshot();
  s.runs = sim_runs, s.us = sim_us, s.max_us = sim_max_us;
  s.thread = GetCurrentThreadId();
  s.sb_thread = at<uint32_t>(base + (kLogicThreadId - nightop::kImageBase));
  return s;
}
// One run: hers in and ours out around the engine's Simulate, never waiting (Mail's try_lock).
__declspec(noinline) void simulate_body(fight::Job &job) {
  const uint64_t start = clock_us();
  fight_mail.exchange(fight_snapshot());
  WinGame g;
  fight_engine.simulate(job, g, start / 1000);
  const uint64_t took = clock_us() - start;
  ++sim_runs, sim_us += took, sim_max_us = std::max(sim_max_us, took);
  fight_mail.exchange(fight_snapshot());
}
// Slot 1, which SB's drain calls with the job, on its logic thread (the game thread in non-threaded mode). The first
// fault turns the shared fight off for the run; SB's drain goes on with its next job.
void job_simulate(void *self) {
  __try {
    simulate_body(*static_cast<fight::Job *>(self));
  } __except (fault_filter(GetExceptionInformation(), fight_fault_code, fight_fault_rva, fight_fault_address)) {
    fight_faulted = true;
    fight_engine.latch("fault");
  }
}
// The vtable SB's queue sees: slot 0 frees nothing (our jobs are static), slot 1 Simulate, slot 2 nothing.
struct JobVtable {
  void *(*release)(void *, unsigned);
  void (*simulate)(void *);
  void (*nothing)(void *);
};
const JobVtable kJobVtable = {fight::job_release, job_simulate, fight::job_nothing};

// The game thread, each frame while on: the engine's arm rule, under the same latch.
__declspec(noinline) void arm_body() {
  WinGame g;
  fight_engine.arm(g, clock_us() / 1000);
  fight_mail.armed(fight_engine.counts, GetCurrentThreadId());
}
void guarded_arm() {
  __try {
    arm_body();
  } __except (fault_filter(GetExceptionInformation(), fight_fault_code, fight_fault_rva, fight_fault_address)) {
    fight_faulted = true;
    fight_engine.latch("fault");
  }
}

// ---- The synced photo mode's pause (photo_freeze.h) ----
// SB's on the pinned build (FEATURE-PARITY.md 6.2): the pause-tag function photo mode pauses with, the player
// controller getter it pauses through, and FName's MakeWithNumber (FUN_142938380, which SB calls for "PhotoMode"; our
// name has no number suffix, so ParseNumber's 0 goes as it is). The set's singleton is fight_engine.h's kPauseAt.
constexpr uint64_t kPauseTag = 0x1422aafe0, kController = 0x14231c710, kMakeName = 0x142938380;
// FUN_1422ab320's reads, null-checked here: the controller's GetWorld (virtual +0x158), the world's persistent level,
// the level's WorldSettings, and their PauserPlayerState.
constexpr size_t kGetWorld = 0x158, kLevel = 0x30, kWorldSettings = 0x268, kPauser = 0x20b0;
struct NameView { // FUN_142938380's name: its characters, their count, and whether any needs more than 7 bits.
  const wchar_t *text;
  uint32_t len;
  bool wide;
};
static_assert(sizeof(NameView) == 16 && offsetof(NameView, len) == 8 && offsetof(NameView, wide) == 12);
using PauseTag = void (*)(bool add, const uint64_t *name, bool notify);
using Controller = uintptr_t (*)();
using MakeName = uint64_t *(*)(uint64_t *out, const NameView *name, int find_type, uint32_t number);
using GetWorld = uintptr_t (*)(uintptr_t controller);

// The worker's asks, and what the game thread did, for its log.
std::atomic<bool> freeze_pinned{false}, freeze_sync{false}, freeze_held{false}, freeze_faulted{false};
std::atomic<uint32_t> freeze_test{0};   // The running coop freeze's number, 0 when none.
std::atomic<uint32_t> freeze_unsure{0}; // Bumped at each Lua load.
std::atomic<uint64_t> freeze_reapplied{0}, freeze_dropped{0};
std::atomic<uint64_t> freeze_fault_code{0}, freeze_fault_rva{0}, freeze_fault_address{0};
// The game thread's.
photo::Freeze freeze;
uint64_t freeze_name = 0; // FName "StellarCoopFreeze" (ComparisonIndex, Number), made once.
uint32_t freeze_unsure_seen = 0;

struct FreezeGame {
  uintptr_t controller() { return game_function<Controller>(kController)(); }
  bool ready() {
    return at<uint64_t>(base + (nightop::kGlobals + fight::kPauseAt - nightop::kImageBase)) && controller();
  }
  void tag(bool add) { game_function<PauseTag>(kPauseTag)(add, &freeze_name, true); }
  bool paused() {
    const uintptr_t pc = controller();
    const uintptr_t world = pc ? reinterpret_cast<GetWorld>(at<uintptr_t>(at<uintptr_t>(pc) + kGetWorld))(pc) : 0;
    const uintptr_t level = world ? at<uintptr_t>(world + kLevel) : 0;
    const uintptr_t settings = level ? at<uintptr_t>(level + kWorldSettings) : 0;
    return !settings || at<uintptr_t>(settings + kPauser) != 0;
  }
};
// Each tick: nothing while no pause is asked or held. coop off (blocked) asks for none, so a held tag goes.
__declspec(noinline) void freeze_body() {
  if (const uint32_t n = freeze_unsure; n != freeze_unsure_seen) {
    freeze_unsure_seen = n;
    freeze.unsure();
  }
  const bool sync = freeze_sync && !blocked;
  const uint32_t test = blocked ? 0 : freeze_test.load();
  if (!sync && !test && !freeze.held())
    return;
  if (!freeze_name) {
    const NameView name{L"StellarCoopFreeze", 17, false};
    game_function<MakeName>(kMakeName)(&freeze_name, &name, 1, 0); // 1: FNAME_Add.
    if (!freeze_name) {                                             // "None": never a tag of ours.
      freeze_faulted = true;
      return;
    }
  }
  FreezeGame g;
  freeze.step(g, sync, test, clock_us() / 1000);
  freeze_held = freeze.held();
  freeze_reapplied = freeze.reapplied, freeze_dropped = freeze.dropped;
}
__declspec(noinline) void freeze_release() {
  FreezeGame g;
  if (g.ready())
    g.tag(false);
}
// The first fault turns the pause off for the run (the worker logs it and says so on screen), after one try to remove
// our tag, so a pause never outlives the latch while SB still takes the call.
void guarded_freeze() {
  __try {
    freeze_body();
  } __except (fault_filter(GetExceptionInformation(), freeze_fault_code, freeze_fault_rva, freeze_fault_address)) {
    freeze_faulted = true;
  }
  if (!freeze_faulted)
    return;
  if (freeze_name) { // Even unheld: a fault inside an add may come after our tag went into SB's set.
    __try {
      freeze_release();
    } __except (EXCEPTION_EXECUTE_HANDLER) {
    }
  }
  freeze_held = false;
}

} // namespace

// At most about max bytes of the file (read on in 4 KB steps while under it): Lua's files and the remote table are
// under 64 KB, a recording under 24 MiB, so a longer file reads past its cap and is refused by its parser.
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
bool pin_checked = false, fault_logged = false, fx_fault_logged = false, buffers_ready = false;
uint64_t next_poll = 0, next_counters = 0;
uint64_t vitals_reads = 0, vitals_max_us = 0; // local_vitals()'s, for the 60 s line.
bool world = false; // From coop-state.txt: a save is loaded (the link's held invites wait for one).
uint32_t rate = 20;  // From coop-state.txt: poses sent a second.
State lua;           // coop-state.txt as last read, the synced photo mode's fields with it.
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
nightop::Poller poller;
uint64_t nightop_next = 0;
size_t nightop_bytes = 0;
constexpr size_t kProbeCap = 4 << 20; // About 30 min of lines at 10 a second (a field flickering every sample).
// ReadProcessMemory fails on unmapped memory instead of faulting, and never trips a guard page.
bool rpm(uint64_t address, void *out, size_t n) {
  SIZE_T got = 0;
  return ReadProcessMemory(GetCurrentProcess(), reinterpret_cast<LPCVOID>(address), out, n, &got) && got == n;
}
// The shared fight's worker side (fight_engine.h's Worker), with channel 2 as the last fight_pass gave it.
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

// coop-fight.log (the Worker's trace): the shared fight's probe actors and stats lines, stamped in UTC like
// coop-link.log, whose 1 MB they would fill. Past 4 MB a last line says so and the run's later ones go nowhere.
size_t fight_log_bytes = 0;
constexpr size_t kFightLogCap = 4 << 20; // About 2 h of stats lines each second, or a T11a probe's half hour.
void trace_fight(const std::string &line) {
  if (fight_log_bytes >= kFightLogCap)
    return;
  SYSTEMTIME t;
  GetSystemTime(&t);
  char stamp[32];
  wsprintfA(stamp, "%04u-%02u-%02uT%02u:%02u:%02u.%03uZ ", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond,
            t.wMilliseconds);
  std::string text = stamp + line + "\r\n";
  if (fight_log_bytes + text.size() > kFightLogCap) {
    text = std::string(stamp) + "capped at 4 MB: the shared fight's events go on in coop-link.log\r\n";
    fight_log_bytes = kFightLogCap;
    say("fight: coop-fight.log capped at 4 MB for this run");
  } else {
    fight_log_bytes += text.size();
  }
  append_file(L"coop-fight.log", text);
}

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

// The only way in: a table to take_table, a pose or a delta of this protocol to the game thread's inbox, anything else
// counted.
void wire_receive(const uint8_t *data, size_t size, uint64_t now_us) {
  if (size >= 3 && !std::memcmp(data, "SBT", 3)) {
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
    freeze_pinned = pinned; // After base: the game thread's pause calls need it.
    event(std::string("engine ") + (engine_on ? "on: " : "off: ") + engine_reason);
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
    event("new Lua session: capture and ghost dropped");
  }
  take_capture();
  take_display();
  // A missing or bad file keeps the previous values: Lua's put() removes the old file before it renames the new one in,
  // so the worker can find none in between.
  if (State now; parse_state(read_file(folder + L"coop-state.txt", exists, kMaxState), now)) {
    lua = now;
    world = now.world;
    if (now.rate != rate) {
      rate = now.rate;
      send_us = 1'000'000 / rate;
      event("send rate " + std::to_string(rate) + " poses a second");
    }
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

bool world_loaded() { return world; }
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
  delay_line.deliver(now_us, receive);
  replay.deliver(now_us, receive);
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
  return "record on: her poses into coop-record.bin for up to 120 s (or 24 MiB), until coop record off";
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
  std::snprintf(text, sizeof text, "replay on: %zu poses and %zu tables, %.1f s a loop, until coop replay off", r.poses,
                r.entries.size() - r.poses, double(r.last - r.first) / 1e6);
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

int loaded_slot() { return pinned && !blocked ? slot::index(base, rpm) : slot::kUnread; }
namespace {
slot::Names names; // The save name as the worker last read it back.
// After coop off nothing is read again, but the name stays as it was until the game exits: the last value read.
slot::Saves saves_now() { return pinned ? names.saves() : slot::Saves::off; }
// The name's compare-and-swap. clang-cl catches a fault only in a function the __try calls, so the write stays out of
// line; a fault (the entry freed since its read) is a failed swap, which latches the switch off.
__declspec(noinline) bool cas_body(uint64_t at, uint64_t expected, uint64_t desired) {
  return InterlockedCompareExchange64(reinterpret_cast<volatile LONG64 *>(at), static_cast<LONG64>(desired),
                                      static_cast<LONG64>(expected)) == static_cast<LONG64>(expected);
}
bool guarded_cas(uint64_t at, uint64_t expected, uint64_t desired) {
  __try {
    return cas_body(at, expected, desired);
  } __except (EXCEPTION_EXECUTE_HANDLER) {
    return false;
  }
}
} // namespace
slot::Saves saves() {
  if (pinned && !blocked)
    names.update(slot::find(base, rpm));
  return saves_now();
}
std::string saves_why() { return !pinned ? engine_reason : blocked ? std::string("coop off") : names.why(); }
int load_mode() { return pinned && !blocked ? slot::field(base, rpm, slot::kLoadMode) : slot::kUnread; }
std::string saves_switch(bool coop) {
  if (!pinned || blocked)
    return saves_why();
  return names.swap(base, rpm, guarded_cas, coop);
}
std::string saves_probe() {
  if (!pinned || blocked)
    return "saves probe: off: " + (blocked ? std::string("coop off") : engine_reason);
  return slot::probe(base, rpm);
}
bool loopback() { return engine_on && loopback_on; }
bool local_vitals(coop::Vitals &out, uint64_t &took_us) {
  took_us = 0;
  if (!pinned || blocked)
    return false;
  const uint64_t start = clock_us();
  const bool ok = fight::vitals(base, rpm, out);
  took_us = clock_us() - start;
  ++vitals_reads;
  vitals_max_us = std::max(vitals_max_us, took_us);
  return ok;
}

namespace {
// Why the shared fight may not run now, or empty: the pinned build, before coop off, on a co-op save (a save loaded
// from the co-op copies, or the slot the game entered is the one StellarCoopSlot.txt names: slot=coop). Off a co-op
// save the reason starts with fight::kNoCoopSave, which coop fight on waits out.
std::string fight_gate(int marker) {
  if (!pinned)
    return engine_reason;
  if (blocked)
    return "coop off";
  const std::string where = slot::line(loaded_slot(), marker, world, saves_now());
  return where.rfind("slot=coop ", 0) == 0 ? std::string() : std::string(fight::kNoCoopSave) + " (" + where + ")";
}
} // namespace

std::string ask_fight(const coop::Request &request, int marker) {
  FightIo io;
  return fight_worker.ask(request, [marker] { return fight_gate(marker); }, io);
}

std::string fight_status() { return fight_worker.detail(); }

bool fight_pass(uint64_t now_ms, bool linked, bool hosting, int marker, const std::vector<std::string> &lines,
                bool (*send)(const std::string &, bool)) {
  fight_send = send;
  if (fight_faulted && !fight_fault_logged) {
    fight_fault_logged = true;
    // In an SB call made from our job: its address as the decompiles name it; in this DLL: its offset; else (ntdll
    // under ApplyStat's heap, say) the address itself.
    const uint64_t at_address = fight_fault_rva + reinterpret_cast<uintptr_t>(&__ImageBase);
    const auto *ours = reinterpret_cast<const IMAGE_NT_HEADERS *>(reinterpret_cast<const char *>(&__ImageBase) +
                                                                  __ImageBase.e_lfanew);
    char where[64], text[200];
    if (at_address - base < kSizeOfImage)
      std::snprintf(where, sizeof where, "the game at 0x%llx",
                    static_cast<unsigned long long>(at_address - base + nightop::kImageBase));
    else if (fight_fault_rva < ours->OptionalHeader.SizeOfImage)
      std::snprintf(where, sizeof where, "StellarCoop.dll+0x%llx",
                    static_cast<unsigned long long>(fight_fault_rva.load()));
    else
      std::snprintf(where, sizeof where, "0x%llx (another module)", static_cast<unsigned long long>(at_address));
    std::snprintf(text, sizeof text, "shared fight fault 0x%08llx in %s reading 0x%llx: the ghost and the link go on",
                  static_cast<unsigned long long>(fight_fault_code.load()), where,
                  static_cast<unsigned long long>(fight_fault_address.load()));
    say(text);
  }
  FightIo io;
  // Our photo mode pauses it (pinned build). Two or three reads, so every kGateMs, not at every 5 ms pass: SB's logic
  // stands still meanwhile anyway.
  static bool photo = false;
  static uint64_t next_photo = 0;
  if (now_ms >= next_photo)
    next_photo = now_ms + fight::kGateMs, photo = pinned && !blocked && fight::photo_mode(base, rpm);
  fight_worker.pass(now_ms, linked, hosting, world, lines, [marker] { return fight_gate(marker); }, io, photo);
  return fight_engine.on();
}

bool can_freeze() { return pinned && !blocked && !freeze_faulted; }
bool frozen() { return freeze_held; }

std::string ask_freeze(bool on, uint64_t ms, uint64_t now_ms) {
  if (!on) {
    if (!freeze_until)
      return "coop freeze is not on";
    freeze_until = 0, freeze_test = 0;
    return "coop freeze off: our pause tag goes";
  }
  if (!can_freeze())
    return "coop freeze refused: " + (blocked          ? std::string("coop off")
                                      : freeze_faulted ? std::string("the photo pause stopped for this run")
                                                       : engine_reason);
  freeze_until = now_ms + ms;
  freeze_test = ++freeze_tests;
  return "coop freeze: our pause tag held for " + std::to_string(ms / 1000) +
         " s, or until coop freeze off or the world it paused is gone";
}

std::string freeze_pass(bool sync, uint64_t now_ms) {
  freeze_sync = sync && can_freeze();
  if (freeze_until && now_ms >= freeze_until) {
    freeze_until = 0, freeze_test = 0;
    say("coop freeze over: our pause tag goes");
  }
  if (const uint64_t n = freeze_dropped; n != freeze_dropped_seen) {
    freeze_dropped_seen = n;
    freeze_until = 0, freeze_test = 0;
    say("coop freeze ended: the world ran under our pause tag (a load, or the game refused the pause)");
  }
  if (const uint64_t n = freeze_reapplied; n != freeze_reapplied_seen) { // Repeats are counted by the journal.
    freeze_reapplied_seen = n;
    say("photo pause applied again: the world ran under our pause tag (a load, or the game refused the pause)");
  }
  if (!freeze_faulted || freeze_fault_logged)
    return {};
  freeze_fault_logged = true;
  char text[200];
  if (!freeze_fault_code)
    std::snprintf(text, sizeof text, "photo pause off: the game made no FName for our pause tag");
  else
    std::snprintf(text, sizeof text,
                  "photo pause off: fault 0x%08llx at StellarCoop.dll+0x%llx reading 0x%llx; our tag released, photo "
                  "sync gives notices only until the game restarts",
                  static_cast<unsigned long long>(freeze_fault_code.load()),
                  static_cast<unsigned long long>(freeze_fault_rva.load()),
                  static_cast<unsigned long long>(freeze_fault_address.load()));
  say(text);
  return "Photo sync can no longer pause this game: notices only until the game restarts.";
}

void block() {
  blocked = true;
  engine_on = false;
  fight_engine.set(false, false); // Its job ends at its next turn; the worker says why at its next pass.
  loopback_on = false;
  record_on = false; // worker_stream writes what was recorded and stops the replay.
}

std::string status() {
  std::string s = std::string("engine=") + (engine_on ? "on" : "off");
  if (blocked)
    s += " reason=coop_off";
  else if (!engine_on)
    s += " reason=" + engine_reason;
  if (engine_on && loopback_on)
    s += capture.generation ? " loopback=on " + std::to_string(loopback_delay) + " " + std::to_string(loopback_jitter) +
                                  " " + std::to_string(loopback_loss)
                            : std::string(" loopback=waiting");
  if (engine_on && recorder)
    s += " record=on"; // No seconds: each changed status line goes to UE4SS.log (the stop line gives the length).
  if (engine_on && replay.on())
    s += " replay=on";
  if (engine_on && remote.generation && remote_count) // Once coop-remote.txt was written at least once.
    s += " remote=" + std::to_string(remote.generation) + " " + std::to_string(remote_count) + " " + remote_source;
  s += fight_worker.status();
  if (nightop_on && !blocked) // Last, so Lua's unanchored remote= match still holds.
    s += poller.rule_asked() ? " nightop=rule" : " nightop=on";
  for (char &c : s)
    if (c == '\n' || c == '\r')
      c = ' ';
  return s; // Stable between events, the recording's seconds aside: per-frame counts go into the 60 s lines instead.
}
} // namespace coop::pose

// Called by Lua once per frame (package.loadlib(dll, "coop_tick")), in lua_CFunction's shape: the Lua state is
// ignored and nothing is returned to Lua. Never throws, never waits.
extern "C" __declspec(dllexport) int coop_tick(void *) noexcept {
  using namespace coop::pose;
  if (engine_on && !blocked)
    guarded_tick();
  // Its own latch: a ghost fault leaves the shared fight running, and the reverse. Once more after off: the arm rule
  // then forgets its last arm, so the next on arms at once.
  const bool fight_on = fight_engine.on();
  if ((fight_on || fight_ticked) && !blocked)
    guarded_arm();
  fight_ticked = fight_on;
  // The photo pause's own latch, after coop off too: its tag is released then, and nothing more is called.
  if (freeze_pinned && !freeze_faulted)
    guarded_freeze();
  return 0;
}
