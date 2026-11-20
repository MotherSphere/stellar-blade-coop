// Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
// SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
// SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
// Gun mode's rounds batch (kNikkeRecipe, request word "nikke"), asked by fight/gunmode/nikke.lua at the title on the
// co-op save files. The rifle's round is SB's own ItemTable row Bullet_Nikke (ID 37): the round the NIKKE stage hands
// EVE (the game constant NikkeStage_ChangeBullet, default text at 0x145d3c038; FUN_141c30030 sets it as her current
// bullet). The row ships, so a save that holds rounds always finds it, and this batch leaves it as it is. The batch
// adds where to get it:
//   - drops: 8 RewardGroupTable rows, each a copy of a shipped row of an ammo group that enemies or supply boxes roll
//     (its ItemAlias, DropRate and counts changed, its Group kept). Every one of those groups is RandomEach. SB
//     resolves a row naming an ItemAlias in FUN_141bea040: count rand(ItemMinCount, ItemMaxCount). AddRow
//     (0x1441815b0) puts the row in the table's index of Group (FUN_144182060, table +0x170), which the group query
//     reads.
//   - the shop: the ShopItemTable row Camp_Bullet_Nikke_Buy (a copy of Camp_Bullet_Normal_Buy: ShopType Buy, gold),
//     then the three camp vending machines' ShopTable rows patched in place with it added to ShopItems. Their other
//     items and their order are the shipped ones (the build 26123051 dump). SB's FSBActorBuyItem (FUN_141bbe480) sells
//     any item a shop lists in ShopItems whose ShopItemTable row names it with ShopType Buy or Exchange.
// Row sizes and field offsets read in Ghidra on build 26123051: SBRewardGroupTableProperty FStructParams 0x146db2a30
// (0x80 bytes), its ItemAlias 0x145e0f998 (+0x28), DropRate 0x145e0f830 (+0x54), ItemMinCount 0x145e0f750 (+0x58),
// ItemMaxCount 0x145e0f728 (+0x5c); SBShopItemTableProperty 0x146db1d10 (0xa0), its ItemAlias 0x145e1acb8 (+0x18),
// MoneyItemCount1 0x145e1ac18 (+0x34), CheckConditionGroup 0x145e1aa00 (+0x7c), FriendShip 0x145e198e8 (+0x90);
// SBShopTableProperty 0x146db1d60 (0xa8), its ShopItems 0x145e197b8 (+0x38). Donor rows, their groups and the free IDs
// from the build 26123051 table dumps; rows/rows.h refuses an ID SB already holds.
#pragma once

#include "rows/rows.h"

