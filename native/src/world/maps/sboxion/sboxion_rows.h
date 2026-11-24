// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Written by hand: two rows need no generator and no data file.
// SBO Xion's batch (kSboxionRecipe; world/maps/sboxion/data.lua lists the same rows for the read-back) holds one
// WorldTable row and one type-5 ZoneTable row, so SB's URL warp reaches /Game/SBO_World/Xion_P, the persistent level
// of the zSBO_Xion test pak. That pak is built outside the repository and never shipped with the mod.
//
// The world row SBO_Xion is a copy of CombatTestMapMk2 (1003, the hall lobbies' donor: only UMapPath and FileSuffix
// exist) with UMapPath naming the test pak's level. The zone row Zone_SBO_Xion is a copy of Zone_NK_Boss_Scarlet
// (3191: type 5 BossChallenge, StartPointAlias None, AdditiveDesignLevel empty, no events, no LoadLevels) with
// WorldAlias naming the world row. ZoneType 5 is written again as a guard. The world row comes first, so the zone
// never names a world row that is not in yet. SB's world row Xion and its zones are not touched.
//
// IDs World 7131 and Zone 1000131. Both are free on build 26123051 (WorldTable 50 rows, highest ID 7000; ZoneTable
// 199 rows, highest ID 999992). The hall lobbies hold 7121-7125 and 1000121-1000125. tools/sbo_lobby_rows.py gives
// hall i the pair (7121 + i, 1000121 + i): 7126-7130 and 1000126-1000130 stay free for five more halls. An SB update
// that takes either ID refuses the batch (Why::id). No name ends in _<digits>: the warp sends FName number 0.
// Offsets as in online/lobby/halls_rows.h (SDK stellar-sdk-647527f: SBWorldTableProperty 0x30, SBZoneTableProperty
// 0x150), read again in Ghidra on build 26123051: SB's own Boss Challenge entry 0x141ce4150 hands zone row +0x14 to
// the world row lookup 0x141ae2f70 (LEA at 0x141ce424e) and world row +0x18 to the URL warp 0x141cdfa50; the type-5
// test 0x141cf7630 reads zone row +0x25.
#pragma once

#include "rows/rows.h"

namespace coop::lion {

constexpr Patch kSboxionPatches[] = {
    {0x18, Kind::string, 0, "/Game/SBO_World/Xion_P.Xion_P"}, // UMapPath (SBO_Xion)
    // Zone_SBO_Xion
    {0x14, Kind::name, 0, "SBO_Xion"}, // WorldAlias
    {0x25, Kind::u8, 5, nullptr}, // ZoneType Zone_BossChallenge, the donor's
};
constexpr Row kSboxionRecipe[] = {
    {Table::world, "SBO_Xion", "CombatTestMapMk2", 7131u, 0, 1},
    {Table::zone, "Zone_SBO_Xion", "Zone_NK_Boss_Scarlet", 1000131u, 1, 2},
};
constexpr size_t kSboxionRows = sizeof kSboxionRecipe / sizeof kSboxionRecipe[0];
static_assert(kSboxionRows < 256, "a row index fits a byte");
constexpr Batch kSboxion{"sboxion", kSboxionRecipe, kSboxionRows, kSboxionPatches};

} // namespace coop::lion
