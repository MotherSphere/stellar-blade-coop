-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Tetrapod's door of SBO Xion (world/maps/sboxion/tetrapod.lua) over a fake world. The frame: SB's own point
-- inside the ship reads (81, 624, 332) in the ship frame and a point taken to the world and back is the same. The
-- data: EVE arrives inside 1.2 m from the hatch box, at the height of SB's point, facing the cabin. SB's point
-- outside is far from the door box. The way in: one pass in the door box moves nothing; at the second SB's black is
-- asked (0.3 s in, 1 s black, 0.5 s out) and two passes later EVE goes to the point inside plus 10 cm; nothing is
-- looked at for the next 8 passes. The way out: two passes in the hatch box, the black, then SB's point in front of
-- the Tetrapod. A pass outside the box between two passes inside starts the count again. While the recovery is busy
-- nothing is counted. A refused teleport and a black that raises each change one log line. An error in a pass turns
-- the door off with one line until the next arrival. coop xion tetrapod in and out ask the move at once, refuse a
-- second one under way and say where EVE is with no word. An arrival drops a move that waits. No EVE: nothing.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Tetrapod=require('world.maps.sboxion.tetrapod')
local D=require('world.maps.sboxion.data')
local T=D.TETRAPOD
assert(T.STAY==2 and T.HOLD==8 and D.LEAD==2 and D.LIFT==10)

local function near(a,b,by) return math.abs(a-b)<=(by or 0.01) end
-- The frame. SB's point inside, SBSpawnPoint43 of E04_LD_Respawn, in the ship frame.
local sb=Tetrapod.ship({X=16362.827,Y=-24523.453,Z=-1865.1406})
assert(near(sb.x,81,1) and near(sb.y,624,1) and near(sb.z,332,1),string.format('%.1f %.1f %.1f',sb.x,sb.y,sb.z))
local back=Tetrapod.world(sb)
assert(near(back.X,16362.827) and near(back.Y,-24523.453) and near(back.Z,-1865.1406))
-- The data. The point inside: on the ship's right, 1.2 m short of the hatch box, at the height of SB's own point.
assert(T.IN.x==240 and T.IN.y==397 and near(T.IN.z,sb.z,1) and T.IN.yaw==180)
assert(T.HATCH.lo.x-T.IN.x==120 and T.IN.y>T.HATCH.lo.y and T.IN.y<T.HATCH.hi.y)
assert(sb.x<T.HATCH.lo.x,"SB's own point inside is not in the hatch box")
local IN=Tetrapod.world(T.IN)
assert(near(IN.X,16637.5,0.5) and near(IN.Y,-24557.9,0.5) and near(IN.Z,-1865.2,0.1),
    string.format('%.1f %.1f %.1f',IN.X,IN.Y,IN.Z))
assert(T.OUT.Y<T.DOOR.lo.Y-1000,"SB's point outside is more than 10 m in front of the door box")
assert(T.DOOR.hi.X-T.DOOR.lo.X==244 and T.DOOR.hi.Y-T.DOOR.lo.Y==229)

local logs,puts,blacks,order={},{},{},{}
local eve,refuse,black_error,broken=nil,false,nil,nil
local world={
    move=function()
        if broken then error(broken) end
        return eve and {at={X=eve.X,Y=eve.Y,Z=eve.Z},yaw=0,mode=1,time=0,pawn=1}
    end,
    put=function(at,yaw)
        puts[#puts+1]={at=at,yaw=yaw}
        order[#order+1]='put'
        if refuse then return false end
        eve={X=at.X,Y=at.Y,Z=at.Z}
        return true
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
local STEPS={X=-13265,Y=19400,Z=200} -- On the steps, short of the box.
local HATCH=Tetrapod.world({x=400,y=397,z=340}) -- At the ship's right door, inside.
local CABIN=Tetrapod.world({x=0,y=0,z=340})
local function fresh() logs,puts,blacks,order={},{},{},{}; refuse,black_error,broken=false,nil,nil; door.arrive() end

-- No EVE: nothing.
fresh()
assert(logged('tetrapod: door on'),logs[1])
pass(5)
assert(#puts==0 and #blacks==0)
-- The way in.
eve=STEPS
pass(5)
assert(#blacks==0,'the steps are not the doorway')
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
assert(#puts==1 and order[1]=='black' and order[2]=='put')
assert(near(puts[1].at.X,IN.X) and near(puts[1].at.Y,IN.Y) and near(puts[1].at.Z,IN.Z+10),'inside, 10 cm up')
assert(near(puts[1].yaw,-132.188366,0.001),'facing the cabin: '..puts[1].yaw)
assert(logged('tetrapod: in: EVE at (16638, -24558, -1865), yaw -132.2'),logs[#logs])
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
