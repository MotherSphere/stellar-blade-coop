// The component table (Phase 3b): what a ghost is made of and the layout its poses travel in, in one plain ASCII
// grammar for Lua's capture file (coop-components.txt), the wire and the remote table the worker hands Lua; and the
// display file Lua answers with, naming the ghost it built. No Windows types: tests/native/pose/table_test.cpp checks
// it on the build machine, fuzzing the table parser.
//
// A table, every line ending in '\n', in this order, each where shown and nowhere else:
//   SBT <protocol>                                    the wire form only
//   generation <1 to 2^53>
//   map /<up to 127 of a-z 0-9 _ / ->                 the world's package path, lowercased
//   then for each part i from 0 (1 to kMaxParts parts):
//   part <i> <lead|-> <parent|-> <socket|-> <shown 0|1> <bones> <name> <path|->
//   place <i> qx qy qz qw tx ty tz sx sy sz           i >= 1 only: its transform relative to its parent
//   material <i> <slot> <path>                        0 to 16, slots 0 to 63 strictly rising: a material it overrides
//   cloth <i> <path>                                  optional: the PhysicsAsset its cloth collides with (her
//                                                     ponytail's OverrideClothPhysicsAsset, a CNS outfit's PonyPhysics)
//   mod <i> <label>                                   optional, a word: on a mod's mesh, the outfit it comes from (its
//                                                     CNS UniqueFitID, else the path's first two folders), for the
//                                                     viewer's notice when that mod is not installed there
//   names <i> <bone>...                               leaders only: one per bone, in the mesh's order
//   read <i> 0x<object> 0x<class> 0x<mesh>            leaders only, in the capture file only
//   then, in the capture file only, after the last part:
//   effects 0x<class> 0x<offset>                      the NiagaraComponent class and its Asset field's offset
//                                                     (0x100 to 0x1000, a multiple of 8): the native effect read
//   effect <k> 0x<system>                             0 to 32 after effects, k 1 to 32 strictly rising: Lua's list
//                                                     entry k is this NiagaraSystem object
// A leader has lead '-' and 1 to kMaxBones bones; part 0 is one, hung from nothing. A follower names a leader before
// it and has no bones of its own (SetMasterPoseComponent); every part after 0 hangs from a part before it. A word is 1
// to 64 bytes of '!' to '~'. The path alone may be longer: then it, like any path path_allowed refuses, reads as '-',
// and the viewer draws a fallback mesh instead of loading what a peer named. A material's or cloth's path is 1 to 255
// bytes, and one path_allowed refuses is dropped: the viewer keeps the mesh's own material for that slot, or the
// collision named from the body.
#pragma once

#include <algorithm>
#include <array>
#include <charconv>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <system_error>
#include <utility>
#include <vector>

#include "pose/core.h" // Part, hex(), kMaxParts, kMaxBones; number() and kProtocol from link/protocol.h

