-- coop chainspin (cut/chainspin.lua) over fakes: the native status text, EVE and the player controller
-- (nightop/probe.lua's her and controller), the controller's Cheat request, recorded or raising, and Lion.rows (in at
-- once, refused, or waiting with its answer later). Covered: the effect's ID is the generated row's; only a GUID of 1 to
-- 2^32-1 reaches the call, with SBApplyEffectMe, no player ID and that ID; each refusal (an extra word, no coop lion,
-- rows that cannot be added, no warp read, a warp under way, a GUID of 0, no EVE, no controller, a call that raises)
-- asks nothing; the call goes out once the rows are in, at once or after the wait, and its checks run then.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local calls,raise={},nil
local pc={ServerRequest_Cheat=function(_,...)
    calls[#calls+1]=table.pack(...)
    if raise then error(raise) end
end}
local her,controller={},pc
package.loaded['nightop.probe']={her=function() return her end,controller=function() return controller end}
local C=require('cut.chainspin')

-- 1. The effect: the generated EffectTable row, an EffectAction_UseSkill (69) of the ChainSpin skill while EVE has
-- P_Eve_TachyMode, and the one call that applies it.
do
    local found
    for _,r in ipairs(require('cut.lion_rows').ROWS) do
        if r[1]=='EffectTable' and r[2]=='P_Eve_Tachy_Skill_ChainSpin1_Use' then found=r end
    end
    assert(found and C.ID==found[3] and C.ID==1004500,'The generated row\'s ID')
    local f={}
    for _,c in ipairs(found[4]) do f[c[1]]=c[3] end
    assert(f.Action1==69 and f.ActionValue1=='P_Eve_Tachy_Skill_ChainSpin1_1'
        and f.ConditionActive_CheckEffectAliasArray=='P_Eve_TachyMode')
end
for _,g in ipairs({0,-1,0x100000000,7.0,'7',nil}) do assert(not pcall(C.cast,pc,g),tostring(g)) end
assert(#calls==0,'Nothing reached the call')
C.cast(pc,0xFFFFFFFF)
local a=calls[1]
assert(a.n==4 and a[1]==0xFFFFFFFF and a[2]==0 and a[3]=='SBApplyEffectMe' and a[4]=='1004500','The four arguments')
calls={}

-- 2. The command over a status, a log and rows.
local status_text
local ENGINE='engine=on peers=0 warp=%s me=%s'
local function status_with(warp,me) status_text='mod=v steam=ready\n'..ENGINE:format(warp,me)..'\nslot=coop index=0\n' end
local lines={}
local rows_mode,later='in',nil -- in: done at once; refused; wait: done kept in later.
local function rows(done)
    if rows_mode=='in' then return done(true,'rows in') end
    if rows_mode=='refused' then return done(false,'logic busy') end
    later=done
    return true,'asked',true
end
local cs=C.new({log=function(m) lines[#lines+1]=m end,status=function() return status_text end,rows=rows})
status_with('idle',228)
local ok,why=cs.command()
assert(ok and why=='ChainSpin asked of the game: EVE spins if she is in Tachy Mode' and #calls==1,why)
assert(calls[1][1]==228 and calls[1][4]=='1004500' and lines[#lines]=='ChainSpin asked: SBApplyEffectMe 1004500 on EVE '
    ..'(guid 228)',lines[#lines])
calls={}
-- Each refusal asks nothing.
local function refused(want)
    local o,w=cs.command()
    assert(not o and w:find(want,1,true) and #calls==0,tostring(w))
end
assert(select(2,cs.command('x'))=='Use: coop chainspin' and #calls==0)
assert(select(2,C.new({log=print,status=function() return status_text end}).command()):find('coop lion is not loaded'))
rows_mode='refused'; refused('the ChainSpin rows cannot be added to the game (logic busy)'); rows_mode='in'
status_text='mod=v\nengine=on peers=0\n'; refused('no warp read yet')
status_with('busy',228); refused('a respawn or a warp is under way')
status_with('idle',0); refused("EVE's GUID reads 0")
status_with('idle',228)
her=nil; refused('no EVE in the world'); her={}
controller=nil; refused('no SB player controller'); controller=pc
raise='boom'; ok,why=cs.command(); raise=nil
assert(not ok and why=='the game call failed: boom' and #calls==1,why)
calls={}
-- Rows asked: the call waits for them, its checks run when they come in.
rows_mode='wait'
ok,why=cs.command()
assert(ok and why=='the ChainSpin rows are asked of the native part; EVE spins once they are in' and #calls==0,why)
assert(lines[#lines]=='ChainSpin waits for its rows (asked)',lines[#lines])
status_with('busy',228)
assert(not later(true,'rows in') and #calls==0,'A warp started in the wait: nothing asked')
status_with('idle',229)
ok,why=later(true,'rows in')
assert(ok and #calls==1 and calls[1][1]==229,why)
print('chainspin_test: ok')
