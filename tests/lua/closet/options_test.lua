-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The options layer (closet/options.lua) over a fake dress and a fake store: piece toggles per outfit and variant
-- (followers copy their leader), the chosen variant, values kept only where they differ from the pack, saved values
-- of a gone outfit, variant or slot ignored and said once, the tick that shows a change on the worn look.
local run = dofile('tests/lua/closet/run.lua')
local Fits = require('closet.fits')
local Options = require('closet.options')

-- A pack suit: two variants; Jacket (3, on) leads Lining (5, off by its own default), Boots (4, on), Mystery (6, off).
local function suit(id)
    return {UniqueFitID = id, DisplayName = 'Suit ' .. id, Slot = 'FullOutfit', File = '~mods\\P\\p.dekcns.json',
        Variants = {{Mesh = '/Game/P/V1.V1', HiddenMats = {}, Materials = {}, Parameters = {}, Name = 'Plain'},
            {Mesh = '/Game/P/V2.V2', HiddenMats = {2}, Materials = {}, Parameters = {}}},
        PieceHints = {},
        UserConfigs = {MaterialToggles = {
            {DisplayName = 'Jacket', MaterialIndex = 3, Value = true},
            {DisplayName = 'Lining', MaterialIndex = 5, Value = false, ControlledBy = 'Jacket'},
            {DisplayName = 'Boots', MaterialIndex = 4, Value = true},
            {DisplayName = 'Mystery', MaterialIndex = 6, Value = false}}}}
end

