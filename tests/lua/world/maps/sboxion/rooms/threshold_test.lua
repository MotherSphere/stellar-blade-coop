-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's threshold doors (world/maps/sboxion/rooms/threshold.lua) over a fake world, a fake pak gate and a fake
-- door file. The rooms are those of rooms/list.lua that carry a threshold. Every place below is worked out from a
-- room's own numbers, so the test holds when a room leaves the list.
-- The pak: each room asked on its own at an arrival, one line for what the pak holds, a room the pak lacks never
-- pushed, a gate that raises leaving its room out.
-- The level: a way in needs the room's level loaded and visible on the streaming list, read once a whole push. Not
-- visible, not loaded, off the list or a read that raises: no black, no move, nothing opened, one line a door a
-- stay. The other doors go on and the door works once its level is there. The way out never asks.
-- The push, way in: EVE on the ground within 100 cm in front of the street door's plane, inside its width, 40 to 160
-- cm over its floor, turned toward it within 50 degrees, for 3 passes in a row. Each of those limits is tried 1 cm
-- or 1 degree on both sides. Running along the facade, her back to the door and a pass elsewhere do nothing. Then
-- SB's black (0.3 s in, 1 s black, 0.5 s out) and two passes later the move to the room's point inside, as high over
-- the room floor as she stood over the street plus 10 cm, turned into the room. A black that raises changes one
-- line.
-- The push, way out: the same on the inner door from inside, turned toward the street, then the move to the point
-- outside, turned away from the door. A room with a passage counts the passage too.
-- A push that fails: EVE close to a door or turned toward it for 8 passes with no push gets one line a door and way
-- a stay, with her place, her distance, her turn and her height. Too far and turned away, as a move leaves her, a
-- floor above, busy passes and a real push say nothing.
-- The watch: the first pass that reads her walking 40 to 160 cm over the floor she was put on says she stands. Under
-- 40 cm, or not standing after 32 passes, she is put back where she pushed, under a black that is up at once.
-- One line says so and that door does nothing more until the next arrival. The other doors go on. A refused move
-- ends the same way.
-- Locked and opened: the first push of a door says it opened and writes its name to the door file. A later push
-- says nothing and writes nothing. A new Lua load reads the file. Names the list does not know stay in the file. A
-- file that cannot be written or read is one line and stops nothing.
-- A requirement: a door whose requirement is not met does nothing and says so once a stay. Met, it opens. Once
-- opened it asks no more. The way out never asks.
-- It waits while the recovery or the Tetrapod's door is busy: such a pass counts nothing and a move already asked is
-- still made. busy() says a move waits or is watched. coop xion rooms off turns the doors off until on or the next
-- arrival. An arrival drops a move that waits. An error in a pass turns them off with one line until the next
-- arrival. With the pass's read of EVE handed over, the part reads her no second time.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Threshold=require('world.maps.sboxion.rooms.threshold')
local D=require('world.maps.sboxion.data')
local T=D.THRESHOLD
assert(T.REACH==100 and T.TURN==50 and T.PUSH==3 and T.LOW==40 and T.HIGH==160 and T.SETTLE==32
    and T.IDLE==8 and D.LEAD==2 and D.LIFT==10)
