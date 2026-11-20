-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The day/night cycle's wiring (world/daynight/): the request for the native part's env writer.
return {
uses={'online.lobby','online.modes.nightop'},
exports={'daynight'},
new=function(M)
local print,log=M.print,M.log
local U=require('core.unreal')
local Keep=require('core.keep')
local Rule=require('world.daynight.rule')
-- The day/night cycle (world/daynight/daynight.lua): the request for the native part's env writer
-- (world/daynight/sky.h), decided in the 250 ms loop of main/pass.lua from the map, the setting and SB's state; coop
-- daynight reads and pins it (world/daynight/commands.lua).
-- The lobby rule is Xion's training room only: a hall lobby has its own row.
-- coop-sky.txt keeps the originals of the world's lights, so a Lua reload does not take the dimmed ones for them.
-- The star material is the keep's (core/keep.lua): the layer waits for it, never loads it on the game thread.
Keep.want({Rule.STARS})
M.daynight=require('world.daynight.daynight').new({log=log,ask=function(line) return M.ask(line)() end,
    status=function() return M.link and M.link.status() end,settings=M.settings,
    store=M.link and M.link.store('coop-sky.txt'),
    her=function() return U.her(U.valid(require('UEHelpers').GetPlayer())) end,address=U.address,map_of=U.map_of,
    world=function(eve) return U.address(eve:GetWorld()) end,
    photo=M.photo_state,
    night=function() return M.night.running() end,
    frozen=function()
        local p=M.link and M.link.photo()
        return p~=nil and p.frozen
    end,
    lobby=function()
        local t=M.sbo and M.sbo.target()
        return t~=nil and t.key=='xion'
    end,
    find=function(path)
        if Keep.serves(path) then return Keep.get(path) end
        return U.valid(StaticFindObject(path))
    end,
    actors_of=function(path)
        local cls,her=U.valid(StaticFindObject(path)),U.her(U.valid(require('UEHelpers').GetPlayer()))
        return cls and her and (U.actors_of(cls,path:match('([^.]+)$'),her)) or {}
    end,
    load=function(path) if not Keep.serves(path) then return LoadAsset(path) end end,
    stars_ready=function() return not Keep.wanted(Rule.STARS) or Keep.ready() end,
    -- The streaming level of a sublevel package in EVE's world (GameplayStatics GetStreamingLevel matches the end of
    -- each streaming level's package name in C++), or nil when it is not streamed.
    level=function(package)
        local her=U.her(U.valid(require('UEHelpers').GetPlayer()))
        return her and U.find('/Script/Engine.Default__GameplayStatics'):GetStreamingLevel(her,FName(package)) or nil
    end,
    exists=function(path)
        local f=io.open(path,'rb')
        if f then f:close() end
        return f~=nil
    end,
    cps=M.folder and Rule.cps(M.folder)})
return require('world.daynight.commands').new({daynight=M.daynight})
end,
}
