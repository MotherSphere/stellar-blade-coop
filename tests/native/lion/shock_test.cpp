// The Shock Bolt's two lists on the build machine against fake memory laid out like the pinned build: both gun stances
// get the two fire commands at the end of their CommandArray (one through SB's grow, one inside its Max), the const
// list Bullet_Shock as a sixth FString (its array reallocated) and the slot manager's list its FName (SB's grow), the
// first entries untouched; a second run writes nothing; no slot manager yet; a stance that holds one fire command
// already gets the other; the key found down its hash chain; each refusal (no FName, no stance row, a wrong ID, a
// CommandArray, the const store or its map out of range, no key, a list or slot list that is not the five SB ships)
// writes nothing; an allocation that fails stops there; the answer word, the status line and the log line.
#include "lion/shock.h"

#include <algorithm>
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
constexpr uint32_t kKey = 0x0351259a; // Strihash_DEPRECATED("BulletItemSlotArray"), as worked out offline.

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

// One game: the image's two globals (the const store, the slot manager's holder), the two stance rows by FName with
// 22 commands each, the const store's string-array map with BulletItemSlotArray and one other array, the slot manager
// with its list, SB's grow and GMalloc over the fake memory, and FNames interned by text and number.
struct Game {
  Memory mem;
  std::map<std::pair<std::string, uint32_t>, uint32_t> interned;
  std::vector<std::string> texts{"None"};
  std::map<uint64_t, uint64_t> stances; // FName -> row
  uint64_t rows[2] = {}, consts = 0, buckets = 0, element = 0, other = 0, holder = 0, manager = 0;
  std::set<std::string> no_name;
  bool no_malloc = false;
  int writes = 0, grows = 0, mallocs = 0, reallocs = 0;

  explicit Game(int32_t gun_max = 22, int32_t block_max = 24) {
    mem.regions[rebased(kConsts)].assign(8, 0);
    mem.regions[rebased(kSlotsHolder)].assign(8, 0);
    for (size_t s = 0; s < 2; ++s) {
      rows[s] = mem.alloc(0x220);
      mem.put<uint32_t>(rows[s] + kIdAt, kGunStanceIds[s]);
      const int32_t max = s ? block_max : gun_max;
      const uint64_t data = mem.alloc(8 * size_t(max));
      for (int32_t i = 0; i < 22; ++i)
        mem.put<uint64_t>(data + 8 * uint64_t(i), name(("P_Eve_Gun_Command" + std::to_string(i)).c_str()));
      put_array(rows[s] + kCommandArray, data, 22, max);
      stances[name(kGunStances[s])] = rows[s];
    }
    // The string-array map: two elements, the other array first in the key's bucket, its next ours.
    consts = mem.alloc(0x698);
    mem.put<uint64_t>(rebased(kConsts), consts);
    const uint64_t elements = mem.alloc(2 * kArrayElement);
    mem.put<uint64_t>(consts + kArrays, elements);
    mem.put<int32_t>(consts + kArraysCount, 2);
    mem.put<int32_t>(consts + kArraysFree, 0);
    mem.put<int32_t>(consts + kArraysHashSize, 8); // Past the one inline bucket: on the heap.
    buckets = mem.alloc(4 * 8);
    mem.put<uint64_t>(consts + kArraysHashPointer, buckets);
    for (int32_t b = 0; b < 8; ++b)
      mem.put<int32_t>(buckets + 4 * uint64_t(b), -1);
    other = elements, element = elements + kArrayElement;
    mem.put<uint32_t>(other, kKey + 8); // Same bucket, another key.
    mem.put<int32_t>(other + kArrayNext, 1);
    mem.put<uint32_t>(element, kKey);
    mem.put<int32_t>(element + kArrayNext, -1);
    mem.put<int32_t>(buckets + 4 * uint64_t(kKey & 7), 0);
    const uint64_t list = mem.alloc(16 * 5);
    for (size_t i = 0; i < 5; ++i)
      put_string(list + 16 * i, kShippedBullets[i]);
    put_array(element + kArrayAt, list, 5, 5);
    // The slot manager and its list of FNames.
    holder = mem.alloc(0x2230);
    manager = mem.alloc(0x300);
    mem.put<uint64_t>(rebased(kSlotsHolder), holder);
    mem.put<uint64_t>(holder + kSlotManager, manager);
    const uint64_t slots = mem.alloc(8 * 5);
    for (size_t i = 0; i < 5; ++i)
      mem.put<uint64_t>(slots + 8 * i, name(kShippedBullets[i]));
    put_array(manager + kSlotList, slots, 5, 5);
  }
  void put_array(uint64_t at, uint64_t data, int32_t num, int32_t max) {
    mem.put<uint64_t>(at, data);
    mem.put<int32_t>(at + 8, num);
    mem.put<int32_t>(at + 12, max);
  }
  void put_string(uint64_t header, const char *text) {
    const size_t len = std::strlen(text);
    const uint64_t data = mem.alloc(2 * (len + 1));
    for (size_t k = 0; k < len; ++k)
      mem.put<uint16_t>(data + 2 * k, uint8_t(text[k]));
    put_array(header, data, int32_t(len + 1), int32_t(len + 1));
  }

