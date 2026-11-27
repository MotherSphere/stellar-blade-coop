-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The slot taxonomy (closet/slots.lua): unique ids, apply order by layer, each slot's kind and menu, the ghost-part
-- rule, the adult menu, the menu lists, the pairs of left and right slots and each slot's glyph PNG.
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
        -- The Colour tab lists closet/colour.lua's roles, never a slot.
        for _, menu in ipairs(Slots.MENUS) do
            if menu[1] == 'colour' then same(Slots.in_menu('colour'), {}, 'the Colour tab lists no slot')
            else ok(#Slots.in_menu(menu[1]) > 0, menu[1] .. ' is empty') end
        end
        same(Slots.in_menu('full'), {Slots.FULL_OUTFIT})
        same(Slots.in_menu('weapon'), {'Weapon'})
    end,
    the_colour_tab_follows_full_outfit = function()
        local ids, beta = {}, {}
        for i, menu in ipairs(Slots.MENUS) do
            ids[i] = menu[1]
            if menu[3] then beta[#beta + 1] = menu[1] end
        end
        same(ids, {'full', 'colour', 'head', 'torso', 'arms', 'hips', 'intimate', 'legs', 'body', 'weapon'}, 'the tabs')
        same(beta, {'head', 'torso', 'arms', 'hips', 'intimate', 'legs', 'body'}, 'the Beta tabs')
        eq(Slots.ADULT_MENU.colour, false, 'not adult')
    end,
    every_slot_has_a_glyph_png = function()
        -- Each slot's glyph (Slots.glyph) is a 256 px RGBA PNG in closet/ui/icons/ (tools/closet_icons/render.py's):
        -- the PNG signature, then IHDR's width and height (4 bytes each, big end), bit depth 8 and colour type 6.
        local glyphs = {}
        for _, entry in ipairs(Slots.LIST) do
            local name = Slots.glyph(entry[1])
            ok(type(name) == 'string' and name:match('^[a-z_]+$'), entry[1] .. ' glyph ' .. tostring(name))
            if not glyphs[name] then
                glyphs[name], glyphs[#glyphs + 1] = true, name
                local f = io.open('mod/StellarCoop/Scripts/closet/ui/icons/' .. name .. '.png', 'rb')
                ok(f, entry[1] .. ': no ' .. name .. '.png')
                local head = f:read(26)
                f:close()
                eq(head:sub(1, 8), '\137PNG\r\n\26\n', name .. ' signature')
                same({string.unpack('>I4I4BB', head, 17)}, {256, 256, 8, 6, 27}, name .. ' size and colour')
            end
        end
        eq(#glyphs, 41, 'glyphs for the 73 slots')
        eq(#Slots.LIST, 73, 'slots')
        eq(Slots.glyph(Slots.FULL_OUTFIT), 'full_outfit') eq(Slots.glyph('TattooBack'), 'tattoo')
        eq(Slots.glyph('FaceTattoo'), 'tattoo') eq(Slots.glyph('NippleL'), 'piercing') eq(Slots.glyph('Anus'), 'body')
        eq(Slots.glyph('AnkletR'), 'bracelet') eq(Slots.glyph('Garter'), 'band') eq(Slots.glyph('Nope'), nil)
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