local LIST=Threshold.LIST
assert(#LIST>=2,'Two threshold rooms at least: '..#LIST)
local NAMES={}
for i,room in ipairs(LIST) do
    NAMES[i]=room.name
    assert(room.level=='Xion_Rooms_'..room.name and room.umap=='/Game/SBO_World/Rooms/'..room.level,
        'The game path the pak gate is asked for')
end
local ALL=table.concat(NAMES,', ')
local A,B=LIST[1],LIST[2]
local STAND=97 -- cm from the floor to the middle of EVE's capsule, as a game log read her.
-- A place against a door's centre p: d cm behind its plane along the way in (negative: in front), u cm across, h cm
-- over its floor.
local function at(room,p,d,u,h)
    return {X=p.X+d*room.cos-u*room.sin,Y=p.Y+d*room.sin+u*room.cos,Z=p.Z+(h or STAND)}
end
local function turned(yaw) return (yaw+180)%360-180 end
local function near(a,b,by) return math.abs(a-b)<=(by or 0.01) end

local logs,puts,blacks,order,moves={},{},{},{},0
-- eve: her place with yaw and mode (1 walking, 3 falling). lands: the mode a put leaves her in.
local eve,refuse,black_error,broken,lands=nil,false,nil,nil,1
local world={
    move=function()
        moves=moves+1
        if broken then error(broken) end
        return eve and {at={X=eve.X,Y=eve.Y,Z=eve.Z},yaw=eve.yaw or 0,mode=eve.mode or 1,time=0,pawn=1}
    end,
    put=function(to,yaw)
        puts[#puts+1]={at=to,yaw=yaw}
        order[#order+1]='put'
        if refuse then return false end
        eve={X=to.X,Y=to.Y,Z=to.Z,yaw=yaw,mode=lands}
        return true
    end,
    black=function(hold,fade,out)
        blacks[#blacks+1]={hold=hold,fade=fade,out=out}
        order[#order+1]='black'
        if black_error then error(black_error) end
        return true
    end,
}
-- The streaming list: one level of SB, then each room's level, loaded and visible. down, by room name: what the
-- list says of its level instead ({loaded=, visible=}), or false for a level off the list. levels_error: what the
-- read raises. level_reads: the reads.
local down,levels_error,level_reads={},nil,0
world.levels=function()
    level_reads=level_reads+1
    if levels_error then error(levels_error) end
    local list={{name='E04_Area02_Architecture_A_01',loaded=true,visible=true}}
    for _,room in ipairs(Threshold.LIST) do
        local d=down[room.name]
        if d==nil then d={loaded=true,visible=true} end
        if d then list[#list+1]={name=room.level,loaded=d.loaded,visible=d.visible} end
    end
    return list
end
-- The door file: its one line, each save, what a save answers and what a load raises.
local file,saves,save_fails,load_error=nil,0,nil,nil
local store={
    save=function(line)
        saves=saves+1
        if save_fails then return false,save_fails end
        file=line
        return true
    end,
    load=function() if load_error then error(load_error) end; return file end,
}
-- The pak: has names the rooms it holds (nil: every room). asked: each game path asked.
local has,asked,gate_error=nil,{},nil
local function gate(umap)
    asked[#asked+1]=umap
    local name=umap:match('Xion_Rooms_(%w+)$')
    if name==gate_error then error('no pak folder') end
    if not has or has[name] then return true end
    return nil,'zSBO_Xion.utoc does not hold Xion_Rooms_'..name..'.umap'
end
local met=nil -- What the requirement check answers.
local function logged(text)
    for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end
end
local function times(text) local n=0; for _,l in ipairs(logs) do if l:find(text,1,true) then n=n+1 end end; return n end
local function new()
    return Threshold.new({log=function(m) logs[#logs+1]=m end,world=world,gate=gate,store=store,
        met=function(need) return met and met(need) end})
end
local door=new()
local function pass(n,busy) for _=1,n or 1 do door.tick(busy) end end
local function fresh()
    logs,puts,blacks,order,asked={},{},{},{},{}
    eve,refuse,black_error,broken,lands=nil,false,nil,nil,1
    down,levels_error,level_reads={},nil,0
    door.arrive()
end
-- EVE in front of room's street door, turned toward it, or inside in front of its inner door, turned to the street.
local function street(room,d,u,h,off)
    eve=at(room,room.street,d or -60,u or 0,h)
    eve.yaw=turned(room.yaw+(off or 0))
end
local function inner(room,d,u,h,off)
    eve=at(room,room.inner,d or 60,u or 0,h)
    eve.yaw=turned(room.yaw+180+(off or 0))
end

-- The pak that holds every room: each asked on its own, one line.
fresh()
assert(#logs==1 and logs[1]=='threshold: this pak holds '..#LIST..' of '..#LIST..' rooms: '..ALL..'; opened: none',
    logs[1])
assert(#asked==#LIST and asked[1]==A.umap and asked[#LIST]==LIST[#LIST].umap,'Each room asked on its own')
assert(door.status()=='threshold doors '..#LIST..' in the pak, 0 opened',door.status())
-- No EVE: nothing.
pass(5)
assert(#puts==0 and #blacks==0 and #logs==1)

-- The way in. Two passes of a push move nothing. The third asks SB's black. Two passes later she is inside.
street(A)
local pushed=eve
pass(2)
assert(#blacks==0 and #puts==0,'Two passes are no push')
pass()
assert(#blacks==1 and blacks[1].hold==1 and blacks[1].fade==0.3 and blacks[1].out==0.5 and #puts==0,
    'The third pass asks the black')
assert(logs[#logs]==string.format('threshold: %s in asked (EVE pushed 3 passes at (%.0f, %.0f, %.0f)); black up in '
    ..'0.3 s; EVE moves in 2 passes',A.name,pushed.X,pushed.Y,pushed.Z),logs[#logs])
assert(door.busy(),'A move waits')
pass()
assert(#puts==0,'The move waits under the black')
pass()
assert(#puts==1 and table.concat(order,', ')=='black, put','The black comes before the move')
assert(puts[1].at.X==A.inside.X and puts[1].at.Y==A.inside.Y and near(puts[1].at.Z,A.inside.Z+STAND+10),
    'Inside, as high over the room floor as she stood over the street, plus 10 cm: '..puts[1].at.Z)
assert(near(puts[1].yaw,turned(A.yaw)),'Turned into the room: '..puts[1].yaw)
assert(logs[#logs]==string.format('threshold: %s in: EVE at (%.0f, %.0f, %.0f), yaw %.1f',A.name,A.inside.X,
    A.inside.Y,A.inside.Z,turned(A.yaw)),logs[#logs])
assert(door.busy(),'The move is watched')
pass()
assert(logs[#logs]=='threshold: '..A.name..' in: EVE stands on the room floor after 1 passes' and not door.busy(),
    logs[#logs])
-- Where she arrives she looks into the room: no push, however long she stands.
pass(20)
assert(#puts==1 and #blacks==1,'The point inside is no push')
-- The point inside lies 150 cm inside the inner door, the point outside 150 cm in front of the street door.
for _,room in ipairs(LIST) do
    local c,s=room.cos,room.sin
    local deep=(room.inside.X-room.inner.X)*c+(room.inside.Y-room.inner.Y)*s
    local front=(room.outside.X-room.street.X)*c+(room.outside.Y-room.street.Y)*s
    assert(near(deep,150,0.5) and near(front,-150,0.5),room.name..': '..deep..' and '..front)
end

-- The way out: the same push on the inner door, from inside, turned toward the street.
inner(A)
pushed=eve
pass(2)
assert(#blacks==1)
pass()
assert(#blacks==2 and logs[#logs]==string.format('threshold: %s out asked (EVE pushed 3 passes at (%.0f, %.0f, '
    ..'%.0f)); black up in 0.3 s; EVE moves in 2 passes',A.name,pushed.X,pushed.Y,pushed.Z),logs[#logs])
pass(2)
assert(#puts==2 and puts[2].at.X==A.outside.X and puts[2].at.Y==A.outside.Y
    and near(puts[2].at.Z,A.outside.Z+STAND+10),'Outside, 150 cm in front of the street door')
assert(near(puts[2].yaw,turned(A.yaw+180)),'Turned away from the door: '..puts[2].yaw)
pass()
assert(logs[#logs]=='threshold: '..A.name..' out: EVE stands on the street after 1 passes',logs[#logs])
pass(20)
assert(#puts==2 and #blacks==2,'The point outside is no push: her back is to the door')

-- The place. In front of the plane: 99 cm is a push, 101 cm is none. Behind the plane: none.
local function pushes(n) local b=#blacks; pass(n or 3); return #blacks>b end
local again=fresh -- An arrival: nothing waits, every door on.
again()
street(A,-T.REACH-1)
assert(not pushes(10),'101 cm in front of the plane')
street(A,-T.REACH+1)
assert(pushes(),'99 cm in front of the plane')
again()
street(A,1)
assert(not pushes(10),'Behind the plane')
-- The width.
street(A,-60,A.street.half+1)
assert(not pushes(10),'1 cm past the door\'s width')
street(A,-60,-A.street.half-1)
assert(not pushes(10),'1 cm past it on the other side')
street(A,-60,A.street.half-1)
assert(pushes(),'Inside its width')
-- The height: a floor above or below the door is no push.
again()
street(A,-60,0,T.LOW-1)
assert(not pushes(10),'Under the band')
street(A,-60,0,T.HIGH+1)
assert(not pushes(10),'Over the band')
street(A,-60,0,T.HIGH-1)
assert(pushes(),'At the top of the band')
again()
street(A,-60,0,T.LOW+1)
assert(pushes(),'At its bottom')
-- The turn: 49 degrees is a push, 51 is none, either way. Along the facade and her back to the door: none.
again()
for _,off in ipairs({T.TURN+1,-T.TURN-1,90,-90,180}) do
    street(A,-60,0,nil,off)
    assert(not pushes(10),'Turned '..off..' degrees from the door')
end
street(A,-60,0,nil,T.TURN-1)
assert(pushes(),'Turned 49 degrees from the door')
again()
street(A,-60,0,nil,1-T.TURN)
assert(pushes(),'Turned 49 degrees the other way')
-- On the ground: a jump or a fall in front of the door is no push.
again()
street(A)
eve.mode=3
assert(not pushes(10),'Not on the ground')
eve.mode=2
assert(pushes(),'Walking on the navmesh counts')
-- The passes: three in a row at one door. A pass elsewhere, or at another door, starts the count again.
again()
street(A)
pass(2)
street(A,-300)
pass()
street(A)
assert(not pushes(2),'A pass elsewhere starts the count again')
assert(pushes(1),'The third pass in a row')
again()
street(A)
pass(2)
street(B)
assert(not pushes(2),'Two passes at another door')
assert(pushes(1) and logged('threshold: '..B.name..' in asked'),'The count is the second door\'s')
-- The inner door's limits, from inside: place, width and turn. Her back to the inner door: none.
again()
inner(A,T.REACH+1)
assert(not pushes(10),'101 cm inside the inner door')
inner(A,60,A.inner.half+1)
assert(not pushes(10),'Past the inner door\'s width')
inner(A,60,0,nil,T.TURN+1)
assert(not pushes(10),'Turned 51 degrees from the inner door')
inner(A,60,0,nil,180)
assert(not pushes(10),'Her back to the inner door')
inner(A,-(A.inner.passage or 0)-1)
assert(not pushes(10),'Behind the inner door')
inner(A,T.REACH-1,A.inner.half-1,nil,T.TURN-1)
assert(pushes() and logged('threshold: '..A.name..' out asked'),'99 cm inside, inside its width, turned 49 degrees')
-- A passage: the open doorway behind the inner plane counts to its end.
local P
for _,room in ipairs(LIST) do P=P or room.inner.passage and room end
if P then
    again()
    inner(P,-P.inner.passage-1)
    assert(not pushes(10),'Past the end of the passage')
    inner(P,-P.inner.passage+1)
    assert(pushes() and logged('threshold: '..P.name..' out asked'),'In the passage')
end

-- A push that fails. Turned toward the door from 130 cm: after 8 passes one line with the three numbers a push
-- needs. It comes once a door and way a stay.
again()
street(A,-130)
local stood=eve
pass(7)
assert(not logged('no push'),'Not before 8 passes')
pass()
assert(logs[#logs]==string.format('threshold: %s in: no push in 8 passes with EVE at (%.0f, %.0f, %.0f): 130 cm '
    ..'before the door\'s plane (100 at most), turned 0 degrees from the door (50 at most), 97 cm over its floor (40 '
    ..'to 160)',A.name,stood.X,stood.Y,stood.Z),logs[#logs])
pass(20)
assert(times('no push')==1 and #blacks==0,'Said once')
-- Close to the door and turned away from it: the line gives the turn. The inner door has its own line.
street(B,-60,0,nil,120)
pass(8)
assert(logged('threshold: '..B.name..' in: no push in 8 passes') and logs[#logs]:find('): 60 cm before the door\'s '
    ..'plane (100 at most), turned 120 degrees from the door (50 at most), ',1,true),logs[#logs])
inner(A,60,0,T.HIGH+20)
pass(8)
assert(logged('threshold: '..A.name..' out: no push in 8 passes') and logs[#logs]:find(', 180 cm over its floor (40 '
    ..'to 160)',1,true),logs[#logs])
-- The next arrival says it again.
door.arrive()
street(A,-130)
pass(8)
assert(times(A.name..' in: no push')==2,'Once a stay')
-- Nothing is said: too far and turned away (where a move leaves her), more than 200 cm away, a floor above, 7
-- passes, 7 passes with a busy one or a pass of a real push before the eighth, busy passes, a falling EVE and a
-- real push.
again()
local quiet=#logs
street(A,-150,0,nil,180)
pass(20)
inner(A,150,0,nil,180)
pass(20)
street(A,-2*T.REACH-10)
pass(20)
street(A,-130,0,T.HIGH+101)
pass(20)
street(A,-130)
pass(7)
street(A,-300)
pass()
street(A,-130)
pass(7)
pass(1,true)
pass(7)
street(A)
pass()
street(A,-130)
pass(7)
pass(20,true)
eve.mode=3
pass(20)
assert(#logs==quiet,'Nothing said: '..tostring(logs[#logs]))
street(A)
pass(20)
assert(not logged('no push') and #puts==1,'A real push says no such line')
-- She is put as high over the new floor as she stood over the old one: a ramp or rubble under her does not put her
-- into the floor.
again()
street(A,-60,0,STAND+14)
pass(5)
assert(#puts==1 and near(puts[1].at.Z,A.inside.Z+STAND+14+10),'14 cm higher: '..puts[1].at.Z)
pass()
assert(logged('stands on the room floor after 1 passes'),logs[#logs])

-- A black that raises changes one log line and not the move.
again()
black_error='no library'
street(A)
pass(3)
assert(logged('black not shown: no library; EVE moves in 2 passes'),logs[#logs])
pass(2)
assert(#puts==1,'The move is made whatever the black did')

-- The watch. She lands a pass late: said when she walks.
again()
lands=3
street(A)
pass(5)
pass(4)
assert(not logged('stands') and door.busy(),'Not standing yet')
eve.mode=1
pass()
assert(logged('threshold: '..A.name..' in: EVE stands on the room floor after 5 passes'),logs[#logs])
-- She falls through the floor: 40 cm over it is no fall yet, 39 cm is. She is put back where she pushed, under a black
-- that is up at once. One line. That door does nothing more for the stay. Another door goes on.
again()
lands=3
street(A,-70,20)
pushed=eve
pass(5)
eve.Z=A.inside.Z+T.LOW
pass()
assert(#puts==1,'40 cm over the room floor is no fall yet')
eve.Z=A.inside.Z+T.LOW-1
local fell=eve
local lines=#logs
lands=1
pass()
assert(#puts==2 and puts[2].at.X==pushed.X and puts[2].at.Y==pushed.Y and near(puts[2].at.Z,pushed.Z+10)
    and puts[2].yaw==pushed.yaw,'Back where she pushed, 10 cm up, turned as she was')
assert(#blacks==2 and blacks[2].fade==0 and blacks[2].hold==1 and order[#order-1]=='black','A black that is up at once')
assert(#logs==lines+1 and logs[#logs]==string.format('threshold: %s in: EVE fell under the room floor to (%.0f, %.0f, '
    ..'%.0f) after 2 passes: back at (%.0f, %.0f, %.0f) where she pushed; this door does nothing more until the next '
    ..'arrival',A.name,fell.X,fell.Y,fell.Z,pushed.X,pushed.Y,pushed.Z),logs[#logs])
assert(not door.busy())
street(A)
assert(not pushes(10),'Its way in does nothing more for this stay')
street(B)
assert(pushes(),'Another door goes on')
door.arrive()
street(A)
assert(pushes(),'The next arrival turns the door on again')
-- She does not stand: after 32 passes she is put back.
again()
lands=3
street(A)
pushed=eve
pass(5)
pass(31)
assert(#puts==1 and door.busy(),'31 passes: still watched')
lands=1
pass()
assert(#puts==2 and puts[2].at.X==pushed.X and logged('threshold: '..A.name..' in: EVE does not stand on the room '
    ..'floor after 32 passes'),logs[#logs])
assert(logs[#logs]:find('where she pushed; this door does nothing more until the next arrival',1,true),logs[#logs])
-- Walking more than 160 cm over the room floor is no standing on it: after 32 passes she is put back.
again()
street(A)
pushed=eve
pass(5)
eve.Z=A.inside.Z+T.HIGH+1
pass(31)
assert(#puts==1 and not logged('stands'),'Walking over the band is not standing on the room floor')
pass()
assert(#puts==2 and puts[2].at.X==pushed.X and logged('does not stand on the room floor after 32 passes'),
    logs[#logs])
-- Walking on a floor far under the room is no standing in the room: she is put back.
again()
street(A)
pushed=eve
pass(5)
eve.Z=eve.Z-300
pass()
assert(#puts==2 and puts[2].at.X==pushed.X and not logged('stands') and logged('fell under the room floor'),
    logs[#logs])
-- The way out is watched the same way: back inside, where she pushed.
again()
lands=3
inner(A)
pushed=eve
pass(5)
eve.Z=eve.Z-200
pass()
assert(#puts==2 and puts[2].at.X==pushed.X and puts[2].at.Y==pushed.Y
    and logged('threshold: '..A.name..' out: EVE fell under the street to'),logs[#logs])
-- A way out that fails stays open, so a room cannot hold her: the next push on the inner door asks a move again.
assert(logs[#logs]:find('where she pushed; the way out stays open',1,true),logs[#logs])
lands=1
inner(A)
assert(pushes(),'The way out answers again after a failed move')
-- A door whose way in died keeps its way out.
again()
lands=3
street(A)
pass(5)
eve.Z=eve.Z-300
pass()
assert(logged('in: EVE fell under the room floor') and logged('this door does nothing more until the next arrival'))
lands=1
street(A)
assert(not pushes(10),'The way in is dead')
inner(A)
assert(pushes(),'The way out of a door whose way in died')
-- A move back that the engine refuses is said in the same line.
again()
lands=3
street(A)
pass(5)
eve.Z=eve.Z-200
refuse=true
lines=#logs
pass()
assert(#logs==lines+1 and logs[#logs]:find('the move back to (',1,true)
    and logs[#logs]:find('was refused by K2_TeleportTo; this door does nothing more until the next arrival',1,true),
    logs[#logs])
-- A refused move: one line, no watch, the door does nothing more for the stay.
again()
refuse=true
street(A)
pushed=eve
pass(5)
assert(#puts==1 and not door.busy() and logs[#logs]==string.format('threshold: %s in: the move to (%.0f, %.0f, %.0f) '
    ..'was refused by K2_TeleportTo; this door does nothing more until the next arrival',A.name,A.inside.X,A.inside.Y,
    A.inside.Z),logs[#logs])
refuse=false
eve=pushed
assert(not pushes(10),'No second try in this stay')

-- Locked and opened. The first push opens the door: one line, its name in the door file.
file,saves=nil,0
door=new()
fresh()
assert(door.opened(A.name)==false and door.may(A.name)==true,'A door starts locked and may be opened')
street(A)
pass(3)
assert(logs[#logs-1]=='threshold: '..A.name..' opened for good (kept in the door file)' and saves==1 and file==A.name,
    tostring(logs[#logs-1])..' / '..tostring(file))
assert(door.opened(A.name)==true and door.opened(B.name)==false)
assert(door.status()=='threshold doors '..#LIST..' in the pak, 1 opened',door.status())
pass(3)
-- A later push of an opened door: no line, no write.
inner(A)
pass(6)
street(A)
pass(6)
assert(#puts==3 and times('opened for good')==1 and saves==1,'Opened once')
-- A second door joins the file. Names the list does not know stay in it.
file=A.name..' D999'
fresh()
assert(logged('; opened: '..A.name),logs[1])
street(B)
pass(3)
local kept={}
for name in file:gmatch('%S+') do kept[name]=true end
assert(saves==2 and kept[A.name] and kept[B.name] and kept.D999 and select(2,file:gsub('%S+',''))==3,file)
-- A new Lua load, or a game run after an install: the file says which doors are opened.
door=new()
fresh()
assert(door.opened(A.name) and door.opened(B.name) and saves==2,'Read from the door file')
street(A)
pass(5)
assert(#puts==1 and times('opened for good')==0 and saves==2,'An opened door moves her with no line and no write')
-- A file that cannot be written: said in the line. The door opens all the same.
file,saves,save_fails=nil,0,'cannot write coop-xion-doors.txt.tmp'
door=new()
fresh()
street(A)
pass(5)
assert(logged('threshold: '..A.name..' opened for good (the door file was not written: cannot write '
    ..'coop-xion-doors.txt.tmp)') and #puts==1 and door.opened(A.name),logs[#logs])
save_fails=nil
-- A file that cannot be read: one line an arrival, no door is opened from it and the part goes on.
load_error='disk gone'
door=new()
fresh()
assert(logs[1]=='threshold: the door file did not read (disk gone): no door is opened from it'
    and logged('; opened: none'),logs[1])
street(A)
assert(pushes(),'It stops nothing')
load_error=nil

-- A requirement. Not met: the door does nothing, one line a stay. may() says why.
file,saves=nil,0
A.requires='badge'
door=new()
fresh()
local ok,why=door.may(A.name)
assert(ok==false and why=='its requirement badge is not met',tostring(why))
assert(door.may(B.name)==true and door.may('D000')==false)
street(A)
assert(not pushes(12) and saves==0 and not door.opened(A.name),'A door whose requirement is not met does nothing')
assert(times('threshold: '..A.name..' stays locked: its requirement badge is not met')==1,'Said once a stay')
door.arrive()
pass(6)
assert(times('stays locked')==2,'Once more after the next arrival')
-- The way out never asks: a room cannot hold her. It opens nothing.
inner(A)
assert(pushes() and times('stays locked')==2 and saves==0 and not door.opened(A.name),
    'The way out of a locked door')
pass(3)
street(B)
assert(pushes(),'A door with no requirement goes on')
-- Met: it opens.
local needs={}
met=function(need) needs[#needs+1]=need; return true end
fresh()
assert(door.may(A.name)==true and needs[1]=='badge','The row\'s requirement is what is asked')
street(A)
assert(pushes() and door.opened(A.name) and logged('threshold: '..A.name..' opened for good'),logs[#logs])
-- Opened for good: it is asked no more. The way out asks nothing either.
met=nil
pass(3)
inner(A)
assert(pushes(),'The way out asks no requirement')
pass(3)
street(A)
assert(pushes() and not logged('stays locked'),'An opened door stays open')
-- A part built with no requirement check: a row with one stays locked.
file=nil
door=Threshold.new({log=function(m) logs[#logs+1]=m end,world=world,gate=gate,store=store})
fresh()
street(A)
assert(not pushes(6) and door.may(A.name)==false and logged('stays locked'),'No check: not met')
A.requires=nil
door=new()

-- The pak cases. No room in the pak: one calm line, no push, the status says none.
has={}
fresh()
assert(#logs==1 and logs[1]=='threshold: none of the '..#LIST..' rooms is in this pak' and #asked==#LIST,logs[1])
assert(door.status()=='threshold doors none in the pak',door.status())
street(A)
assert(not pushes(10) and #logs==1,'Nothing happens with an older pak')
-- The pak that holds one of them: that door works, the others do nothing.
has={[B.name]=true}
fresh()
assert(logs[1]=='threshold: this pak holds 1 of '..#LIST..' rooms: '..B.name..'; opened: none',logs[1])
assert(door.status()=='threshold doors 1 in the pak, 0 opened',door.status())
street(A)
assert(not pushes(10),'A room the pak lacks is never pushed')
street(B)
assert(pushes(),'The room the pak holds is')
-- A gate that raises for one room leaves that room out.
has,gate_error=nil,A.name
fresh()
assert(logs[1]:find('this pak holds '..(#LIST-1)..' of '..#LIST..' rooms: '..B.name,1,true),logs[1])
gate_error=nil

-- The level. An arrival reads no level. A whole push reads the list once, the two passes before it read nothing.
file,saves=nil,0
door=new()
fresh()
assert(level_reads==0,'An arrival reads no level')
street(A)
pass(2)
assert(level_reads==0,'Two passes are no push: no read')
assert(pushes(1) and level_reads==1,'One read of the list a push')
-- A level that is loaded and not visible: the door stays shut. No black, no move, nothing opened, one line a stay.
file,saves=nil,0
door=new()
fresh()
down[A.name]={loaded=true,visible=false}
street(A)
assert(not pushes(12) and #puts==0 and saves==0 and not door.opened(A.name) and not door.busy(),
    'A room whose level is not visible keeps its door shut')
assert(times('threshold: '..A.name..' stays shut: its level '..A.level..' reads loaded true visible false')==1
    and #logs==2,logs[#logs])
-- The other doors go on.
street(B)
assert(pushes() and door.opened(B.name),'A door whose level is there')
pass(3)
-- Once the level is there the door works, in the same stay.
down[A.name]=nil
street(A)
assert(pushes() and door.opened(A.name),'The level came: the door works')
-- The next arrival says it again. Not loaded reads the same way.
fresh()
down[A.name]={loaded=false,visible=true}
street(A)
assert(not pushes(6) and logged('threshold: '..A.name..' stays shut: its level '..A.level
    ..' reads loaded false visible true'),logs[#logs])
-- A level off the streaming list.
fresh()
down[A.name]=false
street(A)
assert(not pushes(6) and #puts==0 and logged('threshold: '..A.name..' stays shut: its level '..A.level
    ..' is not on the streaming list'),logs[#logs])
-- A read that raises: shut and said once. The part stays on.
fresh()
levels_error='no world'
street(A)
assert(not pushes(6) and #puts==0 and times('threshold: '..A.name
    ..' stays shut: the levels did not read (no world)')==1 and not logged('off until the next arrival'),logs[#logs])
levels_error=nil
assert(pushes(),'The read is back: the door works with no new arrival')
-- The way out never asks: no read of the list, whatever it says.
fresh()
down[A.name]=false
inner(A)
assert(pushes() and level_reads==0,'The way out reads no level')
file,saves=nil,0
door=new()

-- Busy (the recovery waits or handles a fall or a death, the Tetrapod's door moves her): nothing is counted.
fresh()
street(A)
pass(6,true)
assert(#blacks==0,'Busy passes count nothing')
assert(not pushes(2),'The count started again')
assert(pushes(1))
-- A move already asked is still made on a busy pass. It is watched on one too.
pass(2,true)
assert(#puts==1,'The move is made on a busy pass')
pass(1,true)
assert(logged('stands on the room floor'),logs[#logs])
-- coop xion rooms off: the doors off until on or the next arrival.
again()
door.switch(false)
assert(door.status()=='threshold doors off',door.status())
street(A)
assert(not pushes(10),'Off')
door.switch(true)
assert(pushes(),'On again')
again()
door.switch(false)
door.arrive()
street(A)
assert(pushes(),'An arrival turns them on')
-- An arrival drops a move that waits.
again()
street(A)
pass(3)
door.arrive()
street(A,-300)
pass(5)
assert(#puts==0,'The arrival dropped the move')
-- An error in a pass: off with one line until the next arrival.
again()
street(A)
broken='lost pawn'
pass(4)
assert(times('threshold: off until the next arrival: error (lost pawn)')==1,logs[#logs])
broken=nil
assert(not pushes(10),'Off')
fresh()
street(A)
assert(pushes(),'The next arrival turns the doors on again')
-- The pass's read of EVE, handed over by the recovery: she is read no second time.
again()
street(A)
local read=world.move()
moves=0
for _=1,3 do door.tick(false,read) end
assert(moves==0 and #blacks==1,'One read of EVE a pass')
print('sboxion_rooms_threshold_test ok')
