-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The fit maps (closet/fits.lua): each names every material slot of its mesh exactly once (skin, a piece or unknown),
-- in known slots and regions, one piece a slot; and the lookups.
local run = dofile('tests/lua/closet/run.lua')
local Fits = require('closet.fits')
local Slots = require('closet.slots')

-- Material slot counts of the two meshes, from the spike's slot dump (25 Nov 2026).
local SLOT_COUNT = {AiK_CH27_14595 = 48, AiK_CH46_xSH_14462 = 44}

local tests = {
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
