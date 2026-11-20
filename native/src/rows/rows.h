// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// The row engine every batch shares, free of Windows: tests/native/rows/rows_test.cpp checks it on the build machine
// against fake memory. Each batch's rows sit in the header of the module that asks for them:
//   lion, gardener, tendril: fight/bosses/lion_rows.h
//   bolt: eve/bolt_rows.h
//   shop: online/modes/nightop/shop_rows.h
//   mxiii, mxspawn, mxenv, mxupper, mxmiddle, mxlower, mxlily, mxnames, mxrecords: world/maps/matrix13/mxiii_rows.h
//   signal: world/maps/matrix13/signal_rows.h
//   halls: online/lobby/halls_rows.h
//   teamshop: world/teamshop/teamshop_rows.h
// A Batch names its rows, its patches and the word its status line, log lines and request start with ("lion",
// "gardener", "tendril", "bolt", "mxiii", "shop", "signal", "halls", "teamshop": coop-status.txt's shock line is
// rows/shock.h's); every batch shares the table checks, the block and the rules below, and each keeps its own Builder.
//
// SB reads CharacterTable, SkillTable and CharacterStanceTable by ID through maps that only its own AddRow fills (the
// table's vtable slot +0x2b0), so every row goes in through that call, on the game thread with no logic task in flight
// (rows/rows_game.inc's gate: no lock guards the tables). For each row not added yet, in order: the table must be
// SB's UDataTable with its row struct of the size the SDK gives; the new name must be free in RowMap; the template is
// found by name; the new ID must be free in the table's ID map; then the row is built in a block the glue owns
// (InitializeStruct, CopyScriptStruct from the template, the ID at +0x10, the patches) and handed to AddRow, which
// removes any row of that name, copies ours into its own allocation and fills the ID and index maps. The first refusal
// stops the run before any later row of its batch, and each batch's CharacterTable rows come last, so NewActor finds
// 50020 (or 50010, 50060) only once every other row of its batch is in. A row is added once a run: a later run skips
// it, so AddRow's RemoveRow never frees a row a Lion (or a Gardener, a Tendril) still reads.
//
// A row whose template is itself (donor equal to name) is a shipped row patched in place, not added: it must be in the
// table under that name, with its ID in the ID map naming it; it is copied into the block, patched there and copied
// back over itself with CopyScriptStruct, which reassigns its strings and arrays through SB's allocator. The row keeps
// its address, ID and lazy-init state, and AddRow is not called. Only tables without Transient arrays take such rows
// (rows_test checks it), so no parsed copy of a patched field goes stale.
//
// SB parses a row's JSON strings (StartEffect, AttackCollisionGroupArray, AttackerEffectWhenDead, a hit result's
// effects...) into Transient arrays the first time it uses the row (row +8 is 0 until then; every lookup site sets it
// and calls the row's vtable +0x20). The copy carries the template's flag and parsed arrays, so the block's flag goes
// back to 0 and its Transient arrays to empty: AddRow's copy then reads as a freshly loaded row, and SB parses our
// strings on its own copy. The 4 tables the Lion's own moves, filters, results and effect need (CharacterMoveTable,
// TargetFilterTable, SkillResultTable, EffectTable) derive from the same FSBTablePropertyBase, with its flag at +8;
// that SB's lookups of their rows run the same lazy init was not traced, and resetting a flag the struct does not use
// changes nothing.
//
// The block's strings and arrays point at its pool (UTF-16 text, FName and FString arrays), which AddRow's copy
// duplicates into SB's allocations. The block is never destroyed: the next row's InitializeStruct writes over it.
// ponytail: each row's copy of the template's strings and arrays leaks inside the block's history, a few KB a game run;
// destroying the block would free our pool through SB's allocator instead.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

