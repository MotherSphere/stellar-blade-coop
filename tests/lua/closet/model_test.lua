-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The menu's data model (closet/ui/model.lua): tabs, rows, tiles and the pure choice edits.
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end} -- dress.lua needs it to load
local Model = require('closet.ui.model')
local Slots = require('closet.slots')
local Fits = require('closet.fits')
local Dress = require('closet.dress')
local CnsImport = require('closet.cns_import')

local CH27, CH46 = 'AiK_CH27_14595', 'AiK_CH46_xSH_14462'

local function new(o)
    o = o or {}
    return Model.new({slots = Slots, fits = Fits, installed = o.installed or function() return true end,
        adult = o.adult, shapes = o.shapes})
end

local function slots_of(choices, fit)
    for _, c in ipairs(choices) do
        if c.fit == fit then
            local out = {}
            for _, s in ipairs(c.slots or {}) do out[#out + 1] = s end
            table.sort(out)
            return out
        end
    end
    return nil
end

local tests = {
    tabs_leave_out_the_adult_menu = function()
        local t = new().tabs()
        eq(#t, 9, 'tab count')
        for _, id in ipairs(t) do ok(id ~= 'intimate', 'intimate listed') end
        eq(t[1], 'full', 'first') eq(t[#t], 'weapon', 'last')
        local a = new({adult = true}).tabs()
        eq(#a, 10, 'adult count') eq(a[7], 'intimate', 'intimate place')
    end,

    colour_is_the_second_tab = function()
        eq(new().tabs()[2], 'colour', 'Colour right after Full outfit')
        eq(new({adult = true}).tabs()[2], 'colour', 'with the adult menu too')
        same({table.unpack(new({adult = true}).tabs(), 1, 10)},
            {'full', 'colour', 'head', 'torso', 'arms', 'hips', 'intimate', 'legs', 'body', 'weapon'}, 'the order')
    end,

    -- The fitting tabs (Head..Body and Intimate) are Beta; Full outfit, Colour and Weapon are not.
    fitting_tabs_carry_beta = function()
        local t = new({adult = true}).tabs()
        same(t.beta, {head = true, torso = true, arms = true, hips = true, intimate = true, legs = true, body = true},
            'the Beta tabs')
    end,

    the_colour_tab_lists_the_four_roles = function()
        same(new().rows('colour'), {{role = 'primary'}, {role = 'secondary'}, {role = 'accent'}, {role = 'glow'}},
            'Primary, Secondary, Accent, Glow')
    end,

    -- The Body tab: one row per shape name (closet/shape.lua's rows) right below the Body row; none without names.
    the_body_tab_lists_the_shape_rows_below_the_body = function()
        local names = {'Butt', 'Hips'}
        local rows = new({shapes = function() return names end}).rows('body')
        eq(rows[1].slot, 'BaseBody', 'the body choice first')
        same(rows[2], {morph = 'Butt'}, 'then the shape rows') same(rows[3], {morph = 'Hips'})
        eq(rows[4].slot, 'SkinSuit', 'then the other body slots')
        eq(#rows, #Slots.in_menu('body') + 2, 'one row per name')
        names = {}
        rows = new({shapes = function() return names end}).rows('body')
        eq(rows[2].slot, 'SkinSuit', 'no name: no shape row')
        eq(new().rows('body')[2].slot, 'SkinSuit', 'no shape layer: no shape row')
        for _, r in ipairs(new({shapes = function() return {'Butt'} end}).rows('torso')) do
            eq(r.morph, nil, 'other tabs list no shape row')
        end
    end,

    rows_mark_soon_and_empty = function()
        local m = new()
        local function state(tab, slot)
            for _, r in ipairs(m.rows(tab)) do if r.slot == slot then return r.state end end
        end
        eq(state('head', 'Face'), 'soon') eq(state('torso', 'Necklace'), 'empty')
        eq(state('torso', 'Chest'), 'pieces') eq(state('arms', 'Fingernails'), 'pieces')
        eq(#m.rows('torso'), #Slots.in_menu('torso'), 'one row per slot')
    end,

    full_tab_lists_outfits = function()
        local m = new({installed = function(f) return f == CH27 end})
        local rows = m.rows('full')
        eq(#rows, 4, 'rows: the outfits, Make preview pictures, then Reset Stellar Closet')
        same(rows[1], {whole = CH46, outfit = 'Kunoichi Shadow', pack = 'AiK', locked = true}, 'first by name')
        same(rows[2], {whole = CH27, outfit = 'Ocean Maid', pack = 'AiK', locked = false}, 'second')
        same(rows[3], {thumbs = true}, 'the Make preview pictures row after the outfits')
        same(rows[4], {reset = true}, 'the Reset row last')
    end,

    -- Every installed pack's suit (FitMeshType Body or none, EVE's) gets a row, the hand fits with them, by name.
    every_pack_suit_gets_a_row = function()
        local file = '~mods\\P\\p.dekcns.json'
        local text = '[{"UniqueFitID":"z.suit","DisplayName":"Zeta","FitMeshType":"Body","OutfitPaths":["/Game/Z.Z"]},'
            .. '{"UniqueFitID":"a.suit","DisplayName":"alpha","OutfitPaths":["/Game/A.A"]},'
            .. '{"UniqueFitID":"h.hair","DisplayName":"Aaa","FitMeshType":"Hair","OutfitPaths":["/Game/H.H"]},'
            .. '{"UniqueFitID":"d.suit","DisplayName":"Adam","CharacterID":"Adam","OutfitPaths":["/Game/D.D"]}]'
        local catalogue = {}
        CnsImport.merge(catalogue, CnsImport.parse(text, file).items, file)
        Fits.use(catalogue)
        local good, why = pcall(function()
            local rows = new({installed = function(f) return f ~= 'z.suit' end}).rows('full')
            eq(#rows, 6, 'four suits, Make preview pictures, Reset')
            same(rows[1], {whole = 'a.suit', outfit = 'alpha', pack = 'p', locked = false}, 'by name in any case')
            eq(rows[2].whole, CH46) eq(rows[3].whole, CH27)
            same(rows[4], {whole = 'z.suit', outfit = 'Zeta', pack = 'p', locked = true}, 'not installed: locked')
            ok(rows[5].thumbs and rows[6].reset, 'then the two rows')
        end)
        Fits.use(nil)
        ok(good, why)
    end,

    -- Shift Up's own suits (Origin original) come after the pack outfits, under the Original header.
    original_suits_sit_under_their_header = function()
        Fits.BY_ID.ZZ_ORIG = {Outfit = 'Original suit', Pack = 'Shift Up', Origin = 'original', Mesh = '/Game/O.O',
            Pieces = {}}
        Fits.BY_ID.ZZ_ORIG2 = {Outfit = 'Another original', Pack = 'Shift Up', Origin = 'original',
            Mesh = '/Game/O2.O2', Pieces = {}}
        local good, why = pcall(function()
            local rows = new().rows('full')
            eq(#rows, 7, 'two Custom suits, the header, two Original suits, the two rows')
            eq(rows[1].whole, CH46) eq(rows[2].whole, CH27)
            same(rows[3], {header = 'original'}, 'the header after the pack outfits')
            eq(rows[4].whole, 'ZZ_ORIG2', 'by name') eq(rows[5].whole, 'ZZ_ORIG')
            ok(rows[6].thumbs and rows[7].reset, 'then the two rows')
        end)
        Fits.BY_ID.ZZ_ORIG, Fits.BY_ID.ZZ_ORIG2 = nil, nil
        ok(good, why)
        for _, r in ipairs(new().rows('full')) do eq(r.header, nil, 'no Original suit: no header') end
    end,

    -- A whole outfit with no piece map comes off whole when a piece is picked.
    a_whole_pack_fit_comes_off_for_a_piece = function()
        Fits.PACKS = {['p.suit'] = {Outfit = 'P', Pack = 'p', Origin = 'custom', Mesh = '/Game/P.P', Whole = true,
            Pieces = {}}}
        local good, why = pcall(function()
            local m = new()
            same(m.choose(m.whole('p.suit'), 'Chest', CH27), {{fit = CH27, slots = {'Chest'}}}, 'only the piece')
        end)
        Fits.use(nil)
        ok(good, why)
    end,

    basebody_lists_fits_with_skin = function()
        local m = new({installed = function(f) return f == CH27 end})
        local state
        for _, r in ipairs(m.rows('body')) do if r.slot == 'BaseBody' then state = r.state end end
        eq(state, 'pieces', 'a fit with Skin gives the Body row tiles')
        local t = m.tiles('BaseBody')
        eq(#t, 3, 'None, then each fit with Skin')
        same(t[1], {none = true}, 'None: the body rule picks the body')
        same(t[2], {fit = CH27, name = 'Ocean Maid', outfit = 'Ocean Maid', pack = 'AiK', locked = false}, 'Ocean Maid')
        eq(t[3].fit, CH46) eq(t[3].name, 'Kunoichi Shadow') eq(t[3].locked, true, 'not installed: locked')
        eq(m.piece(CH46, 'BaseBody').Name, 'Kunoichi Shadow', 'the body pseudo piece')
        eq(m.piece(CH46, 'Gloves').Name, 'Long gloves', 'a real piece')
    end,

    choose_sets_and_clears_basebody = function()
        local m = new()
        local start = {{fit = CH46, slots = {'Gloves'}}}
        local out = m.choose(start, 'BaseBody', CH27)
        eq(m.worn(out, 'BaseBody'), CH27) eq(m.worn(out, 'Gloves'), CH46)
        eq(assert(Dress.plan(out)).body.fit, CH27, 'the picked body')
        out = m.choose(out, 'BaseBody', CH46)
        eq(m.worn(out, 'BaseBody'), CH46) eq(#out, 1, "Ocean Maid's choice goes with its body")
        same(slots_of(out, CH46), {'BaseBody', 'Gloves'})
        out = m.choose(out, 'BaseBody', nil)
        same(out, {{fit = CH46, slots = {'Gloves'}}}, 'None: no body picked')
        same(start, {{fit = CH46, slots = {'Gloves'}}}, 'input untouched')
        -- A whole outfit keeps its pieces when its body is picked.
        out = m.choose(m.whole(CH27), 'BaseBody', CH27)
        eq(m.worn(out, 'Chest'), CH27) eq(m.worn(out, 'BaseBody'), CH27)
        eq(assert(Dress.plan(out)).body.fit, CH27)
    end,

    tiles_start_with_none_and_lock_missing_packs = function()
        local m = new({installed = function(f) return f == CH27 end})
        local t = m.tiles('Chest')
        eq(#t, 3, 'tiles')
        same(t[1], {none = true}, 'none')
        eq(t[2].fit, CH27) eq(t[2].name, 'Maid top') eq(t[2].outfit, 'Ocean Maid') eq(t[2].pack, 'AiK')
        eq(t[2].locked, false) eq(t[3].fit, CH46) eq(t[3].locked, true)
        eq(m.tiles('Legs')[2].off, true, 'stockings off by default')
        same(m.tiles('Gloves')[3].covers, {'ArmUpper', 'Forearm', 'Hand'}, 'covers')
        same(m.tiles('UndergarmentTop')[2].also, {'UndergarmentBottom'}, 'also')
        eq(#m.tiles('Face'), 1, 'none only')
    end,

    choose_replaces_a_slot_across_outfits = function()
        local m = new()
        local start = {{fit = CH27, slots = {'Chest', 'Shoes'}}}
        eq(m.worn(start, 'Chest'), CH27)
        local out = m.choose(start, 'Chest', CH46)
        eq(m.worn(out, 'Chest'), CH46) eq(m.worn(out, 'Shoes'), CH27)
        same(slots_of(out, CH27), {'Shoes'}) same(slots_of(out, CH46), {'Chest'})
        same(start, {{fit = CH27, slots = {'Chest', 'Shoes'}}}, 'input untouched')
        ok(Dress.plan(out), 'plans')
    end,

    choose_expands_a_whole_outfit = function()
        local m = new()
        local start = m.whole(CH27)
        same(start, {{fit = CH27}}, 'whole')
        eq(m.worn(start, 'Chest'), CH27) eq(m.worn(start, 'Legs'), nil, 'Off piece not worn')
        local out = m.choose(start, 'Chest', CH46)
        eq(m.worn(out, 'Collar'), CH27) eq(m.worn(out, 'Chest'), CH46) eq(m.worn(out, 'Legs'), nil)
        ok(out[1].slots, 'expanded')
        ok(Dress.plan(out), 'plans')
        same(start, {{fit = CH27}}, 'input untouched')
    end,

    choose_frees_occupied_slots = function()
        local m = new()
        -- CH27's Leotard (UndergarmentTop) occupies UndergarmentBottom.
        local out = m.choose({{fit = CH46, slots = {'Chest'}}}, 'UndergarmentTop', CH27)
        eq(m.worn(out, 'UndergarmentTop'), CH27)
        local worn = {{fit = CH27, slots = {'UndergarmentTop', 'Shoes'}}}
        -- Picking a piece for the occupied slot takes the Leotard off.
        local off = m.choose(worn, 'UndergarmentBottom', nil)
        eq(m.worn(off, 'UndergarmentTop'), nil) eq(m.worn(off, 'Shoes'), CH27)
        ok(Dress.plan(off), 'plans')
        -- Picking the Leotard frees the slot it occupies in another outfit.
        local both = m.choose({{fit = CH46, slots = {'Chest'}}, {fit = CH27, slots = {'Shoes'}}}, 'UndergarmentTop',
            CH27)
        eq(m.worn(both, 'UndergarmentTop'), CH27) eq(m.worn(both, 'Chest'), CH46)
        ok(Dress.plan(both), 'plans')
    end,

    none_takes_a_slot_off = function()
        local m = new()
        local out = m.choose({{fit = CH27, slots = {'Chest', 'Shoes'}}}, 'Chest', nil)
        eq(m.worn(out, 'Chest'), nil) eq(m.worn(out, 'Shoes'), CH27)
        same(m.choose({{fit = CH27, slots = {'Chest'}}}, 'Chest', nil), {}, 'empty choices dropped')
        local w = m.choose(m.whole(CH27), 'Chest', nil)
        eq(m.worn(w, 'Chest'), nil) eq(m.worn(w, 'Collar'), CH27)
    end,

    -- User decision: Original (game) suits are worn whole only, from Full outfit; the region tabs and the Body tab list
    -- Custom pieces only.
    original_suits_are_listed_in_full_outfit_only = function()
        Fits.BY_ID.ZZ_ORIG = {Outfit = 'Original suit', Pack = 'Shift Up', Origin = 'original', Mesh = '/Game/O.O',
            Skin = {[0] = {'HeadNeck'}}, Pieces = {{Slot = 'Chest', Name = 'Suit top', Materials = {1}},
                {Slot = 'Necklace', Name = 'Suit necklace', Materials = {2}}}}
        local good, why = pcall(function()
            local m = new({adult = true})
            local full = {}
            for _, r in ipairs(m.rows('full')) do if r.whole then full[r.whole] = true end end
            ok(full.ZZ_ORIG and full[CH27], 'Full outfit lists the Original suit with the Custom ones')
            local n = 0
            for _, tab in ipairs(m.tabs()) do
                for _, r in ipairs(tab ~= 'full' and m.rows(tab) or {}) do
                    for _, t in ipairs(r.slot and m.tiles(r.slot) or {}) do -- The Colour tab's rows have no tiles.
                        ok(t.fit ~= 'ZZ_ORIG', tab .. ' ' .. r.slot .. ': an Original tile')
                        n = n + (t.fit and 1 or 0)
                    end
                end
            end
            ok(n > 0, 'Custom tiles listed')
            eq(m.tiles('Chest')[2].fit, CH27, 'the Custom tops stay')
            local state
            for _, r in ipairs(m.rows('torso')) do if r.slot == 'Necklace' then state = r.state end end
            eq(state, 'empty', 'a slot only the Original suit fills has no pieces')
        end)
        Fits.BY_ID.ZZ_ORIG = nil
        ok(good, why)
    end,

    choose_always_plans = function()
        local m = new()
        local starts = {m.whole(CH27), m.whole(CH46),
            {{fit = CH27, slots = {'Chest'}}, {fit = CH46, slots = {'Gloves'}}}}
        local n = 0
        for _, start in ipairs(starts) do
            for _, slot in ipairs(Slots.LIST) do
                for _, tile in ipairs(m.tiles(slot[1])) do
                    local out = m.choose(start, slot[1], tile.fit)
                    n = n + 1
                    if #out > 0 then
                        local plan, why = Dress.plan(out)
                        ok(plan, ('%s %s: %s'):format(slot[1], tostring(tile.fit), tostring(why)))
                    end
                end
            end
        end
        ok(n > 0, 'ran')
    end,
}
run('model_test', tests)
