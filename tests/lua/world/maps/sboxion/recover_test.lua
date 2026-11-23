-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's falls (world/maps/sboxion/recover.lua) over a fake world and a fake status text. The ground point: three
-- walking passes give none and four give the first of the four; a falling pass keeps it; a step of 2000 cm starts
-- the streak again; walking under the floor and passes with one world time add nothing; a guard that waits empties
-- the streak. The fall: EVE under the floor goes to the ground point plus 10 cm with its yaw, or to the arrival point
-- with no ground point; nothing moves while a guard waits (no EVE, photo mode, a cutscene, a warp, another zone or
-- zone type), while her life reads 3 to 5 or in the modes death and off; with no warp= word the fall is still caught
-- and one line says so. The check: a walking read within 3 s of world time is a success and sets the failures to 0;
-- 6 s of passes on one world time, then a walking read, is a success; a refused teleport sends the next try to the
-- arrival point; a second failure stops the recovery with one line and no third call; the mode word starts it again;
-- an error in a pass counts as a failure; an arrival resets all of it; a stop drops a put-back being checked.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Recover=require('world.maps.sboxion.recover')
local D=require('world.maps.sboxion.data')
assert(D.FLOOR==-3275 and D.LIFT==10 and D.STREAK==4 and D.JUMP==1500 and D.CHECK==3)

