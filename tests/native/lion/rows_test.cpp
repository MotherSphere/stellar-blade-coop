// The Lion's rows and the Gardener's on the build machine against fake memory laid out like the pinned build: the
// recipes themselves (names and IDs unique across both batches, every patch inside its struct and past its header, the
// step chains, skills, commands, stances, moves and target filters pointing at the new rows, the cut items first, then
// the Tachy ChainSpin's rows (their steps on the Tachy NPC's Show and the shipped ChainSpin moves, their effect
// starting their skill in Tachy Mode), and the CharacterTable rows last with the link flag Common and the phase-2
// stance, no field naming a Behemoth row or asset but the sound set; the Gardener's ToxicBeam steps lasting its Show's
// 5.4 s, its skills on its shipped steps, a stance with its 3 commands at speed 0 and its 3 CharacterTable rows last,
// with their trees, scales, the shipped dead and appearance rows and the album's name key); a whole run of each batch
// (the Gardener's reading only the tables its rows go into) (the table checks, each row built from its template with
// SB's lazy-init flag and Transient arrays reset, its ID, its patches of every kind read back, the pool's strings among
// them, AddRow given the new name); a missing template, a taken ID, a taken name, a wrong vtable (even with SB's AddRow
// in its slot), AddRow slot or row size, and no FName for a row's, a template's, a patch's or a list item's text,
// refusing without calling AddRow, and a later run skipping the rows already in; the pool's bound and a list item's
// FName length; FName's number split; the read-back through SB's lookups by ID (nothing found is no match); the answer
// word, the status line and the log lines.
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
size_t kind_size(Kind k) { return k == Kind::f32 || k == Kind::i32 ? 4 : k == Kind::u8 ? 1 : k == Kind::name ? 8 : 16; }

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

// One game: SB's 14 tables (its UDataTable vtable with AddRow in slot +0x2b0, each row struct with its size), the
// template rows every recipe row names (filled with a pattern, their lazy-init flag set, their Transient arrays
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
    const auto donor_rows = [this](const Batch &b) {
      for (size_t i = 0; i < b.count; ++i) {
        const Row &r = b.rows[i];
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
    };
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
    donor_rows(kLion);
    donor_rows(kGardener);
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

size_t row_index(const char *name, Table t, const Batch &b = kLion) {
  for (size_t i = 0; i < b.count; ++i)
    if (b.rows[i].table == t && !std::strcmp(b.rows[i].name, name))
      return i;
  assert(false);
  return b.count;
}
} // namespace

