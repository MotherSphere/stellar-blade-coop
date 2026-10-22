-- The camp phone booths near EVE, for the co-op line: the booth of every full camp (Env_Camp_TeleportMachine_C) and
-- the warp-only phones (Env_Camp_TeleportMachine_Standalone_C). The levels place them and they stream in and out with
-- distance, so the list is found again: at once on a new map, then at most every EVERY s. FindAllOf walks every object,
-- so it never runs per tick; each scan is timed and a slow one gets its own line. Positions are read during a scan
-- only, and no booth is touched between scans. Nothing in the game is changed: the only game calls are FindAllOf on the
-- two classes, K2_GetActorLocation and the EnvActorName read.
local U=require('core.unreal')
local Booth={}
Booth.CLASSES={'Env_Camp_TeleportMachine_C','Env_Camp_TeleportMachine_Standalone_C'}
Booth.NEAR,Booth.EVERY,Booth.SLOW=3,4,5 -- metres; seconds between scans; a scan this many ms gets its own line
local function metres(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)/100 end
-- me, in tick and near: puppet.me(), {at={X,Y,Z},map=}, or nil.
function Booth.new(log)
    -- The last scan's booths ({id,class,at}), its map, the next scan's time, and the last line's '<n> on <map>' (or
    -- 'scan failed on <map>: <why>').
    local list,map,due,said={},nil,-math.huge,nil
    local function scan(now,where)
        -- ponytail: a fixed scan every EVERY s; NotifyOnNewObject on the two classes if slow-scan lines show in play.
        list,map,due=({}),where,now+Booth.EVERY
        local t=os.clock()
        -- A scan that raises finds no booth, says why once (until the next change) and is tried again EVERY s later:
        -- tick never raises into the caller's loop.
        local ok,why=pcall(function()
            for _,class in ipairs(Booth.CLASSES) do
                U.each(FindAllOf and FindAllOf(class) or {},function(_,a)
                    pcall(function() -- A booth whose read raises is skipped.
                        a=U.valid(a)
                        if not a then return end
                        local at=U.value_of(a:K2_GetActorLocation())
                        list[#list+1]={id=U.text(a.EnvActorName),class=class,at={X=at.X,Y=at.Y,Z=at.Z}}
                    end)
                end)
            end
        end)
        if not ok then list={} end
        local ms=(os.clock()-t)*1000
        local now_said=ok and #list..' on '..map or 'scan failed on '..map..': '..tostring(why)
        if now_said~=said then log(string.format('booths: %s (%.1f ms)',now_said,ms)) end
        said=now_said
        if ms>=Booth.SLOW then log(string.format('booths: slow scan %.1f ms (%d found)',ms,#list)) end
    end
    local self={}
    -- No EVE: nothing, and the list is kept.
    function self.tick(now,me)
        if me and (me.map~=map or now>=due) then scan(now,me.map) end
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
