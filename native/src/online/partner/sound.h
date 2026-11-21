// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Her sounds, the sender's side (the ghost's fidelity, phase 5 Task 9). Context hooks in the vtable slots of SB's
// footstep, character sound and sound notifies and of its show sound updaters set a mark while SB runs one of them for
// her. A sink in the audio component's start slot records the sound SB picked, with its class, attenuation, volume,
// pitch, int parameters and place, under the mark or when its owner or attach parent is hers. The game thread names
// each sound once (an asset key and its SBA line, game/events.h) and puts it in the pose's event slots.
// online/partner/sound_game.inc holds the hooks, online/partner/sound_worker.inc the swaps. No Windows types:
// tests/native/online/partner/sound_test.cpp checks it on the build machine.
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "game/events.h" // Kind, kNoPart, Param, asset_line, kMaxParams
#include "game/pilot.h"  // fname, kObjectName, kOuter, kShowInterface

namespace coop::sound {

// A vtable slot in .rdata and the game function it holds on the pinned build, both as Ghidra gives them (image base
// 0x140000000); the worker relocates the original once before its first swap.
struct Hook {
  uint64_t slot, original;
};
// The context entries, in this order (the wrappers in sound_game.inc take their index), read in Ghidra 26123051:
// 0 FUN_142019370, SB's footstep notify (this, MeshComp, Animation), void;
// 1 FUN_1420173d0, SB's character sound notify (this, MeshComp), void;
// 2 FUN_1420286c0, USBAnimNotifyState_PlaySound's NotifyBegin (this, MeshComp, Animation, float TotalDuration in
//   XMM3), void;
// 3 to 5 FUN_1424679c0, FUN_142468d90, FUN_14245cdb0, the show sound updaters' slot +0x30 (this, int, pointer), 8
//   bytes back;
// 6 FUN_143fccef0, the engine's UAnimNotify_PlaySound::Notify (this, MeshComp, Animation), void.
constexpr Hook kContext[] = {{0x145c51bb0, 0x142019370}, {0x145c525f0, 0x1420173d0}, {0x145c60d60, 0x1420286c0},
                             {0x145cf6398, 0x1424679c0}, {0x145cf5a40, 0x142468d90}, {0x145cf5cb0, 0x14245cdb0},
                             {0x1463c3358, 0x143fccef0}};
constexpr size_t kFootstep = 0, kCharacterSound = 1, kNotifyBegin = 2, kShowFirst = 3, kShowLast = 5,
                 kEnginePlaySound = 6;
// The audio start: UAudioComponent's vtable 0x1463dadb0 and USBSoundComponent's 0x145d078d8 hold the same Play
// (FUN_1440925f0: this, float StartTime in XMM1, void) at +0x570.
constexpr Hook kAudioSink[] = {{0x1463db320, 0x1440925f0}, {0x145d07e48, 0x1440925f0}};

// UAudioComponent: Sound, SoundClassOverride, AttenuationSettings and InstanceParameters (their reflection params
// 0x1464f8fb0, 0x1464f8f70, 0x1464f9840, 0x1464f8ed8), VolumeMultiplier and PitchMultiplier (FUN_144094850 and
// FUN_144094900 store XMM1 there). InstanceParameters as FUN_1440944c0 (SetIntParameter) writes it: data, count +8, max
// +0xc; 0x20-byte entries of FName +0, float +8, bool +0xc, int +0x10, wave +0x18. UActorComponent: its owner
// (GetOwner's exec 0x143805070 returns +0xb0). USceneComponent: AttachParent (params 0x146649920) and its socket name
// (FUN_1441090b0 writes both).
constexpr size_t kSound = 0x260, kClassOverride = 0x278, kVolume = 0x2a4, kPitch = 0x2c0, kAttenuation = 0x2d0,
                 kOwner = 0xb0, kAttachParent = 0xd8, kAttachSocket = 0xe0, kParams = 0x268, kParamCount = 0x270,
                 kParamBytes = 0x20, kParamFloat = 0x8, kParamBool = 0xc, kParamInt = 0x10, kParamWave = 0x18;
constexpr size_t kMaxParams = pose::kMaxParams;
// A show updater's player (this +0x20, which FUN_14242dd60 takes) and the player's stage (+0x20, FUN_14242dd60's first
// read); the stage's main actor is game/pilot.h's kStageMainWeak and kStageMain.
constexpr size_t kUpdaterPlayer = 0x20, kPlayerStage = 0x20;

// Each slot of one set from from to to, all or none: at the slots as Ghidra gives them (swap relocates them), from the
// values they must hold (the originals relocated to the loaded image, or ours to give them back), to the new ones.
// swap(at, from, to, held) is a compare-and-swap that says what the slot held, false when the slot would not become
// writable. Returns n when every slot held its from and took its to; else gives back the ones it took and returns the
// index of the slot refused.
template <class Swap> size_t swap_all(const uint64_t *at, const uint64_t *from, const uint64_t *to, size_t n,
                                      Swap &&swap) {
  for (size_t i = 0; i < n; ++i) {
    uint64_t held = 0;
    if (swap(at[i], from[i], to[i], held) && held == from[i])
      continue;
    for (size_t j = i; j-- > 0;) {
      uint64_t back = 0;
      swap(at[j], to[j], from[j], back);
    }
    return i;
  }
  return n;
}
// Three sets swap apart: the context set while sounds or her world effects are wanted, the audio sinks while sounds
// are.
inline bool context_wanted(bool sounds, bool effects) { return sounds || effects; }

// Why a started sound is hers: started under a mark (a context hook ran SB's function for her), owned by one of hers
// (her actor, her drone) or attached to one of hers (her parts' components). Checked in that order.
enum class Rule : uint8_t { none, mark, owner, attach };
inline Rule rule_of(bool mark, uint64_t owner, uint64_t parent, const uint64_t *hers, size_t n) {
  if (mark)
    return Rule::mark;
  const auto in = [&](uint64_t v) { return v && std::find(hers, hers + n, v) != hers + n; };
  return in(owner) ? Rule::owner : in(parent) ? Rule::attach : Rule::none;
}
// Whether the sink records a sound: never while the viewer plays her sounds (applying), never on a thread without its
// own ring (own_ring false: counted as another thread), never for Rule::none.
inline bool records(bool applying, bool own_ring, Rule rule) { return !applying && own_ring && rule != Rule::none; }
// A show stage's main actor is her: its weak pointer names her object (index, serial), or with no weak pointer its
// interface is hers (game/pilot.h's rule for a stage). her 0: none.
inline bool stage_hers(int32_t weak_index, int32_t weak_serial, uint64_t main, uint64_t her, int32_t her_index,
                       int32_t her_serial) {
  if (!her)
    return false;
  return weak_serial ? weak_index == her_index && weak_serial == her_serial : main == her + pilot::kShowInterface;
}

// One sound start as the sink read it: the component, its sound, class and attenuation objects (0 for none), volume and
// pitch, the part it is attached to (pose::kNoPart: placed relative to part 0) and its place relative to that part
// (rotation xyzw, translation xyz), why it is hers, its first kMaxParams int parameters (FName as index | number << 32,
// value) and how many it left out (a float, bool or wave set, or past kMaxParams).
struct Record {
  uint64_t component = 0, sound = 0, cls = 0, att = 0;
  float volume = 0, pitch = 0;
  uint8_t part = pose::kNoPart;
  float place[7] = {};
  Rule rule = Rule::none;
  uint8_t params = 0, left_out = 0;
  uint64_t param_name[kMaxParams] = {};
  int32_t param_value[kMaxParams] = {};
};

// The sink's ring, one writer thread each: kEntries records, past that a start is lost (counted in over()). Under one
// mark (non-zero) a later start of the same component replaces its record with that later call's fields:
// FUN_1441ff120's pooled branch starts it once before its caller's setup and the caller starts it again after. Outside
// a mark each start is its own record. take() moves the oldest out, at most cap of them. No allocation.
class Records {
public:
  static constexpr size_t kEntries = 64;
  void add(const Record &r, uint32_t mark) {
    for (size_t i = 0; mark && i < count_; ++i)
      if (marks_[i] == mark && entries_[i].component == r.component) {
        entries_[i] = r;
        return;
      }
    if (count_ == kEntries) {
      ++over_;
      return;
    }
    entries_[count_] = r;
    marks_[count_++] = mark;
  }
  size_t take(Record *out, size_t cap) {
    const size_t n = std::min(cap, count_);
    std::copy(entries_, entries_ + n, out);
    std::copy(entries_ + n, entries_ + count_, entries_);
    std::copy(marks_ + n, marks_ + count_, marks_);
    count_ -= n;
    return n;
  }
  uint64_t over() const { return over_; }

private:
  Record entries_[kEntries];
  uint32_t marks_[kEntries] = {};
  size_t count_ = 0;
  uint64_t over_ = 0;
};

// The asset keys' b for a record: its attenuation, mixed with its params when it has any (FNV-1a over each name and
// value, never 0), so the same sound with other int parameters gets a key of its own.
inline uint64_t keyed_attenuation(const Record &r) {
  if (!r.params)
    return r.att;
  uint64_t h = 0xcbf29ce484222325;
  const auto mix = [&h](uint64_t v, int bytes) {
    for (int k = 0; k < bytes; ++k)
      h = (h ^ ((v >> (8 * k)) & 0xff)) * 0x100000001b3;
  };
  for (uint8_t i = 0; i < r.params && i < kMaxParams; ++i)
    mix(r.param_name[i], 8), mix(uint32_t(r.param_value[i]), 4);
  return r.att ^ (h | 1);
}

// An asset's path from the name pool: its package (its outer, which has no outer) and its own name, as
// "<package>.<name>". False for 0, an object not at the top of its package or a name that does not read.
template <class Read> bool asset_path(Read &&read, uint64_t pool, uint64_t object, std::string &out) {
  constexpr size_t kName = 256;
  uint64_t pkg = 0, outer = 1;
  uint32_t pn[2] = {}, on[2] = {};
  char p[kName], o[kName];
  size_t pl = 0, ol = 0;
  if (!object || !read(object + pilot::kOuter, &pkg, sizeof pkg) || !game::plausible(pkg) ||
      !read(pkg + pilot::kOuter, &outer, sizeof outer) || outer || !read(pkg + pilot::kObjectName, pn, sizeof pn) ||
      !read(object + pilot::kObjectName, on, sizeof on) || !pilot::fname(read, pool, pn[0], pn[1], p, kName, pl) ||
      !pilot::fname(read, pool, on[0], on[1], o, kName, ol))
    return false;
  out.assign(p, pl).append(".").append(o, ol);
  return true;
}
// The words of r's SBA line, what it carries after its key: sound <asset> <class|-> <attenuation|-> <params|->. Empty
// when the sound's path does not read or the line would be refused (a path outside SB's own folders, over
// kMaxMessage under the longest key, kMaxAssetKeys, so it passes under any key AssetKeys::add gives). A class or
// attenuation that does not read or whose path is refused goes as -. A param whose name does not read or is not a word
// is left out and counted in left_out.
template <class Read> std::string record_words(Read &&read, uint64_t pool, const Record &r, uint64_t &left_out) {
  std::string asset, a = "-", b = "-", path;
  if (!asset_path(read, pool, r.sound, asset))
    return {};
  if (asset_path(read, pool, r.cls, path) && pose::event_path_ok(path))
    a = path;
  if (asset_path(read, pool, r.att, path) && pose::event_path_ok(path))
    b = path;
  std::vector<pose::Param> params;
  for (uint8_t i = 0; i < r.params && i < kMaxParams; ++i) {
    char name[pose::sba::kMaxWord + 1];
    size_t len = 0;
    if (pilot::fname(read, pool, uint32_t(r.param_name[i]), uint32_t(r.param_name[i] >> 32), name, sizeof name, len) &&
        pose::sba::word_ok(std::string_view(name, len)))
      params.push_back({std::string(name, len), r.param_value[i]});
    else
      ++left_out;
  }
  const std::string line = pose::asset_line(uint16_t(pose::kMaxAssetKeys), pose::Kind::sound, asset, a, b, params);
  return line.empty() ? std::string()
                      : line.substr((asset_tag() + " " + std::to_string(pose::kMaxAssetKeys) + " ").size());
}

// The pose's event slots fitted to its table of parts parts: an event recorded on a part the table no longer has (her
// drone gone, a smaller outfit since) goes empty in this pose, since get_event (game/codec.h) refuses the whole pose
// for it. The outbox keeps the event until its hold ends.
inline void fit_parts(pose::Event *slots, size_t parts) {
  for (size_t k = 0; k < pose::kEventSlots; ++k)
    if (slots[k].part != pose::kNoPart && slots[k].part >= parts)
      slots[k] = pose::Event();
}

} // namespace coop::sound