int main() {
  // ---- The recipe ----
  static_assert(kRows == 237, "the 4 cut items' rows, the Tachy ChainSpin's 11, 21 commands, 21 skills, 80 steps, 61 "
                              "moves, 25 target filters, 5 results, the effect, 2 anim sets, 2 stances, the dead and "
                              "appearance rows and the two CharacterTable rows");
  const auto rows_of = [](Table t) { return coop::lion::rows_of(kLion, t); };
  assert(rows_of(Table::step) == 89 && rows_of(Table::skill) == 23 && rows_of(Table::command) == 21 &&
         rows_of(Table::move) == 61 && rows_of(Table::filter) == 25 && rows_of(Table::result) == 5 &&
         rows_of(Table::effect) == 2 && rows_of(Table::anim) == 2 && rows_of(Table::stance) == 2 &&
         rows_of(Table::dead) == 1 && rows_of(Table::appearance) == 1 && rows_of(Table::character) == 2 &&
         rows_of(Table::item) == 2 && rows_of(Table::consumable) == 1);
  // The Gardener's batch: ToxicBeam's 3 steps, 3 skills and their commands, its stance, 3 CharacterTable rows.
  static_assert(kGardenerRows == 13, "the Gardener's 13 rows");
  assert(coop::lion::rows_of(kGardener, Table::step) == 3 && coop::lion::rows_of(kGardener, Table::skill) == 3 &&
         coop::lion::rows_of(kGardener, Table::command) == 3 && coop::lion::rows_of(kGardener, Table::stance) == 1 &&
         coop::lion::rows_of(kGardener, Table::character) == 3);
  // The cut items first, in the order each needs the one before: the skill the stimpacks play, the Beta Stimpack's
  // consumable, then the two items (ItemTable ID, ConsumableAlias +0x14c). The skill is the health potion's under the
  // name HP2Burst_Potion gives (FirstSkillActiveAlias +0x100: the potion's own steps).
  {
    const char *const kCut[] = {"P_Eve_Sword_Normal_Buff_1", "Buff_HP2MP", "HP2Burst_Potion", "Buff_HP2MP"};
    const Table kCutTables[] = {Table::skill, Table::consumable, Table::item, Table::item};
    for (size_t i = 0; i < 4; ++i)
      assert(kRecipe[i].table == kCutTables[i] && !std::strcmp(kRecipe[i].name, kCut[i]));
    assert(!std::strcmp(kRecipe[0].donor, "P_Eve_Sword_Normal_Potion_1") && kRecipe[0].id == 6000101 &&
           kRecipe[1].id == 1032 && kRecipe[2].id == 300013 && kRecipe[3].id == 300014);
  }
  // The two CharacterTable rows last, M_LionC the very last: NewActor finds 50020 only once every other row is in.
  assert(kRecipe[kRows - 1].table == Table::character && !std::strcmp(kRecipe[kRows - 1].name, "M_LionC") &&
         kRecipe[kRows - 1].id == 50020 && kRecipe[kRows - 2].table == Table::character &&
         kRecipe[kRows - 2].id == 50021);
  // Its CharacterTable rows last, M_Gardener (50010) the very last.
  assert(kGardenerRecipe[kGardenerRows - 1].table == Table::character &&
         !std::strcmp(kGardenerRecipe[kGardenerRows - 1].name, "M_Gardener") &&
         kGardenerRecipe[kGardenerRows - 1].id == 50010 && kGardenerRecipe[kGardenerRows - 2].id == 50012 &&
         kGardenerRecipe[kGardenerRows - 3].id == 50011);
  std::vector<Row> both(kRecipe, kRecipe + kRows); // Both batches, in kPatches' order.
  both.insert(both.end(), kGardenerRecipe, kGardenerRecipe + kGardenerRows);
  for (size_t t = 0; t < kTableCount; ++t) { // Names and IDs unique in each table across both batches.
    std::set<std::string> names;
    std::set<uint32_t> ids;
    for (const Row &r : both)
      if (size_t(r.table) == t) {
        assert(names.insert(r.name).second);
        assert(kTables[t].id ? r.id && ids.insert(r.id).second : r.id == 0);
        assert(std::strcmp(r.name, r.donor) != 0);
      }
  }
  size_t patches = 0;
  for (const Row &r : both) {
    const TableInfo &info = kTables[size_t(r.table)];
    assert(r.first == patches && r.count > 0);
    patches += r.count;
    for (size_t p = r.first; p < size_t(r.first) + r.count; ++p) {
      const Patch &x = kPatches[p];
      // Inside the struct, past the vtable, the lazy-init flag and the ID, clear of every Transient array.
      assert(x.at >= kIdAt + (info.id ? 4 : 0) && x.at + kind_size(x.kind) <= info.size);
      for (uint16_t at : info.transient)
        assert(!at || x.at + kind_size(x.kind) <= at || x.at >= at + 16u);
      const bool number = x.kind == Kind::f32 || x.kind == Kind::i32 || x.kind == Kind::u8;
      assert(number ? x.text == nullptr : x.text != nullptr);
      // An int32 or a byte is a whole number its float holds exactly; a byte fits.
      assert(x.kind == Kind::f32 || (x.f == float(int32_t(x.f)) && x.f > -16777216.0f && x.f < 16777216.0f));
      assert(x.kind != Kind::u8 || (x.f >= 0 && x.f <= 255));
      // No field names a Behemoth row or asset, but the sound set the Lion has no copy of (CharacterTable +0x520).
      assert(!x.text || (!std::strstr(x.text, "Behemoth") && !std::strstr(x.text, "CH_M_NA_46")) ||
             (r.table == Table::character && x.at == 0x520));
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
  // Every reference among the new rows lands on a new row: the steps' chains and moves, the skills' first steps and
  // target filters, the commands' skills, the stances' commands and anim sets, the CharacterTable rows' stances, dead
  // row and appearance.
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
  const auto each = [](const char *list, auto f) { // A '|'-joined list's items.
    for (std::string s = list; !s.empty();) {
      const size_t bar = s.find('|');
      f(s.substr(0, bar));
      s = bar == std::string::npos ? "" : s.substr(bar + 1);
    }
  };
  for (const Row &r : kRecipe) {
    if (r.table == Table::step) {
      if (const char *next = patched(r, 0x34))
        assert(has(Table::step, next));
      if (const char *moves = patched(r, 0x138)) // SelfMoveAliasArray: the Lion's own moves, the ChainSpin's shipped.
        each(moves, [&](const std::string &m) {
          assert(has(Table::move, m.c_str()) || (!std::strncmp(r.name, "P_Eve_Tachy_Skill_ChainSpin1_1_", 31) &&
                                                 !m.compare(0, 33, "P_Eve_Tachy_Skill_ChainSpin1_Move")));
        });
    }
    if (r.table == Table::skill && !std::strncmp(r.name, "M_LionC_", 8))
      assert(has(Table::step, patched(r, 0x100)) && std::strstr(patched(r, 0x100), r.name) == patched(r, 0x100) &&
             has(Table::filter, patched(r, 0xb4)));
    if (r.table == Table::command)
      assert(has(Table::skill, patched(r, 0x18)) && !std::strcmp(patched(r, 0x18), r.name));
    if (r.table == Table::character)
      assert(!std::strcmp(patched(r, 0x3a8), "M_LionC_Default") && !std::strcmp(patched(r, 0x298), "M_LionC") &&
             !std::strcmp(patched(r, 0x420), "M_LionC") && !std::strcmp(patched(r, 0x398), "M_LionC_Phase2") &&
             has(Table::dead, "M_LionC") && has(Table::appearance, "M_LionC") &&
             has(Table::stance, "M_LionC_Default") && has(Table::stance, "M_LionC_Phase2"));
    // The link flag: the Behemoth's "Behemoth" picks EVE's link Show whose target clip the Lion lacks; "Common" plays
    // the anim sets' Hit_Sword_Normal_LinkAttack1, which it has.
    if (r.table == Table::character)
      assert(patched(r, 0x60) && !std::strcmp(patched(r, 0x60), "Common"));
  }
  // The stances: phase 1 lists 17 commands, phase 2 (HP under 60%: Condition_ActorStat HP +0x30, UnderRate +0x31, 60 at
  // +0x34, Priority 10 at +0x14) all 21 with the phase-2 roar, and its start runs M_LionC_PhaseRoar, the effect whose
  // action (+0x2fc, EffectAction_UseSkill 69) uses that roar (+0x300). Neither holds HP at 60%.
  const auto value = [](const Row &r, uint16_t at) {
    for (size_t p = r.first; p < size_t(r.first) + r.count; ++p)
      if (kPatches[p].at == at)
        return kPatches[p].f;
    return -1.0f;
  };
  {
    const Row &one = kRecipe[row_index("M_LionC_Default", Table::stance)];
    const Row &two = kRecipe[row_index("M_LionC_Phase2", Table::stance)];
    size_t n = 0, m = 0;
    each(patched(one, 0x90), [&](const std::string &c) { assert(has(Table::command, c.c_str())), ++n; });
    each(patched(two, 0x90), [&](const std::string &c) { assert(has(Table::command, c.c_str())), ++m; });
    assert(n == 17 && m == 21 && !std::strstr(patched(one, 0x90), "M_LionC_RoarPhaseChange") &&
           std::strstr(patched(two, 0x90), "M_LionC_RoarPhaseChange"));
    assert(value(two, 0x14) == 10 && value(two, 0x30) == 1 && value(two, 0x31) == 2 && value(two, 0x34) == 60);
    assert(std::strstr(patched(two, 0x110), "\"M_LionC_PhaseRoar\"") &&
           !std::strstr(patched(one, 0x110), "MinimumHP") && !std::strstr(patched(two, 0x110), "MinimumHP"));
    assert(has(Table::anim, patched(one, 0x150)) && has(Table::anim, patched(one, 0x160)));
    const Row &roar = kRecipe[row_index("M_LionC_PhaseRoar", Table::effect)];
    assert(value(roar, 0x2fc) == 69 && !std::strcmp(patched(roar, 0x300), "M_LionC_RoarPhaseChange") &&
           has(Table::skill, "M_LionC_RoarPhaseChange"));
  }
  // EVE's Tachy ChainSpin after the cut items: its 9 steps (100450001-100450009, each a copy of a ChainStab1 step), the
  // first playing the Tachy NPC's Show of EVE's clip (ShowPath +0x160), then the skill (1004500) that starts them
  // (FirstSkillActiveAlias +0x100) with no acquisition (+0x17c), then the effect (1004500) whose action (+0x2fc,
  // EffectAction_UseSkill 69) uses it (+0x300) only while EVE has P_Eve_TachyMode (+0x80, a condition of the effect).
  {
    for (size_t i = 0; i < 9; ++i)
      assert(kRecipe[4 + i].table == Table::step && kRecipe[4 + i].id == 100450001 + i &&
             !std::strncmp(kRecipe[4 + i].name, "P_Eve_Tachy_Skill_ChainSpin1_1_", 31) &&
             !std::strncmp(kRecipe[4 + i].donor, "P_Eve_Tachy_Skill_Chainstab1_1_", 31));
    assert(!std::strcmp(patched(kRecipe[4], 0x160), "CH_NPC_TachyNPC/Skill/N_TachyNPC_SwingChain"));
    const Row &skill = kRecipe[13], &use = kRecipe[14];
    assert(skill.table == Table::skill && skill.id == 1004500 &&
           !std::strcmp(skill.name, "P_Eve_Tachy_Skill_ChainSpin1_1"));
    assert(!std::strcmp(patched(skill, 0x100), "P_Eve_Tachy_Skill_ChainSpin1_1_Cast1") &&
           !std::strcmp(patched(skill, 0x17c), "None"));
    assert(use.table == Table::effect && use.id == 1004500 && value(use, 0x2fc) == 69 &&
           !std::strcmp(patched(use, 0x300), skill.name) && !std::strcmp(patched(use, 0x80), "P_Eve_TachyMode"));
  }
  // A move of the Lion's own clip travel: the low jump's leap, up to 615.5 cm toward EVE (LocalAxis 6 at +0x3a,
  // InsideTargetOrSelf 3 at +0x3b, SelfToTarget 2 at +0x60, ForwardValue +0x94), stopping 150 cm short of her
  // (LimitApproachDistance +0xb0), where its paws land at their peak. Its skill's range starts 30 cm past that stop
  // (NearDistance +0x20), so the leap never starts with EVE already inside it.
  {
    const Row &leap = kRecipe[row_index("M_LionC_JumpAttackLow_Move1", Table::move)];
    assert(value(leap, 0x3a) == 6 && value(leap, 0x3b) == 3 && value(leap, 0x60) == 2 && value(leap, 0x94) == 615.5f &&
           value(leap, 0xb0) == 150.0f);
    const Row &range = kRecipe[row_index("M_LionC_JumpAttackLow_Target", Table::filter)];
    assert(value(range, 0x20) == 180.0f && value(range, 0x24) == 490.0f);
  }
  // The Gardener's: ToxicBeam's three steps chain into each other (NextStepAlias +0x34), its Cast1 plays its Show
  // (ShowPath +0x160) and the three last 5.4 s, the Show's length (Duration +0x18; Hit1 keeps its template's 0.2), its
  // Hit1 fires the Gardener's shells (+0x178, +0x190). Each skill is MeleeAttack (+0x80, what the flag trees pick):
  // ToxicBeam starts its own Cast1 (+0x100), the two others the shipped SingleShot_4 and MultipleShot_1 steps. Each
  // command's skill (+0x18) is its own; the stance lists the 3 commands (+0x90) with every speed 0 (+0xa8 to +0xb4).
  // The CharacterTable rows: its stance (+0x3a8), the shipped dead, appearance and detect rows (+0x298, +0x420,
  // +0x3f8), the Tentacle tree or the Skulling test tree (+0x3e8), scale 1 or 0.5 (+0x1fc), MaxHP 37840 as an int32
  // (+0x78), the album's name key (+0x508), no link flag (+0x60), no weak point (+0x2f8) and the Cocoon's despawn.
  {
    const auto at = [](const char *name, Table t) -> const Row & {
      return kGardenerRecipe[row_index(name, t, kGardener)];
    };
    const Row &cast = at("M_GardenerC_ToxicBeam_Cast1", Table::step),
              &hit = at("M_GardenerC_ToxicBeam_Hit1", Table::step);
    const Row &finish = at("M_GardenerC_ToxicBeam_Finish1", Table::step);
    assert(!std::strcmp(patched(cast, 0x34), hit.name) && !std::strcmp(patched(hit, 0x34), finish.name) &&
           !patched(finish, 0x34));
    assert(!std::strcmp(patched(cast, 0x160), "CH_M_NA_01_Gardener/Skill/M_Gardener_ToxicBeam"));
    assert(value(cast, 0x18) + value(hit, 0x18) + value(finish, 0x18) == 1.86f + 0.2f + 3.34f &&
           value(cast, 0x18) == 1.86f && value(finish, 0x18) == 3.34f);
    assert(!std::strcmp(patched(hit, 0x190), patched(hit, 0x178)) &&
           std::string(patched(hit, 0x190)).rfind("M_Gardener_SingleShot_Projectile1|", 0) == 0);
    const char *const kFirst[] = {"M_Gardener_SingleShot_4_Cast1", "M_Gardener_MultipleShot_1_Cast1", cast.name};
    const char *const kSkills[] = {"M_GardenerC_SingleShot", "M_GardenerC_MultipleShot", "M_GardenerC_ToxicBeam"};
    for (size_t k = 0; k < 3; ++k) {
      const Row &skill = at(kSkills[k], Table::skill), &command = at(kSkills[k], Table::command);
      assert(!std::strcmp(patched(skill, 0x80), "MeleeAttack") && !std::strcmp(patched(skill, 0x100), kFirst[k]));
      assert(skill.id == 5001010 + k && command.id == skill.id && !std::strcmp(patched(command, 0x18), skill.name));
    }
    const Row &stance = at("M_GardenerC_Default", Table::stance);
    assert(
        stance.id == 500101 &&
        !std::strcmp(patched(stance, 0x90), "M_GardenerC_SingleShot|M_GardenerC_MultipleShot|M_GardenerC_ToxicBeam"));
    for (uint16_t speed = 0xa8; speed <= 0xb4; speed += 4)
      assert(value(stance, speed) == 0.0f);
    const char *const kTrees[] = {"M_Skulling_AI_Test", "M_Tentacle_AI", "M_Tentacle_AI"};
    const float kScales[] = {1.0f, 0.5f, 1.0f};
    for (size_t k = 0; k < 3; ++k) {
      const Row &c = kGardenerRecipe[kGardenerRows - 3 + k];
      assert(c.table == Table::character && !std::strcmp(c.donor, "M_Maelstrom"));
      assert(!std::strcmp(patched(c, 0x3a8), stance.name) && !std::strcmp(patched(c, 0x298), "M_Gardener") &&
             !std::strcmp(patched(c, 0x420), "M_Gardener") && !std::strcmp(patched(c, 0x3f8), "M_Gardener"));
      assert(std::strstr(patched(c, 0x3e8), kTrees[k]) && value(c, 0x1fc) == kScales[k] && value(c, 0x78) == 37840);
      assert(!std::strcmp(patched(c, 0x508), "Char_M_Gardener_AlbumName") && !std::strcmp(patched(c, 0x60), "") &&
             !std::strcmp(patched(c, 0x2f8), "None") && !std::strcmp(patched(c, 0x2a8), "Despawn/M_Cocoon_Despawn"));
      assert(std::strstr(patched(c, 0x220), "M_Common_FixedLocation") && !std::strstr(patched(c, 0x220), "Maelstrom"));
    }
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
  // Each added row of a batch (from: its first add) as AddRow saw it: in order, to its table, under its new name; SB's
  // flag back to 0, its ID, the Transient arrays empty; each patch as written; every other byte past the header is the
  // donor's.
  const auto verify = [](Game &g, const Builder &b, const Batch &batch, size_t from) {
    for (size_t i = 0; i < batch.count; ++i) {
      const Row &r = batch.rows[i];
      const TableInfo &info = kTables[size_t(r.table)];
      const Game::Add &add = g.adds[from + i];
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
        else if (x.kind == Kind::i32)
          assert(Game::field<int32_t>(add, x.at) == int32_t(x.f));
        else if (x.kind == Kind::u8)
          assert(add.block[x.at] == uint8_t(x.f));
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
  };
  {
    Game g;
    Builder b(kLion);
    const Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::rows && a.why == Why::none && a.added == kRows && b.count() == kRows);
    assert(g.adds.size() == kRows && g.constructs == int(kRows) && g.copies == int(kRows));
    verify(g, b, kLion, 0);
    // Spot checks: a Hit step's collision group as JSON text, its type (Hit, 1) and detection (ActiveCollision, 2) as
    // bytes, the first step's Show, the phase-1 stance's 17 commands, the dead row's Shows, the Lion's 160000 HP as an
    // int32, the brains.
    const Game::Add &hit = g.adds[row_index("M_LionC_ClawAttackLeft_Hit1", Table::step)];
    assert(g.string_field(hit, 0x1c0) ==
           "[{\"CollisionGroupName\":\"Mon_Lion_Attack_L_Arm_Collision\", \"DelayTime\":0}]");
    const Game::Add &cast = g.adds[row_index("M_LionC_ClawAttackLeft_Cast1", Table::step)];
    assert(g.name_text(Game::field<uint64_t>(cast, 0x160)) == "CH_M_NA_02_Lion/Skill/M_LionC_ClawAttackLeft_1");
    assert(uint32_t(Game::field<uint64_t>(cast, 0x160) >> 32) == 2); // "_1" as FName's number, as SB makes it.
    const Game::Add &stance = g.adds[row_index("M_LionC_Default", Table::stance)];
    assert(Game::field<int32_t>(stance, 0x90 + 8) == 17);
    assert(hit.block[0x14] == 1 && hit.block[0x1a5] == 2 && Game::field<int32_t>(g.adds[kRows - 1], 0x78) == 160000);
    const Game::Add &dead = g.adds[row_index("M_LionC", Table::dead)];
    assert(g.list_field(dead, 0x10, Kind::strings) == "CH_M_NA_02_Lion/Basic/M_Lion_Dead");
    // The template's move list emptied where a step has no move of its own (no data, no count), the template's
    // CanCutoff (+0x240) cleared on a Hit step, the link flag one FName.
    assert(Game::field<uint64_t>(hit, 0x138) == 0 && Game::field<int32_t>(hit, 0x138 + 8) == 0 &&
           hit.block[0x240] == 0);
    assert(g.list_field(g.adds[kRows - 1], 0x60, Kind::names) == "Common");
    assert(g.string_field(g.adds[kRows - 1], 0x3e8) ==
           "/Game/GameDesign/Combat/BehaviorTree/Monster/M_Skulling_AI_Test");
    assert(g.string_field(g.adds[kRows - 2], 0x3e8) ==
           "/Game/GameDesign/Combat/BehaviorTree/Monster/M_LesserLurker_AI");
    assert(g.string_field(g.adds[kRows - 1], 0x508).empty() && Game::field<uint64_t>(g.adds[kRows - 1], 0x508) == 0);

    // The cut items: the Burst Stimpack's consumable and text keys, the Beta Stimpack's consumable with its two effects
    // (EffectAliasArray +0x20) and the skill they both play (ConsumeSkillAlias +0x38).
    const Game::Add &burst = g.adds[row_index("HP2Burst_Potion", Table::item)];
    assert(g.name_text(Game::field<uint64_t>(burst, 0x14c)) == "HP2Burst_Potion" &&
           g.string_field(burst, 0x30) == "Item_HP2Burst_Potion_Name");
    const Game::Add &beta = g.adds[row_index("Buff_HP2MP", Table::consumable)];
    assert(g.list_field(beta, 0x20, Kind::names) == "Item_Buff_HP2MP_ReduceHP|Item_Buff_HP2MP_GainMP" &&
           g.name_text(Game::field<uint64_t>(beta, 0x38)) == "P_Eve_Sword_Normal_Buff_1");

    // SB's lookups by ID find our rows: both CharacterTable rows, the 23 skills, both stances' names.
    Builder::ReadBack rb = b.read_back(g, g.tables);
    assert(rb.character == 2 && rb.skills == 23 && rb.stance == 2);
    g.skill_override = 0x12345678, g.skill_override_id = 5002003;
    rb = b.read_back(g, g.tables);
    assert(rb.skills == 22);
    assert(describe_read(kLion, rb) == "lion rows by SB's lookups: CharacterTable 50020-50021 2/2, SkillTable "
                                       "1004500-6000101 22/23, stance 500200-500201 2/2");

    // A second run adds nothing: every row is in.
    const Answer again = b.run(g, kBase, g.tables, g.block);
    assert(again.state == State::rows && again.added == kRows && g.adds.size() == kRows);

    // The Gardener's batch in the same game, on its own Builder: its 13 rows after the 237, none of them meeting
    // another; SB's lookups find its 3 CharacterTable rows, 3 skills and its stance.
    Builder gb(kGardener);
    const Answer ga = gb.run(g, kBase, g.tables, g.block);
    assert(ga.state == State::rows && ga.added == kGardenerRows && g.adds.size() == kRows + kGardenerRows);
    verify(g, gb, kGardener, kRows);
    const Game::Add &gardener = g.adds[kRows + kGardenerRows - 1];
    assert(Game::field<int32_t>(gardener, 0x78) == 37840 && Game::field<float>(gardener, 0x1fc) == 1.0f &&
           g.string_field(gardener, 0x508) == "Char_M_Gardener_AlbumName" &&
           Game::field<uint32_t>(gardener, kIdAt) == 50010);
    rb = gb.read_back(g, g.tables);
    assert(rb.character == 3 && rb.skills == 3 && rb.stance == 1);
    assert(describe_read(kGardener, rb) == "gardener rows by SB's lookups: CharacterTable 50010-50012 3/3, SkillTable "
                                           "5001010-5001012 3/3, stance 500101 1/1");
    assert(gb.run(g, kBase, g.tables, g.block).added == kGardenerRows && g.adds.size() == kRows + kGardenerRows);
  }
  {
    // The Gardener's run reads only the tables its rows go into: an appearance table that is not SB's stops the Lion's
    // batch, not the Gardener's.
    Game g;
    g.mem.put<uint64_t>(g.tables[size_t(Table::appearance)], rebased(kTableVtable) + 8);
    Builder lb(kLion), gb(kGardener);
    assert(lb.run(g, kBase, g.tables, g.block).why == Why::table && g.adds.empty());
    assert(gb.run(g, kBase, g.tables, g.block).state == State::rows && g.adds.size() == kGardenerRows);
  }
  {
    Game g; // A taken ID stops the Gardener's batch at its row; the Lion's goes on.
    g.ids[{g.tables[size_t(Table::character)], 50010}] = g.name("SomeOtherMonster");
    Builder gb(kGardener), lb(kLion);
    const Answer a = gb.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::id && a.row == kGardenerRows - 1 && a.added == kGardenerRows - 1);
    assert(describe(kGardener, a) == "gardener rows refused M_Gardener: ID 50010 taken; 12/13 added");
    assert(lb.run(g, kBase, g.tables, g.block).state == State::rows && g.adds.size() == kGardenerRows - 1 + kRows);
  }
  {
    Game g; // No row added: SB's lookups find nothing, and nothing found is no match (0 == 0 counts no row).
    const Builder::ReadBack rb = Builder(kLion).read_back(g, g.tables);
    assert(rb.character == 0 && rb.skills == 0 && rb.stance == 0);
  }

  // ---- Refusals: nothing handed to AddRow for the refused row or any after it; a later run goes on ----
  {
    Game g; // The steps' template gone: the first step refused, every row before it in.
    const size_t first = row_index("M_LionC_ClawAttackLeft_Cast1", Table::step);
    const uint64_t key = g.name("M_Behemoth_ScratchLeft_Finish1");
    const uint64_t row = g.rows[{g.tables[size_t(Table::step)], key}];
    g.rows.erase({g.tables[size_t(Table::step)], key});
    Builder b(kLion);
    Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::donor && a.row == first && a.added == first);
    assert(g.adds.size() == first && !b.added(first) && first == 107);
    assert(describe(kLion, a) ==
           "lion rows refused M_LionC_ClawAttackLeft_Cast1: template M_Behemoth_ScratchLeft_Finish1 "
           "missing; 107/237 added");
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
    Builder b(kLion);
    const Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::id && a.row == at && g.adds.size() == at);
    assert(describe(kLion, a).find("M_LionC_TurnAttackRight: ID 5002005 taken") != std::string::npos);
  }
  {
    Game g; // A row of the new name already there (another mod's).
    const size_t at = row_index("M_LionC_Default", Table::stance);
    g.rows[{g.tables[size_t(Table::stance)], g.name("M_LionC_Default")}] = g.mem.alloc(0x220);
    Builder b(kLion);
    const Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::name && a.row == at && g.adds.size() == at);
  }
  {
    Game g; // Not SB's UDataTable: the vtable, then its AddRow slot; nothing is added, whatever the table.
    g.mem.put<uint64_t>(g.tables[size_t(Table::anim)], rebased(kTableVtable) + 8);
    Builder b(kLion);
    Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::table && a.row == row_index("M_LionC_Peaceful", Table::anim));
    assert(g.adds.empty() && g.constructs == 0);
    g.mem.put<uint64_t>(g.tables[size_t(Table::anim)], rebased(kTableVtable));
    g.mem.put<uint64_t>(g.vtable_at + kAddRowSlot, rebased(kAddRow) + 0x10);
    a = b.run(g, kBase, g.tables, g.block);
    assert(a.why == Why::table && a.row == kRows - 2 && g.adds.empty()); // CharacterTable, checked first.
    assert(describe(kLion, a) ==
           "lion rows refused M_LionC_Lurker: CharacterTable is not SB's UDataTable; 0/237 added");
  }
  {
    Game g; // Another vtable whose AddRow slot holds SB's AddRow: still not SB's UDataTable.
    const uint64_t other = g.mem.alloc(0x400);
    g.mem.put<uint64_t>(other + kAddRowSlot, rebased(kAddRow));
    g.mem.put<uint64_t>(g.tables[size_t(Table::stance)], other);
    Builder b(kLion);
    const Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::table && a.row == row_index("M_LionC_Default", Table::stance));
    assert(g.adds.empty() && g.constructs == 0);
  }
  {
    // No FName for a row's name, its donor's, an FName patch's text or a list item's: that row refused, none after it.
    const auto refused_at = [](const char *text, size_t row) {
      Game g;
      g.no_name.insert(text);
      Builder b(kLion);
      const Answer a = b.run(g, kBase, g.tables, g.block);
      assert(a.state == State::refused && a.why == Why::fname && a.row == row && a.added == row &&
             g.adds.size() == row);
      assert(describe(kLion, a).find(": the game made no FName; ") != std::string::npos);
    };
    refused_at("M_LionC_TurnAttackLeft_Cast1", row_index("M_LionC_TurnAttackLeft_Cast1", Table::step));
    // The effects' template: the ChainSpin's effect is the first to use it.
    refused_at("M_Scarlet_CounterLinkStart", row_index("P_Eve_Tachy_Skill_ChainSpin1_Use", Table::effect));
    refused_at("HP_Potion", row_index("HP2Burst_Potion", Table::item)); // The stimpacks' template.
    refused_at("M_Behemoth_ScratchLeft_Move2", row_index("M_LionC_ClawAttackLeft_Turn", Table::move));
    // A Hit step's just-parry result, an FName patch.
    refused_at("M_Common_ParryJustFX", row_index("M_LionC_ClawAttackLeft_Hit1", Table::step));
    // The Cast step's NextStepAlias, before the Hit step is named so.
    refused_at("M_LionC_ClawAttackLeft_Hit1", row_index("M_LionC_ClawAttackLeft_Cast1", Table::step));
    refused_at("Rank_Elite", kRows - 2); // M_LionC_Lurker's DefaultEffectArray.
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
    Builder b(kLion);
    Answer a = b.run(g, kBase, g.tables, g.block);
    assert(a.why == Why::size && a.detail == 0x2c8 && g.adds.empty());
    assert(describe(kLion, a) ==
           "lion rows refused M_LionC: CharacterDeadTable's row size 0x2c8 not 0x2d0; 0/237 added");
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
    assert(status_line(kLion, s) == "lion=off");
    a = Answer(), a.state = State::waiting, a.why = Why::busy;
    s.word = pack(a, 0), s.ticks = 41;
    assert(status_line(kLion, s) == "lion=waiting added=0/237 asks=0 spawns=? why=busy ticks=41");
    a = Answer(), a.state = State::rows, a.added = 237;
    s.word = pack(a, 1), s.read = {2, 23, 2}, s.spawns_read = true, s.spawns = 7;
    assert(status_line(kLion, s) == "lion=rows added=237/237 asks=1 spawns=7 char=2/2 skills=23/23 stance=2/2");
    assert(describe(kLion, a) == "lion rows: 237/237 added through SB's AddRow 0x14417ba30, 0 refused");
    a = Answer(), a.state = State::refused, a.why = Why::size, a.added = 0, a.row = uint8_t(kRows - 2),
    a.detail = 0x540;
    s.word = pack(a, 2);
    assert(status_line(kLion, s) ==
           "lion=refused added=0/237 asks=2 spawns=7 why=size table=CharacterTable row=M_LionC_Lurker detail=0x540");
    a = Answer(), a.state = State::refused, a.why = Why::busy, a.added = 3, a.row = uint8_t(kRows);
    s.word = pack(a, 3);
    assert(status_line(kLion, s) == "lion=refused added=3/237 asks=3 spawns=7 why=busy table=- row=-");
    assert(describe(kLion, a) == "lion rows refused -: logic busy 300 frames; 3/237 added");
    a.why = Why::net, a.detail = 3, s.word = pack(a, 4);
    assert(status_line(kLion, s) == "lion=refused added=3/237 asks=4 spawns=7 why=net table=- row=- detail=3");
    a.why = Why::off, s.word = pack(a, 5);
    assert(status_line(kLion, s) == "lion=refused added=3/237 asks=5 spawns=7 why=coop_off table=- row=-");
    a = Answer(), a.state = State::fault, a.added = 30, s.word = pack(a, 6), s.fault = "the game at 0x14417ba30";
    assert(status_line(kLion, s) == "lion=fault added=30/237 asks=6 spawns=7 where=the game at 0x14417ba30");
    // The Gardener's line: its word, its own counts.
    Status gs;
    assert(status_line(kGardener, gs) == "gardener=off");
    a = Answer(), a.state = State::rows, a.added = 13;
    gs.word = pack(a, 1), gs.read = {3, 3, 1}, gs.spawns_read = true, gs.spawns = 6;
    assert(status_line(kGardener, gs) == "gardener=rows added=13/13 asks=1 spawns=6 char=3/3 skills=3/3 stance=1/1");
    assert(describe(kGardener, a) == "gardener rows: 13/13 added through SB's AddRow 0x14417ba30, 0 refused");
    a = Answer(), a.state = State::refused, a.why = Why::donor, a.added = 3, a.row = 3, gs.word = pack(a, 2);
    assert(status_line(kGardener, gs) ==
           "gardener=refused added=3/13 asks=2 spawns=6 why=donor table=SkillTable row=M_GardenerC_SingleShot");
    assert(describe(kGardener, a) ==
           "gardener rows refused M_GardenerC_SingleShot: template M_Gardener_SingleShot_4 missing; 3/13 added");
  }

  std::puts("lion_rows_test: ok");
  return 0;
}
