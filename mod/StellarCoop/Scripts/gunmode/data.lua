-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's game data, without a pak of tables: SB's own rows, used as they are or borrowed while gun mode is on and
-- put back when it goes off. Only fields of rows FindRow gives are written (live data, as gunmode/aim.lua writes the
-- projectile row); no row is added: UE4SS's AddRow given a copied row crashed the game (11-17).
-- * EventActorEffectTable (fired as zone events by gunmode/rows.lua): SB's own NIKKE rows where one applies the effect
--   (the cover positions, the gun off, the drone); for the others, rows of the NIKKE missions' drone summons and a
--   spare position row, their ActorEffectAlias pointed at gun mode's effect while it is on.
-- * EffectTable, only with fire_effect (gun_fire_effect=on, a test): M_Scarlet_CounterLinkStart (0.1 s on self, one
--   UseSkill action) starts P_Eve_GunNikke_ShootSlug1_1: the shot, started without the stance's fire command. Off by
--   default: UE4SS's FindRow on EffectTable crashed the game in its copy of the row, some times out of some (11-17).
--   Without it the stance's own fire command shoots (aimed: Ctrl / L2 held, LMB / R2).
-- * SkillCommandTable: the NIKKE fire commands ShootSlug1_1 and _2 take the burst shot's command type
--   (RangedFireSkill: no check of the equipped bullet), as zNikkeGunMode_P did.
-- * SkillActiveStepTable: the shot's Hit1 step takes its Cast1 step's type (fires its projectile, spends no round).
-- Everything goes back at put_back() (gun mode off, a new world), so the NIKKE missions find their rows as shipped.
-- Neither Survival Protocol's pak nor zNikkeGunMode_P is needed.
local Data={}

local BASE='/Game/Local/Data/'
-- Rows used as SB ships them: logical name -> row (its effect, for the check).
Data.OWN={
    Pos2={'Nikke_01_E_ActorEff_012','P_Eve_GunNikke_Position2'},
    PosOff={'Nikke_01_E_ActorEff_011','P_Eve_GunNikke_Position_Dispel'},
    GunOff={'Nikke_03_E_ActorEff_021','P_Eve_GunNikke_Dispel'},
    DroneFree={'Xion_11_E_ActorEff_001','P_EVE_DoNotSummonDrone_Dispel'},
    Drone={'CGH_data_E_ActorEff_003','P_Eve_Sword_SummonDrone'},
}
-- Rows borrowed while gun mode is on: logical name -> {row, the effect gun mode points it at}. All of them NIKKE
-- mission rows (drone summons and a spare position row), unused outside those missions.
Data.FIRE_EFFECT='M_Scarlet_CounterLinkStart'
Data.BORROWED={
    GunOn={'Nikke_01_E_ActorEff_041','P_Eve_GunNikke'},
    Reload={'Nikke_06_E_ActorEff_041','P_Eve_GunNikke_ReloadStartDelay'},
    Beta={'Nikke_00_Battle_E_ActorEff_002','P_Eve_GunNikke_MaxBetaGauge100'},
    BetaOff={'Nikke_Stage01_E_ActorEff_002','P_Eve_GunNikke_MaxBetaGauge100_Dispel'},
    Ammo={'Nikke_Stage02_E_ActorEff_002','P_Eve_GunNikke_BurstSkillReloadCompleted'},
    Peace={'Nikke_03_E_ActorEff_002','PeacefulMode_Infinite'},
    PeaceOff={'Nikke_05_E_ActorEff_017','PeacefulMode_Infinite_Dispel'},
    Fire={'Nikke_01_E_ActorEff_015',Data.FIRE_EFFECT},
}
Data.BORROW_ORDER={'GunOn','Reload','Beta','BetaOff','Ammo','Peace','PeaceOff','Fire'} -- Fire: fire_effect only.
Data.FIRE_SKILL='P_Eve_GunNikke_ShootSlug1_1'
Data.FIRE_COMMANDS={'P_Eve_GunNikke_ShootSlug1_1','P_Eve_GunNikke_ShootSlug1_2'}
Data.BURST_COMMAND='P_Eve_GunNikke_ShootSlug2_1'
Data.HIT_STEP,Data.CAST_STEP='P_Eve_GunNikke_ShootSlug1_1_Hit1','P_Eve_GunNikke_ShootSlug1_1_Cast1'

