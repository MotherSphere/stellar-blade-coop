-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's magazine (fight/gunmode/ammo.lua) with a fake stock in place of a host's round store (ready, count,
-- take, watch). Covered: free magazines without stock and before ready(); once ready the magazine empties, a reload
-- takes min(mag_size, count) through take() and loads it at two thirds of the reload time; a count that dropped during
-- the reload caps the take; a refused take loads nothing, the cool time goes to 999 at the reload's end and the next
-- reload waits Ammo.RETRY s; with no round carried the cool time is 999 and 'out of rounds' is logged once (fired dry
-- too); rounds carried later reload an empty magazine by itself; ready() turning false gives the free magazines back;
-- refill() keeps the magazine with stock; stop() ends the watch and loads a magazine put away mid-reload through
-- take(). A part-spent magazine never reloads by itself (the rifle lowered or not): the player's reload (manual)
-- throws its rounds away and loads a magazine through take(), never while a refused take waits Ammo.RETRY s.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
FindAllOf=function() return {} end
local Ammo=require('fight.gunmode.ammo')

local CFG={mag_size=30,spare_mags=2,reload_time=1.5,fire_interval=0.1,round_color={1,1,1},
    reload_color={1,0,0},round_name='NIKKE RAPID',reload_text='RELOADING',empty_text='NO AMMO'}
local logs,cools,reloads={},{},{}
local g={log=function(m) logs[#logs+1]=m end,valid=function(x) return x~=nil end,
    try=function(f) local ok,v=pcall(f); if ok then return v end end,
    words=function() return {round='round',reload='reload',empty='empty'} end}
local function count(text) local n=0; for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end; return n end
local function cool() return cools[#cools] end

-- The fake stock: ready once its rows are in, count what she carries, take(n) refused while refuse holds.
local function stock(carried)
    local st={rows=false,carried=carried,takes={},watches={},refuse=nil}
    st.ready=function() return st.rows end
    st.count=function() return st.carried end
    st.watch=function(on) st.watches[#st.watches+1]=on end
    st.take=function(n)
        if st.refuse then return false,st.refuse end
        st.takes[#st.takes+1]=n
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
assert(count("the magazine loads from the round store")==1)
local start=a.reload_until-CFG.reload_time
-- Nothing taken before two thirds of the reload time.
while clock+1/60<start+0.6*CFG.reload_time do frame(a) end
assert(#st.takes==0 and a.left==0,'Nothing taken before two thirds')
while clock<start+0.7*CFG.reload_time do frame(a) end
assert(#st.takes==1 and st.takes[1]==30 and a.left==30,'min(mag_size, count) taken at two thirds')
while a.reload_until do frame(a) end
assert(cool()==CFG.fire_interval,tostring(cool()))
assert(a.reserve==20,'The spares follow the count: '..a.reserve)

-- Fewer rounds than a magazine: the reload takes them all.
st=stock(12)
st.rows=true
a=new(st)
frame(a)
while a.reload_until do frame(a) end
assert(#st.takes==1 and st.takes[1]==12 and a.left==12 and a.reserve==0,'All 12 taken')

-- A part-spent magazine, lowered for 10 s: no reload by itself. The player's reload throws the 25 rounds away; the
-- count drops during the reload: the take is the count now.
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
assert(a.manual(clock)==true and a.left==0,'The player\'s reload empties the magazine')
assert(a.reload_from==0 and a.reload_to==10)
st.carried=3 -- Spent elsewhere while the reload runs.
while a.reload_until do frame(a) end
assert(#st.takes==2 and st.takes[2]==3,'Only the 3 carried taken: '..tostring(st.takes[2]))
assert(a.left==3,'3 loaded: '..a.left)

-- ready() turns false (your own save loaded) mid-reload: the free magazines back, the reload and the watch ended.
st.carried=5; frame(a)
assert(a.manual(clock),'The player\'s reload')
st.rows=false
frame(a)
assert(a.left==30 and a.reserve==60 and not a.reload_until,'Free magazines: '..a.left..' '..a.reserve)
assert(reloads[#reloads]==false and st.watches[#st.watches]==false and cool()==CFG.fire_interval)
local takes=#st.takes
frames(a,120)
assert(a.left==30 and a.reserve==60 and #st.takes==takes,'No take with free magazines')
assert(count('ammo: free magazines')==1,count('ammo: free magazines')..' logs')

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
assert(a.left==30 and st.takes[1]==30 and cool()==CFG.fire_interval)

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
assert(cool()==CFG.fire_interval)

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

-- Before the count's first read (count() nil, as fight/gunmode/nikke.lua gives it until the inventory is read): the
-- magazine holds no round (cool time 999 once the store is ready), logs no 'out of rounds' and starts no reload. Once
-- the count is read the empty magazine reloads from it.
st=stock(nil)
st.rows=true
a=new(st)
frame(a)
assert(a.left==0 and cool()==999,'No round before the first count: '..a.left..' '..tostring(cool()))
frames(a,30,true,true)
assert(count('out of rounds')==0 and not a.reload_until and #st.takes==0,'Nothing before the first count')
st.carried=40
frames(a,2)
assert(a.reload_until,'The first count starts the reload')
while a.reload_until do frame(a) end
assert(a.left==30 and st.takes[1]==30,'Loaded from the count: '..a.left)

print('gunmode stock_test ok')
