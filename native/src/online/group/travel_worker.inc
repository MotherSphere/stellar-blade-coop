// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Part of glue/tick.cpp, one translation unit with it (see there).
// The follow's travel ask, from the worker.

namespace coop::pose {

// The follow's travel (Lua's travel <alias> <index> <number>): the camp's FName for the game thread's next frame. Or
// the spot warp (travel spot <x> <y> <z> <yaw>, then optionally <world> <index> <number>): the place, the yaw and the
// world's FName (index 0 for none). An ask the game thread has not taken yet is replaced. Refused off the pinned build,
// after coop off or after a fault.
std::string ask_travel(const coop::Request &request) {
  if (!game_pinned || blocked || travel_faulted)
    return "travel refused: " + (blocked          ? std::string("coop off")
                                 : travel_faulted ? std::string("travel stopped for this run")
                                                  : engine_reason);
  {
    std::lock_guard<std::mutex> lock(travel_m);
    travel_alias_ask = ++travel_asked;
    travel_index = request.index, travel_number = request.number;
    travel_spot = request.spot, travel_at = request.at;
  }
  if (request.spot) { // The call's log line names the place: travel_alias holds it.
    travel_alias = std::to_string(request.at[0]) + " " + std::to_string(request.at[1]) + " " +
                   std::to_string(request.at[2]) + " " + std::to_string(request.at[3]) +
                   (request.index ? " " + request.alias : std::string());
    return "travel asked: spot " + travel_alias;
  }
  travel_alias = request.alias;
  return "travel asked: " + request.alias + " (FName " + std::to_string(request.index) + " " +
         std::to_string(request.number) + ")";
}

// The zone type of our zone as the vit line carries it (warp_game.inc's read of the ZoneTable row, wire_zone's 0 to
// 6): 0 before the first read and after the zone row's fault.
uint32_t zone_type() { return warp_zonetype; }

} // namespace coop::pose
