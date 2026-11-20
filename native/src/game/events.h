// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// When the ghost's features may call the game; the events a pose carries (what her game played: a sound, an effect,
// a trail) and the sender's side of them: the Outbox that puts them in the pose's event slots and the asset keys their
// names travel under; the SBA lines that carry those names on channel 2, the book a later member reads them from, the
// slot watch that forgets a member's names and the viewer's coop-loaded lines. No Windows types:
// tests/native/game/events_test.cpp checks it on the build machine. game/codec.h writes and reads an event slot's bytes
// (put_event, get_event).
#pragma once

#include <algorithm>
#include <array>
#include <charconv>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

#include "game/travel.h"    // kInGame, kPlaying
#include "link/pose_cap.h" // kPoseCaps, kPoseCapCount
#include "link/protocol.h" // asset_tag, kMaxMessage, kMaxRemote

namespace coop::pose {

// A pose's event slots, each kEventBytes on the wire (game/codec.h); at most kMaxAssetKeys asset keys per sender in a
// link session; kNoPart: an event placed relative to part 0, not attached to a part.
constexpr size_t kEventSlots = 4, kEventBytes = 19, kMaxAssetKeys = 4096;
constexpr uint8_t kNoPart = 0xff;
enum class Kind : uint8_t { none, sound, niagara, cascade, decal, trail_on, trail_off };
// One event. Wire (game/codec.h's put_event): kind, serial, asset (u16), part, value[2], translation (3 i16 in cm),
// rotation (6 bytes, the codec's smallest three); an empty slot is 19 zero bytes. asset: its key, 1 to kMaxAssetKeys
// (AssetKeys). part kNoPart: placed relative to part 0; else attached to that part with that offset (no socket on the
// wire). value: a sound's volume and pitch in 1/64 steps; Niagara and Cascade a uniform scale in 1/32 steps and 0;
// else 0 0. place: rotation xyzw, translation xyz. serial: a new event in the slot (Outbox).
struct Event {
  Kind kind = Kind::none;
  uint8_t serial = 0, part = kNoPart;
  uint16_t asset = 0;
  uint8_t value[2] = {};
  float place[7] = {};
};

// The sender's events on their way into the pose's slots: at most kWaiting wait, a waiting event older than kWaitUs is
// dropped. A slot frees once its event rode in at least kHoldPoses filled poses and kHoldUs plus one send interval
// passed since it was placed: link/core.h's send_binary gives a member on the lowest pose cap (20 a second) a pose at
// most each 1000 / 20 - kPoseSlackMs ms, so she gets a pose that carries it. Each new event in a slot takes the slot's
// serial + 1 (1 to 255, then 1 again). Game thread; no allocation.
constexpr uint64_t kWaitUs = 100'000, kHoldUs = 1'000'000 / kPoseCaps[kPoseCapCount - 1];
constexpr uint32_t kHoldPoses = 2;
class Outbox {
public:
  static constexpr size_t kWaiting = 8;
  // An event at now: waiting, or false (counted in dropped()) when kWaiting already wait.
  bool push(const Event &e, uint64_t now_us) {
    if (count_ == kWaiting) {
      ++dropped_;
      return false;
    }
    waiting_[(first_ + count_++) % kWaiting] = {e, now_us};
    return true;
  }
  // The pose about to be encoded at now: its slots (kEventSlots) written. In order: the slots held long enough free,
  // the waits past kWaitUs are dropped (counted), the oldest waits take the free slots. every_us: the stream's send
  // interval.
  void fill(Event *slots, uint64_t now_us, uint64_t every_us) {
    for (Held &h : held_)
      if (h.event.kind != Kind::none && h.poses >= kHoldPoses && now_us >= h.placed + kHoldUs + every_us)
        h.event = Event();
    for (; count_ && now_us > waiting_[first_].at + kWaitUs; first_ = (first_ + 1) % kWaiting, --count_)
      ++dropped_;
    for (Held &h : held_) {
      if (h.event.kind == Kind::none && count_) {
        h.serial = h.serial == 255 ? 1 : uint8_t(h.serial + 1);
        h.event = waiting_[first_].event;
        h.event.serial = h.serial;
        h.placed = now_us;
        h.poses = 0;
        first_ = (first_ + 1) % kWaiting;
        --count_;
      }
      h.poses += h.event.kind != Kind::none;
    }
    for (size_t k = 0; k < kEventSlots; ++k)
      slots[k] = held_[k].event;
  }
  uint64_t dropped() const { return dropped_; }

private:
  struct Waiting {
    Event event;
    uint64_t at = 0;
  };
  struct Held {
    Event event;
    uint64_t placed = 0;
    uint32_t poses = 0;
    uint8_t serial = 0;
  };
  Waiting waiting_[kWaiting];
  Held held_[kEventSlots];
  size_t first_ = 0, count_ = 0;
  uint64_t dropped_ = 0;
};

// The sender's asset keys for one link session. known(): the k of an object already seen (its address, its class and
// attenuation, its index and serial, so a freed and reused address is unknown), 0 for none. The game thread then
// resolves its paths once (words: what its SBA line carries after k) and calls add(), which gives the k those words
// already have, else the next one from 1 (fresh). A k is never reused until clear() (a new link session); past
// kMaxAssetKeys add() gives 0 (counted in full()). An asset collected after a map change and loaded again keeps its k:
// its words name it. The object cache holds kObjects, the oldest given up first. Game thread.
class AssetKeys {
public:
  static constexpr size_t kObjects = 512;
  uint16_t known(Kind kind, uint64_t asset, uint64_t a, uint64_t b, int32_t index, int32_t serial) const {
    const Object o{kind, asset, a, b, index, serial, 0};
    for (const Object &x : objects_)
      if (x.k && x.same(o))
        return x.k;
    return 0;
  }
  uint16_t add(Kind kind, uint64_t asset, uint64_t a, uint64_t b, int32_t index, int32_t serial,
               std::string_view words, bool &fresh) {
    fresh = false;
    uint16_t k = 0;
    if (auto it = words_.find(std::string(words)); it != words_.end()) {
      k = it->second;
    } else if (words_.size() == kMaxAssetKeys) {
      ++full_;
      return 0;
    } else {
      k = uint16_t(words_.size() + 1);
      words_.emplace(words, k);
      fresh = true;
    }
    if (!known(kind, asset, a, b, index, serial)) {
      objects_[next_] = {kind, asset, a, b, index, serial, k};
      next_ = (next_ + 1) % kObjects;
    }
    return k;
  }
  void clear() {
    words_.clear();
    objects_.fill(Object());
    next_ = 0;
  }
  uint64_t full() const { return full_; }

private:
  struct Object {
    Kind kind = Kind::none;
    uint64_t asset = 0, a = 0, b = 0;
    int32_t index = 0, serial = 0;
    uint16_t k = 0; // 0: an empty entry.
    bool same(const Object &o) const {
      return kind == o.kind && asset == o.asset && a == o.a && b == o.b && index == o.index && serial == o.serial;
    }
  };
  std::unordered_map<std::string, uint16_t> words_;
  std::array<Object, kObjects> objects_{};
  size_t next_ = 0;
  uint64_t full_ = 0;
};

// Her asset names on channel 2, one line per asset key, reliable, to every member (glue/steam.cpp):
// SBA<protocol> <k> <kind> <asset> <a> <b>, a sound with one more word. kind: sound, niagara, cascade, decal or trail.
// sound: a and b its class and attenuation paths or -, then - or at most kMaxParams <name>:<int> joined by commas (its
// InstanceParameters ints). niagara and cascade: - -. decal: a its size <x>,<y>,<z> in whole cm 1 to 4096, b its
// fade-out in ms 0 to 60000. trail: a its sockets <socket>,<socket>, b its width in 1/100 cm 1 to 100000. Each path
// passes event_path_ok(); a name or socket is 1 to 64 bytes of A-Z a-z 0-9 _; a line is at most kMaxMessage.
constexpr size_t kMaxParams = 8;
struct Param {
  std::string name;
  int32_t value;
};
struct AssetLine {
  uint16_t k;
  Kind kind; // Kind::trail_on for a trail line.
  std::string asset, a, b;
  std::vector<Param> params;
};

namespace sba {
constexpr size_t kMaxPath = 255, kMaxWord = 64; // As game/table.h gives these names (it includes this file).
inline bool word_ok(std::string_view s, size_t max = kMaxWord) {
  if (s.empty() || s.size() > max)
    return false;
  for (char c : s)
    if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_'))
      return false;
  return true;
}
// A whole number from lo to hi written as std::to_string writes it (no sign but a minus, no leading zero, no -0).
inline bool number(std::string_view s, int64_t lo, int64_t hi, int64_t &out) {
  const bool minus = !s.empty() && s[0] == '-';
  const std::string_view digits = s.substr(minus);
  if (digits.empty() || digits.size() > 10 || (digits[0] == '0' && (digits.size() > 1 || minus)))
    return false;
  const auto [end, error] = std::from_chars(s.data(), s.data() + s.size(), out);
  return error == std::errc() && end == s.data() + s.size() && out >= lo && out <= hi;
}
// Numbers from lo to hi joined by commas, exactly count of them.
inline bool numbers(std::string_view s, size_t count, int64_t lo, int64_t hi) {
  for (size_t i = 0; i < count; ++i) {
    const size_t comma = i + 1 < count ? s.find(',') : s.size();
    int64_t v = 0;
    if (comma == std::string_view::npos || !number(s.substr(0, comma), lo, hi, v))
      return false;
    s.remove_prefix(comma == s.size() ? comma : comma + 1);
  }
  return true;
}
inline const char *kind_word(Kind kind) {
  switch (kind) {
  case Kind::sound:
    return "sound";
  case Kind::niagara:
    return "niagara";
  case Kind::cascade:
    return "cascade";
  case Kind::decal:
    return "decal";
  case Kind::trail_on:
  case Kind::trail_off:
    return "trail";
  default:
    return nullptr;
  }
}
} // namespace sba

// /Game/[DLC_<1 or 2 digits>/](Sound|Art)/<folders>/<asset>.<asset>, each folder and the asset's name of A-Z a-z 0-9 _,
// at most 255 bytes: SB's own sounds and effects. /Engine and /Script defaults, a mod's paths and anything that
// climbs out (..) are refused.
inline bool event_path_ok(std::string_view path) {
  if (path.size() > sba::kMaxPath || path.rfind("/Game/", 0) != 0)
    return false;
  path.remove_prefix(6);
  if (path.rfind("DLC_", 0) == 0) {
    const size_t slash = path.find('/');
    if (slash == std::string_view::npos || slash < 5 || slash > 6 ||
        !std::all_of(path.begin() + 4, path.begin() + slash, [](char c) { return c >= '0' && c <= '9'; }))
      return false;
    path.remove_prefix(slash + 1);
  }
  if (path.rfind("Sound/", 0) == 0)
    path.remove_prefix(6);
  else if (path.rfind("Art/", 0) == 0)
    path.remove_prefix(4);
  else
    return false;
  for (size_t slash; (slash = path.find('/')) != std::string_view::npos; path.remove_prefix(slash + 1))
    if (!sba::word_ok(path.substr(0, slash), sba::kMaxPath))
      return false;
  const size_t dot = path.find('.');
  return dot != std::string_view::npos && sba::word_ok(path.substr(0, dot), sba::kMaxPath) &&
         path.substr(0, dot) == path.substr(dot + 1);
}

// Strict: exactly what asset_line() writes, under this kProtocol. A trail line gives Kind::trail_on.
inline std::optional<AssetLine> parse_asset_line(std::string_view line) {
  if (line.size() > kMaxMessage)
    return std::nullopt;
  std::string_view w[7];
  size_t n = 0;
  for (size_t at = 0; at <= line.size();) {
    if (n == 7)
      return std::nullopt; // An eighth word.
    const size_t space = std::min(line.find(' ', at), line.size());
    w[n++] = line.substr(at, space - at);
    at = space + 1;
  }
  int64_t k = 0, v = 0;
  if (n < 6 || w[0] != asset_tag() || !sba::number(w[1], 1, int64_t(kMaxAssetKeys), k) || !event_path_ok(w[3]))
    return std::nullopt;
  AssetLine out{uint16_t(k), Kind::none, std::string(w[3]), std::string(w[4]), std::string(w[5]), {}};
  const auto path_or_none = [](std::string_view s) { return s == "-" || event_path_ok(s); };
  const size_t comma = w[4].find(',');
  if (w[2] == "sound" && n == 7 && path_or_none(w[4]) && path_or_none(w[5])) {
    out.kind = Kind::sound;
    for (std::string_view rest = w[6]; rest != "-";) {
      const size_t end = std::min(rest.find(','), rest.size()), colon = rest.substr(0, end).find(':');
      if (out.params.size() == kMaxParams || colon == std::string_view::npos || !sba::word_ok(rest.substr(0, colon)) ||
          !sba::number(rest.substr(colon + 1, end - colon - 1), INT32_MIN, INT32_MAX, v))
        return std::nullopt;
      out.params.push_back({std::string(rest.substr(0, colon)), int32_t(v)});
      if (end == rest.size())
        break;
      rest.remove_prefix(end + 1);
    }
  } else if (n == 6 && (w[2] == "niagara" || w[2] == "cascade") && w[4] == "-" && w[5] == "-") {
    out.kind = w[2] == "niagara" ? Kind::niagara : Kind::cascade;
  } else if (n == 6 && w[2] == "decal" && sba::numbers(w[4], 3, 1, 4096) && sba::number(w[5], 0, 60000, v)) {
    out.kind = Kind::decal;
  } else if (n == 6 && w[2] == "trail" && comma != std::string_view::npos && sba::word_ok(w[4].substr(0, comma)) &&
             sba::word_ok(w[4].substr(comma + 1)) && sba::number(w[5], 1, 100000, v)) {
    out.kind = Kind::trail_on;
  } else {
    return std::nullopt;
  }
  return out;
}

// One SBA line exactly as parse_asset_line() reads it: kMaxMessage bytes at most. A sound with no params writes -.
inline std::string asset_line(uint16_t k, Kind kind, std::string_view asset, std::string_view a, std::string_view b,
                              const std::vector<Param> &params = {}) {
  const char *word = sba::kind_word(kind);
  if (!word)
    return {};
  std::string line = asset_tag() + " " + std::to_string(k) + " " + word + " ";
  line.append(asset).append(" ").append(a).append(" ").append(b);
  if (kind == Kind::sound) {
    line += params.empty() ? " -" : " ";
    for (size_t i = 0; i < params.size(); ++i)
      line += (i ? "," : "") + params[i].name + ":" + std::to_string(params[i].value);
  }
  // Empty for a line the viewer would refuse: past kMaxMessage (three 255-byte paths), a bad path, name or value.
  return parse_asset_line(line) ? line : std::string();
}

// A member's SBA line into her ghost slot's names by key (glue/tick/worker.inc): fresh for a new key; again for the
// same line a second time (her game sends its whole book again once it becomes the pair, as the host moves her ghost
// to slot 0); refused for a bad line or another line for a key she named, since a key lives for the link session.
enum class Taken { fresh, again, refused };
inline Taken take_name(std::unordered_map<uint16_t, std::string> &names, const std::string &line) {
  const auto parsed = parse_asset_line(line);
  if (!parsed)
    return Taken::refused;
  const auto [it, fresh] = names.emplace(parsed->k, line);
  return fresh ? Taken::fresh : it->second == line ? Taken::again : Taken::refused;
}

// Every SBA line of this link session in order, as the game thread named them (glue/steam.cpp's, worker thread): a
// member who comes in later is sent each one from her cursor, at kNamesBytesPerSecond.
constexpr size_t kNamesBytesPerSecond = 8192;
class NameBook {
public:
  void add(std::string line) { lines_.push_back(std::move(line)); }
  size_t size() const { return lines_.size(); }
  const std::string &at(size_t i) const { return lines_[i]; }
  void clear() { lines_.clear(); }

private:
  std::vector<std::string> lines_;
};
// From cursor on, while the next line fits budget bytes and send(line) says yes (the link took it): each line sent
// takes its size from budget and moves the cursor past it. How many went.
template <class Send> size_t send_from(const NameBook &book, size_t &cursor, size_t &budget, Send &&send) {
  size_t n = 0;
  for (; cursor < book.size() && book.at(cursor).size() <= budget && send(book.at(cursor)); ++cursor, ++n)
    budget -= book.at(cursor).size();
  return n;
}

// Each ghost slot's member (her SteamID, 0 for none) as of the last pass: a slot whose member changed, to or from 0
// included, is reset; every slot is when the link session starts or ends. A k of the member before never names an
// asset of the next. Worker thread.
class SlotWatch {
public:
  template <class Reset> void pass(const uint64_t *ids, size_t n, bool linked, Reset &&reset) {
    for (size_t s = 0; s < n && s < kMaxRemote; ++s)
      if (linked != linked_ || ids[s] != ids_[s]) {
        ids_[s] = ids[s];
        reset(s);
      }
    linked_ = linked;
  }

private:
  std::array<uint64_t, kMaxRemote> ids_{};
  bool linked_ = false;
};

// One line of a ghost slot's coop-loaded file (the viewer's Lua appends one per key once its paths loaded):
// loaded <k> 0x<object> 0x<class> 0x<a|0> 0x<b|0>, a and b the sound's class and attenuation objects. Each whole line
// of text goes to out; false when any line was refused (k past 1 to kMaxAssetKeys, object or class 0, a bad word).
struct Loaded {
  uint16_t k;
  uint64_t object, cls, a, b;
};
inline bool parse_loaded(const std::string &text, std::vector<Loaded> &out) {
  bool ok = true;
  for (size_t at = 0; at < text.size();) {
    const size_t end = std::min(text.find('\n', at), text.size());
    const std::string_view line(text.data() + at, end - at);
    at = end + 1;
    std::string_view w[6];
    size_t n = 0;
    for (size_t from = 0; from <= line.size() && n <= 6;) {
      const size_t space = std::min(line.find(' ', from), line.size());
      if (n < 6)
        w[n] = line.substr(from, space - from);
      ++n;
      from = space + 1;
    }
    uint64_t v[4] = {};
    int64_t k = 0;
    bool good = n == 6 && w[0] == "loaded" && sba::number(w[1], 1, int64_t(kMaxAssetKeys), k);
    for (size_t i = 0; good && i < 4; ++i) {
      const std::string_view hex = w[2 + i];
      const char *end_of = hex.data() + hex.size();
      good = hex.size() > 2 && hex.size() <= 18 && hex.substr(0, 2) == "0x" &&
             std::from_chars(hex.data() + 2, end_of, v[i], 16).ptr == end_of;
    }
    if (good && v[0] && v[1])
      out.push_back({uint16_t(k), v[0], v[1], v[2], v[3]});
    else
      ok = false;
  }
  return ok;
}

// The game thread may call SB for the ghost's features when lion_gate is open (net mode 0, no logic task in flight),
// the client is in game (flow travel::kInGame) and playing (phase travel::kPlaying) and the caller is not SB's logic
// thread. These are world_in_game()'s conditions without its write of world_engine.caster.
inline bool game_calls_ok(bool gate_open, int32_t flow, int32_t phase, bool logic_thread) {
  return gate_open && flow == travel::kInGame && phase == travel::kPlaying && !logic_thread;
}

} // namespace coop::pose