local IDLE='engine=on remote=0 0 none warp=idle me=2610 zonetype=5 area=Zone_SBO_Xion rest=0::0 starts=0 theater=none'
local logs,puts={},{}
local eve,photo,engine,warp_line -- The fake EVE ({at=, yaw=, mode=, time=, pawn=}, or nil), the status text's parts.
local refuse,lands,broken=false,3,nil -- put: refused; the mode it leaves her in. move: raises with broken.
local world={
    move=function()
        if broken then error(broken) end
        return eve and {at={X=eve.at.X,Y=eve.at.Y,Z=eve.at.Z},yaw=eve.yaw,mode=eve.mode,time=eve.time,pawn=eve.pawn}
    end,
    put=function(at,yaw)
        puts[#puts+1]={at=at,yaw=yaw}
        if refuse then return false end
        eve.at,eve.yaw,eve.mode={X=at.X,Y=at.Y,Z=at.Z},yaw,lands
        return true
    end,
}
local function fresh(at)
    logs,puts={},{}
    eve={at=at or {X=0,Y=0,Z=225},yaw=90,mode=1,time=500,pawn=0x7000}
    photo,engine,warp_line,refuse,lands,broken='0',IDLE,'sboxionwarp=entered asks=1 life=1',false,3,nil
    local r=Recover.new({log=function(m) logs[#logs+1]=m end,
        status=function() return 'mod=v\n'..engine..'\n'..warp_line..'\nlast=x\n' end,
        photo=function() return photo end,world=world})
    r.arrive('city')
    return r
end
local function logged(text) for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end end
local function times(text) local n=0; for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end; return n end
local function last() return logs[#logs] end
-- n passes of 250 ms; the world's time stands still with still.
local function pass(r,n,still)
    for _=1,n or 1 do
        if eve and not still then eve.time=eve.time+0.25 end
        r.tick()
    end
end
-- n walking passes, each dx cm further along X.
local function walk(r,n,dx)
    for _=1,n do
        eve.at.X,eve.mode=eve.at.X+(dx or 100),1
        pass(r)
    end
end
local function fall(z) eve.at.Z,eve.mode=z or D.FLOOR-1,3 end

-- arrival: one line with the floor and the arrival point.
local r=fresh()
assert(logs[1]=='recovery on: floor Z -3275, arrival point city (-8304, 7201, 225)',logs[1])
assert(select(2,r.status())==nil and r.status()=='recovery on, no ground point, failures 0',r.status())

-- ground_point: three walking passes give no point, the fourth gives the first of the four, said once.
walk(r,3)
assert(r.status()=='recovery on, no ground point, failures 0' and not logged('ground:'),r.status())
walk(r,1)
assert(last()=='ground: first point (100, 0, 225)' and r.status()=='recovery on, ground (100, 0, 225) 0.8 s old, '
    ..'failures 0',r.status())
walk(r,1) -- The point follows her, three passes behind.
assert(r.status()=='recovery on, ground (200, 0, 225) 0.8 s old, failures 0' and times('ground:')==1,r.status())
-- A falling pass (a jump) keeps the point and empties the streak: four more walking passes move it.
eve.mode=3
pass(r)
assert(r.status()=='recovery on, ground (200, 0, 225) 1.0 s old, failures 0',r.status())
walk(r,3)
assert(r.status():find('ground (200, 0, 225)',1,true),'Three passes after a jump: the old point')
walk(r,1)
assert(r.status():find('ground (600, 0, 225)',1,true),r.status())
-- A step of 2000 cm between two passes starts the streak again at the new place.
walk(r,1,2000)
assert(r.status():find('ground (600, 0, 225)',1,true),r.status())
walk(r,2)
assert(r.status():find('ground (600, 0, 225)',1,true),'Three passes after the step')
walk(r,1)
assert(r.status():find('ground (2900, 0, 225)',1,true),r.status())
-- Passes on one world time add nothing.
for _=1,8 do eve.at.X=eve.at.X+100; pass(r,1,true) end
assert(r.status():find('ground (2900, 0, 225)',1,true),r.status())
-- Walking under the floor records nothing (the fall rule is off here, so nothing moves her).
r=fresh({X=0,Y=0,Z=D.FLOOR-500})
assert(r.mode('off'))
walk(r,8)
assert(r.status()=='recovery off, no ground point, failures 0' and #puts==0,r.status())
-- At the floor's own height she walks on ground.
r=fresh({X=0,Y=0,Z=D.FLOOR})
walk(r,4)
assert(r.status():find('ground (100, 0, -3275)',1,true) and #puts==0,r.status())

-- fall_to_ground: under the floor she goes to the ground point plus 10 cm, facing its yaw.
r=fresh()
eve.yaw=40
walk(r,6)
eve.yaw=170 -- She turned while falling: the point's yaw is used.
fall(-3275.5)
pass(r)
assert(#puts==1 and puts[1].at.X==300 and puts[1].at.Y==0 and puts[1].at.Z==235 and puts[1].yaw==40,'To the point')
assert(logged('fall: EVE at (600, 0, -3276) under the floor, mode 3, life 1: to the ground point (300, 0, 225) read '
    ..'1.0 s ago'),last())
-- The check: no second move while it runs; a walking read is the success.
pass(r,2)
assert(#puts==1 and not logged('put back'))
eve.mode=1
pass(r)
assert(last()=='put back: EVE walks at (300, 0, 235), 0.8 s after the move' and #puts==1,last())
assert(r.status():find('failures 0',1,true))
-- The ground point is kept through the fall: a second fall goes to a point again.
walk(r,4)
fall()
pass(r)
assert(#puts==2 and puts[2].at.X==400 and puts[2].at.Z==245,'The new point')

-- fall_no_point: with no ground point she goes to the stay's arrival point.
r=fresh()
r.arrive('gate')
fall()
pass(r)
assert(#puts==1 and puts[1].at.X==-23392.768 and puts[1].at.Z==1285.3723+10 and puts[1].yaw==-8.409791)
assert(last()=='fall: EVE at (0, 0, -3276) under the floor, mode 3, life 1: to the arrival point gate (-23393, 17287, '
    ..'1285), no ground point',last())
-- An unread life counts as alive.
r=fresh()
warp_line='sboxionwarp=entered asks=1'
fall()
pass(r)
assert(#puts==1 and logged('mode 3, life ?: to the arrival point city'),last())

-- guards: nothing moves while one waits; each reason is said once; the streak is emptied.
for _,g in ipairs({
    {'no EVE',function() eve=nil end},
    {'photo mode',function() photo='1' end},
    {'photo mode',function() photo='s' end},
    {'cutscene SEQ_Xion',function() engine=IDLE:gsub('theater=none','theater=SEQ_Xion') end},
    {'cutscene fault',function() engine=IDLE:gsub('theater=none','theater=fault') end},
    {'a warp is under way',function() engine=IDLE:gsub('warp=idle','warp=busy') end},
    {'zone none type 1',function() engine=IDLE:gsub('zonetype=5 area=Zone_SBO_Xion','zonetype=1 area=none') end},
    {'zone Zone_SBO_Xion type 1',function() engine=IDLE:gsub('zonetype=5','zonetype=1') end},
}) do
    r=fresh()
    walk(r,6)
    local kept={at=eve.at,time=eve.time}
    fall()
    g[2]()
    pass(r,8)
    assert(#puts==0 and times('recovery waits: '..g[1])==1 and not logged('fall:'),g[1]..': '..tostring(last()))
    eve=eve or {at=kept.at,yaw=90,mode=3,time=kept.time+2,pawn=0x7000}
    photo,engine='0',IDLE
    pass(r)
    assert(times('recovery waits no more')==1 and #puts==1,g[1]..': the fall is caught once the wait ends')
end
-- A wait empties the streak: the point is not made of passes from before and after it.
r=fresh()
walk(r,3)
photo='1'
pass(r)
photo='0'
walk(r,3)
assert(r.status():find('no ground point',1,true),r.status())
walk(r,1)
assert(r.status():find('ground (400, 0, 225)',1,true),r.status())
-- No theater= word and no warp= word: no guard on them.
r=fresh()
engine='engine=on remote=0 0 none'
walk(r,5)
assert(times('recovery: the engine line has no warp= word: falls are caught, deaths are not')==1,last())
fall()
pass(r)
assert(#puts==1 and puts[1].at.X==200 and times('the engine line has no warp= word')==1,'Still caught, said once')

-- Nothing moves while her life reads 3 to 5, or in the modes death and off.
for life=3,5 do
    r=fresh()
    warp_line='sboxionwarp=refused asks=2 verb=leave why=camp life='..life
    fall()
    pass(r,1)
    assert(#puts==0 and not logged('fall:'),'life '..life)
end
for _,word in ipairs({'death','off'}) do
    r=fresh()
    local ok,line=r.mode(word)
    assert(ok and line==last() and line:find('^recovery mode '..word..': falls are not caught, deaths are'),line)
    fall()
    pass(r,20)
    assert(#puts==0 and not logged('fall:'),word)
    ok,line=r.mode('on')
    assert(ok and line=='recovery mode on: falls are caught, deaths are',line)
    pass(r)
    assert(#puts==1,'On again: caught')
end
r=fresh()
local ok,line=r.mode('up')
assert(not ok and line=='Use: coop xion recover [on|death|off]',line)
ok,line=r.mode()
assert(ok and line=='recovery on, no ground point, failures 0',line)

-- check_paused: 6 s of passes on one world time after the move, then a walking read: a success, no failure.
r=fresh()
walk(r,6)
fall()
pass(r)
pass(r,24,true)
assert(#puts==1 and not logged('failure'),'A world that stands still runs no check out')
eve.mode=1
pass(r)
assert(logged('put back: EVE walks at (300, 0, 235), 0.2 s after the move'),last())

-- check_failed: no walking read in 3 s of world time is a failure; the next try goes to the arrival point.
r=fresh()
walk(r,6)
fall()
pass(r)
eve.at.Z=100 -- Above the floor, still falling.
pass(r,11)
assert(not logged('failure'))
pass(r)
assert(last()=='put back failed: EVE at (300, 0, 100), mode 3, 3 s after the move: failure 1 of 2',last())
assert(r.status()=='recovery on, ground (300, 0, 225) 4.0 s old, failures 1',r.status())
fall()
pass(r)
assert(#puts==2 and puts[2].at.X==-8303.969 and puts[2].at.Z==235 and puts[2].yaw==-233.43753,'The arrival point')
assert(logged('to the arrival point city (-8304, 7201, 225), after a failure'),last())
-- A walking read sets the failures to 0: the next fall goes to a ground point again.
eve.mode=1
pass(r)
assert(r.status():find('failures 0',1,true),r.status())

-- stopped: a refused teleport, then a second failure, stop the recovery; no third call.
r=fresh()
walk(r,6)
refuse=true
fall()
pass(r)
assert(#puts==1 and last()=='put back refused by K2_TeleportTo: failure 1 of 2',last())
pass(r)
assert(#puts==2 and puts[2].at.X==-8303.969,'The second try goes to the arrival point')
assert(logs[#logs-1]=='put back refused by K2_TeleportTo: failure 2 of 2' and last()=='recovery stopped after 2 '
    ..'failures in a row; coop xion recover on starts it again; way out: coop xion leave',last())
pass(r,40)
assert(#puts==2 and times('recovery stopped')==1,'No third call')
assert(r.status():find('^recovery stopped, ground %(300, 0, 225%) %d+%.%d s old, failures 2$'),r.status())
-- The mode word starts it again with the failures at 0.
refuse=false
ok,line=r.mode('on')
assert(ok and r.status():find('^recovery on, .* failures 0$'),r.status())
pass(r)
assert(#puts==3 and puts[3].at.X==300,'Caught again, to the ground point')
-- An error in a pass is a failure too: two in a row stop the recovery, with two lines and no more.
r=fresh()
broken='no world'
pass(r,10)
assert(times('recovery: error (no world): failure')==2 and times('recovery stopped')==1,last())
broken=nil

-- arrival: a new arrival sets the mode to on, drops the point, the failures and the stop.
r=fresh()
walk(r,6)
refuse=true
fall()
pass(r,2)
assert(r.status():find('^recovery stopped'))
refuse=false
r.arrive('gate')
assert(last()=='recovery on: floor Z -3275, arrival point gate (-23393, 17287, 1285)',last())
assert(r.status()=='recovery on, no ground point, failures 0',r.status())
-- stop: a put-back being checked is dropped, so nothing is said of it after.
r=fresh()
walk(r,6)
fall()
pass(r)
r.stop('a map change')
local lines=#logs
eve.mode=1
pass(r,20)
assert(#logs==lines or not logged('put back:'),'Nothing of the dropped check')
print('sboxion_recover_test ok')
