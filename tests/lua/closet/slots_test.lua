-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The slot taxonomy (closet/slots.lua): unique ids, apply order by layer, each slot's kind and menu, the ghost-part
-- rule, the adult menu, the menu lists and the pairs of left and right slots.
local run = dofile('tests/lua/closet/run.lua')
local Slots = require('closet.slots')

local KINDS = {mesh = true, swap = true, skin = true, colour = true, body = true}
local GROUPS = {body = true, head = true, weapon = true, override = true}

local tests = {
    ids_are_unique_and_complete = function()
        local seen = {}
        for _, entry in ipairs(Slots.LIST) do
            ok(not seen[entry[1]], 'duplicate ' .. entry[1])
            seen[entry[1]] = true
            ok(KINDS[entry[4]], entry[1] .. ' kind ' .. tostring(entry[4]))
            ok(GROUPS[entry[3]], entry[1] .. ' group ' .. tostring(entry[3]))
            ok(Slots.ADULT_MENU[entry[5]] ~= nil, entry[1] .. ' menu ' .. tostring(entry[5]))
        end
        ok(Slots.known(Slots.FULL_OUTFIT))
        ok(not Slots.known('Neck') and not Slots.known('PelvicHardware') and not Slots.known('FacePiercings'),
            'the split slots are gone')
    end,
    list_is_in_layer_order = function()
        local last = -1
        for _, entry in ipairs(Slots.LIST) do
            ok(entry[2] >= last, entry[1] .. ' breaks the layer order')
            last = entry[2]
        end
        same(Slots.sort({'Hair', 'Shoes', 'BaseBody', Slots.FULL_OUTFIT, 'Legs'}),
            {'BaseBody', 'Legs', 'Shoes', 'Hair', Slots.FULL_OUTFIT})
    end,
    only_mesh_slots_cost_a_part = function()
        eq(Slots.costs_part('EarringL'), true) eq(Slots.costs_part('Chest'), true)
        eq(Slots.costs_part('Hair'), false, 'a swap replaces her own part')
        eq(Slots.costs_part('TattooBack'), false) eq(Slots.costs_part('Fingernails'), false)
        eq(Slots.costs_part('BaseBody'), false) eq(Slots.costs_part('Nope'), false)
    end,
    the_head_survives_a_full_outfit = function()
        for _, id in ipairs(Slots.in_menu('head')) do eq(Slots.group(id), 'head', id) end
        eq(Slots.group('Weapon'), 'weapon')
        for _, id in ipairs(Slots.in_menu('torso')) do eq(Slots.group(id), 'body', id) end
    end,
    only_the_intimate_menu_is_adult = function()
        local adult = {}
        for _, entry in ipairs(Slots.LIST) do
            if Slots.adult(entry[1]) then adult[#adult + 1] = entry[1] end
        end
        same(adult, {'PubicHair', 'Anus', 'TattooPubic', 'ClitPiercing', 'LabiaPiercing', 'AnalPlug'})
    end,
    every_menu_lists_slots = function()
        for _, menu in ipairs(Slots.MENUS) do ok(#Slots.in_menu(menu[1]) > 0, menu[1] .. ' is empty') end
        same(Slots.in_menu('full'), {Slots.FULL_OUTFIT})
        same(Slots.in_menu('weapon'), {'Weapon'})
    end,
    left_slots_have_right_twins = function()
        for _, entry in ipairs(Slots.LIST) do
            local base = entry[1]:match('^(.+)L$')
            if base and Slots.known(base .. 'R') then
                eq(Slots.layer(base .. 'R'), entry[2], base) eq(Slots.menu(base .. 'R'), entry[5], base)
            end
        end
        ok(Slots.known('EarringR') and Slots.known('NippleR') and Slots.known('BraceletR') and Slots.known('AnkletR'))
    end,
}
run('slots_test', tests)
