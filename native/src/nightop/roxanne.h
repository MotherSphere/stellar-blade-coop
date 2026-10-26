// Roxanne's Night Operation choices (nightop/roxanne.lua), free of Windows: tests/native/nightop/roxanne_test.cpp
// checks it against fake memory. Her dialogue's choice list, TS_Xion_Roxane_Choice, holds two TheaterSelectDataTable
// rows, Shop and End Conversation. SB does not read that list from the table when a dialogue starts: it reads a cache
// built before play, a TMap from a select list's name to the TArray of its row names, at the world singleton's (the
// global at 0x147032570) +0xe0 object's +0x5f0 (FUN_141b41090 finds the list with FUN_1417022e0 there, then fetches
// each listed row by name and reads its fields live). So a row of ours never shows by its SelectDataName, and AddRow
// would not list it either. Here the list's own entry in that cache is pointed at a TArray of six names of ours: four
// shipped test rows no story graph lists (Temp_TS_Select_Test_1 to _3 and TS_GoToTest_1, which nightop/roxanne.lua
// edits and gives its text), then her two rows, so End Conversation stays the last slot (the cancel input picks the
// last one) whether the widget sorts by priority (all six read 0) or not, and the select widget's six slots hold them
// all. The new array is SB's GMalloc's (FMalloc at 0x14706b500, Malloc at its vtable's +0x10), so SB may free it like
// its own: from the moment the entry points at it, it is SB's, reused only once off took it back, and an entry the game
// rebuilt meanwhile gets a new one. The old one is kept untouched, and off puts the old pointer, count and max back
// while the entry still points at ours. The entry is found again by name at each step (a rehash may move the map's
// elements), and it is changed only when it holds exactly her two rows, in her order.
// The writes: the pointer before the count when the list grows, the count before the pointer when it shrinks, so a
// reader between two writes never reads past an array; they run on the game thread under the rows' gate (net mode 0,
// no logic task in flight), glue/tick/nightop_game.inc, under their own SEH latch.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

#include "game/memory.h"
#include "lion/rows.h"

