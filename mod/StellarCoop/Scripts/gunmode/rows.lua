-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The zone-event rows gun mode fires on EVE through SBBlueprintLibrary.CreateSBZoneEvent(type, row): type 2 attaches
-- an EventActorEffectTable effect, type 13 runs an EventItemActionTable action. Namespace 'GM': SB's own rows, used or
-- borrowed by gunmode/data.lua (Data.row names them); 'NGM': the NGM_AE_* rows a Survival Protocol pak built with gun
-- mode's patches carries (with its +60 NIKKE rounds item). The order of on() copies a NIKKE stage's start: the ammo
-- first, the opening reload, then the mode and the stat bars.
local Rows={}
local Data=require('gunmode.data')

Rows.EFFECT,Rows.ITEM=2,13

local function row(ns,k)
    if ns=='GM' then return {2,Data.row(k)} end
    return {2,ns..'_AE_'..k}
end

-- The rows that turn gun mode on, for settings s ({real_ammo=bool}) and rows of namespace ns ('GM' or 'NGM').
function Rows.on(s,ns)
    ns=ns or 'GM'
    local rows={}
    if ns=='NGM' and not s.real_ammo then rows[#rows+1]={13,'NGM_ItemA_Ammo'} end -- +60 rounds (that pak's item).
    rows[#rows+1]=row(ns,'Reload')
    rows[#rows+1]=row(ns,'GunOn')
    rows[#rows+1]=row(ns,'Beta')
    if not s.real_ammo then rows[#rows+1]=row(ns,'Ammo') end -- The magazine kept full.
    if s.real_ammo and ns=='NGM' then rows[#rows+1]={2,'NGM_AE_RealAmmo'} end -- Its reload waits while this is on.
    rows[#rows+1]=row(ns,'Peace') -- PeacefulMode_Infinite, as a stage applies (no sword flash on battle start).
    return rows
end

-- The rows that turn it off, the drone given back last (SB's own rows: its lock lifted, the drone summoned).
function Rows.off(ns)
    ns=ns or 'GM'
    return {row(ns,'PeaceOff'),row(ns,'GunOff'),row(ns,'PosOff'),row(ns,'BetaOff'),row(ns,'DroneFree'),
        {2,'Xion_11_E_ActorEff_001'},{2,'CGH_data_E_ActorEff_003'}}
end

-- A single row of the namespace: 'Pos2', 'PosOff', 'GunOn', 'Fire', ...
function Rows.one(ns,k) return row(ns or 'GM',k) end

return Rows