namespace coop::lion {

// SB's UDataTable vtable and its AddRow slot (the exe's EmptyTable, RemoveRow and AddRow at +0x2a0, +0x2a8, +0x2b0;
// UE4SS 3.0.1 computes them one slot off), the row struct (+0x28) and its PropertiesSize (UScriptStruct +0x58).
constexpr uint64_t kImageBase = 0x140000000, kTableVtable = 0x146409530, kAddRow = 0x1441815b0;
constexpr size_t kAddRowSlot = 0x2b0, kRowStruct = 0x28, kPropertiesSize = 0x58;
// A row: its vtable, SB's lazy-init flag (a byte at +8: 0 until first used) and, in tables that have one, its ID.
constexpr size_t kInitFlag = 8, kIdAt = 0x10;
// The glue's block: the row at +0, the patches' strings and lists in the pool after it.
constexpr size_t kRowBytes = 0x1000, kPoolBytes = 0x1000, kBlock = kRowBytes + kPoolBytes;

// The 39 tables, in coop::kLionTables' order (link/protocol.h): Lua's rows requests (lion, gardener, tendril, bolt,
// mxiii, shop, signal, mxspawn, mxenv, mxupper, mxmiddle, mxlower, mxnames, mxlily, mxrecords, halls, teamshop) name
// those their batch writes, each with its address. kTables describes them all: the generated part's, the two zone
// tables camp (ZoneCampTable) and env (ZoneEnvSpawnTable) and trigger (ZoneTriggerTable), which Matrix XIII's batches
// write (env also the halls batch's seats), the five only Lily's signal batch writes: quest (QuestTable), group
// (QuestTaskGroupTable), task (QuestTaskTable), target (LevelTargetFilter) and select (TheaterSelectDataTable, whose ID
// the batch neither writes nor checks: it only patches a shipped row in place), then the seven only Matrix XIII's
// batches write (world/maps/matrix13/mxiii_rows.h): spawn (EventSpawnTable), eitem (EventItemTable), zevent
// (ZoneEventTable), envc (EventEnvControlTable), transition (WorldTransitionTable), warp (EventZoneWarpTable) and
// effvol (EffectVolumeTable), then the two only the mxlily batch writes: condition (ConditionTable) and cgroup
// (ConditionGroupTable), then the three only the mxrecords batch writes: album (AlbumTable), achievement
// (AchievementTable) and puzzle (PuzzleStringArrayTable), then the two only the halls batch writes: world (WorldTable)
// and zone (ZoneTable). None of the fourteen has a Transient field (SDK stellar-sdk-647527f).
enum class Table : uint8_t {
  character,
  appearance,
  dead,
  stance,
  anim,
  command,
  skill,
  step,
  move,
  filter,
  result,
  effect,
  item,
  consumable,
  projectile,
  camp,
  env,
  shop,
  shopitem,
  trigger,
  quest,
  group,
  task,
  target,
  select,
  spawn,
  eitem,
  zevent,
  envc,
  transition,
  warp,
  effvol,
  condition,
  cgroup,
  album,
  achievement,
  puzzle,
  world,
  zone
};
constexpr size_t kTableCount = 39;
struct TableInfo {
  const char *name;       // The asset, /Game/Local/Data/<name>.<name>.
  uint32_t size;          // Its row struct's PropertiesSize.
  bool id;                // An ID at +0x10, which AddRow puts in the table's ID maps.
  uint16_t transient[25]; // The Transient TArrays SB's lazy init fills from the row's JSON strings; 0 ends the list.
};
// A patch writes one field of the copy: a float, an int32 or a byte (a bool or an enum's value), both held exactly in f
// (the generator keeps every int32 under 2^24), an FName, an FString (UTF-16 in the pool), a TArray of FNames or of
// FStrings (items joined by '|' in text; empty text: an empty array), or a TArray of structs that each hold one TArray
// of FNames at +0 (FSBQuestTaskContainer: containers joined by ';', each one's FNames by '|').
enum class Kind : uint8_t { f32, i32, u8, name, string, names, strings, containers };
struct Patch {
  uint16_t at;
  Kind kind;
  float f;
  const char *text;
};
struct Row {
  Table table;
  const char *name, *donor; // donor: the template row, the struct copied before the patches.
  uint32_t id;              // 0 in a table with no ID.
  uint16_t first, count;    // Its patches in its batch's patches.
};
// A batch: its rows, the patches their first and count index and its word, which starts its status line, its log
// lines and Lua's request for it (link/protocol.h's kRowWords).
struct Batch {
  const char *word;
  const Row *rows;
  size_t count;
  const Patch *patches;
};
// A shipped row patched in place: its template is itself (see the top of this file).
inline bool shipped_row(const Row &r) { return !std::strcmp(r.name, r.donor); }

// ---- Generated by ~/.claude/project-notes/stellar-blade-minecraft/tools/lion-rows/gen.py: do not edit by hand ----
constexpr TableInfo kTables[kTableCount] = {
    {"CharacterTable", 0x548, true, {0x538}},              // SBCharacterTableProperty
    {"CharacterAppearanceTable", 0x158, true, {}},         // SBCharacterAppearanceTableProperty
    {"CharacterDeadTable", 0x2d0, false, {}},              // SBCharacterDeadTableProperty
    {"CharacterStanceTable", 0x220, true, {0x200, 0x210}}, // SBCharacterStanceTableProperty
    {"CharacterAnimSetTable", 0xc98, true, {}},            // SBCharacterAnimSetTableProperty
    {"SkillCommandTable", 0x100, true, {}},                // SBSkillCommandTableProperty
    {"SkillTable", 0x308, true, {0x2f8}},                  // SBSkillTableProperty
    // SBSkillActiveStepTableProperty
    {"SkillActiveStepTable", 0x390, true, {0x300, 0x310, 0x320, 0x330, 0x340, 0x350, 0x360, 0x370, 0x380}},
    {"CharacterMoveTable", 0x130, true, {}}, // SBCharacterMoveTableProperty
    {"TargetFilterTable", 0xb8, true, {}},   // SBSkillTargetFilterTableProperty
    // SBSkillResultTableProperty
    {"SkillResultTable", 0x4b0, true, {0x320, 0x330, 0x340, 0x350, 0x360, 0x370, 0x380, 0x390, 0x3a0,
                                       0x3b0, 0x3c0, 0x3d0, 0x3e0, 0x3f0, 0x400, 0x410, 0x420, 0x430,
                                       0x440, 0x450, 0x460, 0x470, 0x480, 0x490, 0x4a0}},
    {"EffectTable", 0x588, true, {0x578}},   // SBEffectTableProperty
    {"ItemTable", 0x1c0, true, {}},          // SBItemTableProperty
    {"ItemConsumableTable", 0x58, true, {}}, // SBItemConsumableTableProperty
    {"ProjectileTable", 0x398, true, {0x328, 0x338, 0x348, 0x358, 0x368, 0x378, 0x388}}, // SBProjectileTableProperty
    {"ZoneCampTable", 0xa8, true, {}},                                                   // SBZoneCampTableProperty
    {"ZoneEnvSpawnTable", 0x508, true, {}},                                              // SBZoneEnvSpawnTableProperty
    {"ShopTable", 0xa8, true, {}},                                                       // SBShopTableProperty
    {"ShopItemTable", 0xa0, true, {}},                                                   // SBShopItemTableProperty
    {"ZoneTriggerTable", 0xa8, true, {}},                                                // SBZoneTriggerTableProperty
    {"QuestTable", 0x188, true, {}},                                                     // SBQuestTableProperty
    {"QuestTaskGroupTable", 0x118, true, {}},    // SBQuestTaskGroupTableProperty
    {"QuestTaskTable", 0x128, true, {}},         // SBQuestTaskTableProperty
    {"LevelTargetFilter", 0x50, true, {}},       // SBLevelTargetFilterTableProperty
    {"TheaterSelectDataTable", 0xd8, false, {}}, // SBTheaterSelectDataTableProperty
    // Matrix XIII's world tables (by hand, after the generated ones: the generator knows none of them).
    {"EventSpawnTable", 0x290, true, {}},       // SBZoneEventSpawnTableProperty
    {"EventItemTable", 0x80, true, {}},         // SBZoneEventItemTableProperty
    {"ZoneEventTable", 0x70, true, {}},         // SBZoneEventTableProperty
    {"EventEnvControlTable", 0x70, true, {}},   // SBEventEnvControlTableProperty
    {"WorldTransitionTable", 0x88, true, {}},   // SBWorldTransitionTableProperty
    {"EventZoneWarpTable", 0x70, true, {}},     // SBEventZoneWarpTableProperty
    {"EffectVolumeTable", 0xc0, true, {}},      // SBEffectVolumeTableProperty
    {"ConditionTable", 0x78, true, {}},         // SBConditionTableProperty
    {"ConditionGroupTable", 0x50, true, {}},    // SBConditionGroupTableProperty
    {"AlbumTable", 0x90, true, {}},             // SBAlbumTableProperty
    {"AchievementTable", 0xf0, true, {}},       // SBAchievementTableProperty
    {"PuzzleStringArrayTable", 0x30, true, {}}, // SBPuzzleStringArrayTableProperty
    // The hall lobbies' two (by hand too).
    {"WorldTable", 0x30, true, {}}, // SBWorldTableProperty
    {"ZoneTable", 0x150, true, {}}, // SBZoneTableProperty
};
// ---- End of the generated part ----

static_assert(kTables[kTableCount - 1].name, "the generated kTables describes every table");
constexpr const TableInfo &table_info(Table t) { return kTables[size_t(t)]; }

// FName's own split of a trailing number (UE 4.26 ParseNumber), so our FNames equal those SB makes from the same text:
// "X_1" is "X" with the internal number 2; "X_04", "X_" and "X" keep their whole text and number 0.
struct NameParts {
  size_t len;
  uint32_t number;
};
inline NameParts split_number(const char *text) {
  const size_t len = std::strlen(text);
  size_t digits = 0;
  while (digits < len && text[len - 1 - digits] >= '0' && text[len - 1 - digits] <= '9')
    ++digits;
  const char *first = text + len - digits;
  if (!digits || digits == len || first[-1] != '_' || digits > 10 || (digits > 1 && *first == '0'))
    return {len, 0};
  uint64_t n = 0;
  for (size_t i = 0; i < digits; ++i)
    n = n * 10 + uint64_t(first[i] - '0');
  return n < 0x7fffffff ? NameParts{len - 1 - digits, uint32_t(n + 1)} : NameParts{len, 0};
}

// Why a run stopped. table: not SB's UDataTable (its vtable or AddRow slot); size: its row struct's size is not the
// SDK's; fname: no FName for a name; name: a row of the new name is already in the table; id: the new ID is taken;
// donor: the template row is missing; pool: the block's pool is full; busy, net, unread: the gate stayed shut for
// kGateTicks (a logic task in flight, the net mode not 0, no logic or net-mode global yet); off: coop off.
enum class Why : uint8_t { none, table, size, fname, name, id, donor, pool, busy, net, unread, off };
inline const char *why_word(Why w) {
  static const char *const kWords[] = {"none",  "table", "size", "fname", "name",   "id",
                                       "donor", "pool",  "busy", "net",   "unread", "coop_off"};
  return kWords[size_t(w)];
}
constexpr uint32_t kGateTicks = 300; // Frames an ask waits for the gate before it is refused.

// What the game thread did: nothing asked, an ask waiting for the gate, every row in, a refusal or the latch's fault.
enum class State : uint8_t { off, waiting, rows, refused, fault };
struct Answer {
  State state = State::off;
  Why why = Why::none;
  uint8_t added = 0;   // Rows in so far.
  uint8_t row = 0;     // refused: the row it stopped at, the batch's count for the gate or coop off.
  uint32_t detail = 0; // size: the size read (24 bits); net: the net mode read.
};
// One word for the worker, so it never reads half an answer: detail 0-23, row 24-31, added 32-39, why 40-43, state
// 44-47, and the asks the game thread finished in 48-63.
inline uint64_t pack(const Answer &a, uint32_t asks) {
  return uint64_t(asks & 0xffff) << 48 | uint64_t(a.state) << 44 | uint64_t(a.why) << 40 | uint64_t(a.added) << 32 |
         uint64_t(a.row) << 24 | (a.detail & 0xffffff);
}
inline Answer unpack(uint64_t w, uint32_t &asks) {
  Answer a;
  asks = uint32_t(w >> 48);
  a.state = State((w >> 44) & 15), a.why = Why((w >> 40) & 15);
  a.added = uint8_t(w >> 32), a.row = uint8_t(w >> 24), a.detail = uint32_t(w & 0xffffff);
  return a;
}

// The rows of one table kind in a batch.
inline uint32_t rows_of(const Batch &b, Table t) {
  uint32_t n = 0;
  for (size_t i = 0; i < b.count; ++i)
    n += b.rows[i].table == t;
  return n;
}

// rows.h's Game: the glue's (rows/rows_game.inc) or a test's. read (the tables' headers only, false when
// unmapped) and write (the block only); name(text, len, number): FName's MakeWithNumber with FNAME_Add, as a word
// (ComparisonIndex, then Number in the high half; 0 is None); find(table, name): the row by name in the table's
// RowMap, whatever its row struct (not SB's FindRow FUN_141aa99a0, which knows CharacterTable's only), or 0;
// id_name(table, id): the row name the table's ID map holds for id (FUN_141a2cf40), or 0; construct(struct, row):
// InitializeStruct (the struct's vtable +0x2a8); copy(struct, dest, src): CopyScriptStruct; add(add_row, table, name,
// row): the AddRow the table's slot holds. For the read-back: character(id) and skill(id), SB's own row lookups by ID
// through its table registry (FUN_141a9ee40, FUN_141a9e920), and stance(id), the stance's row name by ID
// (FUN_141a2cfe0).
class Builder {
public:
  explicit Builder(const Batch &batch) : batch_(batch) {}
  // One run over the batch (see the top of this file). tables: the 39 tables' addresses as Lua found them, in Table's
  // order (0 for a table the batch never writes, which is never read); block: kBlock bytes of the glue's, 16-aligned;
  // base: SB's image base. Runs every row not added yet and stops at the first refusal.
  template <class Game> Answer run(Game &g, uint64_t base, const uint64_t (&tables)[kTableCount], uint64_t block) {
    Answer a;
    a.state = State::refused;
    uint64_t structs[kTableCount] = {}, add_row = base + (kAddRow - kImageBase);
    // Every table the batch's rows go into before any row (a wrong address adds nothing); the others are never read.
    for (size_t t = 0; t < kTableCount; ++t) {
      uint64_t vtable = 0, slot = 0;
      int32_t size = 0;
      a.row = first_row(Table(t));
      if (a.row == batch_.count)
        continue;
      if (!g.read(tables[t], &vtable, 8) || vtable != base + (kTableVtable - kImageBase) ||
          !g.read(vtable + kAddRowSlot, &slot, 8) || slot != add_row ||
          !g.read(tables[t] + kRowStruct, &structs[t], 8) || !structs[t])
        return a.why = Why::table, a.added = uint8_t(count_), a;
      if (!g.read(structs[t] + kPropertiesSize, &size, 4) || uint32_t(size) != table_info(Table(t)).size)
        return a.why = Why::size, a.detail = uint32_t(size) & 0xffffff, a.added = uint8_t(count_), a;
    }
    for (size_t i = 0; i < batch_.count; ++i) {
      if (added_[i])
        continue;
      a.row = uint8_t(i);
      const Row &r = batch_.rows[i];
      const TableInfo &info = table_info(r.table);
      const uint64_t table = tables[size_t(r.table)], rs = structs[size_t(r.table)];
      const uint64_t name = make(g, r.name), donor_name = make(g, r.donor);
      if (!name || !donor_name)
        return a.why = Why::fname, a.added = uint8_t(count_), a;
      const bool shipped = shipped_row(r); // Patched in place: the row must be there, its ID naming it.
      if (!shipped && g.find(table, name))
        return a.why = Why::name, a.added = uint8_t(count_), a;
      const uint64_t donor = g.find(table, donor_name); // First: a shipped row missing from RowMap has no ID either.
      if (!donor)
        return a.why = Why::donor, a.added = uint8_t(count_), a;
      if (info.id && g.id_name(table, r.id) != (shipped ? name : 0))
        return a.why = Why::id, a.added = uint8_t(count_), a;
      g.construct(rs, block);
      g.copy(rs, block, donor);
      if (!shipped) {
        const uint8_t fresh = 0;
        g.write(block + kInitFlag, &fresh, 1);
        if (info.id)
          g.write(block + kIdAt, &r.id, 4);
        static const uint8_t kEmpty[16] = {};
        for (uint16_t at : info.transient)
          if (at)
            g.write(block + at, kEmpty, sizeof kEmpty);
      }
      uint64_t pool = block + kRowBytes;
      for (size_t p = r.first; p < size_t(r.first) + r.count; ++p)
        if (const Why why = patch(g, block, batch_.patches[p], pool, block + kBlock); why != Why::none)
          return a.why = why, a.added = uint8_t(count_), a;
      if (shipped)
        g.copy(rs, donor, block);
      else
        g.add(add_row, table, name, block);
      added_[i] = true;
      ++count_;
    }
    a.state = State::rows, a.why = Why::none, a.row = 0, a.added = uint8_t(count_);
    return a;
  }

