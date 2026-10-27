// coop shortcut load: one of the cut Load Shortcut menu's developer saves (save/shortcut.h) made into a save the
// released game loads, with its achievement data taken out. glue/steam.cpp writes the result into co-op slot 5
// (StellarBladeCoop04.sav) through save/twins.h's Convert::plant; the player loads it with the game's own Load Game.
//
// What the game does with a loaded save (Ghidra, 2026-10-27): FUN_1421def10 runs nine fix-up passes on it. The save's
// achievement list (SBAchievement, USBSaveGame +0x2c8: AchievementList of {AchievementAlias, ProgressValue,
// bCompleted, bRecievedReward}) is read by six of them: FUN_1421defb0 writes its count of Ach_Album_Unlock_* entries
// into the Trophy_KillCharacter_AllNative entry, FUN_1421e1ff0 queues an achievement event for that entry (the path to
// Steam), FUN_1421e21f0 raises PlayerActor's weapon level from Trophy_WeaponMaxUpgrade, FUN_1421e3860 changes a
// Matrix 11 door from a completed entry, FUN_1421e41e0 adds completed Ach_BossChal_Unlock_* entries and
// FUN_1421e5e60 reads Nest_Ending. FUN_1421e41e0 also adds those entries for six gears in the inventory
// (DataMap_SBItem's Item, Inventory): the only pass that makes achievement data from anything but the list. The others
// read quests, zone objects, PlayerActor, DataMap_int32 and NewGamePlusBaseData and write only those.
//
// So clean() drops the top-level SBAchievement property (the save object then starts with an empty list), and every
// inventory and ItemOtaineSet entry of those six gears and of the seven items the released ItemTable has no row for.
// The developer's quests, zone objects, skills and camps stay: they are the chapter. It takes only the 15 files the
// pinned build's paks hold, by their CRC-32, the bytes tests/native/save/shortcut_load_test.cpp checked: no
// achievement name left, every item left with an ItemTable row. The result is wrapped as the game's save writer
// (FSBSaveSystemWindows::OnCompleteSerialize, FUN_1421f5de0) wraps its own: "EVAS", version byte 1, three bytes the
// writer leaves unset (0 here, as most real saves hold), the GVAS body, then its CRC-32 (FUN_1428dbbd0, zlib's) in
// little endian. The GVAS header keeps the file's own engine and package versions, which the loader honours.
//
// GVAS as UE 4.25 and 4.26 write it: the header, then tagged properties up to "None", then 4 bytes. A tag is its name
// and type (FStrings), its value's size and an array index, then by type: StructProperty its struct name and a GUID,
// BoolProperty its value, Byte and EnumProperty the enum's name, Array and SetProperty the inner type, MapProperty the
// key and value types; then a byte that says a property GUID follows. Elements of arrays, sets and maps carry no tag:
// a struct element is its properties up to None. No Windows types.
#pragma once

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "save/shortcut.h" // name()
#include "save/twins.h"    // crc32(), game_save()

