// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After pose_game_shared.inc (base, objects,
// fault_filter, Live) and before pose_game.inc, which drains the rings this part fills.
// Her sounds, the sender's hooks (online/partner/sound.h): the context wrappers set a mark while SB runs one of its
// sound notifies or show sound updaters for her; the sink in the audio component's start slot records the sound SB
// picked into its thread's ring. They make no game call but the originals, through the relocated addresses the worker
// wrote before its swaps. Each frame the game thread publishes who is her for them, and names each record once
// (sound_take, which pose_game.inc's drain calls). Under their own SEH latch: a fault turns her sounds off for the run,
// the worker gives the slots back and logs it once; the ghost goes on.

namespace coop::pose {
namespace {
std::atomic<bool> sounds_faulted{false};
std::atomic<uint64_t> sounds_fault_code{0}, sounds_fault_rva{0}, sounds_fault_address{0};
// The sounds look (coop-state.txt's sounds, on until Lua says sounds=0) while the engine runs and before coop off: the
// worker sets it, the hooks read it first.
std::atomic<bool> sounds_wanted{false};
// The originals relocated to the loaded image (base + original - kImageBase), written by the worker before its first
// swap of their set; the wrappers call them.
uint64_t sound_context_run[std::size(sound::kContext)] = {}, sound_sink_run[std::size(sound::kAudioSink)] = {};
// Her, as the game thread last published it for the hooks, which may run on SB's logic thread too: her actor with its
// object index and serial (a show stage's weak pointer names her by them), her parts' components in table order and
// whether her game's theater holds a cutscene. Nobody is her while no capture goes to the loopback or a member.
std::atomic<uint64_t> sound_her{0};
std::atomic<int32_t> sound_her_index{0}, sound_her_serial{0};
std::array<std::atomic<uint64_t>, kMaxParts> sound_parts{};
std::atomic<uint32_t> sound_part_count{0};
std::atomic<bool> sound_theater{false};
std::atomic<uint32_t> sound_thread{0}; // The game thread's ID, as of its last publish.
std::atomic<uint32_t> sound_marks{0};
// Her mark on the two threads that have a ring, [0] the game thread's, [1] SB's logic thread's, each written and read
// by its own thread only: set while a context wrapper runs SB's function for her event, else 0. No thread_local: the
// DLL loads into threads that already run.
uint32_t her_mark[2] = {};
bool sound_applying = false; // Game thread: while the viewer plays her sounds, which its own sink must not take.
sound::Records sound_game_records;  // Appended by the sink on the game thread only.
sound::Records sound_logic_records; // Appended by the sink on SB's logic thread only, drained while no task runs.
// The 60 s line's counts (game thread, the other thread one by any sink).
std::atomic<uint64_t> window_sound_mark{0}, window_sound_owner{0}, window_sound_attach{0}, window_sound_other{0},
    window_sound_sent{0}, window_sound_dropped{0}, window_sound_paths{0}, window_sound_left_out{0},
    window_sound_keys{0}, window_sound_ring{0};
bool shared_scene(); // sound_worker.inc's: story_scene, which freeze_game_shared.inc declares after this part.

uint32_t sound_mark() {
  const uint32_t mark = ++sound_marks;
  return mark ? mark : ++sound_marks;
}
// The calling thread's her_mark: the game thread's (its ID as of the last publish), SB's logic thread's (the ID its
// task writes at 0x1470683b0 while it runs, 0 after: FUN_141add2f0), else nullptr.
uint32_t *sound_mark_of_thread() {
  const uint32_t me = GetCurrentThreadId();
  if (me == sound_thread)
    return &her_mark[0];
  const uint32_t logic = at<uint32_t>(base + (world::kLogicThread - game::kImageBase));
  return logic && me == logic ? &her_mark[1] : nullptr;
}
// Out of line with plain values: clang-cl catches a fault only in a function the __try calls.
// A notify's MeshComp is hers when its owner (+0xb0) is her actor or her drone.
__declspec(noinline) bool sound_mesh_read(uintptr_t mesh) {
  const uint64_t owner = game::plausible(mesh) ? at<uint64_t>(mesh + sound::kOwner) : 0;
  return owner && (owner == sound_her || owner == drone_actor);
}
// A show updater's stage (its player +0x20, the player's +0x20, as FUN_14242dd60 reads them) has her as main actor.
__declspec(noinline) bool sound_stage_read(uintptr_t updater) {
  const uintptr_t player = at<uintptr_t>(updater + sound::kUpdaterPlayer);
  const uintptr_t stage = game::plausible(player) ? at<uintptr_t>(player + sound::kPlayerStage) : 0;
  return game::plausible(stage) &&
         sound::stage_hers(at<int32_t>(stage + pilot::kStageMainWeak), at<int32_t>(stage + pilot::kStageMainWeak + 4),
                           at<uint64_t>(stage + pilot::kStageMain), sound_her, sound_her_index, sound_her_serial);
}
bool sound_mesh_hers(const void *mesh) {
  if (!sounds_wanted || sounds_faulted)
    return false;
  bool hers = false;
  __try {
    hers = sound_mesh_read(reinterpret_cast<uintptr_t>(mesh));
  } __except (fault_filter(GetExceptionInformation(), sounds_fault_code, sounds_fault_rva, sounds_fault_address)) {
    sounds_faulted = true;
  }
  return hers;
}
// No mark while her own theater holds a cutscene or a shared scene plays: scene dialogue stays out.
bool sound_stage_hers(const void *updater) {
  if (!sounds_wanted || sounds_faulted || sound_theater || shared_scene())
    return false;
  bool hers = false;
  __try {
    hers = sound_stage_read(reinterpret_cast<uintptr_t>(updater));
  } __except (fault_filter(GetExceptionInformation(), sounds_fault_code, sounds_fault_rva, sounds_fault_address)) {
    sounds_faulted = true;
  }
  return hers;
}

// ---- The context wrappers: each its slot's own prototype (CHECKS.md check 9), the same arguments to the original,
// its result back. A wrapper for another character's event clears the mark while SB's function runs; on a thread
// without a ring it marks nothing. ----
template <size_t I> void sound_notify(void *self, void *mesh, void *anim) { // Footstep, engine PlaySound.
  uint32_t *const mark = sound_mark_of_thread();
  const uint32_t was = mark ? *mark : 0;
  if (mark)
    *mark = sound_mesh_hers(mesh) ? sound_mark() : 0;
  reinterpret_cast<void (*)(void *, void *, void *)>(sound_context_run[I])(self, mesh, anim);
  if (mark)
    *mark = was;
}
void sound_character(void *self, void *mesh) {
  uint32_t *const mark = sound_mark_of_thread();
  const uint32_t was = mark ? *mark : 0;
  if (mark)
    *mark = sound_mesh_hers(mesh) ? sound_mark() : 0;
  reinterpret_cast<void (*)(void *, void *)>(sound_context_run[sound::kCharacterSound])(self, mesh);
  if (mark)
    *mark = was;
}
void sound_notify_begin(void *self, void *mesh, void *anim, float total) { // total stays in XMM3.
  uint32_t *const mark = sound_mark_of_thread();
  const uint32_t was = mark ? *mark : 0;
  if (mark)
    *mark = sound_mesh_hers(mesh) ? sound_mark() : 0;
  reinterpret_cast<void (*)(void *, void *, void *, float)>(sound_context_run[sound::kNotifyBegin])(self, mesh, anim,
                                                                                                     total);
  if (mark)
    *mark = was;
}
template <size_t I> uint64_t sound_show(void *self, int32_t a, void *b) {
  uint32_t *const mark = sound_mark_of_thread();
  const uint32_t was = mark ? *mark : 0;
  if (mark)
    *mark = sound_stage_hers(self) ? sound_mark() : 0;
  const uint64_t result = reinterpret_cast<uint64_t (*)(void *, int32_t, void *)>(sound_context_run[I])(self, a, b);
  if (mark)
    *mark = was;
  return result;
}

// ---- The sink ----
// The started component's fields when it is hers (Rule::none when not): its sound, class, attenuation, volume and
// pitch, its first int parameters, the part it hangs on and its place relative to that part (to part 0 when it hangs on
// none of hers). hers: her parts in table order, then her actor and her drone. A part that is gone keeps its place 0.
__declspec(noinline) sound::Rule sound_read(uintptr_t comp, uint32_t mark, sound::Record &r) {
  uint64_t hers[kMaxParts + 2];
  const size_t parts = std::min<size_t>(sound_part_count, kMaxParts);
  for (size_t i = 0; i < parts; ++i)
    hers[i] = sound_parts[i];
  hers[parts] = sound_her, hers[parts + 1] = drone_actor;
  if (!parts || !hers[parts])
    return sound::Rule::none;
  const uint64_t parent = at<uint64_t>(comp + sound::kAttachParent);
  r.rule = sound::rule_of(mark != 0, at<uint64_t>(comp + sound::kOwner), parent, hers, parts + 2);
  r.sound = at<uint64_t>(comp + sound::kSound);
  if (r.rule == sound::Rule::none || !game::plausible(r.sound))
    return sound::Rule::none;
  r.component = comp;
  r.cls = at<uint64_t>(comp + sound::kClassOverride);
  r.att = at<uint64_t>(comp + sound::kAttenuation);
  r.volume = at<float>(comp + sound::kVolume);
  r.pitch = at<float>(comp + sound::kPitch);
  const uintptr_t params = at<uintptr_t>(comp + sound::kParams);
  const int32_t count = at<int32_t>(comp + sound::kParamCount);
  for (int32_t i = 0; game::plausible(params) && i < count && i < 256; ++i) {
    const uintptr_t e = params + uintptr_t(i) * sound::kParamBytes;
    if (at<float>(e + sound::kParamFloat) != 0 || at<uint8_t>(e + sound::kParamBool) ||
        at<uint64_t>(e + sound::kParamWave) || r.params == sound::kMaxParams) {
      r.left_out += r.left_out < 255;
      continue;
    }
    r.param_name[r.params] = at<uint64_t>(e);
    r.param_value[r.params++] = at<int32_t>(e + sound::kParamInt);
  }
  for (size_t i = 0; i < parts; ++i)
    if (hers[i] == parent)
      r.part = uint8_t(i);
  const uintptr_t frame = static_cast<uintptr_t>(hers[r.part == kNoPart ? 0 : r.part]);
  if (alive(objects, frame)) {
    float from[10], to[10], place[7];
    read_world(frame, from);
    read_world(comp, to);
    relative(from, to, place);
    std::memcpy(r.place, place, sizeof place);
  }
  return r.rule;
}
// Records it on the game thread or SB's logic thread, each into its own ring, under the mark of the context wrapper
// SB is in; on another thread a start of hers is counted only. Nothing while the viewer plays her sounds.
void sound_capture(uintptr_t comp) {
  const uint32_t *const slot = sound_mark_of_thread();
  const bool on_game = slot == &her_mark[0], on_logic = slot == &her_mark[1];
  const uint32_t mark = slot ? *slot : 0;
  sound::Record r;
  sound::Rule rule = sound::Rule::none;
  __try {
    rule = sound_read(comp, mark, r);
  } __except (fault_filter(GetExceptionInformation(), sounds_fault_code, sounds_fault_rva, sounds_fault_address)) {
    sounds_faulted = true;
    return;
  }
  if (sound::records(on_game && sound_applying, on_game || on_logic, rule))
    (on_game ? sound_game_records : sound_logic_records).add(r, mark);
  else if (rule != sound::Rule::none && !on_game && !on_logic)
    ++window_sound_other;
}
// UAudioComponent::Play's slot in both audio classes (this, float StartTime in XMM1), void.
template <size_t I> void sound_play(void *self, float start) {
  if (sounds_wanted && !sounds_faulted)
    sound_capture(reinterpret_cast<uintptr_t>(self));
  reinterpret_cast<void (*)(void *, float)>(sound_sink_run[I])(self, start);
}

// ---- The game thread, each frame ----
// Who is her for the hooks: her actor (her main mesh's owner) and her parts while her capture goes to the loopback or
// a member and her sounds are wanted, else nobody; whether her game's theater holds a cutscene (story::kManagerAt's
// current theater).
__declspec(noinline) void sound_publish_read(const Live *live) {
  const auto read = [](uint64_t a, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(a), n);
    return true;
  };
  uint64_t her = 0;
  int32_t index = 0, serial = 0;
  uint32_t n = 0;
  if (live && live->capture.generation && !live->capture.eve.empty() && (loopback_on || peer_on) && sounds_wanted &&
      published(objects, live->capture.eve[0])) {
    her = at<uint64_t>(static_cast<uintptr_t>(live->capture.eve[0].object) + sound::kOwner);
    if (!pilot::live(read, objects, her, &index, &serial))
      her = 0;
    for (size_t i = 0; her && i < live->capture.eve.size() && i < kMaxParts; ++i)
      sound_parts[n++] = live->capture.eve[i].object;
  }
  sound_her_index = index, sound_her_serial = serial;
  sound_part_count = n;
  sound_her = her;
  const uintptr_t manager = at<uintptr_t>(base + (story::kManagerAt - game::kImageBase));
  sound_theater = game::plausible(manager) && game::plausible(at<uintptr_t>(manager + story::kCurrent));
}
void sound_publish(const Live *live) {
  sound_thread = GetCurrentThreadId();
  if (sounds_faulted)
    return;
  __try {
    sound_publish_read(live);
  } __except (fault_filter(GetExceptionInformation(), sounds_fault_code, sounds_fault_rva, sounds_fault_address)) {
    sounds_faulted = true;
    sound_her = 0;
  }
}
// One record into the outbox: its asset key (known by its objects, else its words read once from the name pool and a
// fresh key's SBA line into lines), then its event. A sound whose path is refused is dropped and counted; a volume
// or pitch past the event's byte is cut and counted in clamped (the stream line's values cut).
__declspec(noinline) void sound_take_body(const sound::Record &r, AssetKeys &keys, Outbox &out,
                                          std::vector<std::string> &lines, uint64_t now_us, uint32_t &clamped) {
  const auto read = [](uint64_t a, void *out, size_t n) {
    std::memcpy(out, reinterpret_cast<const void *>(a), n);
    return true;
  };
  int32_t index = 0, serial = 0;
  if (!pilot::live(read, objects, r.sound, &index, &serial)) {
    ++window_sound_paths;
    return;
  }
  const uint64_t b = sound::keyed_attenuation(r);
  uint16_t k = keys.known(Kind::sound, r.sound, r.cls, b, index, serial);
  if (!k) {
    uint64_t left_out = 0;
    const std::string words =
        sound::record_words(read, base + (pilot::kNamePool - game::kImageBase), r, left_out);
    window_sound_left_out += left_out;
    if (words.empty()) {
      ++window_sound_paths;
      return;
    }
    bool fresh = false;
    if (!(k = keys.add(Kind::sound, r.sound, r.cls, b, index, serial, words, fresh))) {
      ++window_sound_keys;
      return;
    }
    if (fresh)
      lines.push_back(asset_tag() + " " + std::to_string(k) + " " + words);
  }
  Event e;
  e.kind = Kind::sound;
  e.asset = k;
  e.part = r.part;
  e.value[0] = value_byte(r.volume, 64, clamped);
  e.value[1] = value_byte(r.pitch, 64, clamped);
  std::memcpy(e.place, r.place, sizeof e.place);
  if (out.push(e, now_us))
    ++window_sound_sent;
}
void sound_take(const sound::Record &r, AssetKeys &keys, Outbox &out, std::vector<std::string> &lines,
                uint64_t now_us, uint32_t &clamped) {
  ++(r.rule == sound::Rule::mark ? window_sound_mark : r.rule == sound::Rule::owner ? window_sound_owner
                                                                                     : window_sound_attach);
  window_sound_left_out += r.left_out;
  __try {
    sound_take_body(r, keys, out, lines, now_us, clamped);
  } __except (fault_filter(GetExceptionInformation(), sounds_fault_code, sounds_fault_rva, sounds_fault_address)) {
    sounds_faulted = true;
  }
}
} // namespace
} // namespace coop::pose
