// The Lion's rows on the build machine against fake memory laid out like the pinned build: the recipe itself (names
// and IDs unique, every patch inside its struct and past its header, the step chains, skills, commands and stance
// pointing at the new rows, the CharacterTable rows last); a whole run (the table checks, each row built from its
// donor with SB's lazy-init flag and Transient arrays reset, its ID, its patches read back from the pool, AddRow given
// the new name); a missing donor, a taken ID, a taken name, a wrong vtable (even with SB's AddRow in its slot), AddRow
// slot or row size, and no FName for a row's, a donor's, a patch's or a list item's text, refusing without calling
// AddRow, and a later run skipping the rows already in; the pool's bound and a list item's FName length; FName's number
// split; the read-back through SB's lookups by ID (nothing found is no match); the answer word, the status line and the
// log lines.
#include "lion/rows.h"

#include <cassert>
#include <cstdio>
#include <cstring>
#include <map>
#include <set>
#include <string>
#include <utility>
#include <vector>

using namespace coop::lion;

namespace {
constexpr uint64_t kBase = 0x7ff600000000;
uint64_t rebased(uint64_t address) { return kBase + (address - kImageBase); }
size_t kind_size(Kind k) { return k == Kind::f32 ? 4 : k == Kind::name ? 8 : 16; }

// Regions by start address, with gaps between them: an access outside them fails, as the game's would fault.
struct Memory {
  std::map<uint64_t, std::vector<uint8_t>> regions;
  uint64_t next = 0x10000000;
  uint64_t alloc(size_t n) {
    const uint64_t at = next;
    regions[at].assign(n, 0);
    next += (n + 0x1fff) & ~uint64_t(0xfff);
    return at;
  }
  uint8_t *at(uint64_t address, size_t n) {
    auto r = regions.upper_bound(address);
    if (r == regions.begin())
      return nullptr;
    --r;
    return address + n <= r->first + r->second.size() ? r->second.data() + (address - r->first) : nullptr;
  }
  template <class T> T get(uint64_t address) {
    T v;
    const uint8_t *p = at(address, sizeof v);
    assert(p);
    std::memcpy(&v, p, sizeof v);
    return v;
  }
  template <class T> void put(uint64_t address, T v) {
    uint8_t *p = at(address, sizeof v);
    assert(p);
    std::memcpy(p, &v, sizeof v);
  }
};

// One game: SB's 8 tables (its UDataTable vtable with AddRow in slot +0x2b0, each row struct with its size), the
// Behemoth donors every recipe row names (filled with a pattern, their lazy-init flag set, their Transient arrays
// holding junk as after SB parsed them), FNames interned by text and number, the RowMap and ID maps as AddRow fills
// them, and the registry's lookups by ID over them.
struct Game {
  Memory mem;
  uint64_t tables[kTableCount] = {}, block = 0;
  std::map<std::pair<std::string, uint32_t>, uint32_t> interned;
  std::vector<std::string> texts{"None"};
  std::map<std::pair<uint64_t, uint64_t>, uint64_t> rows; // (table, FName) -> row
  std::map<std::pair<uint64_t, uint32_t>, uint64_t> ids;  // (table, ID) -> FName
  struct Add {
    size_t table;
    uint64_t name;
    std::vector<uint8_t> block; // The row and the pool, as AddRow saw them.
  };
  std::vector<Add> adds;
  std::map<uint64_t, uint64_t> donors; // Donor row -> table index, for the copy's size.
  int constructs = 0, copies = 0;
  uint64_t skill_override = 0; // A registry that gives another row for one skill ID.
  uint32_t skill_override_id = 0;
  std::set<std::string> no_name; // Texts the game makes no FName for.

