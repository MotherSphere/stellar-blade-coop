-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The camp phone booths near EVE, for the co-op line: the booth of every full camp (Env_Camp_TeleportMachine_C) and the
-- warp-only phones (Env_Camp_TeleportMachine_Standalone_C). The levels place them and they stream in and out with
-- distance. A booth never moves, so each one a scan finds is kept until the map changes (the scans of a map add up),
-- and a scan runs only when it may find a new one: at once on a new map, then once EVE is FAR m from where the last
-- scan ran, at most every EVERY s, and only while she moves at PACE or slower. A scan asks the engine's class hash for
-- each class's actors (core/unreal.lua's actors_of): FindAllOf, which walks every object, held the game thread 60 to 79
-- ms at each scan in game. The hash route still took 20 to 55 ms a scan in game (59 ms the first on a new map,
-- UE4SS.log 2026-11-12): a scan every 4 s was a micro freeze every 4 s. Each class is looked up by its path at each
-- scan and never kept: a class kept across a reload of the same map is freed, and IsValid on freed memory is no guard.
-- The lookup asks the engine's name hash (core/unreal.lua's class_at). UE4SS's StaticFindObject, which walks the
-- objects, made each scan 31 to 61 ms in game (UE4SS.log 2026-11-12) and is only the fallback now.
-- Each scan is timed and a slow one gets its own line, with the route of its actor lists and of its class lookups. The
-- class lookup route also gets a line of its own once it is decided.
-- Positions are read during a scan only, and no booth is touched between scans. Nothing in the game is changed: the
-- only game calls are the class lookups, the actor lists of the two classes, K2_GetActorLocation and the EnvActorName
-- read.
local U=require('core.unreal')
local Booth={}
Booth.CLASSES={'Env_Camp_TeleportMachine_C','Env_Camp_TeleportMachine_Standalone_C'}
Booth.PATHS={Env_Camp_TeleportMachine_C='/Game/GameDesign/Level/ZoneEnv/Env_Camp_TeleportMachine.'
    ..'Env_Camp_TeleportMachine_C',Env_Camp_TeleportMachine_Standalone_C='/Game/GameDesign/Level/ZoneEnv/'
    ..'Env_Camp_TeleportMachine_Standalone.Env_Camp_TeleportMachine_Standalone_C'}
Booth.NEAR,Booth.EVERY,Booth.SLOW=3,30,5 -- metres; least seconds between two scans; a scan this many ms gets its line
Booth.FAR=100 -- metres from the last scan's spot before a scan may find a booth that streamed in since
Booth.PACE=300 -- cm/s: a scan that is due waits while EVE moves faster (her run is 500)
local metres=U.metres
-- me, in tick and near: core/where.lua's me(), {at={X,Y,Z},map=}, or nil.
function Booth.new(log)
    -- The booths found on this map ({id,class,at}, each once by its position), the map, the last good scan's spot, the
    -- next scan's earliest time, and the last line's '<n> on <map>' (or 'scan failed on <map>: <why>').
    local list,seen,map,from,due,said={},{},nil,nil,-math.huge,nil
    local route,look='walk','walk' -- The routes of the last actor list and of the last class lookup.
    local told=nil -- The class lookup route said so far.
    local function scan(now,me)
        if me.map~=map then list,seen,from={},{},nil end
        map,due=me.map,now+Booth.EVERY
        local t=os.clock()
        local got={}
        -- A scan that raises adds no booth, says why once (until the next change) and is tried again EVERY s later (its
        -- spot does not count as scanned): tick never raises into the caller's loop.
        local ok,why=pcall(function()
            local ctx=U.controller()
            for _,class in ipairs(Booth.CLASSES) do
                local cls
                cls,look=U.class_at(Booth.PATHS[class],ctx)
                local found={}
                if cls then found,route=U.actors_of(cls,class,ctx) end
                for _,a in ipairs(found) do
                    pcall(function() -- A booth whose read raises is skipped.
                        local at=U.value_of(a:K2_GetActorLocation())
                        got[#got+1]={id=U.text(a.EnvActorName),class=class,at={X=at.X,Y=at.Y,Z=at.Z}}
                    end)
                end
            end
        end)
        if ok then from={X=me.at.X,Y=me.at.Y,Z=me.at.Z} else got={} end
        for _,b in ipairs(got) do
            local key=string.format('%.0f %.0f %.0f',b.at.X,b.at.Y,b.at.Z)
            if not seen[key] then seen[key]=true; list[#list+1]=b end
        end
        local ms=(os.clock()-t)*1000
        local now_said=ok and #list..' on '..map or 'scan failed on '..map..': '..tostring(why)
        if now_said~=said then log(string.format('booths: %s (%.1f ms)',now_said,ms)) end
        said=now_said
        if ms>=Booth.SLOW then log(string.format('booths: slow scan %.1f ms (%d found, %s, %s)',ms,#got,route,look)) end
        -- The lookup route once class_at has decided it (once a Lua load), fast scan or slow: a failed check says why.
        if look~='walk' and look~=told then
            told=look
            log('booths: class lookup route: '..look)
        end
    end
    local self={}
    local was -- EVE's place and the time at the last tick, for her speed.
    -- No EVE: nothing, and the list is kept.
    function self.tick(now,me)
        local fast=me and was and now>was.now and metres(me.at,was.at)*100/(now-was.now)>Booth.PACE
        was=me and {at=me.at,now=now}
        if me and (me.map~=map or now>=due and not fast and (not from or metres(me.at,from)>=Booth.FAR)) then
            scan(now,me)
        end
    end
    -- The nearest booth found on EVE's map within NEAR m: {id=,class=,d=} (d in metres), or nil.
    function self.near(me)
        if not me or me.map~=map then return nil end
        local best=nil
        for _,b in ipairs(list) do
            local d=metres(b.at,me.at)
            if d<=Booth.NEAR and (not best or d<best.d) then best={id=b.id,class=b.class,d=d} end
        end
        return best
    end
    return self
end
return Booth