  // rows.h's Game, the parts shock() uses.
  bool read(uint64_t address, void *out, size_t n) {
    const uint8_t *p = mem.at(address, n);
    if (p)
      std::memcpy(out, p, n);
    return p;
  }
  void write(uint64_t address, const void *in, size_t n) {
    uint8_t *p = mem.at(address, n);
    assert(p);
    std::memcpy(p, in, n);
    ++writes;
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
  uint64_t stance_row(uint64_t n) {
    const auto it = stances.find(n);
    return it == stances.end() ? 0 : it->second;
  }
  // SB's FUN_140e47f00: Max from Num (max(4, n) the first time, n + 3n/8 + 16 after), the data reallocated.
  void grow(uint64_t array) {
    ++grows;
    const int32_t num = mem.get<int32_t>(array + 8), max = mem.get<int32_t>(array + 12);
    const int32_t want = max == 0 ? (num > 4 ? num : 4) : num + 3 * num / 8 + 16;
    const uint64_t data = mem.alloc(8 * size_t(want)), old = mem.get<uint64_t>(array);
    if (old)
      std::memcpy(mem.at(data, 8 * size_t(max)), mem.at(old, 8 * size_t(max)), 8 * size_t(max));
    mem.put<uint64_t>(array, data);
    mem.put<int32_t>(array + 12, want);
  }
  uint32_t hash(const char *text) { return std::strcmp(text, kSlotArray) ? 0 : kKey; }
  uint64_t malloc(size_t n) {
    ++mallocs;
    return no_malloc ? 0 : mem.alloc(n);
  }
  uint64_t realloc(uint64_t p, size_t n) {
    ++reallocs;
    const uint64_t to = mem.alloc(n);
    auto r = mem.regions.find(p);
    assert(r != mem.regions.end());
    std::memcpy(mem.at(to, n), r->second.data(), std::min(n, r->second.size()));
    mem.regions.erase(r); // The old buffer is gone, as GMalloc's Realloc frees it.
    return to;
  }

  std::string name_text(uint64_t n) {
    const uint32_t number = uint32_t(n >> 32);
    return texts[uint32_t(n)] + (number ? "_" + std::to_string(number - 1) : std::string());
  }
  std::vector<std::string> commands(size_t s) {
    std::vector<std::string> out;
    const uint64_t data = mem.get<uint64_t>(rows[s] + kCommandArray);
    for (int32_t i = 0; i < mem.get<int32_t>(rows[s] + kCommandArray + 8); ++i)
      out.push_back(name_text(mem.get<uint64_t>(data + 8 * uint64_t(i))));
    return out;
  }
  std::string string_at(uint64_t header) {
    const uint64_t data = mem.get<uint64_t>(header);
    const int32_t num = mem.get<int32_t>(header + 8);
    assert(num == mem.get<int32_t>(header + 12) && mem.get<uint16_t>(data + 2 * uint64_t(num - 1)) == 0);
    std::string s;
    for (int32_t k = 0; k + 1 < num; ++k)
      s += char(mem.get<uint16_t>(data + 2 * uint64_t(k)));
    return s;
  }
  std::vector<std::string> list() {
    std::vector<std::string> out;
    const uint64_t data = mem.get<uint64_t>(element + kArrayAt);
    for (int32_t i = 0; i < mem.get<int32_t>(element + kArrayAt + 8); ++i)
      out.push_back(string_at(data + 16 * uint64_t(i)));
    return out;
  }
  std::vector<std::string> slots() {
    std::vector<std::string> out;
    const uint64_t data = mem.get<uint64_t>(manager + kSlotList);
    for (int32_t i = 0; i < mem.get<int32_t>(manager + kSlotList + 8); ++i)
      out.push_back(name_text(mem.get<uint64_t>(data + 8 * uint64_t(i))));
    return out;
  }
};

void refused(Game &g, ShockWhy why, ShockAt at) {
  const ShockAnswer a = shock(g, kBase);
  assert(a.state == ShockState::refused && a.why == why && a.at == at);
  assert(g.writes == 0 && g.grows == 0 && g.mallocs == 0 && g.reallocs == 0);
}
} // namespace

