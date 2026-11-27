-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's free magazines (fight/gunmode/ammo.lua) against a fake of SB's own NIKKE shot, which keeps a copy of the
-- shot's cool time: the cool time is 0 where rounds come back (a reload's end, a refill, the rifle out) until one cool
-- time and Ammo.OPEN_FRAMES frames after the first round, then the rate of fire again. These are the cool-time cases
-- of stock_test at 5492c007 (4f755c24, 7f3932fe) fitted to luke's magazines. The round store's cases stay out with it.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
FindAllOf=function() return {} end
local Ammo=require('fight.gunmode.ammo')

local CFG={mag_size=30,spare_mags=2,reload_time=1.5,fire_interval=0.1,round_name='N',reload_text='R',empty_text='E',
    round_color={1,1,1},reload_color={1,0,0}}
local logs,cools={},{}
local g={log=function(m) logs[#logs+1]=m end,valid=function(x) return x~=nil end,
    try=function(f) local ok,v=pcall(f); if ok then return v end end}
local function cool() return cools[#cools] end
local function new()
    cools={}
    return Ammo.new(g,CFG,function(v) cools[#cools+1]=v end,function() end)
end

-- SB's own NIKKE shot, built on SB's rule as read in Ghidra on 26123051 (4f755c24): a skill start copies the row's
-- CoolTime into the skill component (FUN_141d2f750, from FSBSkillStart::Execute). Each tick counts that copy down by
-- the frame time (FUN_141d2e4c0). A start is refused while the row's CoolTime and the copy are both above 0
-- (FUN_141d2cce0).
-- Each start drops the game's aim for the next frame (bTPSMode, seen in the game), so that frame fires nothing.
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
-- The rounds gun mode counted from the magazine and the spares.
local function fired(a) return CFG.mag_size*(1+CFG.spare_mags)-a.left-a.reserve end

-- 1. The magazine fired empty with the trigger held through the reload: the reload's start writes its wait, which SB
--    copies with the trigger held. At the reload's end the row reads 0, so SB's next start passes at once. Before the
--    fix the end wrote the rate of fire, which SB refused while its copy of the wait lasted. Then 1 s with the trigger
--    held: SB fires at the rate of fire, as many rounds as gun mode counts.
for _,sb_first in ipairs({true,false}) do
    local how=sb_first and 'SB first' or 'gun mode first'
    local a=new()
    cools[#cools+1]=0 -- data.take at the rifle out
    a.sync()
    local sb={starts=0,stored=0}
    for _=1,600 do if a.reload_until then break end; sb_fire(a,sb,1,true,sb_first) end
    for _=1,600 do if not a.reload_until then break end; sb_fire(a,sb,1,true,sb_first) end
    assert(a.left==CFG.mag_size and cool()==0,how..': the reload ends on 0: '..tostring(cool()))
    local starts,n=sb.starts,0
    while sb.starts==starts and n<60 do sb_fire(a,sb,1,true,sb_first); n=n+1 end
    assert(n<=2,how..': SB\'s first round after the reload came '..n..' frames after its end')
    local counted=fired(a)
    starts=sb.starts
    sb_fire(a,sb,60,true,sb_first)
    local got=sb.starts-starts
    assert(got>=8 and got<=14,how..': '..got..' SB rounds in 1 s after the reload, about 10 wanted')
    assert(math.abs(got-(fired(a)-counted))<=2,
        how..': SB fired '..got..', gun mode counted '..(fired(a)-counted))
    assert(cool()==CFG.fire_interval,how..': the rate of fire back: '..tostring(cool()))
end

-- 2. Every magazine fired dry with the trigger held: the 999 goes in while SB can start, so SB keeps 999. A new world
--    fills the magazines (refill). Then 1 s with the trigger held: SB fires again at the rate of fire. Before the fix
--    the refill wrote the rate of fire, which SB refuses while its copy of 999 lasts: no round and no shot sound for up
--    to 999 s while gun mode's flash, recoil and count went on (the 2026-11-21 test).
local function locked(sb_first,how)
    local a=new()
    cools[#cools+1]=0 -- data.take at the rifle out
    a.sync()
    local sb={starts=0,stored=0}
    for _=1,6000 do if a.left<=0 and a.reserve<=0 then break end; sb_fire(a,sb,1,true,sb_first) end
    sb_fire(a,sb,30,true,sb_first)
    assert(cool()==999 and sb.stored>900,how..': SB keeps the 999: '..sb.stored)
    a.refill()
    assert(cool()==0,how..': the refill writes 0: '..tostring(cool()))
    return a,sb
end
for _,sb_first in ipairs({true,false}) do
    local how=sb_first and 'SB first' or 'gun mode first'
    local a,sb=locked(sb_first,how)
    local counted=fired(a)
    sb_fire(a,sb,60,true,sb_first)
    assert(sb.starts>0,how..': SB fires after the refill')
    local starts=sb.starts
    sb_fire(a,sb,60,true,sb_first)
    local got=sb.starts-starts
    assert(got>=8 and got<=14,how..': '..got..' SB rounds in the second second, about 10 wanted')
    assert(fired(a)>counted,how..': gun mode counts again')
    assert(cool()==CFG.fire_interval,how..': the rate of fire back: '..tostring(cool()))
end

-- 3. A slow frame (0.12 s, over one cool time) right after the press, with SB's start one frame after gun mode sees the
--    press: the 0 lasts Ammo.OPEN_FRAMES frames as well as one cool time, so that start still passes (7f3932fe). With
--    one cool time alone the 0 ended on the slow frame before SB's start: no SB round in the whole magazine.
do
    local a,sb=locked(false,'slow frame')
    sb_fire(a,sb,1,false,false)
    local starts=sb.starts
    sb_fire(a,sb,1,true,false,1/60,1)
    sb_fire(a,sb,1,true,false,0.12,1)
    sb_fire(a,sb,58,true,false,1/60,1)
    local n=sb.starts-starts
    assert(n>=8 and n<=14,'slow frame: '..n..' SB rounds in 1 s after the refill, about 10 wanted')
    assert(cool()==CFG.fire_interval,'slow frame: the rate of fire back: '..tostring(cool()))
end

-- 4. The rifle out again: fight/gunmode/data.lua's take writes 0, sync() with rounds writes nothing over it. The first
--    round puts the rate of fire back after one cool time, not a first round of an earlier rifle out.
do
    local a=new()
    local sb={starts=0,stored=0}
    sb_fire(a,sb,2,true,false)
    a.stop()
    sb_fire(a,sb,60,false,false)
    cools[#cools+1]=0 -- data.take at the rifle out
    local writes=#cools
    a.sync()
    assert(#cools==writes,'sync() with rounds writes nothing')
    sb_fire(a,sb,1,true,false)
    assert(cool()==0,'0 kept on the first round: '..tostring(cool()))
    sb_fire(a,sb,12,true,false)
    assert(cool()==CFG.fire_interval,'the rate of fire back: '..tostring(cool()))
end

-- 5. Gun mode's own round (spend: hip fire, own fire) starts that clock too: after a refill the first own round puts
--    the rate of fire back one cool time and Ammo.OPEN_FRAMES frames later, with no aim of the game's.
do
    local a=new()
    a.refill()
    assert(cool()==0,'the refill writes 0')
    assert(a.spend(clock),'an own round')
    for _=1,12 do clock=clock+1/60; a.tick(false,false,clock) end
    assert(cool()==CFG.fire_interval,'the rate of fire back after an own round: '..tostring(cool()))
end

print('fight/gunmode/stock_test: ok')
