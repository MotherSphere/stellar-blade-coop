// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// coop emote's native backend (eve/emote.lua), free of Windows: one of EVE's animation clips played on the player's
// EVE through SB's own custom animation call, the way the game plays her clips, and stopped again.
// eve/anim_game.inc makes the calls on the game thread; tests/native/game/anim_test.cpp checks this file on the
// build machine.
//
// Why not a montage: CH_P_EVE_01_AnimBP_New has no AnimNode_Slot, so a dynamic montage plays with nothing shown. SB
// plays her clips through SB's own nodes instead (SBAnimNode_SequenceBlendedPlayer, CustomAnimNode in that blueprint),
// fed by ASBCharacter::PlayCustomAnim (FUN_1420b2d70, 38 parameters). It plays a UAnimSequenceBase in one of the
// character's custom animation slots (an array of 0x70-byte slots at +0x21b8, its count at +0x21c0) and returns the
// play's FGuid, all zero when it played nothing: an additive clip, a clip of another skeleton, an end before the start,
// no animation instance, or a slot already playing a clip of a higher priority. On success the slot holds +0x14 the
// weight, +0x18 1 while it plays, +0x20 the FGuid, +0x30 the priority and +0x3c the clip's FName.
//
// The call made here is its by-path entry FUN_1420b7800 (31 parameters), as the MovingTarget animation calls it
// (0x142094ff3): StaticLoadObject of the path as a UAnimSequenceBase, an additive clip sent to the additive play
// (FUN_1420b5930), the priority rule, and the defaults it builds itself (five -1 body weights, the 44-byte struct copied
// from 0x1470fc3f8). It returns 0 once it called the play, 1 for the additive play, -1 when the clip did not load or the
// slot's clip outranks ours, and writes the FGuid into its fourth argument (zeroed first). The path is a const FString&
// it only reads; its five other FString arguments are by value and freed by the callee when their data is set, so
// empty ones (null data) free nothing. The flight start's wrapper FUN_1420b39f0 cannot loop: it passes no loop flag.
//
// Each tick ASBCharacter::UpdateCustomAnimWeight (FUN_1420ab760) moves each slot's time and weight. A clip played once
// starts blending out at its end minus the blend out time and clears +0x18 when its weight reaches 0; a loop with count
// -1 never blends out. A slot whose node is not playing gets weight 0 each tick, its +0x18 left set. Photo mode stops
// the player's custom animation (FUN_1420b23f0(character, 0, ...)), which this watch reads as the clip ending. Its one
// caller, FUN_1420ac600(character, delta time), is reached only through vtables: her tick, which a paused world does
// not run, so coop freeze and the photo pause a host's photo mode puts on the guest leave the weight where it was.
//
// The stop is SB's FUN_1420b23f0(character, slot, blend out, FName, force): the slot's clip blends out when it is the
// named one (NAME_None: any), so ours stops only while the slot still holds the clip we played.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <string_view>

#include "game/memory.h" // plausible

