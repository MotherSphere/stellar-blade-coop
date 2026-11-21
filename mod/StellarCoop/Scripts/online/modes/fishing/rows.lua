-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The 40 rows of SB's /Game/Local/Data/ItemFishTable by name, in the table's order: the 34 rows Fish_GoldFish to
-- Fish_Box4, then the six NIKKE fish. ItemTable has a row of each name. Names only: each game reads a row's ItemTable
-- ID and its points (RewardItemCount) at run time, so the repo holds no value of SB's tables. Read in the 12 base
-- containers of build 26123051.
return {
    'Fish_GoldFish','Fish_Goby','Fish_Betta','Fish_ButterflyFish','Fish_PorcupineFish','Fish_FlyingFish',
    'Fish_Triggerfish','Fish_FootBallfish','Fish_SeaBass','Fish_mackerel','Fish_SeaBream','Fish_FancyCarp',
    'Fish_ChannelCatfish','Fish_Salmon','Fish_Mahimahi','Fish_Halibut','Fish_MolaMola','Fish_SailFish','Fish_Tuna',
    'Fish_Arowana','Fish_Pirarucu','Fish_GreatWhiteShark','Fish_WhaleShark','Fish_Dunkleosteus','Fish_Lobster',
    'Fish_FishCake','Fish_Tire','Fish_NuclearWaste','Fish_CannedFish','Fish_CannerHam','Fish_Box1','Fish_Box2',
    'Fish_Box3','Fish_Box4',
    'Fish_Nikke_Poli','Fish_Nikke_Tape','Fish_Nikke_Glasses','Fish_Nikke_Rapunzel','Fish_Nikke_Laplace',
    'Fish_Nikke_SnowWhite',
}
