// Roxanne's Night Operation choices (nightop/roxanne.lua) and Lily's signal choice (matrix13/quest/on_time.lua), free
// of Windows: tests/native/nightop/roxanne_test.cpp checks it against fake memory. Roxanne's dialogue's choice list,
// TS_Xion_Roxane_Choice, holds two TheaterSelectDataTable rows, Shop and End Conversation; Lily's, TS_Xion_Lily_Choice,
// holds eight (the bike signal, four About Enya rows, Travel to Another Region, Repair Console, End Conversation). SB
// does not read a list from the table when a dialogue starts: it reads a cache built before play, a TMap from a select
// list's name to the TArray of its row names, at the world singleton's (the global at 0x147032570) +0xe0 object's
// +0x5f0 (FUN_141b41090 finds the list with FUN_1417022e0 there, then fetches each listed row by name and reads its
// fields live). So a row of ours never shows by its SelectDataName, and AddRow would not list it either. Here a list's
// own entry in that cache is pointed at a TArray of names: our rows first, then the list's own rows as the entry held
// them. Roxanne's are four shipped test rows no story graph lists (Temp_TS_Select_Test_1 to _3 and TS_GoToTest_1,
// which nightop/roxanne.lua edits and gives its text), so End Conversation stays the last slot (the cancel input picks
// the last one) whether the widget sorts by priority (all six read 0) or not, and the select widget's six slots hold
// them all. Lily's is one, TS_GoToTest_2, which lion/rows.h's signal batch patches in place (priority 3: sorted by
// priority it stands below her bike signal and above her Travel, Repair and End rows; unsorted it stands first, End
// staying last either way); the game hides the rows whose conditions fail before the widget fills, as it does for her
// own eight. Roxanne's two rows must be in her order; Lily's eight are checked as a set, since the cache's order of
// them is not known, and kept in that order.
// The new array is SB's GMalloc's (FMalloc at 0x14706b500, Malloc at its vtable's +0x10), so SB may free it like
// its own: from the moment the entry points at it, it is SB's, reused only once off took it back, and an entry the game
// rebuilt meanwhile gets a new one. The old one is kept untouched, and off puts the old pointer, count and max back
// while the entry still points at ours. The entry is found again by name at each step (a rehash may move the map's
// elements), and it is changed only when it holds exactly the list's own rows.
// The writes: the pointer before the count when the list grows, the count before the pointer when it shrinks, so a
// reader between two writes never reads past an array; they run on the game thread under the rows' gate (net mode 0,
// no logic task in flight), glue/tick/nightop_game.inc, under each list's own SEH latch.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>

#include "game/memory.h"
#include "lion/rows.h"

