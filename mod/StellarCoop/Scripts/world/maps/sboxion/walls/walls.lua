-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's walls (world/maps/sboxion/sboxion.lua puts them up at each arrival and ticks this part each 250 ms pass
-- while EVE's map is SBO Xion).
-- SBO Xion loads none of SB's level-design sublevels, so the doors, the lift pieces and the ways down SB closes its
-- city with are missing: one step leads out of the city at 22 places, lift doorway A among them. The cave at the
-- gate point runs on with no ground behind it. walls/list.lua holds a box for each stretch of open edge. This part
-- makes one invisible wall a box (world.wall: an engine cube with SB's collision profile for its own block walls,
-- world/maps/sboxion/engine.lua) and takes them down again. Nothing is made in any other map and SB's Xion is never
-- touched: the walls are actors of SBO Xion's own world.
-- Up: an arrival queues every box, nearest to EVE's own place first, so at the gate point the cave wall, 17.5 m from
-- it, is up in the first pass. Her place is read at the arrival: a Lua reload forgets the point coop xion asked. Each
-- pass makes PER_PASS. A wall that cannot be made is logged, at most SAID reasons a build. The others go up. The
-- count line names the ones not made. The recovery (recover.lua) stays the net under every edge that is still open.
-- Down: at a map change (coop xion leave is one), at coop off and at coop xion walls off, each wall is asked of the
-- world once. world.unwall destroys an actor only while it is still the one made, so after a map change, which
-- destroyed the world with its walls, nothing is called. A map read that failed for one pass ends the stay too: the
-- walls of a world that still stands are then destroyed, so the arrival that follows makes no second set.
-- coop xion walls [on|off]: off takes them down until on or the next arrival, for a test of an open edge. on puts
-- them up again, nearest to EVE first.
-- A Lua reload (Ctrl+R) forgets the walls it made. Their paths are kept in the store, one line, at each pass that
-- made one. The first pass of a Lua load asks the world to sweep them (world.wall_swept) until the first path that is
-- no wall, so the paths of a game run that ended inside SBO Xion cost one look. A store that raises stops nothing: a
-- save that fails is logged once a build and the walls go up, a load that fails is logged and nothing is swept.
-- An error in a pass is logged once and ends the build. The walls made stay up. The status part then ends with
-- "build ended".
-- tests/lua/world/maps/sboxion/walls/walls_test.lua covers it.
local U=require('core.unreal')
local Walls={}
-- shortcut: 10 a pass whatever a spawn costs, never timed in game; lower it if the count line's ms show a hitch.
Walls.PER_PASS=10
local SAID,NAMED=3,12 -- Reasons logged a build; names in the count line.
-- The boxes, each named by its hole and its number there: {name=, i=, at=, yaw=, size=}.
Walls.BOXES={}
do
    local n={}
    for i,r in ipairs(require('world.maps.sboxion.walls.list')) do
        n[r[1]]=(n[r[1]] or 0)+1
        Walls.BOXES[i]={name=r[1]..'.'..n[r[1]],i=i,at={X=r[2],Y=r[3],Z=r[4]},yaw=r[5],size={X=r[6],Y=r[7],Z=r[8]}}
    end
end
local BOXES=Walls.BOXES