-- The row name for logical name k ('GunOn', 'Fire', ...), or nil.
function Data.row(k)
    local e=Data.OWN[k] or Data.BORROWED[k]
    return e and e[1]
end

-- g: gun mode's shared state (log, try, valid). Returns an object: take() points the rows at gun mode's data (true,
-- or false and why), put_back() restores what take() changed.
function Data.new(g,fire_effect)
    local self={saved=nil,fire=fire_effect==true}
    local function tbl(name)
        local t=g.try(function() return StaticFindObject(BASE..name..'.'..name) end)
        assert(g.valid(t),'no '..name)
        return t
    end
    local function text(v) return g.try(function() return v:ToString() end) or tostring(v) end
    local trace=true -- The first take logs each row it reads (a crash in one showed no line, 11-17).
    local function row(t,name)
        if trace then g.log('data: row '..name) end
        local r=g.try(function() return t:FindRow(name) end)
        assert(r,'no row '..name)
        return r
    end

    function self.take()
        if self.saved then return true end
        local saved={}
        local ok,err=pcall(function()
            local eae=tbl('EventActorEffectTable')
            for k,e in pairs(Data.OWN) do
                local got=text(row(eae,e[1]).ActorEffectAlias)
                assert(got==e[2],e[1]..' applies '..got..', not '..e[2])
            end
            local spare=nil -- NIKKE mission rows to borrow in place of one this game version lacks.
            local function take_spare(used)
                if not spare then
                    spare={}
                    g.try(function() eae:ForEachRow(function(name)
                        local n=text(name)
                        if n:match('^Nikke_') then spare[#spare+1]=n end
                    end) end)
                    table.sort(spare)
                end
                for _,n in ipairs(spare) do if not used[n] then used[n]=true; return n end end
            end
            local used={}
            for _,e in pairs(Data.OWN) do used[e[1]]=true end
            for _,e in pairs(Data.BORROWED) do used[e[1]]=true end
            for _,k in ipairs(Data.BORROW_ORDER) do
                local e=(k~='Fire' or self.fire) and Data.BORROWED[k]
                if e and trace then g.log('data: has '..e[1]) end
                if e and not g.try(function() return eae:FindRow(e[1]) end) then
                    local n=take_spare(used)
                    assert(n,'no spare row for '..k)
                    g.log('data: '..e[1]..' missing, borrowing '..n..' for '..k)
                    e[1]=n
                end
                if e then
                    local r=row(eae,e[1])
                    saved[#saved+1]={r,'ActorEffectAlias',FName(text(r.ActorEffectAlias))}
                    r.ActorEffectAlias=FName(e[2])
                end
            end
            if self.fire then
                local fire=row(tbl('EffectTable'),Data.FIRE_EFFECT)
                saved[#saved+1]={fire,'ActionValue1',FName(text(fire.ActionValue1))}
                fire.ActionValue1=FName(Data.FIRE_SKILL)
            end
            local cmd=tbl('SkillCommandTable')
            local kind=row(cmd,Data.BURST_COMMAND).CommandActionType
            for _,name in ipairs(Data.FIRE_COMMANDS) do
                local r=row(cmd,name)
                saved[#saved+1]={r,'CommandActionType',r.CommandActionType}
                r.CommandActionType=kind
            end
            if trace then g.log('data: steps') end
            local step=g.try(function() return tbl('SkillActiveStepTable') end)
            local hit=step and g.try(function() return step:FindRow(Data.HIT_STEP) end)
            local cast=step and g.try(function() return step:FindRow(Data.CAST_STEP) end)
            if hit and cast then
                saved[#saved+1]={hit,'StepType',hit.StepType}
                hit.StepType=cast.StepType
            end
        end)
        if not ok then
            for i=#saved,1,-1 do local e=saved[i]; pcall(function() e[1][e[2]]=e[3] end) end
            g.log('data: not taken ('..tostring(err)..')')
            return false,err
        end
        self.saved=saved
        trace=false
        g.log('data: '..#saved..' fields of SB\'s rows taken for gun mode')
        return true
    end

    function self.put_back()
        local saved=self.saved
        self.saved=nil
        if not saved then return end
        for i=#saved,1,-1 do local e=saved[i]; pcall(function() e[1][e[2]]=e[3] end) end
        g.log('data: SB\'s rows put back')
    end

    return self
end

return Data
