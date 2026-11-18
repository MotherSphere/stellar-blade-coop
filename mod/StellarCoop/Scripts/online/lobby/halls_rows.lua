-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The hall lobbies' world, zone and seat rows: the native part's halls batch (online/lobby/halls_rows.h's kHallsRecipe,
-- added on the game thread), one WorldTable row and one type-5 ZoneTable row for each map of online/lobby/sbo_maps.lua,
-- so SB's warp reaches the maps of the local lobby pak, then one ZoneEnvSpawnTable row for each of its seats with a
-- row, the row the chair of SB's spawned at that seat binds to by name. Asked at the title on the co-op save files
-- (core/enemy.lua's title_batch, from main.lua's 250 ms loop), once a game run, and only once the lobby pak gate
-- passed: with no pak there is nothing to add, and nothing is said here. ok() tells online/lobby/sbo.lua whether the
-- hall maps can be used: a refusal (an ID a later SB update took, a row size that changed, a fault, rows that read back
-- other than written) keeps the lobby in Xion, said once a Lua load.
local Enemy=require('core.enemy')
local Maps=require('online.lobby.sbo_maps')
local Halls={}
-- The rows as core/enemy.lua reads them back (online/lobby/halls_rows_test checks them against
-- online/lobby/halls_rows.h's kHallsRecipe and kHallsPatches): the five worlds first, with the cooked persistent
-- level's UMapPath, then the five zones, each naming its world row and its spawn point, ZoneType 5 as in the template
-- row, AdditiveDesignLevel emptied, then the seats, maps in order, each in its hall's zone, named after itself,
-- InitStateTag FirstInteraction and SaveType None (0), all four other than in Xion's chair row it copies.
local rows,n={},#Maps.order
for i,key in ipairs(Maps.order) do
    local m=Maps.maps[key]
    rows[i]={'WorldTable',m.world,m.world_id,{{'UMapPath','s',m.umap..'.'..m.umap:match('[^/]+$'),true}}}
    rows[n+i]={'ZoneTable',m.zone,m.zone_id,{{'WorldAlias','n',m.world,true},{'ZoneType','e',5,false},
        {'StartPointAlias','s',m.point,true},{'AdditiveDesignLevel','N','',true}}}
end
for _,key in ipairs(Maps.order) do
    local m=Maps.maps[key]
    for _,s in ipairs(m.seats) do
        if s.row then
            rows[#rows+1]={'ZoneEnvSpawnTable',s.row,s.id,{{'ZoneList','N',m.zone,true},{'EnvActorName','n',s.row,true},
                {'InitStateTag','n','FirstInteraction',true},{'SaveType','e',0,true}}}
        end
    end
end
Halls.ROWS=Enemy.rows(rows)
-- rows/rows.h's refusals of a gate that stayed shut (busy, net, unread): the title asks again, so nothing is decided.
local SHUT={busy=true,net=true,unread=true}

-- o: log, status() the native status text, ask(line) its request (ok, message), gate() the lobby pak's version, or nil
-- and why (read once a Lua load).
function Halls.new(o)
    local log=o.log
    local e=Enemy.new({log=function(m) log('halls '..m) end,ask=o.ask,status=o.status},
        {word='halls',name='hall lobby',command='coop sbo',tag='[SB]',rows=Halls.ROWS,ids={}})
    local version=nil -- The lobby pak's version (false: none), looked for once a Lua load.
    local asking=false -- This Lua load's ask under way: the halls line may read rows before the read-back.
    local verdict=nil -- true: the rows in; false: refused (said); nil: nothing decided yet.
    local function refused(why)
        if verdict~=false then log('halls: rows refused ('..why..'), lobby stays in Xion') end
        verdict=false
    end
    -- The halls line's word: the rows in (this Lua load's read-back, or an earlier load's), or a refusal that stays.
    local function from_line()
        local s=Enemy.parse(o.status(),'halls')
        if not s then return end
        if s.state=='rows' then verdict=true
        elseif s.state=='fault' or s.state=='refused' and not SHUT[s.why] then refused(s.line) end
    end
    local title,title_stop=e.title_batch(function()
        if version==nil then version=o.gate() or false end
        asking=version~=false
        return version and 'the co-op save files and lobby pak '..version or nil
    end,'the next visit of the title',function(fine)
        asking=false
        if fine then verdict=true return end
        local s=Enemy.parse(o.status(),'halls')
        if s and s.state=='rows' then refused('they read back other than written') else from_line() end
    end)
    local self={}
    -- title(at_title, coop): at each 250 ms pass while the title shows (main.lua).
    self.title=title
    -- Each 250 ms pass: the title's ask's wait and read-back.
    self.tick=e.tick
    -- true when the hall maps' rows are in, false when refused, nil while nothing is decided.
    function self.ok()
        if verdict==nil and not asking then from_line() end
        return verdict
    end
    -- coop off: the title's wait ended (the rows already in stay for the game run).
    function self.stop()
        title_stop()
        e.stop()
    end
    return self
end
return Halls
