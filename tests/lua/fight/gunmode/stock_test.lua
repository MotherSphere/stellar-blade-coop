-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's magazine (fight/gunmode/ammo.lua) with a fake stock in place of fight/gunmode/nikke.lua (ready, count,
-- take, watch). Covered: free magazines without stock and before ready(); once ready the magazine empties, a reload
-- takes min(mag_size, count) through take() and loads it at two thirds of the reload time; a count that dropped during
-- the reload caps the take; a refused take loads nothing, the cool time goes to 999 at the reload's end and the next
-- reload waits Ammo.RETRY s; with no round carried the cool time is 999 and 'out of rounds' is logged once (fired dry
-- too); rounds carried later reload an empty magazine by itself; ready() turning false gives the free magazines back;
-- refill() keeps the magazine with stock; stop() ends the watch and loads a magazine put away mid-reload through
-- take(). A part-spent magazine never reloads by itself (the rifle lowered or not): the player's reload (manual)
-- keeps its rounds and tops it up through take() with at most what she carries, never while a refused take waits
-- Ammo.RETRY s. A refused take at the player's reload keeps the magazine as it was. Fired empty after it, the magazine
-- waits Ammo.RETRY s too.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
FindAllOf=function() return {} end
local Ammo=require('fight.gunmode.ammo')

local CFG={mag_size=30,spare_mags=2,reload_time=1.5,fire_interval=0.1,round_color={1,1,1},
    reload_color={1,0,0}}
