-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The engine lookups main.lua's two loops make at idle, counted by fixture.lua's FindAllOf and StaticFindObject
-- (UE4SS's FindAllOf walks every object, 25 to 80 ms in game; a StaticFindObject of a path not in memory costs 25 to 35
-- ms). One minute at 64 frames a second, the 250 ms loop every 16th frame, with the native part, no session and EVE
-- standing still, each case from a fresh Lua load (the modules main.lua requires loaded again, their caches empty). In
-- a world with the UI up, the first frame finds the player controller's class, the first 250 ms pass the photo mode's
-- library, the engine's library and the booths' two classes, and its booth scan walks for the player controllers and
-- the booths of each class (the fixture gives no player controller, so the class hash is never proven); then nothing
-- more for the rest of the minute. At the title, the controller's class and the engine's library only.
dofile('tests/lua/main/fixture.lua')
local fakes={} -- The fixture's fake modules and Lua's own libraries.
for name in pairs(package.loaded) do fakes[name]=true end
local function idle(world)
    for name in pairs(package.loaded) do if not fakes[name] then package.loaded[name]=nil end end
    settings_text,status_text,link_mode,photo_mode='',plain,'none',false
    in_world,at_title=world,not world
    load_main(true)
    kit_ready=true
    finds.all,finds.static=0,0
    local first
    for frame=1,64*60 do
        clock=frame/64
        loops[1].f()
        if frame%16==0 then loops[2].f() end
        if frame==64 then first=finds.all..' '..finds.static end
    end
    assert(not logged('error'),table.concat(printed,'|'))
    in_world,at_title,kit_ready=false,false,false
    return first..', '..finds.all..' '..finds.static
end
-- FindAllOf and StaticFindObject after 1 s, then after 60 s.
local counts=idle(true)
assert(counts=='4 5, 4 5','World: '..counts)
counts=idle(false)
assert(counts=='0 2, 0 2','Title: '..counts)
io.stdout:write('idle_test ok\n')