  Game() {
    const uint64_t vtable = rebased(kTableVtable); // SB's UDataTable vtable, in the image.
    mem.regions[vtable].assign(0x400, 0);
    mem.put<uint64_t>(vtable + kAddRowSlot, rebased(kAddRow));
    for (size_t t = 0; t < kTableCount; ++t) {
      tables[t] = mem.alloc(0x100);
      const uint64_t rs = mem.alloc(0x100);
      mem.put<uint64_t>(tables[t], rebased(kTableVtable));
      mem.put<uint64_t>(tables[t] + kRowStruct, rs);
      mem.put<int32_t>(rs + kPropertiesSize, int32_t(kTables[t].size));
    }
    vtable_at = vtable;
    block = mem.alloc(kBlock);
    for (const Row &r : kRecipe) {
      const size_t t = size_t(r.table);
      const uint64_t key = name(r.donor);
      if (rows.count({tables[t], key}))
        continue;
      const uint64_t row = mem.alloc(kTables[t].size);
      for (size_t k = 0; k < kTables[t].size; ++k)
        mem.at(row + k, 1)[0] = uint8_t(0x40 + (k * 7 + t) % 0x3f);
      mem.put<uint8_t>(row + kInitFlag, 1);
      for (uint16_t at : kTables[t].transient)
        if (at)
          mem.put<uint64_t>(at + row, 0x1234567812345678), mem.put<uint64_t>(at + row + 8, 0x0000000500000005);
      rows[{tables[t], key}] = row;
      donors[row] = t;
    }
  }
  uint64_t vtable_at = 0;

  bool read(uint64_t address, void *out, size_t n) {
    const uint8_t *p = mem.at(address, n);
    if (p)
      std::memcpy(out, p, n);
    return p;
  }
  void write(uint64_t address, const void *in, size_t n) {
    uint8_t *p = mem.at(address, n);
    assert(p && address >= block && address + n <= block + kBlock); // Only the glue's block is ever written.
    std::memcpy(p, in, n);
  }
  uint64_t name(const char *text, size_t len, uint32_t number) {
    const std::string s(text, len);
    if ((s == "None" && !number) || no_name.count(s))
      return 0;
    auto it = interned.find({s, number});
    if (it == interned.end()) {
      texts.push_back(s);
      it = interned.emplace(std::make_pair(s, number), uint32_t(texts.size() - 1)).first;
    }
    return uint64_t(number) << 32 | it->second;
  }
  uint64_t name(const char *text) {
    const NameParts p = split_number(text);
    return name(text, p.len, p.number);
  }
  uint64_t find(uint64_t table, uint64_t n) {
    const auto it = rows.find({table, n});
    return it == rows.end() ? 0 : it->second;
  }
  uint64_t id_name(uint64_t table, uint32_t id) {
    const auto it = ids.find({table, id});
    return it == ids.end() ? 0 : it->second;
  }
  size_t table_of_struct(uint64_t rs) {
    for (size_t t = 0; t < kTableCount; ++t)
      if (mem.get<uint64_t>(tables[t] + kRowStruct) == rs)
        return t;
    assert(false);
    return 0;
  }
  void construct(uint64_t rs, uint64_t row) {
    assert(row == block);
    std::memset(mem.at(row, kTables[table_of_struct(rs)].size), 0, kTables[table_of_struct(rs)].size);
    ++constructs;
  }
  void copy(uint64_t rs, uint64_t dest, uint64_t src) {
    const size_t t = table_of_struct(rs);
    assert(dest == block && donors.count(src) && donors[src] == t && constructs == copies + 1);
    std::memcpy(mem.at(dest, kTables[t].size), mem.at(src, kTables[t].size), kTables[t].size);
    ++copies;
  }
  // SB's AddRow: our block copied into a row of its own, RowMap and (with an ID) the ID map filled.
  void add(uint64_t add_row, uint64_t table, uint64_t n, uint64_t row) {
    assert(add_row == rebased(kAddRow) && row == block);
    size_t t = 0;
    while (tables[t] != table)
      ++t;
    adds.push_back({t, n, std::vector<uint8_t>(mem.at(block, kBlock), mem.at(block, kBlock) + kBlock)});
    const uint64_t copy = mem.alloc(kTables[t].size);
    std::memcpy(mem.at(copy, kTables[t].size), mem.at(block, kTables[t].size), kTables[t].size);
    rows[{table, n}] = copy;
    if (kTables[t].id)
      ids[{table, mem.get<uint32_t>(block + kIdAt)}] = n;
  }
  uint64_t character(uint32_t id) { return by_id(Table::character, id); }
  uint64_t skill(uint32_t id) {
    return skill_override && id == skill_override_id ? skill_override : by_id(Table::skill, id);
  }
  uint64_t stance(uint32_t id) { return id_name(tables[size_t(Table::stance)], id); }
  uint64_t by_id(Table t, uint32_t id) { return find(tables[size_t(t)], id_name(tables[size_t(t)], id)); }