-- o: log(m), world, the engine calls (world/maps/sboxion/engine.lua's wall, unwall, wall_swept and move; a fake in the
-- tests) and store (core/link.lua's store: save(line), load(), clear(); optional).
function Walls.new(o)
    local log,world=o.log,o.world
    local store=o.store or {save=function() end,load=function() end,clear=function() end}
    local on,swept,arrived=true,false,nil -- arrived: EVE's place ({X,Y}) at the last arrival.
    local up,queue,failed={},nil,{} -- The walls made, the boxes still to make (nil: no build) and the names not made.
    local passes,ms=0,0 -- Of the build.
    local ended,unkept=false,false -- Of the build: a pass raised and ended it; the store refused the paths (said).
    local self={}
    -- A build of every box, nearest to from ({X,Y}) first. what: from's name for the log.
    local function start(from,what)
        queue,failed,passes,ms,ended,unkept={},{},0,0,false,false
        for i,b in ipairs(BOXES) do queue[i]=b end
        local function far(b) return (b.at.X-from.X)^2+(b.at.Y-from.Y)^2 end
        table.sort(queue,function(a,b)
            local x,y=far(a),far(b)
            return x<y or x==y and a.i<b.i
        end)
        log(string.format('walls: %d to put up, %d a pass, nearest to %s first',#queue,Walls.PER_PASS,what))
    end
    local function keep()
        if #up==0 then return end
        local paths={}
        for i,d in ipairs(up) do paths[i]=d.path end
        local ok,why=pcall(store.save,table.concat(paths,'\t'))
        if ok or unkept then return end
        unkept=true
        log('walls: paths not kept ('..U.why(why)..'): a Lua reload would leave these walls up')
    end
    -- An earlier Lua load's walls, by the paths it kept.
    local function sweep()
        swept=true
        local ok,line=pcall(store.load)
        if not ok then
            log('walls: an earlier Lua load\'s paths unread ('..U.why(line)..'): none swept')
            return
        end
        if not line then return end
        local left,gone=0,0
        for _ in line:gmatch('[^\t]+') do left=left+1 end
        for path in line:gmatch('[^\t]+') do
            local ok,was=pcall(world.wall_swept,path)
            if not (ok and was) then break end -- No wall at the path: the world that held them is gone.
            gone=gone+1
        end
        store.clear()
        log(string.format('walls: an earlier Lua load left %d: %d swept',left,gone))
    end
    local function pass()
        if not swept then sweep() end
        if not queue then return end
        local started=os.clock()
        passes=passes+1
        for _=1,math.min(Walls.PER_PASS,#queue) do
            local b=table.remove(queue,1)
            local ok,d=pcall(world.wall,b)
            if ok then
                up[#up+1]=d
                if #up==1 then log('walls: first wall '..b.name..' up: '..tostring(d.read)) end
            else
                failed[#failed+1]=b.name
                if #failed<=SAID then log('walls: '..b.name..' not made: '..U.why(d)) end
            end
        end
        ms=ms+(os.clock()-started)*1000
        keep()
        if #queue>0 then return end
        queue=nil
        local missing=''
        if #failed>0 then
            missing='; not made: '..table.concat(failed,', ',1,math.min(#failed,NAMED))
                ..(#failed>NAMED and ' and '..#failed-NAMED..' more' or '')
        end
        log(string.format('walls: %d of %d up in %d passes, %.0f ms%s',#up,#BOXES,passes,ms,missing))
    end
    -- Each 250 ms pass while EVE's map is SBO Xion: the sweep once, then PER_PASS walls of a build.
    function self.tick()
        local ok,e=pcall(pass)
        if ok then return end
        queue,ended=nil,true
        log(string.format('walls: error (%s): the build is ended with %d of %d up',U.why(e),#up,#BOXES))
    end
    -- Every wall down and the build ended (reason: for the log). With nothing up and no build it does nothing.
    function self.down(reason)
        if not queue and #up==0 then return end
        local removed,gone,raised,why=0,0,0,nil
        for _,d in ipairs(up) do
            local ok,was=pcall(world.unwall,d)
            if not ok then raised,why=raised+1,why or U.why(was)
            elseif was then removed=removed+1
            else gone=gone+1 end
        end
        log(string.format('walls: down (%s): %d removed%s%s%s',reason,removed,
            gone>0 and ', '..gone..' gone already' or '',raised>0 and ', '..raised..' raised ('..why..')' or '',
            queue and #queue>0 and ', '..#queue..' never made' or ''))
        up,queue,failed,ended={},nil,{},false
        store.clear()
    end
    -- Each arrival in SBO Xion, with EVE's place there ({X,Y}): on, a new build nearest to her. Walls still up are
    -- taken down first.
    function self.arrive(at)
        self.down('an arrival')
        on,arrived=true,at
        start(at,'EVE')
    end
    -- One part of coop xion status.
    function self.status()
        if not on then return 'walls off' end
        return string.format('walls %d of %d up',#up,#BOXES)..(queue and ', '..#queue..' to go' or '')
            ..(#failed>0 and ', '..#failed..' not made' or '')..(ended and ', build ended' or '')
    end
    -- coop xion walls [on|off]: off takes the walls down until on or the next arrival. on puts them up again when none
    -- is up and none is being made, nearest to EVE first, or to her place at the arrival when she does not read. With
    -- no word: the status part.
    function self.switch(word)
        if word==nil then return true,self.status() end
        if word=='off' then
            on=false
            self.down('coop xion walls off')
            return true,'walls off until coop xion walls on or the next arrival'
        end
        if word~='on' then return false,'Use: coop xion walls [on|off]' end
        if on and (queue or #up>0) then return true,self.status() end
        on=true
        local read,m=pcall(world.move)
        local eve=read and m and m.at
        start(eve or arrived,eve and 'EVE' or 'EVE\'s place at the arrival')
        return true,'walls on: '..#BOXES..' to put up ([SX] lines follow)'
    end
    return self
end
return Walls
