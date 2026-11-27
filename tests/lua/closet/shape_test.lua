-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet's shape layer (closet/shape.lua) over a fake dress and fake components and meshes: each worn mesh's morph
-- names read once per mesh path, the rows only for the names the body has or two worn meshes share, the values in
-- steps of 10 from 0 to 100, SetMorphTarget on her body for its names and on each added component for the names her
-- body lacks, the shape put on again when dress.applied() changes and when a value changes, her own look given back,
-- the shape kept in its file and read back, off() clearing it, stop() giving the curves back; coop closet shape
-- (closet/commands.lua).
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end} -- closet/dress.lua (commands.lua) needs it to load

local function obj(name)
    local o = {name = name, alive = true}
    o.type = function() return 'UObject' end
    function o:IsValid() return self.alive end
    return o
end
-- A skeletal mesh: its MorphTargets (each named by its GetFName), every read of the list counted.
local function mesh(path, names)
    local list = {}
    for i, n in ipairs(names) do
        local m = obj(n)
        function m:GetFName() return n end
        list[i] = m
    end
    local m = obj(path)
    m.reads = 0
    return setmetatable(m, {__index = function(self, k)
        if k ~= 'MorphTargets' then return nil end
        rawset(self, 'reads', self.reads + 1)
        if self.broken then error('engine said no') end
        return list
    end})
