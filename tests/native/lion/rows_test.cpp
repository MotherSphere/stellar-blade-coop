// The Lion's rows, the Gardener's, the Tendril's, the Shock Bolt's and Matrix XIII's on the build machine against fake
// memory laid out like the pinned build (Matrix XIII's camp and env-spawn rows with patches of their own, in the two
// zone tables no other batch reads, and its 5 shipped trigger rows patched in place, never added, a wrong zone table,
// a taken camp ID, a missing shipped row or one its ID does not name refusing it alone): the recipes themselves
// (names and IDs unique across the batches, every patch inside its struct
// and past its header, the
// step chains, skills, commands, stances, moves and target filters pointing at the new rows, the cut items first, then
// the Tachy ChainSpin's rows (their steps on the Tachy NPC's Show and the shipped ChainSpin moves, their effect
// starting their skill in Tachy Mode), and the CharacterTable rows last with the link flag Common and the phase-2
// stance, no field naming a Behemoth row or asset but the sound set; the Shock Bolt's 4 in a batch of their own (its
// item, skill, projectile and stun hit result), whose ProjectileTable the Lion's batch never reads; the Gardener's
// ToxicBeam steps lasting its Show's
// 5.4 s, its skills on its shipped steps, a stance with its 3 commands at speed 0 and its 3 CharacterTable rows last,
// with their trees, scales, the shipped dead and appearance rows and the album's name key; the Tendril's skills each
// playing a run-time Show from its first step, its Hit steps hitting through its own areas, its stance with its 11
// commands, its dead row on its run-time death Show and its CharacterTable row last, on the Skulling test tree, with
// no link flag and no name); a whole run of each batch (the Gardener's reading only the tables its rows go into) (the
// table checks, each row built from its template with
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