namespace coop::roxanne {

constexpr uint64_t kImageBase = 0x140000000, kWorldAt = 0x147032570, kMapFind = 0x1417022e0;
constexpr size_t kHolder = 0xe0, kMap = 0x5f0;
// A map element: the list's name at +0, its TArray of row names at +0x10 (data), +0x18 (count), +0x1c (max).
constexpr size_t kStride = 0x28, kData = 0x10, kCount = 0x18, kMax = 0x1c;
// A list: its status line's word, its name in the cache, its own rows, ours, and whether its own rows must be in the
// order given (else in any order, each once).
struct List {
  const char *word, *name;
  const char *const *theirs;
  int32_t their_count;
  const char *const *ours;
  int32_t our_count;
  bool ordered;
};
constexpr int32_t kMaxNames = 16; // Ours and theirs together, at most.
constexpr const char *kRoxanneRows[] = {"TS_Xion_Roxane_Choice_1", "TS_Xion_Roxane_Choice_2"};
constexpr const char *kRoxanneOurs[] = {"Temp_TS_Select_Test_1", "Temp_TS_Select_Test_2", "Temp_TS_Select_Test_3",
                                        "TS_GoToTest_1"};
constexpr List kRoxanne{"roxanne", "TS_Xion_Roxane_Choice", kRoxanneRows, 2, kRoxanneOurs, 4, true};
constexpr const char *kLilyRows[] = {"TS_Xion_Lily_Choice_1", "TS_Xion_Lily_Choice_2", "TS_Xion_Lily_Choice_3",
                                     "TS_Xion_Lily_Choice_4", "TS_Xion_Lily_Choice_5", "TS_Xion_Lily_Choice_6",
                                     "TS_Xion_Lily_Choice_7", "TS_Xion_Lily_Choice_8"};
constexpr const char *kLilyOurs[] = {"TS_GoToTest_2"};
constexpr List kLily{"lily", "TS_Xion_Lily_Choice", kLilyRows, 8, kLilyOurs, 1, false};
static_assert(kRoxanne.their_count + kRoxanne.our_count <= kMaxNames &&
                  kLily.their_count + kLily.our_count <= kMaxNames,
              "a list's names fit");

// What the list's entry holds: no world or cache yet, no entry for the list, ours, hers (the list's own rows), or
// something else (another shape: changed by the game or another mod, never touched).
enum class Shape : uint8_t { unread, absent, ours, hers, other };
// Why an ask did nothing: the cache unread, the list absent, the entry not the list's own, no FName, no allocation,
// or the gate shut for kGateTicks (busy, net, unread).
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
// The address of the list's element in the cache, or 0 with shape unread or absent.
template <class Game> uint64_t element(Game &g, uint64_t base, const List &l, Shape &shape) {
  uint64_t world = 0, holder = 0, elements = 0;
  shape = Shape::unread;
  if (!g.read(base + (kWorldAt - kImageBase), &world, 8) || !game::plausible(world) ||
      !g.read(world + kHolder, &holder, 8) || !game::plausible(holder) || !g.read(holder + kMap, &elements, 8) ||
      !game::plausible(elements))
    return 0;
  const uint64_t list = make(g, l.name);
  const int32_t index = list ? g.find(holder + kMap, list) : -1;
  shape = Shape::absent;
  return index < 0 ? 0 : elements + uint64_t(index) * kStride;
}
// Whether names (count of them) are the list's own rows: in its order, or each once in any order.
template <class Game> bool theirs(Game &g, const List &l, const uint64_t *names, int32_t count) {
  if (count != l.their_count)
    return false;
  bool seen[kMaxNames] = {};
  for (int32_t i = 0; i < count; ++i) {
    int32_t k = 0;
    while (k < count && (seen[k] || (l.ordered && k != i) || names[i] != make(g, l.theirs[k])))
      ++k;
    if (k == count || !names[i])
      return false;
    seen[k] = true;
  }
  return true;
}
// What the list's entry holds now; names gets them when they are the list's own rows.
template <class Game> Shape shape(Game &g, uint64_t base, const List &l, const Swap &s, uint64_t *names = nullptr) {
  Shape at = Shape::unread;
  const uint64_t e = element(g, base, l, at);
  if (!e)
    return at;
  uint64_t data = 0, read[kMaxNames] = {};
  int32_t count = 0;
  if (!g.read(e + kData, &data, 8) || !g.read(e + kCount, &count, 4))
    return Shape::unread;
  // The count too: SB may hand a freed array of ours out again.
  if (s.ours && data == s.ours && count == l.our_count + l.their_count)
    return Shape::ours;
  if (count != l.their_count || !game::plausible(data) || !g.read(data, read, 8 * size_t(count)) ||
      !theirs(g, l, read, count))
    return Shape::other;
  if (names)
    std::memcpy(names, read, 8 * size_t(count));
  return Shape::hers;
}
// On: the entry pointed at our names, then the list's own as the entry held them (reused after an off, a new array
// once the game rebuilt the entry). Why::none once it is ours.
template <class Game> Why arm(Game &g, uint64_t base, const List &l, Swap &s) {
  uint64_t names[kMaxNames] = {};
  const Shape now = shape(g, base, l, s, names + l.our_count);
  if (now == Shape::ours)
    return Why::none;
  if (now != Shape::hers)
    return now == Shape::unread ? Why::unread : now == Shape::absent ? Why::absent : Why::other;
  if (s.installed) // Hers again with no off: the game rebuilt the entry, and its TArray freed ours or holds it.
    s.ours = 0, s.installed = false;
  const int32_t total = l.our_count + l.their_count;
  for (int32_t i = 0; i < l.our_count; ++i)
    if (!(names[i] = make(g, l.ours[i])))
      return Why::name;
  if (!s.ours && !(s.ours = g.malloc(8 * size_t(total))))
    return Why::alloc;
  Shape at = Shape::unread;
  const uint64_t e = element(g, base, l, at);
  g.write(s.ours, names, 8 * size_t(total));
  g.read(e + kData, &s.old_data, 8);
  g.read(e + kCount, &s.old_count, 4);
  g.read(e + kMax, &s.old_max, 4);
  g.write(e + kData, &s.ours, 8); // The pointer first: a reader in between reads the old count of names from ours.
  g.write(e + kCount, &total, 4);
  g.write(e + kMax, &total, 4);
  s.installed = true;
  return Why::none;
}
// Off: the list's own names back (the old pointer, count and max) while the entry still points at ours; true when it
// did.
template <class Game> bool disarm(Game &g, uint64_t base, const List &l, Swap &s) {
  if (!s.ours || shape(g, base, l, s) != Shape::ours)
    return false;
  Shape at = Shape::unread;
  const uint64_t e = element(g, base, l, at);
  g.write(e + kCount, &s.old_count, 4); // The count first: never more names than the array behind the pointer.
  g.write(e + kMax, &s.old_max, 4);
  g.write(e + kData, &s.old_data, 8);
  s.installed = false; // Ours again: the next on reuses it.
  return true;
}

// coop-status.txt's roxanne and lily lines (nightop/roxanne.lua and matrix13/quest/on_time.lua read them), <word>
// the list's:
//   <word>=<unread|absent|on|off|other> asks=<a> want=<on|off> why=<word>
//   <word>=fault asks=<a> where=<text, maybe with spaces>
// The entry's shape as of the game thread's last look (every 250 ms after the first ask; off: the list's own rows,
// other: a shape this never touches), the asks it handled, what the last one wanted and why it did nothing (none:
// done).
struct Status {
  Shape shape = Shape::unread;
  uint32_t asks = 0;
  bool want = false;
  Why why = Why::none;
  bool faulted = false;
  std::string fault;
};
inline std::string status_line(const List &l, const Status &s) {
  if (s.faulted)
    return std::string(l.word) + "=fault asks=" + std::to_string(s.asks) + " where=" + s.fault;
  return std::string(l.word) + "=" + shape_word(s.shape) + " asks=" + std::to_string(s.asks) +
         " want=" + (s.want ? "on" : "off") + " why=" + why_word(s.why);
}

} // namespace coop::roxanne
