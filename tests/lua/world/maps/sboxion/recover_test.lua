-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's falls and deaths (world/maps/sboxion/recover.lua) over a fake world and a fake status text. The ground
-- point: three walking passes give none and four give the first of the four; a falling pass keeps it; a step of 2000 cm
-- starts the streak again; walking under the floor and passes with one world time add nothing; a guard that waits
-- empties the streak. The fall: SB's black is asked at the pass that reads EVE under the floor (0.3 s in, 1 s black,
-- 0.5 s out) and she goes two passes later to the ground point plus 10 cm with its yaw, or to the arrival point with no
-- ground point; a black that raises, that SB did not make or whose handle did not read changes one log line and not
-- the move; the move waits like a check while a guard waits or the world's time stands still; the mode off, an
-- arrival, a stop, a death that starts and an error in a pass drop it; after a failure the move is made at once, then
-- a black that is up at once, none after a refused teleport; one black a put-back, the one after a respawn included;
-- nothing moves and no black is asked while a guard waits (no EVE, photo mode, a cutscene, a warp, another zone
-- or zone type), while her life reads 3 to 5 or in the modes death and off; with no warp= word the fall is still caught
-- and one line says so; the fault words theater=fault and zonetype=0 beside SBO Xion's area are no wait. The check: a
-- walking read within 3 s of world time is a success and sets the failures to 0; 6 s of passes on one world time, then
-- a walking read, is a success; 24 passes in 0.75 s of world time are no failure and three passes of 1 s each are one;
-- a refused teleport sends the next try to the arrival point; a second failure stops the recovery with one line and no
-- third call; the mode word starts it again; an error in a pass counts as a failure; 1 s of walking between two
-- failures sets them to 0, so the recovery stays on; an arrival resets all of it, the modes death and off included; an
-- arrival, a stop, an error in a pass and the mode off each drop a put-back being checked; a put-back that leaves her
-- under the floor is not made again while it is checked: the check fails after 3 s and the next try goes to the arrival
-- point.
-- The death, with the respawn cases of tests/lua/online/modes/scoreattack/run_test.lua for this module's copy: it
-- starts while her life reads 3 to 5 (not on the change), each reason the respawn waits for is said once, one call of
-- SB's respawn with her GUID, the result line 2 s later, a death screen that still plays over a living EVE hidden, then
-- shown again at a new death (in the modes off and death too), at a stop and when two failures stop the recovery; no
-- call in 10 s is a failure. This module's own cases: with no death screen playing the call is made after 5 s; a
-- respawn that leaves her off the ground puts her back, in the mode death too; life still 3 after the call is a
-- failure and the death starts again; two failures stop the recovery and the mode word starts it again; a death left
-- from the mode off, one read during a guard's wait and one on a world time that stands still are all asked; a life
-- back at 1 before the call ends the death with one line and no failure, then the next fall is caught; without a warp=
-- word the respawn is never asked; an arrival, a stop and the mode off drop a death being handled; a respawn that
-- leaves her walking sets the failures to 0; a death that starts while a put-back is checked drops the check.
-- busy, for the Tetrapod's door (tetrapod.lua): whether a guard waits or a put-back or a death is handled, with the
-- pass's read of EVE.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Recover=require('world.maps.sboxion.recover')
local D=require('world.maps.sboxion.data')
assert(D.FLOOR==-3275 and D.LIFT==10 and D.STREAK==4 and D.JUMP==1500 and D.CHECK==3)
assert(D.BLACK_IN==0.3 and D.BLACK==1 and D.BLACK_OUT==0.5 and D.LEAD==2)