end
-- A skeletal mesh component: SetMorphTarget as FUN_14411b400 does it (Ghidra, build 26123051): the name's curve added
-- or changed, removed when bRemoveZeroWeight is set and |value| <= 1e-05.
local function component(name, m)
    local c = obj(name)
    c.SkeletalMesh, c.curves, c.calls = m, {}, {}
    function c:SetMorphTarget(n, v, remove)
        self.calls[#self.calls + 1] = {n, v, remove}
        if remove and math.abs(v) <= 1e-5 then self.curves[n] = nil else self.curves[n] = v end
    end
    -- As exec 0x14491efb0: the name's value in the curves, else 0.
    function c:GetMorphTarget(n) return self.curves[n] or 0 end
    return c
end

-- EVE's body (Breasts, Butt) with two added pieces: a skirt (Butt, Hips, Legs) and a belt (Hips, Arms).
local function rig(file, options)
    local r = {gen = 1, log = {}, file = file}
    r.store = {save = function(line) r.file = line; return true end, load = function() return r.file end,
        clear = function() r.file = nil end}
    r.body_mesh = mesh('/Game/Body', {'Breasts', 'Butt'})
    r.skirt_mesh = mesh('/Game/Skirt', {'Butt', 'Hips', 'Legs'})
    r.belt_mesh = mesh('/Game/Belt', {'Hips', 'Arms'})
    r.body = component('Body', r.body_mesh)
    r.skirt, r.belt = component('Skirt', r.skirt_mesh), component('Belt', r.belt_mesh)
    r.parts = {{c = r.body, mesh = '/Game/Body', slots = {}}, {c = r.skirt, mesh = '/Game/Skirt', slots = {}},
        {c = r.belt, mesh = '/Game/Belt', slots = {}}}
    r.dress = {applied = function() return r.gen end, parts = function() return r.parts end}
    FName = function(s) return s end
    package.loaded['closet.shape'] = nil
    r.Shape = require('closet.shape')
    r.s = r.Shape.new({dress = r.dress, store = r.store, options = options,
        log = function(m) r.log[#r.log + 1] = m end})
    return r
end

local tests = {
    -- Gun mode's rebuild (SetSkeletalMesh with another body, then hers, in one frame) empties her body's curves while
    -- dress.applied() stays: the curves set are read back once a second and the shape goes on again.
    a_curve_gone_with_a_rebuilt_body_is_set_again = function()
        local r = rig()
        local now = 0
        r.s = r.Shape.new({dress = r.dress, store = r.store, log = function(m) r.log[#r.log + 1] = m end,
            clock = function() return now end})
        r.s.set('Breasts', 50)
        r.s.tick()
        eq(r.body.curves.Breasts, 0.5, 'set')
        local calls = #r.body.calls
        now = now + 1.01
        r.s.tick()
        eq(#r.body.calls, calls, 'the curve still there: nothing set again')
        r.body.curves = {} -- Her body rebuilt: the curves at +0xec8 emptied.
        r.s.tick()
        eq(r.body.curves.Breasts, nil, 'read back once a second only')
        now = now + 1.01
        r.s.tick()
        eq(r.body.curves.Breasts, 0.5, 'set again') has(r.log, 'a curve set is gone', 'said')
    end,
    morph_names_are_read_once_per_mesh = function()
        local r = rig()
        r.s.tick()
        eq(r.body_mesh.reads, 1, 'the body mesh read') eq(r.skirt_mesh.reads, 1) eq(r.belt_mesh.reads, 1)
        r.gen = 2 -- A wear with the same meshes on new components.
        r.parts[2].c = component('Skirt2', r.skirt_mesh)
        r.s.tick()
        eq(r.body_mesh.reads, 1, 'cached by mesh path') eq(r.skirt_mesh.reads, 1)
        -- A mesh whose list does not read: logged once, no names from it.
        local odd = mesh('/Game/Odd', {'Hips'})
        odd.broken = true
        r.parts[4] = {c = component('Odd', odd), mesh = '/Game/Odd', slots = {}}
        r.gen = 3
        r.s.tick()
        eq(odd.reads, 1, 'read once') has(r.log, 'engine said no', 'the failure logged')
        r.gen = 4
        r.s.tick()
        eq(odd.reads, 1, 'not read again')
        -- A part whose component is gone gives no names and is read once it is there.
        local late = mesh('/Game/Late', {'Legs'})
        r.parts[4] = {c = nil, mesh = '/Game/Late', slots = {}}
        r.gen = 5
        r.s.tick()
        eq(late.reads, 0, 'no component: nothing read')
        r.parts[4].c = component('Late', late)
        r.gen = 6
        r.s.tick()
        eq(late.reads, 1, 'read once the component is there')
    end,

    rows_only_for_the_names_the_rule_allows = function()
        local r = rig()
        same(r.s.rows(), {}, 'nothing painted yet: no row')
        r.s.tick()
        -- Breasts and Butt: the body has them. Hips: two worn meshes share it. Legs and Arms: one added mesh only.
        same(r.s.rows(), {'Breasts', 'Butt', 'Hips'}, 'the body\'s names, then the shared ones')
        -- Her own look (nothing mixed): no row.
        r.gen, r.parts = 2, {}
        r.s.tick()
        same(r.s.rows(), {}, 'no look: no row')
        -- Meshes without morphs (Ocean Maid, Kunoichi Shadow): no row.
        r.gen = 3
        r.parts = {{c = component('Maid', mesh('/Game/Maid', {})), mesh = '/Game/Maid', slots = {}},
            {c = component('Ninja', mesh('/Game/Ninja', {})), mesh = '/Game/Ninja', slots = {}}}
        r.s.tick()
        same(r.s.rows(), {}, 'no morphs: no row')
        -- A name listed twice in one mesh counts once.
        r.gen = 4
        r.parts = {{c = component('Maid', mesh('/Game/Maid2', {})), mesh = '/Game/Maid2', slots = {}},
            {c = component('Twice', mesh('/Game/Twice', {'Hips', 'Hips'})), mesh = '/Game/Twice', slots = {}}}
        r.s.tick()
        same(r.s.rows(), {}, 'one mesh, the name twice: no row')
    end,

    values_step_and_clamp = function()
        local r = rig()
        eq(r.s.get('Butt'), 0, '0 at first')
        local good, line = r.s.step('Butt', 1)
        ok(good, line) eq(line, 'closet: shape Butt 10%') eq(r.s.get('Butt'), 10, 'right: 10')
        for _ = 1, 12 do r.s.step('Butt', 1) end
        eq(r.s.get('Butt'), 100, 'stops at 100')
        r.s.step('Butt', -1)
        eq(r.s.get('Butt'), 90, 'left: 90')
        for _ = 1, 12 do r.s.step('Butt', -1) end
        eq(r.s.get('Butt'), 0, 'stops at 0')
        r.s.set('Butt', 35) eq(r.s.get('Butt'), 40, 'to the nearest step')
        r.s.set('Butt', 34) eq(r.s.get('Butt'), 30)
        r.s.set('Butt', 150) eq(r.s.get('Butt'), 100, 'at most 100')
        r.s.set('Butt', -5) eq(r.s.get('Butt'), 0, 'at least 0')
    end,

    set_on_the_body_and_on_follower_only_names = function()
        local r = rig()
        r.s.set('Butt', 50)
        r.s.set('Hips', 30)
        same(r.body.calls, {}, 'the shape goes on in the tick')
        r.s.tick()
        -- Butt: her body has it, the skirt follows it (the engine's follower merge): set on her body only.
        same(r.body.curves, {Butt = 0.5}, 'Butt on her body')
        same(r.body.calls, {{'Butt', 0.5, true}}, 'once, bRemoveZeroWeight set')
        -- Hips: her body lacks it: set on each added piece that has it.
        same(r.skirt.curves, {Hips = 0.3}, 'Hips on the skirt, not Butt')
        same(r.belt.curves, {Hips = 0.3}, 'Hips on the belt')
        -- A value changed: only that name set again.
        r.s.set('Hips', 60)
        r.s.tick()
        same(r.body.calls, {{'Butt', 0.5, true}}, 'Butt not sent again')
        same(r.skirt.curves, {Hips = 0.6}) same(r.belt.curves, {Hips = 0.6})
        r.s.tick() r.s.tick()
        eq(#r.skirt.calls, 2, 'nothing changed: no call')
        -- Back to 0: the name removed (SetMorphTarget with 0 and bRemoveZeroWeight).
        r.s.set('Butt', 0)
        r.s.tick()
        same(r.body.curves, {}, 'Butt removed from her body')
        same(r.body.calls[2], {'Butt', 0, true}, 'removed with 0 and bRemoveZeroWeight')
        -- A name no row lists (Legs: the skirt alone has it) is never set.
        r.s.set('Legs', 70)
        r.s.tick()
        eq(r.skirt.curves.Legs, nil, 'Legs: no row, not set')
        has(r.log, 'shape: ', 'logged')
    end,

    applied_again_when_the_dress_applies = function()
        local r = rig()
        r.s.set('Butt', 50)
        r.s.set('Hips', 30)
        r.s.tick()
        -- A wear on the same body mesh: SetSkeletalMesh kept her body's curves, the added pieces are new.
        r.gen = 2
        r.body.curves.Foreign = 0.7 -- A curve the closet did not set (CNS, the game).
        local skirt = component('Skirt2', r.skirt_mesh)
        r.parts[2].c, r.parts[3] = skirt, nil
        r.s.tick()
        same(skirt.curves, {}, 'one piece has Hips now: no row, not set')
        same(r.body.curves, {Butt = 0.5, Foreign = 0.7}, 'Butt set again')
        eq(#r.body.calls, 2, 'set again after the apply')
        -- A wear with a body mesh that cleared her curves (SetSkeletalMesh with a new mesh).
        r.gen = 3
        r.body.curves = {}
        r.parts[3] = {c = component('Belt2', r.belt_mesh), mesh = '/Game/Belt', slots = {}}
        r.s.tick()
        same(r.body.curves, {Butt = 0.5}, 'Butt set again')
        same(skirt.curves, {Hips = 0.3}, 'Hips again: two pieces share it')
        -- Paused (Tachy Mode) or stopped: nothing; the shape comes back with the mix.
        r.gen, r.parts = 4, nil
        r.body.curves = {}
        r.s.tick()
        same(r.body.curves, {}, 'nothing while paused')
        r.parts = {{c = r.body, mesh = '/Game/Body', slots = {}}}
        r.gen = 5
        r.s.tick()
        same(r.body.curves, {Butt = 0.5}, 'set once the mix is back')
        -- Her own look (own_look or off): the closet's names off her body, a foreign curve kept.
        r.body.curves.Foreign = 0.7
        r.gen, r.parts = 6, {}
        r.s.tick()
        same(r.body.curves, {Foreign = 0.7}, 'only the closet\'s names removed')
        same(r.s.rows(), {}, 'no row')
    end,

    the_shape_is_kept = function()
        local r = rig()
        r.s.set('Hips', 30)
        r.s.set('Butt', 50)
        eq(r.file, 'Butt=50\tHips=30', 'the file in name order')
        local again = r.Shape.new({dress = r.dress, store = r.store, log = function() end})
        eq(again.get('Butt'), 50, 'read back') eq(again.get('Hips'), 30) eq(again.get('Breasts'), 0)
        again.tick()
        same(r.body.curves, {Butt = 0.5}, 'worn again after a restart')
        r.s.set('Hips', 0)
        eq(r.file, 'Butt=50', 'a value of 0 is left out')
        ok(r.s.off())
        eq(r.file, nil, 'off clears the file')
        eq(r.s.get('Butt'), 0)
        -- Words it cannot read are left out, values are kept in steps and range.
        r.file = 'Butt=abc\tHips=150\tLegs=34\tArms=0\tnope'
        local odd = r.Shape.new({dress = r.dress, store = r.store, log = function() end})
        eq(odd.get('Butt'), 0) eq(odd.get('Hips'), 100) eq(odd.get('Legs'), 30) eq(odd.get('Arms'), 0)
        -- A file that cannot be written: logged, the value still on.
        r.store.save = function() return false, 'disk full' end
        ok(r.s.set('Butt', 20))
        has(r.log, 'disk full', 'logged') eq(r.s.get('Butt'), 20)
    end,

    off_takes_the_shape_off = function()
        local r = rig()
        r.s.set('Butt', 50)
        r.s.set('Hips', 30)
        r.s.tick()
        local good, line = r.s.off()
        ok(good) eq(line, 'closet: shape off')
        r.s.tick()
        same(r.body.curves, {}, 'her body\'s curve removed')
        same(r.skirt.curves, {}) same(r.belt.curves, {})
    end,

    stop_gives_the_curves_back = function()
        local r = rig()
        r.s.set('Butt', 50)
        r.s.tick()
        r.s.stop() -- coop off: the dress gave her look back first; her body may wear the same mesh.
        same(r.body.curves, {}, 'the closet\'s curve removed')
        eq(r.file, 'Butt=50', 'the shape stays for the next look')
        r.s.tick()
        same(r.body.curves, {Butt = 0.5}, 'set again at the next tick')
    end,

    commands = function()
        local r = rig()
        local C = require('closet.commands').new({dress = {}, fits = require('closet.fits'), shape = r.s})
        local good, line = C.closet('shape', 'Butt', '50', nil, nil, nil)
        ok(good and line == 'closet: shape Butt 50%', line)
        eq(r.s.get('Butt'), 50)
        good, line = C.closet('shape', 'Butt', '0', nil, nil, nil)
        ok(good and line == 'closet: shape Butt 0%', line)
        r.s.set('Hips', 40)
        good, line = C.closet('shape', 'off', nil, nil, nil, nil)
        ok(good and line == 'closet: shape off', line)
        eq(r.s.get('Hips'), 0)
        for _, words in ipairs({{}, {'Butt'}, {'Butt', 'lots'}, {'Butt', '50', 'x'}, {'off', 'x'}}) do
            good, line = C.closet('shape', table.unpack(words))
            ok(not good and line == r.Shape.USE, table.concat(words, ' ') .. ': ' .. tostring(line))
        end
    end,
    -- A name the options layer wrote on the same component (a pack ShapeKey) gets its pack value back, not removal.
    a_pack_shape_key_comes_back_when_its_row_goes_to_0 = function()
        local options = {}
        local r = rig(nil, options)
        function options.shaped(c, name) if c == r.body and name == 'Breasts' then return 0.5 end end
        r.s.set('Breasts', 30) r.s.set('Butt', 40)
        r.s.tick()
        eq(r.body.curves.Breasts, 0.3, 'the row on her body')
        r.s.set('Breasts', 0) r.s.set('Butt', 0)
        r.s.tick()
        local back = {}
        for _, call in ipairs(r.body.calls) do back[call[1]] = call end
        eq(back.Breasts[2], 0.5, 'the pack value written back') eq(back.Breasts[3], true)
        eq(r.body.curves.Breasts, 0.5, 'the pack shape key stays')
        eq(r.body.curves.Butt, nil, 'a name options does not hold is removed')
    end,
}
run('shape_test', tests)