  // What SB's own lookups by ID give back for the batch's rows (glue's R3 log line, the status's char=, skills= and
  // stance=): how many of the CharacterTable and SkillTable rows its registry lookups find as the row of our name, and
  // how many stance IDs give our row name.
  struct ReadBack {
    uint8_t character = 0, skills = 0, stance = 0;
  };
  template <class Game> ReadBack read_back(Game &g, const uint64_t (&tables)[kTableCount]) const {
    ReadBack b;
    for (size_t i = 0; i < batch_.count; ++i) {
      const Row &r = batch_.rows[i];
      const uint64_t name = make(g, r.name), table = tables[size_t(r.table)];
      if (r.table == Table::character)
        b.character += name && g.character(r.id) == g.find(table, name) && g.character(r.id);
      else if (r.table == Table::skill)
        b.skills += name && g.skill(r.id) == g.find(table, name) && g.skill(r.id);
      else if (r.table == Table::stance)
        b.stance += name && g.stance(r.id) == name;
    }
    return b;
  }

  bool added(size_t i) const { return added_[i]; }
  uint32_t count() const { return count_; }

private:
  uint8_t first_row(Table t) const {
    for (size_t i = 0; i < batch_.count; ++i)
      if (batch_.rows[i].table == t)
        return uint8_t(i);
    return uint8_t(batch_.count);
  }
  template <class Game> static uint64_t make(Game &g, const char *text) {
    const NameParts p = split_number(text);
    return g.name(text, p.len, p.number);
  }

public: // For the test's pool and FName cases, which the recipe's own data never reaches.
  // The pool's next 8-aligned n bytes, or 0 when they do not fit.
  static uint64_t take(uint64_t &pool, uint64_t end, size_t n) {
    const uint64_t at = (pool + 7) & ~uint64_t(7);
    if (at + n > end)
      return 0;
    pool = at + n;
    return at;
  }
  // An FString header {data, num, max} for text (its first len characters), its UTF-16 characters and NUL in the
  // pool; {0, 0, 0} when empty, as UE keeps an empty FString.
  template <class Game>
  static bool string(Game &g, const char *text, size_t len, uint64_t &pool, uint64_t end, uint8_t (&header)[16]) {
    std::memset(header, 0, sizeof header);
    if (!len)
      return true;
    const uint64_t at = take(pool, end, 2 * (len + 1));
    if (!at)
      return false;
    for (size_t k = 0; k <= len; ++k) {
      const uint16_t c = k < len ? uint8_t(text[k]) : 0;
      g.write(at + 2 * k, &c, 2);
    }
    const int32_t n = int32_t(len + 1);
    std::memcpy(header, &at, 8);
    std::memcpy(header + 8, &n, 4);
    std::memcpy(header + 12, &n, 4);
    return true;
  }
  template <class Game> static Why patch(Game &g, uint64_t row, const Patch &p, uint64_t &pool, uint64_t end) {
    if (p.kind == Kind::f32) {
      g.write(row + p.at, &p.f, 4);
      return Why::none;
    }
    if (p.kind == Kind::i32) {
      const int32_t v = int32_t(p.f);
      g.write(row + p.at, &v, 4);
      return Why::none;
    }
    if (p.kind == Kind::u8) {
      const uint8_t v = uint8_t(p.f);
      g.write(row + p.at, &v, 1);
      return Why::none;
    }
    if (p.kind == Kind::name) {
      const uint64_t name = make(g, p.text);
      if (!name && std::strcmp(p.text, "None") != 0)
        return Why::fname;
      g.write(row + p.at, &name, 8);
      return Why::none;
    }
    uint8_t header[16];
    if (p.kind == Kind::containers) {
      // Each container a TArray of FNames, its header in the pool, written there as a names patch of its own.
      int32_t n = *p.text != 0;
      for (const char *c = p.text; *c; ++c)
        n += *c == ';';
      const uint64_t items = n ? take(pool, end, 16 * size_t(n)) : 0;
      if (n && !items)
        return Why::pool;
      const char *at = p.text;
      for (int32_t k = 0; k < n; ++k) {
        const char *semi = std::strchr(at, ';');
        const size_t len = semi ? size_t(semi - at) : std::strlen(at);
        char names[512];
        if (len >= sizeof names)
          return Why::pool;
        std::memcpy(names, at, len);
        names[len] = 0;
        if (const Why why = patch(g, items + 16 * uint64_t(k), Patch{0, Kind::names, 0, names}, pool, end);
            why != Why::none)
          return why;
        at = semi ? semi + 1 : at + len;
      }
      std::memset(header, 0, sizeof header);
      if (n) {
        std::memcpy(header, &items, 8);
        std::memcpy(header + 8, &n, 4);
        std::memcpy(header + 12, &n, 4);
      }
      g.write(row + p.at, header, 16);
      return Why::none;
    }
    if (p.kind == Kind::string) {
      if (!string(g, p.text, std::strlen(p.text), pool, end, header))
        return Why::pool;
      g.write(row + p.at, header, 16);
      return Why::none;
    }
    // A list: its items in the pool (8 bytes an FName, 16 an FString header), then the header over the field.
    int32_t n = *p.text != 0;
    for (const char *c = p.text; *c; ++c)
      n += *c == '|';
    const size_t item = p.kind == Kind::names ? 8 : 16;
    const uint64_t items = n ? take(pool, end, item * size_t(n)) : 0;
    if (n && !items)
      return Why::pool;
    const char *at = p.text;
    for (int32_t k = 0; k < n; ++k) {
      const char *bar = std::strchr(at, '|');
      const size_t len = bar ? size_t(bar - at) : std::strlen(at);
      if (p.kind == Kind::names) {
        char text[128];
        if (len >= sizeof text)
          return Why::fname;
        std::memcpy(text, at, len);
        text[len] = 0;
        const uint64_t name = make(g, text);
        if (!name)
          return Why::fname;
        g.write(items + 8 * uint64_t(k), &name, 8);
      } else {
        uint8_t s[16];
        if (!string(g, at, len, pool, end, s))
          return Why::pool;
        g.write(items + 16 * uint64_t(k), s, 16);
      }
      at = bar ? bar + 1 : at + len;
    }
    std::memset(header, 0, sizeof header);
    if (n) {
      std::memcpy(header, &items, 8);
      std::memcpy(header + 8, &n, 4);
      std::memcpy(header + 12, &n, 4);
    }
    g.write(row + p.at, header, 16);
    return Why::none;
  }

private:
  const Batch &batch_;
  bool added_[256] = {};
  uint32_t count_ = 0;
};

// coop-status.txt's line for a batch (fight/bosses/lion.lua reads lion=, bolt= and shop=, fight/bosses/gardener.lua
// gardener=, fight/bosses/tendril.lua tendril=, world/maps/matrix13/level/travel.lua mxiii=, mxspawn=, mxenv=,
// mxupper=, mxmiddle= and mxlower=, world/maps/matrix13/quest/on_time.lua signal=), from its answer word, its
// read-back, the frames its ask waited, the spawn manager's counter and, after the latch, where the fault was:
//   <word>=off
//   <word>=waiting added=<n>/<N> asks=<a> spawns=<s> why=<busy|net|unread> ticks=<t>
//   <word>=rows added=<N>/<N> asks=<a> spawns=<s> char=<k>/<n> skills=<k>/<n> stance=<k>/<n>
//   <word>=refused added=<n>/<N> asks=<a> spawns=<s> why=<word> table=<Table|-> row=<Row|->[ detail=<value>]
//   <word>=fault added=<n>/<N> asks=<a> spawns=<s> where=<text, maybe with spaces>
// asks: the asks the game thread finished (a new answer when it grows); spawns: the int32 at the spawn manager's
// +0x198, "?" until read. detail: the size read as 0x<hex> (why=size) or the net mode read (why=net).
struct Status {
  uint64_t word = 0;
  Builder::ReadBack read;
  uint32_t ticks = 0;
  bool spawns_read = false;
  int32_t spawns = 0;
  std::string fault; // Where, once the latch closed.
};
inline std::string status_line(const Batch &b, const Status &s) {
  uint32_t asks = 0;
  const Answer a = unpack(s.word, asks);
  if (a.state == State::off)
    return std::string(b.word) + "=off";
  static const char *const kStates[] = {"off", "waiting", "rows", "refused", "fault"};
  std::string line = std::string(b.word) + "=" + kStates[size_t(a.state)] + " added=" + std::to_string(a.added) + "/" +
                     std::to_string(b.count) + " asks=" + std::to_string(asks) +
                     " spawns=" + (s.spawns_read ? std::to_string(s.spawns) : std::string("?"));
  const auto count = [&b](uint32_t k, Table t) { return std::to_string(k) + "/" + std::to_string(rows_of(b, t)); };
  if (a.state == State::waiting)
    line += std::string(" why=") + why_word(a.why) + " ticks=" + std::to_string(s.ticks);
  else if (a.state == State::rows)
    line += " char=" + count(s.read.character, Table::character) + " skills=" + count(s.read.skills, Table::skill) +
            " stance=" + count(s.read.stance, Table::stance);
  else if (a.state == State::refused) {
    const bool row = a.row < b.count;
    line += std::string(" why=") + why_word(a.why) + " table=" + (row ? table_info(b.rows[a.row].table).name : "-") +
            " row=" + (row ? b.rows[a.row].name : "-");
    char detail[24] = "";
    if (a.why == Why::size)
      std::snprintf(detail, sizeof detail, " detail=0x%x", unsigned(a.detail));
    else if (a.why == Why::net)
      std::snprintf(detail, sizeof detail, " detail=%u", unsigned(a.detail));
    line += detail;
  } else if (a.state == State::fault)
    line += " where=" + s.fault;
  return line;
}
// The log line for a batch's answer (coop-link.log), as the test campaign's R2 reads it.
inline std::string describe(const Batch &b, const Answer &a) {
  const std::string added = std::to_string(a.added) + "/" + std::to_string(b.count);
  size_t shipped = 0;
  for (size_t i = 0; i < b.count; ++i)
    shipped += shipped_row(b.rows[i]);
  if (a.state == State::rows && shipped)
    return std::string(b.word) + " rows: " + added + " in, " + std::to_string(b.count - shipped) +
           " added through SB's AddRow 0x1441815b0 and " + std::to_string(shipped) +
           " shipped rows patched in place, 0 refused";
  if (a.state == State::rows)
    return std::string(b.word) + " rows: " + added + " added through SB's AddRow 0x1441815b0, 0 refused";
  if (a.state != State::refused)
    return std::string(b.word) + " rows: " + added + " added";
  const bool row = a.row < b.count;
  const Row &r = b.rows[row ? a.row : 0];
  const TableInfo &info = table_info(r.table);
  char why[160];
  switch (a.why) {
  case Why::table: std::snprintf(why, sizeof why, "%s is not SB's UDataTable", info.name); break;
  case Why::size:
    std::snprintf(why, sizeof why, "%s's row size 0x%x not 0x%x", info.name, unsigned(a.detail), unsigned(info.size));
    break;
  case Why::fname: std::snprintf(why, sizeof why, "the game made no FName"); break;
  case Why::name: std::snprintf(why, sizeof why, "a row of that name is already in %s", info.name); break;
  case Why::id:
    std::snprintf(why, sizeof why, shipped_row(r) ? "ID %u does not name it" : "ID %u taken", unsigned(r.id));
    break;
  case Why::donor:
    if (shipped_row(r))
      std::snprintf(why, sizeof why, "no shipped row of that name in %s", info.name);
    else
      std::snprintf(why, sizeof why, "template %s missing", r.donor);
    break;
  case Why::pool: std::snprintf(why, sizeof why, "its strings overflow the pool"); break;
  case Why::busy: std::snprintf(why, sizeof why, "logic busy %u frames", unsigned(kGateTicks)); break;
  case Why::net:
    std::snprintf(why, sizeof why, "net mode %u for %u frames", unsigned(a.detail), unsigned(kGateTicks));
    break;
  case Why::unread:
    std::snprintf(why, sizeof why, "no logic or net-mode global for %u frames", unsigned(kGateTicks));
    break;
  case Why::off: std::snprintf(why, sizeof why, "coop off"); break;
  default: std::snprintf(why, sizeof why, "?"); break;
  }
  return std::string(b.word) + " rows refused " + (row ? r.name : "-") + ": " + why + "; " + added + " added";
}
// The log line for a batch's read-back (the campaign's R3): the IDs asked of each lookup and how many gave our row ("-"
// for a table the batch has no row in, as the bolt batch's CharacterTable and stance).
inline std::string describe_read(const Batch &batch, const Builder::ReadBack &b) {
  const auto ids = [&batch](Table t) {
    uint32_t low = UINT32_MAX, high = 0;
    for (size_t i = 0; i < batch.count; ++i)
      if (const Row &r = batch.rows[i]; r.table == t)
        low = r.id < low ? r.id : low, high = r.id > high ? r.id : high;
    if (low > high)
      return std::string("-");
    return low == high ? std::to_string(low) : std::to_string(low) + "-" + std::to_string(high);
  };
  const auto count = [&batch](uint32_t k, Table t) {
    return std::to_string(k) + "/" + std::to_string(rows_of(batch, t));
  };
  return std::string(batch.word) + " rows by SB's lookups: CharacterTable " + ids(Table::character) + " " +
         count(b.character, Table::character) + ", SkillTable " + ids(Table::skill) + " " +
         count(b.skills, Table::skill) + ", stance " + ids(Table::stance) + " " + count(b.stance, Table::stance);
}

} // namespace coop::lion