local function rig(line)
    -- fail: what again and reshow give back (closet/dress.lua's apply gives nil and why when it fails); broken: the
    -- mesh paths that do not load (dress.loads).
    local r = {file = line, log = {}, again = 0, reshown = 0, plan = nil, fail = nil, broken = {}}
    r.store = {save = function(l) r.file = l; return true end, load = function() return r.file end,
        clear = function() r.file = nil end}
    r.dress = {plan = function() return r.plan end,
        again = function() r.again = r.again + 1; if r.fail then return nil, r.fail end return true end,
        reshow = function() r.reshown = r.reshown + 1; if r.fail then return nil, r.fail end return true end,
        loads = function(path) return not r.broken[path] end}
    r.new = function()
        return Options.new({store = r.store, dress = r.dress, log = function(m) r.log[#r.log + 1] = m end})
    end
    r.o = r.new()
    return r
end
local function count(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then n = n + 1 end end
    return n
end
-- f() with the suit s in the catalogue, which goes again after.
local function with_suit(f)
    Fits.use({s = suit('s')})
    local good, why = pcall(f)
    Fits.use(nil)
    Fits.CHOSEN = {}
    ok(good, why)
end

local tests = {
    a_follower_copies_its_leader = function()
        with_suit(function()
            local r = rig()
            same(r.o.toggles().s, {[3] = true, [4] = true, [5] = true, [6] = false}, 'Lining copies Jacket at once')
            ok(r.o.set('s', 1, 'toggle:3', false))
            same(r.o.toggles().s, {[3] = false, [4] = true, [5] = false, [6] = false}, 'and follows it off')
        end)
    end,
    values_are_saved_per_fit_and_variant_and_only_when_changed = function()
        with_suit(function()
            local r = rig()
            ok(r.o.set('s', 1, 'toggle:4', true))
            eq(r.file, nil, 'the pack value: nothing kept')
            ok(r.o.set('s', 1, 'toggle:4', false))
            eq(r.file, 's 1 toggle:4=off', 'one value kept')
            eq(r.o.get('s', 1, 'toggle:4'), false) eq(r.o.get('s', 2, 'toggle:4'), true, 'variant 2 has its own')
            ok(r.o.set_variant('s', 2))
            eq(r.o.variant('s'), 2) eq(Fits.get('s').Mesh, '/Game/P/V2.V2', 'the fit wears variant 2')
            eq(r.o.toggles().s[4], true, 'variant 2\'s values')
            local again = r.new()
            eq(again.variant('s'), 2, 'read back') eq(again.get('s', 1, 'toggle:4'), false, 'read back')
            ok(r.o.set('s', 1, 'toggle:4', true))
            ok(r.o.set_variant('s', 1))
            eq(r.file, nil, 'every value the pack\'s again: the file goes')
            local good, why = r.o.set('s', 1, 'toggle:99', true)
            eq(good, false) ok(why:find('no toggle on slot 99', 1, true), why)
            good, why = r.o.set_variant('s', 3)
            eq(good, false) ok(why:find('no variant 3', 1, true), why)
        end)
    end,
    a_saved_value_for_a_gone_slot_is_ignored_once = function()
        local r = rig('s 1 toggle:9=on\tgone 1 toggle:3=off\ts 1 toggle:4=off\ts variant=7')
        with_suit(function()
            r.o.tick() r.o.tick()
            same(r.o.toggles().s, {[3] = true, [4] = false, [5] = true, [6] = false}, 'slot 9 ignored, slot 4 kept')
            eq(r.o.variant('s'), 1, 'a gone variant: the first')
            Fits.use({s = suit('s')}) -- coop closet rescan
            r.o.tick()
            eq(count(r.log, 'no toggle on slot 9'), 1, 'said once')
            eq(count(r.log, 'gone is not installed'), 1, 'said once')
            eq(count(r.log, 'no variant 7'), 1, 'said once')
        end)
    end,
    the_tick_shows_a_change_on_the_worn_look = function()
        with_suit(function()
            local r = rig()
            r.o.set('s', 1, 'toggle:3', false)
            r.o.tick()
            eq(r.reshown, 0, 'nothing worn: nothing to show')
            r.plan = {body = {fit = 's'}, added = {}}
            r.o.set('s', 1, 'toggle:4', false)
            r.o.tick() r.o.tick()
            eq(r.reshown, 1, 'the worn outfit\'s toggles shown once') eq(r.again, 0)
            r.o.set_variant('s', 2)
            r.o.tick() r.o.tick()
            eq(r.again, 1, 'a new variant: dressed again once')
            r.plan = {body = {fit = 'other'}, added = {}}
            r.o.set('s', 2, 'toggle:4', false)
            r.o.tick()
            eq(r.reshown, 1, 'another outfit worn: nothing')
        end)
    end,
    a_change_that_fails_to_show_is_asked_again = function()
        with_suit(function()
            local r = rig()
            r.plan = {body = {fit = 's'}, added = {}}
            r.fail = 'no EVE in the world'
            r.o.set_variant('s', 2)
            r.o.tick()
            eq(r.again, 1) eq(count(r.log, 'the change waits: no EVE in the world'), 1, 'the failure said')
            r.o.tick()
            eq(r.again, 2, 'asked again at the next tick')
            r.fail = nil
            r.o.tick() r.o.tick()
            eq(r.again, 3, 'shown once it works, then done')
            r.fail = 'EVE has no body mesh'
            r.o.set('s', 2, 'toggle:4', false)
            r.o.tick() r.o.tick()
            eq(r.reshown, 2, 'a toggle change asked again too')
        end)
    end,
    a_variant_whose_mesh_does_not_load_is_not_worn = function()
        with_suit(function()
            local r = rig()
            r.broken['/Game/P/V2.V2'] = true
            local good, why = r.o.set_variant('s', 2)
            eq(good, false) ok(why:find('does not load', 1, true), why)
            eq(r.o.variant('s'), 1, 'variant 1 kept') eq(Fits.get('s').Mesh, '/Game/P/V1.V1')
            eq(r.file, nil, 'nothing saved')
        end)
        -- A saved variant whose mesh no longer loads (a pack update): the first worn, said once, the value kept.
        local r = rig('s variant=2')
        r.broken['/Game/P/V2.V2'] = true
        with_suit(function()
            r.o.tick() r.o.tick()
            eq(r.o.variant('s'), 1, 'the first worn') eq(Fits.get('s').Mesh, '/Game/P/V1.V1')
            eq(count(r.log, 's variant 2: its mesh does not load'), 1, 'said once')
            eq(r.file, 's variant=2', 'the value stays in the file')
            Fits.use({s = suit('s')}) -- coop closet rescan: the chosen variant tried again
            r.o.tick()
            eq(Fits.get('s').Mesh, '/Game/P/V1.V1', 'still the first')
            eq(count(r.log, 's variant 2: its mesh does not load'), 1, 'said once')
            eq(count(r.log, 'has no variant'), 0, 'not said gone')
        end)
    end,
    coop_closet_option_sets_a_variant_or_a_toggle = function()
        with_suit(function()
            package.loaded.UEHelpers = package.loaded.UEHelpers or {GetPlayer = function() return nil end}
            local r = rig()
            local C = require('closet.commands').new({options = r.o})
            ok(C.closet('option', 's', 'variant', '2', nil, nil))
            eq(r.o.variant('s'), 2)
            ok(C.closet('option', 's', 'toggle', '4', 'off', nil))
            eq(r.o.get('s', 2, 'toggle:4'), false, 'in the variant worn')
            local good, why = C.closet('option', 's', 'toggle', '99', 'on', nil)
            eq(good, false) ok(why:find('no toggle on slot 99', 1, true), why)
            for _, bad in ipairs({{'option'}, {'option', 's', 'variant'}, {'option', 's', 'variant', 'x'},
                {'option', 's', 'toggle', '4'}, {'option', 's', 'toggle', '4', 'maybe'},
                {'option', 's', 'toggle', '4', 'on', 'more'}}) do
                eq(select(2, C.closet(table.unpack(bad))), Options.USE, table.concat(bad, ' '))
            end
            ok(require('closet.commands').USE:find('option <fit> toggle <slot> on|off', 1, true))
        end)
    end,
    reset_and_off_give_the_pack_values_back = function()
        with_suit(function()
            local r = rig('other 1 toggle:2=on')
            r.o.set('s', 1, 'toggle:4', false)
            r.o.set_variant('s', 2)
            r.o.reset('s')
            eq(r.o.variant('s'), 1) eq(r.o.get('s', 1, 'toggle:4'), true)
            eq(r.file, 'other 1 toggle:2=on', 'another outfit keeps its values')
            r.o.set('s', 1, 'toggle:4', false)
            r.o.off()
            eq(r.file, nil, 'the file cleared') eq(r.o.get('s', 1, 'toggle:4'), true)
            eq(Fits.get('s').Mesh, '/Game/P/V1.V1', 'variant 1 again')
        end)
    end,
}
run('options_test', tests)
