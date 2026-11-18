-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The day/night cycle's wiring (sky/): the request for the native part's env writer.
return {
uses={'group','lobby','nightop'},
exports={'daynight'},
new=function(M)
local print,log=M.print,M.log
local U=require('core.unreal')
-- The day/night cycle (sky/daynight.lua): the request for the native part's env writer (sky/sky.h), decided in the
-- 250 ms loop of main/pass.lua from the map, the setting and SB's state; coop daynight reads and pins it
-- (sky/commands.lua).
-- The lobby rule is Xion's training room only: a hall lobby has its own row.
-- coop-sky.txt keeps the originals of the world's lights, so a Lua reload does not take the dimmed ones for them.
M.daynight=require('sky.daynight').new({log=log,ask=function(line) return M.ask(line)() end,
    status=function() return M.link and M.link.status() end,settings=M.settings,
    store=M.link and M.link.store('coop-sky.txt'),
    her=function() return U.her(U.valid(require('UEHelpers').GetPlayer())) end,address=U.address,map_of=U.map_of,
    world=function(eve) return U.address(eve:GetWorld()) end,
    cutscene=function() return M.group~=nil and M.group.cutscene_playing() end,
    screen=function() return M.kit~=nil and M.kit.paused(true) end,photo=M.photo_state,
    night=function() return M.night.running() end,
    frozen=function()
        local p=M.link and M.link.photo()
        return p~=nil and p.frozen
    end,
    lobby=function()
        local t=M.sbo and M.sbo.target()
        return t~=nil and t.key=='xion'
    end,
    find=function(path) return U.valid(StaticFindObject(path)) end,
    actors_of=function(path)
        local cls,her=U.valid(StaticFindObject(path)),U.her(U.valid(require('UEHelpers').GetPlayer()))
        return cls and her and (U.actors_of(cls,path:match('([^.]+)$'),her)) or {}
    end,
    load=function(path) return LoadAsset(path) end,
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
    cps=M.folder and require('sky.rule').cps(M.folder)})
return require('sky.commands').new({daynight=M.daynight})
end,
}
