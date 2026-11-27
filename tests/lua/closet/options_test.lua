-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The options layer (closet/options.lua) over a fake dress and a fake store: piece toggles per outfit and variant
-- (followers copy their leader), the chosen variant, values kept only where they differ from the pack, saved values
-- of a gone outfit, variant or slot ignored and said once, the tick that shows a change on the worn look, a shape key
-- read back beside the Body tab's shape (closet/shape.lua) on the same name.
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

-- The engine side of the material values: a component (closet/colour_test.lua's: CreateDynamicMaterialInstance hands
-- back an instance already on the slot, else makes one) whose instances keep each value set and whose SetMorphTarget
-- keeps each curve; textures by object path (StaticFindObject), a Texture2D when F_TEXTURES names it.
local addresses = 0
local function obj(name)
    addresses = addresses + 1
    local o = {name = name, alive = true, address = addresses}
    o.type = function() return 'UObject' end
    function o:IsValid() return self.alive end
    function o:GetAddress() return self.address end
    return o
end
local TEXTURE2D = obj('Texture2D class')
local textures = {}
StaticFindObject = function(path)
    if path == '/Script/Engine.Texture2D' then return TEXTURE2D end
    return textures[path]
end
LoadAsset = function() end
FName = function(s) return s end
local function texture(path)
    local t = obj(path)
    function t:IsA(class) return class == TEXTURE2D end
    textures[path] = t
    return t
end
local function component(name, slots)
    local c = obj(name)
    c.mats, c.creates, c.morphs, c.morph_calls = {}, 0, {}, 0
    for _, i in ipairs(slots) do c.mats[i] = obj(name .. ' material ' .. i) end
    function c:GetMaterial(i) return self.mats[i] end
    function c:SetMaterial(i, m) self.mats[i] = m end
    function c:CreateDynamicMaterialInstance(i, source)
        if source then self.mats[i] = source end
        local now = self.mats[i]
        if not now then return nil end
        if now.mid then return now end
        local m = obj('MID ' .. i)
        m.mid, m.values, m.writes = true, {}, 0
        local function keep(self2, n, v) self2.values[n] = v; self2.writes = self2.writes + 1 end
        m.SetVectorParameterValue = function(self2, n, v)
            keep(self2, n, {R = v.R, G = v.G, B = v.B, A = v.A})
        end
        m.SetScalarParameterValue, m.SetTextureParameterValue = keep, keep
        -- closet/colour.lua reads a vector parameter before it sets one (its value from before).
        m.K2_GetVectorParameterValue = function(self2, n) return self2.values[n] or {R = 0, G = 0, B = 0, A = 1} end
        self.mats[i], self.creates = m, self.creates + 1
        return m
    end
    function c:SetMorphTarget(n, v, remove)
        self.morph_calls = self.morph_calls + 1
        if remove and math.abs(v) <= 1e-5 then self.morphs[n] = nil else self.morphs[n] = v end
    end
    -- As exec 0x14491efb0: the name's value in the curves, else 0.
    function c:GetMorphTarget(n) return self.morphs[n] or 0 end
    return c