namespace coop::pose {

constexpr size_t kMaxTable = 65536, kMaxWord = 64, kMaxPath = 255, kMaxMap = 128, kMaxMaterials = 16, kMaxSlots = 64;
constexpr uint64_t kMaxGeneration = uint64_t(1) << 53; // Exact as a double too.

// What the ghost shows of one part, beside its Part in Table::eve.
struct Look {
  std::string name, path, socket; // path and socket are empty for '-'.
  int lead = -1, parent = -1;     // Part indexes, -1 for '-'.
  bool shown = true;
  float place[10]{};              // Relative to the parent: rotation xyzw, translation xyz, scale xyz. Not part 0's.
  std::vector<std::string> names; // A leader's bones.
  std::vector<std::pair<uint8_t, std::string>> materials; // Overridden slots and their paths, slots rising.
  std::string cloth, label;                                // Empty without a cloth or mod line.
};

struct Table {
  uint64_t generation = 0;
  std::string map;
  std::vector<Part> eve; // The pose layout: bones and leader always; addresses only from read lines.
  std::vector<Look> look;
  // The capture file's effect lines: cls 0 means no effect read. assets[k] is list entry k's object, 0 when not found.
  struct Fx {
    uint64_t cls = 0;
    uint32_t asset = 0; // UNiagaraComponent::Asset's offset.
    std::array<uint64_t, kMaxEffectAssets + 1> assets{};
  } fx;
};

// The ghost Lua built for a remote table, from its display file.
struct Display {
  uint64_t generation = 0, mailbox = 0, mailbox_class = 0;
  uint64_t effects[kEffectSlots] = {}; // The slot boxes, scene components of mailbox_class; all 0 without effects.
  std::vector<Part> puppet;                // Index for index with the remote parts; object 0: not drawn.
  std::vector<std::vector<int16_t>> remap; // Per bone of the loaded mesh, the remote bone it takes, -1 none; empty:
                                           // the remote bones as they are.
};

// The pose message's size: pose/codec.h writes the layout, but a table whose poses would not fit is refused here.
constexpr size_t kMaxPose = 16384, kPoseHeader = 29, kWorldBytes = 24, kBoneBytes = 18;

// The bytes a pose of this table takes (every message of a table has this one size), or 0 above kMaxPose.
inline size_t pose_size(const Table &t) {
  size_t size = kPoseHeader + kEffectSlots * kEffectBytes;
  for (size_t i = 0; i < t.eve.size(); ++i)
    size += 1 + (i == 0 ? kWorldBytes : 0) + (t.eve[i].leader ? kBoneBytes * t.eve[i].bones : 0);
  return t.eve.empty() || t.eve.size() > 255 || size > kMaxPose ? 0 : size;
}

// A mesh, material or cloth asset a peer may name: /Game/<folder>/.../<asset>.<asset>, each name of A-Z a-z 0-9 _ -,
// at most 255 bytes. So no '..', '//', '\' or sub-object, and the object is the package's own asset, which a Blueprint
// class (X.X_C) never is. Two families pass: the game's own, /Game/[DLC_<1 or 2 digits>/]Art/Character/... with no '-'
// (partner/capture.lua's Capture.base_path), which the viewer loads as before, and any other, an added-asset mod's
// (/Game/OutfitMods/<Mod>/..., /Game/Mods/HD-ATOOL_P/...), which partner/puppet.lua looks up only when the viewer's own
// CNS packs declare that path. This rule is syntax only, and cannot tell a map from a mesh: the Lua gate and the class
// check after loading decide what is used.
inline bool path_allowed(std::string_view path) {
  const std::string_view root = "/Game/";
  if (path.size() > kMaxPath || path.substr(0, root.size()) != root)
    return false;
  path.remove_prefix(root.size());
  size_t slash = path.rfind('/'), dot = path.find('.');
  if (slash == std::string_view::npos || dot == std::string_view::npos || dot < slash)
    return false;
  std::string_view asset = path.substr(slash + 1, dot - slash - 1);
  if (asset.empty() || path.substr(dot + 1) != asset)
    return false;
  for (size_t at = 0; at < dot; ++at) { // Folders and asset: names between single slashes.
    const char c = path[at];
    const bool name =
        (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '-';
    if (c == '/' ? at == 0 || path[at - 1] == '/' : !name)
      return false;
  }
  return true;
}

namespace grammar {
// One line's words: views into the text being read.
struct Words {
  const std::string_view *first = nullptr;
  size_t count = 0;
  size_t size() const { return count; }
  std::string_view operator[](size_t i) const { return first[i]; }
};

// A text's lines, read in order.
struct Lines {
  std::vector<std::string_view> words; // Every word of the text, sized once: the lines point into it.
  std::vector<Words> lines;
  size_t next = 0;
  bool done() const { return next == lines.size(); }
  // The next line, used up, when it is of this kind with this many words (0: any number); else null.
  const Words *take(const char *kind, size_t words = 0) {
    if (done() || lines[next][0] != kind || (words && lines[next].size() != words))
      return nullptr;
    return &lines[next++];
  }
};

// Splits on '\n' and single spaces. False when the last line does not end in '\n' (a file cut short) or a word is
// empty (an empty line, two spaces in a row, a space at either end) or has a byte outside '!' to '~' ('\r' among
// them: Lua writes its files in binary mode and turns any other byte into '_').
inline bool read_lines(const std::string &text, Lines &out) {
  if (text.empty() || text.back() != '\n')
    return false;
  const char *begin = text.data(), *end = begin + text.size();
  size_t words = 0, lines = 0;
  for (const char *at = begin; at != end; ++at) {
    char c = *at;
    if (c == '\n')
      ++lines;
    if (c == ' ' || c == '\n')
      ++words;
    else if (c < '!' || c > '~')
      return false;
  }
  out.words.resize(words);
  out.lines.resize(lines);
  size_t word = 0, line = 0, line_start = 0;
  for (const char *at = begin, *start = begin; at != end; ++at) {
    if (*at != ' ' && *at != '\n')
      continue;
    if (at == start)
      return false;
    out.words[word++] = std::string_view(start, size_t(at - start));
    start = at + 1;
    if (*at == '\n') {
      out.lines[line++] = {out.words.data() + line_start, word - line_start};
      line_start = word;
    }
  }
  return true;
}

inline bool index_is(const Words &line, size_t i) {
  uint64_t value = 0;
  return number(line[1], value) && value == i;
}

// A finite float, the whole word. std::from_chars takes no locale, no leading '+' and no space.
inline bool real(std::string_view word, float &out) {
  const char *end = word.data() + word.size();
  auto r = std::from_chars(word.data(), end, out);
  return r.ec == std::errc() && r.ptr == end && std::isfinite(out);
}

inline bool map_allowed(std::string_view map) {
  if (map.size() > kMaxMap || map[0] != '/')
    return false;
  for (char c : map)
    if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '_' || c == '/' || c == '-'))
      return false;
  return true;
}
} // namespace grammar

