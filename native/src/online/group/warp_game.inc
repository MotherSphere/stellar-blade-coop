// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).

namespace coop::pose {
namespace {
// ---- The revive's guard, the game thread's read: a respawn or a warp in flight, and our EVE's GUID ----
// Read straight from the client game-flow singleton's and the world's globals, never through their getters (which
// allocate when the pointer is null). Busy: a warp written at client +0xa20 (a camp on another map, a fast travel), the
// death screen's camp request at +0xb60 and +0xb61 (a respawn on this map, waiting in the client tick), or the world's
// respawn state at +0x1c4 (1 at rest, 2 from the request on, then ResetZone and the respawn: travel::respawning). Our GUID: client +0x58, the key the
// world's player map holds for the local player. Every 250 ms, under its own latch: the first fault ends the reads for
// the run, and the engine line then has no warp= (Lua's revive then waits forever).
//
// Under the same latch (Seamless gap phase 4): every 250 ms the area, the world's +0x90 FName (the zone alias SB's camp
// process FUN_141ca8270 logs as CurrentZoneInfo.ZoneAlias), and the logic's zone, +0x598 (fight::kZoneAlias) of the
// object at quest::kLogicGlobal (0x1470373e0, FUN_141a98a30's global, read straight). FSBResetZone's Simulate
// (FUN_141b128a0, then FUN_141ace080) resets only the zone the logic holds, so area= is the world's zone only when the
// two agree. And at each frame the starts of SB's camp process (game/travel.h's Rests): FUN_141ca7040 copies a camp
// request to world +0x1a0 (its +0x18 GUID to +0x1b8, its +0x24 type to +0x1c4, the same int the revive reads as its
// respawn state) and sets +0x1a0 to 1; the process's end (state 0xe) clears +0x1a0 and +0x34 in one call, so a read
// each 250 ms could merge two starts.
constexpr uint64_t kWarpBlock = 0xa20, kCampAsked = 0xb60, kCampWaits = 0xb61, kRespawnState = 0x1c4;
constexpr uint64_t kArea = 0x90, kRestFlag = 0x1a0, kRestGuid = 0x1b8, kRestType = 0x1c4;
std::atomic<bool> warp_faulted{false};
std::atomic<int> warp_state{-1}; // -1: no read (no client or world yet, or the latch); 0 idle; 1 busy.
std::atomic<uint32_t> warp_me{0};
std::atomic<uint64_t> warp_fault_code{0}, warp_fault_rva{0}, warp_fault_address{0};
uint64_t warp_next = 0; // The game thread's: its next read.
constexpr bool warp_busy(uint8_t warp, uint8_t asked, uint8_t waits, int32_t respawn) {
  return warp != 0 || (asked != 0 && waits != 0) || travel::respawning(respawn);
}
static_assert(!warp_busy(0, 0, 0, 0) && warp_busy(1, 0, 0, 0) && !warp_busy(0, 1, 0, 0) && !warp_busy(0, 0, 1, 0) &&
                  warp_busy(0, 1, 1, 0) && !warp_busy(0, 0, 0, 1) && warp_busy(0, 0, 0, 2),
              "busy: a warp, the camp request with its wait, or the world's respawn");

// ---- The zone type, the game thread's call (Seamless gap phase 4) ----
// sbo::kCurrentZoneRow, FUN_141d01910(&zone FName): the ZoneTable row of the client's zone (+0x68), whose +0x25 is
// its type (ESBZoneType: 0 None, 1 Public, 2 TrainningRoom, 3 SpiritRoom, 4 TestZone, 5 BossChallenge, 6 Nikke). It
// calls 141a98e30 (the tables' getter, which allocates while 0x1470373b0 is null) and runs the row's first use (row +8,
// vfunc +0x20), as SB's FUN_141cf7630 does. So the call is made each 250 ms only in game (flow and phase), with the
// tables' global set, and only when the 8 bytes at client +0x68 differ from its last call's, on a local copy as SB's
// save 0x141ce8050 passes its own. Otherwise the last type stays, so a load into or out of a Boss Challenge keeps it.
// Under its own latch: a fault gives zonetype=0 for the run and never ends the warp read.
std::atomic<uint32_t> warp_zonetype{0}; // wire_zone() of the row's type; 0 before the first read and after a fault.
std::atomic<bool> zone_faulted{false};
std::atomic<uint64_t> zone_fault_code{0}, zone_fault_rva{0}, zone_fault_address{0};

// What the worker takes, under warp_text_m (the game thread only try-locks it): the area and our last rest's area as
// texts, the counts of game/travel.h's Rests and the event lines for the log. One struct, so the engine line never
// shows a new rest count with the area of the one before.
struct WarpText {
  std::string area = "none", rest = "none";
  uint32_t ours = 0, starts = 0;
  int32_t type = 0;
  std::vector<std::string> lines;
};
std::mutex warp_text_m;
WarpText warp_text; // The worker's.
// The game thread's own: the rest count, the names last read with their texts, the last zone the row was read for, the
// type last logged, the aliases already logged with no row or a type past kMaxZoneType, and the copy for the worker.
travel::Rests warp_rests;
bool warp_names_read = false, zone_called = false, warp_text_pending = false;
uint64_t warp_area_name = 0, warp_logic_name = 0, zone_last = 0;
uint32_t zone_logged = UINT32_MAX;
std::string warp_area_made = "none", warp_rest_made = "none";
std::vector<std::string> zone_odd;
WarpText warp_text_out;

// An FName as the engine line and the log name it: none for NAME_None, for 0 (no logic made yet) or for a text that is
// no alias word (the engine line is split at spaces).
std::string warp_alias(uint64_t name) {
  const uint32_t none = at<uint32_t>(base + (quest::kNoneName - game::kImageBase)); // NAME_None, number 0.
  if (!name || (uint32_t(name) == none && !(name >> 32)))
    return "none";
  std::string text = camps_name(name);
  return coop::alias_word(text) ? text : "none";
}
void warp_say(std::string line) {
  warp_text_out.lines.push_back(std::move(line));
  warp_text_pending = true;
}

__declspec(noinline) void warp_body() {
  const uintptr_t client = at<uintptr_t>(base + (slot::kClient - game::kImageBase));
  const uintptr_t world = at<uintptr_t>(base + (quest::kWorldGlobal - game::kImageBase));
  if (!game::plausible(client) || !game::plausible(world)) {
    warp_state = -1;
    return;
  }
  const bool busy = warp_busy(at<uint8_t>(client + kWarpBlock), at<uint8_t>(client + kCampAsked),
                              at<uint8_t>(client + kCampWaits), at<int32_t>(world + kRespawnState));
  warp_me = at<uint32_t>(client + slot::kPlayerGuid);
  warp_state = busy ? 1 : 0;
  // The area, and the logic's zone (0 while the logic is not made): texts only when a name changes.
  const uintptr_t logic = at<uintptr_t>(base + (quest::kLogicGlobal - game::kImageBase));
  const uint64_t area = at<uint64_t>(world + kArea);
  const uint64_t zone = game::plausible(logic) ? at<uint64_t>(logic + fight::kZoneAlias) : 0;
  if (warp_names_read && area == warp_area_name && zone == warp_logic_name)
    return;
  warp_names_read = true, warp_area_name = area, warp_logic_name = zone;
  const std::string text = warp_alias(area);
  warp_area_made = area == zone ? text : "none";
  warp_text_pending = true;
  if (area != zone)
    warp_say("zone " + text + ": world and logic differ (" + warp_alias(zone) + ")");
}

// Each frame: an edge of world +0x1a0 is a start of SB's camp process; ours (our EVE's GUID) keeps its type and area.
__declspec(noinline) void rest_body() {
  const uintptr_t client = at<uintptr_t>(base + (slot::kClient - game::kImageBase));
  const uintptr_t world = at<uintptr_t>(base + (quest::kWorldGlobal - game::kImageBase));
  if (!game::plausible(client) || !game::plausible(world))
    return;
  const uint32_t starts = warp_rests.starts, guid = at<uint32_t>(world + kRestGuid);
  const int32_t type = at<int32_t>(world + kRestType);
  const uint64_t area = at<uint64_t>(world + kArea);
  const bool ours = warp_rests.step(at<uint8_t>(world + kRestFlag), type, guid,
                                    at<uint32_t>(client + slot::kPlayerGuid), area);
  if (warp_rests.starts == starts)
    return;
  const std::string text = warp_alias(area);
  if (ours)
    warp_rest_made = text;
  warp_say("zone reset start: type " + std::to_string(type) + " guid " + std::to_string(guid) +
           (ours ? " ours" : " another") + " in " + text);
}

__declspec(noinline) void zone_body() {
  const uintptr_t client = at<uintptr_t>(base + (travel::kClientAt - game::kImageBase));
  const uintptr_t tables = at<uintptr_t>(base + (travel::kTablesAt - game::kImageBase));
  if (!travel::plausible(client) || !travel::plausible(tables) ||
      at<int32_t>(client + travel::kFlow) != travel::kInGame ||
      at<int32_t>(client + travel::kPhase) != travel::kPlaying)
    return;
  const uint64_t zone = at<uint64_t>(client + sbo::kZone); // The local copy the call reads.
  if (zone_called && zone == zone_last)
    return;
  zone_called = true, zone_last = zone;
  using ZoneRowOf = uint8_t *(*)(const uint64_t *zone);
  const uint8_t *row = reinterpret_cast<ZoneRowOf>(base + (sbo::kCurrentZoneRow - game::kImageBase))(&zone);
  const uint32_t raw = row ? row[sbo::kZoneType] : 0, type = coop::wire_zone(raw);
  warp_zonetype = type;
  // The log: each change of type; a zone with no row, or a type this build does not know, once per alias.
  const std::string alias = warp_alias(zone);
  const auto first = [&alias] {
    for (const std::string &a : zone_odd)
      if (a == alias)
        return false;
    zone_odd.push_back(alias);
    return true;
  };
  if (!row) {
    if (first())
      warp_say("zone " + alias + ": type unknown");
  } else if (raw != type) {
    if (first())
      warp_say("zone " + alias + ": type " + std::to_string(raw) + " is past " + std::to_string(coop::kMaxZoneType) +
               ", sent as 0");
  } else if (type != zone_logged) {
    warp_say("zone " + alias + ": type " + std::to_string(type));
  }
  zone_logged = type;
}

// Each frame: the worker's copy, swapped in once it took the last lines (so only a swap happens under the lock).
void warp_publish() {
  if (!warp_text_pending)
    return;
  warp_text_out.area = warp_area_made, warp_text_out.rest = warp_rest_made;
  warp_text_out.ours = warp_rests.ours, warp_text_out.starts = warp_rests.starts, warp_text_out.type = warp_rests.type;
  if (!warp_text_m.try_lock())
    return;
  const bool taken = warp_text.lines.empty();
  if (taken)
    std::swap(warp_text, warp_text_out);
  warp_text_m.unlock();
  if (taken)
    warp_text_out.lines.clear(), warp_text_pending = false;
}

void warp_tick() {
  const uint64_t now = GetTickCount64();
  const bool due = now >= warp_next;
  if (due)
    warp_next = now + 250;
  __try {
    rest_body();
    if (due)
      warp_body();
  } __except (fault_filter(GetExceptionInformation(), warp_fault_code, warp_fault_rva, warp_fault_address)) {
    warp_faulted = true;
    warp_state = -1;
  }
  if (due && !warp_faulted && !zone_faulted) {
    __try {
      zone_body();
    } __except (fault_filter(GetExceptionInformation(), zone_fault_code, zone_fault_rva, zone_fault_address)) {
      zone_faulted = true;
      warp_zonetype = 0;
    }
  }
  warp_publish();
}
} // namespace
} // namespace coop::pose