end
-- A pack suit with material controls: colours on slots 3 (Top, 0..1), 4 (Glow, an HDR default above its Max) and 5
-- (Lining, follows Top); numbers on 3 (Shine, its own step) and 4 (Opacity, no range); a finish on 3 (Pattern, three
-- textures, the second missing); shape keys FB_Breast (named by ShapeKeyName) and TopReveal (by DisplayName).
local function dyed(id)
    local s = suit(id)
    s.UserConfigs.VectorControls = {
        {DisplayName = 'Top', ParamName = 'Base Color Tint', MaterialIndex = 3, Value = {0.5, 0.5, 0.5, 1},
            Min = {0, 0, 0, 0}, Max = {1, 1, 1, 1}, Step = {0.01, 0.01, 0.01, 0.01},
            Sliders = {true, true, true, false}},
        {DisplayName = 'Glow', ParamName = 'EmissiveColor', MaterialIndex = 4, Value = {32, 0, 0, 1},
            Min = {0, 0, 0, 0}, Max = {10, 10, 10, 1}},
        {DisplayName = 'Lining', ParamName = 'Base Color Tint', MaterialIndex = 5, Value = {0.5, 0.5, 0.5, 1},
            ControlledBy = 'Top'}}
    s.UserConfigs.ScalarControls = {
        {DisplayName = 'Shine', ParamName = 'Metallic', MaterialIndex = 3, Value = 0.5, Min = 0, Max = 1, Step = 0.1},
        {DisplayName = 'Opacity', ParamName = 'Opacity Inner', MaterialIndex = 4, Value = 0.32}}
    s.UserConfigs.TextureOptions = {
        {DisplayName = 'Pattern', ParamName = 'BaseColor', MaterialIndex = 3,
            OptionNames = {'Plain', 'Stripes', 'Dots'}, Textures = {'/Game/P/T0.T0', '/Game/P/T1.T1', '/Game/P/T2.T2'}, Value = 0}}
    s.UserConfigs.ShapeKeys = {
        {DisplayName = 'Breast', ShapeKeyName = 'FB_Breast', Min = -2, Max = 0, Step = 0.5, Value = 0},
        {DisplayName = 'TopReveal', Min = 0, Max = 1, Step = 1, Value = 0}}
    return s
end
-- f(r) with the dyed suit s worn as her body (dress.applied, dress.parts), textures T0 and T2 loading.
local function dyed_rig(f)
    Fits.use({s = dyed('s')})
    textures = {}
    local t0, t2 = texture('/Game/P/T0.T0'), texture('/Game/P/T2.T2')
    local good, why = pcall(function()
        local r = rig()
        r.gen, r.body = 1, component('Body', {3, 4, 5})
        r.parts = {{c = r.body, fit = 's', mesh = '/Game/P/V1.V1', slots = {}}}
        r.dress.applied = function() return r.gen end
        r.dress.parts = function() return r.parts end
        r.t0, r.t2 = t0, t2
        r.value = function(i, n) local m = r.body.mats[i]; return m.mid and m.values[n] end
        f(r)
    end)
    Fits.use(nil)
    Fits.CHOSEN = {}
    ok(good, why)
end
local function near(got, want, what)
    for _, k in ipairs({'R', 'G', 'B', 'A'}) do
        ok(got and math.abs(got[k] - want[k]) < 1e-6, ('%s: %s %s, want %s'):format(what, k,
            tostring(got and got[k]), tostring(want[k])))
    end
end

