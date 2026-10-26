// coop emote's native backend (cut/emote.lua), free of Windows: one of EVE's animation clips played on the player's EVE
// through SB's own custom animation call, the way the game plays her clips, and stopped again. glue/tick/anim_game.inc
// makes the calls on the game thread; tests/native/game/anim_test.cpp checks this file on the build machine.
//
// Why not a montage: CH_P_EVE_01_AnimBP_New has no AnimNode_Slot, so a dynamic montage plays with nothing shown. SB
// plays her clips through SB's own nodes instead (SBAnimNode_SequenceBlendedPlayer, CustomAnimNode in that blueprint),
// fed by ASBCharacter::PlayCustomAnim (FUN_1420ae740, 38 parameters). It plays a UAnimSequenceBase in one of the
// character's custom animation slots (an array of 0x70-byte slots at +0x21b8, its count at +0x21c0) and returns the
// play's FGuid, all zero when it played nothing: an additive clip, a clip of another skeleton, an end before the start,
// no animation instance, or a slot already playing a clip of a higher priority. On success the slot holds +0x14 the
// weight, +0x18 1 while it plays, +0x20 the FGuid, +0x30 the priority and +0x3c the clip's FName.
//
// The call made here is its by-path entry FUN_1420b31d0 (31 parameters), as the MovingTarget animation calls it
// (0x1420909c3): StaticLoadObject of the path as a UAnimSequenceBase, an additive clip sent to the additive play
// (FUN_1420b1300), the priority rule, and the defaults it builds itself (five -1 body weights, the 44-byte struct copied
// from 0x1470f7598). It returns 0 once it called the play, 1 for the additive play, -1 when the clip did not load or the
// slot's clip outranks ours, and writes the FGuid into its fourth argument (zeroed first). The path is a const FString&
// it only reads; its five other FString arguments are by value and freed by the callee when their data is set, so
// empty ones (null data) free nothing. The flight start's wrapper FUN_1420af3c0 cannot loop: it passes no loop flag.
//
// Each tick ASBCharacter::UpdateCustomAnimWeight (FUN_1420a7130) moves each slot's time and weight. A clip played once
// starts blending out at its end minus the blend out time and clears +0x18 when its weight reaches 0; a loop with count
// -1 never blends out. A slot whose node is not playing gets weight 0 each tick, its +0x18 left set. Photo mode stops
// the player's custom animation (FUN_1420addc0(character, 0, ...)), which this watch reads as the clip ending.
//
// The stop is SB's FUN_1420addc0(character, slot, blend out, FName, force): the slot's clip blends out when it is the
// named one (NAME_None: any), so ours stops only while the slot still holds the clip we played.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <string_view>

