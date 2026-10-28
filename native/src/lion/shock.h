// EVE's cut Shock Bolt ammo made usable once its rows are in (lion/rows.h's bolt rows batch: ItemTable Bullet_Shock,
// SkillTable P_Eve_Gun_ShootShockSlug1_1, its projectile and its hit result), free of Windows:
// tests/native/lion/shock_test.cpp checks it on the build machine against fake memory. What the rows cannot do is make
// the ammo selectable and the gun fire it. Two of SB's lists do that, and each is grown in place, never through AddRow:
//
// The fire commands. EVE's gun stances P_Eve_Gun (100104) and P_Eve_GunBlockSword (100110) list 22 commands in their
// CommandArray (a TArray<FName> at row +0x90); for Shock only P_Eve_Gun_ShootShockSlugFail1_1. SB reads that array in
// one place: when a stance starts (FUN_141a7d4b0), FUN_141a61c50 copies every command into nodes of its own and keeps
// no pointer into the array. So the two fire commands SB ships (SkillCommandTable P_Eve_Gun_ShootShockSlug1_1 and
// _1_2: RangedFireItem, BulletItemAlias Bullet_Shock) go at the end of the live row the stance change reads (the
// registry's FUN_141a9cd20 by name, its override map first), the way SB itself appends: Num raised, FUN_140e47f00 (SB's
// grow of an 8-byte TArray through GMalloc's Realloc) when Num passes Max, then the FNames written. EVE gets them the
// next time she enters the stance (aiming again, if she aimed while they went in). AddRow under a live stance's name
// would free the row SB hands out.
//
// The ammo list. SB's const store (the singleton at 0x147032540, game/debug_keys.h's) holds BulletItemSlotArray, a
// TArray<FString> in its string-array map at +0x288 (the gates' map layout, 0x20-byte elements: key, the array at +8,
// the next element's index at +0x18), keyed by Strihash_DEPRECATED of the name (SB's FUN_14117c1f0, called, not
// copied): Bullet_Normal, Bullet_Scatter, Bullet_Railgun, Bullet_Missile, Bullet_Explosive. The item slot manager
// (FUN_141a97c40's object +0xe8, its list of FNames at +0x238) and the TPS bullet HUD build their own lists from it
// when they start. SB locks an entry only while its index is below BulletItemAcquisitionSlotArray's 5 entries, so a
// sixth, Bullet_Shock, is never locked. It goes at the end of the const array (GMalloc's Realloc for the array, its
// Malloc for the text) and, when the slot manager already exists, of its list too (SB's grow again). The HUD (a
// carousel of three slots, Left, Center1 and Right, plus Missile's and Railgun's own) takes it at its next start; every
// HUD and tick reader of the slot index checks it against its list's length, so a list one entry short of the other is
// read as no bullet, never past its end.
//
// Every write is checked first, and a check's refusal writes nothing: the two rows found with their IDs, each array's
// Num and Max in range, each FName made, the const list and the slot manager's list exactly the five SB ships (or those
// five and Bullet_Shock: grown already, left as it is), every element read. Then the writes, in that order; an
// allocation that fails stops there and keeps the writes before it (an array left longer than its Num, never an entry
// half written). Runs once a game run, on the game thread in the rows' gate (glue/tick/lion_game.inc: no logic task in
// flight, and none can start before the call returns), right after the bolt rows batch's last row went in, under a
// latch of its own. Only the shop asks for that batch (nightop/shop.lua: a Shock Bolt buy, and coop nightop shop before
// it opens the screen, which Roxanne's supplies choice runs too), so a player who opens that screen grows the lists
// even without buying a bolt, and no other command grows them.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>

#include "game/memory.h"
#include "lion/rows.h"