namespace coop::lion {

// The rifle's round, a shipped ItemTable row.
constexpr char kNikkeRound[] = "Bullet_Nikke";
// Gold a round costs in the camp vending machines.
constexpr int kNikkePrice = 2;

constexpr Patch kNikkePatches[] = {
    // 31114: subGroup_FA_Normal_Bullet (RandomEach), over its Bullet_Scatter row 200026
    {0x28, Kind::name, 0, kNikkeRound}, // ItemAlias
    {0x54, Kind::i32, 1500, nullptr},   // DropRate
    {0x58, Kind::i32, 15, nullptr},     // ItemMinCount
    {0x5c, Kind::i32, 30, nullptr},     // ItemMaxCount
    // 31115: subGroup_FA_Normal3_Bullet (RandomEach), over its Bullet_Scatter row 200030
    {0x28, Kind::name, 0, kNikkeRound}, // ItemAlias
    {0x54, Kind::i32, 2000, nullptr},   // DropRate
    {0x58, Kind::i32, 20, nullptr},     // ItemMinCount
    {0x5c, Kind::i32, 40, nullptr},     // ItemMaxCount
    // 31116: subGroup_global_Normal_Bullet (RandomEach), over its Bullet_Scatter row 200016
    {0x28, Kind::name, 0, kNikkeRound}, // ItemAlias
    {0x54, Kind::i32, 1000, nullptr},   // DropRate
    {0x58, Kind::i32, 10, nullptr},     // ItemMinCount
    {0x5c, Kind::i32, 20, nullptr},     // ItemMaxCount
    // 31117: subGroup_global_Normal3_Bullet (RandomEach), over its Bullet_Scatter row 200020
    {0x28, Kind::name, 0, kNikkeRound}, // ItemAlias
    {0x54, Kind::i32, 1500, nullptr},   // DropRate
    {0x58, Kind::i32, 15, nullptr},     // ItemMinCount
    {0x5c, Kind::i32, 30, nullptr},     // ItemMaxCount
    // 31118: subGroup_FA_BodyBag_Bullet (RandomEach), over its Bullet_Scatter row 200035
    {0x28, Kind::name, 0, kNikkeRound}, // ItemAlias
    {0x54, Kind::i32, 3000, nullptr},   // DropRate
    {0x58, Kind::i32, 30, nullptr},     // ItemMinCount
    {0x5c, Kind::i32, 60, nullptr},     // ItemMaxCount
    // 31119: subGroup_Raven_Bullet (RandomEach), over its Bullet_Scatter row 220025
    {0x28, Kind::name, 0, kNikkeRound}, // ItemAlias
    {0x54, Kind::i32, 3000, nullptr},   // DropRate
    {0x58, Kind::i32, 30, nullptr},     // ItemMinCount
    {0x5c, Kind::i32, 60, nullptr},     // ItemMaxCount
    // 31120: subGroup_FA_Animal_Bullet (RandomEach), over its Bullet_Normal row 200024 (its only row)
    {0x28, Kind::name, 0, kNikkeRound}, // ItemAlias
    {0x54, Kind::i32, 1000, nullptr},   // DropRate
    {0x58, Kind::i32, 10, nullptr},     // ItemMinCount
    {0x5c, Kind::i32, 20, nullptr},     // ItemMaxCount
    // 31121: subGroup_b_standard_Bullet_Random (RandomEach, supply boxes), over its Bullet_Scatter row 31105
    {0x28, Kind::name, 0, kNikkeRound}, // ItemAlias
    {0x54, Kind::i32, 5000, nullptr},   // DropRate
    {0x58, Kind::i32, 20, nullptr},     // ItemMinCount
    {0x5c, Kind::i32, 40, nullptr},     // ItemMaxCount
    // Camp_Bullet_Nikke_Buy (ShopItemTable), over Camp_Bullet_Normal_Buy: sold for gold with no condition. The donor's
    // CG_TPSMode_Opened is the drone's gun, not the rifle's.
    {0x18, Kind::name, 0, kNikkeRound},             // ItemAlias
    {0x34, Kind::i32, kNikkePrice, nullptr},        // MoneyItemCount1
    {0x7c, Kind::name, 0, "None"},                  // CheckConditionGroup
    {0x90, Kind::f32, float(kNikkePrice), nullptr}, // FriendShip (the donor holds its price)
    // Shop_SimpleCamp (ShopTable 1001), in place: its shipped ShopItems with the round after the drone's
    {0x38, Kind::names, 0,
     "Camp_ResurrectionItem_x3_Buy|Camp_HP_Potion_Buy|Camp_HP_Potion_Small_Buy|Camp_Bullet_Package_Dummy_Buy|"
     "Camp_Bullet_Normal_Buy|Camp_Bullet_Scatter_Buy|Camp_Bullet_Explosive_Buy|Camp_Bullet_Missile_Buy|"
     "Camp_Bullet_Railgun_Buy|Camp_Bullet_Nikke_Buy|Camp_ConcussionGrenade_Buy|Camp_PulseGrenade_Buy|"
     "Camp_FlashGrenade_Buy|Camp_TrapGrenade_Buy|Camp_HealGrenade_Buy|Camp_SPInitializer_Buy"},
    // Shop_FullCamp (ShopTable 1002), in place: the same list
    {0x38, Kind::names, 0,
     "Camp_ResurrectionItem_x3_Buy|Camp_HP_Potion_Buy|Camp_HP_Potion_Small_Buy|Camp_Bullet_Package_Dummy_Buy|"
     "Camp_Bullet_Normal_Buy|Camp_Bullet_Scatter_Buy|Camp_Bullet_Explosive_Buy|Camp_Bullet_Missile_Buy|"
     "Camp_Bullet_Railgun_Buy|Camp_Bullet_Nikke_Buy|Camp_ConcussionGrenade_Buy|Camp_PulseGrenade_Buy|"
     "Camp_FlashGrenade_Buy|Camp_TrapGrenade_Buy|Camp_HealGrenade_Buy|Camp_SPInitializer_Buy"},
    // Shop_NestCamp (ShopTable 1003), in place: its own first item (one resurrection item, not three)
    {0x38, Kind::names, 0,
     "Camp_ResurrectionItem_Buy|Camp_HP_Potion_Buy|Camp_HP_Potion_Small_Buy|Camp_Bullet_Package_Dummy_Buy|"
     "Camp_Bullet_Normal_Buy|Camp_Bullet_Scatter_Buy|Camp_Bullet_Explosive_Buy|Camp_Bullet_Missile_Buy|"
     "Camp_Bullet_Railgun_Buy|Camp_Bullet_Nikke_Buy|Camp_ConcussionGrenade_Buy|Camp_PulseGrenade_Buy|"
     "Camp_FlashGrenade_Buy|Camp_TrapGrenade_Buy|Camp_HealGrenade_Buy|Camp_SPInitializer_Buy"},
};
// The drops first (each stands alone), then the shop item, then the three shops that list it, once it is in.
constexpr Row kNikkeRecipe[] = {
    {Table::reward, "31114", "200026", 31114u, 0, 4},
    {Table::reward, "31115", "200030", 31115u, 4, 4},
    {Table::reward, "31116", "200016", 31116u, 8, 4},
    {Table::reward, "31117", "200020", 31117u, 12, 4},
    {Table::reward, "31118", "200035", 31118u, 16, 4},
    {Table::reward, "31119", "220025", 31119u, 20, 4},
    {Table::reward, "31120", "200024", 31120u, 24, 4},
    {Table::reward, "31121", "31105", 31121u, 28, 4},
    {Table::shopitem, "Camp_Bullet_Nikke_Buy", "Camp_Bullet_Normal_Buy", 37u, 32, 4},
    {Table::shop, "Shop_SimpleCamp", "Shop_SimpleCamp", 1001u, 36, 1},
    {Table::shop, "Shop_FullCamp", "Shop_FullCamp", 1002u, 37, 1},
    {Table::shop, "Shop_NestCamp", "Shop_NestCamp", 1003u, 38, 1},
};
constexpr size_t kNikkeRows = sizeof kNikkeRecipe / sizeof kNikkeRecipe[0];
static_assert(sizeof kNikkePatches / sizeof kNikkePatches[0] == 39, "every row's patches");
constexpr Batch kNikke{"nikke", kNikkeRecipe, kNikkeRows, kNikkePatches};

} // namespace coop::lion
