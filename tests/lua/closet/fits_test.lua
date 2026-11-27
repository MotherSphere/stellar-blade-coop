-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The fit maps (closet/fits.lua): each names every material slot of its mesh exactly once (skin, a piece or unknown),
-- in known slots and regions, one piece a slot; and the lookups.
local run = dofile('tests/lua/closet/run.lua')
local Fits = require('closet.fits')
local Slots = require('closet.slots')

-- Material slot counts of the two meshes, read in game on 25 Nov 2026 (coop closet skin <fit> <n> on refuses an n
-- past the mesh's last slot).
local SLOT_COUNT = {AiK_CH27_14595 = 48, AiK_CH46_xSH_14462 = 44}

-- A pack item as closet/cns_import.lua makes it (only the fields Fits.pack reads), with two variants.
local function item(id, extra)
    local it = {UniqueFitID = id, DisplayName = 'Pack ' .. id, Slot = 'FullOutfit', Image = '/Game/I/P.P',
        File = '~mods\\P\\Some Pack.dekcns.json',
        Variants = {{Mesh = '/Game/P/V1.V1', HiddenMats = {7}}, {Mesh = '/Game/P/V2.V2', HiddenMats = {}}},
        UserConfigs = {MaterialToggles = {{MaterialIndex = 3, Value = false}, {MaterialIndex = 4, Value = true},
            {MaterialIndex = 5, Value = true}, {MaterialIndex = 5, Value = false}}, ShapeKeys = {},
            ScalarControls = {}, VectorControls = {}, TextureOptions = {}}}
    for k, v in pairs(extra or {}) do it[k] = v end
    return it
end

local tests = {
    a_pack_item_becomes_a_whole_fit = function()
        local it = item('p.suit')
        local fit = Fits.pack(it, 1)
        same({fit.Outfit, fit.Pack, fit.Origin, fit.Mesh, fit.Image, fit.Variant, fit.Whole},
            {'Pack p.suit', 'Some Pack', 'custom', '/Game/P/V1.V1', '/Game/I/P.P', 1, true}, 'the fields')
        same(fit.Hidden, {7}, 'the variant\'s HiddenMats') eq(fit.Controls, it.UserConfigs, 'the controls')
        same(fit.Toggles, {[3] = false, [4] = true, [5] = false}, 'each toggle\'s default; an off one wins a slot')
        same(fit.Pieces, {}, 'no piece map') eq(Fits.pack(it, 3), nil, 'no third variant')
        eq(Fits.pack(item('q', {File = '~mods\\Q\\QDekcns.json'}), 1).Pack, 'Q', 'a name without the dot')
    end,
    a_whole_fit_shows_all_but_hidden_and_off_toggles = function()
        same(Fits.shows(Fits.pack(item('p.suit'), 1), 9), {[0] = true, [1] = true, [2] = true, [4] = true,
            [6] = true, [8] = true}, '3 and 5 off, 7 hidden')
        same(Fits.shows(Fits.pack(item('p.suit'), 2), 4), {[0] = true, [1] = true, [2] = true}, 'variant 2')
    end,
    a_hand_fit_keeps_its_piece_map = function()
        local hand = Fits.BY_ID.AiK_CH27_14595
        local fit = Fits.pack(item('AiK_CH27_14595'), 1)
        eq(fit.Pieces, hand.Pieces, 'pieces') eq(fit.Skin, hand.Skin, 'skin') eq(fit.Unknown, hand.Unknown)
        eq(fit.Pack, 'AiK', 'the hand fit\'s pack name') eq(fit.Whole, true, 'worn whole from Full outfit')
        local all = Fits.all({AiK_CH27_14595 = item('AiK_CH27_14595'), ['p.suit'] = item('p.suit'),
            hair = item('hair', {Slot = 'Hair'})})
        eq(all.AiK_CH27_14595.Mesh, '/Game/P/V1.V1', 'the pack fit wins the id')
        eq(all.AiK_CH46_xSH_14462, Fits.BY_ID.AiK_CH46_xSH_14462, 'a hand fit with no pack stays')
        ok(all['p.suit'] and not all.hair, 'suits only')
        Fits.use({AiK_CH27_14595 = item('AiK_CH27_14595')})
        local good, why = pcall(function()
            eq(Fits.piece('AiK_CH27_14595', 'Chest'), hand.Pieces[2], 'the fitting tabs keep the hand pieces')
            eq(Fits.get('AiK_CH27_14595').Whole, true, 'the pack fit through Fits.get')
        end)
        Fits.use(nil)
        ok(good, why)
        eq(Fits.get('AiK_CH27_14595'), hand, 'no catalogue: the hand fit')
    end,
    variant_one_is_worn_by_default = function()
        local all = Fits.all({['p.suit'] = item('p.suit')})
        eq(all['p.suit'].Variant, 1) eq(all['p.suit'].Mesh, '/Game/P/V1.V1')
    end,
    every_slot_named_once = function()
        for id, fit in pairs(Fits.BY_ID) do
            local count = SLOT_COUNT[id]
            ok(count, id .. ': no slot count in this test')
            local seen = {}
            local function take(index, what)
                ok(math.type(index) == 'integer' and index >= 0 and index < count, id .. ': ' .. what .. ' index ' ..
                    tostring(index))
                ok(not seen[index], ('%s: index %d named twice (%s and %s)'):format(id, index, tostring(seen[index]),
                    what))
                seen[index] = what
            end
            for index in pairs(fit.Skin) do take(index, 'skin') end
            for _, piece in ipairs(fit.Pieces) do
                for _, index in ipairs(piece.Materials) do take(index, piece.Name) end
            end
            for _, index in ipairs(fit.Unknown) do take(index, 'unknown') end
            for index = 0, count - 1 do ok(seen[index], ('%s: index %d named nowhere'):format(id, index)) end
        end
    end,
    slots_and_regions_are_known = function()
        for id, fit in pairs(Fits.BY_ID) do
            local used = {}
            for _, piece in ipairs(fit.Pieces) do
                ok(Slots.known(piece.Slot), id .. ': slot ' .. tostring(piece.Slot))
                ok(not used[piece.Slot], id .. ': two pieces in ' .. piece.Slot)
                used[piece.Slot] = true
                for _, slot in ipairs(piece.Occupies or {}) do ok(Slots.known(slot), id .. ': occupies ' .. slot) end
            end
            for _, regions in pairs(fit.Skin) do
                for _, region in ipairs(regions) do ok(Slots.IS_REGION[region], id .. ': region ' .. region) end
            end
            ok(fit.Mesh:match('^/Game/'), id .. ': mesh path')
            ok(fit.Image == nil or fit.Image:match('^/Game/'), id .. ': image path')
            ok(fit.Origin == nil or fit.Origin == 'original' or fit.Origin == 'custom', id .. ': origin')
        end
    end,
    kunoichi_skin_covers_each_region_once = function()
        local fit = Fits.get('AiK_CH46_xSH_14462')
        local covered = {}
        for _, regions in pairs(fit.Skin) do
            for _, region in ipairs(regions) do
                ok(not covered[region], region .. ' twice') covered[region] = true
            end
        end
        for _, region in ipairs(Slots.REGIONS) do ok(covered[region], region .. ' missing') end
    end,
    lookups = function()
        eq(Fits.piece('AiK_CH46_xSH_14462', 'Shoes').Name, 'Shadow heel boots')
        same(Fits.piece('AiK_CH27_14595', 'Chest').Materials[1], 15)
        eq(Fits.piece('AiK_CH27_14595', 'Mask'), nil) eq(Fits.get('nope'), nil) eq(Fits.piece('nope', 'Shoes'), nil)
        eq(Fits.piece('AiK_CH27_14595', 'BaseBody'), nil, 'BaseBody is a pseudo slot of every fit with Skin')
    end,
}
run('fits_test', tests)
