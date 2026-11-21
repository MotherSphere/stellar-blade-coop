// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there). After fight_worker_shared.inc (swap_slot,
// slot_value, Filter) and freeze_game_shared.inc (story_scene).
// Her sounds, the worker's side (online/partner/sound.h): the originals relocated once a run, then two sets swapped
// apart, each all or none. The context set while sounds or her world effects are wanted, the audio sinks while
// sounds are. A set another mod's hook refuses stays as it is for the run. sound_undo gives each swapped set back at
// coop off and after a fault; a look turned off gives it back until it is on again.

namespace coop::pose {
namespace {
bool shared_scene() { return story_scene; }

// Ours, in each set's order: the wrapper of each context entry, the sink in both audio classes' slot.
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
static_assert(std::size(sound_context_ours) == std::size(sound::kContext) &&
              std::size(sound_sink_ours) == std::size(sound::kAudioSink));
struct SoundSet {
  const sound::Hook *hooks;
  size_t n;
  uint64_t *run;
  const uint64_t *ours;
  const char *what;
  Filter state;
};
SoundSet sound_sets[] = {{sound::kContext, std::size(sound::kContext), sound_context_run, sound_context_ours,
                          "her events' context", Filter::untried},
                         {sound::kAudioSink, std::size(sound::kAudioSink), sound_sink_run, sound_sink_ours,
                          "audio starts", Filter::untried}};
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
  if (s.state == Filter::on)
    say("sounds on: " + std::to_string(s.n) + " slots swapped (" + s.what + ")");
  else
    say("sounds refused: " + sound_hex(slots[done]) +
        (page ? " holds " + slot_value(last) : std::string(" would not become writable")) +
        "; nothing of that set swapped, the ghost goes on without sounds (" + s.what + ")");
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
        std::string("sounds: ") + s.what + " slot off (" + why + "): " + sound_hex(s.hooks[i].slot);
    if (!swap_slot(s.hooks[i].slot, s.ours[i], s.run[i], held))
      say(head + " would not become writable; our hook stays in it and only runs the game's function");
    else if (held != s.ours[i])
      say(head + " holds " + slot_value(held) + ", left as it is");
  }
}
// coop off (block()) and after a fault: every set back, none swapped again this run.
void sound_undo(const char *why) {
  sounds_wanted = false;
  for (SoundSet &s : sound_sets) {
    sound_give_back(s, why, Filter::off);
    s.state = Filter::off;
  }
}

// Worker, every 250 ms after coop-state.txt is read: sounds the sounds look. On the pinned build with the engine on and
// before coop off, the originals are relocated once, then each set swaps in while wanted (once: a refused set stays
// refused) and back while not. After a fault every set goes back.
void sound_pass(bool sounds) {
  if (!pinned || blocked)
    return;
  if (sounds_faulted) {
    if (sound_sets[0].state != Filter::off || sound_sets[1].state != Filter::off)
      sound_undo("a fault");
    return;
  }
  sounds_wanted = sounds && engine_on;
  if (!engine_on)
    return;
  if (!sound_relocated) {
    for (SoundSet &s : sound_sets)
      for (size_t i = 0; i < s.n; ++i)
        s.run[i] = base + (s.hooks[i].original - game::kImageBase);
    sound_relocated = true;
  }
  const bool want[] = {sound::context_wanted(sounds, false), sounds}; // No world effects yet.
  for (size_t k = 0; k < std::size(sound_sets); ++k) {
    SoundSet &s = sound_sets[k];
    if (want[k] && s.state == Filter::untried)
      sound_swap_in(s);
    else if (!want[k])
      sound_give_back(s, "sounds look off", Filter::untried);
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
} // namespace
} // namespace coop::pose
