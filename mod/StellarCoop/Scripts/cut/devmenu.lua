-- coop devmenu: the rows of SB's developer cheat menu that still work in the shipping build, on a co-op save only. SB
-- ships the menu (WB_DebugCommand_Master, its tab and slot widgets, the DebugCommand UI definition) and its data
-- (CheatCommandTable, 7,139 rows over 18 tabs), but no UI logic for it: ESBUILogicType_DebugCommand (191) is not in
-- the game's logic registry, so the widget would open empty. Each row is a console command for USBCheatManager, and
-- 702 of its 703 exec functions are compiled out (they read their parameters and return), SBLoadingScreenFadeAuto
-- being the one with a body, in no row. What still runs is SB's logic job for the controller's Cheat request
-- (FSBCheat::Simulate), which knows six words; the table uses three of them in 87 rows: SBApplyEffectMe (82),
-- SBPlayerSP (4) and SBPlayerRevival (1). This file offers the SBApplyEffectMe rows whose effect grants nothing that
-- counts toward a trophy or stays in the save, under names of its own, and sends each through cut/chainspin.lua's one
-- call (ChainSpin.apply, after ChainSpin.target's checks), as the menu's own rows would have.
-- Left out, with why: the enemy kills and HP cuts (Test_EnemyKill, Test_EnemyKillToBoss, Test_EnemyHP1ToBoss, the
-- twelve Test_EnemyHpDamage rows: our EVE would be the killer, with the kill's rewards, counters and boss trophies),
-- the ranged mode unlock (Eve_ModeOpen_TPS_Eff), the consumable stacks (T_StackConsumable1 to 7), FishingGod, the skill
-- points (SBPlayerSP), EVE's death and revival, the test stances and skills, the effects on every actor, and the ones
-- no clear row removes (NoDamageNoHitImmuneAbnormal_Infinite, the two 80 % damage cuts, T_Drone_NoCoolScan).
-- Each effect's ID is read from the game's EffectTable by its name at each use (FindRow, a table always loaded), so
-- nothing of the table is copied here. The effects are not saved (bEnableSave is false on every one): loading a save
-- ends them, as does clear for the lasting ones (TestEffect and Groggy flags).
local U=require('core.unreal')
local ChainSpin=require('cut.chainspin')
local DevMenu={}
local EFFECTS='/Game/Local/Data/EffectTable.EffectTable'
-- The rows: a name, its effects in the menu's order (one menu entry may run two), and what it does. Lasting ones stay
-- until clear (or enemyclear for enemies), a save load or the game's end; the others act once.
DevMenu.ROWS={
    {'nodamage',{'Test_NoDamageMe'},'EVE takes no damage (lasting)'},
    {'stealth',{'Test_Stealth'},'EVE is hidden from enemies (lasting)'},
    {'speed150',{'Test_MoveSpeed_150'},'EVE moves 1.5 times as fast (lasting)'},
    {'speed200',{'Test_MoveSpeed_200'},'EVE moves twice as fast (lasting)'},
    {'attack5',{'Test_PhysicDamageUpMe5','Test_ShieldDamageUpMe5'},'EVE deals 5 times the damage (lasting)'},
    {'attack30',{'Test_PhysicDamageUpMe30','Test_ShieldDamageUpMe30'},'EVE deals 30 times the damage (lasting)'},
    {'gauges',{'T_Eve_BetaGaugeRegen','T_Eve_Burst_Infinite'},'Beta and Burst gauges refill on their own (lasting)'},
    {'tachy',{'T_Eve_TachyGaugeRegen'},'the Tachy gauge refills on its own (lasting)'},
    {'tachyfull',{'T_Eve_TachyGaugeFull'},'the Tachy gauge full, once'},
    {'heal',{'Test_HPRecover100pMe'},"EVE's health full, once"},
    {'hp1',{'Test_StatSet_HP1'},"EVE's health set to 1, once"},
    {'nolockswitch',{'Off_LockOnDelivery'},'the lock-on stays off when its target dies (until lockswitch)'},
    {'lockswitch',{'Off_LockOnDelivery_Dispel'},'the lock-on moves to the next target again'},
    {'enemynodamage',{'Test_NoDamageEnemy'},'enemies near EVE take no damage (lasting)'},
    {'enemynoai',{'Test_EnemyBlockAI'},'enemies near EVE stop acting (lasting)'},
    {'enemygroggy',{'Test_EnemyEffectGroggy'},'enemies near EVE stay stunned (lasting)'},
    {'enemyimmortal',{'Test_EnemyEffectImmortal'},'enemies near EVE cannot die (lasting)'},
    {'enemyshield1',{'Test_StatSet_Shield1Enemy'},"enemies near EVE: shield set to 1, once"},
    {'enemybalance1',{'Test_StatSet_Stamina1Enemy'},"enemies near EVE: balance set to 1, once"},
    {'enemyclear',{'Test_EffectDispelEnemy'},"the lasting rows' effects off the enemies near EVE"},
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
-- o: log(text) writes a [DM] line; status() is the native part's status text. coop devmenu's slot check is
-- commands/cut.lua's.
function DevMenu.new(o)
    local log,status=o.log,o.status
    local self={row=DevMenu.row}
    function self.command(name,extra)
        if extra~=nil then return false,USE end
        if name==nil or name=='list' then return true,'coop devmenu rows: '..DevMenu.list() end
        local row=BY[name]
        if not row then return false,USE..'; rows: coop devmenu list' end
        -- Every ID first, so a row runs whole or not at all.
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
            log(string.format('devmenu %s: SBApplyEffectMe %s (%d) on EVE (guid %d)',name,row[2][i],id,guid))
        end
        return true,'devmenu '..name..' asked of the game: '..row[3]
    end
    return self
end
return DevMenu