namespace coop::anim {
constexpr uint64_t kPlayByPath = 0x1420b7800, kStop = 0x1420b23f0;
constexpr size_t kSlots = 0x21b8, kSlotCount = 0x21c0; // The slot array and its count on the ASBCharacter.
// Slot 0's fields: the weight, the playing byte, the FGuid (16 bytes), the clip's FName (8 bytes). The watch reads the
// kSlotRead bytes from +kSlotWeight at once.
constexpr size_t kSlotWeight = 0x14, kSlotPlaying = 0x18, kSlotGuid = 0x20, kSlotName = 0x3c;
constexpr size_t kSlotRead = kSlotGuid + 16 - kSlotWeight;
constexpr uint64_t kWatchMs = 100; // The game thread reads slot 0 this often while ours plays.
// A play whose slot took no weight in this long is ended and stopped: SB's node is not playing it (its time then never
// moves, so a clip played once would never end), and nothing shows. Only time in a world that is not paused counts.
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

// Our EVE, the actor Lua's UEHelpers.GetPlayer gives: the pawn of the player controller pc (AController::Pawn, as
// execK2_GetPawn 0x144729020 reads it), when live(pawn, &index, &serial) says it is a live object (index and serial
// take its object item's) and is_a(pawn) that it is an ASBCharacter; else 0. The glue passes game/pilot.h's live and
// is_a, which this header cannot include (pilot.h reaches link/protocol.h, which includes this file).
constexpr size_t kPawn = 0x2f8;
template <class Read, class Live, class IsA>
uint64_t eve(Read &&read, Live &&live, IsA &&is_a, uint64_t pc, int32_t &index, int32_t &serial) {
  uint64_t pawn = 0;
  return game::plausible(pc) && read(pc + kPawn, &pawn, sizeof pawn) && game::plausible(pawn) &&
                 live(pawn, &index, &serial) && is_a(pawn)
             ? pawn
             : 0;
}
// The character played on (ch, its object item's index and serial at the play) is still that live object: one freed
// whose address and item went to another object has another serial.
template <class Live> bool alive(Live &&live, uint64_t ch, int32_t index, int32_t serial) {
  int32_t i = 0, s = 0;
  return ch && live(ch, &i, &s) && i == index && s == serial;
}

// The scalar arguments: from the start (0) to the end (-1: the whole clip) at rate 1, blended in and out over 0.25 s
// as the montage fallback is, -1 for the blend of SB's stop at input (its own rule, off: byte 15 is 0), a loop with
// count -1 (forever) or none, priority 0 as the flight start plays its clips. The bike's ride is a loop with foot_ik 2,
// the by-path call's int 30: PlayCustomAnim (its 32nd argument, kept at the slot's +0x68) then turns her foot IK off
// over the blend-in through FUN_1421119c0 under the key "ASBCharacter::PlayCustomAnim_29770", at priority 100. SB's
// stop turns it back on only while the slot's +0x68 still reads 1 or 2 (feet() below covers the other ends). 0
// leaves her foot IK alone.
// The ride is also held (vehicles/bike/ride.lua's hold way, bike_pose=hold): hold 1 and kRidePriority. The by-path
// call passes its 17th argument on as PlayCustomAnim's 17th (0x1420b7dea), which writes it to the slot's byte +0x34
// (0x1420b36e0). PlayCustomAnim compares priorities only while the slot is held that way or its clip has time left
// (0x1420b3041..0x1420b3050). It refuses a new play only when its priority is strictly lower than the slot's +0x30
// (COMISS, JC at 0x1420b3052). A loop with count -1 has no time left (+0x04 is -1), so without hold any play of SB's
// replaces the ride. The by-path entry refuses too while +0x34 is set (FUN_1420b39b0 is then false).
// kRidePriority sits between 100.0 (0x146750350) and 101.0 (0x146750358). It refuses SB's fixed slot-0 plays at 0, 90.0
// (0x146750338) and 99.0 (0x14675034c, the FixedTargetRotation turn 0x142037f0e). It refuses the player tick block
// 0x14206947a in its 100.0 branch (0x1420692f5). The 101.0 plays still replace the ride: CancelEventMove's play
// 0x142094ff3, the slide slip end 0x14208303b, 0x14206947a in its 101.0 branch. It stays below 101.0 for SB's stop at
// 0x142063b6d (in FUN_1420634f0). That stop runs when slot 0's priority is 101.0 or more (COMISS, JA at 0x142063b32)
// and her state passes the tests at 0x142063a3e..0x142063b25, among them +0x2051 set, +0xa94 below 0, +0x204c at
// most 0, +0x2050 and +0x2052 clear. It passes the FName None: index 0 from FUN_140e4abf0 (0x142063b40), number 0.
// StopCustomAnim compares the slot's clip name (+0x3c, 0x1420b24ba) only for a name other than None (0x1420b24a2:
// 0x147017b00 is the name pool's entry of "None"), so it would end any clip.
constexpr float kRidePriority = 100.5f;
struct Play {
  float start = 0, end = -1, rate = 1, blend_in = 0.25f, blend_out = 0.25f, input_blend = -1, priority = 0;
  uint8_t loop = 0, hold = 0;
  int32_t loops = -1, foot_ik = 0;
};
inline Play play(bool loop, bool ride = false) {
  Play p;
  p.loop = loop || ride ? 1 : 0;
  p.foot_ik = ride ? 2 : 0;
  p.priority = ride ? kRidePriority : 0;
  p.hold = ride ? 1 : 0;
  return p;
}

// EVE's foot IK after the ride's play is over without SB's stop turning it back on (another clip took slot 0, so its
// +0x68 holds that clip's type; a replay refused; EVE gone). SB's stop FUN_1420b23f0 does, for a slot of type 1 or 2:
// FUN_142111440(character, 0) true, FUN_1421119c0(character, key, 1, blend, -1, 0, 0, 100), the only priority that
// can undo the ride's off; else, while +0x2b20 (on) reads 0, +0x2b23 = 1, which FUN_1420fe2b0 turns on at 100 later.
// The glue does the same: nothing while she is gone (alive false), while her foot IK is on, or while slot 0 plays a
// clip of type 1 or 2 (that clip turned it off; its own stop turns it on).
constexpr uint64_t kFootIkAllowed = 0x142111440, kSetFootIk = 0x1421119c0;
constexpr size_t kFootIkOn = 0x2b20, kFootIkLater = 0x2b23, kSlotFootIk = 0x68;
constexpr char16_t kFootIkKey[] = u"ASBCharacter::StopCustomAnim_29443"; // SB's stop's key for type 2.
enum class Feet : uint8_t { none, on, later, gone };
inline Feet feet(bool alive, bool on, bool playing, int32_t type, bool allowed) {
  if (!alive)
    return Feet::gone;
  if (on || (playing && (type == 1 || type == 2)))
    return Feet::none;
  return allowed ? Feet::on : Feet::later;
}
// The worker's line for what feet() decided.
inline std::string describe_feet(Feet f) {
  switch (f) {
  case Feet::on:
    return "anim: EVE's foot IK turned back on after the bike's ride, as SB's stop does";
  case Feet::later:
    return "anim: EVE's foot IK set to come back once SB allows it, as SB's stop does";
  case Feet::gone:
    return "anim: EVE's foot IK left alone after the bike's ride: the EVE it played on is gone, or her state did not "
           "read";
  case Feet::none:
    break;
  }
  return "anim: EVE's foot IK needs nothing after the bike's ride (it is on, or the clip in her slot turns it on at "
         "its stop)";
}

// What became of the last play asked: idle (none yet), playing, ended (SB ended it: a clip played once ran out,
// another clip took the slot, photo mode, or EVE went; or its slot took no weight), stopped (our stop), refused, fault
// (the latch).
enum class State : uint8_t { idle, playing, ended, stopped, refused, fault };
// Why it was refused, ended or stopped. eve: no EVE of ours found (no player controller, no pawn, or not a live
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
  // The call's answer for play id: playing with its FGuid and the slot's FName, or refused (game) without an FGuid. A
  // ride that played turned EVE's foot IK off: owes_feet() from its end until paid_feet().
  void played(uint32_t id, int32_t ret, const int32_t (&guid)[4], uint64_t name, uint64_t now, bool ride = false) {
    ret_ = ret, peak_ = 0, held_ = 0, since_ = now, last_ = now, unpaused_ = 0, name_ = name;
    std::memcpy(guid_, guid, sizeof guid_);
    ride_ = ride && any(guid);
    feet_ = feet_ || ride_;
    set(id, any(guid) ? State::playing : State::refused, any(guid) ? Why::none : Why::game);
  }
  // The ride's foot IK off is owed back once no ride of ours plays (eve/anim_game.inc's anim_feet, game thread).
  bool owes_feet() const { return feet_ && !(live() && ride_); }
  void paid_feet() { feet_ = false; }
  void refused(uint32_t id, Why why) {
    ret_ = 0, peak_ = 0, held_ = 0;
    set(id, State::refused, why);
  }
  // The watch, while ours plays: alive says the character is the one played on, still live. Ours while slot 0 plays
  // with our FGuid; else ended. True when the caller must stop the slot: ours, but no weight in kNoWeightMs of a world
  // that is not paused (paused: the time since the last watch does not count, as her tick did not run).
  bool watch(bool alive, const Slot &s, uint64_t now, bool paused) {
    if (!live())
      return false;
    if (!alive || !s.playing || std::memcmp(s.guid, guid_, sizeof guid_) != 0) {
      end(now, State::ended, Why::none);
      return false;
    }
    unpaused_ += paused ? 0 : now - last_;
    last_ = now;
    peak_ = s.weight > peak_ ? s.weight : peak_;
    if (peak_ > 0 || unpaused_ < kNoWeightMs)
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
  uint64_t name_ = 0, since_ = 0, held_ = 0, last_ = 0, unpaused_ = 0; // last_: the last watch; unpaused_: ms counted.
  int32_t ret_ = 0;
  float peak_ = 0;
  bool ride_ = false, feet_ = false; // ride_: the last play is a ride that played; feet_: a ride turned foot IK off.
};

// What the game thread does this frame (eve/anim_game.inc's anim_tick). got: an ask taken this frame, stop: it
// is a stop; blocked: coop off; drop: a new Lua load; live: ours plays; next: when the next watch is due. A play asked
// is refused after coop off or at a new Lua load (why off or session: the Lua load that asked is gone), else played;
// while ours plays, it stops first (stop_first). While ours plays, a stop asked, a new Lua load or coop off stop it
// (why: off, session or none), else the watch runs once next is due. Nothing otherwise: a stop with nothing of ours
// playing has nothing to do.
enum class Act : uint8_t { none, refuse, play, stop, watch };
inline Act act(bool got, bool stop, bool blocked, bool drop, bool live, uint64_t now, uint64_t next, Why &why) {
  why = blocked ? Why::off : drop ? Why::session : Why::none;
  if (got && !stop)
    return blocked || drop ? Act::refuse : Act::play;
  if (!live)
    return Act::none;
  if (got || drop || blocked)
    return Act::stop;
  return now >= next ? Act::watch : Act::none;
}
// A play's answer, or its refusal, overwrites the track: taken while ours plays, ours would then go unwatched and
// never be stopped (not at a new Lua load, not at coop off). So the caller stops ours first, with act's why.
inline bool stop_first(Act a, bool live) { return live && (a == Act::play || a == Act::refuse); }

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
    case Why::session:
      return id + " refused: a new Lua load";
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