local IDLE='engine=on remote=0 0 none warp=idle me=2610 zonetype=5 area=Zone_SBO_Xion rest=0::0 starts=0 theater=none'
local logs,puts={},{}
local eve,photo,engine -- The fake EVE ({at=, yaw=, mode=, time=, pawn=}, or nil) and the status text's parts.
local refuse,lands,broken=false,3,nil -- put: refused; the mode it leaves her in. move: raises with broken.
-- SB's black: each call ({hold=, fade=, out=}); what it returns (true, false or nil), or the error it raises. order:
-- the black and put calls as they came.
local blacks,order,black_up,black_error={},{},true,nil
local world={
    move=function()
        if broken then error(broken) end
        return eve and {at={X=eve.at.X,Y=eve.at.Y,Z=eve.at.Z},yaw=eve.yaw,mode=eve.mode,time=eve.time,pawn=eve.pawn}
    end,
    put=function(at,yaw)
        puts[#puts+1]={at=at,yaw=yaw}
        order[#order+1]='put'
        if refuse then return false end
        eve.at,eve.yaw,eve.mode={X=at.X,Y=at.Y,Z=at.Z},yaw,lands
        return true
    end,
    black=function(hold,fade,out)
        blacks[#blacks+1]={hold=hold,fade=fade,out=out}
        order[#order+1]='black'
        if black_error then error(black_error) end
        return black_up
    end,
}
-- The respawn's fakes: the controller, the standalone test, SB's request (revive: the life it leaves, or nil) and the
-- death screen (there: the widget exists; playing; visible until hidden; looks: each search for the widget).
local PC={}
local pc,standalone,respawns,revive=PC,true,{},nil
local there,playing,visible,looks=true,false,true,0
local warp_line
world.controller=function() return pc end
world.standalone=function(p) assert(p==PC,'The test is asked on the controller'); return standalone end
world.respawn=function(p,me)
    assert(p==PC)
    respawns[#respawns+1]=me
    if revive then warp_line='sboxionwarp=entered asks=1 life='..revive end
end
world.screen=function(look)
    if look then looks=looks+1 end
    if not there then return nil end
    return playing
end
world.hide=function()
    if not there then return nil end
    visible=false
    return function() visible=true end
end
local function fresh(at)
    logs,puts={},{}
    blacks,order,black_up,black_error={},{},true,nil
    eve={at=at or {X=0,Y=0,Z=225},yaw=90,mode=1,time=500,pawn=0x7000}
    photo,engine,warp_line,refuse,lands,broken='0',IDLE,'sboxionwarp=entered asks=1 life=1',false,3,nil
    pc,standalone,respawns,revive,there,playing,visible,looks=PC,true,{},nil,true,false,true,0
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

-- fall_to_ground: under the floor she goes to the ground point plus 10 cm, facing its yaw. black_lead: SB's black is
-- asked at the pass that reads her under the floor (0.3 s in, 1 s black, 0.5 s out) and nothing moves. The move comes
-- two passes later, with the fall line then.
r=fresh()
eve.yaw=40
walk(r,6)
eve.yaw=170 -- She turned while falling: the point's yaw is used.
fall(-3275.5)
pass(r)
assert(#blacks==1 and blacks[1].hold==1 and blacks[1].fade==0.3 and blacks[1].out==0.5 and #puts==0,'The black first')
assert(last()=='black: up in 0.3 s; EVE at (600, 0, -3276) moves in 2 passes' and not logged('fall:'),last())
pass(r)
assert(#puts==0,'One pass after the black: not yet')
pass(r)
assert(#puts==1 and puts[1].at.X==300 and puts[1].at.Y==0 and puts[1].at.Z==235 and puts[1].yaw==40,'To the point')
assert(logged('fall: EVE at (600, 0, -3276) under the floor, mode 3, life 1: to the ground point (300, 0, 225) read '
    ..'1.5 s ago'),last())
assert(last()=='fall: EVE at (600, 0, -3276) under the floor, mode 3, life 1: to the ground point (300, 0, 225) read '
    ..'1.5 s ago' and #blacks==1 and table.concat(order,',')=='black,put','The black, then the move: '..last())
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
pass(r,3)
assert(#puts==2 and puts[2].at.X==400 and puts[2].at.Z==245,'The new point')

-- fall_no_point: with no ground point she goes to the stay's arrival point.
r=fresh()
r.arrive('gate')
fall()
pass(r,3)
assert(#puts==1 and puts[1].at.X==-23392.768 and puts[1].at.Z==1285.3723+10 and puts[1].yaw==-8.409791)
assert(last()=='fall: EVE at (0, 0, -3276) under the floor, mode 3, life 1: to the arrival point gate (-23393, 17287, '
    ..'1285), no ground point',last())
-- An unread life counts as alive.
r=fresh()
warp_line='sboxionwarp=entered asks=1'
fall()
pass(r,3)
assert(#puts==1 and logged('mode 3, life ?: to the arrival point city'),last())

-- guards: nothing moves while one waits; each reason is said once; the streak is emptied.
for _,g in ipairs({
    {'no EVE',function() eve=nil end},
    {'photo mode',function() photo='1' end},
    {'photo mode',function() photo='s' end},
    {'cutscene SEQ_Xion',function() engine=IDLE:gsub('theater=none','theater=SEQ_Xion') end},
    {'a warp is under way',function() engine=IDLE:gsub('warp=idle','warp=busy') end},
    {'zone none type 1',function() engine=IDLE:gsub('zonetype=5 area=Zone_SBO_Xion','zonetype=1 area=none') end},
    {'zone Zone_SBO_Xion type 1',function() engine=IDLE:gsub('zonetype=5','zonetype=1') end},
    {'zone none type 0',function() engine=IDLE:gsub('zonetype=5 area=Zone_SBO_Xion','zonetype=0 area=none') end},
}) do
    r=fresh()
    walk(r,6)
    local kept={at=eve.at,time=eve.time}
    fall()
    g[2]()
    pass(r,8)
    assert(#puts==0 and times('recovery waits: '..g[1])==1 and not logged('fall:'),g[1]..': '..tostring(last()))
    assert(#blacks==0,g[1]..': no black while a guard waits')
    eve=eve or {at=kept.at,yaw=90,mode=3,time=kept.time+2,pawn=0x7000}
    photo,engine='0',IDLE
    pass(r)
    assert(#blacks==1 and #puts==0,g[1]..': the black at the first pass after the wait')
    pass(r,2)
    assert(times('recovery waits no more')==1 and #puts==1,g[1]..': the fall is caught once the wait ends')
end
-- fault_words: theater=fault (the native theater read faulted and is off for the game run) and zonetype=0 beside SBO
-- Xion's area (the native zone row read faulted) are no wait. The fall is caught and no wait is said.
for _,w in ipairs({{'theater=none','theater=fault'},{'zonetype=5','zonetype=0'}}) do
    r=fresh()
    engine=IDLE:gsub(w[1],w[2])
    assert(engine:find(' '..w[2],1,true))
    walk(r,6)
    fall()
    pass(r,3)
    assert(#puts==1 and puts[1].at.X==300 and not logged('recovery waits'),w[2]..': '..tostring(last()))
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
pass(r,3)
assert(#puts==1 and puts[1].at.X==200 and times('the engine line has no warp= word')==1,'Still caught, said once')

-- Nothing moves while her life reads 3 to 5, or in the modes death and off.
for life=3,5 do
    r=fresh()
    warp_line='sboxionwarp=refused asks=2 verb=leave why=camp life='..life
    fall()
    pass(r,1)
    assert(#puts==0 and not logged('fall:'),'life '..life)
    assert(#blacks==0,'No black either, life '..life)
end
for _,word in ipairs({'death','off'}) do
    r=fresh()
    local ok,line=r.mode(word)
    assert(ok and line==last() and line:find('^recovery mode '..word..': falls are not caught, deaths are'),line)
    fall()
    pass(r,20)
    assert(#puts==0 and not logged('fall:'),word)
    assert(#blacks==0,'No black either: '..word)
    ok,line=r.mode('on')
    assert(ok and line=='recovery mode on: falls are caught, deaths are',line)
    pass(r,3)
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
pass(r,3)
pass(r,24,true)
assert(#puts==1 and not logged('failure'),'A world that stands still runs no check out')
eve.mode=1
pass(r)
assert(logged('put back: EVE walks at (300, 0, 235), 0.2 s after the move'),last())

-- check_world_time: CHECK counts the world's time, not passes. 24 passes of 1/32 s after the move are 0.75 s: no
-- failure. The walking read after them is the success. Three passes of 1 s each are 3 s: the failure.
r=fresh()
walk(r,6)
fall()
pass(r,3)
eve.at.Z=100 -- Above the floor, still falling.
for _=1,24 do eve.time=eve.time+0.03125; r.tick() end
assert(#puts==1 and not logged('failure'),'24 passes in 0.75 s of world time run no check out')
eve.mode=1
pass(r)
assert(last()=='put back: EVE walks at (300, 0, 100), 1.0 s after the move',last())
r=fresh()
walk(r,6)
fall()
pass(r,3)
eve.at.Z=100
for _=1,2 do eve.time=eve.time+1; r.tick() end
assert(not logged('failure'),'2 s of world time in two passes')
eve.time=eve.time+1
r.tick()
assert(last()=='put back failed: EVE at (300, 0, 100), mode 3, 3 s after the move: failure 1 of 2',last())

-- check_failed: no walking read in 3 s of world time is a failure; the next try goes to the arrival point.
-- black_at_once: that try is made in the pass that reads her under the floor, then a black that is up at once.
r=fresh()
walk(r,6)
fall()
pass(r,3)
eve.at.Z=100 -- Above the floor, still falling.
pass(r,11)
assert(not logged('failure'))
pass(r)
assert(last()=='put back failed: EVE at (300, 0, 100), mode 3, 3 s after the move: failure 1 of 2',last())
assert(r.status()=='recovery on, ground (300, 0, 225) 4.5 s old, failures 1',r.status())
fall()
pass(r)
assert(#puts==2 and puts[2].at.X==-8303.969 and puts[2].at.Z==235 and puts[2].yaw==-233.43753,'The arrival point')
assert(logged('to the arrival point city (-8304, 7201, 225), after a failure'),last())
assert(#blacks==2 and blacks[2].hold==1 and blacks[2].fade==0 and blacks[2].out==0.5,'A black that is up at once')
assert(table.concat(order,',')=='black,put,put,black' and last()=='black: up at once',last())
-- A walking read sets the failures to 0: the next fall goes to a ground point again.
eve.mode=1
pass(r)
assert(r.status():find('failures 0',1,true),r.status())
-- check_holds: a put-back that leaves her falling under the floor is not made again while it is checked. The check
-- runs its 3 s out as a failure. The try after it goes to the arrival point.
r=fresh()
walk(r,6)
fall()
pass(r,3)
assert(#puts==1)
fall() -- Still in mode 3 and under the floor again, at the place the put-back gave her.
pass(r,11)
assert(#puts==1 and not logged('failure'),'No second put-back while the first is checked')
pass(r)
assert(last()=='put back failed: EVE at (300, 0, -3276), mode 3, 3 s after the move: failure 1 of 2',last())
pass(r)
assert(#puts==2 and puts[2].at.X==-8303.969,'The try after the failure goes to the arrival point')

-- stopped: a refused teleport, then a second failure, stop the recovery; no third call.
r=fresh()
walk(r,6)
refuse=true
fall()
pass(r,3)
assert(#puts==1 and last()=='put back refused by K2_TeleportTo: failure 1 of 2',last())
assert(#blacks==1,'black_refused: the one black of the first try')
pass(r)
assert(#puts==2 and puts[2].at.X==-8303.969,'The second try goes to the arrival point')
assert(#blacks==1 and table.concat(order,',')=='black,put,put','black_refused: no black after a refused teleport')
assert(logs[#logs-1]=='put back refused by K2_TeleportTo: failure 2 of 2' and last()=='recovery stopped after 2 '
    ..'failures in a row; coop xion recover on starts it again; way out: coop xion leave',last())
pass(r,40)
assert(#puts==2 and times('recovery stopped')==1,'No third call')
assert(#blacks==1,'lead_at_stop: no black and no move once the recovery stopped')
assert(r.status():find('^recovery stopped, ground %(300, 0, 225%) %d+%.%d s old, failures 2$'),r.status())
-- The mode word starts it again with the failures at 0.
refuse=false
ok,line=r.mode('on')
assert(ok and r.status():find('^recovery on, .* failures 0$'),r.status())
pass(r,3)
assert(#puts==3 and puts[3].at.X==300,'Caught again, to the ground point')
-- An error in a pass is a failure too: two in a row stop the recovery, with two lines and no more.
r=fresh()
broken='no world'
pass(r,10)
assert(times('recovery: error (no world): failure')==2 and times('recovery stopped')==1,last())
broken=nil
-- walked_since: a full streak sets the failures to 0. An error, 1 s of walking and a second error leave the recovery
-- on; the next fall goes to the ground point.
r=fresh()
broken='no world'
pass(r)
broken=nil
assert(r.status()=='recovery on, no ground point, failures 1',r.status())
walk(r,3)
assert(r.status()=='recovery on, no ground point, failures 1','Three walking passes are not a streak')
walk(r,1)
assert(r.status()=='recovery on, ground (100, 0, 225) 0.8 s old, failures 0',r.status())
broken='no world'
pass(r)
broken=nil
assert(last()=='recovery: error (no world): failure 1 of 2' and not logged('recovery stopped'),last())
walk(r,4)
assert(r.status():find('ground (500, 0, 225)',1,true) and r.status():find('failures 0',1,true),r.status())
fall()
pass(r,3)
assert(#puts==1 and puts[1].at.X==500 and logged('to the ground point (500, 0, 225)'),last())
-- An error in a pass drops a put-back being checked: the walking read after it is no success of that put-back.
r=fresh()
walk(r,6)
fall()
pass(r,3)
broken='no world'
pass(r)
broken=nil
eve.mode=1
pass(r)
assert(#puts==1 and not logged('put back') and r.status():find('failures 1',1,true),r.status())
-- mode_off_check: coop xion recover off drops a put-back being checked. Nothing is said of it after, whether she
-- walks or goes on falling.
for _,after in ipairs({1,3}) do
    r=fresh()
    walk(r,6)
    fall()
    pass(r,3)
    eve.at.Z=100
    assert(#puts==1 and r.mode('off'))
    eve.mode=after
    pass(r,20)
    assert(not logged('put back') and not logged('failure'),'Nothing of the check in the mode off, mode '..after)
end

-- arrival: a new arrival sets the mode to on, drops the point, the failures and the stop.
r=fresh()
walk(r,6)
refuse=true
fall()
pass(r,4)
assert(r.status():find('^recovery stopped'))
refuse=false
r.arrive('gate')
assert(last()=='recovery on: floor Z -3275, arrival point gate (-23393, 17287, 1285)',last())
assert(r.status()=='recovery on, no ground point, failures 0',r.status())
for _,word in ipairs({'death','off'}) do
    r=fresh()
    assert(r.mode(word) and r.status()=='recovery '..word..', no ground point, failures 0',r.status())
    r.arrive('city')
    assert(r.status()=='recovery on, no ground point, failures 0',word..': '..r.status())
end
-- An arrival drops a put-back being checked.
r=fresh()
walk(r,6)
fall()
pass(r,3)
r.arrive('city')
eve.mode=1
pass(r,20)
assert(#puts==1 and not logged('put back'),'Nothing of the check of the stay before')
-- stop: a put-back being checked is dropped, so nothing is said of it after.
r=fresh()
walk(r,6)
fall()
pass(r,3)
r.stop('a map change')
eve.mode=1
pass(r,20)
assert(not logged('put back:'),'Nothing of the dropped check')

local function die(z)
    warp_line='sboxionwarp=entered asks=1 life=3'
    if z then eve.at.Z,eve.mode=z,3 end
end
local function count(text) return times(text) end
local ASKED='respawn: ServerRequest_ActorRespawn(2610, false) asked (life 3, death screen up)'

-- death: each reason the respawn waits for is said once, then one call with her GUID and the result 2 s later.
r=fresh()
walk(r,6)
playing,standalone=true,false
die()
pass(r)
assert(logs[#logs-1]=='death: life 3, EVE at (600, 0, 225)' and last()=='respawn waits: the game is not standalone',
    last())
pass(r,3)
assert(count('respawn waits:')==1 and count('death: life')==1,'A reason is said once, the death once')
standalone=true
engine=IDLE:gsub('warp=idle','warp=busy')
pass(r,2)
assert(last()=='respawn waits: a respawn or a warp is under way' and #respawns==0,last())
engine=IDLE..' nightop=rule'
pass(r)
assert(last()=='respawn waits: a coop no probe rule is set in this game run',last())
engine,pc=IDLE,nil
pass(r)
assert(last()=='respawn waits: no SB player controller',last())
pc,playing=PC,false
pass(r)
assert(last()=='respawn waits: no death screen' and #respawns==0,last())
playing=true
pass(r)
assert(#respawns==1 and respawns[1]==2610 and last()==ASKED,last())
pass(r,3)
assert(#respawns==1,'Once')
warp_line,eve.mode='sboxionwarp=entered asks=1 life=1',1 -- Up and standing; the death screen still plays.
pass(r,4)
assert(not logged('respawn result'),'Not before 2 s')
pass(r)
assert(last()=='respawn result: life 3/1, death screen up/hidden, EVE pawn same, mode 1',last())
assert(visible==false and #respawns==1 and #puts==0 and r.status():find('failures 0',1,true))
pass(r,40)
assert(#respawns==1 and count('death: life')==1,'Nothing more while she lives')
-- A new death shows the screen the part hid, first. With no life read after it started, the respawn is given up
-- after 10 s as a failure. A life that is not read starts no death.
die()
pass(r)
assert(visible==true and logs[#logs-2]=='respawn: death screen shown again (a new death)' and last()==ASKED,last())
r=fresh()
playing=false
die()
pass(r)
warp_line='sboxionwarp=entered asks=1'
pass(r)
assert(last()=='respawn waits: no life read',last())
pass(r,37)
assert(#respawns==0 and not logged('failure'))
pass(r)
assert(last()=='respawn not asked in 10 s: no life read: failure 1 of 2' and #respawns==0,last())
pass(r,40)
assert(count('death: life')==1 and count('failure')==1,'An unread life starts no death')
-- A screen the part hid comes back at a stop (a map change, coop off).
r=fresh()
playing,revive=true,1
die()
pass(r,9)
assert(visible==false,last())
r.stop('coop off')
assert(visible==true and last()=='respawn: death screen shown again (coop off)',last())
-- stopped_screen: a screen the part hid comes back when two failures stop the recovery. A death after the stop is
-- not handled: its death screen must not stay hidden.
r=fresh()
walk(r,6)
playing,revive=true,1
die()
pass(r,9)
assert(visible==false and last()=='respawn result: life 3/1, death screen up/hidden, EVE pawn same, mode 1',last())
refuse=true
fall()
pass(r,4)
assert(r.status():find('^recovery stopped'),r.status())
assert(visible==true,'The screen is shown again when the recovery stops')
assert(logs[#logs-1]:find('^recovery stopped after 2') and last()=='respawn: death screen shown again (the recovery '
    ..'stopped)',last())
die()
pass(r,40)
assert(visible==true and #respawns==1 and count('death screen shown again')==1,'Nothing more after the stop')
-- show_in_any_mode: a new death shows the screen the part hid in the modes off and death too. In the mode off the death
-- is not handled, so nothing else would show it.
for _,word in ipairs({'off','death'}) do
    r=fresh()
    playing,revive=true,1
    die()
    pass(r,9)
    assert(visible==false,last())
    assert(r.mode(word))
    die()
    pass(r)
    assert(visible==true and count('respawn: death screen shown again (a new death)')==1,word..': '..last())
end
-- A stop before the call drops the death being handled. So does an arrival. A pass after it that still reads life
-- 3 starts a new death, with its line and its reason said again.
for _,drop in ipairs({function() r.stop('a map change') end,function() r.arrive('city') end}) do
    r=fresh()
    standalone=false
    die()
    pass(r,30)
    assert(count('death: life 3')==1 and count('respawn waits: the game is not standalone')==1)
    drop()
    pass(r,30)
    assert(count('death: life 3')==2 and count('respawn waits: the game is not standalone')==2,'A new death')
    assert(not logged('failure'),'The 10 s of the dropped death do not count')
end

-- no_screen: with no death screen playing, the call is made 5 s after the death started.
r=fresh()
die()
pass(r,19)
assert(#respawns==0 and last()=='respawn waits: no death screen',last())
pass(r)
assert(#respawns==1 and last()=='respawn: ServerRequest_ActorRespawn(2610, false) asked (life 3, no death screen in 5 '
    ..'s)',last())
warp_line,eve.mode='sboxionwarp=entered asks=1 life=1',1
pass(r,8)
assert(last()=='respawn result: life 3/1, death screen off/off, EVE pawn same, mode 1' and visible==true,last())
-- No widget at all: the same. It is looked for once in those 10 s.
r=fresh()
there=false
die()
pass(r,20)
assert(#respawns==1 and looks==1,'One search for the widget')
warp_line,eve.mode,eve.pawn='sboxionwarp=entered asks=1 life=6',1,0x7100
pass(r,8)
assert(last()=='respawn result: life 3/6, death screen gone/gone, EVE pawn new, mode 1',last())

-- off_the_ground: a respawn that leaves her falling under the floor puts her on the ground point, in the mode death
-- too. The walking read after it is the success.
for _,word in ipairs({'on','death'}) do
    r=fresh()
    walk(r,6)
    assert(r.mode(word))
    playing,revive=true,1
    eve.at.Z,eve.mode=-25367,3
    if word=='on' then -- The fall is caught first; here it leaves her falling, then SB's timer kills her.
        pass(r,3)
        assert(#puts==1)
        eve.at.Z=-25367
    else pass(r,4) end
    die()
    pass(r)
    assert(#respawns==1 and logged('death: life 3, EVE at ('..(word=='on' and 300 or 600)..', 0, -25367)'),last())
    pass(r,8)
    local n,b=#puts,#blacks
    assert(logs[#logs-1]=='respawn result: life 3/1, death screen up/hidden, EVE pawn same, mode 3',logs[#logs-1])
    -- black_death: the put-back after the respawn shows the same fade and comes two passes later.
    assert(last():find('^black: up in 0%.3 s; EVE at %(%d+, 0, %-25367%) moves in 2 passes$'),last())
    assert(n==(word=='on' and 1 or 0) and b==n+1 and blacks[b].fade==0.3 and order[#order]=='black',word)
    pass(r)
    assert(#puts==n,'One pass after the black: not yet')
    pass(r)
    n=#puts
    assert(last():find('^death: EVE at %(%d+, 0, %-25367%) not on the ground: to the ground point %(300, 0, 225%) '),
        last())
    assert(puts[n].at.X==300 and puts[n].at.Z==235 and n==(word=='on' and 2 or 1),word)
    assert(#blacks==b and order[#order]=='put','No second black for one put-back')
    eve.mode=1
    pass(r)
    assert(last():find('^put back: EVE walks at %(300, 0, 235%), 0.2 s after the move'),last())
end
-- Above the floor and falling after the respawn: put back too. A guard that waits then: nothing is moved.
r=fresh()
walk(r,6)
playing,revive=true,1
die(500)
pass(r,11)
assert(#puts==1 and logged('death: EVE at (600, 0, 500) not on the ground'),last())
r=fresh()
walk(r,6)
playing,revive=true,1
die(500)
pass(r)
photo='1'
pass(r,8)
assert(#puts==0 and logged('respawn result: life 3/1'),'No put-back while a guard waits')
assert(#blacks==0,'No black either while a guard waits')

-- still_dead: life still 3 two seconds after the call is a failure; the death starts again; the second stops the
-- recovery, with two calls and no third. The mode word starts it again.
r=fresh()
playing=true
die()
pass(r,9)
assert(last()=='respawn result: life 3/3, death screen up/up, EVE pawn same, mode 1: failure 1 of 2' and visible,
    last())
pass(r)
assert(#respawns==2 and count('death: life 3')==2,'The death starts again on the next pass')
pass(r,8)
assert(logs[#logs-1]:find('respawn result: life 3/3.*: failure 2 of 2') and last():find('^recovery stopped after 2'),
    last())
pass(r,60)
assert(#respawns==2 and count('death: life 3')==2,'No third call')
local ok,line=r.mode('death')
assert(ok and line=='recovery mode death: falls are not caught, deaths are')
revive=1
pass(r)
assert(#respawns==3 and count('death: life 3')==3,'Started again by the word')
pass(r,8)
assert(logged('respawn result: life 3/1') and r.status():find('^recovery death, .* failures 0$'),r.status())

-- off_then_on: a death left from the mode off is asked once the mode is on.
r=fresh()
playing=true
assert(r.mode('off'))
die()
pass(r,20)
assert(#respawns==0 and not logged('death:'),'Nothing in the mode off')
assert(r.mode('on'))
pass(r)
assert(#respawns==1 and logged('death: life 3'),last())
-- off_during_death: coop xion recover off drops a death being handled: no call after it and no failure.
r=fresh()
standalone=false
die()
pass(r,2)
assert(last()=='respawn waits: the game is not standalone',last())
assert(r.mode('off'))
standalone,playing=true,true
pass(r,60)
assert(#respawns==0 and count('death: life 3')==1 and not logged('failure'),last())
-- respawn_walking: a respawn that leaves her walking sets the failures to 0.
r=fresh()
playing,revive=true,1
broken='no world'
pass(r)
broken=nil
assert(r.status():find('failures 1',1,true),r.status())
die()
pass(r,9)
assert(last()=='respawn result: life 3/1, death screen up/hidden, EVE pawn same, mode 1',last())
assert(r.status():find('failures 0',1,true),r.status())
-- death_drops_check: a death that starts while a put-back is checked drops the check. After the respawn nothing is
-- said of that put-back.
r=fresh()
walk(r,6)
playing,revive=true,1
fall()
pass(r,3)
assert(#puts==1)
eve.at.Z=100
die()
pass(r)
assert(#respawns==1 and logged('death: life 3, EVE at (300, 0, 100)'),last())
eve.mode=1
pass(r,12)
assert(logged('respawn result: life 3/1') and #puts==1 and not logged('put back'),last())
-- guard_wait: a death read while a guard waits is asked once the wait ends.
r=fresh()
playing,photo=true,'1'
die()
pass(r,8)
assert(#respawns==0 and not logged('death:'),'No death starts while a guard waits')
photo='0'
pass(r)
assert(#respawns==1,last())
-- still_world: the respawn is asked on a world time that stands still.
r=fresh()
playing=true
pass(r,2)
die()
pass(r,1,true)
assert(#respawns==1,'Asked in a stopped world')
warp_line='sboxionwarp=entered asks=1 life=1'
pass(r,8,true)
assert(logged('respawn result: life 3/1'),'The result is read in a stopped world')
-- alive_again: her life back at 1 before the call ends the death with no failure.
r=fresh()
standalone=false
die()
pass(r,2)
warp_line='sboxionwarp=entered asks=1 life=1'
pass(r)
assert(last()=='death: over before the respawn was asked (life 1)',last())
pass(r,60)
assert(#respawns==0 and not logged('failure'))
assert(count('death: over before')==1,'Said once: the death is over, not read again on each pass')
fall()
pass(r,3)
assert(#puts==1,'The fall after it is caught')
-- no_warp_word: the call needs her GUID from the engine line. Two waits of 10 s stop the recovery.
r=fresh()
engine='engine=on remote=0 0 none theater=none'
playing=true
die()
pass(r,2)
assert(last()=='respawn waits: no warp read' and count('the engine line has no warp= word')==1,last())
pass(r,38)
assert(last()=='respawn not asked in 10 s: no warp read: failure 1 of 2',last())
pass(r,40)
assert(last():find('^recovery stopped after 2') and #respawns==0 and count('death: life 3')==2,last())
-- The life word is read on the refused and fault forms too, before where=.
for _,l in ipairs({'sboxionwarp=refused asks=2 verb=leave why=camp life=3',
    'sboxionwarp=fault asks=2 life=3 where=SB.exe+0x10 (a read of life=1)'}) do
    r=fresh()
    playing=true
    warp_line=l
    pass(r)
    assert(#respawns==1 and logged('death: life 3'),l)
end

-- black_not_shown: a black SB does not show changes one log line. The move is made two passes later all the same and
-- the walking read after it is the success.
for _,c in ipairs({
    {function() black_error='LoadingScreenFadeAuto: no such function' end,
        'black: not shown: LoadingScreenFadeAuto: no such function; EVE at (600, 0, -3276) moves in 2 passes'},
    {function() black_up=false end,
        'black: not shown: SB made no loading screen; EVE at (600, 0, -3276) moves in 2 passes'},
    {function() black_up=nil end,'black: asked, its handle did not read; EVE at (600, 0, -3276) moves in 2 passes'},
}) do
    r=fresh()
    walk(r,6)
    c[1]()
    fall()
    pass(r)
    assert(last()==c[2] and #blacks==1 and #puts==0,last())
    pass(r,2)
    assert(#puts==1 and puts[1].at.X==300,'The move does not depend on the black: '..c[2])
    eve.mode=1
    pass(r)
    assert(last()=='put back: EVE walks at (300, 0, 235), 0.2 s after the move' and not logged('failure'),last())
end
-- black_once: one black a put-back, none more during the lead's passes or during the check. A second fall after the
-- success asks a second one.
r=fresh()
walk(r,6)
fall()
pass(r,3)
assert(#blacks==1 and #puts==1)
pass(r,4) -- The check runs: she still reads falling, above the floor.
assert(#blacks==1 and #puts==1,'No black while a put-back is checked')
eve.mode=1
pass(r)
assert(logged('put back: EVE walks'),last())
walk(r,4)
fall()
pass(r)
assert(#blacks==2 and #puts==1,'A second fall: a second black')
pass(r,2)
assert(#blacks==2 and #puts==2)
-- lead_waits: the move that waits under the black is counted like a check: not while a guard waits and not on a world
-- time that stands still.
r=fresh()
walk(r,6)
fall()
pass(r)
photo='1'
pass(r,8)
assert(#puts==0,'No move while a guard waits')
photo='0'
pass(r)
assert(#puts==0,'The wait used up no pass of the lead')
pass(r)
assert(#puts==1 and #blacks==1,'Moved once the passes count again')
r=fresh()
walk(r,6)
fall()
pass(r)
pass(r,8,true)
assert(#puts==0,'No move on a world time that stands still')
pass(r,2)
assert(#puts==1 and #blacks==1)
-- lead_dropped: a move that waits under the black is dropped where a check is dropped: the mode off, an arrival, a
-- stop, a death that starts and an error in a pass.
local function waiting_move()
    r=fresh()
    walk(r,6)
    fall()
    pass(r,2) -- The black, then one pass of the lead: the move is due at the next pass.
    assert(#blacks==1 and #puts==0)
end
waiting_move()
assert(r.mode('off'))
pass(r,4)
assert(#puts==0 and #blacks==1,'The mode off drops it')
waiting_move()
r.arrive('city')
eve.at.Z,eve.mode=225,1 -- She walks above the floor in the new stay.
pass(r,4)
assert(#puts==0 and #blacks==1,'An arrival drops it')
waiting_move()
r.stop('coop off')
pass(r)
assert(#puts==0,'A stop drops it: no move at the pass it was due')
waiting_move()
playing,revive=true,1
die()
pass(r)
assert(logged('death: life 3'),last())
eve.at.Z,eve.mode=225,1 -- The respawn leaves her walking above the floor: no put-back of the death rule.
pass(r,12)
assert(logged('respawn result: life 3/1') and #puts==0,'A death that starts drops it')
waiting_move()
broken='x'
pass(r)
assert(#puts==0 and last()=='recovery: error (x): failure 1 of 2',last())
broken=nil
pass(r)
assert(#puts==1 and puts[1].at.X==-8303.969,'After the failure the move is made at once, to the arrival point')
assert(#blacks==2 and last()=='black: up at once','It is a new put-back with its own black: '..last())

-- busy, for the Tetrapod's door: false with the pass's own read of EVE while she walks; true while a guard waits,
-- while a move waits under the black and while a put-back is checked; no read once the recovery stopped.
r=fresh()
walk(r,4)
local busy,read=r.busy()
assert(busy==false and read.at.X==eve.at.X and read.mode==1 and read.time==eve.time,'Free, with the read of the pass')
photo='1'
pass(r)
busy,read=r.busy()
assert(busy==true and read.at.X==eve.at.X,'A guard waits')
photo='0'
pass(r)
assert(r.busy()==false)
fall()
pass(r)
assert(r.busy()==true and #puts==0,'A move waits under the black')
pass(r,2)
assert(#puts==1 and r.busy()==true,'A put-back is checked')
eve.mode=1
pass(r)
assert(r.busy()==false,'She walks again: '..last())
broken='lost pawn'
pass(r,2)
assert(logged('recovery stopped after 2 failures in a row'),last())
broken=nil
pass(r)
busy,read=r.busy()
assert(read==nil,'A stopped recovery reads nothing')
print('sboxion_recover_test ok')