  // A field of the added row's block: its FString text, its FName list's texts, its FString list's texts.
  template <class T> static T field(const Add &a, size_t at) {
    T v;
    std::memcpy(&v, a.block.data() + at, sizeof v);
    return v;
  }
  std::string text_at(const Add &a, uint64_t data, int32_t num) {
    if (!num)
      return "";
    assert(data >= block && data + 2 * uint64_t(num) <= block + kBlock);
    std::string s;
    for (int32_t k = 0; k < num; ++k) {
      uint16_t c;
      std::memcpy(&c, a.block.data() + (data - block) + 2 * size_t(k), 2);
      if (k + 1 == num)
        assert(c == 0);
      else
        s += char(c);
    }
    return s;
  }
  std::string string_field(const Add &a, size_t at) {
    const int32_t num = field<int32_t>(a, at + 8), max = field<int32_t>(a, at + 12);
    assert(num == max);
    return text_at(a, field<uint64_t>(a, at), num);
  }
  std::string list_field(const Add &a, size_t at, Kind kind) {
    const uint64_t data = field<uint64_t>(a, at);
    const int32_t num = field<int32_t>(a, at + 8);
    assert(num == field<int32_t>(a, at + 12) && (num || !data));
    std::string out;
    for (int32_t k = 0; k < num; ++k) {
      const size_t item = (data - block) + (kind == Kind::names ? 8 : 16) * size_t(k);
      if (k)
        out += "|";
      if (kind == Kind::names) {
        uint64_t n;
        std::memcpy(&n, a.block.data() + item, 8);
        const uint32_t number = uint32_t(n >> 32);
        out += texts[uint32_t(n)] + (number ? "_" + std::to_string(number - 1) : std::string());
      } else {
        uint64_t d;
        int32_t sn;
        std::memcpy(&d, a.block.data() + item, 8);
        std::memcpy(&sn, a.block.data() + item + 8, 4);
        out += text_at(a, d, sn);
      }
    }
    return out;
  }
  std::string name_text(uint64_t n) {
    const uint32_t number = uint32_t(n >> 32);
    return texts[uint32_t(n)] + (number ? "_" + std::to_string(number - 1) : std::string());
  }
};

size_t row_index(const char *name, Table t) {
  for (size_t i = 0; i < kRows; ++i)
    if (kRecipe[i].table == t && !std::strcmp(kRecipe[i].name, name))
      return i;
  assert(false);
  return kRows;
}
} // namespace