local tests = {
    -- The options layer and the palette (closet/colour.lua) together on one held slot, through the real pack scan
    -- (closet/packs.lua over a fake list file, then Fits.use, as closet/wiring.lua's scan) and ticked in the wiring's
    -- order: a rescan whose pack list cannot be read, then one that reads it again, keeps the palette's colour; Primary
    -- turned off during a rescan's repaint gives the pack colour back.
    the_palette_and_options_agree_across_a_rescan = function()
        dyed_rig(function(r)
            local paks, list = 'C:\\SB\\Content\\Paks', 'C:\\SB\\coop-cns-packs.txt'
            local file = '~mods\\S\\s.dekcns.json'
            local listed = '1 1 ' .. file .. '\n'
            local text = '[{"UniqueFitID":"s","DisplayName":"S","OutfitPaths":["/Game/P/V1.V1"],'
                .. '"UserConfigs":{"VectorControls":[{"DisplayName":"Top","ParamName":"Base Color Tint",'
                .. '"MaterialIndex":3,"Value":[0.5,0.5,0.5,1]}]}}]'
            local packs = require('closet.packs').new({paks = paks, list = list, log = function() end,
                read = function(path, limit)
                    if path == list then
                        if not listed then return nil, list .. ': No such file or directory', 2 end
                        return listed
                    end
                    return limit and text:sub(1, limit) or text
                end})
            local function rescan() Fits.use((packs.scan())) end
            rescan()
            r.parts[1].slots = {[3] = 'FullOutfit'} -- A pack suit worn whole: its section is Primary's.
            local c = require('closet.colour').new({dress = r.dress, log = function() end, options = r.o,
                store = {save = function() return true end, load = function() return nil end, clear = function() end}})
            local function tick() r.o.tick(); c.tick() end
            local cr, cg, cb = require('closet.colour').swatch('crimson')
            local crimson, pack = {R = cr, G = cg, B = cb, A = 1}, {R = 0.5, G = 0.5, B = 0.5, A = 1}
            tick()
            near(r.value(3, 'Base Color Tint'), pack, 'the pack colour first')
            c.set('primary', 'crimson')
            tick()
            near(r.value(3, 'Base Color Tint'), crimson, 'the palette on the held slot')
            listed = nil -- The list file cannot be read.
            rescan()
            tick()
            near(r.value(3, 'Base Color Tint'), crimson, 'a failed list read: the palette stays')
            listed = '1 1 ' .. file .. '\n' -- Read again: options writes its pack colour anew.
            rescan()
            tick()
            near(r.value(3, 'Base Color Tint'), crimson, 'recovered: the palette over the pack colour again')
            rescan() -- The same pack again, Primary turned off before the next tick.
            c.set('primary', 'off')
            tick()
            near(r.value(3, 'Base Color Tint'), pack, 'Primary off during a repaint: the pack colour back')
        end)
    end,
    a_colour_swatch_and_custom_rgb_write_the_param = function()
        dyed_rig(function(r)
            r.o.tick()
            near(r.value(3, 'Base Color Tint'), {R = 0.5, G = 0.5, B = 0.5, A = 1}, 'the pack value written')
            near(r.value(5, 'Base Color Tint'), {R = 0.5, G = 0.5, B = 0.5, A = 1}, 'the follower too')
            eq(r.o.choice('s', 1, 1), 'pack')
            ok(r.o.cycle('s', 1, 1, 1))
            eq(r.o.choice('s', 1, 1), 'white', 'the first swatch after Pack colour')
            r.o.tick()
            near(r.value(3, 'Base Color Tint'), {R = 0.888, G = 0.888, B = 0.888, A = 1}, 'the swatch, the pack alpha')
            near(r.value(5, 'Base Color Tint'), {R = 0.888, G = 0.888, B = 0.888, A = 1}, 'Lining follows Top')
            eq(r.file, 's 1 colour:1=0.888,0.888,0.888,1', 'kept')
            ok(r.o.cycle('s', 1, 1, -1)) eq(r.o.choice('s', 1, 1), 'pack') eq(r.file, nil, 'the pack value again')
            ok(r.o.cycle('s', 1, 1, -1)) eq(r.o.choice('s', 1, 1), 'custom', 'Custom before Pack colour')
            ok(r.o.step('s', 1, 'colour:1', 1, 'r'))
            r.o.tick()
            near(r.value(3, 'Base Color Tint'), {R = 0.55, G = 0.5, B = 0.5, A = 1}, 'red a step up')
            eq(r.o.choice('s', 1, 1), 'custom')
            eq(r.file, 's 1 colour:1=custom:0.55,0.5,0.5,1', 'a custom value kept')
            eq(r.new().choice('s', 1, 1), 'custom', 'read back')
            ok(r.o.cycle('s', 1, 1, 1)) eq(r.o.choice('s', 1, 1), 'pack', 'Pack colour after Custom')
        end)
    end,
    a_value_above_max_is_kept_until_moved = function()
        dyed_rig(function(r)
            r.o.tick()
            near(r.value(4, 'EmissiveColor'), {R = 32, G = 0, B = 0, A = 1}, 'the HDR default written as it is')
            eq(r.o.get('s', 1, 'colour:2').R, 32, 'shown as it is')
            ok(r.o.step('s', 1, 'colour:2', -1, 'r'))
            eq(r.o.get('s', 1, 'colour:2').R, 10, 'moved: into its range')
            r.o.tick()
            near(r.value(4, 'EmissiveColor'), {R = 10, G = 0, B = 0, A = 1}, 'written')
        end)
    end,
    steps_are_one_twentieth_of_the_range_or_the_pack_step = function()
        dyed_rig(function(r)
            same({r.o.range('s', 'colour:1', 'r')}, {0, 1, 0.05}, 'a colour: 1/20 of its range')
            same({r.o.range('s', 'colour:2', 'g')}, {0, 10, 0.5}, 'an HDR colour: 1/20 of its range')
            same({r.o.range('s', 'number:1')}, {0, 1, 0.1}, 'a number: the pack step')
            same({r.o.range('s', 'number:2')}, {0, 1, 0.05}, 'no range: 0..1 in 1/20')
            same({r.o.range('s', 'shape:1')}, {-2, 0, 0.5}, 'a shape key: the pack range and step')
        end)
    end,
    a_finish_loads_its_texture_and_a_missing_one_is_dropped_once = function()
        dyed_rig(function(r)
            same(r.o.finishes('s', 1), {0, 2}, 'Stripes does not load: dropped')
            same(r.o.finishes('s', 1), {0, 2})
            eq(count(r.log, 'T1.T1'), 1, 'said once')
            r.o.tick()
            eq(r.value(3, 'BaseColor'), r.t0, 'the pack finish written')
            ok(r.o.set('s', 1, 'finish:1', 2))
            eq(r.file, 's 1 finish:1=2')
            r.o.tick()
            eq(r.value(3, 'BaseColor'), r.t2, 'Dots')
            ok(r.o.set('s', 1, 'finish:1', 1))
            r.o.tick()
            eq(r.value(3, 'BaseColor'), r.t2, 'a missing finish writes nothing')
            eq(count(r.log, 'T1.T1'), 1, 'still said once')
        end)
    end,
    a_number_row_clamps_to_min_max = function()
        dyed_rig(function(r)
            for _ = 1, 8 do r.o.step('s', 1, 'number:1', 1) end
            eq(r.o.get('s', 1, 'number:1'), 1, 'up to Max')
            for _ = 1, 30 do r.o.step('s', 1, 'number:1', -1) end
            eq(r.o.get('s', 1, 'number:1'), 0, 'down to Min')
            eq(r.file, 's 1 number:1=0')
            r.o.tick()
            eq(r.value(3, 'Metallic'), 0, 'written') eq(r.value(4, 'Opacity Inner'), 0.32, 'the other: its pack value')
            local good = r.o.set('s', 1, 'number:9', 1)
            eq(good, false, 'no such number')
        end)
    end,
    shape_keys_use_shapekeyname_else_displayname = function()
        dyed_rig(function(r)
            ok(r.o.step('s', 1, 'shape:1', -1)) ok(r.o.step('s', 1, 'shape:2', 1))
            r.o.tick()
            same(r.body.morphs, {FB_Breast = -0.5, TopReveal = 1}, 'ShapeKeyName, else DisplayName')
            -- shaped finds the value by the component's address: each read of her body is a new UE4SS wrapper.
            local again = setmetatable({}, {__index = r.body})
            eq(r.o.shaped(again, 'FB_Breast'), -0.5, 'another wrapper of her body: its value')
            eq(r.o.shaped(again, 'Nothing'), nil, 'a name not written: nil')
            r.o.reset('s')
            r.o.tick()
            same(r.body.morphs, {}, 'the pack values: the curves removed')
        end)
    end,
    -- A worn mesh put on again (gun mode's rebuild of her body) empties the curves while dress.applied() stays: the
    -- shape keys written are read back once a second and written again.
    a_shape_key_gone_with_a_rebuilt_body_is_written_again = function()
        dyed_rig(function(r)
            local now = 0
            local o = Options.new({store = r.store, dress = r.dress, log = function(m) r.log[#r.log + 1] = m end,
                clock = function() return now end})
            ok(o.step('s', 1, 'shape:2', 1))
            o.tick()
            same(r.body.morphs, {TopReveal = 1}, 'written')
            local calls = r.body.morph_calls
            now = now + 1.01
            o.tick()
            eq(r.body.morph_calls, calls, 'the curves still there: nothing written again')
            r.body.morphs = {}
            now = now + 1.01
            o.tick()
            same(r.body.morphs, {TopReveal = 1}, 'written again') ok(count(r.log, 'written again') == 1, 'said')
        end)
    end,
    -- The Body tab's shape (closet/shape.lua) and the pack's shape key write FB_Breast on one component: after the first
    -- paint neither reads the other's value as gone, so nothing is written or said again and the shape's value stays.
    two_writers_of_one_name_settle_after_the_first_paint = function()
        dyed_rig(function(r)
            package.loaded['closet.shape'] = nil
            local Shape = require('closet.shape')
            local now = 0
            local clock = function() return now end
            local morph = obj('FB_Breast')
            function morph:GetFName() return 'FB_Breast' end
            r.body.SkeletalMesh = {MorphTargets = {morph}}
            local o = Options.new({store = r.store, dress = r.dress, log = function(m) r.log[#r.log + 1] = m end,
                clock = clock})
            local file
            local s = Shape.new({dress = r.dress, log = function(m) r.log[#r.log + 1] = m end, clock = clock,
                store = {save = function(l) file = l; return true end, load = function() return file end,
                    clear = function() file = nil end}})
            s.set('FB_Breast', 50)
            o.tick() s.tick()
            eq(r.body.morphs.FB_Breast, 0.5, 'the shape written last')
            local calls, lines = r.body.morph_calls, #r.log
            for _ = 1, 600 do -- 10 s at 60 frames a second.
                now = now + 1 / 60
                o.tick() s.tick()
            end
            eq(r.body.morph_calls, calls, 'nothing written again') eq(#r.log, lines, 'nothing said again')
            eq(r.body.morphs.FB_Breast, 0.5, 'the shape\'s value stays')
            r.body.morphs = {} -- Her body rebuilt: both find their curve gone.
            now = now + 1.01
            o.tick() s.tick()
            eq(r.body.morphs.FB_Breast, 0.5, 'set again') has(r.log, 'a curve set is gone', 'the shape said it')
        end)
    end,
    -- The same two writers with the pack's shape key set away from 0 on the options page: after her body is rebuilt the
    -- options layer writes its value first. The shape reads that value as the pack's (not its own) and puts its value
    -- back. Then neither reads the other's value as gone.
    the_shape_wins_again_over_a_pack_value_after_a_rebuild = function()
        dyed_rig(function(r)
            package.loaded['closet.shape'] = nil
            local Shape = require('closet.shape')
            local now = 0
            local clock = function() return now end
            local morph = obj('FB_Breast')
            function morph:GetFName() return 'FB_Breast' end
            r.body.SkeletalMesh = {MorphTargets = {morph}}
            local o = Options.new({store = r.store, dress = r.dress, log = function(m) r.log[#r.log + 1] = m end,
                clock = clock})
            local file
            local s = Shape.new({dress = r.dress, options = o, log = function(m) r.log[#r.log + 1] = m end,
                clock = clock, store = {save = function(l) file = l; return true end, load = function() return file end,
                    clear = function() file = nil end}})
            ok(o.step('s', 1, 'shape:1', -1)) -- The pack's FB_Breast at -0.5.
            s.set('FB_Breast', 50)
            o.tick() s.tick()
            eq(r.body.morphs.FB_Breast, 0.5, 'the shape written last')
            r.body.morphs = {} -- Her body rebuilt: both find their curve gone.
            now = now + 1.01
            o.tick() s.tick() -- The options layer writes -0.5 back first: the shape reads it as the pack's.
            eq(r.body.morphs.FB_Breast, 0.5, 'set again') has(r.log, 'a curve set is gone', 'the shape said it')
            local calls, lines = r.body.morph_calls, #r.log
            for _ = 1, 600 do -- 10 s at 60 frames a second.
                now = now + 1 / 60
                o.tick() s.tick()
            end
            eq(r.body.morph_calls, calls, 'nothing written again') eq(#r.log, lines, 'nothing said again')
            eq(r.body.morphs.FB_Breast, 0.5, 'the shape\'s value stays')
        end)
    end,
    values_apply_again_after_applied_changes = function()
        dyed_rig(function(r)
            r.o.tick()
            local writes, morphs = r.body.mats[3].writes, r.body.morph_calls
            ok(writes >= 3, 'tint, number, finish on slot 3')
            r.o.tick()
            eq(r.body.mats[3].writes, writes, 'nothing changed: nothing written') eq(r.body.morph_calls, morphs)
            ok(r.o.set('s', 1, 'number:1', 0.7))
            r.o.tick()
            eq(r.body.mats[3].writes, writes + 1, 'only the changed value') eq(r.value(3, 'Metallic'), 0.7)
            r.gen, r.body = 2, component('Body again', {3, 4, 5}) -- A map load: the dress put the look on again.
            r.parts = {{c = r.body, fit = 's', mesh = '/Game/P/V1.V1', slots = {}}}
            r.o.tick()
            eq(r.value(3, 'Metallic'), 0.7, 'the kept value on the new body')
            near(r.value(3, 'Base Color Tint'), {R = 0.5, G = 0.5, B = 0.5, A = 1}, 'the pack values too')
            ok(r.o.holds(r.body, 3) and r.o.holds(r.body, 4), 'the slots with a pack colour control')
            -- revision grows with every paint, a pack rescan's too (Fits.PACKS replaced, no value changed): the
            -- palette (closet/colour.lua) paints after each.
            local rev = r.o.revision()
            require('closet.fits').PACKS = setmetatable({}, {__index = require('closet.fits').PACKS})
            r.o.tick()
            ok(r.o.revision() ~= rev, 'a rescan\'s repaint: a new revision')
            ok(not r.o.holds(r.body, 6), 'a slot without one')
            -- owns: a control changed away from the pack's colour (the palette leaves only those alone).
            ok(not r.o.owns(r.body, 3) and not r.o.owns(r.body, 4), 'on the pack colour: not owned')
            ok(r.o.step('s', 1, 'colour:1', 1, 'r'))
            r.o.tick()
            local custom = {}
            for _, i in ipairs({3, 4, 5}) do custom[#custom + 1] = r.o.owns(r.body, i) and i or nil end
            ok(#custom > 0, 'a custom colour: its slot owned')
            ok(not r.o.owns(r.body, 6), 'a slot without a control: never owned')
        end)
    end,
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
    -- Any UniqueFitID: its file word is Fits.word's, read back as the same id (spaces, ':', '=', non-ASCII).
    any_pack_id_survives_the_file = function()
        local odd = 'Ocean = Maid:v2,(Shadow)+\195\136ve%01\t'
        Fits.use({[odd] = suit(odd)})
        local good, why = pcall(function()
            local r = rig()
            ok(r.o.set_variant(odd, 2))
            ok(r.o.set(odd, 2, 'toggle:4', false))
            ok(not r.file:find(' Maid', 1, true), r.file)
            -- A game restart: the catalogue scanned again with no variant chosen, so the variant comes from the file.
            Fits.CHOSEN = {}
            Fits.use({[odd] = suit(odd)})
            eq(Fits.PACKS[odd].Variant, 1, 'the scan alone wears the first')
            local again = r.new()
            eq(again.variant(odd), 2, 'its variant read back') eq(again.get(odd, 2, 'toggle:4'), false, 'its value')
            eq(again.toggles()[odd][4], false, 'in the plans\' toggles')
            again.off()
            eq(r.file, nil, 'off clears every value of it')
        end)
        Fits.use(nil)
        Fits.CHOSEN = {}
        ok(good, why)
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