namespace coop::lion {

// The stances, their IDs, and the two fire commands both get.
constexpr const char *kGunStances[2] = {"P_Eve_Gun", "P_Eve_GunBlockSword"};
constexpr uint32_t kGunStanceIds[2] = {100104, 100110};
constexpr const char *kShockFire[2] = {"P_Eve_Gun_ShootShockSlug1_1", "P_Eve_Gun_ShootShockSlug1_2"};
constexpr size_t kCommandArray = 0x90; // FSBCharacterStanceTableProperty::CommandArray.
// The const store, its string-array map (fields as FUN_14261dfa0 reads them) and the ammo list's name and entries.
constexpr uint64_t kConsts = 0x147032540, kSlotsHolder = 0x147032570;
constexpr size_t kArrays = 0x288, kArraysCount = 0x290, kArraysFree = 0x2bc, kArraysInlineHash = 0x2c0,
                 kArraysHashPointer = 0x2c8, kArraysHashSize = 0x2d0, kArrayElement = 0x20, kArrayAt = 8,
                 kArrayNext = 0x18;
constexpr const char *kSlotArray = "BulletItemSlotArray";
constexpr const char *kShippedBullets[5] = {"Bullet_Normal", "Bullet_Scatter", "Bullet_Railgun", "Bullet_Missile",
                                            "Bullet_Explosive"};
constexpr const char *kShockBullet = "Bullet_Shock";
// The item slot manager's object (FUN_141a97c40's, never made here: 0 until SB made it) and its list.
constexpr size_t kSlotManager = 0xe8, kSlotList = 0x238;
// Far above any count these hold (22 commands, 5 bullets, a few hundred string arrays).
constexpr int32_t kMaxCommands = 256, kMaxBullets = 64, kMaxArrays = 1 << 16;

// Why nothing was written. fname: no FName for a name; stance: no row of that name; id: the row's ID is not the
// stance's; commands: its CommandArray reads out of range; consts: no const store, or its map reads out of range or
// empty; key: no BulletItemSlotArray in it; list: that array is not the five SB ships (nor those and Bullet_Shock);
// slots: the slot manager's list is not either; alloc: SB's allocator gave nothing (the writes before it stay).
enum class ShockWhy : uint8_t { none, fname, stance, id, commands, consts, key, list, slots, alloc };
inline const char *shock_why_word(ShockWhy w) {
  static const char *const kWords[] = {"none",   "fname", "stance", "id",    "commands",
                                       "consts", "key",   "list",   "slots", "alloc"};
  return size_t(w) < sizeof kWords / sizeof *kWords ? kWords[size_t(w)] : "?";
}
// Where: a stance (0, 1), the const list (2), the slot manager's list (3).
enum class ShockAt : uint8_t { gun, block, list, slots };
enum class ShockState : uint8_t { off, in, refused, fault };
struct ShockAnswer {
  ShockState state = ShockState::off;
  ShockWhy why = ShockWhy::none;
  ShockAt at = ShockAt::gun;
  uint8_t added = 0;           // Fire commands appended, both stances.
  uint8_t commands[2] = {};    // Each stance's CommandArray length after.
  uint8_t list = 0, slots = 0; // The const list's and the slot manager's lengths after; slots 0: no manager yet.
  bool list_added = false, slots_added = false;
};
// One word for the worker and the status: state 0-3, why 4-7, at 8-11, added 12-19, the lengths 20-51, the two
// appends 52-53.
inline uint64_t pack(const ShockAnswer &a) {
  return uint64_t(a.state) | uint64_t(a.why) << 4 | uint64_t(a.at) << 8 | uint64_t(a.added) << 12 |
         uint64_t(a.commands[0]) << 20 | uint64_t(a.commands[1]) << 28 | uint64_t(a.list) << 36 |
         uint64_t(a.slots) << 44 | uint64_t(a.list_added) << 52 | uint64_t(a.slots_added) << 53;
}
inline ShockAnswer unpack_shock(uint64_t w) {
  ShockAnswer a;
  a.state = ShockState(w & 15), a.why = ShockWhy((w >> 4) & 15), a.at = ShockAt((w >> 8) & 15);
  a.added = uint8_t(w >> 12), a.commands[0] = uint8_t(w >> 20), a.commands[1] = uint8_t(w >> 28);
  a.list = uint8_t(w >> 36), a.slots = uint8_t(w >> 44), a.list_added = (w >> 52) & 1, a.slots_added = (w >> 53) & 1;
  return a;
}

// The Game shock() takes: lion/rows.h's read (false when unmapped), write and name(text, len, number), and
// stance_row(name): the stance row the registry gives for an FName (FUN_141a9cd20), or 0; grow(array): SB's
// FUN_140e47f00 on a TArray of 8-byte items whose Num was raised; hash(text): FUN_14117c1f0 of the ASCII text as
// UTF-16; malloc(n) and realloc(address, n): GMalloc's, 0 when they give nothing.
template <class Game> struct ShockRun {
  Game &g;
  ShockAnswer a;
  template <class T> bool get(uint64_t address, T &v) { return g.read(address, &v, sizeof v); }
  uint64_t make(const char *text) {
    const NameParts p = split_number(text);
    return g.name(text, p.len, p.number);
  }
  ShockAnswer refuse(ShockWhy why, ShockAt at) {
    a.state = ShockState::refused, a.why = why, a.at = at;
    return a;
  }
  // A TArray header {data, num, max} at address, in range: 0 <= num <= max <= most, data mapped when max > 0.
  bool array(uint64_t address, uint64_t &data, int32_t &num, int32_t &max, int32_t most) {
    return get(address, data) && get(address + 8, num) && get(address + 12, max) && num >= 0 && num <= max &&
           max <= most && (max == 0 || game::plausible(data));
  }
  // An FString's text, compared with ASCII text (its NUL included).
  bool string_is(uint64_t header, const char *text) {
    uint64_t data = 0;
    int32_t num = 0;
    const size_t len = std::strlen(text);
    if (!get(header, data) || !get(header + 8, num) || num != int32_t(len + 1) || !game::plausible(data))
      return false;
    for (size_t k = 0; k <= len; ++k) {
      uint16_t c = 0;
      if (!get(data + 2 * k, c) || c != (k < len ? uint8_t(text[k]) : 0))
        return false;
    }
    return true;
  }
  // The five SB ships, then Bullet_Shock or nothing: 5 or 6, and 0 for anything else. is(i, text): entry i is text.
  template <class Is> static int32_t bullets(int32_t num, Is is) {
    if (num != 5 && num != 6)
      return 0;
    for (int32_t i = 0; i < 5; ++i)
      if (!is(i, kShippedBullets[i]))
        return 0;
    return num == 5 || is(5, kShockBullet) ? num : 0;
  }

  ShockAnswer run(uint64_t base) {
    // ---- The checks, nothing written ----
    uint64_t fire[2];
    for (size_t k = 0; k < 2; ++k)
      if (!(fire[k] = make(kShockFire[k])))
        return refuse(ShockWhy::fname, ShockAt::gun);
    uint64_t rows[2], data[2];
    int32_t num[2], max[2], missing[2] = {};
    bool has[2][2] = {};
    for (size_t s = 0; s < 2; ++s) {
      const ShockAt at = ShockAt(s);
      const uint64_t name = make(kGunStances[s]);
      if (!name)
        return refuse(ShockWhy::fname, at);
      uint32_t id = 0;
      if (!(rows[s] = g.stance_row(name)))
        return refuse(ShockWhy::stance, at);
      if (!get(rows[s] + kIdAt, id) || id != kGunStanceIds[s])
        return refuse(ShockWhy::id, at);
      if (!array(rows[s] + kCommandArray, data[s], num[s], max[s], kMaxCommands))
        return refuse(ShockWhy::commands, at);
      for (int32_t i = 0; i < num[s]; ++i) {
        uint64_t n = 0;
        if (!get(data[s] + 8 * uint64_t(i), n))
          return refuse(ShockWhy::commands, at);
        for (size_t k = 0; k < 2; ++k)
          has[s][k] = has[s][k] || n == fire[k];
      }
      missing[s] = !has[s][0] + !has[s][1];
      if (num[s] + missing[s] > 255) // The answer's byte.
        return refuse(ShockWhy::commands, at);
    }
    // The const list: its element in the map, then its five (or six) FStrings.
    uint64_t consts = 0, elements = 0, pointer = 0;
    int32_t count = 0, holes = 0, size = 0;
    if (!get(base + (kConsts - kImageBase), consts) || !game::plausible(consts) || !get(consts + kArraysCount, count) ||
        !get(consts + kArraysFree, holes) || !get(consts + kArraysHashSize, size) || !get(consts + kArrays, elements) ||
        !get(consts + kArraysHashPointer, pointer) || count <= 0 || count > kMaxArrays || count == holes || size <= 0 ||
        size > kMaxArrays || (size & (size - 1)) || !game::plausible(elements) ||
        (pointer && !game::plausible(pointer)))
      return refuse(ShockWhy::consts, ShockAt::list);
    const uint32_t key = g.hash(kSlotArray);
    int32_t index = -1;
    if (!get((pointer ? pointer : consts + kArraysInlineHash) + 4 * uint64_t(key & uint32_t(size - 1)), index))
      return refuse(ShockWhy::consts, ShockAt::list);
    uint64_t element = 0;
    for (int32_t steps = 0; index != -1 && !element; ++steps) {
      uint32_t got = 0;
      const uint64_t e = elements + uint64_t(index) * kArrayElement;
      if (index < 0 || index >= count || steps >= count || !get(e, got) || !get(e + kArrayNext, index))
        return refuse(ShockWhy::consts, ShockAt::list);
      element = got == key ? e : 0;
    }
    if (!element)
      return refuse(ShockWhy::key, ShockAt::list);
    uint64_t list = 0;
    int32_t list_num = 0, list_max = 0;
    if (!array(element + kArrayAt, list, list_num, list_max, kMaxBullets) ||
        !bullets(list_num, [&](int32_t i, const char *text) { return string_is(list + 16 * uint64_t(i), text); }))
      return refuse(ShockWhy::list, ShockAt::list);
    // The slot manager's list, when SB made the manager.
    uint64_t holder = 0, manager = 0, slots = 0;
    int32_t slots_num = 0, slots_max = 0;
    if (get(base + (kSlotsHolder - kImageBase), holder) && game::plausible(holder) &&
        get(holder + kSlotManager, manager) && game::plausible(manager)) {
      uint64_t names[6] = {};
      for (size_t i = 0; i < 6; ++i)
        if (!(names[i] = make(i < 5 ? kShippedBullets[i] : kShockBullet)))
          return refuse(ShockWhy::fname, ShockAt::slots);
      if (!array(manager + kSlotList, slots, slots_num, slots_max, kMaxBullets) ||
          !bullets(slots_num, [&](int32_t i, const char *) {
            uint64_t n = 0;
            return get(slots + 8 * uint64_t(i), n) && n == names[i];
          }))
        return refuse(ShockWhy::slots, ShockAt::slots);
    }

    // ---- The writes ----
    for (size_t s = 0; s < 2; ++s) {
      int32_t n = num[s];
      if (missing[s]) {
        const int32_t want = n + missing[s];
        g.write(rows[s] + kCommandArray + 8, &want, 4);
        if (want > max[s]) {
          g.grow(rows[s] + kCommandArray);
          if (!array(rows[s] + kCommandArray, data[s], n, max[s], 1 << 30) || n != want || max[s] < want) {
            g.write(rows[s] + kCommandArray + 8, &num[s], 4); // Its old length back: nothing appended.
            return refuse(ShockWhy::alloc, ShockAt(s));
          }
        }
        for (size_t k = 0; k < 2; ++k)
          if (!has[s][k]) {
            g.write(data[s] + 8 * uint64_t(num[s]), &fire[k], 8);
            ++num[s], ++a.added;
          }
      }
      a.commands[s] = uint8_t(num[s]);
    }
    if (list_num == 5) {
      if (list_max < 6) {
        const uint64_t grown = g.realloc(list, 16 * 6);
        if (!grown)
          return refuse(ShockWhy::alloc, ShockAt::list);
        const int32_t six = 6;
        g.write(element + kArrayAt, &grown, 8);
        g.write(element + kArrayAt + 12, &six, 4);
        list = grown;
      }
      const size_t len = std::strlen(kShockBullet);
      const uint64_t text = g.malloc(2 * (len + 1));
      if (!text)
        return refuse(ShockWhy::alloc, ShockAt::list);
      for (size_t k = 0; k <= len; ++k) {
        const uint16_t c = k < len ? uint8_t(kShockBullet[k]) : 0;
        g.write(text + 2 * k, &c, 2);
      }
      const int32_t chars = int32_t(len + 1), six = 6;
      g.write(list + 16 * 5, &text, 8);
      g.write(list + 16 * 5 + 8, &chars, 4);
      g.write(list + 16 * 5 + 12, &chars, 4);
      g.write(element + kArrayAt + 8, &six, 4);
      list_num = 6, a.list_added = true;
    }
    a.list = uint8_t(list_num);
    if (manager && slots_num == 5) {
      const int32_t six = 6;
      const uint64_t shock = make(kShockBullet);
      g.write(manager + kSlotList + 8, &six, 4);
      if (slots_max < 6) {
        int32_t n = 0;
        g.grow(manager + kSlotList);
        if (!array(manager + kSlotList, slots, n, slots_max, 1 << 30) || n != 6 || slots_max < 6) {
          g.write(manager + kSlotList + 8, &slots_num, 4);
          return refuse(ShockWhy::alloc, ShockAt::slots);
        }
      }
      g.write(slots + 8 * 5, &shock, 8);
      slots_num = 6, a.slots_added = true;
    }
    a.slots = uint8_t(manager ? slots_num : 0);
    a.state = ShockState::in;
    return a;
  }
};
// One run over both lists (see the top of this file). base: SB's image base.
template <class Game> ShockAnswer shock(Game &g, uint64_t base) { return ShockRun<Game>{g, {}}.run(base); }

// coop-status.txt's shock line (nightop/shop.lua reads it before a Shock Bolt buy):
//   shock=off
//   shock=in commands=<gun>,<block> added=<n> list=<n> slots=<n|->
//   shock=refused why=<word> at=<P_Eve_Gun|P_Eve_GunBlockSword|BulletItemSlotArray|slots>
//   shock=fault where=<text, maybe with spaces>
// slots=-: the slot manager was not made yet (its list then comes from the const list).
inline const char *shock_at_word(ShockAt at) {
  return at == ShockAt::gun     ? kGunStances[0]
         : at == ShockAt::block ? kGunStances[1]
         : at == ShockAt::list  ? kSlotArray
                                : "slots";
}
inline std::string shock_line(uint64_t word, const std::string &fault) {
  const ShockAnswer a = unpack_shock(word);
  if (a.state == ShockState::in)
    return "shock=in commands=" + std::to_string(a.commands[0]) + "," + std::to_string(a.commands[1]) +
           " added=" + std::to_string(a.added) + " list=" + std::to_string(a.list) +
           " slots=" + (a.slots ? std::to_string(a.slots) : std::string("-"));
  if (a.state == ShockState::refused)
    return std::string("shock=refused why=") + shock_why_word(a.why) + " at=" + shock_at_word(a.at);
  if (a.state == ShockState::fault)
    return "shock=fault where=" + fault;
  return "shock=off";
}
// The log line (coop-link.log), once.
inline std::string describe_shock(uint64_t word) {
  const ShockAnswer a = unpack_shock(word);
  char text[400];
  if (a.state == ShockState::in) {
    char slots[96] = "the slot manager is not made yet and takes the list when it starts";
    if (a.slots)
      std::snprintf(slots, sizeof slots, "the slot manager's list %s, %u entries", a.slots_added ? "grown" : "kept",
                    unsigned(a.slots));
    std::snprintf(text, sizeof text,
                  "shock bolt in: %u fire commands added (P_Eve_Gun %u commands, P_Eve_GunBlockSword %u), "
                  "BulletItemSlotArray %s, %u entries, %s",
                  unsigned(a.added), unsigned(a.commands[0]), unsigned(a.commands[1]), a.list_added ? "grown" : "kept",
                  unsigned(a.list), slots);
    return text;
  }
  if (a.state != ShockState::refused)
    return std::string("shock bolt ") + (a.state == ShockState::fault ? "fault" : "off");
  static const char *const kWhy[] = {"?",
                                     "the game made no FName",
                                     "no stance row of that name",
                                     "the row's ID is not the stance's",
                                     "its CommandArray reads out of range",
                                     "no const store, or its map reads out of range",
                                     "no BulletItemSlotArray in the const store",
                                     "the list is not the five SB ships",
                                     "the slot manager's list is not the five SB ships",
                                     "SB's allocator gave nothing"};
  std::snprintf(text, sizeof text, "shock bolt refused at %s: %s; %s", shock_at_word(a.at),
                kWhy[size_t(a.why) < sizeof kWhy / sizeof *kWhy ? size_t(a.why) : 0],
                a.why == ShockWhy::alloc ? "the writes before it stay" : "nothing written");
  return text;
}

} // namespace coop::lion
