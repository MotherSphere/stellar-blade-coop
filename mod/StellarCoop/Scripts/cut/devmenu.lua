-- coop devmenu: the rows of SB's developer cheat menu that still work in the shipping build, on a co-op save only. SB
-- ships the menu (WB_DebugCommand_Master, its tab and slot widgets, the DebugCommand UI definition) and its data
-- (CheatCommandTable, 7,139 rows over 18 tabs), but no UI logic for it: ESBUILogicType_DebugCommand (191) is not in
-- the game's logic registry, so the widget would open empty. Each row is a console command for USBCheatManager, and
-- 702 of its 703 exec functions are compiled out (they read their parameters and return), SBLoadingScreenFadeAuto
-- being the one with a body, in no row. What still runs is SB's logic job for the controller's Cheat request
-- (FSBCheat::Simulate), which knows six words; the table uses three of them in 87 rows: SBApplyEffectMe (82),
-- SBPlayerSP (4) and SBPlayerRevival (1). This file offers the SBApplyEffectMe rows that grant nothing by themselves
-- (no item, skill, quest step or trophy) and whose lasting effects a clear row ends, under names of its own, and sends
-- each through cut/chainspin.lua's one call (ChainSpin.apply, after ChainSpin.target's checks), as the menu's own rows
-- would have. Kills made with the help of the attack, gauge or enemy rows are still EVE's own: they count toward the
-- kill trophies (Trophy_CharKill_Beta, _Burst and _TachySkill among them) in the co-op save, as any kill does.
-- Left out, with why: the enemy kills and HP cuts (Test_EnemyKill, Test_EnemyKillToBoss, Test_EnemyHP1ToBoss, the
-- thirteen Test_EnemyHpDamage rows: our EVE would be the killer, with the kill's rewards, counters and boss trophies),
-- the ranged mode unlock (Eve_ModeOpen_TPS_Eff), the consumable stacks (T_StackConsumable1 to 7), FishingGod, the skill
-- points (SBPlayerSP), EVE's death and revival, the test stances and skills, the effects on every actor, and the ones
-- no clear row removes (NoDamageNoHitImmuneAbnormal_Infinite, the two 80 % damage cuts, T_Drone_NoCoolScan, and
-- Test_EnemyEffectGroggy, whose Test_GroggyInfinite on the enemies has the Groggy flag and no end).
-- Each effect's ID is read from the game's EffectTable by its name at each use (FindRow, a table always loaded), so
-- nothing of the table is copied here. The effects are not saved (bEnableSave is false on every one), so loading a
-- save should end them (not checked in game). Both dispel rows hand their targets Test_EffectDispelAll_Effect, which
-- removes the TestEffect flag on each; every lasting row's effect has that flag but nolockswitch's (LockOnDelivery,
-- which lockswitch removes). Their own flag lists (TestEffect, and Groggy for clear) most likely act on EVE, the
-- effect's owner, as the game's P_Eve_Stance_GunTutorial_End does (it targets the drone and removes EVE's stances), so
-- enemyclear probably ends EVE's lasting rows too. coop off runs clear and lockswitch once more (stop, below), even
-- after a Lua reload (coop-devmenu.txt).
local U=require('core.unreal')
local ChainSpin=require('cut.chainspin')
local DevMenu={}
local EFFECTS='/Game/Local/Data/EffectTable.EffectTable'
-- The rows: a name, its effects in the menu's order (one menu entry may run two), and what it does. Lasting ones stay
-- until clear (or enemyclear for enemies), coop off, a save load or the game's end; the others act once. The attack
-- rows add up (EffectOverlap_Overlap: +4 or +29 to the attack power rates at each run); the speed rows do not (Unique).
DevMenu.ROWS={
    {'nodamage',{'Test_NoDamageMe'},'EVE takes no damage (lasting)'},
    {'stealth',{'Test_Stealth'},'EVE is hidden from enemies (lasting)'},
    {'speed150',{'Test_MoveSpeed_150'},'EVE moves 1.5 times as fast (lasting)'},
    {'speed200',{'Test_MoveSpeed_200'},'EVE moves twice as fast (lasting)'},
    {'attack5',{'Test_PhysicDamageUpMe5','Test_ShieldDamageUpMe5'},'EVE deals 5 times the damage (lasting, adds up)'},
    {'attack30',{'Test_PhysicDamageUpMe30','Test_ShieldDamageUpMe30'},
        'EVE deals 30 times the damage (lasting, adds up)'},
    {'gauges',{'T_Eve_BetaGaugeRegen','T_Eve_Burst_Infinite'},'Beta and Burst gauges refill on their own (lasting)'},
    {'tachy',{'T_Eve_TachyGaugeRegen'},'the Tachy gauge refills on its own (lasting)'},
    {'tachyfull',{'T_Eve_TachyGaugeFull'},'the Tachy gauge full, once'},
    {'heal',{'Test_HPRecover100pMe'},"EVE's health full, once"},
    {'hp1',{'Test_StatSet_HP1'},"EVE's health set to 1, once"},
    {'nolockswitch',{'Off_LockOnDelivery'},'the lock-on stays off when its target dies (until lockswitch)'},
    {'lockswitch',{'Off_LockOnDelivery_Dispel'},'the lock-on moves to the next target again'},
    {'enemynodamage',{'Test_NoDamageEnemy'},'enemies near EVE take no damage (lasting)'},
    {'enemynoai',{'Test_EnemyBlockAI'},'enemies near EVE stop acting (lasting)'},
    {'enemyimmortal',{'Test_EnemyEffectImmortal'},'enemies near EVE cannot die (lasting)'},
    {'enemyshield1',{'Test_StatSet_Shield1Enemy'},"enemies near EVE: shield set to 1, once"},
    {'enemybalance1',{'Test_StatSet_Stamina1Enemy'},"enemies near EVE: balance set to 1, once"},
    {'enemyclear',{'Test_EffectDispelEnemy'},"the lasting rows' effects off the enemies near EVE (likely off EVE too)"},
    {'clear',{'Test_EffectDispelAll'},"the lasting rows' effects off EVE and the enemies near her"},
}
local BY={}
for _,r in ipairs(DevMenu.ROWS) do BY[r[1]]=r end
function DevMenu.row(name) return BY[name] end -- The row of that name, or nil.
local USE='Use: coop devmenu [list|<row>]'
local function why(e) return (tostring(e):gsub('^.-:%d+: ','')) end -- Without the file and line.
-- An effect's EffectTable ID by its row name, or nil when this game has no such row.
function DevMenu.effect_id(name)
    local row=U.find(EFFECTS):FindRow(name)
    if row==nil then return nil end
    return math.tointeger(tonumber(U.value_of(row.ID)))
end
-- The list as one line: each name and what it does.
function DevMenu.list()
    local out={}
    for _,r in ipairs(DevMenu.ROWS) do out[#out+1]=r[1]..': '..r[3] end
    return table.concat(out,'; ')
end
-- o: log(text) writes a [DM] line; status() is the native part's status text; store (coop-devmenu.txt through
-- link.store; nil without the native part) keeps across Lua loads that a row reached the game. coop devmenu's slot
-- check is commands/cut.lua's.
function DevMenu.new(o)
    local log,status=o.log,o.status
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local self={row=DevMenu.row}
    -- A row reached the game in this Lua load or an earlier one, so stop has something to end. shortcut: the file
    -- outlives a game exit without coop off (the effects do not), so the next run's first coop off dispels once with
    -- nothing to remove; a per-run token would end that.
    local asked=store.load()~=nil
    -- One row by name: every ID first, so a row runs whole or not at all, then the target and the calls.
    local function run(name)
        local row=BY[name]
        local ids={}
        for i,effect in ipairs(row[2]) do
            local ok,id=pcall(DevMenu.effect_id,effect)
            if not ok then return false,'the EffectTable cannot be read: '..why(id) end
            if not id then return false,effect..' is not in this game\'s EffectTable: nothing asked' end
            ids[i]=id
        end
        local guid,pc=ChainSpin.target(status())
        if not guid then return false,pc end
        for i,id in ipairs(ids) do
            local called,e=pcall(ChainSpin.apply,pc,guid,id)
            if not called then
                log('devmenu '..name..' failed at '..row[2][i]..': '..why(e))
                return false,'the game call failed: '..why(e)
            end
            if not asked then
                asked=true
                store.save('asked')
            end
            log(string.format('devmenu %s: SBApplyEffectMe %s (%d) on EVE (guid %d)',name,row[2][i],id,guid))
        end
        return true,'devmenu '..name..' asked of the game: '..row[3]
    end
    function self.command(name,extra)
        if extra~=nil then return false,USE end
        if name==nil or name=='list' then return true,'coop devmenu rows: '..DevMenu.list() end
        if not BY[name] then return false,USE..'; rows: coop devmenu list' end
        return run(name)
    end
    -- coop off, before it asks the native part off (the engine line still reads warp= and me=; after it no command
    -- reaches this file): clear and lockswitch once, when a row was asked in this Lua load or an earlier one. A dispel
    -- with nothing to remove changes nothing, so any row counts. One try: refused (a warp under way, no EVE), the
    -- effects stay until a save load or the game's end, and clear reaches only the enemies near EVE then.
    function self.stop()
        if not asked then return end
        for _,name in ipairs({'clear','lockswitch'}) do
            local ok,said=run(name)
            if not ok then log('coop off: devmenu '..name..' not asked: '..said) end
        end
        asked=false
        store.clear()
    end
    return self
end
return DevMenu
