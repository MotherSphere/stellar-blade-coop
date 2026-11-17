-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The zone-event rows gun mode fires on EVE through SBBlueprintLibrary.CreateSBZoneEvent(type, row): type 2 attaches
-- an EventActorEffectTable effect, type 13 runs an EventItemActionTable action. The NGM_* rows are added to Survival
-- Protocol's pak RoguelikeMode_P by tools/gunmode/build/build_sp_rows.py (data/gunmode/patches, and EffectTable's
-- NGM_Fire); the two others are SB's own (the drone's lock lifted, the drone summoned again). The order of on() copies
-- a NIKKE stage's start: the ammo item first, the opening reload, then the mode and the stat bars.
local Rows={}

Rows.EFFECT,Rows.ITEM=2,13

-- The rows that turn gun mode on, for settings s ({real_ammo=bool}).
function Rows.on(s)
    local rows={}
    if not s.real_ammo then rows[#rows+1]={13,'NGM_ItemA_Ammo'} end -- +60 rounds; with real ammo, a starter once.
    rows[#rows+1]={2,'NGM_AE_Reload'}
    rows[#rows+1]={2,'NGM_AE_GunOn'}
    rows[#rows+1]={2,'NGM_AE_Beta'}
    if not s.real_ammo then rows[#rows+1]={2,'NGM_AE_Ammo'} end -- The magazine kept at 60.
    if s.real_ammo then rows[#rows+1]={2,'NGM_AE_RealAmmo'} end -- The NIKKE auto-reload waits while this is on.
    rows[#rows+1]={2,'NGM_AE_Peace'} -- PeacefulMode_Infinite, as a stage applies (no sword flash on battle start).
    return rows
end

-- The rows that turn it off, the drone given back last.
Rows.OFF={{2,'NGM_AE_PeaceOff'},{2,'NGM_AE_GunOff'},{2,'NGM_AE_PosOff'},{2,'NGM_AE_BetaOff'},
    {2,'NGM_AE_DroneFree'},{2,'Xion_11_E_ActorEff_001'},{2,'CGH_data_E_ActorEff_003'}}

return Rows
