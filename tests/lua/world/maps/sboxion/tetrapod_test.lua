-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Tetrapod's door of SBO Xion (world/maps/sboxion/tetrapod.lua) over a fake world. The frame: SB's own point
-- inside the ship reads (81, 624, 332) in the ship frame and a point taken to the world and back is the same. The
-- data: EVE arrives inside 1.2 m from the hatch box, 13 cm over SB's point, facing the cabin. SB's point
-- outside is far from the door box. The way in: one pass in the door box moves nothing; at the second SB's black is
-- asked (0.3 s in, 1 s black, 0.5 s out) and two passes later EVE goes to the point inside plus 10 cm; nothing is
-- looked at for the next 8 passes. The way out: two passes in the hatch box, the black, then SB's point in front of
-- the Tetrapod. A pass outside the box between two passes inside starts the count again. While the recovery is busy
-- nothing is counted. A refused teleport and a black that raises each change one log line. An error in a pass turns
-- the door off with one line until the next arrival. coop xion tetrapod in and out ask the move at once, refuse a
-- second one under way and say where EVE is with no word. An arrival drops a move that waits. No EVE: nothing.
-- The floor: SB ships the ship with no collision, so the way in asks the engine to make its parts solid before the
-- move and the way out and coop off put them back. After the way in EVE is watched until she stands: under the point
-- by more than 60 cm she is put on it again, the ship is asked again while it was not found and a black that is up
-- at once comes every 6 passes. After 32 passes with no floor she is put back outside with the ship as SB ships it.
-- A recovery that moved her out of the ship ends the watch. No other part of the module waits for this door, so it
-- has no busy().
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Tetrapod=require('world.maps.sboxion.tetrapod')
local D=require('world.maps.sboxion.data')
local T=D.TETRAPOD
assert(T.STAY==2 and T.HOLD==8 and D.LEAD==2 and D.LIFT==10 and T.DROP==60 and T.AGAIN==6 and T.SETTLE==32)

local function near(a,b,by) return math.abs(a-b)<=(by or 0.01) end
-- The frame. SB's point inside, SBSpawnPoint43 of E04_LD_Respawn, in the ship frame.
local sb=Tetrapod.ship({X=16362.827,Y=-24523.453,Z=-1865.1406})
assert(near(sb.x,81,1) and near(sb.y,624,1) and near(sb.z,332,1),string.format('%.1f %.1f %.1f',sb.x,sb.y,sb.z))
local back=Tetrapod.world(sb)
assert(near(back.X,16362.827) and near(back.Y,-24523.453) and near(back.Z,-1865.1406))
-- The data. The point inside: on the ship's right, 1.2 m short of the hatch box, 13 cm over SB's own point.
assert(T.IN.x==240 and T.IN.y==397 and T.IN.z==345 and T.IN.yaw==180)
assert(T.HATCH.lo.x-T.IN.x==120 and T.IN.y>T.HATCH.lo.y and T.IN.y<T.HATCH.hi.y)
assert(sb.x<T.HATCH.lo.x,"SB's own point inside is not in the hatch box")
local IN=Tetrapod.world(T.IN)
assert(near(IN.X,16637.5,0.5) and near(IN.Y,-24557.9,0.5) and near(IN.Z,-1851.7,0.1),
    string.format('%.1f %.1f %.1f',IN.X,IN.Y,IN.Z))
assert(T.OUT.Y<T.DOOR.lo.Y-900,"SB's point outside is more than 9 m in front of the door box")
assert(T.DOOR.hi.X-T.DOOR.lo.X==344 and T.DOOR.hi.Y-T.DOOR.lo.Y==441 and T.DOOR.lo.Z==150)

