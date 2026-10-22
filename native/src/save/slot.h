// The co-op save slot (Phase 7, D2): the slot the game entered, read through a read function like the Night Operation
// probe's (ReadProcessMemory on the worker, which fails rather than faults; a fake image in
// tests/native/save/slot_test.cpp), the slot StellarCoopSlot.txt names beside the saves (tools/save_guard.py writes
// it), and the slot= status line made from both. coop no runs only on slot=coop. Nothing here writes a save or a file.
// No Windows types.
//
// The co-op saves (AUTO-COOP-SAVE): every slot file name starts with the GameSaveFileName string of SB's constant
// table, which the name builder (0x141cf7310) copies at each call. find() walks the table the builder's way to that
// string through the same read function; its last four characters, "Save" or "Coop", say which files the game uses:
// StellarBladeSave00-04.sav (the player's own) or StellarBladeCoop00-04.sav (the co-op copies, save/twins.h). Names
// keeps what was found and latches when the entry moves.
#pragma once

#include <climits>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include "game/memory.h" // plausible(), kImageBase

namespace coop::slot {

constexpr uint64_t kClient = 0x147032520; // The client game-flow singleton's pointer (getter 0x141a978c0), 8 bytes
                                          // before game::kGlobals. Its +0x54 is the slot the game entered (stored
                                          // by 0x141cd5e10) and names every in-game save's file (0x141ce5c30).
constexpr int kSlots = 5;                 // SaveSlotMaxCount: files 00-04 (WB_LoadGame has five); 05-09 are never listed.
constexpr size_t kMaxMarker = 4096;
constexpr int kUnread = INT32_MIN;                  // index: not read (see pose::loaded_slot).
constexpr int kNotRead = -3, kBad = -2, kNone = -1; // marker: not looked up yet; not one valid line; no file.

// The client's fields this file reads: the entered slot; the load the title asked for, its slot and its mode (the
// Continue and Load Game handlers set them, 2 for a load; 0 at boot [L]); the count of the title's slot list (rebuilt
// from the save files by 0x141cd4ef0 at StartClient and at each return to the title).
constexpr uint64_t kEntered = 0x54, kLoadSlot = 0x868, kLoadMode = 0x86c, kCacheCount = 0xa10;

// The int32 at client + offset, or kUnread when the pointer's read fails, the pointer is implausible (0 before the
// client exists: one read only) or the field's read fails. Two reads at most; read(address, out, n) returns false when
// the memory is unreadable.
template <class Read> int field(uint64_t base, Read &&read, uint64_t offset) {
  uint64_t client = 0;
  int32_t value = 0;
  if (!read(base + (kClient - game::kImageBase), &client, 8) || !game::plausible(client) ||
      !read(client + offset, &value, 4))
    return kUnread;
  return value;
}
// The slot the game entered: client +0x54.
template <class Read> int index(uint64_t base, Read &&read) { return field(base, read, kEntered); }

constexpr uint64_t kNames = 0x147032540;    // The constant table's pointer (getter 0x141a977b0), 0 until it exists.
constexpr uint64_t kKeyCache = 0x1471035ac; // The builder's cached key: 0 until its first call.
constexpr uint32_t kNameKey = 0xbb9194f2;   // UE4's Strihash_DEPRECATED of "GameSaveFileName".
constexpr uint32_t kMaxNames = 4096;        // SB's table holds about 200 constants; more is not its table.
constexpr int32_t kNameChars = 17;          // "StellarBladeSave" and its NUL, as the FString counts them.
// The name's last four characters as one little-endian word at its characters + 24: L"Save" and L"Coop".
constexpr uint64_t kSave = 0x0065007600610053, kCoop = 0x0070006f006f0043;

// Which save files the game uses: not read yet (or no table yet), the player's own, the co-op copies, or none of ours
// (another build, coop off, or a check failed).
enum class Saves { unread, main, coop, off };
inline const char *saves_name(Saves s) {
  return s == Saves::main ? "main" : s == Saves::coop ? "coop" : s == Saves::off ? "off" : "?";
}

// One walk: the verdict, why it is off or unread, and what was read on the way (for the probe).
struct Name {
  Saves saves = Saves::off;
  const char *why = "";
  uint64_t table = 0, entry = 0, data = 0; // The table, the element with the key, the FString's characters.
  int32_t num = -1;                        // The FString's count, NUL included.
  char text[kNameChars] = {};              // Its 16 characters as ASCII, '?' for any other.
};

// The GameSaveFileName entry, found as the builder finds it: the table's TMap {u32 key -> FString} has its sparse
// array's elements at +0xf8 (0x20 bytes each: key +0, FString +8 {characters, count +0x10}, next index in the bucket's
// chain +0x18), the array's count +0x100 and free count +0x12c, its buckets at +0x138 (inline at +0x130 when there is
// one bucket) and their count +0x140. Two independent facts make it ours: the key, and 17 characters reading
// "StellarBladeSave" or "StellarBladeCoop" with their NUL, 8-aligned so their last four are one word. Every count is
// checked before it is used and every chain ends within the array's count. Six reads when the table is SB's.
template <class Read> Name find(uint64_t base, Read &&read) {
  Name n;
  auto off = [&n](const char *why) {
    n.saves = Saves::off;
    n.why = why;
    return n;
  };
  if (!read(base + (kNames - game::kImageBase), &n.table, 8))
    return off("the table pointer is unreadable");
  if (!n.table) {
    n.saves = Saves::unread;
    n.why = "no table yet";
    return n;
  }
  if (!game::plausible(n.table))
    return off("the table pointer is implausible");
  uint8_t h[0x50]; // +0xf8 to +0x148.
  if (!read(n.table + 0xf8, h, sizeof h))
    return off("the table is unreadable");
  uint64_t elements = 0, hash = 0;
  int32_t count = 0, free = 0, size = 0;
  std::memcpy(&elements, h, 8);
  std::memcpy(&count, h + 0x8, 4);
  std::memcpy(&free, h + 0x34, 4);
  std::memcpy(&hash, h + 0x40, 8);
  std::memcpy(&size, h + 0x48, 4);
  if (free < 0 || count <= free || count > int32_t(kMaxNames) || !game::plausible(elements))
    return off("the table is empty or implausible");
  if (size < 1 || size > 65536 || (size & (size - 1)) || (!hash && size != 1) || (hash && !game::plausible(hash)))
    return off("the table's buckets are implausible");
  uint32_t at = 0;
  if (!read((hash ? hash : n.table + 0x130) + 4 * (kNameKey & uint32_t(size - 1)), &at, 4))
    return off("the table's bucket is unreadable");
  for (int32_t steps = 0; at != 0xffffffff; ++steps) {
    if (steps >= count || at >= uint32_t(count))
      return off("the table's chain is implausible");
    uint8_t e[0x20];
    if (!read(elements + uint64_t(at) * 0x20, e, sizeof e))
      return off("an element of the table is unreadable");
    uint32_t key = 0;
    std::memcpy(&key, e, 4);
    if (key != kNameKey) {
      std::memcpy(&at, e + 0x18, 4);
      continue;
    }
    n.entry = elements + uint64_t(at) * 0x20;
    std::memcpy(&n.data, e + 8, 8);
    std::memcpy(&n.num, e + 0x10, 4);
    if (n.num != kNameChars || !game::plausible(n.data))
      return off("the name is not 17 aligned characters");
    char16_t chars[kNameChars];
    if (!read(n.data, chars, sizeof chars))
      return off("the name is unreadable");
    for (int i = 0; i < kNameChars - 1; ++i)
      n.text[i] = chars[i] >= 0x20 && chars[i] < 0x7f ? char(chars[i]) : '?';
    if (!std::memcmp(chars, u"StellarBladeSave", sizeof chars))
      n.saves = Saves::main;
    else if (!std::memcmp(chars, u"StellarBladeCoop", sizeof chars))
      n.saves = Saves::coop;
    else
      return off("the name is neither StellarBladeSave nor StellarBladeCoop");
    return n;
  }
  return off("no GameSaveFileName entry");
}

// The worker's view of the name across reads (every 250 ms, and around a switch). Before the entry is found the state
// follows each read; once found, an entry that moves or no longer reads as one of the two names latches it to unread
// for the run, and no switch is made again (AUTO-COOP-SAVE §4.1, H6).
class Names {
public:
  Saves update(const Name &n) {
    if (latched_)
      return saves_;
    const bool ours = n.saves == Saves::main || n.saves == Saves::coop;
    if (ours && (!tail_ || tail_ == n.data + 24)) {
      tail_ = n.data + 24;
      why_.clear();
      return saves_ = n.saves;
    }
    if (tail_)
      return latch(ours ? std::string("the save name moved") : std::string("the save name no longer reads: ") + n.why);
    why_ = n.why;
    return saves_ = n.saves;
  }
  // The switch: the name read again, one compare-and-swap of its last four characters (cas(address, expected,
  // desired) is true only when it swapped; on the worker, under SEH), then the name read back. Empty once the name
  // reads the asked one; else why not. A failed swap or read-back latches: no switch again this run. A read-back that
  // fails after the swap says the name was written, since the game may use the other files from then on.
  template <class Read, class Cas> std::string swap(uint64_t base, Read &&read, Cas &&cas, bool coop) {
    const Saves from = coop ? Saves::main : Saves::coop, to = coop ? Saves::coop : Saves::main;
    if (update(find(base, read)) != from)
      return std::string("the save name reads ") + saves_name(saves_) + (why_.empty() ? "" : ": " + why_);
    if (!cas(tail_, coop ? kSave : kCoop, coop ? kCoop : kSave)) {
      latch("the save name could not be written");
      return why_;
    }
    if (update(find(base, read)) != to) {
      latch("the save name was written but did not read back: restart the game before you play");
      return why_;
    }
    return {};
  }
  Saves saves() const { return saves_; }
  bool latched() const { return latched_; }
  const std::string &why() const { return why_; } // Why the state is off or unread, or empty.
  uint64_t tail() const { return tail_; }         // The address of the name's last four characters, once found.

private:
  Saves latch(const std::string &why) {
    latched_ = true;
    why_ = why;
    return saves_ = Saves::unread;
  }
  uint64_t tail_ = 0;
  Saves saves_ = Saves::unread;
  bool latched_ = false;
  std::string why_ = "not read yet";
};

// Why the save files may not change now (the copies or the name), or empty: only at the title, which Lua says
// (coop-state.txt's world=title: a pawn on the title screen's map, so never during a loading screen, a New Game intro
// or with no Lua), with no save loaded (world=1) and no load asked there (client +0x86c is 0; 0 at boot [L], set by
// Continue and Load Game, and whether the game resets it at the title is for the probe to show), so a world never
// saves into the other files (AUTO-COOP-SAVE §4.3).
inline std::string not_title(bool world, bool title, int load_mode) {
  if (world)
    return "a save is loaded: quit to the title first";
  if (!title)
    return "the title screen is not shown";
  if (load_mode == kUnread)
    return "the game's load state is unreadable";
  if (load_mode)
    return "Continue or Load Game was chosen at the title (load mode " + std::to_string(load_mode) + ")";
  return {};
}

// One line for the log, read-only (T-AS0 step 1, H0): the client (0 before it exists) with its slot list's count, the
// title's pending load (slot and mode) and the entered slot; the table, the entry and its text; the verdict; and the
// builder's cached key (0 until the builder first ran).
template <class Read> std::string probe(uint64_t base, Read &&read) {
  char text[160];
  auto hex = [&text](uint64_t value) {
    std::snprintf(text, sizeof text, value ? "0x%llx" : "0", static_cast<unsigned long long>(value));
    return std::string(text);
  };
  auto number = [](int value) { return value == kUnread ? std::string("?") : std::to_string(value); };
  std::string s = "saves probe: client ";
  uint64_t client = 0;
  if (!read(base + (kClient - game::kImageBase), &client, 8))
    s += "?";
  else
    s += hex(client);
  if (client)
    s += " cache=" + number(field(base, read, kCacheCount)) + " load_slot=" + number(field(base, read, kLoadSlot)) +
         " load_mode=" + number(field(base, read, kLoadMode)) + " entered=" + number(field(base, read, kEntered));
  const Name n = find(base, read);
  s += "; table " + hex(n.table);
  if (n.entry) {
    s += " entry " + hex(n.entry) + " data " + hex(n.data) + " num " + std::to_string(n.num);
    if (n.text[0])
      s += std::string(" text ") + n.text;
  }
  s += std::string("; saves=") + saves_name(n.saves) + (*n.why ? std::string(" (") + n.why + ")" : std::string());
  uint32_t key = 0;
  if (read(base + (kKeyCache - game::kImageBase), &key, 4)) {
    std::snprintf(text, sizeof text, "%08x", key);
    s += std::string("; key cache ") + text;
  } else {
    s += "; key cache ?";
  }
  return s;
}

// StellarCoopSlot.txt's slot, 0 to 4, or kBad; the same grammar as save_guard.py's marked(): at most 4096 bytes, an
// optional UTF-8 BOM, lines split on '\n' and trimmed of spaces, tabs and '\r', blank and '#' lines dropped, and
// exactly one line left that is StellarBladeSave0N.sav with N in 0-4, ASCII case ignored. UTF-16 holds NUL bytes, so
// no line of it matches.
inline int marker(const std::string &text) {
  if (text.size() > kMaxMarker)
    return kBad;
  auto blank = [](char c) { return c == ' ' || c == '\t' || c == '\r'; };
  int slot = kBad, lines = 0;
  for (size_t at = text.compare(0, 3, "\xEF\xBB\xBF") ? 0 : 3, end; at <= text.size(); at = end + 1) {
    end = text.find('\n', at);
    if (end == std::string::npos)
      end = text.size();
    size_t a = at, b = end;
    while (a < b && blank(text[a]))
      ++a;
    while (b > a && blank(text[b - 1]))
      --b;
    if (a == b || text[a] == '#')
      continue;
    std::string line = text.substr(a, b - a);
    for (char &c : line)
      if (c >= 'A' && c <= 'Z')
        c = char(c - 'A' + 'a');
    slot = line.size() == 22 && !line.compare(0, 17, "stellarbladesave0") && line[17] >= '0' &&
                   line[17] < '0' + kSlots && !line.compare(18, 4, ".sav")
               ? line[17] - '0'
               : kBad;
    ++lines;
  }
  return lines == 1 ? slot : kBad;
}

// "slot=<coop|main|none|unknown> index=<n|?> marker=<n|none|bad|?> saves=<coop|main|off|?>", no '\n'. The first rule
// that applies: unknown while the name, the index or (unless the name is the co-op one) the marker is unread; none
// without a loaded save (the title, a map load); unknown for an index outside 0-4 (before it is compared, so -1 never
// equals kNone); coop on the co-op saves, the marker then ignored; coop when the marker names the entered slot (the
// legacy slot, on the player's own saves or with co-op saves off); main otherwise.
inline std::string line(int index, int marker, bool world, Saves saves) {
  const bool named = saves == Saves::coop;
  const char *verdict = saves == Saves::unread || index == kUnread || (!named && marker == kNotRead) ? "unknown"
                        : !world                                                                    ? "none"
                        : index < 0 || index >= kSlots                                              ? "unknown"
                        : named || marker == index                                                  ? "coop"
                                                                                                    : "main";
  return std::string("slot=") + verdict + " index=" + (index == kUnread ? "?" : std::to_string(index)) + " marker=" +
         (marker == kNotRead ? "?"
          : marker == kBad   ? "bad"
          : marker == kNone  ? "none"
                             : std::to_string(marker)) +
         " saves=" + saves_name(saves);
}

} // namespace coop::slot
