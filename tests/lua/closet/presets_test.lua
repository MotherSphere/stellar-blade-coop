-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Presets and favourites (closet/presets.lua) over the real options layer (closet/options.lua), a fake dress and fake
-- stores: a preset keeps the worn outfit, its variant and its values; wear puts them back; a preset of a gone outfit
-- stays in the file and is greyed; coop closet preset and coop closet favourite.
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end} -- closet/commands.lua's dress needs it to load
local Fits = require('closet.fits')
local Options = require('closet.options')
local Presets = require('closet.presets')

-- A pack suit: two variants; Jacket (3) and Boots (4) on, a colour on slot 3.
local function suit(id)
    return {UniqueFitID = id, DisplayName = 'Suit ' .. id, Slot = 'FullOutfit', File = '~mods\\P\\p.dekcns.json',
        Variants = {{Mesh = '/Game/P/V1.V1', HiddenMats = {}, Materials = {}, Parameters = {}},
            {Mesh = '/Game/P/V2.V2', HiddenMats = {}, Materials = {}, Parameters = {}}},
        PieceHints = {},
        UserConfigs = {MaterialToggles = {
            {DisplayName = 'Jacket', MaterialIndex = 3, Value = true},
            {DisplayName = 'Boots', MaterialIndex = 4, Value = true}},
            VectorControls = {{DisplayName = 'Tint', MaterialIndex = 3, ParamName = 'Tint', Value = {1, 1, 1, 1}}}}}
end
local function store()
    local s = {}
    s.save = function(l) s.file = l; return true end
    s.load = function() return s.file end
    s.clear = function() s.file = nil end
    return s
