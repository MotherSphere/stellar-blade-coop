-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Other players' parked bikes on our screen: each member's bike line (link.bikes, vehicles/bike/park.lua's from_wire)
-- drawn as a copy (vehicles/bike/stand.lua, culled at 200 m) while it parks on the map our EVE stands on. Every 250 ms
-- (self.slow): no copy before our EVE has been in the world 2 s, at most one made a pass, a copy moved when its place
-- changes, removed when its line says none, names another map or is gone (she left the lobby). None for our own
-- SteamID, none with bike=off (that setting frees the bike's files) or while the mesh is not ready. A new EVE drops
-- them all (the level took them). Hidden while a level sequence holds our EVE; while shown, solid against her once she
-- is clear of it. The copies' actor paths go to coop-bike-copies.txt, tab-separated: the next Lua load's first tick
-- sweeps them (Ctrl+R).
-- tests/lua/vehicles/bike/others_test.lua covers it.
local U=require('core.unreal')
local Park=require('vehicles.bike.park')
local Stand=require('vehicles.bike.stand')
local Ride=require('vehicles.bike.ride')
local Others={}
local SETTLE=2 -- s our EVE has been in the world before a copy is made (the ride's own wait).

local function path_of(o) return o:GetFullName():match('^%S+ (.+)$') end
local function whole(v) return math.floor(v+0.5) end

-- o: log (the [BK] lines); bikes() (link.bikes: SteamID to bike line); members() (link.members, for names); me() (our
-- SteamID, nil before Steam); eve() (our EVE, or nil); status() (the native status text); settings (main.lua's: bike,
-- false for off); store (coop-bike-copies.txt through link.store).
function Others.new(o)
    local log,store=o.log,o.store
    local self={}
    local copies={} -- SteamID to {d (the stand), payload (its line as placed), name}.
    local failed={} -- SteamID to the line whose copy could not be made: not tried again until it changes.
    local told={} -- SteamID to the line logged last.
    local seen=nil -- Our EVE: {at, path, since (os.clock), map}.
    local saved='' -- The copies' paths as the store holds them.
    local restored=false

    local function name_of(id,names)
        local n=names and names[id] or copies[id] and copies[id].name
        return (n and n~='') and n or id
    end
    local function save()
        local list={}
        for _,c in pairs(copies) do list[#list+1]=c.d.path end
        table.sort(list)
        local joined=table.concat(list,'\t')
        if joined==saved then return end
        saved=joined
        if joined=='' then store.clear() else store.save(joined) end
    end
    local function remove(id,why,names)
        local name,c=name_of(id,names),copies[id]
        copies[id]=nil
        Stand.remove(c.d)
        log(('bike of %s: copy removed (%s)'):format(name,why))
    end
    local function drop(why)
        for id in pairs(copies) do remove(id,why) end
        failed={}
        save()
    end
    -- Each member's line logged once each time it changes.
    local function tell(bikes,me,names)
        for id,payload in pairs(bikes) do
            if id~=me and told[id]~=payload then
                told[id]=payload
                local place=Park.from_wire(payload)
                log(place and ('bike of %s: parked on %s at %d,%d,%d'):format(name_of(id,names),
                    place.map:match('[^/]+$') or place.map,whole(place.at.X),whole(place.at.Y),whole(place.at.Z))
                    or ('bike of %s: none'):format(name_of(id,names)))
            end
        end
        for id in pairs(told) do if not bikes[id] then told[id]=nil end end
    end

    function self.slow()
        local bikes,me=o.bikes() or {},o.me()
        local names={}
        for _,m in ipairs(o.members() or {}) do names[m.id]=m.name end
        tell(bikes,me,names)
        if o.settings and o.settings.bike==false then return drop('bike=off') end
        local w=Ride.native(o.status())
        if not (w and w.load=='ready') then return drop('the bike is not loaded') end
        local e=o.eve()
        if not e then return end
        local now=os.clock()
        local at,path=U.address(e),path_of(e)
        if not seen or seen.at~=at or seen.path~=path then
            drop('a new EVE')
            seen={at=at,path=path,since=now,map=U.map_of(e)}
        end
        if now-seen.since<SETTLE then return end
        -- The copies whose line is gone, says none or names another map.
        for id,c in pairs(copies) do
            local place=Park.from_wire(bikes[id])
            local why=not bikes[id] and 'left the lobby' or not place and 'none'
                or place.map~=seen.map and 'another map' or not Stand.alive(c.d) and 'gone'
            if why then remove(id,why,names) end
        end
        -- Then each line on our map in SteamID order: moved, or made (one a pass).
        local ids={}
        for id in pairs(bikes) do if id~=me then ids[#ids+1]=id end end
        table.sort(ids)
        local made=false
        for _,id in ipairs(ids) do
            local payload=bikes[id]
            local place=Park.from_wire(payload)
            local c=copies[id]
            if place and place.map==seen.map then
                if c and c.payload~=payload then
                    Stand.put(c.d,place)
                    c.payload=payload
                elseif not c and not made and failed[id]~=payload then
                    made=true
                    local ok,d=pcall(Stand.make,e:GetWorld(),Ride.MESH,Stand.CULL)
                    if ok then
                        Stand.put(d,place)
                        copies[id]={d=d,payload=payload,name=names[id]}
                    else
                        failed[id]=payload
                        log(('bike of %s: copy not made: %s'):format(name_of(id,names),U.why(d)))
                    end
                end
            end
        end
        local held=e:IsAttachedToLevelSequenceWithoutPlayable()==true
        for id,c in pairs(copies) do
            if c.d.shown==held then Stand.show(c.d,not held) end
            local line=Stand.step(c.d,e)
            if line then log(('bike of %s: %s'):format(name_of(id,names),line)) end
        end
        save()
    end
    -- coop off: every copy out of our world.
    function self.clear(why) drop(why or 'coop off') end
    -- At the first tick of a Lua load, once: the copies an earlier load left in the world swept by their paths.
    function self.restore()
        if restored then return end
        restored=true
        local text=store.load()
        if not text then return end
        for p in (text..'\t'):gmatch('([^\t]+)\t') do
            local swept,why=pcall(Stand.sweep,p,Ride.MESH)
            if not swept then log('bike copy not swept: '..U.why(why)) end
        end
        store.clear()
    end
    return self
end
return Others
