-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet's wiring (closet/wiring.lua) over stub parts: coop off stops each part under a guard of its own, the menu
-- first, so a part whose stop raises never skips the others (the menu's camera gives SB's view back). The dress and the
-- menu refuse while SBO's own state holds EVE's body, read through its modules' exports.
local run = dofile('tests/lua/closet/run.lua')
local Loader = require('main.loader')

-- Each part a stub whose stop is counted; raising: the parts whose stop raises.
local function wire(raising)
    local stopped, logged, given = {}, {}, {}
    local function part(name)
        return {tick = function() end, stop = function()
            stopped[#stopped + 1] = name
            if raising[name] then error(name .. ' raised') end
        end}
    end
    local stubs = {
        ['closet.dress'] = {new = function(o)
            given.dress = o
            local d = part('dress'); d.installed = function() end; return d
        end},
        ['closet.ui.camera'] = {FILE = 'cam', new = function() return {} end},
        ['closet.ui.menu'] = {new = function(o) given.menu = o; return {open = function() end} end},
        ['closet.options'] = {FILE = 'o', new = function() return part('options') end},
        ['closet.presets'] = {FILE = 'p', new = function() return {} end},
        ['closet.colour'] = {FILE = 'c', new = function() return part('colour') end},
        ['closet.shape'] = {FILE = 's', new = function() return part('shape') end},
        ['closet.ui.probe'] = {new = function() return part('probe') end},
        ['closet.thumbs'] = {FILE = 't', new = function() return part('thumbs') end},
        ['closet.packs'] = {new = function() return {scan = function() end} end},
        ['closet.fits'] = {use = function() end},
        ['closet.commands'] = {new = function() return {} end},
        ['core.pak_gate'] = {paks_of = function() end},
        ['core.link'] = {files = {}},
    }
    for name, stub in pairs(stubs) do package.loaded[name] = stub end
    package.loaded['closet.wiring'] = nil
    local M = {print = function() end}
    function M.guarded(name, f, ...)
        local good, why = pcall(f, ...)
        if not good then logged[#logged + 1] = name .. ': ' .. tostring(why) end
    end
    local wiring = require('closet.wiring')
    wiring.new(M)
    M.link, M.kit = {store = function() end}, {}
    wiring.build.menu(M, {})
    M.closet_menu = part('menu')
    for name in pairs(stubs) do package.loaded[name] = nil end
    return M, stopped, logged, given
end

local ALL = {'menu', 'dress', 'options', 'colour', 'shape', 'probe', 'thumbs'}

local tests = {
    coop_off_stops_every_part_menu_first = function()
        local M, stopped, logged = wire({})
        M.closet.stop()
        same(stopped, ALL, 'every part, the menu first') same(logged, {}, 'nothing raised')
    end,
    a_stop_that_raises_never_skips_the_others = function()
        local M, stopped, logged = wire({dress = true, options = true})
        M.closet.stop()
        same(stopped, ALL, 'every part stopped')
        eq(#logged, 2, 'both errors logged')
        ok(logged[1]:find('^closet: .*dress raised'), logged[1])
        ok(logged[2]:find('^closet options: .*options raised'), logged[2])
        M, stopped = wire({menu = true})
        M.closet.stop()
        same(stopped, ALL, 'a menu that raises skips nothing either')
    end,
    -- The bike ride (the runtime's riding), the Doro look, the rifle out, an emote, a coop wear suit (eve/wear.lua's
    -- worn() leaves a hair alone out): each one's key (closet.refused) and its words, for the dress and the menu alike.
    -- Off modules' stubs hold nothing.
    sbo_state_that_holds_her_body_refuses = function()
        local M, _, _, given = wire({})
        M.riding = function() return false end
        M.doro, M.gun, M.emote, M.wear = Loader.STUB, Loader.STUB, Loader.STUB, Loader.STUB
        eq(given.dress.busy(), nil, 'off modules hold nothing') eq(given.menu.busy(), nil, 'nor for the menu')
        local on = {}
        M.riding = function() return on.bike end
        M.doro = {active = function() return on.doro end}
        M.gun = {out = function() return on.rifle end}
        M.emote = {active = function() return on.emote end}
        M.wear = {worn = function() return on.wear end}
        eq(given.dress.busy(), nil, 'none on')
        for _, key in ipairs({'bike', 'doro', 'rifle', 'emote', 'wear'}) do
            on = {[key] = true}
            local got, why = given.dress.busy()
            eq(got, key, key) eq(type(why), 'string', key .. ': its words')
            if key == 'wear' then ok(why:find('coop wear off suit', 1, true), why) end
            eq((given.menu.busy()), key, key .. ': the menu')
        end
    end,
}
run('wiring_test', tests)
