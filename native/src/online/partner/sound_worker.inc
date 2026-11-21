// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After fight_worker_shared.inc (swap_slot,
// slot_value, Filter) and freeze_game_shared.inc (story_scene).
// Her sounds, the worker's side (online/partner/sound.h): the originals relocated once a run, then three sets swapped
// apart, each all or none. The context set while sounds or her world effects are wanted, the audio sinks while
// sounds are, the world-effect sinks while effects are. A set another mod's hook refuses stays as it is for the run.
// sound_undo gives the sound sets back at coop off and after a sounds fault, worldfx_undo the world-effect set at coop
// off and after a world effects fault; a look turned off gives a set back until it is on again.

namespace coop::pose {
namespace {
bool shared_scene() { return story_scene; }

// Ours, in each set's order: the wrapper of each context entry, the sink in both audio classes' slot, the sinks in the
// Niagara and Cascade start slots.
const uint64_t sound_context_ours[] = {
    reinterpret_cast<uintptr_t>(&sound_notify<sound::kFootstep>),
    reinterpret_cast<uintptr_t>(&sound_character),
    reinterpret_cast<uintptr_t>(&sound_notify_begin),
    reinterpret_cast<uintptr_t>(&sound_show<sound::kShowFirst>),
    reinterpret_cast<uintptr_t>(&sound_show<sound::kShowFirst + 1>),
    reinterpret_cast<uintptr_t>(&sound_show<sound::kShowLast>),
    reinterpret_cast<uintptr_t>(&sound_notify<sound::kEnginePlaySound>)};
const uint64_t sound_sink_ours[] = {reinterpret_cast<uintptr_t>(&sound_play<0>),
                                    reinterpret_cast<uintptr_t>(&sound_play<1>)};
const uint64_t worldfx_sink_ours[] = {reinterpret_cast<uintptr_t>(&worldfx_start<sound::kNiagaraSink>),
                                      reinterpret_cast<uintptr_t>(&worldfx_start<sound::kCascadeSink>)};
static_assert(std::size(sound_context_ours) == std::size(sound::kContext) &&
              std::size(sound_sink_ours) == std::size(sound::kAudioSink) &&
              std::size(worldfx_sink_ours) == std::size(sound::kWorldSink));
// feature: the words its log lines start with and what the ghost goes on without.
struct SoundSet {
  const sound::Hook *hooks;
  size_t n;
  uint64_t *run;
  const uint64_t *ours;
  const char *what, *feature;
  Filter state;
};
SoundSet sound_sets[] = {{sound::kContext, std::size(sound::kContext), sound_context_run, sound_context_ours,
                          "her events' context", "sounds", Filter::untried},
                         {sound::kAudioSink, std::size(sound::kAudioSink), sound_sink_run, sound_sink_ours,
                          "audio starts", "sounds", Filter::untried},
                         {sound::kWorldSink, std::size(sound::kWorldSink), worldfx_sink_run, worldfx_sink_ours,
                          "world effect starts", "world effects", Filter::untried}};
constexpr size_t kWorldSet = 2;
bool sound_relocated = false;

std::string sound_hex(uint64_t v) {
  char text[24];
  std::snprintf(text, sizeof text, "0x%llx", static_cast<unsigned long long>(v));
  return text;
}
// One set from the game's functions to ours, all or none.
void sound_swap_in(SoundSet &s) {
  uint64_t slots[std::size(sound::kContext)], last = 0;
  bool page = true, refused = false; // What the refused slot held, before the swaps back.
  for (size_t i = 0; i < s.n; ++i)
    slots[i] = s.hooks[i].slot;
  const size_t done = sound::swap_all(slots, s.run, s.ours, s.n,
                                      [&](uint64_t slot, uint64_t from, uint64_t to, uint64_t &held) {
                                        const bool ok = swap_slot(slot, from, to, held);
                                        if (!refused && (!ok || held != from))
                                          refused = true, page = ok, last = held;
                                        return ok;
                                      });
  s.state = done == s.n ? Filter::on : Filter::refused;
  const std::string feature = s.feature;
  if (s.state == Filter::on)
    say(feature + " on: " + std::to_string(s.n) + " slots swapped (" + s.what + ")");
  else
    say(feature + " refused: " + sound_hex(slots[done]) +
        (page ? " holds " + slot_value(last) : std::string(" would not become writable")) +
        "; nothing of that set swapped, the ghost goes on without " + feature + " (" + s.what + ")");
}
// One set back from ours to the game's functions, by a compare-and-swap from ours only: a slot that holds anything
// else is left as it is. A hook left in place only runs the game's function once sounds_wanted is false.
void sound_give_back(SoundSet &s, const char *why, Filter after) {
  if (s.state != Filter::on)
    return;
  s.state = after;
  for (size_t i = 0; i < s.n; ++i) {
    uint64_t held = 0;
    const std::string head =
        std::string(s.feature) + ": " + s.what + " slot off (" + why + "): " + sound_hex(s.hooks[i].slot);
    if (!swap_slot(s.hooks[i].slot, s.ours[i], s.run[i], held))
      say(head + " would not become writable; our hook stays in it and only runs the game's function");
    else if (held != s.ours[i])
      say(head + " holds " + slot_value(held) + ", left as it is");
  }
}
// coop off (block()) and after a sounds fault: the context and audio sets back, neither swapped again this run.
void sound_undo(const char *why) {
  sounds_wanted = false;
  for (size_t k = 0; k < kWorldSet; ++k) {
    sound_give_back(sound_sets[k], why, Filter::off);
    sound_sets[k].state = Filter::off;
  }
}
// coop off (block()) and after a world effects fault: the world-effect set back, not swapped again this run.
void worldfx_undo(const char *why) {
  worldfx_wanted = false;
  sound_give_back(sound_sets[kWorldSet], why, Filter::off);
  sound_sets[kWorldSet].state = Filter::off;
}

// Worker, every 250 ms after coop-state.txt is read: sounds the sounds look. The effects look is on while her capture
// names effect lines or a ghost's display names effect boxes (Lua writes neither with effects off). On the pinned build
// with the engine on and before coop off, the originals are relocated once, then each set swaps in while wanted (once:
// a refused set stays refused) and back while not. After a sounds fault the sound sets go back, after a world effects
// fault the world-effect set; the other feature goes on.
void sound_pass(bool sounds) {
  if (!pinned || blocked)
    return;
  if (sounds_faulted && (sound_sets[0].state != Filter::off || sound_sets[1].state != Filter::off))
    sound_undo("a fault");
  if (worldfx_faulted && sound_sets[kWorldSet].state != Filter::off)
    worldfx_undo("a fault");
  bool effects = capture.fx.cls != 0;
  for (const Remote &r : remotes)
    effects = effects || r.display.effects[0];
  sounds_wanted = sounds && engine_on && !sounds_faulted;
  worldfx_wanted = effects && engine_on && !worldfx_faulted;
  if (!engine_on)
    return;
  if (!sound_relocated) {
    for (SoundSet &s : sound_sets)
      for (size_t i = 0; i < s.n; ++i)
        s.run[i] = base + (s.hooks[i].original - game::kImageBase);
    sound_relocated = true;
  }
  // Each look without its faulted feature: the context set goes back once neither feature uses it.
  const bool want[] = {sound::context_wanted(sounds_wanted, worldfx_wanted), sounds_wanted, worldfx_wanted};
  static_assert(std::size(want) == std::size(sound_sets));
  for (size_t k = 0; k < std::size(sound_sets); ++k) {
    SoundSet &s = sound_sets[k];
    if (want[k] && s.state == Filter::untried)
      sound_swap_in(s);
    else if (!want[k])
      sound_give_back(s, k == kWorldSet ? "effects look off" : k ? "sounds look off" : "sounds and effects looks off",
                      Filter::untried);
  }
}

// coop-status.txt's sounds word: fault after its latch, refused when a set was refused, on while the audio sinks are
// ours, else off.
std::string sound_status() {
  if (sounds_faulted)
    return "fault";
  if (sound_sets[0].state == Filter::refused || sound_sets[1].state == Filter::refused)
    return "refused";
  return sound_sets[1].state == Filter::on && sounds_wanted ? "on" : "off";
}
// Its world_effects word, the same way for the world-effect set (the context set's refusal shows in the sounds word).
std::string worldfx_status() {
  if (worldfx_faulted)
    return "fault";
  if (sound_sets[kWorldSet].state == Filter::refused)
    return "refused";
  return sound_sets[kWorldSet].state == Filter::on && worldfx_wanted ? "on" : "off";
}
} // namespace
} // namespace coop::pose