local logs,cools,reloads={},{},{}
-- Gun mode's controller and EVE, as fight/gunmode/mode.lua's g gives them without a walk of the object array.
local PC,PAWN={name='controller'},{name='EVE'}
local g={log=function(m) logs[#logs+1]=m end,valid=function(x) return x~=nil end,
    try=function(f) local ok,v=pcall(f); if ok then return v end end,
    words=function() return {round='round',reload='reload',empty='empty'} end,
    pc=function() return PC end,pawn=function() return PAWN end}
local function count(text) local n=0; for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end; return n end
local function cool() return cools[#cools] end

-- The fake stock: ready once its rows are in, count what she carries, take(n) refused while refuse holds.
local function stock(carried)
    local st={rows=false,carried=carried,takes={},watches={},refuse=nil}
    st.ready=function() return st.rows end
    st.count=function() return st.carried end
    st.watch=function(on) st.watches[#st.watches+1]=on end
    st.take=function(n,pc,pawn)
        if st.refuse then return false,st.refuse end
        st.takes[#st.takes+1]=n
        st.by=st.by or {}
        st.by[#st.by+1]={pc=pc,pawn=pawn}
        st.carried=math.max(0,st.carried-n)
        return true
    end
    return st
end
local function new(st)
    logs,cools,reloads={},{},{}
    return Ammo.new(g,CFG,function(v) cools[#cools+1]=v end,function(on) reloads[#reloads+1]=on end,nil,st)
end
-- A frame at 60 fps: the rifle out, lowered and not firing unless said.
local function frame(a,aiming,firing) clock=clock+1/60; a.tick(aiming or false,firing or false,clock) end
local function frames(a,n,aiming,firing) for _=1,n do frame(a,aiming,firing) end end

-- Without stock: the free magazines, a reload takes from the spares.
local a=new(nil)
assert(a.left==30 and a.reserve==60)
frames(a,400,true,true)
assert(a.reserve<60 and a.reserve%30==0,'The spares feed the reload: '..a.reserve)

-- With stock before its rows: the free magazines, no watch and no take.
local st=stock(50)
a=new(st)
frames(a,10)
assert(a.left==30 and a.reserve==60 and #st.takes==0 and #st.watches==0,'Free magazines before ready()')

-- The rows in: the magazine empties, the spares are what she carries, the reload starts at once.
st.rows=true
frame(a)
assert(a.left==0 and st.watches[#st.watches]==true,'Empty and watched once ready')
assert(a.reserve==50 and a.reload_until,'A reload from what she carries')
assert(count("the magazine loads from EVE's inventory")==1)
local start=a.reload_until-CFG.reload_time
-- Nothing taken before two thirds of the reload time.
while clock+1/60<start+0.6*CFG.reload_time do frame(a) end
assert(#st.takes==0 and a.left==0,'Nothing taken before two thirds')
while clock<start+0.7*CFG.reload_time do frame(a) end
assert(#st.takes==1 and st.takes[1]==30 and a.left==30,'min(mag_size, count) taken at two thirds')
-- The take gets gun mode's controller and EVE: fight/gunmode/nikke.lua's own lookup is a FindFirstOf of the
-- controller, a walk of the object array (each reload's frame took 64 to 66 ms in the 2026-11-21 test).
assert(st.by[1].pc==PC and st.by[1].pawn==PAWN,'the take looks for the controller and EVE itself')
while a.reload_until do frame(a) end
-- The reload's end writes 0, which clears SB's own copy of a longer cool time. The first round puts the rate of fire
-- back one cool time later.
assert(cool()==0,tostring(cool()))
frames(a,12,true,true)
assert(cool()==CFG.fire_interval,tostring(cool()))
assert(a.reserve==20,'The spares follow the count: '..a.reserve)

-- Fewer rounds than a magazine: the reload takes them all.
st=stock(12)
st.rows=true
a=new(st)
frame(a)
while a.reload_until do frame(a) end
assert(#st.takes==1 and st.takes[1]==12 and a.left==12 and a.reserve==0,'All 12 taken')

-- A part-spent magazine, lowered for 10 s: no reload by itself. The player's reload keeps the 25 rounds and tops the
-- magazine up. The count drops below the 5 it lacks during the reload: the take is the count now, never fewer rounds
-- than before the press.
st=stock(40)
st.rows=true
a=new(st)
frame(a)
while a.reload_until do frame(a) end
assert(a.left==30 and a.reserve==10)
for _=1,5 do frame(a,true,true); frame(a,true,false) end
assert(a.left==25,'Five presses, five rounds: '..a.left)
frames(a,600)
assert(a.left==25 and not a.reload_until and #st.takes==1,'No reload when lowered')
assert(a.manual(clock)==true and a.left==25,'The player\'s reload keeps the magazine\'s rounds: '..a.left)
assert(a.reload_from==25 and a.reload_to==30)
st.carried=3 -- Spent elsewhere while the reload runs.
while a.reload_until do frame(a) end
assert(#st.takes==2 and st.takes[2]==3,'Only the 3 carried taken: '..tostring(st.takes[2]))
assert(a.left==28,'25 kept, 3 loaded: '..a.left)

-- ready() turns false (your own save loaded) mid-reload: the free magazines back, the reload and the watch ended.
st.carried=5; frame(a)
assert(a.manual(clock),'The player\'s reload')
st.rows=false
frame(a)
assert(a.left==30 and a.reserve==60 and not a.reload_until,'Free magazines: '..a.left..' '..a.reserve)
assert(reloads[#reloads]==false and st.watches[#st.watches]==false and cool()==0)
local takes=#st.takes
frames(a,120)
assert(a.left==30 and a.reserve==60 and #st.takes==takes,'No take with free magazines')
assert(count('ammo: free magazines')==1,count('ammo: free magazines')..' logs')
frames(a,12,true,true)
assert(cool()==CFG.fire_interval,tostring(cool()))

-- A refused take: nothing loaded, the cool time 999 at the reload's end.
st=stock(40)
st.rows=true
st.refuse='the game is paused'
a=new(st)
frame(a)
local ends=assert(a.reload_until)
local at=#cools -- After the reload's start, which set its own cool time.
while clock<ends do frame(a) end
frame(a)
assert(a.left==0 and #st.takes==0,'Nothing loaded')
assert(count('30 rounds not taken (the game is paused): nothing loaded')==1,logs[#logs])
local saw=false
for i=at+1,#cools do saw=saw or cools[i]==999 end
assert(saw,'Cool time 999 at the reload\'s end')
-- The next reload waits Ammo.RETRY s after the refused take (at two thirds of the reload, its first frame past it).
-- The rifle raised here: the lowered rifle's reload is checked at the end of the file.
a=new(st)
frame(a,true)
ends=assert(a.reload_until)
local reloaded=count('ammo: reload (')
local retry=ends-CFG.reload_time+0.66*CFG.reload_time+Ammo.RETRY
while clock<retry-0.05 do frame(a,true) end
assert(count('ammo: reload (')==reloaded and not a.reload_until,'No reload before Ammo.RETRY s')
st.refuse=nil
frames(a,10,true)
assert(count('ammo: reload (')==reloaded+1 and a.reload_until,'Reloaded after Ammo.RETRY s')

-- No round carried: cool time 999, 'out of rounds' once.
st=stock(0)
st.rows=true
a=new(st)
frames(a,30)
assert(cool()==999 and a.left==0 and not a.reload_until)
assert(count('ammo: out of rounds')==1,count('out of rounds')..' logs')
-- Rounds carried later (a purchase, a drop): the empty magazine reloads by itself.
st.carried=30
frame(a)
assert(a.reload_until and reloads[#reloads]==true,'Reload by itself')
while a.reload_until do frame(a) end
assert(a.left==30 and st.takes[1]==30 and cool()==0)
frames(a,12,true,true)
assert(cool()==CFG.fire_interval,tostring(cool()))

-- refill() with stock: the magazine as it was (its rounds came out of the inventory).
st=stock(30)
st.rows=true
a=new(st)
frame(a)
while a.reload_until do frame(a) end
frames(a,30,true,true)
local left=a.left
assert(left>0 and left<30)
a.refill()
assert(a.left==left and a.reserve==0,'refill keeps the magazine: '..a.left)
assert(cool()==0)
frames(a,12,true,true)
assert(cool()==CFG.fire_interval,tostring(cool()))

-- stop() mid-reload: the watch ends, the magazine goes in through take().
st=stock(30)
st.rows=true
a=new(st)
frame(a)
assert(a.reload_until and #st.takes==0)
a.stop()
assert(st.watches[#st.watches]==false,'Watch ended')
assert(#st.takes==1 and st.takes[1]==30 and a.left==30 and not a.reload_until,'Loaded through take')
assert(reloads[#reloads]==false)

-- A magazine fired dry with nothing carried: 'out of rounds' once, as with an empty one.
st=stock(30)
st.rows=true
a=new(st)
frame(a)
while a.reload_until do frame(a) end
frames(a,400,true,true)
assert(a.left==0 and a.reserve==0 and cool()==999)
assert(count('ammo: out of rounds')==1,
    'fired dry: "out of rounds" logged '..count('ammo: out of rounds')..' times, once wanted (ammo.lua logs it at the'
    ..' last shot and again in the stocked empty check of the same tick)')

-- A refused take with the rifle lowered: the next reload waits Ammo.RETRY s too.
st=stock(40)
st.rows=true
st.refuse='the game is paused'
a=new(st)
frame(a)
ends=assert(a.reload_until)
retry=ends-CFG.reload_time+0.66*CFG.reload_time+Ammo.RETRY
reloaded=count('ammo: reload (')
while clock<retry-0.05 do frame(a) end
assert(count('ammo: reload (')==reloaded,
    'lowered: '..(count('ammo: reload (')-reloaded)..' reloads before Ammo.RETRY s, none wanted')
assert(a.manual(clock)==false and #st.takes==0,'No player\'s reload before Ammo.RETRY s')
st.refuse=nil
frames(a,10)
assert(count('ammo: reload (')==reloaded+1 and a.reload_until,'The empty magazine reloads after Ammo.RETRY s')

-- A refused take at the player's reload of a part-filled magazine: its 20 rounds stay, nothing loaded. Fired empty
-- with the trigger held, no reload (and no take) before Ammo.RETRY s. Each wait is bounded: a fault fails here instead
-- of looping.
st=stock(40)
st.rows=true
a=new(st)
frame(a)
for _=1,600 do if not a.reload_until then break end; frame(a) end
assert(not a.reload_until,'The first reload ends')
for _=1,10 do frame(a,true,true); frame(a,true,false) end
assert(a.left==20 and a.reserve==10,'Ten presses: '..a.left..' '..a.reserve)
st.refuse='no EVE'
local refused=count('rounds not taken')
assert(a.manual(clock)==true and a.left==20,'The player\'s reload keeps the 20 rounds: '..a.left)
for _=1,600 do if count('rounds not taken')>refused then break end; frame(a) end
assert(count('rounds not taken')==refused+1,'The take was refused once')
retry=assert(a.retry_at)
for _=1,600 do if not a.reload_until then break end; frame(a) end
assert(not a.reload_until and a.left==20,'The refused take loaded nothing, the 20 rounds stay: '..a.left)
assert(cool()==0,'The 20 rounds fire: '..tostring(cool()))
frames(a,12,true,true)
assert(cool()==CFG.fire_interval,tostring(cool()))
reloaded,takes=count('ammo: reload ('),#st.takes
for _=1,math.ceil((retry-0.05-clock)*60) do frame(a,true,true) end
assert(clock<retry and count('ammo: reload (')==reloaded and #st.takes==takes and not a.reload_until and a.left==0,
    'trigger held: '..(count('ammo: reload (')-reloaded)..' reloads before Ammo.RETRY s, none wanted')
assert(cool()==999,'No round while it waits: '..tostring(cool()))
st.refuse=nil
frames(a,10,true)
assert(count('ammo: reload (')==reloaded+1 and a.reload_until,'Reloaded after Ammo.RETRY s')

-- SB's own NIKKE shot, built on SB's rule as read in Ghidra on 26123051: a skill start copies the row's CoolTime into
-- the skill component (FUN_141d2f750, from FSBSkillStart::Execute). Each tick counts that copy down by the frame time
-- (FUN_141d2e4c0). A start is refused while the row's CoolTime and the copy are both above 0 (FUN_141d2cce0). Each
-- start drops the game's aim for the next frame (bTPSMode, seen in the game), so that frame fires nothing.
-- sb_first: SB's check runs before gun mode's tick in the frame, else after it. dt: the frame time (1/60 s). late: SB
-- starts from the frame after this many frames of the trigger held (0: from the press's frame).
local function sb_fire(a,sb,n,held,sb_first,dt,late)
    dt,late=dt or 1/60,late or 0
    for _=1,n do
        clock=clock+dt
        sb.stored=math.max(0,sb.stored-dt)
        sb.held=held and (sb.held or 0)+1 or 0
        local tps=not sb.dropped
        sb.dropped=false
        local function try()
            local row=cool() or 0
            if held and tps and sb.held>late and not (row>0 and sb.stored>0) then
                sb.starts,sb.stored,sb.dropped=sb.starts+1,row,true
            end
        end
        if sb_first then try() end
        a.tick(true,held and tps,clock)
        if not sb_first then try() end
    end
end
-- A magazine fired dry with the trigger held and nothing carried: the 999 goes in while SB can start, so SB keeps 999.
-- Rounds come, the reload runs with the trigger held or let go. Then 1 s with the trigger held: SB fires again at the
-- rate of fire. Before the fix the reload's end wrote the rate of fire, which SB refuses while its copy of 999 lasts:
-- no round and no shot sound after the second reload (2026-11-21 test).
local function locked(sb_first,through,how)
    st=stock(30)
    st.rows=true
    a=new(st)
    local sb={starts=0,stored=0}
    for _=1,600 do sb_fire(a,sb,1,false,sb_first); if not a.reload_until then break end end
    for _=1,600 do if a.dry then break end; sb_fire(a,sb,1,true,sb_first) end
    sb_fire(a,sb,30,true,sb_first)
    assert(a.dry and cool()==999 and sb.stored>900,how..': SB keeps the 999: '..sb.stored)
    st.carried=30
    for _=1,600 do sb_fire(a,sb,1,through,sb_first); if a.reload_until then break end end
    for _=1,600 do if not a.reload_until then break end; sb_fire(a,sb,1,through,sb_first) end
    assert(a.left==30 and cool()==0,how..': the reload ends on 0: '..tostring(cool()))
    return sb
end
for _,sb_first in ipairs({true,false}) do
    for _,through in ipairs({true,false}) do
        local how=(sb_first and 'SB first' or 'gun mode first')..(through and ', held through the reload' or '')
        local sb=locked(sb_first,through,how)
        local starts,fired=sb.starts,a.fired
        sb_fire(a,sb,60,true,sb_first)
        local n,counted=sb.starts-starts,a.fired-fired
        assert(n>=8 and n<=14,how..': '..n..' SB rounds in 1 s after the reload, about 10 wanted')
        assert(math.abs(n-counted)<=2,how..': SB fired '..n..', gun mode counted '..counted)
        assert(cool()==CFG.fire_interval,how..': the rate of fire back: '..tostring(cool()))
    end
end
-- A slow frame (0.12 s, over one cool time) right after the press, with SB's start one frame after gun mode sees the
-- press: the 0 lasts Ammo.OPEN_FRAMES frames as well as one cool time, so that start still passes. With one cool time
-- alone the 0 ended on the slow frame before SB's start: no SB round in the whole magazine.
do
    local sb=locked(false,false,'slow frame')
    local starts=sb.starts
    sb_fire(a,sb,1,true,false,1/60,1)
    sb_fire(a,sb,1,true,false,0.12,1)
    sb_fire(a,sb,58,true,false,1/60,1)
    local n=sb.starts-starts
    assert(n>=8 and n<=14,'slow frame: '..n..' SB rounds in 1 s after the reload, about 10 wanted')
    assert(cool()==CFG.fire_interval,'slow frame: the rate of fire back: '..tostring(cool()))
end

-- The rifle out again: fight/gunmode/data.lua's take writes 0, sync() with rounds writes nothing over it. The first
-- round puts the rate of fire back after one cool time, not a first round of an earlier rifle out.
st=stock(30)
st.rows=true
a=new(st)
frame(a)
while a.reload_until do frame(a) end
frames(a,2,true,true)
a.stop()
frames(a,60)
cools[#cools+1]=0 -- data.take at the rifle out
local writes=#cools
a.sync()
assert(#cools==writes,'sync() with rounds writes nothing')
frame(a,true,true)
assert(cool()==0,'0 kept on the first round: '..tostring(cool()))
frames(a,12,true,true)
assert(cool()==CFG.fire_interval,'the rate of fire back: '..tostring(cool()))

print('fight/gunmode/stock_test: ok')