end
local function rig()
    local r = {log = {}, worn = {}, choices = {{fit = 's'}}, ostore = store(), pstore = store()}
    r.dress = {plan = function() end, again = function() return true end, reshow = function() return true end,
        loads = function() return true end, choices = function() return r.choices end,
        installed = function(fit) return Fits.get(fit) ~= nil end,
        wear = function(c) r.worn[#r.worn + 1] = c; return true, 'closet: worn' end}
    local log = function(m) r.log[#r.log + 1] = m end
    r.options = Options.new({store = r.ostore, dress = r.dress, log = log})
    r.new = function() return Presets.new({store = r.pstore, options = r.options, dress = r.dress, log = log}) end
    r.p = r.new()
    return r
end
local function with_suit(f)
    Fits.use({s = suit('s'), t = suit('t')})
    local good, why = pcall(f)
    Fits.use(nil)
    Fits.CHOSEN = {}
    ok(good, why)
end

run('presets', {
    save_names_preset_n_and_wear_restores_outfit_variant_and_values = function()
        with_suit(function()
            local r = rig()
            r.options.set_variant('s', 2)
            r.options.set('s', 2, 'toggle:4', false)
            r.options.set('s', 2, 'colour:1', {R = 0.5, G = 0.25, B = 1, A = 1, custom = true})
            local n = r.p.save()
            eq(n, 1, 'the first preset is 1')
            eq(r.p.save('Night out'), 2, 'the next is 2')
            local list = r.p.list()
            eq(#list, 2, 'two presets')
            eq(list[1].n, 1, 'number') eq(list[1].name, nil, 'no name: the menu shows Preset 1')
            eq(list[1].fit, 's', 'outfit') eq(list[1].variant, 2, 'variant') eq(list[1].gone, false, 'not gone')
            eq(list[2].name, 'Night out', 'named')
            -- Another look, then the preset back.
            r.options.set_variant('s', 1)
            r.options.reset('s')
            r.choices = {{fit = 't'}}
            local good, line = r.p.wear(1)
            ok(good, line)
            same(r.worn[#r.worn], {{fit = 's'}}, 'the outfit worn whole')
            eq(r.options.variant('s'), 2, 'its variant')
            eq(r.options.get('s', 2, 'toggle:4'), false, 'its toggle')
            same(r.options.get('s', 2, 'colour:1'), {R = 0.5, G = 0.25, B = 1, A = 1, custom = true}, 'its colour')
            eq(r.options.get('s', 2, 'toggle:3'), true, 'a value it did not change: the pack\'s')
            -- Kept across Lua loads.
            local again = r.new().list()
            eq(#again, 2, 'read back') eq(again[2].name, 'Night out', 'name read back')
            eq(again[1].variant, 2, 'variant read back')
            -- A wear with another put (the menu's preview).
            local put
            r.p.wear(2, function(c) put = c; return true end)
            same(put, {{fit = 's'}}, 'the given put wears it')
            eq(#r.worn, 1, 'not through the dress')
        end)
    end,
    a_failed_wear_gives_the_outfit_its_options_back = function()
        with_suit(function()
            local r = rig()
            r.options.set_variant('s', 2)
            r.options.set('s', 2, 'toggle:4', false)
            r.p.save()
            -- Other options before the wear: variant 1, another value on variant 2.
            r.options.reset('s')
            r.options.set('s', 2, 'toggle:3', false)
            r.options.set_variant('s', 1)
            local before = r.options.words('s', 2)
            r.dress.wear = function() return false, 'no EVE in the world' end
            local good, why = r.p.wear(1)
            eq(good, false, 'not worn') eq(why, 'no EVE in the world', 'the dress says why')
            eq(r.options.variant('s'), 1, 'the variant from before')
            same(r.options.words('s', 2), before, 'the values from before')
            eq(r.options.get('s', 2, 'toggle:4'), true, 'not the preset\'s value')
        end)
    end,
    save_needs_one_whole_outfit = function()
        with_suit(function()
            local r = rig()
            r.choices = {{fit = 's', slots = {'Chest'}}}
            local n, why = r.p.save()
            eq(n, nil, 'no preset') ok(why:find('whole outfit', 1, true), why)
            r.choices = nil
            eq((r.p.save()), nil, 'nothing worn: no preset')
            eq(r.pstore.file, nil, 'nothing written')
        end)
    end,
    delete_and_rename_keep_the_other_numbers = function()
        with_suit(function()
            local r = rig()
            r.p.save(); r.p.save(); r.p.save()
            ok(r.p.delete(2))
            eq(#r.p.list(), 2, 'one gone')
            eq(r.p.save(), 2, 'a new one takes the free number')
            ok(r.p.rename(3, 'Beach'))
            eq(r.p.list()[3].name, 'Beach', 'renamed')
            ok(r.p.rename(3, nil))
            eq(r.p.list()[3].name, nil, 'no name: Preset 3 again')
            eq((r.p.delete(9)), false, 'no preset 9')
            eq((r.p.rename(9, 'x')), false, 'no preset 9 to rename')
            eq((r.p.wear(9)), false, 'no preset 9 to wear')
        end)
    end,
    rename_by_command = function()
        with_suit(function()
            local r = rig()
            local cmd = require('closet.commands').new({presets = r.p, dress = r.dress})
            local good, line = cmd.closet('preset', 'save')
            ok(good, line)
            ok(cmd.closet('preset', 'rename', '1', 'Night', 'out'))
            eq(r.p.list()[1].name, 'Night out', 'the words after the number are the name')
            ok(cmd.closet('preset', 'save', 'Day'))
            eq(r.p.list()[2].name, 'Day', 'save takes a name')
            ok(cmd.closet('preset', 'wear', '2'))
            same(r.worn[1], {{fit = 's'}}, 'preset wear wears it through the dress')
            ok(cmd.closet('preset', 'delete', '2'))
            eq(#r.p.list(), 1, 'deleted')
            ok(cmd.closet('favourite', 's'))
            eq(r.p.is_fav('s'), true, 'coop closet favourite marks it')
            eq((cmd.closet('preset', 'wear', 'x')), false, 'not a number')
            eq((cmd.closet('preset')), false, 'no word')
            eq((cmd.closet('favourite')), false, 'no fit')
        end)
    end,
    a_preset_of_a_gone_outfit_is_kept_and_greyed = function()
        with_suit(function()
            local r = rig()
            r.p.save()
            local file = r.pstore.file
            Fits.use({t = suit('t')}) -- The pack of s is removed.
            local p = r.new()
            local list = p.list()
            eq(#list, 1, 'kept')
            eq(list[1].gone, true, 'greyed')
            local good, why = p.wear(1)
            eq(good, false, 'not worn') ok(why:find('not installed', 1, true), why)
            eq(#r.worn, 0, 'nothing worn')
            eq(r.pstore.file, file, 'the file keeps it')
        end)
    end,
    -- Any UniqueFitID: its file word is Fits.word's, read back as the same id in a favourite and in a preset.
    any_pack_id_survives_the_file = function()
        local odd = '1 name=Ocean Maid:v2,(Shadow)+\195\136ve%01\t'
        Fits.use({[odd] = suit(odd)})
        local good, why = pcall(function()
            local r = rig()
            r.choices = {{fit = odd}}
            ok(r.p.fav(odd))
            eq(r.p.save('Look'), 1)
            local p = r.new()
            eq(p.is_fav(odd), true, 'the favourite read back')
            local list = p.list()
            eq(#list, 1) eq(list[1].fit, odd, 'the preset\'s outfit') eq(list[1].name, 'Look') eq(list[1].gone, false)
        end)
        Fits.use(nil)
        Fits.CHOSEN = {}
        ok(good, why)
    end,
    favourites_toggle_and_stay = function()
        with_suit(function()
            local r = rig()
            eq(r.p.is_fav('s'), false, 'not yet')
            ok(r.p.fav('s'))
            eq(r.p.is_fav('s'), true, 'marked')
            r.p.save('Look')
            local p = r.new()
            eq(p.is_fav('s'), true, 'read back')
            eq(p.list()[1].name, 'Look', 'presets and favourites in one file')
            ok(p.fav('s'))
            eq(p.is_fav('s'), false, 'toggled off')
            eq(r.new().is_fav('s'), false, 'saved off')
        end)
    end,
})