namespace coop::anim {
constexpr uint64_t kPlayByPath = 0x1420b31d0, kStop = 0x1420addc0;
constexpr size_t kSlots = 0x21b8, kSlotCount = 0x21c0; // The slot array and its count on the ASBCharacter.
// Slot 0's fields: the weight, the playing byte, the FGuid (16 bytes), the clip's FName (8 bytes). The watch reads the
// kSlotRead bytes from +kSlotWeight at once.
constexpr size_t kSlotWeight = 0x14, kSlotPlaying = 0x18, kSlotGuid = 0x20, kSlotName = 0x3c;
constexpr size_t kSlotRead = kSlotGuid + 16 - kSlotWeight;
constexpr uint64_t kWatchMs = 100; // The game thread reads slot 0 this often while ours plays.
// A play whose slot took no weight in this long is ended and stopped: SB's node is not playing it (its time then never
// moves, so a clip played once would never end), and nothing shows.
constexpr uint64_t kNoWeightMs = 1000;
// Only EVE's clips: the path starts with kDir, holds letters, digits, '_', '/' and single '.', and fits kMaxPath.
constexpr char kDir[] = "/Game/Art/Character/PC/CH_P_EVE_01/Animation/";
constexpr size_t kMaxPath = 192;
inline bool path_ok(std::string_view p) {
  const std::string_view dir(kDir);
  if (p.size() <= dir.size() || p.size() > kMaxPath || p.compare(0, dir.size(), dir) != 0 || p.back() == '/' ||
      p.back() == '.')
    return false;
  for (size_t i = dir.size(); i < p.size(); ++i) {
    const char c = p[i];
    const bool mark = c == '/' || c == '.';
    if (!(mark || c == '_' || (c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')))
      return false;
    if (mark && (p[i - 1] == '/' || p[i - 1] == '.'))
      return false;
  }
  return true;
}
// The path as the FString the call reads: UTF-16 with its null, num counting the null (FString's ArrayNum).
struct Path {
  char16_t chars[kMaxPath + 1] = {};
  int32_t num = 0;
};
inline Path widen(std::string_view p) {
  Path out;
  if (!path_ok(p))
    return out;
  for (size_t i = 0; i < p.size(); ++i)
    out.chars[i] = char16_t(uint8_t(p[i]));
  out.num = int32_t(p.size() + 1);
  return out;
}

// The scalar arguments: from the start (0) to the end (-1: the whole clip) at rate 1, blended in and out over 0.25 s
// as the montage fallback is, -1 for the blend of SB's stop at input (its own rule, off: byte 15 is 0), a loop with
// count -1 (forever) or none, priority 0 as the flight start plays its clips.
struct Play {
  float start = 0, end = -1, rate = 1, blend_in = 0.25f, blend_out = 0.25f, input_blend = -1, priority = 0;
  uint8_t loop = 0;
  int32_t loops = -1;
};
inline Play play(bool loop) {
  Play p;
  p.loop = loop ? 1 : 0;
  return p;
}

// What became of the last play asked: idle (none yet), playing, ended (SB ended it: a clip played once ran out,
// another clip took the slot, photo mode, or EVE went; or its slot took no weight), stopped (our stop), refused, fault
// (the latch).
enum class State : uint8_t { idle, playing, ended, stopped, refused, fault };
// Why it was refused, ended or stopped. eve: no EVE of ours found (no GUID, a global unset, or not a live
// ASBCharacter). slots: she has no custom animation slot. game: SB played nothing (the call returned -1, or no FGuid).
// off: coop off. session: a new Lua load. weight: the slot took no weight in kNoWeightMs.
enum class Why : uint8_t { none, eve, slots, game, off, session, weight };
inline const char *why_name(Why w) {
  static const char *const kNames[] = {"none", "eve", "slots", "game", "off", "session", "weight"};
  return size_t(w) < sizeof kNames / sizeof kNames[0] ? kNames[size_t(w)] : "?";
}
// The status line's word (Lua reads it): idle, playing, ended, ended:weight, stopped, refused:<why> or fault.
inline std::string state_text(State s, Why w) {
  switch (s) {
  case State::idle:
    return "idle";
  case State::playing:
    return "playing";
  case State::ended:
    return w == Why::weight ? "ended:weight" : "ended";
  case State::stopped:
    return "stopped";
  case State::refused:
    return std::string("refused:") + why_name(w);
  case State::fault:
    return "fault";
  }
  return "?";
}

// Slot 0 as the watch read it.
struct Slot {
  uint8_t playing = 0;
  float weight = 0;
  int32_t guid[4] = {};
};
// The kSlotRead bytes read from +kSlotWeight.
inline Slot slot(const uint8_t (&b)[kSlotRead]) {
  Slot s;
  std::memcpy(&s.weight, b, 4);
  s.playing = b[kSlotPlaying - kSlotWeight];
  std::memcpy(s.guid, b + (kSlotGuid - kSlotWeight), 16);
  return s;
}

// The last play's track, the game thread's: its answer, the watch, the stop. word() packs what the worker logs and the
// status line shows (the play's id, the state, why, and a count bumped at each change); peak is the highest weight
// read, held the ms from the answer to the end or stop, ret what the call returned.
struct Word {
  uint32_t id = 0;
  State state = State::idle;
  Why why = Why::none;
  uint16_t changes = 0;
};
inline uint64_t pack(const Word &w) {
  return uint64_t(w.id) << 32 | uint64_t(w.state) << 24 | uint64_t(w.why) << 16 | w.changes;
}
inline Word unpack(uint64_t v) {
  return Word{uint32_t(v >> 32), State((v >> 24) & 0xff), Why((v >> 16) & 0xff), uint16_t(v)};
}
class Track {
public:
  // The call's answer for play id: playing with its FGuid and the slot's FName, or refused (game) without an FGuid.
  void played(uint32_t id, int32_t ret, const int32_t (&guid)[4], uint64_t name, uint64_t now) {
    ret_ = ret, peak_ = 0, held_ = 0, since_ = now, name_ = name;
    std::memcpy(guid_, guid, sizeof guid_);
    set(id, any(guid) ? State::playing : State::refused, any(guid) ? Why::none : Why::game);
  }
  void refused(uint32_t id, Why why) {
    ret_ = 0, peak_ = 0, held_ = 0;
    set(id, State::refused, why);
  }
  // The watch, while ours plays: alive says the character is the one played on, still live. Ours while slot 0 plays
  // with our FGuid; else ended. True when the caller must stop the slot: ours, but no weight in kNoWeightMs.
  bool watch(bool alive, const Slot &s, uint64_t now) {
    if (!live())
      return false;
    if (!alive || !s.playing || std::memcmp(s.guid, guid_, sizeof guid_) != 0) {
      end(now, State::ended, Why::none);
      return false;
    }
    peak_ = s.weight > peak_ ? s.weight : peak_;
    if (peak_ > 0 || now - since_ < kNoWeightMs)
      return false;
    end(now, State::ended, Why::weight);
    return true;
  }
  // Our stop was called (or the clip had gone already, which the watch then says).
  void stopped(uint64_t now, Why why) {
    if (live())
      end(now, State::stopped, why);
  }
  void faulted() { set(word_.id, State::fault, Why::none); }
  bool live() const { return word_.state == State::playing; }
  uint64_t name() const { return name_; }
  uint64_t word() const { return pack(word_); }
  int32_t ret() const { return ret_; }
  float peak() const { return peak_; }
  uint64_t held() const { return held_; }

private:
  static bool any(const int32_t (&g)[4]) { return g[0] || g[1] || g[2] || g[3]; }
  void set(uint32_t id, State s, Why w) {
    const uint16_t changes = uint16_t(word_.changes + 1);
    word_ = Word{id, s, w, changes};
  }
  void end(uint64_t now, State s, Why w) {
    held_ = now - since_;
    set(word_.id, s, w);
  }
  Word word_;
  int32_t guid_[4] = {};
  uint64_t name_ = 0, since_ = 0, held_ = 0;
  int32_t ret_ = 0;
  float peak_ = 0;
};

// The worker's log line for a change: what the game thread did with play id.
inline std::string describe(const Word &w, int32_t ret, float peak, uint64_t held_ms) {
  char text[200];
  const std::string id = "anim " + std::to_string(w.id);
  const auto ended = [&](const char *how, const char *why) {
    std::snprintf(text, sizeof text, "%s %s after %.1f s%s, weight up to %.2f%s", id.c_str(), how,
                  double(held_ms) / 1000, why, double(peak),
                  w.why == Why::weight ? ": the slot took no weight, so EVE's animation blueprint did not show the clip"
                                       : "");
    return std::string(text);
  };
  switch (w.state) {
  case State::playing:
    return id + " playing: SB took the clip in EVE's custom animation slot 0 (ret " + std::to_string(ret) + ")";
  case State::ended:
    return ended("ended", "");
  case State::stopped:
    return ended("stopped", w.why == Why::off ? " (coop off)" : w.why == Why::session ? " (a new Lua load)" : "");
  case State::refused:
    switch (w.why) {
    case Why::eve:
      return id + " refused: no EVE of ours in the world";
    case Why::slots:
      return id + " refused: EVE has no custom animation slot";
    case Why::off:
      return id + " refused: coop off";
    default:
      return id + " refused: the game played nothing (ret " + std::to_string(ret) +
             (ret < 0 ? ": the clip did not load, or a clip of a higher priority holds the slot)"
                      : ": SB's play gave no id)");
    }
  case State::fault:
    return id + ": stopped by a fault";
  case State::idle:
    break;
  }
  return id + " idle";
}
} // namespace coop::anim
