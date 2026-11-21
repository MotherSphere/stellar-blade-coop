// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The ghost's pose path, the game thread's half: the shared state, EVE's read and encode, the ghost's write, coop_tick's body.

namespace coop::pose {
namespace {
std::atomic<int> current_part{-1}; // The part being read or written, for the fault line.
// Effects' own latch (ROADMAP 4.8): the game thread turns them off at their first fault, the worker logs it once.
std::atomic<bool> effects_on{true};
std::atomic<uint64_t> fx_fault_code{0}, fx_fault_rva{0}, fx_fault_address{0};
std::atomic<int> fx_fault_part{-1};
// Her face and shape keys' own latch: her parts' weights read and the ghosts' written here (memory only), the arrays
// reserved and the dirty calls in play_game.inc. The first fault turns faces off for the run, the worker logs it once.
// The counters of the worker's 60 s line: parts read, weights cut, parts written, dirty calls, reads and writes
// refused.
std::atomic<bool> faces_faulted{false};
std::atomic<uint64_t> faces_fault_code{0}, faces_fault_rva{0}, faces_fault_address{0};
std::atomic<uint64_t> window_faces_read{0}, window_faces_clamped{0}, window_faces_written{0}, window_faces_dirty{0},
    window_faces_refused{0};

std::atomic<uint32_t> loopback_delay{0}, loopback_jitter{0}, loopback_loss{0};
std::atomic<uint32_t> loopback_epoch{0}; // Bumped by every settings change: the playback's clock starts again.

// An encoded pose on its way: bytes (sized kMaxPose once, by the worker, before the engine goes on; only swapped after
// that), its size, when it was read (outgoing) or received (incoming), in µs, and the ghost slot it came for
// (incoming).
struct Message {
  std::vector<uint8_t> data;
  size_t size = 0;
  uint64_t time = 0;
  uint8_t slot = 0;
};

// Hand-over, guarded by m: the worker's newest Live (or a withdrawal) for the game thread, and the game thread's
// result lines for the worker to log; the newest encoded pose for the worker (out_fresh), and the poses the worker got
// back for the game thread.
std::mutex m;
std::unique_ptr<Live> incoming;
bool incoming_set = false;
// The capture's effect lines changed under one generation (Lua named a new system by an fx line): the game thread puts
// them in its Live of that generation, with no new Live (which would restart her ghost's playback). A plain copy.
Table::Fx fx_incoming;
uint64_t fx_incoming_generation = 0;
bool fx_incoming_set = false;
std::vector<std::string> outbox;
// Her asset names (game/events.h's SBA lines), under m too: the lines the game thread named since the worker's last
// asset_lines(); asset_keys_reset, set by asset_keys_clear() at a link session's start or end (the game thread takes it
// in its next hold of m and drops its asset keys before it names another asset); each ghost slot's loaded
// objects by key, from the slot's coop-loaded file, with the kind and the int parameters her SBA line named for that
// key (the worker writes them in place; asset_slot_reset() empties one; play_game.inc copies an entry out under m).
std::vector<std::string> asset_named;
bool asset_keys_reset = false;
struct Named {
  Loaded loaded{};
  Kind kind = Kind::sound; // Lua loaded the object as this kind: an event of another kind never plays it.
  uint8_t params = 0;
  char param_name[kMaxParams][sba::kMaxWord + 1] = {};
  int32_t param_value[kMaxParams] = {};
  // The paths her SBA line names for the object, a and b ("" for none): play_game.inc checks that each object is still
  // the asset at its path (sound::is_asset).
  std::string path[3];
};
std::array<std::unordered_map<uint16_t, Named>, kMaxRemote> asset_loaded;
// The game thread's: our asset keys for this link session, our events on their way into the pose's event slots, the
// fresh SBA lines not handed over yet. asset_keys_stale: a reset taken under m, carried out right after it (the keys,
// lines and events of the session before are dropped).
AssetKeys asset_keys;
Outbox event_outbox;
std::vector<std::string> asset_waiting;
bool asset_keys_stale = false;
uint64_t ring_over_seen[2] = {}, outbox_dropped_seen = 0; // For the sounds line's deltas.
Message out_mid;
bool out_fresh = false;
std::array<Message, kInbox> inbox;
size_t inbox_count = 0;
// Each native tick gap over 100 ms, for the worker's line (game/core.h's gap_line): its end as a FILETIME, its length,
// the frame it ended in and the coop_tick before it, in µs. The worker takes them every 250 ms, with the outbox.
struct Gap {
  uint64_t filetime, gap_us, frame, tick_us;
};
std::array<Gap, 8> gaps;
size_t gap_count = 0;

uint64_t last_frame = 0, next_capture = 0;
uint64_t coop_tick_us = 0; // The last coop_tick's own time, entry to exit.
Gap gap_waiting{};         // A gap not in gaps yet (the lock was busy, or gaps was full)...
bool gap_held = false;     // ...while this is set. A newer gap takes its place: the 60 s line counts both.
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
// 60), and never more than the link's cap (link/pose_cap.h PoseCap). The worker stores it, the game thread reads it.
std::atomic<uint64_t> send_us{50'000};

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
std::atomic<const char *> last_reject{"none"}; // decode_pose's reason.
// The ghost bench's game thread half, online/partner/bench_game.inc's (after this part): game_tick hands it each
// frame's new list, gap, own time and her Live.
void bench_take();
void bench_gap(uint64_t gap_us);
void bench_tick(uint64_t us);
void bench_stream(const Live &live);

// The encoded pose to the worker (m held): replaces one it has not taken yet, which the receiver counts missing; but a
// keyframe not taken yet stays and a delta, which names it, is dropped instead (keeps_waiting, in game/codec.h's
// hand_over, which stream_test runs on the build machine).
void give_out() { hand_over(out_back, out_mid, out_fresh, out_ready); }

uint64_t micros_between(LARGE_INTEGER a, LARGE_INTEGER b) {
  return frequency.QuadPart ? uint64_t((b.QuadPart - a.QuadPart) * 1000000 / frequency.QuadPart) : 0;
}
void raise_max(std::atomic<uint64_t> &slot, uint64_t value) {
  uint64_t seen = slot.load();
  while (value > seen && !slot.compare_exchange_weak(seen, value))
    ;
}

// Effects under their own latch. clang-cl catches a fault only in a function the __try calls, never in code inlined
// into the __try's own frame, so the accesses stay out of line; the guarded functions hold plain data only.
__declspec(noinline) void effects_read(Live &live) {
  read_effects(objects, live.capture, fx_state, live.capture_fx, fx_counts);
}
// The boxes whose slot changed since last written; false when one was refused (written again next frame).
__declspec(noinline) bool effects_write(Drawn &ghost, uint64_t &written) {
  const Display &d = ghost.display;
  bool all = true;
  for (size_t n = 0; n < kEffectSlots; ++n) {
    const Effect &e = ghost.draw_fx[n], &was = ghost.fx_drawn[n];
    if (e.asset == was.asset && e.part == was.part && e.serial == was.serial &&
        !std::memcmp(e.place, was.place, sizeof e.place))
      continue;
    if (write_effect_box(objects, d.effects[n], d.mailbox_class, d.puppet[0], e) != Io::ok) {
      all = false;
      continue;
    }
    ghost.fx_drawn[n] = e;
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
bool guarded_effects_write(Drawn &ghost) {
  uint64_t written = 0;
  bool all = false;
  __try {
    all = effects_write(ghost, written);
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

// Her weights: each part with a morphs line, from its leader object or its morph_read component, into capture_morphs.
__declspec(noinline) void faces_read(Live &live, uint64_t &read, uint64_t &refused, uint32_t &clamped) {
  const Table &t = live.capture;
  size_t offset = 0;
  for (size_t i = 0; i < t.eve.size(); ++i) {
    const size_t n = t.look[i].morphs.size();
    if (!n)
      continue;
    current_part = static_cast<int>(i);
    const uint64_t component = t.eve[i].leader ? t.eve[i].object : t.look[i].morph_read;
    ++(read_morphs(objects, t.eve[i], component, n, live.capture_morphs.data() + offset, clamped) == Io::ok ? read
                                                                                                           : refused);
    current_part = -1;
    offset += n;
  }
}
// Under the faces latch: the first fault zeroes her weights (a neutral face on every ghost) and turns faces off.
void guarded_faces_read(Live &live) {
  uint64_t read = 0, refused = 0;
  uint32_t clamped = 0;
  __try {
    faces_read(live, read, refused, clamped);
  } __except (fault_filter(GetExceptionInformation(), faces_fault_code, faces_fault_rva, faces_fault_address)) {
    faces_faulted = true;
    current_part = -1;
    std::memset(live.capture_morphs.data(), 0, live.capture_morphs.size());
  }
  window_faces_read += read, window_faces_refused += refused, window_faces_clamped += clamped;
}
// The component remote part i's weights go on, as Lua's display names it: live, of the root part's class (a Poseable,
// so never the cloth follower), on the named mesh and of the ghost's own actor (UObject outer). Else 0.
uintptr_t morph_target(const Drawn &g, size_t i) {
  const Part &root = g.display.puppet[0];
  Part p = g.display.morph_part[i];
  p.cls = root.cls;
  return p.object && published(objects, p) && alive(objects, static_cast<uintptr_t>(root.object)) &&
                 at<uintptr_t>(static_cast<uintptr_t>(p.object) + kOuter) ==
                     at<uintptr_t>(static_cast<uintptr_t>(root.object) + kOuter)
             ? static_cast<uintptr_t>(p.object)
             : 0;
}
// The weights drawn this frame into each part Lua named, by its morph map; a part whose weights changed is marked for
// play_game.inc's dirty call. The first refusal's part and reason go to refused_part and refused_io.
__declspec(noinline) void faces_write(Drawn &ghost, uint64_t &written, uint64_t &refused, int &refused_part,
                                      Io &refused_io) {
  const Display &d = ghost.display;
  const Table &remote = ghost.remote;
  size_t offset = 0;
  for (size_t i = 0; i < remote.eve.size() && i < d.morph_map.size(); ++i) {
    const size_t n = remote.look[i].morphs.size();
    if (n && d.morph_map[i].size() == n) {
      current_part = static_cast<int>(i);
      const uintptr_t object = morph_target(ghost, i);
      Part p = d.morph_part[i];
      p.cls = d.puppet[0].cls;
      bool changed = false;
      const Io r = object ? write_morphs(objects, p, ghost.draw_morphs.data() + offset, d.morph_map[i].data(), n,
                                         ghost.mesh_morphs[i], changed)
                          : Io::gone;
      current_part = -1;
      if (r != Io::ok) {
        if (!refused++)
          refused_part = static_cast<int>(i), refused_io = r;
      } else if (changed) {
        ++written;
        ghost.morphs_dirty |= 1u << i;
      }
    }
    offset += n;
  }
}
// Under the faces latch; false when a part was refused (logged the first time on this ghost) or faulted.
bool guarded_faces_write(Drawn &ghost) {
  uint64_t written = 0, refused_count = 0;
  int part = -1;
  Io why = Io::ok;
  bool faulted_now = false;
  __try {
    faces_write(ghost, written, refused_count, part, why);
  } __except (fault_filter(GetExceptionInformation(), faces_fault_code, faces_fault_rva, faces_fault_address)) {
    faces_faulted = true;
    faulted_now = true;
    current_part = -1;
  }
  window_faces_written += written, window_faces_refused += refused_count;
  if (refused_count)
    refused(ghost, part, why);
  return !refused_count && !faulted_now;
}

// Her sounds and world effects the hooks recorded since the last frame (the logic thread's ring only while no logic
// task runs), into the asset keys and the event outbox while her capture goes to the loopback or a member; else
// dropped. Each kind under its own latch. Each frame, before the capture: an event waits for its slot from the frame SB
// played it in.
void events_drain(const Live &live, uint64_t now_us) {
  const auto read = [](uint64_t a, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(a), n);
    return true;
  };
  window_sound_dropped += event_outbox.dropped() - outbox_dropped_seen;
  outbox_dropped_seen = event_outbox.dropped();
  sound::Record taken[sound::Records::kEntries];
  uint32_t clamped = 0;
  for (size_t ring = 0; ring < 2; ++ring) {
    if (ring == 1 && pilot::logic_busy(read, base))
      break;
    sound::Records &records = ring ? sound_logic_records : sound_game_records;
    const size_t n = records.take(taken, std::size(taken));
    for (size_t i = 0; (loopback_on || peer_on) && i < n; ++i)
      if (taken[i].kind == Kind::sound) {
        if (!sounds_faulted)
          sound_take(taken[i], asset_keys, event_outbox, asset_waiting, now_us, clamped);
      } else if (!worldfx_faulted) {
        worldfx_take(taken[i], live.capture, asset_keys, event_outbox, asset_waiting, now_us, clamped);
      }
    window_sound_ring += records.over() - ring_over_seen[ring];
    ring_over_seen[ring] = records.over();
  }
  window_clamped += clamped;
}

// The pose drawn this frame into the ghost: each remote leader Lua built a part for, as it came or through its remap,
// with the box of a free part (her drone) Lua named, then her weights on the parts Lua named for them, its effect
// boxes and the mailbox. True when every write
// passed its checks.
bool write_puppet(Drawn &ghost) {
  const Table &remote = ghost.remote;
  const Display &d = ghost.display;
  size_t offset = 0, k = 0;
  bool all = true;
  for (size_t i = 0; i < remote.eve.size(); ++i) {
    if (!remote.eve[i].leader)
      continue;
    const Part &p = d.puppet[i];
    if (p.object) { // Else left out: its bytes are skipped.
      const uint8_t *bones = ghost.draw.data() + offset;
      current_part = static_cast<int>(i);
      Io r = d.remap[i].empty() ? write_leader(objects, p, bones)
                                : write_leader_mapped(objects, p, bones, d.remap[i].data(), remote.eve[i].bones);
      current_part = -1;
      if (r != Io::ok) {
        all = false;
        refused(ghost, static_cast<int>(i), r);
      }
    }
    offset += size_t(remote.eve[i].bones) * kTransformBytes;
    if (remote.eve[i].free && d.free_box[i] &&
        write_free_box(objects, d.free_box[i], d.mailbox_class, d.puppet[0], ghost.draw_free[k]) != Io::ok) {
      all = false;
      refused(ghost, -3, Io::gone);
    }
    k += remote.eve[i].free;
  }
  if (!faces_faulted && ghost.morphs_reserved && !guarded_faces_write(ghost)) // Her face: after the bones.
    all = false;
  if (effects_on && d.effects[0] && !guarded_effects_write(ghost)) {
    all = false;
    if (effects_on) // Refused, not faulted: a fault has its own line.
      refused(ghost, -2, Io::gone);
  }
  stamp = stamp >= 1e6f ? 2.f : stamp + 1.f;
  if (write_mailbox(objects, d.mailbox, d.mailbox_class, d.puppet[0], ghost.draw_root, fx_stamp, stamp) != Io::ok) {
    all = false;
    refused(ghost, -1, Io::gone);
  }
  return all;
}

// Each frame: EVE's pose every send interval while the byte budget allows, encoded as a keyframe or a delta for the
// worker, while it sends; the poses the worker got back, each decoded with its slot's remote table into that slot's
// playback, once Lua built the ghost for it; each playback's pose for now, written into its ghost.
void stream(uint64_t now_us) {
  Live &live = *session;
  if (uint32_t epoch = loopback_epoch.load(); epoch != seen_epoch) {
    seen_epoch = epoch; // New settings: the poses in flight were dropped, and the old delay must not pass for a step.
    if (live.remotes[0]) // The loopback feeds slot 0 only.
      live.remotes[0]->playback.clear();
  }
  events_drain(live, now_us);
  const bool capture_due = (loopback_on || record_on || peer_on) && live.capture.generation && now_us >= next_capture;
  if (capture_due && !live.encoder.due(now_us, pilot_sending)) {
    ++window_held; // The byte budget is spent: read again next frame.
  } else if (capture_due) {
    Io r = read_pose(objects, live.capture, live.capture_root, live.capture_bones.data(), live.capture_free,
                     current_part);
    if (r == Io::ok) {
      uint64_t every = send_us.load(std::memory_order_relaxed);
      next_capture = (next_capture && now_us - next_capture < every ? next_capture : now_us) + every;
      if (effects_on && live.capture.fx.cls) // Only with effect lines: Lua sends none while effects are off.
        guarded_effects_read(live);
      else
        for (Effect &e : live.capture_fx)
          e = Effect();
      if (!faces_faulted && !live.capture_morphs.empty()) // Only with morphs lines: Lua sends none with faces off.
        guarded_faces_read(live);
      PoseHeader h;
      h.generation = live.capture.generation;
      h.publication = now_us;
      h.sequence = ++sequence;
      uint32_t clamped = 0;
      if (lost_key(out_back, out_ready)) // A keyframe the worker never got: overwritten.
        live.encoder.lose();
      Event events[kEventSlots];
      event_outbox.fill(events, now_us, every);
      sound::fit_parts(events, live.capture.eve.size()); // An event recorded under an earlier, larger table.
      size_t size = encode_pose(live.capture, h, live.capture_root, live.capture_bones.data(), live.capture_fx,
                                out_back.data.data(), clamped, live.capture_free, events, live.capture_morphs.data());
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
    const Message &in = game_inbox[i];
    Drawn *ghost = live.remotes[in.slot].get(); // The worker's slots are below kMaxRemote.
    if (!ghost || !ghost->drawn()) { // No ghost for the slot's remote table yet, or no remote table.
      ++window_foreign;
      continue;
    }
    Playback::Frame &f = ghost->playback.scratch();
    PoseHeader h;
    if (const char *why = ghost->decoder.decode(ghost->remote, in.data.data(), in.size, h, f.root, f.bones.data(), f.fx,
                                                f.free, f.events, f.morphs.data())) {
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
    ghost->playback.accept(in.time);
  }
  for (const std::unique_ptr<Drawn> &slot : live.remotes) {
    if (!slot)
      continue;
    Drawn &ghost = *slot;
    if (ghost.drawn() && !ghost.ghost_gone) {
      // Lua destroys a ghost (a level change, coop puppet, coop basesuit) and withdraws its display in the same frame,
      // but the worker reads that withdrawal only within 250 ms: a destroyed ghost is no refused write, just the end.
      if (!alive(objects, static_cast<uintptr_t>(ghost.display.puppet[0].object)))
        ghost.ghost_gone = true;
      else if (ghost.playback.sample(now_us, ghost.draw_root, ghost.draw.data(), ghost.draw_fx, ghost.draw_free,
                                     ghost.draw_morphs.data())) {
        ++(write_puppet(ghost) ? window_drawn_written : window_drawn_refused);
        ghost.drawn_at = now_us;
        // Her sounds and world effects the playback reached go to wait for their names (a world effect only while
        // the ghost has effect boxes: the viewer's effects look): play_game.inc plays them, no game call here.
        Event passed[NameWait::kHeld];
        const size_t n = ghost.playback.passed(passed, std::size(passed));
        for (size_t k = 0; k < n; ++k)
          if (passed[k].kind == Kind::sound)
            ghost.waiting.hold(passed[k], now_us);
          else if ((passed[k].kind == Kind::niagara || passed[k].kind == Kind::cascade) && ghost.display.effects[0])
            ghost.fx_waiting.hold(passed[k], now_us);
      }
    }
    Playback::Stats s = ghost.playback.take(); // Summed over the slots: the 60 s line's means stay per pose.
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
    bench_gap(gap);
    if (gap > 100000) {
      ++window_long_gaps;
      FILETIME utc;
      GetSystemTimePreciseAsFileTime(&utc);
      gap_waiting = {uint64_t(utc.dwHighDateTime) << 32 | utc.dwLowDateTime, gap, frame, coop_tick_us};
      gap_held = true;
    }
  }
  last_call = now;
  ++ticks;
  if (m.try_lock()) { // Nothing allocates under the lock: swaps only. The worker frees what it gets back.
    if (incoming_set) {
      session.swap(incoming);
      incoming_set = false;
    }
    if (fx_incoming_set) {
      if (session && session->capture.generation == fx_incoming_generation)
        session->capture.fx = fx_incoming;
      fx_incoming_set = false;
    }
    if (outbox.empty())
      outbox.swap(pending);
    if (out_ready) // A pose whose own hand-over found the lock busy.
      give_out();
    if (inbox_count) { // game_inbox_count is 0: every tick ends by emptying it.
      inbox.swap(game_inbox);
      std::swap(inbox_count, game_inbox_count);
    }
    if (gap_held && gap_count < gaps.size()) {
      gaps[gap_count++] = gap_waiting;
      gap_held = false;
    }
    if (asset_keys_reset) // A link session started or ended: our lines named since are of the session before.
      asset_keys_reset = false, asset_keys_stale = true;
    else if (asset_named.empty())
      asset_named.swap(asset_waiting);
    m.unlock();
  }
  bench_take();
  if (asset_keys_stale) {
    asset_keys.clear();
    asset_waiting.clear();
    event_outbox = Outbox();
    outbox_dropped_seen = 0;
    asset_keys_stale = false;
  }
  sound_publish(session.get());
  if (session)
    stream(micros_now(now));
  else
    window_foreign += game_inbox_count; // No table at all: nothing to decode them with.
  if (session)
    bench_stream(*session); // After the members' ghosts.
  game_inbox_count = 0;
  LARGE_INTEGER done;
  QueryPerformanceCounter(&done);
  uint64_t us = micros_between(now, done);
  window_ticks++;
  window_us += us;
  raise_max(window_max_us, us);
  bench_tick(us);
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
