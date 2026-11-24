-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's walls (world/maps/sboxion/walls/walls.lua) over a fake world that makes, removes and sweeps walls and a
-- fake store: an arrival queues the 178 boxes nearest to its point first and each pass makes 10, so the cave wall is
-- the first one up at the gate point; the first wall's read-back and the count are logged; the paths are saved at each
-- pass that made a wall. A wall that cannot be made is logged with its reason (three reasons at most) and named in
-- the count line while the others go up. Down: every wall asked of the world once, the ones still alive counted as
-- removed, the others as gone already, the boxes not made yet counted too, a removal that raises counted with its
-- reason, the store cleared, nothing made after it. coop xion walls: off takes them down and keeps them down, on puts
-- them up again nearest to EVE first, on again while they are up makes nothing, on after a build that made none tries
-- again, any other word gets the use line. An arrival sets off back to on and takes down what is still up. The
-- sweep: once a Lua load, an earlier load's paths asked of the world until the first one that is no wall, then the
-- store cleared.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=50
os.clock=function() return clock end
package.loaded.UEHelpers={}
local Walls=require('world.maps.sboxion.walls.walls')
local D=require('world.maps.sboxion.data')
local N=#Walls.BOXES
assert(N==178 and Walls.PER_PASS==10)
assert(Walls.BOXES[1].name=='W01.1' and Walls.BOXES[5].name=='W01.5' and Walls.BOXES[6].name=='W02.1')
local cave=Walls.BOXES[N]
assert(cave.name=='CAVE.1' and cave.at.X==-24949.7 and cave.yaw==-55 and cave.size.X==8800 and cave.size.Y==30
    and cave.size.Z==5468.3,'A box holds the row\'s place, yaw and size')

