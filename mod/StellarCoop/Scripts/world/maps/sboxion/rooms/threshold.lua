-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's threshold doors (world/maps/sboxion/sboxion.lua starts this part at each arrival and ticks it each 250 ms
-- pass while EVE's map is SBO Xion, after the Tetrapod's door).
-- A threshold room of rooms/list.lua stands behind a door of SB that stays shut. Nothing of SB is hidden for it. This
-- part is its way in and its way out, made as the Tetrapod's door makes its moves (tetrapod.lua): SB's black first
-- (world.black), then world.put (K2_TeleportTo, then StopMovementImmediately) LEAD passes later, whatever the black's
-- call did. It makes no call into the game of its own.
-- The push: EVE walking within REACH cm in front of a door's plane, inside the door's width, LOW to HIGH cm over the
-- door's floor and turned toward the door within TURN degrees, for PUSH passes in a row. The way in is a push on the
-- street door from the street. The way out is a push on the inner door from inside the room. A room with a passage
-- (D039, whose own doorway is open behind SB's shutter) counts the passage too. Running along the facade, a jump and
-- her back to the door are no push.
-- A push that fails: none of this has run in game, so a door that does not answer must say why. EVE before a door
-- within twice REACH, inside its width, either within REACH or turned toward it, for IDLE passes in a row with no
-- push: one log line a door and way a stay gives her place and the three numbers a push needs. Where a move leaves
-- her she is neither close nor turned toward the door, so standing there says nothing.
-- The move: to the room's point inside, turned into the room, or to its point outside, turned away from the door.
-- Her height is not a number of this part: she is put as high over the new floor as she stood over the old one at
-- the push, plus LIFT. So a ramp or rubble before a door does not put her into the floor.
-- The watch: after a move she must read walking LOW to HIGH cm over the floor she was put on. Some rooms stand on a
-- floor of their own that has not run in game. Under LOW over that floor, or not standing after SETTLE passes, she
-- is put back where she pushed, under a black that is up at once. One log line says so and that door's way in does
-- nothing more until the next arrival. A move the engine refuses ends the same way. The way out never dies: after a
-- way out that fails she is back inside and the next push on the inner door tries again, so a room cannot hold her.
-- Locked and opened: a door starts locked. The first push opens it for good: one log line and its name in the door
-- file (the store, coop-xion-doors.txt in the mod folder, which tools/install.py keeps like every coop-*.txt). Each
-- arrival reads the file. A row may carry a requirement: may(name) asks o.met for it and a locked door whose
-- requirement is not met does nothing, said once a stay. An opened door asks no more. The way out never asks, so a
-- room cannot hold her. No row has a requirement today.
-- The pak: o.gate is asked for each room's level on its own at each arrival, so a pak works the doors of the rooms
-- it holds. An older pak holds D039's room alone, or none: one line an arrival and nothing else.
-- The level: the pak holding a room's level does not say the game loaded it. A way in reads the streaming list
-- (world.levels) once a whole push and needs the room's level loaded and visible. Else the door stays shut: no
-- black, no move, nothing opened, one line a door a stay. A read that raises counts as not there. Without this
-- EVE would be put behind the facade of a room that is not there. Where SB's floor runs on under the room the
-- watch would say she stands on the room floor. The way out never asks.
-- busy: the recovery waits (photo mode, a cutscene, a warp, another zone) or handles a fall or a death
-- (recover.lua's busy), or the Tetrapod's door moves her. Such a pass counts nothing and asks no move. A move already
-- asked is still made and watched. An error in a pass turns the part off with one log line until the next arrival.
-- coop off needs no call here: sboxion.lua ticks nothing after it.
-- tests/lua/world/maps/sboxion/rooms/threshold_test.lua covers it.
local U=require('core.unreal')
local D=require('world.maps.sboxion.data')
local T=D.THRESHOLD
local Threshold={}
local GROUND={[1]=true,[2]=true} -- EMovementMode: Walking, NavWalking.
local function place(at) return string.format('(%.0f, %.0f, %.0f)',at.X,at.Y,at.Z) end
local function turn(a,b) return math.abs((a-b+180)%360-180) end -- Degrees between two yaws, 0 to 180.
local function facing(yaw) return (yaw+180)%360-180 end -- A yaw as the engine gives one, -180 to 180.
-- The threshold rooms: {name=, level=, umap=<its level's game path, for the pak gate>, requires=, yaw=<the way in>,
-- cos=, sin=, street=, inner=, outside=, inside=}, the last four as rooms/list.lua holds them.
Threshold.LIST={}
local ROOM={} -- A room by its name.
for _,r in ipairs(require('world.maps.sboxion.rooms.list')) do
    local t=r.threshold
    if t then
        local a=math.rad(t.street.Yaw)
        local room={name=r.name,level=r.level,umap='/Game/SBO_World/Rooms/'..r.level,requires=r.requires,
            yaw=t.street.Yaw,cos=math.cos(a),sin=math.sin(a),street=t.street,inner=t.inner,outside=t.outside,
            inside=t.inside}
        Threshold.LIST[#Threshold.LIST+1],ROOM[r.name]=room,room
    end
end
local LIST=Threshold.LIST
-- A place against a door's centre p: cm behind its plane along the way in (negative: in front), cm across and cm
-- over its floor.
local function against(room,p,at)
    local dx,dy=at.X-p.X,at.Y-p.Y
    return dx*room.cos+dy*room.sin,-dx*room.sin+dy*room.cos,at.Z-p.Z
end
-- How EVE stands before a door of room, 'in' at its street door or 'out' at its inner door: cm on her side of the
-- door's plane, degrees she is turned from the door and cm over the door's floor. nil when she is not before it
-- within twice REACH (the inner door's passage counts) and inside its width.
local function before(room,way,m)
    local p=way=='in' and room.street or room.inner
    local d,u,h=against(room,p,m.at)
    local front=way=='in' and -d or d
    if front<-(p.passage or 0) or front>2*T.REACH or math.abs(u)>p.half then return nil end
    return front,turn(m.yaw,room.yaw+(way=='in' and 0 or 180)),h
end
-- The door EVE pushes on this pass, of the rooms given less the ways in of skip (by name): the room, 'in' or 'out'
-- and how high over that door's floor she reads. With no push, nil three times and then the door she fails to push, if
-- any: {room=, way=, front=, off=, h=}, close to it or turned toward it, no more than 100 cm off its height band.
local WAYS={'in','out'}
local function pushed(rooms,skip,m)
    local near=nil
    for _,room in ipairs(rooms) do
        for _,way in ipairs(WAYS) do
            local front,off,h=before(room,way,m)
            if front and not (way=='in' and skip[room.name]) then
                local far,turned=front>T.REACH,off>T.TURN
                if not far and not turned and h>=T.LOW and h<=T.HIGH then return room,way,h end
                if not (far and turned) and h>=T.LOW-100 and h<=T.HIGH+100 then
                    near=near or {room=room,way=way,front=front,off=off,h=h}
                end
            end
        end
    end
    return nil,nil,nil,near
end

-- o: log(m), world, the engine calls (world/maps/sboxion/engine.lua's move, put, black and levels; a fake in the
-- tests),
-- gate(umap) (true when the pak holds the room level of that game path, else nil and why), store (core/link.lua's
-- store for the door file: save(line), load(); optional) and met(requirement) (true once a row's requirement is
-- met; optional: without it no requirement is).
function Threshold.new(o)
    local log,world=o.log,o.world
    local store=o.store or {save=function() return true end,load=function() end}
    local on,off=true,nil -- coop xion rooms on or off. off: the error that turned the part off until the next arrival.
    local held={} -- The rooms the pak holds, in the list's order.
    local opened={} -- By name: the doors opened for good, from the door file and from this Lua load.
    local dead,said={},{} -- Of the stay, by name: a door whose way in does nothing more; its requirement was said.
    local shut={} -- Of the stay, by name: its level was said not to be there.
    local told,idling={},nil -- Of the stay: a push that fails, said by room and way; the one counted: {key=, n=}.
    local push=nil -- The push being counted: {room=, way=, n=}.
    local lead=nil -- A move that waits under SB's black: {left=<passes>, room=, way=, from={at=, yaw=}, h=}.
    local watch=nil -- A move being watched: {passes=, room=, way=, from=, floor=<the Z of the floor she was put on>}.
    local self={}
    -- May this door be opened: true, or false and why. A door with no requirement may.
    function self.may(name)
        local room=ROOM[name]
        if not room then return false,'no threshold door '..tostring(name) end
        if room.requires==nil then return true end
        local ok,yes=pcall(o.met or function() return false end,room.requires)
        if ok and yes then return true end
        return false,'its requirement '..tostring(room.requires)..' is not met'
    end
    -- Is this door opened for good.
    function self.opened(name) return opened[name]==true end
    -- SB's black, asked once and never waited for. fade: the s it fades in over, 0 for a black that is up at once.
    local function black(fade)
        local ok,up=pcall(world.black,D.BLACK,fade,D.BLACK_OUT)
        return not ok and 'not shown: '..U.why(up) or up==false and 'not shown: SB made no loading screen'
            or up==nil and 'asked, its handle did not read' or fade>0 and string.format('up in %.1f s',fade)
            or 'up at once'
    end
    -- The first push of a locked door: opened for good, its name in the door file with every name the file held.
    local function open(room)
        opened[room.name]=true
        local names={}
        for name in pairs(opened) do names[#names+1]=name end
        table.sort(names)
        local ok,done,why=pcall(store.save,table.concat(names,' '))
        log('threshold: '..room.name..' opened for good ('..(ok and done~=false and 'kept in the door file'
            or 'the door file was not written: '..(ok and tostring(why) or U.why(done)))..')')
    end
    -- Is the room's level loaded and visible: true, or false and why.
    local function level_up(room)
        local ok,list=pcall(world.levels)
        if not ok then return false,'the levels did not read ('..U.why(list)..')' end
        for _,l in ipairs(list) do
            if l.name==room.level then
                if l.loaded and l.visible then return true end
                return false,string.format('its level %s reads loaded %s visible %s',room.level,tostring(l.loaded),
                    tostring(l.visible))
            end
        end
        return false,'its level '..room.level..' is not on the streaming list'
    end
    local function floor_of(way) return way=='in' and 'the room floor' or 'the street' end
    local function ended(room,way)
        if way=='out' then return '; the way out stays open' end
        dead[room.name]=true
        return '; this door does nothing more until the next arrival'
    end
    -- A push is whole: the move is asked, unless the room's level is not there or the door is locked and may not be
    -- opened.
    local function start(room,way,m,h)
        if way=='in' then
            local up,why=level_up(room)
            if not up then
                if not shut[room.name] then
                    shut[room.name]=true
                    log('threshold: '..room.name..' stays shut: '..why)
                end
                return
            end
        end
        if way=='in' and not opened[room.name] then
            local may,why=self.may(room.name)
            if not may then
                if not said[room.name] then
                    said[room.name]=true
                    log('threshold: '..room.name..' stays locked: '..why)
                end
                return
            end
            open(room)
        end
        log(string.format('threshold: %s %s asked (EVE pushed %d passes at %s); black %s; EVE moves in %d passes',
            room.name,way,T.PUSH,place(m.at),black(D.BLACK_IN),D.LEAD))
        lead={left=D.LEAD,room=room,way=way,from={at=m.at,yaw=m.yaw},h=h}
    end
    -- The move of a push, LEAD passes after its black.
    local function put(l)
        local to=l.way=='in' and l.room.inside or l.room.outside
        local yaw=facing(l.room.yaw+(l.way=='in' and 0 or 180))
        if world.put({X=to.X,Y=to.Y,Z=to.Z+l.h+D.LIFT},yaw)==false then
            log(string.format('threshold: %s %s: the move to %s was refused by K2_TeleportTo%s',l.room.name,l.way,
                place(to),ended(l.room,l.way)))
            return
        end
        log(string.format('threshold: %s %s: EVE at %s, yaw %.1f',l.room.name,l.way,place(to),yaw))
        watch={passes=0,room=l.room,way=l.way,from=l.from,floor=to.Z}
    end
    -- A pass of the watch after a move.
    local function watching(m)
        local w=watch
        w.passes=w.passes+1
        local h=m.at.Z-w.floor
        local low=h<T.LOW
        if GROUND[m.mode] and not low and h<=T.HIGH then
            watch=nil
            log(string.format('threshold: %s %s: EVE stands on %s after %d passes',w.room.name,w.way,
                floor_of(w.way),w.passes))
            return
        end
        if not low and w.passes<T.SETTLE then return end
        watch=nil
        black(0)
        local back=world.put({X=w.from.at.X,Y=w.from.at.Y,Z=w.from.at.Z+D.LIFT},w.from.yaw)~=false
        log(string.format('threshold: %s %s: EVE %s: %s%s',w.room.name,w.way,
            low and string.format('fell under %s to %s after %d passes',floor_of(w.way),place(m.at),w.passes)
                or string.format('does not stand on %s after %d passes, at %s in mode %s',floor_of(w.way),w.passes,
                    place(m.at),tostring(m.mode)),
            back and 'back at '..place(w.from.at)..' where she pushed'
                or 'the move back to '..place(w.from.at)..' was refused by K2_TeleportTo',ended(w.room,w.way)))
    end
    -- A pass with no push. near: the door she fails to push (pushed()'s fourth value), said once after IDLE passes.
    local function idle(near,m)
        local key=near and near.room.name..' '..near.way
        if not key or told[key] then
            idling=nil
            return
        end
        if not idling or idling.key~=key then idling={key=key,n=0} end
        idling.n=idling.n+1
        if idling.n<T.IDLE then return end
        told[key],idling=true,nil
        log(string.format('threshold: %s: no push in %d passes with EVE at %s: %.0f cm before the door\'s plane (%d at '
            ..'most), turned %.0f degrees from the door (%d at most), %.0f cm over its floor (%d to %d)',key,T.IDLE,
            place(m.at),near.front,T.REACH,near.off,T.TURN,near.h,T.LOW,T.HIGH))
    end
    local function tick(busy,read)
        local m=read or world.move()
        if not m then
            push,idling=nil,nil
            return
        end
        if lead then
            lead.left=lead.left-1
            if lead.left<=0 then
                local l=lead
                lead=nil
                put(l)
            end
            return
        end
        if watch then return watching(m) end
        if busy or not on or not GROUND[m.mode] then
            push,idling=nil,nil
            return
        end
        local room,way,h,near=pushed(held,dead,m)
        if not room then
            push=nil
            return idle(near,m)
        end
        idling=nil
        if not push or push.room~=room or push.way~=way then push={room=room,way=way,n=0} end
        push.n=push.n+1
        if push.n<T.PUSH then return end
        push=nil
        start(room,way,m,h)
    end
    -- Each 250 ms pass while EVE's map is SBO Xion. busy: see the header. read: EVE as the recovery read her in this
    -- pass (world.move's table), so a pass reads her once; without it the part reads her itself.
    function self.tick(busy,read)
        if off then return end
        local ok,e=pcall(tick,busy,read)
        if ok then return end
        off,push,lead,watch=U.why(e),nil,nil,nil
        log('threshold: off until the next arrival: error ('..off..')')
    end
    -- A move waits under the black or is watched: the Tetrapod's door counts nothing on such a pass.
    function self.busy() return lead~=nil or watch~=nil end
    -- Each arrival in SBO Xion: on, nothing kept of the stay before but the opened doors. The door file is read and
    -- the pak asked for each room. The part is ticked in SBO Xion only, so a move that waited at a map change is
    -- dropped here.
    function self.arrive()
        on,off,dead,said,shut,told,idling,push,lead,watch,held=true,nil,{},{},{},{},nil,nil,nil,nil,{}
        local ok,line=pcall(store.load)
        if ok then
            for name in (line or ''):gmatch('%S+') do opened[name]=true end
        else log('threshold: the door file did not read ('..U.why(line)..'): no door is opened from it') end
        local names,open_ones={},{}
        for _,room in ipairs(LIST) do
            local asked,has=pcall(o.gate,room.umap)
            if asked and has then
                held[#held+1],names[#names+1]=room,room.name
                if opened[room.name] then open_ones[#open_ones+1]=room.name end
            end
        end
        if #held==0 then return log('threshold: none of the '..#LIST..' rooms is in this pak') end
        log(string.format('threshold: this pak holds %d of %d rooms: %s; opened: %s',#held,#LIST,
            table.concat(names,', '),open_ones[1] and table.concat(open_ones,', ') or 'none'))
    end
    -- coop xion rooms off and on: the doors off until on or the next arrival. A move that waits is dropped. One
    -- already made is still watched.
    function self.switch(to)
        on=to
        if not to then push,lead=nil,nil end
    end
    -- One part of coop xion status: the doors the pak holds and how many of those are opened.
    function self.status()
        if not on then return 'threshold doors off' end
        if #held==0 then return 'threshold doors none in the pak' end
        local n=0
        for _,room in ipairs(held) do if opened[room.name] then n=n+1 end end
        return string.format('threshold doors %d in the pak, %d opened',#held,n)
    end
    return self
end
return Threshold
