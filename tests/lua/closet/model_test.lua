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

-- A pack item for Ocean Maid's id (its hand map knows slots 40 and 41 as the leotard) with its toggles and the piece
-- hints closet/cns_import.lua guesses from their names.
local function maid_item(toggles)
    local hints = {}
    for _, t in ipairs(toggles) do
        hints[#hints + 1] = {MaterialIndex = t.MaterialIndex, Name = t.DisplayName,
            Slot = CnsImport.piece_slot(t.DisplayName)}
    end
    return {UniqueFitID = CH27, DisplayName = 'Ocean Maid', Slot = 'FullOutfit', File = '~mods\\AiK\\m.dekcns.json',
        Variants = {{Mesh = '/Game/M.M', HiddenMats = {}, Materials = {}, Parameters = {}},
            {Mesh = '/Game/M2.M2', HiddenMats = {}, Materials = {}, Parameters = {}}},
        PieceHints = hints, UserConfigs = {MaterialToggles = toggles}}
end

local tests = {
    -- The options page: the outfit's name, Variant (two or more), then a row per section, each followed by its pieces.
    -- A piece's section: its hand map piece's slot, else its piece hint's, else a word of its name, else Other.
    options_rows_group_toggles_in_sections = function()
        Fits.use({[CH27] = maid_item({
            {DisplayName = 'Bag', MaterialIndex = 39, Value = true},
            {DisplayName = 'Long boots', MaterialIndex = 35, Value = true},
            {DisplayName = 'Boots lining', MaterialIndex = 36, Value = true, ControlledBy = 'Long boots'},
            {DisplayName = 'Skin', MaterialIndex = 14, Value = true},
            {DisplayName = 'Vinyl', MaterialIndex = 40, Value = false},
            {DisplayName = 'Jacket', MaterialIndex = 3, Value = true},
            {DisplayName = 'Jacket again', MaterialIndex = 3, Value = true}})})
        local good, why = pcall(function()
            local rows = new().options(CH27)
            same(rows, {
                {header = 'Ocean Maid'}, {variant = true},
                {section = 'BaseBody', toggles = {14}}, {toggle = 14, name = 'Skin', section = 'BaseBody', depth = 1},
                {section = 'UndergarmentTop', toggles = {40}},
                {toggle = 40, name = 'Vinyl', section = 'UndergarmentTop', depth = 1},
                {section = 'Shoes', toggles = {35}}, {toggle = 35, name = 'Long boots', section = 'Shoes', depth = 1},
                {section = 'Outerwear', toggles = {3}}, {toggle = 3, name = 'Jacket', section = 'Outerwear', depth = 1},
                {section = 'Other', toggles = {39}}, {toggle = 39, name = 'Bag', section = 'Other', depth = 1},
                {reset_fit = true},
            }, 'sections in slot order, Other last; no row for the follower or a second toggle on slot 3; '
                .. 'a piece is a child of its section (depth 1)')
            same(new().options(CH46), {}, 'a hand fit with no pack controls: no page')
        end)
        Fits.use(nil)
        ok(good, why)
    end,
    -- The open piece's controls below it (its follower's slot too): finishes, colours (a Custom one's channels per
    -- Sliders), numbers; the controls of a slot no piece has at the end of Other; the Shape section; Reset this outfit.
    a_piece_opens_its_controls_and_shape_keys_close_the_page = function()
        local item = maid_item({
            {DisplayName = 'Long boots', MaterialIndex = 35, Value = true},
            {DisplayName = 'Boots lining', MaterialIndex = 36, Value = true, ControlledBy = 'Long boots'}})
        item.Variants[2] = nil
        item.UserConfigs.VectorControls = {
            {DisplayName = 'Boot colour', Description = 'Leather', MaterialIndex = 35, Value = {1, 1, 1, 1},
                Sliders = {true, true, true, true}},
            {DisplayName = 'Lining colour', MaterialIndex = 36, Value = {1, 1, 1, 1}},
            {DisplayName = 'Follower', MaterialIndex = 36, Value = {1, 1, 1, 1}, ControlledBy = 'Lining colour'},
            {DisplayName = 'Glow', MaterialIndex = 50, Value = {1, 1, 1, 1}}}
        item.UserConfigs.ScalarControls = {{DisplayName = 'Shine', MaterialIndex = 35, Value = 0}}
        item.UserConfigs.TextureOptions = {{DisplayName = 'Finish', MaterialIndex = 36, Textures = {}, Value = 0}}
        item.UserConfigs.ShapeKeys = {{DisplayName = 'Hips', Min = -1, Max = 1, Value = 0}}
        Fits.use({[CH27] = item})
        local good, why = pcall(function()
            local boots = {toggle = 35, name = 'Long boots', section = 'Shoes', controls = true, depth = 1}
            local tail = {{section = 'Other', toggles = {}}, {colour = 4, name = 'Glow', depth = 1},
                {section = 'Shape', toggles = {}}, {shape = 1, name = 'Hips', depth = 1}, {reset_fit = true}}
            same(new().options(CH27), {{header = 'Ocean Maid'}, {section = 'Shoes', toggles = {35}}, boots,
                table.unpack(tail)}, 'closed: one variant, no Variant row')
            same(new().options(CH27, 35, function(n) return n == 1 end), {{header = 'Ocean Maid'},
                {section = 'Shoes', toggles = {35}}, boots,
                {colour = 1, name = 'Boot colour', desc = 'Leather', depth = 2, of = 'Long boots'},
                {channel = 1, c = 'r', depth = 3}, {channel = 1, c = 'g', depth = 3},
                {channel = 1, c = 'b', depth = 3}, {channel = 1, c = 'a', depth = 3},
                {number = 1, name = 'Shine', depth = 2, of = 'Long boots'},
                {finish = 1, name = 'Finish', depth = 2, of = 'Long boots'},
                {colour = 2, name = 'Lining colour', depth = 2, of = 'Long boots'}, table.unpack(tail)},
                'open: its slot, then its follower\'s; Boot colour is Custom; each row its depth, a control its piece')
        end)
        Fits.use(nil)
        ok(good, why)
    end,

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
        eq(#rows, 3, 'rows: the outfits, then Reset Stellar Closet')
        same(rows[1], {whole = CH46, outfit = 'Kunoichi Shadow', pack = 'AiK', locked = true}, 'first by name')
        same(rows[2], {whole = CH27, outfit = 'Ocean Maid', pack = 'AiK', locked = false}, 'second')
        same(rows[3], {reset = true}, 'the Reset row last')
    end,

    -- With presets: Save look as preset, each preset (a gone outfit's greyed), the filter row, then the outfits, each
    -- with its favourite mark; the filter on Favourites lists the favourites only.
    favourites_filter_the_list = function()
        local favs, only = {[CH27] = true}, 'all'
        local presets = {is_fav = function(f) return favs[f] == true end,
            list = function() return {{n = 1, fit = CH27, variant = 1, gone = false},
                {n = 3, name = 'Old', fit = 'gone.suit', variant = 2, gone = true}} end}
        local m = Model.new({slots = Slots, fits = Fits, installed = function() return true end, presets = presets,
            filter = function() return only end})
        local rows = m.rows('full')
        same(rows[1], {save_preset = true}, 'Save look as preset first')
        same(rows[2], {preset = 1, fit = CH27, locked = false}, 'preset 1')
        same(rows[3], {preset = 3, name = 'Old', fit = 'gone.suit', locked = true}, 'a gone outfit: greyed')
        same(rows[4], {filter = true}, 'the filter row')
        same(rows[5], {whole = CH46, outfit = 'Kunoichi Shadow', pack = 'AiK', locked = false}, 'not a favourite')
        same(rows[6], {whole = CH27, outfit = 'Ocean Maid', pack = 'AiK', locked = false, fav = true}, 'a favourite')
        eq(#rows, 7, 'then Reset')
        only = 'favourites'
        rows = m.rows('full')
        eq(rows[5].whole, CH27, 'Favourites: the favourite only')
        ok(rows[6].reset, 'then Reset')
        eq(#rows, 6, 'no other outfit')
    end,

    -- The filter on Original lists Shift Up's own suits only, under their header; on Custom, the pack and hand
    -- outfits only, with no header.
    the_filter_lists_original_or_custom_suits = function()
        Fits.BY_ID.ZZ_ORIG = {Outfit = 'Original suit', Pack = 'Shift Up', Origin = 'original', Mesh = '/Game/O.O',
            Pieces = {}}
        local show = 'original'
        local presets = {is_fav = function() return false end, list = function() return {} end}
        local good, why = pcall(function()
            local m = Model.new({slots = Slots, fits = Fits, installed = function() return true end,
                presets = presets, filter = function() return show end})
            local rows = m.rows('full')
            same(rows[2], {filter = true}, 'the filter row')
            same(rows[3], {header = 'original'}, 'Original: the header')
            eq(rows[4].whole, 'ZZ_ORIG', 'the Original suit') ok(rows[5].reset, 'then Reset')
            eq(#rows, 5, 'no Custom suit')
            show = 'custom'
            rows = m.rows('full')
            eq(rows[3].whole, CH46) eq(rows[4].whole, CH27)
            ok(rows[5].reset, 'Custom: no header, no Original suit')
            eq(#rows, 5, 'the two Custom suits only')
        end)
        Fits.BY_ID.ZZ_ORIG = nil
        ok(good, why)
    end,

    -- With pictures (coop closet thumbs given), Clear preview pictures is the row before Reset Stellar Closet.
    clear_preview_pictures_comes_before_reset = function()
        local rows = Model.new({slots = Slots, fits = Fits, installed = function() return true end, pictures = true})
            .rows('full')
        eq(rows[#rows - 2].whole, CH27, 'the last outfit')
        same(rows[#rows - 1], {clear_thumbs = true}, 'then Clear preview pictures')
        ok(rows[#rows].reset, 'Reset Stellar Closet last')
        for _, r in ipairs(new().rows('full')) do eq(r.clear_thumbs, nil, 'no pictures: no Clear row') end
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
            eq(#rows, 5, 'four suits, Reset')
            same(rows[1], {whole = 'a.suit', outfit = 'alpha', pack = 'p', locked = false}, 'by name in any case')
            eq(rows[2].whole, CH46) eq(rows[3].whole, CH27)
            same(rows[4], {whole = 'z.suit', outfit = 'Zeta', pack = 'p', locked = true}, 'not installed: locked')
            ok(rows[5].reset, 'then Reset')
        end)
        Fits.use(nil)
        ok(good, why)
    end,

    -- installed loads the outfit's mesh: a Full row asks it only when its locked state is read, once.
    full_rows_ask_installed_only_when_read = function()
        local asked = {}
        local rows = new({installed = function(f) asked[#asked + 1] = f; return f ~= CH27 end}).rows('full')
        eq(#asked, 0, 'listing the rows loads no mesh')
        for _, row in ipairs(rows) do
            if row.whole == CH27 then
                eq(row.locked, true, 'not installed: locked') eq(row.locked, true, 'again')
            end
        end
        same(asked, {CH27}, 'asked once, for the row read')
    end,

    -- Shift Up's own suits (Origin original) come after the pack outfits, under the Original header.
    original_suits_sit_under_their_header = function()
        Fits.BY_ID.ZZ_ORIG = {Outfit = 'Original suit', Pack = 'Shift Up', Origin = 'original', Mesh = '/Game/O.O',
            Pieces = {}}
        Fits.BY_ID.ZZ_ORIG2 = {Outfit = 'Another original', Pack = 'Shift Up', Origin = 'original',
            Mesh = '/Game/O2.O2', Pieces = {}}
        local good, why = pcall(function()
            local rows = new().rows('full')
            eq(#rows, 6, 'two Custom suits, the header, two Original suits, Reset')
            eq(rows[1].whole, CH46) eq(rows[2].whole, CH27)
            same(rows[3], {header = 'original'}, 'the header after the pack outfits')
            eq(rows[4].whole, 'ZZ_ORIG2', 'by name') eq(rows[5].whole, 'ZZ_ORIG')
            ok(rows[6].reset, 'then Reset')
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