int main() {
  // ---- The recipe ----
  static_assert(kRows == 78, "15 commands, 15 skills, 41 steps, 2 anim sets, the stance, dead and appearance rows and "
                             "the two CharacterTable rows");
  assert(rows_of(Table::step) == 41 && rows_of(Table::skill) == 15 && rows_of(Table::command) == 15 &&
         rows_of(Table::anim) == 2 && rows_of(Table::stance) == 1 && rows_of(Table::dead) == 1 &&
         rows_of(Table::appearance) == 1 && rows_of(Table::character) == 2);
  // The two CharacterTable rows last, M_LionC the very last: NewActor finds 50020 only once every other row is in.
  assert(kRecipe[kRows - 1].table == Table::character && !std::strcmp(kRecipe[kRows - 1].name, "M_LionC") &&
         kRecipe[kRows - 1].id == 50020 && kRecipe[kRows - 2].table == Table::character &&
         kRecipe[kRows - 2].id == 50021);
  for (size_t t = 0; t < kTableCount; ++t) {
    std::set<std::string> names;
    std::set<uint32_t> ids;
    for (const Row &r : kRecipe)
      if (size_t(r.table) == t) {
        assert(names.insert(r.name).second);
        assert(kTables[t].id ? r.id && ids.insert(r.id).second : r.id == 0);
        assert(std::strcmp(r.name, r.donor) != 0);
      }
  }
  size_t patches = 0;
  for (const Row &r : kRecipe) {
    const TableInfo &info = kTables[size_t(r.table)];
    assert(r.first == patches && r.count > 0);
    patches += r.count;
    for (size_t p = r.first; p < size_t(r.first) + r.count; ++p) {
      const Patch &x = kPatches[p];
      // Inside the struct, past the vtable, the lazy-init flag and the ID, clear of every Transient array.
      assert(x.at >= kIdAt + (info.id ? 4 : 0) && x.at + kind_size(x.kind) <= info.size);
      for (uint16_t at : info.transient)
        assert(!at || x.at + kind_size(x.kind) <= at || x.at >= at + 16u);
      assert(x.kind == Kind::f32 ? x.text == nullptr : x.text != nullptr);
      for (size_t q = r.first; q < p; ++q) // No two patches of a row on the same bytes.
        assert(kPatches[q].at + kind_size(kPatches[q].kind) <= x.at || x.at + kind_size(x.kind) <= kPatches[q].at);
    }
  }
  assert(patches == sizeof kPatches / sizeof kPatches[0]);
  for (size_t t = 0; t < kTableCount; ++t) {
    assert(kTables[t].size <= kRowBytes);
    for (uint16_t at : kTables[t].transient)
      assert(!at || (at >= kIdAt + 4 && at + 16u <= kTables[t].size));
  }
  // Every reference among the new rows lands on a new row: the steps' chains, the skills' first steps, the commands'
  // skills, the stance's commands and anim sets, the CharacterTable rows' stance, dead row and appearance.
  const auto patched = [](const Row &r, uint16_t at) -> const char * {
    for (size_t p = r.first; p < size_t(r.first) + r.count; ++p)
      if (kPatches[p].at == at)
        return kPatches[p].text;
    return nullptr;
  };
  const auto has = [](Table t, const char *name) {
    for (const Row &r : kRecipe)
      if (r.table == t && !std::strcmp(r.name, name))
        return true;
    return false;
  };
  for (const Row &r : kRecipe) {
    if (r.table == Table::step)
      if (const char *next = patched(r, 0x34))
        assert(has(Table::step, next));
    if (r.table == Table::skill)
      assert(has(Table::step, patched(r, 0x100)) && std::strstr(patched(r, 0x100), r.name) == patched(r, 0x100));
    if (r.table == Table::command)
      assert(has(Table::skill, patched(r, 0x18)) && !std::strcmp(patched(r, 0x18), r.name));
    if (r.table == Table::character)
      assert(!std::strcmp(patched(r, 0x3a8), "M_LionC_Default") && !std::strcmp(patched(r, 0x298), "M_LionC") &&
             !std::strcmp(patched(r, 0x420), "M_LionC") && has(Table::dead, "M_LionC") &&
             has(Table::appearance, "M_LionC") && has(Table::stance, "M_LionC_Default"));
  }
  {
    const Row &stance = kRecipe[row_index("M_LionC_Default", Table::stance)];
    std::string commands = patched(stance, 0x90);
    size_t n = 0;
    for (const Row &r : kRecipe)
      if (r.table == Table::command)
        assert(commands.find(r.name) != std::string::npos), ++n;
    assert(n == 15 && std::strstr(patched(stance, 0x110), "MinimumHP") == nullptr);
    assert(has(Table::anim, patched(stance, 0x150)) && has(Table::anim, patched(stance, 0x160)));
  }

  // ---- FName's number split, as UE 4.26's ParseNumber ----
  const auto split = [](const char *text, size_t len, uint32_t number) {
    const NameParts p = split_number(text);
    return p.len == len && p.number == number;
  };
  assert(split("CH_M_NA_02_Lion/Skill/M_LionC_Roar_1", 34, 2) && split("X_0", 1, 1) && split("X_04", 4, 0));
  assert(split("X_", 2, 0) && split("X", 1, 0) && split("M_LionC_Roar_Cast1", 18, 0) && split("Rank_Elite", 10, 0));
  assert(split("X_12345678901", 13, 0) && split("X_2147483646", 1, 2147483647u) && split("X_2147483647", 12, 0));
  assert(split("_5", 0, 6) && split("15", 2, 0) && split("", 0, 0));

  // ---- A whole run ----
  {
    Game g;
    Builder b;
    const Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::rows && a.why == Why::none && a.added == kRows && b.count() == kRows);
    assert(g.adds.size() == kRows && g.constructs == int(kRows) && g.copies == int(kRows));
    for (size_t i = 0; i < kRows; ++i) {
      const Row &r = kRecipe[i];
      const TableInfo &info = kTables[size_t(r.table)];
      const Game::Add &add = g.adds[i];
      // In order, to its table, under its new name; SB's flag back to 0, its ID, the Transient arrays empty.
      assert(add.table == size_t(r.table) && g.name_text(add.name) == r.name && b.added(i));
      assert(add.block[kInitFlag] == 0);
      if (info.id)
        assert(Game::field<uint32_t>(add, kIdAt) == r.id);
      for (uint16_t at : info.transient)
        if (at)
          assert(Game::field<uint64_t>(add, at) == 0 && Game::field<uint64_t>(add, at + 8) == 0);
      // Each patch as written; every other byte past the header is the donor's.
      std::vector<bool> touched(info.size, false);
      for (size_t k = 0; k < 0x14; ++k)
        touched[k] = true;
      for (uint16_t at : info.transient)
        for (size_t k = 0; at && k < 16; ++k)
          touched[at + k] = true;
      for (size_t p = r.first; p < size_t(r.first) + r.count; ++p) {
        const Patch &x = kPatches[p];
        for (size_t k = 0; k < kind_size(x.kind); ++k)
          touched[x.at + k] = true;
        if (x.kind == Kind::f32)
          assert(Game::field<float>(add, x.at) == x.f);
        else if (x.kind == Kind::name)
          assert(g.name_text(Game::field<uint64_t>(add, x.at)) == x.text);
        else if (x.kind == Kind::string)
          assert(g.string_field(add, x.at) == x.text);
        else
          assert(g.list_field(add, x.at, x.kind) == x.text);
      }
      const uint64_t donor = g.find(g.tables[size_t(r.table)], g.name(r.donor));
      for (size_t k = 0; k < info.size; ++k)
        assert(touched[k] || add.block[k] == g.mem.at(donor + k, 1)[0]);
    }
    // Spot checks against the plan's rows: a Hit step's collision group as JSON text, the first step's Show, the
    // stance's 15 commands, the dead row's Shows, the brains.
    const Game::Add &hit = g.adds[row_index("M_LionC_ClawAttackLeft_Hit1", Table::step)];
    assert(g.string_field(hit, 0x1c0) ==
           "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]");
    const Game::Add &cast = g.adds[row_index("M_LionC_ClawAttackLeft_Cast1", Table::step)];
    assert(g.name_text(Game::field<uint64_t>(cast, 0x160)) == "CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackLeft_1");
    assert(uint32_t(Game::field<uint64_t>(cast, 0x160) >> 32) == 2); // "_1" as FName's number, as SB makes it.
    const Game::Add &stance = g.adds[row_index("M_LionC_Default", Table::stance)];
    assert(Game::field<int32_t>(stance, 0x90 + 8) == 15);
    const Game::Add &dead = g.adds[row_index("M_LionC", Table::dead)];
    assert(g.list_field(dead, 0x10, Kind::strings) == "CH_M_NA_02_Lion/Basic/M_Lion_Dead");
    assert(g.string_field(g.adds[kRows - 1], 0x3e8) ==
           "/Game/GameDesign/Combat/BehaviorTree/Monster/M_Skulling_AI_Test");
    assert(g.string_field(g.adds[kRows - 2], 0x3e8) ==
           "/Game/GameDesign/Combat/BehaviorTree/Monster/M_LesserLurker_AI");
    assert(g.string_field(g.adds[kRows - 1], 0x508).empty() && Game::field<uint64_t>(g.adds[kRows - 1], 0x508) == 0);

    // SB's lookups by ID find our rows: both CharacterTable rows, the 15 skills, the stance's name.
    Builder::ReadBack rb = Builder::read_back(g, g.tables);
    assert(rb.character == 2 && rb.skills == 15 && rb.stance == 1);
    g.skill_override = 0x12345678, g.skill_override_id = 5002003;
    rb = Builder::read_back(g, g.tables);
    assert(rb.skills == 14);
    assert(describe_read(rb) == "lion rows by SB's lookups: CharacterTable 50020-50021 2/2, SkillTable "
                                "5002000-5002014 14/15, stance 500200 1/1");

    // A second run adds nothing: every row is in.
    const Answer again = b.run(g, kBase, g.tables, g.block);
    assert(again.state == State::rows && again.added == kRows && g.adds.size() == kRows);
  }
  {
    Game g; // No row added: SB's lookups find nothing, and nothing found is no match (0 == 0 counts no row).
    const Builder::ReadBack rb = Builder::read_back(g, g.tables);
    assert(rb.character == 0 && rb.skills == 0 && rb.stance == 0);
  }

  // ---- Refusals: nothing handed to AddRow for the refused row or any after it; a later run goes on ----
  {
    Game g;
    const size_t roar = row_index("M_LionC_Roar_Hit1", Table::step);
    const uint64_t key = g.name("M_Behemoth_Roar1_Hit1");
    const uint64_t row = g.rows[{g.tables[size_t(Table::step)], key}];
    g.rows.erase({g.tables[size_t(Table::step)], key});
    Builder b;
    Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::donor && a.row == roar && a.added == roar);
    assert(g.adds.size() == roar && !b.added(roar));
    assert(describe(a) == "lion rows refused M_LionC_Roar_Hit1: donor M_Behemoth_Roar1_Hit1 missing; " +
                              std::to_string(roar) + "/78 added");
    g.rows[{g.tables[size_t(Table::step)], key}] = row;
    a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::rows && a.added == kRows && g.adds.size() == kRows); // Each row added once.
    std::set<std::pair<size_t, uint64_t>> once;
    for (const Game::Add &x : g.adds)
      assert(once.insert({x.table, x.name}).second);
  }
  {
    Game g; // A skill's ID already in the table's ID map.
    const size_t at = row_index("M_LionC_TurnAttackRight", Table::skill);
    g.ids[{g.tables[size_t(Table::skill)], 5002005}] = g.name("SomeOtherSkill");
    Builder b;
    const Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::id && a.row == at && g.adds.size() == at);
    assert(describe(a).find("M_LionC_TurnAttackRight: ID 5002005 taken") != std::string::npos);
  }
  {
    Game g; // A row of the new name already there (another mod's).
    const size_t at = row_index("M_LionC_Default", Table::stance);
    g.rows[{g.tables[size_t(Table::stance)], g.name("M_LionC_Default")}] = g.mem.alloc(0x220);
    Builder b;
    const Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::name && a.row == at && g.adds.size() == at);
  }
  {
    Game g; // Not SB's UDataTable: the vtable, then its AddRow slot; nothing is added, whatever the table.
    g.mem.put<uint64_t>(g.tables[size_t(Table::anim)], rebased(kTableVtable) + 8);
    Builder b;
    Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::table && a.row == row_index("M_LionC_Peaceful", Table::anim));
    assert(g.adds.empty() && g.constructs == 0);
    g.mem.put<uint64_t>(g.tables[size_t(Table::anim)], rebased(kTableVtable));
    g.mem.put<uint64_t>(g.vtable_at + kAddRowSlot, rebased(kAddRow) + 0x10);
    a = b.run(g, kBase, g.tables, g.block);
    assert(a.why == Why::table && a.row == kRows - 2 && g.adds.empty()); // CharacterTable, checked first.
    assert(describe(a) == "lion rows refused M_LionC_Lurker: CharacterTable is not SB's UDataTable; 0/78 added");
  }
  {
    Game g; // Another vtable whose AddRow slot holds SB's AddRow: still not SB's UDataTable.
    const uint64_t other = g.mem.alloc(0x400);
    g.mem.put<uint64_t>(other + kAddRowSlot, rebased(kAddRow));
    g.mem.put<uint64_t>(g.tables[size_t(Table::stance)], other);
    Builder b;
    const Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::table && a.row == row_index("M_LionC_Default", Table::stance));
    assert(g.adds.empty() && g.constructs == 0);
  }
  {
    // No FName for a row's name, its donor's, an FName patch's text or a list item's: that row refused, none after it.
    const auto refused_at = [](const char *text, size_t row) {
      Game g;
      g.no_name.insert(text);
      Builder b;
      const Answer a = b.run(g, kBase, g.tables, g.block);
      assert(a.state == State::refused && a.why == Why::fname && a.row == row && a.added == row &&
             g.adds.size() == row);
      assert(describe(a).find(": the game made no FName; ") != std::string::npos);
    };
    refused_at("M_LionC_TurnAttackLeft_Cast1", row_index("M_LionC_TurnAttackLeft_Cast1", Table::step));
    refused_at("M_Behemoth_Roar1_Hit1", row_index("M_LionC_Roar_Hit1", Table::step));
    refused_at("M_LionC_ClawAttackLeft_Hit1", 0); // Row 0's NextStepAlias, before row 1 is named so.
    refused_at("Rank_Elite", kRows - 2);          // M_LionC_Lurker's DefaultEffectArray.
  }
  {
    // The pool's bound and a list item's FName length, which the recipe's own texts stay inside: refused, and nothing
    // written past the block (the fake write asserts it).
    Game g;
    const std::string text(kPoolBytes, 'x'), item(200, 'y'); // text: 2 bytes a character, twice the pool.
    std::string many;                                        // 600 FNames of 8 bytes: past the pool.
    for (int k = 0; k < 600; ++k)
      many += k ? "|N" : "N";
    const uint64_t end = g.block + kBlock;
    uint64_t pool = g.block + kRowBytes;
    assert(Builder::patch(g, g.block, Patch{0x10, Kind::string, 0, text.c_str()}, pool, end) == Why::pool);
    assert(pool == g.block + kRowBytes);
    assert(Builder::patch(g, g.block, Patch{0x10, Kind::strings, 0, text.c_str()}, pool, end) == Why::pool);
    assert(Builder::patch(g, g.block, Patch{0x10, Kind::names, 0, many.c_str()}, pool, end) == Why::pool);
    assert(Builder::patch(g, g.block, Patch{0x10, Kind::names, 0, item.c_str()}, pool, end) == Why::fname);
    pool = g.block + kRowBytes; // One that fits: its UTF-16 text and NUL at the pool's start.
    assert(Builder::patch(g, g.block, Patch{0x10, Kind::string, 0, "fits"}, pool, end) == Why::none);
    assert(pool == g.block + kRowBytes + 10 && g.mem.get<uint64_t>(g.block + 0x10) == g.block + kRowBytes);
  }
  {
    Game g; // A row struct of another size; an unreadable table.
    const uint64_t rs = g.mem.get<uint64_t>(g.tables[size_t(Table::dead)] + kRowStruct);
    g.mem.put<int32_t>(rs + kPropertiesSize, 0x2c8);
    Builder b;
    Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.why == Why::size && a.detail == 0x2c8 && g.adds.empty());
    assert(describe(a) == "lion rows refused M_LionC: CharacterDeadTable's row size 0x2c8 not 0x2d0; 0/78 added");
    g.mem.put<int32_t>(rs + kPropertiesSize, 0x2d0);
    uint64_t tables[kTableCount];
    std::memcpy(tables, g.tables, sizeof tables);
    tables[size_t(Table::skill)] = 0x8;
    a = b.run(g, kBase, tables, g.block);
    assert(a.why == Why::table && g.adds.empty());
  }

  // ---- The answer word, the status line, the log lines ----
  {
    Answer a;
    a.state = State::refused, a.why = Why::size, a.added = 77, a.row = 12, a.detail = 0x2c8;
    uint32_t asks = 0;
    const Answer b = unpack(pack(a, 70001), asks);
    assert(asks == 70001 % 65536 && b.state == a.state && b.why == a.why && b.added == 77 && b.row == 12 &&
           b.detail == 0x2c8);
    Status s;
    assert(status_line(s) == "lion=off");
    a = Answer(), a.state = State::waiting, a.why = Why::busy;
    s.word = pack(a, 0), s.ticks = 41;
    assert(status_line(s) == "lion=waiting added=0/78 asks=0 spawns=? why=busy ticks=41");
    a = Answer(), a.state = State::rows, a.added = 78;
    s.word = pack(a, 1), s.read = {2, 15, 1}, s.spawns_read = true, s.spawns = 7;
    assert(status_line(s) == "lion=rows added=78/78 asks=1 spawns=7 char=2/2 skills=15/15 stance=1/1");
    assert(describe(a) == "lion rows: 78/78 added through SB's AddRow 0x14417ba30, 0 refused");
    a = Answer(), a.state = State::refused, a.why = Why::size, a.added = 0, a.row = 76, a.detail = 0x540;
    s.word = pack(a, 2);
    assert(status_line(s) ==
           "lion=refused added=0/78 asks=2 spawns=7 why=size table=CharacterTable row=M_LionC_Lurker detail=0x540");
    a = Answer(), a.state = State::refused, a.why = Why::busy, a.added = 3, a.row = uint8_t(kRows);
    s.word = pack(a, 3);
    assert(status_line(s) == "lion=refused added=3/78 asks=3 spawns=7 why=busy table=- row=-");
    assert(describe(a) == "lion rows refused -: logic busy 300 frames; 3/78 added");
    a.why = Why::net, a.detail = 3, s.word = pack(a, 4);
    assert(status_line(s) == "lion=refused added=3/78 asks=4 spawns=7 why=net table=- row=- detail=3");
    a.why = Why::off, s.word = pack(a, 5);
    assert(status_line(s) == "lion=refused added=3/78 asks=5 spawns=7 why=coop_off table=- row=-");
    a = Answer(), a.state = State::fault, a.added = 30, s.word = pack(a, 6), s.fault = "the game at 0x14417ba30";
    assert(status_line(s) == "lion=fault added=30/78 asks=6 spawns=7 where=the game at 0x14417ba30");
  }

  std::puts("lion_rows_test: ok");
  return 0;
}