// The wire form: no read or effect lines, floats as %.9g, so a table always reads back to the same bytes. The native
// side sends and stores only this, never the text it received.
inline std::string format_table(const Table &t) {
  std::string s;
  char text[32];
  auto word = [&s](std::string_view w) { // A word after the line's first, '-' for none.
    s += ' ';
    s += w.empty() ? "-" : w;
  };
  auto integer = [&](int64_t n) {
    word(n < 0 ? "-" : std::string_view(text, size_t(std::to_chars(text, text + sizeof text, n).ptr - text)));
  };
  auto real = [&](float v) { // %.9g, which reads back to the same float, and without the locale printf would use.
    word({text, size_t(std::to_chars(text, text + sizeof text, v, std::chars_format::general, 9).ptr - text)});
  };
  s += "SBT";
  integer(kProtocol);
  s += "\ngeneration";
  integer(int64_t(t.generation));
  s += "\nmap";
  word(t.map);
  s += '\n';
  for (size_t i = 0; i < t.eve.size(); ++i) {
    const Look &l = t.look[i];
    s += "part";
    for (int64_t n : {int64_t(i), int64_t(l.lead), int64_t(l.parent)})
      integer(n);
    word(l.socket);
    integer(l.shown);
    integer(t.eve[i].bones);
    word(l.name);
    word(l.path);
    s += '\n';
    if (i > 0) {
      s += "place";
      integer(int64_t(i));
      for (float v : l.place)
        real(v);
      s += '\n';
    }
    for (const auto &[slot, path] : l.materials) {
      s += "material";
      integer(int64_t(i));
      integer(slot);
      word(path);
      s += '\n';
    }
    for (const std::string *text : {&l.cloth, &l.label})
      if (!text->empty()) {
        s += text == &l.cloth ? "cloth" : "mod";
        integer(int64_t(i));
        word(*text);
        s += '\n';
      }
    if (t.eve[i].leader) {
      s += "names";
      integer(int64_t(i));
      for (const std::string &name : l.names)
        word(name);
      s += '\n';
    }
  }
  return s;
}