local logs,puts,blacks,order={},{},{},{}
local eve,refuse,black_error,broken=nil,false,nil,nil
-- The ship: each ask (true or false); the parts it answers (nil: not in memory) or the error it raises. lands: the
-- movement mode a put leaves EVE in (1 walking, 3 falling).
local ships,parts,ship_error,lands={},124,nil,1
local world={
    move=function()
        if broken then error(broken) end
        return eve and {at={X=eve.X,Y=eve.Y,Z=eve.Z},yaw=0,mode=eve.mode or 1,time=0,pawn=1}
    end,
    put=function(at,yaw)
        puts[#puts+1]={at=at,yaw=yaw}
        order[#order+1]='put'
        if refuse then return false end
        eve={X=at.X,Y=at.Y,Z=at.Z,mode=lands}
        return true
    end,
    ship=function(solid)
        ships[#ships+1]=solid
        order[#order+1]='ship '..tostring(solid)
        if ship_error then error(ship_error) end
        return parts
    end,
    black=function(hold,fade,out)
        blacks[#blacks+1]={hold=hold,fade=fade,out=out}
        order[#order+1]='black'
        if black_error then error(black_error) end
        return true
    end,
}
local function logged(text)
    for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
    return false
end
local door=Tetrapod.new({log=function(m) logs[#logs+1]=m end,world=world})
local function pass(n,busy) for _=1,n or 1 do door.tick(busy) end end
local DOOR={X=-13265,Y=19600,Z=347} -- In the doorway of the Tetrapod of the hangar.
local STEPS={X=-13265,Y=19200,Z=120} -- On the lower steps, short of the box.
local STOOD={X=-13156,Y=19351,Z=250} -- Where EVE stood on the steps in the first game test.
local HATCH=Tetrapod.world({x=400,y=397,z=340}) -- At the ship's right door, inside.
local CABIN=Tetrapod.world({x=0,y=0,z=340})
local function fresh()
    logs,puts,blacks,order,ships={},{},{},{},{}
    refuse,black_error,broken,parts,ship_error,lands=false,nil,nil,124,nil,1
    door.arrive()
end

-- No EVE: nothing.
fresh()
assert(logged('tetrapod: door on'),logs[1])
pass(5)
assert(#puts==0 and #blacks==0 and door.busy==nil)
-- The way in.
eve=STEPS
pass(5)
assert(#blacks==0,'the lower steps are not the doorway')
eve=STOOD
pass(2)
assert(#blacks==1,'the top of the steps, where she stood in the first game test, is')
fresh()
eve=DOOR
pass()
assert(#blacks==0 and #puts==0,'one pass in the doorway moves nothing')
pass()
assert(#blacks==1 and blacks[1].hold==1 and blacks[1].fade==0.3 and blacks[1].out==0.5 and #puts==0,
    'the second pass asks the black')
assert(logged('tetrapod: in asked'),logs[#logs])
pass()
assert(#puts==0,'the move waits under the black')
pass()
assert(#puts==1 and table.concat(order,', ')=='black, ship true, put','The ship is made solid before the move')
assert(near(puts[1].at.X,IN.X) and near(puts[1].at.Y,IN.Y) and near(puts[1].at.Z,IN.Z+10),'inside, 10 cm up')
assert(near(puts[1].yaw,-132.188366,0.001),'facing the cabin: '..puts[1].yaw)
assert(logged('tetrapod: in: EVE at (16638, -24558, -1852), yaw -132.2'),logs[#logs])
-- Where she arrives is no box: standing there moves nothing, during the hold and after it.
pass(20)
assert(#puts==1 and #blacks==1,'the point inside is not in the hatch box')
-- The hold: 8 passes after a move look at nothing, the ninth counts again.
eve=HATCH
fresh()
eve=DOOR
pass(4) -- In.
assert(#puts==1)
eve=HATCH
pass(8)
assert(#blacks==1,'nothing is looked at for 8 passes after a move')
pass()
assert(#blacks==1,'the ninth pass is the first one counted')
pass()
assert(#blacks==2,'the tenth asks the black for the way out')
pass(2)
assert(#puts==2 and puts[2].at.X==T.OUT.X and puts[2].at.Y==T.OUT.Y and puts[2].at.Z==T.OUT.Z+10
    and puts[2].yaw==T.OUT.Yaw,"out at SB's point in front of the Tetrapod")
assert(logged('tetrapod: out: EVE at (-13413, 18383, 82), yaw -87.2'),logs[#logs])
-- A pass outside the box starts the count again.
fresh()
eve=DOOR
pass()
eve=STEPS
pass()
eve=DOOR
pass()
assert(#blacks==0,'two passes in a row are needed')
pass()
assert(#blacks==1)
-- While the recovery is busy nothing is counted.
fresh()
eve=DOOR
pass(6,true)
assert(#blacks==0,'the recovery is busy')
pass()
assert(#blacks==0,'the count started again')
pass()
assert(#blacks==1)
-- A refused teleport: one line, the hold still runs.
fresh()
eve=DOOR
refuse=true
pass(4)
assert(#puts==1 and logged('refused by K2_TeleportTo'),logs[#logs])
refuse=false
pass(8)
assert(#blacks==1,'the hold runs after a refused move too')
pass(2)
assert(#blacks==2,'she still stands in the doorway: asked again')
-- A black that raises changes one log line and not the move.
fresh()
eve=DOOR
black_error='no library'
pass(2)
assert(logged('black not shown: no library'),logs[#logs])
pass(2)
assert(#puts==1,'the move is made whatever the black did')
-- An error in a pass: off with one line until the next arrival.
fresh()
eve=DOOR
broken='lost pawn'
pass(3)
local n=0
for _,l in ipairs(logs) do
    if l:find('tetrapod: door off until the next arrival: error (lost pawn)',1,true) then n=n+1 end
end
assert(n==1,'one line: '..n)
broken=nil
pass(5)
assert(#blacks==0,'off')
local ok,line=door.go('in')
assert(not ok and line=='coop xion tetrapod: the door is off until the next arrival: lost pawn',line)
fresh()
pass(2)
assert(#blacks==1,'the next arrival turns it on again')
-- coop xion tetrapod [in|out].
fresh()
eve=STEPS
ok,line=door.go()
assert(ok and line=='EVE is outside the Tetrapod, door on',line)
ok,line=door.go('in')
assert(ok and line=='in: the move is asked' and #blacks==1,line)
ok,line=door.go('out')
assert(not ok and line=='coop xion tetrapod: a move is under way' and #blacks==1,line)
pass(2)
assert(#puts==1 and near(puts[1].at.X,IN.X))
ok,line=door.go()
assert(ok and line=='EVE is inside the Tetrapod, door on',line)
eve=CABIN
ok,line=door.go()
assert(ok and line=='EVE is inside the Tetrapod, door on',line)
ok,line=door.go('out') -- During the hold too: the command is no walk into a box.
assert(ok and #blacks==2,line)
pass(2)
assert(#puts==2 and puts[2].at.X==T.OUT.X)
ok,line=door.go('up')
assert(not ok and line=='Use: coop xion tetrapod [in|out]',line)
eve=nil
ok,line=door.go('in')
assert(not ok and line=='coop xion tetrapod: no EVE',line)
-- The floor. The way in makes the ship solid, the first pass that reads her walking says so.
fresh()
eve=DOOR
pass(4)
assert(#ships==1 and ships[1]==true and not logged('stands in the ship'))
pass()
assert(logged('tetrapod: in: EVE stands in the ship after 1 passes, 124 parts solid'),logs[#logs])
pass(20)
assert(#ships==1 and #puts==1,'Nothing more once she stands')
-- The way out puts the ship back as SB ships it, after the move.
eve=HATCH
pass(2)
pass(2)
assert(#puts==2 and ships[2]==false and order[#order]=='ship false' and order[#order-1]=='put')
assert(logged('tetrapod: ship as SB ships it again: 124 parts'),logs[#logs])
-- The ship's level comes in late: it is not found at the move and EVE falls. Each pass that reads her 60 cm under
-- the point puts her on it again and asks the ship again; once it is solid she stands.
fresh()
parts,lands=nil,3
eve=DOOR
pass(4)
assert(#puts==1 and #ships==1 and logged('tetrapod: in: EVE at (16638, -24558, -1852), yaw -132.2'))
eve.Z=eve.Z-40
pass()
assert(#puts==1 and #ships==2,'40 cm under the point is no fall yet; the ship is asked again')
eve.Z=eve.Z-40
pass()
assert(#puts==2 and near(puts[2].at.Z,IN.Z+10) and #ships==3,'80 cm under: on the point again')
assert(logged('tetrapod: in: no floor yet under EVE at (16638, -24558, -1922): on the point again (ship not found)'),
    logs[#logs])
local lines=#logs
eve.Z=eve.Z-80
pass()
assert(#puts==3 and #logs==lines,'Said once')
parts,lands=124,1
eve.Z=eve.Z-80
pass()
assert(#puts==4 and #ships==5 and ships[5]==true,'Found: made solid. She is put on the point once more')
pass()
assert(logged('tetrapod: in: EVE stands in the ship after 5 passes, 124 parts solid'),logs[#logs])
-- A black that is up at once every 6 passes while she has no floor.
fresh()
lands=3
eve=DOOR
pass(4)
local function drop() eve.Z=eve.Z-100; pass() end
for _=1,5 do drop() end
assert(#blacks==1,'5 passes: the first black still stands')
drop()
assert(#blacks==2 and blacks[2].fade==0 and blacks[2].hold==1,'The sixth pass asks a black that is up at once')
for _=1,6 do drop() end
assert(#blacks==3)
-- No floor after 32 passes: back outside, the ship as SB ships it.
for _=13,31 do drop() end
assert(#puts==32 and not logged('back outside'))
lands=1
drop()
assert(puts[#puts].at.X==T.OUT.X and ships[#ships]==false,'Outside at SB\'s point')
assert(logged('tetrapod: in: no floor under EVE after 32 passes (124 parts solid): back outside'),logs[#logs])
local n=#puts
pass(20)
assert(#puts==n,'Nothing more')
-- The recovery moved her out of the ship while she was watched: the watch ends, the ship is put back.
fresh()
lands=3
eve=DOOR
pass(4)
eve={X=-12973,Y=19176,Z=85,mode=1}
pass()
assert(logged('tetrapod: in: EVE is out of the ship at (-12973, 19176, 85) before she stood: the watch ends')
    and ships[#ships]==false and #puts==1,logs[#logs])
-- The ship's call raises: said once, the move is made all the same.
fresh()
ship_error='no actor'
lands=3
eve=DOOR
pass(4)
eve.Z=eve.Z-100
pass(3)
local said=0
for _,l in ipairs(logs) do if l:find('tetrapod: ship: unread (no actor)',1,true) then said=said+1 end end
assert(#puts>=2 and said==1,'One line: '..said)
-- coop off puts the ship back when this stay made it solid. Otherwise it asks nothing.
fresh()
door.stop()
assert(#ships==0,'Nothing was made solid')
eve=DOOR
pass(5)
door.stop()
assert(ships[#ships]==false and #ships==2)
door.stop()
assert(#ships==2,'Once')
-- An arrival drops a move that waits.
fresh()
eve=DOOR
pass(2)
assert(#blacks==1)
door.arrive()
eve=STEPS
pass(4)
assert(#puts==0,'the arrival dropped the move')
print('sboxion_tetrapod_test ok')
