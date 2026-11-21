// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After drone_game.inc (ghost_calls_ok), so after
// rows_game.inc, fight_game_shared.inc and freeze_game_shared.inc too: lion_gate, game_function, MakeName and
// story_scene.
// Her sounds on the ghost, the viewer's side (the ghost's fidelity, phase 5 Task 10). pose_game.inc puts each sound
// event the ghost's playback reached in the ghost's NameWait. Each frame play_tick() takes the ones whose key the
// slot's coop-loaded lines name (asset_loaded, under m), lets the nearest through the Gate (50 m from your EVE, 8 a
// second from one ghost, 32 from all, none in a scene) and plays each with SB's own calls, as SB's footstep notify
// makes them, on the ghost's actor: placed where her game played it, attached to the ghost's part when hers was.
// Nothing plays from a ghost that does not show, while the sounds look is off or before game_calls_ok(). Under the
// sounds latch (sound_game.inc): a fault turns her sounds off for the run on both sides and the ghost goes on.

namespace coop::pose {
namespace {
// SB's calls as its footstep notify FUN_142019370 makes them, 0x14201a79e to 0x14201aac2 (Ghidra, build 26123051):
// FUN_1441ff120 makes the audio component (world context RCX, sound RDX, volume and pitch in XMM2 and XMM3, a
// concurrency pointer the footstep passes 0, a bool 0, a byte 1, the owner, the pool flag); FUN_1441088f0 places it
// (location, FRotator, no sweep in R9, no hit, no teleport); SB writes its SoundClassOverride and AttenuationSettings;
// FUN_144094850 and FUN_144094900 set volume and pitch (XMM1); FUN_1441090b0 attaches it (parent, the rules at
// 0x146e15994: 01 01 01 00, KeepWorld three times; the socket FName in R9); FUN_1440944c0 sets an int parameter (its
// FName by value in RDX, the int in R8D); then its vtable +0x570, Play (FUN_1440925f0, StartTime 0.0 in XMM1).
constexpr uint64_t kMakeSound = 0x1441ff120, kPlaceSound = 0x1441088f0, kAttachSound = 0x1441090b0,
                   kSetIntParam = 0x1440944c0, kSetVolume = 0x144094850, kSetPitch = 0x144094900,
                   kAttachRules = 0x146e15994;
using MakeSound = uintptr_t (*)(uintptr_t context, uintptr_t sound, float volume, float pitch, uintptr_t concurrency,
                                bool arg6, uint8_t arg7, uintptr_t owner, bool pool);
using PlaceSound = void (*)(uintptr_t comp, const float *location, const float *rotator, bool sweep, uintptr_t hit,
                            uint8_t teleport);
using AttachSound = uint64_t (*)(uintptr_t comp, uintptr_t parent, const uint8_t *rules, uint64_t socket);
using SetIntParam = void (*)(uintptr_t comp, uint64_t name, int32_t value);
using SetFloat = void (*)(uintptr_t comp, float value);
using PlaySound = void (*)(uintptr_t comp, float start);
// AActor::bHidden: byte +0x58, bit 0x20 (its reflection params 0x1464c9cf0, set-bit function 0x1446c01a0).
constexpr size_t kActorHidden = 0x58;
constexpr uint8_t kHiddenBit = 0x20;

// One sound the ghosts asked for this frame: its slot, its event and its key's objects (copied out of asset_loaded
// under m); then its place in the world, the ghost's actor and the part it hangs on (0: placed only).
struct PlayAsk {
  size_t slot;
  Event event;
  Named named;
  float world[7];
  uintptr_t actor, part;
};
PlayAsk play_asks[Gate::kMaxAsks];
Gate::Ask play_gate_asks[Gate::kMaxAsks];
bool play_admitted[Gate::kMaxAsks];
Gate play_gate;
// The viewer's 60 s line (game thread writes, worker reads and resets).
std::atomic<uint64_t> window_play_played{0}, window_play_far{0}, window_play_ghost{0}, window_play_all{0},
    window_play_scene{0}, window_play_hidden{0}, window_play_unnamed{0}, window_play_unloaded{0};

// An int parameter's FName through SB's MakeWithNumber with FNAME_Find: 0 when SB never made that name (no sound of
// this PC reads it) or for None. rows/rows.h's split_number gives SB's own split of a trailing number.
uint64_t play_name(const char *text) {
  wchar_t wide[sba::kMaxWord + 1];
  const lion::NameParts p = lion::split_number(text);
  if (!p.len || p.len > sba::kMaxWord)
    return 0;
  for (size_t k = 0; k < p.len; ++k)
    wide[k] = wchar_t(uint8_t(text[k]));
  wide[p.len] = 0;
  const NameView view{wide, uint32_t(p.len), false};
  uint64_t out = 0;
  game_function<MakeName>(kMakeName)(&out, &view, 0, p.number);
  return uint32_t(out) && uint32_t(out) != at<uint32_t>(base + (world::kNoneName - game::kImageBase)) ? out : 0;
}

// One admitted sound: dropped (not loaded) unless its object is alive with the class Lua loaded it as and its class and
// attenuation objects are alive. Else a component of the ghost's actor, never SB's pool (writes go only to the ghost's
// own components), set up in the footstep's order with her values; the viewer's own sink records none of it.
void play_event(const PlayAsk &a) {
  const Loaded &l = a.named.loaded;
  const uintptr_t asset = static_cast<uintptr_t>(l.object);
  const auto live_or_none = [](uint64_t o) { return !o || alive(objects, static_cast<uintptr_t>(o)); };
  if (!alive(objects, asset) || at<uint64_t>(asset + kClass) != l.cls || !live_or_none(l.a) || !live_or_none(l.b)) {
    ++window_play_unloaded;
    return;
  }
  const float volume = a.event.value[0] / 64.f, pitch = a.event.value[1] / 64.f;
  sound_applying = true;
  const uintptr_t comp =
      game_function<MakeSound>(kMakeSound)(a.actor, asset, volume, pitch, 0, false, 1, a.actor, false);
  if (comp) {
    float rotator[3];
    quat_to_rotator(a.world[0], a.world[1], a.world[2], a.world[3], rotator);
    game_function<PlaceSound>(kPlaceSound)(comp, a.world + 4, rotator, false, 0, 0);
    if (l.a) // A - word: the sound keeps its own class and attenuation.
      std::memcpy(reinterpret_cast<void *>(comp + sound::kClassOverride), &l.a, sizeof l.a);
    if (l.b)
      std::memcpy(reinterpret_cast<void *>(comp + sound::kAttenuation), &l.b, sizeof l.b);
    game_function<SetFloat>(kSetVolume)(comp, volume);
    game_function<SetFloat>(kSetPitch)(comp, pitch);
    if (a.part)
      game_function<AttachSound>(kAttachSound)(
          comp, a.part, reinterpret_cast<const uint8_t *>(base + (kAttachRules - game::kImageBase)), 0);
    for (uint8_t i = 0; i < a.named.params && i < kMaxParams; ++i)
      if (const uint64_t name = play_name(a.named.param_name[i]))
        game_function<SetIntParam>(kSetIntParam)(comp, name, a.named.param_value[i]);
    game_function<PlaySound>(sound::kAudioSink[0].original)(comp, 0.f);
    ++window_play_played;
  }
  sound_applying = false;
}

// The frame's work, out of line with plain values: clang-cl catches a fault only in a function the __try calls.
__declspec(noinline) void play_body(uint64_t now_us) {
  Live &live = *session;
  const bool wanted = sounds_wanted, calls = wanted && ghost_calls_ok();
  float eve[10] = {};
  const bool have_eve = !live.capture.eve.empty() && published(objects, live.capture.eve[0]);
  if (have_eve)
    read_world(static_cast<uintptr_t>(live.capture.eve[0].object), eve);
  const bool locked = calls && m.try_lock(); // Busy: no name this frame; the events keep waiting.
  size_t n = 0;
  for (size_t slot = 0; slot < kMaxRemote; ++slot) {
    Drawn *g = live.remotes[slot].get();
    if (!g)
      continue;
    const uintptr_t root = static_cast<uintptr_t>(g->display.puppet.empty() ? 0 : g->display.puppet[0].object);
    const uintptr_t actor = alive(objects, root) ? at<uintptr_t>(root + kOuter) : 0;
    const bool hidden = !alive(objects, actor) || (at<uint8_t>(actor + kActorHidden) & kHiddenBit);
    if (!wanted) {
      g->waiting.clear();
    } else if (!ghost_shows(g->drawn(), g->ghost_gone, g->draw_root[7], hidden)) {
      window_play_hidden += g->waiting.clear();
    } else {
      auto &book = asset_loaded[slot];
      g->waiting.release(
          now_us, [&](uint16_t k) { return locked && book.count(k); },
          [&](const Event &e) {
            if (n == Gate::kMaxAsks) {
              ++window_play_all;
              return;
            }
            PlayAsk &a = play_asks[n++];
            a.slot = slot, a.event = e, a.named = book.find(e.asset)->second, a.actor = actor, a.part = root;
          });
    }
    window_play_unnamed += g->waiting.dropped() - g->waits_seen;
    g->waits_seen = g->waiting.dropped();
  }
  if (locked)
    m.unlock();
  for (size_t i = 0; i < n; ++i) { // Where each plays: hers relative to part 0 on the drawn root, or on the part.
    PlayAsk &a = play_asks[i];
    const Drawn &g = *live.remotes[a.slot];
    float parent[10];
    if (a.event.part == kNoPart) {
      std::memcpy(parent, g.draw_root, sizeof parent);
      a.part = 0;
    } else { // A part Lua did not draw (a follower, one left out) hangs it on the main mesh.
      const uintptr_t p =
          a.event.part < g.display.puppet.size() ? static_cast<uintptr_t>(g.display.puppet[a.event.part].object) : 0;
      if (p && alive(objects, p))
        a.part = p;
      read_world(a.part, parent);
    }
    sound::compose(parent, a.event.place, a.world);
    const float dx = a.world[4] - eve[4], dy = a.world[5] - eve[5], dz = a.world[6] - eve[6];
    play_gate_asks[i] = {a.slot, have_eve ? std::sqrt(dx * dx + dy * dy + dz * dz) : HUGE_VALF};
  }
  play_gate.admit(play_gate_asks, n, now_us, scene_silent(story_scene, sound_theater), play_admitted);
  window_play_far += play_gate.counts.distant, window_play_ghost += play_gate.counts.ghost;
  window_play_all += play_gate.counts.all, window_play_scene += play_gate.counts.scene;
  play_gate.counts = Gate::Counts();
  for (size_t i = 0; i < n; ++i)
    if (play_admitted[i])
      play_event(play_asks[i]);
}

// Each frame on the game thread, pinned, with the engine on and before coop off: her sounds on every ghost, under the
// sounds latch.
void play_tick() {
  if (sounds_faulted || !session)
    return;
  __try {
    play_body(clock_us());
  } __except (fault_filter(GetExceptionInformation(), sounds_fault_code, sounds_fault_rva, sounds_fault_address)) {
    sounds_faulted = true;
    sound_applying = false;
  }
}
} // namespace
} // namespace coop::pose