local logs,made,asked,removed,alive,bad,eve={},{},{},0,true,{},nil
local remove_error=nil
local world={
    wall=function(b)
        asked[#asked+1]=b.name
        if bad[b.name] or bad.all then error(bad[b.name] or bad.all) end -- error() puts the place before it.
        local d={path='/Game/SBO_World/Xion_P.Xion_P:PersistentLevel.Actor_'..#asked,
            read='object type 20, collision on'}
        made[#made+1]=d
        return d
    end,
    unwall=function(d)
        if remove_error then error(remove_error) end
        if not alive or d.gone then return false end
        d.gone=true
        removed=removed+1
        return true
    end,
    wall_swept=function(path) asked[#asked+1]='swept '..path; return path:find('Actor_',1,true)~=nil end,
    move=function() return eve end,
}
local saved,stored,clears=nil,nil,0
local store={save=function(line) saved=line; stored=line end,load=function() return stored end,
    clear=function() stored=nil; clears=clears+1 end}
local function fresh(with_store)
    logs,made,asked,removed,alive,bad,eve,remove_error={},{},{},0,true,{},nil,nil
    saved,stored,clears=nil,nil,0
    return Walls.new({log=function(m) logs[#logs+1]=m end,world=world,store=with_store~=false and store or nil})
end
local function said(text)
    for _,l in ipairs(logs) do if l:find(text,1,true) then return l end end
end
local function nearest(p)
    local best,far=nil,math.huge
    for _,b in ipairs(Walls.BOXES) do
        local d=(b.at.X-p.X)^2+(b.at.Y-p.Y)^2
        if d<far then best,far=b.name,d end
    end
    return best
end
local function build(w) for _=1,18 do w.tick() end end

-- gate_arrival: the cave wall first, 10 a pass, 18 passes, the count line, the paths saved.
local w=fresh()
w.tick()
assert(#asked==0 and #logs==0,'Nothing before an arrival')
w.arrive('gate')
assert(logs[1]=='walls: 178 to put up, 10 a pass, nearest to the gate point first',logs[1])
assert(w.status()=='walls 0 of 178 up, 178 to go')
w.tick()
assert(#asked==10 and asked[1]=='CAVE.1','The cave wall is the nearest to the gate point: '..asked[1])
assert(logs[2]=='walls: first wall CAVE.1 up: object type 20, collision on',logs[2])
assert(w.status()=='walls 10 of 178 up, 168 to go',w.status())
local _,tabs=saved:gsub('\t','')
assert(tabs==9 and saved:find('Actor_1\t',1,true) and saved:find('Actor_10$'),'Ten paths on one line: '..saved)
for _=1,16 do w.tick() end
assert(#asked==170 and not said('up in'))
clock=clock+0.004
w.tick()
assert(#asked==178 and logs[#logs]=='walls: 178 of 178 up in 18 passes, 0 ms',logs[#logs])
assert(#logs==3 and w.status()=='walls 178 of 178 up')
_,tabs=saved:gsub('\t','')
assert(tabs==177)
w.tick()
assert(#asked==178 and #logs==3,'Nothing more once they are up')
local once={}
for _,name in ipairs(asked) do assert(not once[name],name..' was made twice'); once[name]=true end

-- city_arrival: the nearest box to the city point first; a name that is no point is the city point.
w=fresh()
w.arrive('city')
w.tick()
assert(asked[1]==nearest(D.ARRIVALS.city) and asked[1]~='CAVE.1',asked[1])
w=fresh()
w.arrive('nowhere')
assert(logs[1]:find('nearest to the city point first',1,true),logs[1])

-- some_fail: each is logged, the others go up, the count line names them.
w=fresh()
bad['W08.2'],bad['W03.7']='the game has no name SB_InvisiblewallIgnoreCamera','a wall could not be spawned'
w.arrive('city')
build(w)
assert(#asked==178 and #made==176)
assert(said('walls: W08.2 not made: the game has no name SB_InvisiblewallIgnoreCamera'),'The reason, its place cut')
assert(said('walls: W03.7 not made: a wall could not be spawned'))
local line=logs[#logs]
assert(line:find('^walls: 176 of 178 up in 18 passes, 0 ms; not made: ') and line:find('W08.2',1,true)
    and line:find('W03.7',1,true),line)
assert(w.status()=='walls 176 of 178 up, 2 not made',w.status())
local ok,answer=w.switch('on')
assert(ok and answer=='walls 176 of 178 up, 2 not made' and #asked==178,'on while walls are up makes nothing')
-- all_fail: three reasons, then the count line with twelve names; on tries again.
w=fresh()
bad.all='SetCollisionProfileName: no such function'
w.arrive('city')
build(w)
local reasons=0
for _,l in ipairs(logs) do if l:find(' not made: SetCollisionProfileName',1,true) then reasons=reasons+1 end end
assert(reasons==3 and #made==0,'Three reasons at most: '..reasons)
line=logs[#logs]
assert(line:find('^walls: 0 of 178 up in 18 passes, 0 ms; not made: ') and line:find(' and 166 more$'),line)
assert(not said('first wall') and stored==nil,'No path is kept with no wall up')
bad.all=nil
ok,answer=w.switch('on')
assert(ok and answer=='walls on: 178 to put up ([SX] lines follow)',answer)
build(w)
assert(#made==178 and w.status()=='walls 178 of 178 up')

-- down_alive (coop off): each wall asked of the world once, the store cleared, nothing made after it.
w=fresh()
w.arrive('city')
build(w)
w.down('coop off')
assert(removed==178 and logs[#logs]=='walls: down (coop off): 178 removed',logs[#logs])
assert(stored==nil and clears>=1 and w.status()=='walls 0 of 178 up')
w.tick()
w.down('coop off')
assert(#asked==178 and removed==178 and logs[#logs]=='walls: down (coop off): 178 removed','Down once')
-- down_gone (a map change): the world took them, so none is removed.
w=fresh()
w.arrive('gate')
build(w)
alive=false
w.down('a map change')
assert(removed==0 and logs[#logs]=='walls: down (a map change): 0 removed, 178 gone already',logs[#logs])
-- down_mid_build: the boxes not made yet are counted.
w=fresh()
w.arrive('gate')
w.tick()
w.tick()
w.down('a map change')
assert(removed==20 and logs[#logs]=='walls: down (a map change): 20 removed, 158 never made',logs[#logs])
w.tick()
assert(#asked==20,'The build ends with the walls')
-- down_raises: a removal that raises is named and the rest is still asked.
w=fresh()
w.arrive('gate')
w.tick()
remove_error='K2_DestroyActor: no such function'
w.down('coop off')
assert(logs[#logs]=='walls: down (coop off): 0 removed, 10 raised (K2_DestroyActor: no such function), 168 never '
    ..'made',logs[#logs])

-- switch: off takes them down and keeps them down; on puts them up nearest to EVE; another word is refused.
w=fresh()
w.arrive('gate')
build(w)
ok,answer=w.switch()
assert(ok and answer=='walls 178 of 178 up')
ok,answer=w.switch('off')
assert(ok and answer=='walls off until coop xion walls on or the next arrival' and removed==178,answer)
assert(said('walls: down (coop xion walls off): 178 removed') and w.status()=='walls off')
w.tick()
assert(#asked==178,'Off makes nothing')
ok,answer=w.switch('off')
assert(ok and removed==178,'Off twice removes once')
eve={at={X=3900,Y=-9100,Z=1222}} -- At lift doorway A.
ok,answer=w.switch('on')
assert(ok and answer=='walls on: 178 to put up ([SX] lines follow)')
assert(logs[#logs]=='walls: 178 to put up, 10 a pass, nearest to EVE first',logs[#logs])
w.tick()
assert(asked[179]:find('^W08%.'),'The doorway\'s boxes first: '..asked[179])
ok,answer=w.switch('on')
assert(ok and answer=='walls 10 of 178 up, 168 to go' and #asked==188,'on during a build starts no second one')
ok,answer=w.switch('up')
assert(not ok and answer=='Use: coop xion walls [on|off]',answer)
-- switch_no_eve: on with EVE unread queues from the stay's arrival point.
w=fresh()
w.arrive('gate')
w.switch('off')
world.move=function() error('no EVE in the world') end
ok,answer=w.switch('on')
assert(ok and logs[#logs]=='walls: 178 to put up, 10 a pass, nearest to the gate point first',logs[#logs])
world.move=function() return eve end
-- arrival_after_off: on again. An arrival with walls still up takes them down first.
w=fresh()
w.arrive('city')
w.switch('off')
w.arrive('city')
assert(w.status()=='walls 0 of 178 up, 178 to go','An arrival sets off back to on')
build(w)
w.arrive('gate')
assert(removed==178 and said('walls: down (an arrival): 178 removed'),'No wall is left behind an arrival')
assert(w.status()=='walls 0 of 178 up, 178 to go')

-- sweep: an earlier Lua load's walls, at the first pass of this load only.
w=fresh()
stored='/Game/A.A:PersistentLevel.Actor_7\t/Game/A.A:PersistentLevel.Actor_8\t/Game/A.A:PersistentLevel.Actor_9'
w.tick()
assert(#asked==3 and asked[1]=='swept /Game/A.A:PersistentLevel.Actor_7' and stored==nil)
assert(logs[1]=='walls: an earlier Lua load left 3: 3 swept',logs[1])
stored='/Game/A.A:PersistentLevel.Actor_7'
w.tick()
assert(#asked==3,'Once a Lua load')
-- sweep_stale: the first path that is no wall ends it, so a file of a closed game costs one look.
w=fresh()
stored='/Game/A.A:PersistentLevel.Lamp_1\t/Game/A.A:PersistentLevel.Actor_8\t/Game/A.A:PersistentLevel.Actor_9'
w.arrive('gate')
w.tick()
assert(asked[1]=='swept /Game/A.A:PersistentLevel.Lamp_1' and asked[2]=='CAVE.1','One look, then the build')
assert(said('walls: an earlier Lua load left 3: 0 swept'))
-- no_store: the walls work with no store.
w=fresh(false)
w.arrive('gate')
build(w)
w.down('coop off')
assert(#made==178 and removed==178)
print('sboxion_walls_test ok')