// Lua's capture file (local: no SBT line, a read line after each leader's names, the effect lines last) or a table from
// the wire. Any line unknown, out of order, repeated or missing refuses the whole table.
inline std::optional<Table> parse_table(const std::string &text, bool local) {
  using namespace grammar;
  Lines in;
  if (text.size() > kMaxTable || !read_lines(text, in))
    return std::nullopt;
  Table t;
  t.eve.reserve(kMaxParts);
  t.look.reserve(kMaxParts);
  const Words *f;
  if (!local && !((f = in.take("SBT", 2)) && (*f)[1] == std::to_string(kProtocol)))
    return std::nullopt;
  if (!(f = in.take("generation", 2)) || !number((*f)[1], t.generation) || !t.generation ||
      t.generation > kMaxGeneration)
    return std::nullopt;
  if (!(f = in.take("map", 2)) || !map_allowed((*f)[1]))
    return std::nullopt;
  t.map = (*f)[1];
  while (!in.done()) {
    const size_t i = t.eve.size();
    if (local && (f = in.take("effects", 3))) { // After the last part: effect lines to the end.
      uint64_t offset = 0;
      if (!hex((*f)[1], t.fx.cls) || !t.fx.cls || !hex((*f)[2], offset) || offset < 0x100 || offset > 0x1000 ||
          offset % 8)
        return std::nullopt;
      t.fx.asset = static_cast<uint32_t>(offset);
      for (uint64_t k = 0, last = 0; (f = in.take("effect", 3)); last = k)
        if (!number((*f)[1], k) || k <= last || k > kMaxEffectAssets || !hex((*f)[2], t.fx.assets[k]) ||
            !t.fx.assets[k])
          return std::nullopt;
      if (!in.done())
        return std::nullopt;
      break;
    }
    if (i == kMaxParts || !(f = in.take("part", 9)) || !index_is(*f, i))
      return std::nullopt;
    const Words &p = *f;
    Part part;
    Look look;
    uint64_t lead = 0, parent = 0, bones = 0;
    part.leader = p[2] == "-";
    if (!part.leader && !(number(p[2], lead) && lead < i && t.eve[lead].leader))
      return std::nullopt;
    if (i == 0 ? p[3] != "-" : !(number(p[3], parent) && parent < i))
      return std::nullopt;
    if (p[4].size() > kMaxWord || (p[5] != "0" && p[5] != "1") || !number(p[6], bones) || p[7].size() > kMaxWord)
      return std::nullopt;
    if (part.leader ? !bones || bones > kMaxBones : bones != 0)
      return std::nullopt;
    part.bones = static_cast<uint32_t>(bones);
    look.lead = part.leader ? -1 : static_cast<int>(lead);
    look.parent = i == 0 ? -1 : static_cast<int>(parent);
    if (p[4] != "-")
      look.socket = p[4];
    look.shown = p[5] == "1";
    look.name = p[7];
    if (path_allowed(p[8]))
      look.path = p[8];
    if (i > 0) {
      if (!(f = in.take("place", 12)) || !index_is(*f, i))
        return std::nullopt;
      for (int k = 0; k < 10; ++k)
        if (!real((*f)[2 + k], look.place[k]))
          return std::nullopt;
      const float *q = look.place;
      double norm = double(q[0]) * q[0] + double(q[1]) * q[1] + double(q[2]) * q[2] + double(q[3]) * q[3];
      if (!(norm >= 0.9 && norm <= 1.1))
        return std::nullopt;
      for (int k = 4; k < 10; ++k)
        if (std::fabs(look.place[k]) > (k < 7 ? 1e5f : 100.f)) // cm, then scale.
          return std::nullopt;
    }
    // Every material line counts for the cap and the order, a dropped one too.
    int64_t last = -1;
    for (size_t n = 0; (f = in.take("material", 4)); ++n) {
      uint64_t slot = 0;
      if (n == kMaxMaterials || !index_is(*f, i) || !number((*f)[2], slot) || slot >= kMaxSlots ||
          int64_t(slot) <= last || (*f)[3].size() > kMaxPath)
        return std::nullopt;
      last = int64_t(slot);
      if (path_allowed((*f)[3]))
        look.materials.emplace_back(uint8_t(slot), (*f)[3]);
    }
    if ((f = in.take("cloth", 3))) {
      if (!index_is(*f, i) || (*f)[2].size() > kMaxPath)
        return std::nullopt;
      if (path_allowed((*f)[2]))
        look.cloth = (*f)[2];
    }
    if ((f = in.take("mod", 3))) {
      if (!index_is(*f, i) || (*f)[2].size() > kMaxWord)
        return std::nullopt;
      look.label = (*f)[2];
    }
    if (part.leader) {
      if (!(f = in.take("names", 2 + bones)) || !index_is(*f, i))
        return std::nullopt;
      for (size_t b = 2; b < f->size(); ++b) {
        if ((*f)[b].size() > kMaxWord)
          return std::nullopt;
        look.names.emplace_back((*f)[b]);
      }
      if (local && (!(f = in.take("read", 5)) || !index_is(*f, i) || !hex((*f)[2], part.object) ||
                    !hex((*f)[3], part.cls) || !hex((*f)[4], part.mesh) || !part.object || !part.cls || !part.mesh))
        return std::nullopt;
    }
    t.eve.push_back(part);
    t.look.push_back(std::move(look));
  }
  // The wire form must read back too. Only floats grow when formatted (".1" comes back as "0.100000001": at most 15
  // bytes for at least 1), and a capture file's SBT line is shorter than the read line it loses, so only a text this
  // close to the cap can grow past it.
  constexpr size_t kGrowth = kMaxParts * 10 * 14;
  if (t.eve.empty() || !pose_size(t) || (text.size() + kGrowth > kMaxTable && format_table(t).size() > kMaxTable))
    return std::nullopt;
  return t;
}