int main() {
  // ---- A whole run ----
  {
    Game g;
    const ShockAnswer a = shock(g, kBase);
    assert(a.state == ShockState::in && a.why == ShockWhy::none && a.added == 4);
    assert(a.commands[0] == 24 && a.commands[1] == 24 && a.list == 6 && a.slots == 6 && a.list_added &&
           a.slots_added);
    // P_Eve_Gun through SB's grow (Max 22), P_Eve_GunBlockSword inside its Max (24), the first 22 untouched.
    assert(g.grows == 2 && g.mem.get<int32_t>(g.rows[0] + kCommandArray + 12) == 24 + 24 * 3 / 8 + 16 &&
           g.mem.get<int32_t>(g.rows[1] + kCommandArray + 12) == 24);
    for (size_t s = 0; s < 2; ++s) {
      const std::vector<std::string> c = g.commands(s);
      assert(c.size() == 24 && c[0] == "P_Eve_Gun_Command0" && c[21] == "P_Eve_Gun_Command21" &&
             c[22] == "P_Eve_Gun_ShootShockSlug1_1" && c[23] == "P_Eve_Gun_ShootShockSlug1_2");
    }
    // The const list reallocated to 6, its sixth FString {text, 13, 13}; the slot manager's list through SB's grow.
    const std::vector<std::string> list = g.list();
    assert(list.size() == 6 && list[0] == "Bullet_Normal" && list[4] == "Bullet_Explosive" && list[5] == "Bullet_Shock");
    assert(g.reallocs == 1 && g.mallocs == 1 && g.mem.get<int32_t>(g.element + kArrayAt + 12) == 6);
    const std::vector<std::string> slots = g.slots();
    assert(slots.size() == 6 && slots[0] == "Bullet_Normal" && slots[5] == "Bullet_Shock");
    assert(shock_line(pack(a), "") == "shock=in commands=24,24 added=4 list=6 slots=6");
    assert(describe_shock(pack(a)) ==
           "shock bolt in: 4 fire commands added (P_Eve_Gun 24 commands, P_Eve_GunBlockSword 24), "
           "BulletItemSlotArray grown, 6 entries, the slot manager's list grown, 6 entries");
    // A second run finds everything in place and writes nothing.
    g.writes = g.grows = g.mallocs = g.reallocs = 0;
    const ShockAnswer again = shock(g, kBase);
    assert(again.state == ShockState::in && again.added == 0 && !again.list_added && !again.slots_added &&
           again.commands[0] == 24 && again.list == 6 && again.slots == 6);
    assert(g.writes == 0 && g.grows == 0 && g.mallocs == 0 && g.reallocs == 0);
    assert(describe_shock(pack(again)) ==
           "shock bolt in: 0 fire commands added (P_Eve_Gun 24 commands, P_Eve_GunBlockSword 24), "
           "BulletItemSlotArray kept, 6 entries, the slot manager's list kept, 6 entries");
  }
  // No slot manager yet: the const list only (the manager takes it when it starts).
  {
    Game g;
    g.mem.put<uint64_t>(rebased(kSlotsHolder), 0);
    const ShockAnswer a = shock(g, kBase);
    assert(a.state == ShockState::in && a.slots == 0 && !a.slots_added && a.list == 6 && g.slots().size() == 5);
    assert(shock_line(pack(a), "") == "shock=in commands=24,24 added=4 list=6 slots=-");
    assert(describe_shock(pack(a)) ==
           "shock bolt in: 4 fire commands added (P_Eve_Gun 24 commands, P_Eve_GunBlockSword 24), "
           "BulletItemSlotArray grown, 6 entries, the slot manager is not made yet and takes the list when it starts");
  }
  // A stance that holds one fire command already gets the other only; a list with room takes the text in place.
  {
    Game g(24, 24);
    const uint64_t data = g.mem.get<uint64_t>(g.rows[0] + kCommandArray);
    g.mem.put<uint64_t>(data + 8 * 22, g.name("P_Eve_Gun_ShootShockSlug1_2"));
    g.mem.put<int32_t>(g.rows[0] + kCommandArray + 8, 23);
    const uint64_t list = g.mem.alloc(16 * 8), old = g.mem.get<uint64_t>(g.element + kArrayAt);
    std::memcpy(g.mem.at(list, 16 * 5), g.mem.at(old, 16 * 5), 16 * 5);
    g.put_array(g.element + kArrayAt, list, 5, 8);
    const ShockAnswer a = shock(g, kBase);
    assert(a.state == ShockState::in && a.added == 3 && a.commands[0] == 24 && g.grows == 1 && g.reallocs == 0);
    const std::vector<std::string> c = g.commands(0);
    assert(c[22] == "P_Eve_Gun_ShootShockSlug1_2" && c[23] == "P_Eve_Gun_ShootShockSlug1_1");
    assert(g.mem.get<uint64_t>(g.element + kArrayAt) == list && g.list().size() == 6);
  }

  // ---- Refusals, nothing written ----
  {
    Game g;
    g.no_name.insert("P_Eve_Gun_ShootShockSlug1");
    refused(g, ShockWhy::fname, ShockAt::gun);
  }
  {
    Game g;
    g.stances.erase(g.name("P_Eve_GunBlockSword"));
    refused(g, ShockWhy::stance, ShockAt::block);
  }
  {
    Game g;
    g.mem.put<uint32_t>(g.rows[0] + kIdAt, 100105);
    refused(g, ShockWhy::id, ShockAt::gun);
  }
  {
    Game g;
    g.mem.put<int32_t>(g.rows[1] + kCommandArray + 8, 25); // Num past Max.
    refused(g, ShockWhy::commands, ShockAt::block);
  }
  {
    Game g;
    g.mem.put<uint64_t>(g.rows[0] + kCommandArray, 0x10001); // Data unmapped and unaligned.
    refused(g, ShockWhy::commands, ShockAt::gun);
  }
  {
    Game g;
    g.mem.put<uint64_t>(rebased(kConsts), 0);
    refused(g, ShockWhy::consts, ShockAt::list);
  }
  {
    Game g;
    g.mem.put<int32_t>(g.consts + kArraysHashSize, 6); // Not a power of two.
    refused(g, ShockWhy::consts, ShockAt::list);
  }
  {
    Game g;
    g.mem.put<int32_t>(g.other + kArrayNext, 7); // A chain past the elements.
    refused(g, ShockWhy::consts, ShockAt::list);
  }
  {
    Game g;
    g.mem.put<uint32_t>(g.element, kKey + 16); // No element of the key.
    refused(g, ShockWhy::key, ShockAt::list);
  }
  {
    Game g;
    g.mem.put<int32_t>(g.element + kArrayAt + 8, 4);
    refused(g, ShockWhy::list, ShockAt::list);
  }
  {
    Game g;
    g.put_string(g.mem.get<uint64_t>(g.element + kArrayAt) + 16 * 2, "Bullet_Laser");
    refused(g, ShockWhy::list, ShockAt::list);
  }
  {
    Game g;
    const uint64_t slots = g.mem.get<uint64_t>(g.manager + kSlotList);
    g.mem.put<uint64_t>(slots + 8 * 4, g.name("Bullet_Laser"));
    refused(g, ShockWhy::slots, ShockAt::slots);
  }
  {
    Game g;
    g.mem.put<int32_t>(g.manager + kSlotList + 8, 7);
    refused(g, ShockWhy::slots, ShockAt::slots);
  }
  // An allocation that fails stops there: the stances keep their commands, the array its new Max, its Num stays 5.
  {
    Game g;
    g.no_malloc = true;
    const ShockAnswer a = shock(g, kBase);
    assert(a.state == ShockState::refused && a.why == ShockWhy::alloc && a.at == ShockAt::list && a.added == 4);
    assert(g.commands(0).size() == 24 && g.list().size() == 5 && g.mem.get<int32_t>(g.element + kArrayAt + 12) == 6);
    assert(g.slots().size() == 5);
    assert(shock_line(pack(a), "") == "shock=refused why=alloc at=BulletItemSlotArray");
    assert(describe_shock(pack(a)) ==
           "shock bolt refused at BulletItemSlotArray: SB's allocator gave nothing; the writes before it stay");
  }

  // ---- The word and the lines ----
  {
    ShockAnswer a;
    assert(shock_line(pack(a), "") == "shock=off" && unpack_shock(0).state == ShockState::off);
    a.state = ShockState::refused, a.why = ShockWhy::id, a.at = ShockAt::block;
    assert(shock_line(pack(a), "") == "shock=refused why=id at=P_Eve_GunBlockSword");
    assert(describe_shock(pack(a)) ==
           "shock bolt refused at P_Eve_GunBlockSword: the row's ID is not the stance's; nothing written");
    a = ShockAnswer(), a.state = ShockState::fault;
    assert(shock_line(pack(a), "StellarCoop.dll+0x1234 (shock)") == "shock=fault where=StellarCoop.dll+0x1234 (shock)");
    a.state = ShockState::in, a.added = 4, a.commands[0] = 255, a.commands[1] = 24, a.list = 6, a.slots = 6;
    a.list_added = true;
    const ShockAnswer b = unpack_shock(pack(a));
    assert(b.state == a.state && b.added == 4 && b.commands[0] == 255 && b.commands[1] == 24 && b.list == 6 &&
           b.slots == 6 && b.list_added && !b.slots_added);
  }
  std::puts("lion_shock_test: ok");
  return 0;
}
