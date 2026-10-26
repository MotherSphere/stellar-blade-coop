-- coop devmenu (cut/devmenu.lua) over fakes: the game's EffectTable (FindRow by name, an ID field, a raising lookup),
-- the native status text, EVE and the player controller (nightop/probe.lua's her and controller, through the real
-- cut/chainspin.lua) and the controller's Cheat request, recorded or raising. Covered: the rows' names are unique and
-- none sends an effect left out on purpose; the list names every row; a bare word, list, an unknown name and an extra
-- word ask nothing; a row sends SBApplyEffectMe with each of its effects' IDs as read from the table, on EVE's GUID, in
-- the menu's order; a row with an effect the table lacks, or a table that cannot be read, asks nothing; ChainSpin's
-- target refusals ask nothing; a call that raises stops the row there; an ID of 0 or below from the table never
-- reaches the game; stop (coop off) asks clear then lockswitch once after a row reached the game, and nothing before.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local calls,raise={},nil
local pc={ServerRequest_Cheat=function(_,...)
    calls[#calls+1]=table.pack(...)
    if raise and #calls>=raise.at then error(raise.e) end
end}
local her,controller={},pc
package.loaded['nightop.probe']={her=function() return her end,controller=function() return controller end}
local ids,table_raises={},nil
local found={}
package.loaded['core.unreal']={
    find=function(path)
        found[#found+1]=path
        return {FindRow=function(_,name)
            if table_raises then error(table_raises) end
            return ids[name] and {ID={get=function() return ids[name] end}} or nil
        end}
    end,
    value_of=function(v) return type(v)=='table' and v.get and v.get() or v end}
local D=require('cut.devmenu')

-- 1. The rows: unique names, and none of the effects the header leaves out.
local LEFT_OUT={Test_EnemyKill=1,Test_EnemyKillToBoss=1,Test_EnemyHP1ToBoss=1,Eve_ModeOpen_TPS_Eff=1,FishingGod=1,
    Test_HPReduce100pMe=1,Test_EffectDispelMe=1,T_Eve_TestSkill=1,T_Eve_RangeMode=1,P_Eve_Passive_RangeMode=1,
    P_Eve_Stance_BlockSword=1,P_Eve_BlockSword_ForCheat=1,P_Eve_BlockSword_End=1,Test_MaxHPUpAll=1,Test_MaxShieldUpAll=1,
    NoDamageNoHitImmuneAbnormal_Infinite=1,Test_FinalHPDamageReduce_080p=1,Test_FinalShieldDamageReduce_080p=1,
    T_Drone_NoCoolScan=1,Test_EnemyEffectGroggy=1}
local seen={}
for _,r in ipairs(D.ROWS) do
    assert(not seen[r[1]] and r[1]:match('^%l[%l%d]*$'),r[1])
    seen[r[1]]=true
    assert(#r[2]>=1 and type(r[3])=='string' and D.row(r[1])==r,r[1])
    for _,e in ipairs(r[2]) do
        assert(not LEFT_OUT[e] and not e:find('EnemyHpDamage',1,true) and not e:find('StackConsumable',1,true),e)
    end
end
assert(#D.ROWS==20 and D.row('nope')==nil)
for _,r in ipairs(D.ROWS) do assert(D.list():find(r[1]..': '..r[3],1,true),r[1]) end

-- 2. The command over a status, a log and the table.
local status_text
local function status_with(warp,me) status_text='mod=v\nengine=on peers=0 warp='..warp..' me='..me..'\nslot=coop\n' end
local lines={}
local dm=D.new({log=function(m) lines[#lines+1]=m end,status=function() return status_text end})
status_with('idle',228)
local USE='Use: coop devmenu [list|<row>]'
local ok,why=dm.command()
assert(ok and why=='coop devmenu rows: '..D.list() and #calls==0,why)
assert(select(2,dm.command('list'))==why)
assert(select(2,dm.command('nope'))==USE..'; rows: coop devmenu list' and #calls==0)
assert(select(2,dm.command('heal','x'))==USE and #calls==0)
assert(dm.row('heal')==D.row('heal'),'The instance answers row too')
-- A row of two effects: both IDs as the table gives them, in order, on EVE's GUID.
ids={Test_PhysicDamageUpMe30=9000177,Test_ShieldDamageUpMe30=9000178,Test_HPRecover100pMe=9000014}
ok,why=dm.command('attack30')
assert(ok and why=='devmenu attack30 asked of the game: EVE deals 30 times the damage (lasting, adds up)'
    and #calls==2,why)
for i,id in ipairs({'9000177','9000178'}) do
    local a=calls[i]
    assert(a.n==4 and a[1]==228 and a[2]==0 and a[3]=='SBApplyEffectMe' and a[4]==id,i)
end
assert(found[1]=='/Game/Local/Data/EffectTable.EffectTable')
assert(lines[#lines]=='devmenu attack30: SBApplyEffectMe Test_ShieldDamageUpMe30 (9000178) on EVE (guid 228)',
    lines[#lines])
calls={}
-- Each refusal asks nothing.
local function refused(name,want)
    local o,w=dm.command(name)
    assert(not o and w:find(want,1,true) and #calls==0,tostring(w))
end
ids.Test_ShieldDamageUpMe30=nil
refused('attack30',"Test_ShieldDamageUpMe30 is not in this game's EffectTable: nothing asked")
table_raises='no table'; refused('heal','the EffectTable cannot be read: no table'); table_raises=nil
status_text='mod=v\nengine=on peers=0\n'; refused('heal','no warp read yet')
status_with('busy',228); refused('heal','a respawn or a warp is under way')
status_with('idle',0); refused('heal',"EVE's GUID reads 0")
status_with('idle',228)
her=nil; refused('heal','no EVE in the world'); her={}
controller=nil; refused('heal','no SB player controller'); controller=pc
-- A call that raises stops the row there.
ids.Test_ShieldDamageUpMe30=9000178
raise={at=1,e='boom'}
ok,why=dm.command('attack30')
raise=nil
assert(not ok and why=='the game call failed: boom' and #calls==1,why)
assert(lines[#lines]=='devmenu attack30 failed at Test_PhysicDamageUpMe30: boom',lines[#lines])
calls={}
ok,why=dm.command('heal')
assert(ok and #calls==1 and calls[1][4]=='9000014',why)
calls={}
-- An ID of 0 or below from the table: ChainSpin.apply refuses it before the game call.
for _,bad in ipairs({0,-1}) do
    ids.Test_HPRecover100pMe=bad
    refused('heal','the game call failed: not an effect ID')
    assert(lines[#lines]=='devmenu heal failed at Test_HPRecover100pMe: not an effect ID',lines[#lines])
end
ids.Test_HPRecover100pMe=9000014

-- 3. stop, as coop off calls it: nothing from an instance whose rows never reached the game; after one that did, clear
-- then lockswitch, each through the same checks, once.
ids.Test_EffectDispelAll,ids.Off_LockOnDelivery_Dispel=9000029,2000805
local fresh=D.new({log=function(m) lines[#lines+1]=m end,status=function() return status_text end})
fresh.stop(); assert(#calls==0,'No row asked: nothing to end')
fresh.command('list'); fresh.command('nope'); fresh.command('heal','x')
status_with('busy',228); assert(not fresh.command('heal')); status_with('idle',228)
ids.Test_HPRecover100pMe=0; assert(not fresh.command('heal')); ids.Test_HPRecover100pMe=9000014
fresh.stop(); assert(#calls==0,'Refused rows reached nothing, so stop asks nothing')
assert(fresh.command('heal') and #calls==1)
fresh.stop()
assert(#calls==3 and calls[2][3]=='SBApplyEffectMe' and calls[2][4]=='9000029' and calls[3][4]=='2000805'
    and calls[3][1]==228,'clear, then lockswitch, on EVE')
assert(lines[#lines]=='devmenu lockswitch: SBApplyEffectMe Off_LockOnDelivery_Dispel (2000805) on EVE (guid 228)',
    lines[#lines])
fresh.stop(); assert(#calls==3,'Once')
-- A stop whose target refuses says so in a [DM] line and asks nothing.
assert(fresh.command('stealth')==false) -- Test_Stealth is not in this fake table.
ids.Test_Stealth=9000004; assert(fresh.command('stealth') and #calls==4)
status_text='mod=v\nengine=off\n'
fresh.stop()
assert(#calls==4 and lines[#lines-1]=='coop off: devmenu clear not asked: the native status has no warp read yet: '
    ..'try again in a moment' and lines[#lines]:find('^coop off: devmenu lockswitch not asked: '),lines[#lines])
print('devmenu_test: ok')
