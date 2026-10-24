-- The camp phone booths near EVE, for the co-op line: the booth of every full camp (Env_Camp_TeleportMachine_C) and
-- the warp-only phones (Env_Camp_TeleportMachine_Standalone_C). The levels place them and they stream in and out with
-- distance, so the list is found again: at once on a new map, then at most every EVERY s, and only while EVE moves at
-- PACE or slower. A scan asks the engine's class hash for each class's actors (core/unreal.lua's actors_of): FindAllOf,
-- which walks every object, held the game thread 60 to 79 ms at each scan in game, a freeze every 4 s. Each class is
-- found by its path once a map while it is in memory; one that is not is looked up again RETRY s later (a lookup of a
-- path not in memory costs up to 35 ms). Each scan is timed and a slow one gets its own line, with its route.
-- Positions are read during a scan only, and no booth is touched between scans. Nothing in the game is changed: the
-- only game calls are the class lookups, the actor lists of the two classes, K2_GetActorLocation and the EnvActorName
-- read.
local U=require('core.unreal')
local Booth={}
Booth.CLASSES={'Env_Camp_TeleportMachine_C','Env_Camp_TeleportMachine_Standalone_C'}
Booth.PATHS={Env_Camp_TeleportMachine_C='/Game/GameDesign/Level/ZoneEnv/Env_Camp_TeleportMachine.'
    ..'Env_Camp_TeleportMachine_C',Env_Camp_TeleportMachine_Standalone_C='/Game/GameDesign/Level/ZoneEnv/'
    ..'Env_Camp_TeleportMachine_Standalone.Env_Camp_TeleportMachine_Standalone_C'}
Booth.RETRY=30 -- s before a class not in memory is looked up again on the same map
Booth.NEAR,Booth.EVERY,Booth.SLOW=3,4,5 -- metres; seconds between scans; a scan this many ms gets its own line
Booth.PACE=300 -- cm/s: a scan that is due waits while EVE moves faster (her run is 500)
local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
-- me, in tick and near: puppet.me(), {at={X,Y,Z},map=}, or nil.
function Booth.new(log)
    -- The last scan's booths ({id,class,at}), its map, the next scan's time, and the last line's '<n> on <map>' (or
    -- 'scan failed on <map>: <why>').
    local list,map,due,said={},nil,-math.huge,nil
    local classes,retry={},{} -- This map's class objects found, and when a class not found is looked up again.
    local route='walk'
    local function scan(now,where)
        if where~=map then classes,retry={},{} end
        list,map,due=({}),where,now+Booth.EVERY
        local t=os.clock()
        -- A scan that raises finds no booth, says why once (until the next change) and is tried again EVERY s later:
        -- tick never raises into the caller's loop.
        local ok,why=pcall(function()
            local ctx=U.controller()
            for _,class in ipairs(Booth.CLASSES) do
                local cls=U.valid(classes[class])
                if not cls and now>=(retry[class] or -math.huge) then
                    cls=U.valid(StaticFindObject(Booth.PATHS[class]))
                    classes[class],retry[class]=cls,now+Booth.RETRY
                end
                local found={}
                if cls then found,route=U.actors_of(cls,class,ctx) end
                for _,a in ipairs(found) do
                    pcall(function() -- A booth whose read raises is skipped.
                        local at=U.value_of(a:K2_GetActorLocation())
                        list[#list+1]={id=U.text(a.EnvActorName),class=class,at={X=at.X,Y=at.Y,Z=at.Z}}
                    end)
                end
            end
        end)
        if not ok then list={} end
        local ms=(os.clock()-t)*1000
        local now_said=ok and #list..' on '..map or 'scan failed on '..map..': '..tostring(why)
        if now_said~=said then log(string.format('booths: %s (%.1f ms)',now_said,ms)) end
        said=now_said
        if ms>=Booth.SLOW then log(string.format('booths: slow scan %.1f ms (%d found, %s)',ms,#list,route)) end
    end
    local self={}
    local was -- EVE's place and the time at the last tick, for her speed.
    -- No EVE: nothing, and the list is kept.
    function self.tick(now,me)
        local fast=me and was and now>was.now and metres(me.at,was.at)*100/(now-was.now)>Booth.PACE
        was=me and {at=me.at,now=now}
        if me and (me.map~=map or now>=due and not fast) then scan(now,me.map) end
    end
    -- The nearest kept booth on EVE's map within NEAR m: {id=,class=,d=} (d in metres), or nil.
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