namespace coop::roxanne {

constexpr uint64_t kImageBase = 0x140000000, kWorldAt = 0x147032570, kMapFind = 0x1417022e0;
constexpr size_t kHolder = 0xe0, kMap = 0x5f0;
// A map element: the list's name at +0, its TArray of row names at +0x10 (data), +0x18 (count), +0x1c (max).
constexpr size_t kStride = 0x28, kData = 0x10, kCount = 0x18, kMax = 0x1c;
constexpr const char *kList = "TS_Xion_Roxane_Choice";
constexpr int32_t kOurs = 6, kHers = 2;
constexpr const char *kRows[kOurs] = {"Temp_TS_Select_Test_1", "Temp_TS_Select_Test_2", "Temp_TS_Select_Test_3",
                                      "TS_GoToTest_1",         "TS_Xion_Roxane_Choice_1", "TS_Xion_Roxane_Choice_2"};

// What the list's entry holds: no world or cache yet, no entry for her list, ours, hers (her two rows), or something
// else (another shape: changed by the game or another mod, never touched).
enum class Shape : uint8_t { unread, absent, ours, hers, other };
// Why an ask did nothing: the cache unread, her list absent, the entry not hers, no FName, no allocation, or the gate
// shut for kGateTicks (busy, net, unread).
enum class Why : uint8_t { none, unread, absent, other, name, alloc, busy, net, gate };
inline const char *why_word(Why w) {
  static const char *const kWords[] = {"none", "unread", "absent", "other", "name", "alloc", "busy", "net", "gate"};
  return size_t(w) < sizeof kWords / sizeof *kWords ? kWords[size_t(w)] : "?";
}
inline const char *shape_word(Shape s) {
  static const char *const kWords[] = {"unread", "absent", "on", "off", "other"};
  return kWords[size_t(s)];
}

// Ours, what the entry held before it pointed at ours, and whether the entry was left pointing at ours (no off since).
struct Swap {
  uint64_t ours = 0, old_data = 0;
  int32_t old_count = 0, old_max = 0;
  bool installed = false;
};

// Game: read(address, out, n) (false when unmapped), write(address, in, n), name(text, len, number) (FName's
// MakeWithNumber, 0 for none), find(map, name) (SB's FUN_1417022e0: the element's index, or -1), malloc(n) (SB's
// GMalloc, 0 for none).
template <class Game> uint64_t make(Game &g, const char *text) {
  const lion::NameParts p = lion::split_number(text); // FName's own split of a trailing number.
  return g.name(text, p.len, p.number);
}
// The address of her list's element in the cache, or 0 with shape unread or absent.
template <class Game> uint64_t element(Game &g, uint64_t base, Shape &shape) {
  uint64_t world = 0, holder = 0, elements = 0;
  shape = Shape::unread;
  if (!g.read(base + (kWorldAt - kImageBase), &world, 8) || !game::plausible(world) ||
      !g.read(world + kHolder, &holder, 8) || !game::plausible(holder) || !g.read(holder + kMap, &elements, 8) ||
      !game::plausible(elements))
    return 0;
  const uint64_t list = make(g, kList);
  const int32_t index = list ? g.find(holder + kMap, list) : -1;
  shape = Shape::absent;
  return index < 0 ? 0 : elements + uint64_t(index) * kStride;
}
// What her list's entry holds now.
template <class Game> Shape shape(Game &g, uint64_t base, const Swap &s) {
  Shape at = Shape::unread;
  const uint64_t e = element(g, base, at);
  if (!e)
    return at;
  uint64_t data = 0, names[kHers] = {};
  int32_t count = 0;
  if (!g.read(e + kData, &data, 8) || !g.read(e + kCount, &count, 4))
    return Shape::unread;
  if (s.ours && data == s.ours && count == kOurs) // The count too: SB may hand a freed array of ours out again.
    return Shape::ours;
  if (count != kHers || !game::plausible(data) || !g.read(data, names, sizeof names))
    return Shape::other;
  return names[0] == make(g, kRows[4]) && names[1] == make(g, kRows[5]) && names[0] && names[1] ? Shape::hers
                                                                                                : Shape::other;
}
// On: her entry pointed at our six names (reused after an off, a new array once the game rebuilt the entry). Why::none
// once it is ours.
template <class Game> Why arm(Game &g, uint64_t base, Swap &s) {
  const Shape now = shape(g, base, s);
  if (now == Shape::ours)
    return Why::none;
  if (now != Shape::hers)
    return now == Shape::unread ? Why::unread : now == Shape::absent ? Why::absent : Why::other;
  if (s.installed) // Hers again with no off: the game rebuilt the entry, and its TArray freed ours or holds it.
    s.ours = 0, s.installed = false;
  uint64_t names[kOurs];
  for (int32_t i = 0; i < kOurs; ++i)
    if (!(names[i] = make(g, kRows[i])))
      return Why::name;
  if (!s.ours && !(s.ours = g.malloc(sizeof names)))
    return Why::alloc;
  Shape at = Shape::unread;
  const uint64_t e = element(g, base, at);
  g.write(s.ours, names, sizeof names);
  g.read(e + kData, &s.old_data, 8);
  g.read(e + kCount, &s.old_count, 4);
  g.read(e + kMax, &s.old_max, 4);
  g.write(e + kData, &s.ours, 8); // The pointer first: a reader in between reads her two names at the front of ours.
  g.write(e + kCount, &kOurs, 4);
  g.write(e + kMax, &kOurs, 4);
  s.installed = true;
  return Why::none;
}
// Off: her two names back (the old pointer, count and max) while the entry still points at ours; true when it did.
template <class Game> bool disarm(Game &g, uint64_t base, Swap &s) {
  if (!s.ours || shape(g, base, s) != Shape::ours)
    return false;
  Shape at = Shape::unread;
  const uint64_t e = element(g, base, at);
  g.write(e + kCount, &s.old_count, 4); // The count first: never more names than the array behind the pointer.
  g.write(e + kMax, &s.old_max, 4);
  g.write(e + kData, &s.old_data, 8);
  s.installed = false; // Ours again: the next on reuses it.
  return true;
}

// coop-status.txt's roxanne line (nightop/roxanne.lua reads it):
//   roxanne=<unread|absent|on|off|other> asks=<a> want=<on|off> why=<word>
//   roxanne=fault asks=<a> where=<text, maybe with spaces>
// The entry's shape as of the game thread's last look (every 250 ms after the first ask; off: her two rows, other: a
// shape this never touches), the asks it handled, what the last one wanted and why it did nothing (none: done).
struct Status {
  Shape shape = Shape::unread;
  uint32_t asks = 0;
  bool want = false;
  Why why = Why::none;
  bool faulted = false;
  std::string fault;
};
inline std::string status_line(const Status &s) {
  if (s.faulted)
    return "roxanne=fault asks=" + std::to_string(s.asks) + " where=" + s.fault;
  return std::string("roxanne=") + shape_word(s.shape) + " asks=" + std::to_string(s.asks) +
         " want=" + (s.want ? "on" : "off") + " why=" + why_word(s.why);
}

} // namespace coop::roxanne