// Whether a ghost built for one table fits the other: the same parts, each with the same leader, bones and mesh path,
// as partner/puppet.lua's layout() compares. Lua builds a new ghost for another layout even under the same generation,
// and a display checked against one layout must never be paired with another (write_puppet indexes it by the remote
// parts).
inline bool same_layout(const Table &a, const Table &b) {
  if (a.eve.size() != b.eve.size() || a.look.size() != a.eve.size() || b.look.size() != b.eve.size())
    return false;
  for (size_t i = 0; i < a.eve.size(); ++i)
    if (a.eve[i].bones != b.eve[i].bones || a.look[i].lead != b.look[i].lead || a.look[i].path != b.look[i].path)
      return false;
  return true;
}

// Lua's display file for a remote table (coop-display.txt), every line ending in '\n':
//   display <the remote generation>
//   mailbox 0x<object> 0x<class>
//   effects 0x<box1> 0x<box2> 0x<box3> 0x<box4>              optional: the effect slots' boxes, of the mailbox's class
//   drive <i> 0x<object> 0x<class> 0x<loaded mesh> <bones>   each remote leader it built, part 0 among them
//   remap <i> <k0> ... <k(bones-1)>                           right after the drive line of a leader on a fallback
//                                                             mesh: per bone of that mesh, the remote bone or -1
// A remote leader with no drive line is not drawn: each pose's bytes for it are still read, and nothing is written.
inline std::optional<Display> parse_display(const std::string &text, const Table &remote) {
  using namespace grammar;
  Lines in;
  if (remote.eve.empty() || !read_lines(text, in))
    return std::nullopt;
  Display d;
  d.puppet.resize(remote.eve.size());
  d.remap.resize(remote.eve.size());
  const Words *f;
  if (!(f = in.take("display", 2)) || !number((*f)[1], d.generation) || d.generation != remote.generation)
    return std::nullopt;
  if (!(f = in.take("mailbox", 3)) || !hex((*f)[1], d.mailbox) || !hex((*f)[2], d.mailbox_class) || !d.mailbox ||
      !d.mailbox_class)
    return std::nullopt;
  if ((f = in.take("effects", 1 + kEffectSlots)))
    for (size_t n = 0; n < kEffectSlots; ++n) // Each its own: one written twice would carry only the last slot.
      if (!hex((*f)[1 + n], d.effects[n]) || !d.effects[n] || d.effects[n] == d.mailbox ||
          std::find(d.effects, d.effects + n, d.effects[n]) != d.effects + n)
        return std::nullopt;
  while (!in.done()) {
    uint64_t i = 0, bones = 0;
    Part p;
    if (!(f = in.take("drive", 6)) || !number((*f)[1], i) || i >= remote.eve.size() || !remote.eve[i].leader ||
        d.puppet[i].object || !hex((*f)[2], p.object) || !hex((*f)[3], p.cls) || !hex((*f)[4], p.mesh) || !p.object ||
        !p.cls || !p.mesh || !number((*f)[5], bones) || !bones || bones > kMaxBones)
      return std::nullopt;
    p.bones = static_cast<uint32_t>(bones);
    p.leader = true;
    d.puppet[i] = p;
    if ((f = in.take("remap"))) {
      if (f->size() != 2 + bones || !index_is(*f, i)) // The count first: a remap line may be one word.
        return std::nullopt;
      for (size_t k = 2; k < f->size(); ++k) {
        uint64_t from = 0;
        if ((*f)[k] == "-1")
          d.remap[i].push_back(-1);
        else if (number((*f)[k], from) && from < remote.eve[i].bones)
          d.remap[i].push_back(static_cast<int16_t>(from));
        else
          return std::nullopt;
      }
    } else if (bones != remote.eve[i].bones) { // Drawn as it came: the loaded mesh must have the remote bones.
      return std::nullopt;
    }
  }
  if (!d.puppet[0].object) // No body, no ghost.
    return std::nullopt;
  return d;
}

} // namespace coop::pose