namespace coop::shortcut {

constexpr int kSlot = 4; // Co-op slot 5, StellarBladeCoop04.sav: the one a shortcut save goes to.
// The 12 distinct files' CRC-32 in the pinned build's paks (G03 2 to 4 are F02 1 to 3).
constexpr uint32_t kPinned[] = {0x7edc57b1, 0xea03b476, 0x6fd0b77e, 0x00602f19, 0x7d2dd982, 0x22f93399,
                                0x0b6a83e8, 0xf2329ce2, 0x2d33039c, 0xc93f5d31, 0x864887b3, 0x0b9dd5d3};
// Items dropped, ASCII case ignored as FName compares: FUN_1421e41e0's six gears, then the seven with no ItemTable row
// (the 2026-10-26 table dump).
constexpr const char *kDropped[] = {"Gear_HighHpDamageAdditiveRate_Common",
                                    "Gear_KillEnemyAdditiveDamageRate_Common",
                                    "Gear_KillEnemyAdditiveDamageRate_Uncommon",
                                    "Gear_GainBurstGaugeValueOnDamaged_Common",
                                    "Gear_GainBurstGaugeValueOnDamaged_Uncommon",
                                    "Gear_AdditiveGiveAndReciveDamageRate_Rare",
                                    "BS_Attacker",
                                    "BS_Defender",
                                    "Buff_HP2MP",
                                    "Gear_NarrowVision_Rare",
                                    "DesignPattern_Blue_Suit",
                                    "DesignPattern_Sailor_Jean",
                                    "DesignPattern_Black_Leather_bikini"};
constexpr char kClass[] = "/Script/SB.SBSaveGame";

inline bool same_name(const std::string &a, const char *b) {
  auto low = [](char c) { return c >= 'A' && c <= 'Z' ? char(c - 'A' + 'a') : c; };
  if (a.size() != std::strlen(b))
    return false;
  for (size_t i = 0; i < a.size(); ++i)
    if (low(a[i]) != low(b[i]))
      return false;
  return true;
}
inline bool dropped(const std::string &item) {
  for (const char *d : kDropped)
    if (same_name(item, d))
      return true;
  return false;
}

inline std::string i32(int32_t v) { return std::string(reinterpret_cast<const char *>(&v), 4); }
inline bool get32(const std::string &b, size_t at, size_t end, int32_t &v) {
  if (at + 4 > end)
    return false;
  std::memcpy(&v, b.data() + at, 4);
  return true;
}
// An FString at b[at] within end: its text (empty for a UTF-16 one, which no name here is), at moved past it.
inline bool text(const std::string &b, size_t &at, size_t end, std::string *out) {
  int32_t n = 0;
  if (!get32(b, at, end, n) || n < -(1 << 20) || n > (1 << 20))
    return false;
  const size_t bytes = n < 0 ? size_t(-n) * 2 : size_t(n);
  if (at + 4 + bytes > end)
    return false;
  if (out)
    out->assign(n > 0 ? b.substr(at + 4, bytes - 1) : std::string());
  at += 4 + bytes;
  return true;
}

// One tag: start (its name), size_at (its size field), value (where its value starts), end (where it ends).
struct Tag {
  std::string name, type, inner, value_type; // inner: Array and Set's type, Map's key type, Struct's struct name.
  size_t start = 0, size_at = 0, value = 0, end = 0;
};
// The tag at b[at] within end, at moved past its value; "None" ends a list (value == end then). False when cut.
inline bool tag(const std::string &b, size_t &at, size_t end, Tag &t) {
  t = Tag();
  t.start = at;
  if (!text(b, at, end, &t.name))
    return false;
  if (t.name == "None") {
    t.value = t.end = at;
    return true;
  }
  int32_t size = 0;
  if (!text(b, at, end, &t.type) || !get32(b, at, end, size) || size < 0)
    return false;
  t.size_at = at;
  at += 8; // The size and the array index.
  if (t.type == "StructProperty") {
    if (!text(b, at, end, &t.inner))
      return false;
    at += 16;
  } else if (t.type == "BoolProperty") {
    at += 1;
  } else if (t.type == "ByteProperty" || t.type == "EnumProperty" || t.type == "ArrayProperty" ||
             t.type == "SetProperty") {
    if (!text(b, at, end, &t.inner))
      return false;
  } else if (t.type == "MapProperty") {
    if (!text(b, at, end, &t.inner) || !text(b, at, end, &t.value_type))
      return false;
  }
  if (at >= end)
    return false;
  at += 1 + (b[at] ? 16 : 0);
  t.value = at;
  t.end = at + size_t(size);
  if (t.value > end || t.end > end)
    return false;
  at = t.end;
  return true;
}
// Past the None of the property list at b[at], or 0 when it is cut.
inline size_t list_end(const std::string &b, size_t at, size_t end) {
  for (Tag t; tag(b, at, end, t);)
    if (t.name == "None")
      return at;
  return 0;
}
// A tag with a new value: its bytes up to the value, its size field set to the new size.
inline std::string retag(const std::string &b, const Tag &t, const std::string &value) {
  std::string s = b.substr(t.start, t.value - t.start);
  const int32_t n = int32_t(value.size());
  std::memcpy(&s[t.size_at - t.start], &n, 4);
  return s + value;
}

// The items an inventory element names: its ItemAlias and its ItemInstance's (the released game's saves leave the first
// None), from the element's properties at b[at] within end.
inline void element_items(const std::string &b, size_t at, size_t end, std::vector<std::string> &names) {
  for (Tag t; tag(b, at, end, t) && t.name != "None";) {
    size_t v = t.value;
    std::string item;
    if (t.name == "ItemAlias" && t.type == "NameProperty" && text(b, v, t.end, &item) && item != "None")
      names.push_back(item);
    if (t.name == "ItemInstance" && t.type == "StructProperty")
      element_items(b, t.value, t.end, names);
  }
}

// What one pass over DataMap_SBItem saw: the item names kept and those dropped, in order.
struct Items {
  std::vector<std::string> kept, gone;
};
// An Inventory array (StructProperty elements) at [v, e) without the elements that name a dropped item; false when cut.
inline bool inventory(const std::string &b, size_t v, size_t e, std::string &out, Items &items) {
  int32_t count = 0, size = 0;
  size_t at = v + 4;
  std::string word;
  if (!get32(b, v, e, count) || count < 0 || !text(b, at, e, nullptr) || !text(b, at, e, &word) ||
      word != "StructProperty")
    return false;
  const size_t size_at = at;
  if (!get32(b, at, e, size))
    return false;
  at += 8; // The size and the index, then the struct's name and a GUID.
  if (!text(b, at, e, nullptr) || (at += 16) >= e)
    return false;
  at += 1 + (b[at] ? 16 : 0);
  if (size < 0 || at + size_t(size) != e)
    return false;
  std::string head = b.substr(v + 4, at - v - 4), kept;
  int32_t left = 0;
  for (int32_t i = 0; i < count; ++i) {
    const size_t next = list_end(b, at, e);
    if (!next)
      return false;
    std::vector<std::string> names;
    element_items(b, at, next, names);
    bool drop = false;
    for (const std::string &item : names)
      drop = drop || dropped(item);
    std::vector<std::string> &list = drop ? items.gone : items.kept;
    list.insert(list.end(), names.begin(), names.end());
    if (!drop) {
      kept += b.substr(at, next - at);
      ++left;
    }
    at = next;
  }
  if (at != e)
    return false;
  const int32_t n = int32_t(kept.size());
  std::memcpy(&head[size_at - v - 4], &n, 4);
  out = i32(left) + head + kept;
  return true;
}
// ItemOtaineSet, a set of names, at [v, e) without the dropped items; false when cut.
inline bool obtained(const std::string &b, size_t v, size_t e, std::string &out, Items &items) {
  int32_t removed = 0, count = 0;
  if (!get32(b, v, e, removed) || removed != 0 || !get32(b, v + 4, e, count) || count < 0)
    return false;
  std::string kept;
  int32_t left = 0;
  size_t at = v + 8;
  for (int32_t i = 0; i < count; ++i) {
    const size_t from = at;
    std::string item;
    if (!text(b, at, e, &item))
      return false;
    if (dropped(item)) {
      items.gone.push_back(item);
    } else {
      items.kept.push_back(item);
      kept += b.substr(from, at - from);
      ++left;
    }
  }
  if (at != e)
    return false;
  out = i32(0) + i32(left) + kept;
  return true;
}
// DataMap_SBItem's value (names to structs) at [v, e), each struct's Inventory and ItemOtaineSet rebuilt.
inline bool item_map(const std::string &b, size_t v, size_t e, std::string &out, Items &items) {
  int32_t removed = 0, count = 0;
  if (!get32(b, v, e, removed) || removed != 0 || !get32(b, v + 4, e, count) || count < 0)
    return false;
  out = b.substr(v, 8);
  size_t at = v + 8;
  for (int32_t i = 0; i < count; ++i) {
    const size_t key = at;
    if (!text(b, at, e, nullptr))
      return false;
    out += b.substr(key, at - key);
    for (Tag t;;) {
      if (!tag(b, at, e, t))
        return false;
      std::string value;
      if (t.name == "Inventory" && t.type == "ArrayProperty" && t.inner == "StructProperty") {
        if (!inventory(b, t.value, t.end, value, items))
          return false;
        out += retag(b, t, value);
      } else if (t.name == "ItemOtaineSet" && t.type == "SetProperty" && t.inner == "NameProperty") {
        if (!obtained(b, t.value, t.end, value, items))
          return false;
        out += retag(b, t, value);
      } else {
        out += b.substr(t.start, t.end - t.start);
      }
      if (t.name == "None")
        break;
    }
  }
  return at == e;
}

// A GVAS save's parts: where its properties start, its class, its top-level tags (None last) and where they end.
struct Body {
  size_t first = 0, end = 0;
  std::string cls;
  std::vector<Tag> tags;
};
inline bool body(const std::string &b, Body &out) {
  out = Body();
  size_t at = 22; // "GVAS", the save and package versions, the engine's three numbers and changelist.
  int32_t format = 0, count = 0;
  if (b.size() < 26 || b.compare(0, 4, "GVAS") || !text(b, at, b.size(), nullptr) || !get32(b, at, b.size(), format) ||
      !get32(b, at + 4, b.size(), count) || count < 0 || count > 1024)
    return false;
  at += 8 + size_t(count) * 20; // Each custom version: a GUID and a number.
  if (!text(b, at, b.size(), &out.cls))
    return false;
  out.first = at;
  for (Tag t; tag(b, at, b.size(), t);) {
    out.tags.push_back(t);
    if (t.name == "None") {
      out.end = at;
      return true;
    }
  }
  return false;
}

// The finished save: "EVAS", version 1, three zero bytes, the GVAS body, its CRC-32.
inline std::string wrap(const std::string &gvas) {
  const uint32_t crc = twins::crc32(gvas.data(), gvas.size());
  return std::string("EVAS\x01\0\0\0", 8) + gvas + std::string(reinterpret_cast<const char *>(&crc), 4);
}

// Why a built save is not one the game loads as we mean it, or empty: the game's own check (EVAS, version 1, CRC), a
// GVAS body of class SBSaveGame whose tags all fit and end in None with the 4 trailing bytes after it, no
// SBAchievement, one DataMap_SBItem that parses with no dropped item left. items: what that DataMap_SBItem names.
inline std::string check(const std::string &save, Items &items) {
  items = Items();
  if (!twins::game_save(save))
    return "it fails the game's own check (EVAS header and CRC)";
  const std::string gvas = save.substr(8, save.size() - 12);
  Body parts;
  if (!body(gvas, parts) || parts.cls != kClass)
    return "its GVAS body does not parse as an SBSaveGame";
  if (parts.end + 4 != gvas.size())
    return "bytes follow its properties";
  bool map = false;
  for (const Tag &t : parts.tags) {
    if (t.name == "SBAchievement")
      return "it still holds SBAchievement";
    if (t.name == "DataMap_SBItem") {
      std::string ignored;
      if (map || t.type != "MapProperty" || !item_map(gvas, t.value, t.end, ignored, items))
        return "its DataMap_SBItem does not parse";
      map = true;
    }
  }
  if (!items.gone.empty())
    return "it still holds " + items.gone.front();
  return {};
}

// What clean() did, for the log.
struct Cleaned {
  size_t achievement = 0; // SBAchievement's bytes, 0 when there was none.
  Items items;            // DataMap_SBItem's items kept and dropped.
};
// A GVAS SBSaveGame's bytes made into a save the game loads (see the top of this file), with no pin: empty with save
// set, or why not (save then empty). clean() is the one the mod calls.
inline std::string build(const std::string &file, std::string &save, Cleaned &done) {
  save.clear();
  done = Cleaned();
  Body parts;
  if (!body(file, parts) || parts.cls != kClass || parts.end + 4 != file.size())
    return "it does not parse as an SBSaveGame";
  std::string gvas = file.substr(0, parts.first);
  for (const Tag &t : parts.tags) {
    std::string value;
    if (t.name == "SBAchievement") {
      done.achievement = t.end - t.start;
    } else if (t.name == "DataMap_SBItem" && t.type == "MapProperty") {
      if (!item_map(file, t.value, t.end, value, done.items))
        return "its DataMap_SBItem does not parse";
      gvas += retag(file, t, value);
    } else {
      gvas += file.substr(t.start, t.end - t.start);
    }
  }
  gvas += file.substr(parts.end);
  std::string built = wrap(gvas);
  Items left;
  if (const std::string why = check(built, left); !why.empty())
    return "the cleaned save fails its check: " + why;
  save = std::move(built);
  return {};
}
// One of the 15 files, by its CRC-32, through build(); any other bytes are refused.
inline std::string clean(const std::string &file, std::string &save, Cleaned &done) {
  const uint32_t crc = twins::crc32(file.data(), file.size());
  for (uint32_t c : kPinned)
    if (c == crc)
      return build(file, save, done);
  save.clear();
  done = Cleaned();
  return "it is not one of the 15 files checked for this build";
}

// The log's line for a cleaned file: what went, each dropped item named once.
inline std::string cleaned_line(int file, const Cleaned &done, size_t bytes) {
  std::vector<std::string> names;
  std::string gone;
  for (const std::string &item : done.items.gone)
    if (std::find(names.begin(), names.end(), item) == names.end()) {
      gone += (names.empty() ? "" : ", ") + item;
      names.push_back(item);
    }
  return "shortcut " + name(file) + " cleaned: SBAchievement " +
         (done.achievement ? "removed (" + std::to_string(done.achievement) + " bytes)" : std::string("absent")) +
         ", " + std::to_string(done.items.gone.size()) + " item names removed" +
         (gone.empty() ? "" : " (" + gone + ")") + ", " + std::to_string(bytes) + " bytes";
}

} // namespace coop::shortcut