// One game: SB's 20 tables (its UDataTable vtable with AddRow in slot +0x2b0, each row struct with its size), the
// template rows every recipe row names (filled with a pattern, their lazy-init flag set, their Transient arrays
// holding junk as after SB parsed them; a shipped row patched in place is its own template, with its ID in the row and
// the ID map), FNames interned by text and number, the RowMap and ID maps as AddRow fills them, and the registry's
// lookups by ID over them.
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
  // CopyScriptStruct of the block back over a shipped row: the block as copied, and the row's bytes before.
  struct Put : Add {
    uint64_t row;
    std::vector<uint8_t> before;
  };
  std::vector<Put> puts;
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
        const TableInfo &info = table_info(r.table);
        const uint64_t row = mem.alloc(info.size);
        for (size_t k = 0; k < info.size; ++k)
          mem.at(row + k, 1)[0] = uint8_t(0x40 + (k * 7 + t) % 0x3f);
        mem.put<uint8_t>(row + kInitFlag, 1);
        for (uint16_t at : info.transient)
          if (at)
            mem.put<uint64_t>(at + row, 0x1234567812345678), mem.put<uint64_t>(at + row + 8, 0x0000000500000005);
        rows[{tables[t], key}] = row;
        donors[row] = t;
        if (shipped_row(r) && info.id)
          mem.put<uint32_t>(row + kIdAt, r.id), ids[{tables[t], r.id}] = key;
      }
    };
    mem.regions[vtable].assign(0x400, 0);
    mem.put<uint64_t>(vtable + kAddRowSlot, rebased(kAddRow));
    for (size_t t = 0; t < kTableCount; ++t) {
      tables[t] = mem.alloc(0x100);
      const uint64_t rs = mem.alloc(0x100);
      mem.put<uint64_t>(tables[t], rebased(kTableVtable));
      mem.put<uint64_t>(tables[t] + kRowStruct, rs);
      mem.put<int32_t>(rs + kPropertiesSize, int32_t(table_info(Table(t)).size));
    }
    vtable_at = vtable;
    block = mem.alloc(kBlock);
    donor_rows(kLion);
    donor_rows(kGardener);
    donor_rows(kTendril);
    donor_rows(kBolt);
    donor_rows(kMxiii);
    donor_rows(kShop);
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
    const uint32_t size = table_info(Table(table_of_struct(rs))).size;
    std::memset(mem.at(row, size), 0, size);
    ++constructs;
  }
  void copy(uint64_t rs, uint64_t dest, uint64_t src) {
    const size_t t = table_of_struct(rs);
    const uint32_t size = table_info(Table(t)).size;
    if (dest != block) { // Back over a shipped row, once its copy into the block was patched.
      assert(src == block && donors.count(dest) && donors[dest] == t && constructs == copies);
      Put put;
      put.table = t, put.name = 0, put.row = dest;
      for (const auto &kv : rows)
        if (kv.second == dest)
          put.name = kv.first.second;
      put.block.assign(mem.at(block, kBlock), mem.at(block, kBlock) + kBlock);
      put.before.assign(mem.at(dest, size), mem.at(dest, size) + size);
      puts.push_back(put);
      std::memcpy(mem.at(dest, size), mem.at(src, size), size);
      return;
    }
    assert(donors.count(src) && donors[src] == t && constructs == copies + 1);
    std::memcpy(mem.at(dest, size), mem.at(src, size), size);
    ++copies;
  }
  // SB's AddRow: our block copied into a row of its own, RowMap and (with an ID) the ID map filled.
  void add(uint64_t add_row, uint64_t table, uint64_t n, uint64_t row) {
    assert(add_row == rebased(kAddRow) && row == block);
    size_t t = 0;
    while (tables[t] != table)
      ++t;
    adds.push_back({t, n, std::vector<uint8_t>(mem.at(block, kBlock), mem.at(block, kBlock) + kBlock)});
    const TableInfo &info = table_info(Table(t));
    const uint64_t copy = mem.alloc(info.size);
    std::memcpy(mem.at(copy, info.size), mem.at(block, info.size), info.size);
    rows[{table, n}] = copy;
    if (info.id)
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
         rows_of(Table::item) == 2 && rows_of(Table::consumable) == 1 && rows_of(Table::projectile) == 0);
  // The Gardener's batch: ToxicBeam's 3 steps, 3 skills and their commands, its stance, 3 CharacterTable rows.
  static_assert(kGardenerRows == 13, "the Gardener's 13 rows");
  assert(coop::lion::rows_of(kGardener, Table::step) == 3 && coop::lion::rows_of(kGardener, Table::skill) == 3 &&
         coop::lion::rows_of(kGardener, Table::command) == 3 && coop::lion::rows_of(kGardener, Table::stance) == 1 &&
         coop::lion::rows_of(kGardener, Table::character) == 3);
  // The Tendril's batch: 11 skills with their commands and 45 steps, 28 target filters, 5 results, its turn, 2 anim
  // sets, its stance, its dead, appearance and CharacterTable rows.
  static_assert(kTendrilRows == 107, "the Tendril's 107 rows");
  {
    const auto of = [](Table t) { return coop::lion::rows_of(kTendril, t); };
    assert(of(Table::step) == 45 && of(Table::skill) == 11 && of(Table::command) == 11 && of(Table::filter) == 28 &&
           of(Table::result) == 5 && of(Table::move) == 1 && of(Table::anim) == 2 && of(Table::stance) == 1 &&
           of(Table::dead) == 1 && of(Table::appearance) == 1 && of(Table::character) == 1);
  }
  // The Shock Bolt's batch: its 4 rows alone, so none of them stands in front of a Lion row, and the lion rows batch
  // goes into no ProjectileTable.
  static_assert(kBoltRows == 4, "the Shock Bolt's 4 rows");
  // The Night Operation shop's batch: the Beta Seed's item first (the shop items and shops name it), the two ShopTable
  // rows last, once every row they name is in.
  static_assert(kShopRows == 6, "the Night Operation shop's 6 rows");
  {
    const Table kShopTables[] = {Table::item,     Table::shopitem, Table::shopitem,
                                 Table::shopitem, Table::shop,     Table::shop};
    const uint32_t kShopIds[] = {9011, 3571, 3572, 3573, 1061, 1062};
    for (size_t i = 0; i < kShopRows; ++i)
      assert(kShopRecipe[i].table == kShopTables[i] && kShopRecipe[i].id == kShopIds[i]);
    assert(!std::strcmp(kShopRecipe[0].name, "Money_NightOperation") &&
           !std::strcmp(kShopRecipe[4].name, "Shop_NightOperation_Coop") &&
           !std::strcmp(kShopRecipe[5].name, "Shop_NightOperation_CoopBolt") &&
           !std::strcmp(kShopRecipe[5].donor, "Shop_NightOperation"));
  }
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
  // Its CharacterTable row last, M_TendrilC (50060).
  assert(kTendrilRecipe[kTendrilRows - 1].table == Table::character &&
         !std::strcmp(kTendrilRecipe[kTendrilRows - 1].name, "M_TendrilC") &&
         kTendrilRecipe[kTendrilRows - 1].id == 50060);
  std::vector<Row> all(kRecipe, kRecipe + kRows); // Every batch, in kPatches' order.
  all.insert(all.end(), kGardenerRecipe, kGardenerRecipe + kGardenerRows);
  all.insert(all.end(), kTendrilRecipe, kTendrilRecipe + kTendrilRows);
  all.insert(all.end(), kBoltRecipe, kBoltRecipe + kBoltRows);
  all.insert(all.end(), kShopRecipe, kShopRecipe + kShopRows);
  for (size_t t = 0; t < kTableCount; ++t) { // Names and IDs unique in each table across the batches.
    std::set<std::string> names;
    std::set<uint32_t> ids;
    for (const Row &r : all)
      if (size_t(r.table) == t) {
        assert(names.insert(r.name).second);
        assert(table_info(Table(t)).id ? r.id && ids.insert(r.id).second : r.id == 0);
        assert(std::strcmp(r.name, r.donor) != 0);
      }
  }
  size_t patches = 0;
  for (const Row &r : all) {
    const TableInfo &info = table_info(r.table);
    // The zone tables are Matrix XIII's alone.
    assert(r.table != Table::camp && r.table != Table::env && r.table != Table::trigger);
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
    const TableInfo &info = table_info(Table(t));
    assert(info.name && info.size && info.size <= kRowBytes);
    for (uint16_t at : info.transient)
      assert(!at || (at >= kIdAt + 4 && at + 16u <= info.size));
  }
  assert(!std::strcmp(table_info(Table::camp).name, "ZoneCampTable") && table_info(Table::camp).size == 0xa8 &&
         !std::strcmp(table_info(Table::env).name, "ZoneEnvSpawnTable") && table_info(Table::env).size == 0x508);
  assert(!std::strcmp(table_info(Table::trigger).name, "ZoneTriggerTable") && table_info(Table::trigger).size == 0xa8 &&
         table_info(Table::trigger).id && size_t(Table::trigger) == kTableCount - 1);
  // Matrix XIII's batch, by hand with patches of its own: the camp (a copy of ME01_Camp_03, FullCamp, its
  // CampDisplayType WhenActive left as copied, the coin's spawn point at +0x60), then 7 env-spawn rows whose TargetCamp
  // (+0x270) names it, each under its own actor name (+0x30): DLC02_10_EnvS_900 first (a copy of the activation-only
  // DLC02_10_EnvS_425, no actor), then the kit 901 to 906 (copies of 420 to 424 and 426), each spawning a blueprint
  // under /Game/GameDesign/Level/ZoneEnv/ (EnvBPPath +0x38) at the spawn point of its own name (+0x48); the vending
  // machine last, linking the five kit objects, not 900 (LinkEnvSpawnList +0x260). Then zone 30's camp with no kit or
  // coin (a copy of ME03_Camp_03) and its one env-spawn row, DLC02_10_EnvS_900's recipe with ZoneList (+0x20)
  // Zone_DLC02_30. Then 5 shipped ZoneTriggerTable rows patched in place, each its own template under its shipped ID,
  // in a table with no Transient array: DLC02_20_ZTrigger_001, 005 and 006 touch their wave's zone events after the
  // events they ship with (TouchEvents +0x20), DLC02_40_ZTrigger_001 and 002 start enabled (InitActivate +0x1c, 1).
  // Names and IDs unique, each patch inside its struct past the ID, no two on the same bytes.
  static_assert(kMxiiiRows == 15, "the camp, its 7 env-spawn rows, zone 30's camp and its row, 5 shipped trigger rows");
  {
    const Row &camp = kMxiiiRecipe[0], &first = kMxiiiRecipe[1], &vending = kMxiiiRecipe[7];
    const Row &camp30 = kMxiiiRecipe[8], &env30 = kMxiiiRecipe[9];
    assert(kMxiii.patches == kMxiiiPatches && kLion.patches == kPatches && kBolt.patches == kPatches &&
           kShop.patches == kPatches);
    assert(camp.table == Table::camp && !std::strcmp(camp.name, "DLC02_10_Camp_01") &&
           !std::strcmp(camp.donor, "ME01_Camp_03") && camp.id == 280001);
    assert(!std::strcmp(first.name, "DLC02_10_EnvS_900") && !std::strcmp(first.donor, "DLC02_10_EnvS_425") &&
           first.id == 2800032900u);
    static const char *const kDonors[] = {"DLC02_10_EnvS_420", "DLC02_10_EnvS_421", "DLC02_10_EnvS_422",
                                          "DLC02_10_EnvS_423", "DLC02_10_EnvS_424", "DLC02_10_EnvS_426"};
    std::set<std::string> names;
    std::set<uint32_t> ids;
    size_t n = 0;
    for (size_t i = 0; i < kMxiiiRows; ++i) {
      const Row &r = kMxiiiRecipe[i];
      const TableInfo &info = table_info(r.table);
      assert(r.first == n && r.count > 0 && info.id && r.id && names.insert(r.name).second && ids.insert(r.id).second);
      assert(shipped_row(r) == (i >= 10) && (r.table == Table::trigger) == (i >= 10));
      assert(i == 0 || i >= 8 ||
             (r.table == Table::env && r.id == 2800032900u + (i - 1) && (i == 1 || !std::strcmp(r.donor, kDonors[i - 2]))));
      for (uint16_t at : info.transient)
        assert(!shipped_row(r) || !at); // Patched in place only where no parsed copy can go stale.
      n += r.count;
      for (size_t p = r.first; p < size_t(r.first) + r.count; ++p) {
        const Patch &x = kMxiiiPatches[p];
        assert(x.at >= kIdAt + 4 && x.at + kind_size(x.kind) <= info.size);
        for (size_t q = r.first; q < p; ++q)
          assert(kMxiiiPatches[q].at + kind_size(kMxiiiPatches[q].kind) <= x.at ||
                 x.at + kind_size(x.kind) <= kMxiiiPatches[q].at);
      }
    }
    assert(n == sizeof kMxiiiPatches / sizeof kMxiiiPatches[0] && n == 38);
    const auto find = [](const Row &r, uint16_t offset) -> const Patch * {
      for (size_t p = r.first; p < size_t(r.first) + r.count; ++p)
        if (kMxiiiPatches[p].at == offset)
          return &kMxiiiPatches[p];
      return nullptr;
    };
    const auto at = [&find](const Row &r, uint16_t offset) -> const Patch & {
      const Patch *p = find(r, offset);
      assert(p);
      return *p;
    };
    assert(camp.count == 2 && at(camp, 0x28).kind == Kind::u8 && at(camp, 0x28).f == 3); // CampType FullCamp.
    assert(at(camp, 0x60).kind == Kind::name && !std::strcmp(at(camp, 0x60).text, "DLC02_10_E_ItemS_001"));
    assert(!find(camp, 0x6c)); // CampDisplayType stays the template's WhenActive.
    assert(first.count == 2 && !find(first, 0x38) && !find(first, 0x48));
    for (size_t i = 1; i < 8; ++i) {
      const Row &r = kMxiiiRecipe[i];
      assert(at(r, 0x270).kind == Kind::name && !std::strcmp(at(r, 0x270).text, camp.name));
      assert(at(r, 0x30).kind == Kind::name && !std::strcmp(at(r, 0x30).text, r.name));
      if (i == 1)
        continue;
      const char *path = at(r, 0x38).text;
      assert(at(r, 0x38).kind == Kind::string && !std::strncmp(path, "/Game/GameDesign/Level/ZoneEnv/", 31) &&
             !std::strcmp(path + std::strlen(path) - 2, "_C"));
      assert(at(r, 0x48).kind == Kind::name && !std::strcmp(at(r, 0x48).text, r.name));
      assert(r.count == (&r == &vending ? 5 : 4));
    }
    assert(at(vending, 0x260).kind == Kind::names &&
           !std::strcmp(at(vending, 0x260).text, "DLC02_10_EnvS_901|DLC02_10_EnvS_902|DLC02_10_EnvS_903|"
                                                 "DLC02_10_EnvS_904|DLC02_10_EnvS_905"));
    // Zone 30's camp: a FullCamp with no coin, and one row that leads the travel to Zone_DLC02_30 and names it.
    assert(camp30.table == Table::camp && !std::strcmp(camp30.name, "DLC02_30_Camp_01") &&
           !std::strcmp(camp30.donor, "ME03_Camp_03") && camp30.id == 281001 && camp30.count == 1 &&
           at(camp30, 0x28).kind == Kind::u8 && at(camp30, 0x28).f == 3 && !find(camp30, 0x60));
    assert(env30.table == Table::env && !std::strcmp(env30.name, "DLC02_30_EnvS_900") &&
           !std::strcmp(env30.donor, first.donor) && env30.id == 2810032900u && env30.count == 3);
    assert(at(env30, 0x20).kind == Kind::names && !std::strcmp(at(env30, 0x20).text, "Zone_DLC02_30") &&
           !std::strcmp(at(env30, 0x30).text, env30.name) && !std::strcmp(at(env30, 0x270).text, camp30.name));
    static const char *const kTriggers[] = {"DLC02_20_ZTrigger_001", "DLC02_20_ZTrigger_005", "DLC02_20_ZTrigger_006",
                                            "DLC02_40_ZTrigger_001", "DLC02_40_ZTrigger_002"};
    static const uint32_t kTriggerIds[] = {280501001, 280501005, 280501006, 281501001, 281501002};
    static const char *const kTouch[] = {
        "DLC02_20_ZoneE_022|DLC02_20_ZoneE_023|DLC02_20_ZoneE_024|DLC02_20_ZoneE_025",
        "DLC02_20_E_EnvC_030|DLC02_20_ZoneE_026|DLC02_20_ZoneE_027|DLC02_20_ZoneE_028",
        "DLC02_20_E_EnvC_031|DLC02_20_ZoneE_029|DLC02_20_ZoneE_030|DLC02_20_ZoneE_031|DLC02_20_ZoneE_032"};
    for (size_t i = 10; i < kMxiiiRows; ++i) {
      const Row &r = kMxiiiRecipe[i];
      assert(!std::strcmp(r.name, kTriggers[i - 10]) && r.id == kTriggerIds[i - 10] && r.count == 1);
      if (i < 13)
        assert(at(r, 0x20).kind == Kind::names && !std::strcmp(at(r, 0x20).text, kTouch[i - 10]));
      else
        assert(at(r, 0x1c).kind == Kind::u8 && at(r, 0x1c).f == 1); // ESBObject_Enable; shipped 2, Disable.
    }
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
  // The Shock Bolt's own batch, the item first: Bullet_Shock (32) over its consumable and bullet (+0x14c, +0x180) with
  // its own cap (MaxAmount +0x84) and no stat override (+0x88, +0x90), the skill (1003401) on SB's shipped Shock steps
  // with no acquisition (+0x17c), the projectile (1010051) with the shock blueprint (ResourcePath +0x18) and its own
  // hit result (+0xcc), the result (100200801) with SB's shock stun (+0x28).
  {
    const char *const kShock[] = {"Bullet_Shock", "P_Eve_Gun_ShootShockSlug1_1",
                                  "P_Eve_Gun_ShootShockSlug1_Projectile1",
                                  "P_Eve_Gun_ShootShockSlug1_Projectile1_Hit1"};
    const Table kShockTables[] = {Table::item, Table::skill, Table::projectile, Table::result};
    const uint32_t kShockIds[] = {32, 1003401, 1010051, 100200801};
    for (size_t i = 0; i < 4; ++i)
      assert(kBoltRecipe[i].table == kShockTables[i] && !std::strcmp(kBoltRecipe[i].name, kShock[i]) &&
             kBoltRecipe[i].id == kShockIds[i]);
    const Row &item = kBoltRecipe[0], &skill = kBoltRecipe[1], &shot = kBoltRecipe[2], &hit = kBoltRecipe[3];
    assert(!std::strcmp(patched(item, 0x14c), "Bullet_Shock_Consume") &&
           !std::strcmp(patched(item, 0x180), "Bullet_Shock") && value(item, 0x84) == 30 && value(item, 0x88) == 0 &&
           value(item, 0x90) == 0);
    assert(!std::strcmp(patched(skill, 0x100), "P_Eve_Gun_ShootShockSlug1_1_Cast1") &&
           !std::strcmp(patched(skill, 0x17c), "None"));
    assert(!std::strcmp(patched(shot, 0x18),
                        "/Game/Art/Character/PC/CH_P_EVE_01/Projectile/P_Eve_Gun_ShootShockSlug1_Projectile1") &&
           !std::strcmp(patched(shot, 0xcc), hit.name));
    assert(std::strstr(patched(hit, 0x28), "{\"Alias\":\"ShockSlugStun\"}"));
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
  // The Tendril's: each skill (MeleeAttack +0x80, its own first step +0x100 and range +0xb4) starts a step chain whose
  // first step plays its run-time Show (ShowPath +0x160: the mod's own package, a dot, the Show cut/tendril.lua
  // builds) and turns it toward EVE (SelfMoveAliasArray +0x138), and whose Hit steps hit through a target filter
  // (HitDetectionType +0x1a5, 1) of their own (OverrideTargetFilterAlias +0x1b4). Each command's skill (+0x18) is its
  // own; the stance (+0x90) lists the 11 in order. The dead row plays the run-time death Show (+0x10), the
  // CharacterTable row names its stance, dead row and appearance (+0x3a8, +0x298, +0x420), the Skulling test tree
  // (+0x3e8), 64960 HP (+0x78), immunity to the states it has no anim set for (+0x220), no link flag (+0x60) and no
  // name
  // (+0x508).
  {
    const auto has_t = [](Table t, const char *name) {
      for (const Row &r : kTendrilRecipe)
        if (r.table == t && !std::strcmp(r.name, name))
          return true;
      return false;
    };
    const auto at = [](const char *name, Table t) -> const Row & {
      return kTendrilRecipe[row_index(name, t, kTendril)];
    };
    const std::string kShows = "StellarCoop/Tendril.";
    std::string commands;
    size_t hits = 0;
    for (const Row &skill : kTendrilRecipe) {
      if (skill.table != Table::skill)
        continue;
      assert(!std::strcmp(patched(skill, 0x80), "MeleeAttack") && has_t(Table::filter, patched(skill, 0xb4)));
      const Row *step = &at(patched(skill, 0x100), Table::step);
      assert(patched(*step, 0x160) == kShows + skill.name && !std::strcmp(patched(*step, 0x138), "M_TendrilC_Turn") &&
             has_t(Table::move, "M_TendrilC_Turn"));
      for (const char *next = patched(*step, 0x34);; next = patched(*step, 0x34)) {
        if (value(*step, 0x14) == 1) { // A Hit step.
          ++hits;
          assert(value(*step, 0x1a5) == 1 && has_t(Table::filter, patched(*step, 0x1b4)) &&
                 std::strstr(patched(*step, 0x1b4), "_HitArea"));
        }
        if (!next)
          break;
        step = &at(next, Table::step);
        assert(!patched(*step, 0x160)); // Only the first step plays the Show, across the chain.
      }
      const Row &command = at(skill.name, Table::command);
      assert(command.id == skill.id && !std::strcmp(patched(command, 0x18), skill.name));
      commands += (commands.empty() ? "" : "|") + std::string(skill.name);
    }
    assert(hits == 17 && commands == patched(at("M_TendrilC_Default", Table::stance), 0x90));
    assert(patched(at("M_TendrilC", Table::dead), 0x10) == kShows + "M_TendrilC_Dead");
    const Row &c = kTendrilRecipe[kTendrilRows - 1];
    assert(!std::strcmp(patched(c, 0x3a8), "M_TendrilC_Default") && !std::strcmp(patched(c, 0x298), "M_TendrilC") &&
           !std::strcmp(patched(c, 0x420), "M_TendrilC") && std::strstr(patched(c, 0x3e8), "M_Skulling_AI_Test") &&
           value(c, 0x78) == 64960 && std::strstr(patched(c, 0x220), "M_Common_ImmuneAbnormal") &&
           !std::strcmp(patched(c, 0x60), "") && !std::strcmp(patched(c, 0x508), ""));
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
  // donor's. Each shipped row (from its first put) as copied back over itself: in order, its flag and ID as shipped,
  // each patch as written, every other byte as the row held before, and the row now the block.
  const auto verify = [](Game &g, const Builder &b, const Batch &batch, size_t from, size_t put = 0) {
    for (size_t i = 0, added = 0; i < batch.count; ++i) {
      const Row &r = batch.rows[i];
      const TableInfo &info = table_info(r.table);
      const bool shipped = shipped_row(r);
      const Game::Add &add = shipped ? static_cast<const Game::Add &>(g.puts[put]) : g.adds[from + added];
      // In order, to its table, under its new name; SB's flag back to 0, its ID, the Transient arrays empty.
      assert(add.table == size_t(r.table) && g.name_text(add.name) == r.name && b.added(i));
      assert(add.block[kInitFlag] == (shipped ? 1 : 0));
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
        const Patch &x = batch.patches[p];
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
      if (shipped) {
        const Game::Put &p = g.puts[put++];
        assert(p.row == donor && !std::memcmp(g.mem.at(donor, info.size), p.block.data(), info.size));
        for (size_t k = 0; k < info.size; ++k)
          assert(touched[k] || add.block[k] == p.before[k]);
        continue;
      }
      ++added;
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

    // The Tendril's batch after both, on its own Builder: its 107 rows, none of them meeting another; SB's lookups find
    // its CharacterTable row, its 11 skills and its stance.
    Builder tb(kTendril);
    const Answer ta = tb.run(g, kBase, g.tables, g.block);
    const size_t before = kRows + kGardenerRows;
    assert(ta.state == State::rows && ta.added == kTendrilRows && g.adds.size() == before + kTendrilRows);
    verify(g, tb, kTendril, before);
    const Game::Add &tendril = g.adds[before + kTendrilRows - 1];
    assert(Game::field<int32_t>(tendril, 0x78) == 64960 && Game::field<uint32_t>(tendril, kIdAt) == 50060 &&
           g.string_field(tendril, 0x508).empty());
    rb = tb.read_back(g, g.tables);
    assert(rb.character == 1 && rb.skills == 11 && rb.stance == 1);
    assert(describe_read(kTendril, rb) == "tendril rows by SB's lookups: CharacterTable 50060 1/1, SkillTable "
                                          "5006000-5006010 11/11, stance 500600 1/1");

    // The Shock Bolt's batch last, on its own Builder: its 4 rows; SB's lookups find its one skill, and the line names
    // no ID for the tables it has no row in.
    Builder ob(kBolt);
    const Answer oa = ob.run(g, kBase, g.tables, g.block);
    const size_t bolts = before + kTendrilRows;
    assert(oa.state == State::rows && oa.added == kBoltRows && g.adds.size() == bolts + kBoltRows);
    verify(g, ob, kBolt, bolts);
    assert(Game::field<int32_t>(g.adds[bolts], 0x84) == 30 &&
           Game::field<uint32_t>(g.adds[bolts + 2], kIdAt) == 1010051);
    rb = ob.read_back(g, g.tables);
    assert(rb.character == 0 && rb.skills == 1 && rb.stance == 0);
    assert(describe_read(kBolt, rb) ==
           "bolt rows by SB's lookups: CharacterTable - 0/0, SkillTable 1003401 1/1, stance - 0/0");

    // Matrix XIII's batch after them all, on its own Builder: its 10 new rows from its own patches, into the two zone
    // tables only it reads, the camp first; its IDs above 2^31 go in whole, and every zone 10 env-spawn row names the
    // camp, the vending machine with its blueprint path and its 5 links (901 to 905, not 900); zone 30's camp and its
    // row in Zone_DLC02_30. Then its 5 shipped trigger rows, each copied back over itself and never handed to AddRow,
    // so the ID map still names each and RowMap still holds it at its address. SB's lookups by ID have nothing of it to
    // find.
    Builder mb(kMxiii);
    const Answer ma = mb.run(g, kBase, g.tables, g.block);
    const size_t zone = bolts + kBoltRows, kNew = 10;
    assert(ma.state == State::rows && ma.added == kMxiiiRows && g.adds.size() == zone + kNew &&
           g.puts.size() == kMxiiiRows - kNew);
    verify(g, mb, kMxiii, zone);
    for (size_t i = kNew; i < kMxiiiRows; ++i) {
      const Row &r = kMxiiiRecipe[i];
      const uint64_t table = g.tables[size_t(Table::trigger)], name = g.name(r.name);
      assert(g.puts[i - kNew].table == size_t(Table::trigger) && g.id_name(table, r.id) == name &&
             g.find(table, name) == g.puts[i - kNew].row);
    }
    assert(g.list_field(g.puts[0], 0x20, Kind::names) ==
               "DLC02_20_ZoneE_022|DLC02_20_ZoneE_023|DLC02_20_ZoneE_024|DLC02_20_ZoneE_025" &&
           g.puts[3].block[0x1c] == 1 && g.puts[4].block[0x1c] == 1);
    assert(g.adds[zone].table == size_t(Table::camp) &&
           g.name_text(Game::field<uint64_t>(g.adds[zone], 0x60)) == "DLC02_10_E_ItemS_001");
    for (size_t i = 1; i < 8; ++i)
      assert(g.adds[zone + i].table == size_t(Table::env) &&
             Game::field<uint32_t>(g.adds[zone + i], kIdAt) == 2800032900u + (i - 1) &&
             g.name_text(Game::field<uint64_t>(g.adds[zone + i], 0x270)) == "DLC02_10_Camp_01");
    const Game::Add &machine = g.adds[zone + 7];
    assert(g.string_field(machine, 0x38) == "/Game/GameDesign/Level/ZoneEnv/Env_VendingMachine.Env_VendingMachine_C" &&
           g.name_text(Game::field<uint64_t>(machine, 0x48)) == "DLC02_10_EnvS_906" &&
           g.list_field(machine, 0x260, Kind::names) ==
               "DLC02_10_EnvS_901|DLC02_10_EnvS_902|DLC02_10_EnvS_903|DLC02_10_EnvS_904|DLC02_10_EnvS_905");
    assert(g.id_name(g.tables[size_t(Table::env)], 2800032900u) == g.name("DLC02_10_EnvS_900") &&
           g.id_name(g.tables[size_t(Table::env)], 2800032906u) == g.name("DLC02_10_EnvS_906"));
    const Game::Add &camp30 = g.adds[zone + 8], &env30 = g.adds[zone + 9];
    assert(camp30.table == size_t(Table::camp) && Game::field<uint32_t>(camp30, kIdAt) == 281001 &&
           camp30.block[0x28] == 3 && g.id_name(g.tables[size_t(Table::camp)], 281001) == g.name("DLC02_30_Camp_01"));
    assert(env30.table == size_t(Table::env) && Game::field<uint32_t>(env30, kIdAt) == 2810032900u &&
           g.list_field(env30, 0x20, Kind::names) == "Zone_DLC02_30" &&
           g.name_text(Game::field<uint64_t>(env30, 0x30)) == "DLC02_30_EnvS_900" &&
           g.name_text(Game::field<uint64_t>(env30, 0x270)) == "DLC02_30_Camp_01");
    rb = mb.read_back(g, g.tables);
    assert(rb.character == 0 && rb.skills == 0 && rb.stance == 0);
    assert(describe(kMxiii, ma) == "mxiii rows: 15/15 in, 10 added through SB's AddRow 0x14417ba30 and 5 shipped "
                                   "rows patched in place, 0 refused");
    assert(describe_read(kMxiii, rb) ==
           "mxiii rows by SB's lookups: CharacterTable - 0/0, SkillTable - 0/0, stance - 0/0");
    assert(mb.run(g, kBase, g.tables, g.block).added == kMxiiiRows && g.adds.size() == zone + kNew &&
           g.puts.size() == kMxiiiRows - kNew); // A later run patches nothing again.
    // The Night Operation shop's batch after Matrix XIII's, on its own Builder: its 6 rows; the Beta Seed caps at 999999
    // (MaxAmount +0x84) with its own text key (Name +0x30) and no drop pool (+0x7e), the shop items price in it
    // (MoneyItemAlias1 +0x2c, count +0x34), and the two shops list their goods (ShopItems +0x38) with no tag (Tags
    // +0x28) and the seed as currency (+0x20).
    Builder sb(kShop);
    const Answer sa = sb.run(g, kBase, g.tables, g.block);
    const size_t shops = zone + kNew;
    assert(sa.state == State::rows && sa.added == kShopRows && g.adds.size() == shops + kShopRows);
    verify(g, sb, kShop, shops);
    const Game::Add &seed = g.adds[shops], &stim = g.adds[shops + 1], &coop = g.adds[shops + 4],
                    &with_bolt = g.adds[shops + 5];
    assert(seed.table == size_t(Table::item) && Game::field<int32_t>(seed, 0x84) == 999999 &&
           g.string_field(seed, 0x30) == "Item_Money_NightOperation_Name" && Game::field<uint8_t>(seed, 0x7e) == 0);
    assert(stim.table == size_t(Table::shopitem) &&
           g.name_text(Game::field<uint64_t>(stim, 0x18)) == "HP2Burst_Potion" &&
           g.name_text(Game::field<uint64_t>(stim, 0x2c)) == "Money_NightOperation" &&
           Game::field<int32_t>(stim, 0x34) == 20);
    assert(coop.table == size_t(Table::shop) && Game::field<uint32_t>(coop, kIdAt) == 1061 &&
           g.name_text(Game::field<uint64_t>(coop, 0x20)) == "Money_NightOperation" &&
           g.list_field(coop, 0x28, Kind::names).empty() &&
           g.list_field(coop, 0x38, Kind::names) ==
               "NightOperation_HP_Potion_Buy|NightOperation_HP_Potion_Small_Buy|NightOperation_PulseGrenade_Buy|"
               "NightOperation_ConcussionGrenade_Buy|NightOperation_HP2Burst_Potion_Buy|NightOperation_Buff_HP2MP_Buy");
    assert(g.list_field(with_bolt, 0x38, Kind::names) ==
           g.list_field(coop, 0x38, Kind::names) + "|NightOperation_Bullet_Shock_Buy");
    rb = sb.read_back(g, g.tables);
    assert(describe_read(kShop, rb) ==
           "shop rows by SB's lookups: CharacterTable - 0/0, SkillTable - 0/0, stance - 0/0");
  }
  {
    // Matrix XIII's run reads only the three zone tables: a ZoneEnvSpawnTable whose row size is not the SDK's stops it
    // before any row and names that table, and the Lion's batch, which never reads it, goes on. A camp ID already taken
    // stops it at the camp.
    Game g;
    const uint64_t rs = g.mem.get<uint64_t>(g.tables[size_t(Table::env)] + kRowStruct);
    g.mem.put<int32_t>(rs + kPropertiesSize, 0x500);
    Builder mb(kMxiii), lb(kLion);
    const Answer a = mb.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::size && a.detail == 0x500 && g.adds.empty());
    assert(describe(kMxiii, a) ==
           "mxiii rows refused DLC02_10_EnvS_900: ZoneEnvSpawnTable's row size 0x500 not 0x508; 0/15 added");
    Status s;
    s.word = pack(a, 1);
    assert(status_line(kMxiii, s) == "mxiii=refused added=0/15 asks=1 spawns=? why=size table=ZoneEnvSpawnTable "
                                     "row=DLC02_10_EnvS_900 detail=0x500");
    assert(lb.run(g, kBase, g.tables, g.block).state == State::rows && g.adds.size() == kRows);
    Game h;
    h.ids[{h.tables[size_t(Table::camp)], 280001}] = h.name("SomeOtherCamp");
    Builder hb(kMxiii);
    const Answer b = hb.run(h, kBase, h.tables, h.block);
    assert(b.state == State::refused && b.why == Why::id && b.row == 0 && h.adds.empty());
    assert(describe(kMxiii, b) == "mxiii rows refused DLC02_10_Camp_01: ID 280001 taken; 0/15 added");
  }
  {
    // The shipped trigger rows: a ZoneTriggerTable whose row size is not the SDK's stops Matrix XIII's run before any
    // row, and the Lion's, which never reads it, goes on.
    Game g;
    const uint64_t rs = g.mem.get<uint64_t>(g.tables[size_t(Table::trigger)] + kRowStruct);
    g.mem.put<int32_t>(rs + kPropertiesSize, 0xa0);
    Builder mb(kMxiii), lb(kLion);
    const Answer a = mb.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::size && a.row == 10 && g.adds.empty() && g.puts.empty());
    assert(describe(kMxiii, a) ==
           "mxiii rows refused DLC02_20_ZTrigger_001: ZoneTriggerTable's row size 0xa0 not 0xa8; 0/15 added");
    assert(lb.run(g, kBase, g.tables, g.block).state == State::rows && g.adds.size() == kRows && g.puts.empty());
  }
  {
    // A shipped row missing (from RowMap and the ID map, as SB's AddRow fills both) stops the run at it, the rows
    // before it in, and nothing is added under its name; once it is there, a later run patches it and only it.
    Game g;
    const uint64_t table = g.tables[size_t(Table::trigger)], key = g.name("DLC02_40_ZTrigger_002");
    const uint64_t row = g.rows[{table, key}];
    g.rows.erase({table, key});
    g.ids.erase({table, 281501002});
    Builder mb(kMxiii);
    Answer a = mb.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::donor && a.row == 14 && a.added == 14 && g.adds.size() == 10 &&
           g.puts.size() == 4);
    assert(describe(kMxiii, a) ==
           "mxiii rows refused DLC02_40_ZTrigger_002: no shipped row of that name in ZoneTriggerTable; 14/15 added");
    g.rows[{table, key}] = row;
    g.ids[{table, 281501002}] = key;
    a = mb.run(g, kBase, g.tables, g.block);
    assert(a.state == State::rows && a.added == kMxiiiRows && g.adds.size() == 10 && g.puts.size() == 5 &&
           g.puts[4].row == row);
  }
  {
    // A shipped row whose ID the ID map gives to another row, or to none, is not the row the patch was written for.
    Game g;
    const uint64_t table = g.tables[size_t(Table::trigger)];
    g.ids[{table, 280501001}] = g.name("SomeOtherTrigger");
    Builder mb(kMxiii);
    Answer a = mb.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::id && a.row == 10 && g.adds.size() == 10 && g.puts.empty());
    assert(describe(kMxiii, a) ==
           "mxiii rows refused DLC02_20_ZTrigger_001: ID 280501001 does not name it; 10/15 added");
    g.ids.erase({table, 280501001});
    a = mb.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::id && a.row == 10 && g.puts.empty());
  }
  {
    // A ShopTable whose row size is not the SDK's stops the shop's batch before any row (every table it uses is
    // checked first); the Lion's never reads it.
    Game g;
    const uint64_t rs = g.mem.get<uint64_t>(g.tables[size_t(Table::shop)] + kRowStruct);
    g.mem.put<int32_t>(rs + kPropertiesSize, 0xa0);
    Builder sb(kShop), lb(kLion);
    const Answer a = sb.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::size && a.detail == 0xa0 && a.row == 4 && g.adds.empty());
    assert(describe(kShop, a) ==
           "shop rows refused Shop_NightOperation_Coop: ShopTable's row size 0xa0 not 0xa8; 0/6 added");
    assert(lb.run(g, kBase, g.tables, g.block).state == State::rows && g.adds.size() == kRows);
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
    // A ProjectileTable whose row size is not the SDK's stops the Shock Bolt's batch only: the Lion's never reads it.
    Game g;
    const uint64_t rs = g.mem.get<uint64_t>(g.tables[size_t(Table::projectile)] + kRowStruct);
    g.mem.put<int32_t>(rs + kPropertiesSize, 0x390);
    Builder ob(kBolt), lb(kLion);
    const Answer a = ob.run(g, kBase, g.tables, g.block);
    assert(a.state == State::refused && a.why == Why::size && a.detail == 0x390 && g.adds.empty());
    assert(describe(kBolt, a) ==
           "bolt rows refused P_Eve_Gun_ShootShockSlug1_Projectile1: ProjectileTable's row size 0x390 not 0x398; "
           "0/4 added");
    assert(lb.run(g, kBase, g.tables, g.block).state == State::rows && g.adds.size() == kRows);
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
    // The Tendril's line: its word, its own counts.
    Status ts;
    assert(status_line(kTendril, ts) == "tendril=off");
    a = Answer(), a.state = State::rows, a.added = 107;
    ts.word = pack(a, 1), ts.read = {1, 11, 1}, ts.spawns_read = true, ts.spawns = 5;
    assert(status_line(kTendril, ts) == "tendril=rows added=107/107 asks=1 spawns=5 char=1/1 skills=11/11 stance=1/1");
    assert(describe(kTendril, a) == "tendril rows: 107/107 added through SB's AddRow 0x14417ba30, 0 refused");
    // The Shock Bolt's line: its word (the shock line is lion/shock.h's), its own counts, none of CharacterTable or
    // stance rows.
    Status bs;
    assert(status_line(kBolt, bs) == "bolt=off");
    a = Answer(), a.state = State::rows, a.added = 4;
    bs.word = pack(a, 1), bs.read = {0, 1, 0};
    assert(status_line(kBolt, bs) == "bolt=rows added=4/4 asks=1 spawns=? char=0/0 skills=1/1 stance=0/0");
    // Matrix XIII's line (cut/mxiii.lua reads it): no row SB's lookups by ID count.
    Status ms;
    assert(status_line(kMxiii, ms) == "mxiii=off");
    a = Answer(), a.state = State::rows, a.added = 15;
    ms.word = pack(a, 1);
    assert(status_line(kMxiii, ms) == "mxiii=rows added=15/15 asks=1 spawns=? char=0/0 skills=0/0 stance=0/0");
    // The Night Operation shop's line: its word, no CharacterTable, skill or stance row.
    Status ss;
    assert(status_line(kShop, ss) == "shop=off");
    a = Answer(), a.state = State::rows, a.added = 6;
    ss.word = pack(a, 2);
    assert(status_line(kShop, ss) == "shop=rows added=6/6 asks=2 spawns=? char=0/0 skills=0/0 stance=0/0");
  }

  std::puts("lion_rows_test: ok");
  return 0;
}
