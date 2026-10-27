// The camps the current save has activated, the native half, free of Windows: SB's own list, as its camp list screen
// (the TeleportCamp list, FUN_141f65980) builds it, read on the game thread for session/travel.lua and cut/mxiii.lua.
// This file names the calls and offsets, checks the guard over the game thread's reads, says when to read and writes
// the status line (activated=). tests/native/game/camps_test.cpp checks it on the build machine.
//
// How SB decides, on build 24463856: FUN_141d1d650(zones, region, type, out, all) fills out, a TArray<FName>, with the
// ZoneCampTable rows of that region (NAME_None: every region) and that CampType which hold an active row. A camp's rows
// are the ZoneEnvSpawn rows whose TargetCamp names it (the zone manager's +0x550 map, which FUN_141d18100 builds), and
// a row is active when its ESBZoneEnvActiveState is Active (1): read from its live env object (+0x21c, which
// FSBZoneEnvRegister sets through FUN_141fdf900) for a row of the zone EVE stands in, from its zone's stored record
// (+0x24) for any other. all=true skips that test; the screen passes false, and so does the mod. The screen asks one
// region and FullCamp; the mod asks NAME_None once for each of the four travel types. The camp map and the records
// change only on the game and logic threads, so the read waits while a logic task runs.
//
// The camp EVE respawns at: her FSBActor's +0x26d0, the ZoneEnvSpawn row of the camp she last rested at or used
// (InteractCamp; the save's CampEnvSpawnAlias), which FSBActorRespawn (FUN_141b0f8f0) reads, and that row's TargetCamp
// (+0x270). SB's ReturnToCamp job (FUN_141b2b000, made by effect action 26 in FUN_141bc7af0) takes another camp, her
// FSBActor's +0x2738, which the camp arrival (FUN_141a8afe0) writes only for a Tetrapod camp: her last Tetrapod.
#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

#include "game/travel.h" // The globals and the client's and world's offsets the travel's guard reads too.

namespace coop::camps {
// SB's list (above), FMemory::Free (the list's TArray is SB's to free) and a ZoneEnvSpawnTable row by name on the
// tables' +0x20 (the getter FUN_141d1d650 itself calls; its second argument is unused), on the pinned build. GMalloc,
// which FMemory's calls make when null: the mod never lets them.
constexpr uint64_t kCampList = 0x141d1d650, kFree = 0x14261adb0, kEnvRow = 0x141a9d660, kMallocAt = 0x14706b500;
// The world's zone manager, the FSBActor's respawn camp row, a ZoneEnvSpawn row's TargetCamp.
constexpr size_t kZones = 0xe0, kRestedRow = 0x26d0, kTargetCamp = 0x270;
// The travel types, ESBZoneCampType: SimplyCamp, FullCamp, Tetrapod, PhoneBooth (session/travel.lua's 120 camps).
constexpr uint8_t kTypes[] = {2, 3, 4, 5};
// The guard each kCheckMs; a read at once when none is held or the world changed, else each kReadMs. A list longer
// than kMaxCamps is not SB's (235 camp rows in all).
constexpr uint64_t kCheckMs = 250, kReadMs = 2000;
constexpr int32_t kMaxCamps = 512;

// Why there is no read. client, world, zones, tables, tables_list, malloc: a global, the world's zone manager or the
// tables' +0x20 unset or implausible. flow, phase: the client is not in game (the title, a load). busy: a warp or a
// respawn in flight, or a logic task running: the next check tries again and the list held stays. unread: SB's list
// came back implausible. fault: the first fault ended the read for the run.
enum class Why : uint8_t { none, client, world, zones, tables, tables_list, malloc, flow, phase, busy, unread, fault };
inline const char *why_name(Why w) {
  static const char *const kNames[] = {"none", "client", "world", "zones",  "tables", "tables_list",
                                       "malloc", "flow", "phase", "busy", "unread", "fault"};
  return size_t(w) < sizeof kNames / sizeof *kNames ? kNames[size_t(w)] : "?";
}

// What the game thread read before the list, in the order it reads them.
struct Reads {
  uint64_t client = 0, world = 0, zones = 0, tables = 0, tables_list = 0, malloc = 0;
  int32_t flow = 0, phase = 0;
  uint8_t warp = 0, asked = 0, waits = 0;
  int32_t respawn = 0;
  bool logic = false; // A logic task in flight (fight/pilot.h's logic_busy).
};
// The first guard that fails, or Why::none.
inline Why refuse(const Reads &r) {
  return !travel::plausible(r.client)                        ? Why::client
         : !travel::plausible(r.world)                       ? Why::world
         : !travel::plausible(r.zones)                       ? Why::zones
         : !travel::plausible(r.tables)                      ? Why::tables
         : !travel::plausible(r.tables_list)                 ? Why::tables_list
         : !travel::plausible(r.malloc)                      ? Why::malloc
         : r.flow != travel::kInGame                         ? Why::flow
         : r.phase != travel::kPlaying                       ? Why::phase
         : r.warp || (r.asked && r.waits)                    ? Why::busy
         : travel::respawning(r.respawn) || r.logic          ? Why::busy
                                                             : Why::none;
}

// When to read. A refusal other than busy drops the list held (a load may bring another save in); a list is read at
// once when none is held or the zone manager is another (a new world), and again each kReadMs, so a camp activated
// since shows within 2 s and a list never outlives its save.
struct Schedule {
  uint64_t zones = 0, due = 0; // The zone manager of the list held (0: none held), and the next read.
  bool due_at(uint64_t now, uint64_t z) const { return !zones || z != zones || now >= due; }
  void read(uint64_t now, uint64_t z) { zones = z, due = now + kReadMs; }
  void drop() { zones = 0; }
};

// The status line: "activated=<n>:<alias>,<alias>,..." (n may be 0) with " rested=<alias>" when that camp is known, or
// "activated=none:<why>". A line of its own, so it reaches UE4SS.log only when it changes. A name with a space or a
// comma (none of SB's camps) is left out, so the line always splits.
inline std::string line(Why why, const std::vector<std::string> &camps, const std::string &rested) {
  if (why != Why::none)
    return std::string("activated=none:") + why_name(why);
  const auto clean = [](const std::string &s) { return !s.empty() && s.find_first_of(" ,") == std::string::npos; };
  std::string list;
  size_t n = 0;
  for (const std::string &c : camps)
    if (clean(c))
      list += (n++ ? "," : "") + c;
  return "activated=" + std::to_string(n) + ":" + list + (clean(rested) ? " rested=" + rested : std::string());
}
} // namespace coop::camps
