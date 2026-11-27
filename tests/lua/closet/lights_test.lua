-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet's preview lights (closet/ui/lights.lua) over a fake camera actor, its light components and core/unreal.lua:
-- each preset's lights (deferred, Movable before the setters, their colours, intensities and places in the camera's
-- frame), Game with none, the preset cycle removing the old lights, the intensity steps and limits, a saved preset and
-- intensity read back, a camera that goes taking its lights with it, an engine failure turning the lights off.
local run = dofile('tests/lua/closet/run.lua')
local Lights = require('closet.ui.lights')

local POINT, MATH = '/Script/Engine.PointLightComponent', '/Script/Engine.Default__KismetMathLibrary'
local IDENTITY = {identity = true}
local L -- One case's world.
-- A light component: every call recorded in order ({name, args...}); L.fail names a call that raises.
local LIGHT = {__index = function(_, name)
    return function(self, ...)
        if L.fail == name then error(name .. ' refused', 0) end
        self.calls[#self.calls + 1] = {name, ...}
    end
end}
-- A camera actor: the components it was asked to add; FinishAddComponent is recorded on the component.
local function actor(name)
    local a = {name = name, added = {}}
    a.AddComponentByClass = function(self, class, manual, transform, deferred)
        if L.fail == 'AddComponentByClass' then error('add refused', 0) end
        local c = setmetatable({calls = {}, class = class, manual = manual, transform = transform, deferred = deferred},
            LIGHT)
        self.added[#self.added + 1] = c
        return c
    end
    a.FinishAddComponent = function(self, c, manual, transform)
        assert(self == a)
        c.calls[#c.calls + 1] = {'finish', manual, transform}
    end
    return a
end
local unreal = {valid = function(o) return o end, find = function(path)
    if path == POINT then return 'point class' end
    if path == MATH then
        return {MakeTransform = function(_, at, rot, scale)
            assert(at.X == 0 and at.Y == 0 and at.Z == 0 and rot.Pitch == 0 and rot.Yaw == 0 and rot.Roll == 0
                and scale.X == 1 and scale.Y == 1 and scale.Z == 1, 'an identity transform')
            return IDENTITY
        end}
    end
end}
local function world()
    L = {logs = {}}
    return Lights.new({unreal = unreal, log = function(m) L.logs[#L.logs + 1] = m end})
end
-- The calls named name on component c, each as its argument list.
local function calls(c, name)
    local out = {}
    for _, call in ipairs(c.calls) do if call[1] == name then out[#out + 1] = {table.unpack(call, 2)} end end
    return out
end
-- c removed once, K2_DestroyComponent given its actor a.
local function destroyed(c, a)
    local d = calls(c, 'K2_DestroyComponent')
    return #d == 1 and d[1][1] == a
end
local function near(got, want, tol, what)
    if math.abs(got - want) > tol then error(('%s: got %.4f, want %.4f'):format(what, got, want), 2) end
end
-- Each preset's lights: the place, the colour, the candelas (starting values of closet/ui/lights.lua).
local WANT = {
    studio = {{'key', {1, 1, 1}, 30}, {'fill', {0.85, 0.92, 1}, 10}},
    warm = {{'key', {1, 0.8, 0.6}, 30}, {'fill', {1, 0.8, 0.6}, 8}},
    cool = {{'key', {0.7, 0.85, 1}, 30}, {'fill', {0.7, 0.85, 1}, 8}},
    rim = {{'rim', {1, 1, 1}, 40}, {'key', {1, 1, 1}, 10}},
}
-- Where each place puts its light in the camera's frame (X ahead, Y right, Z up) for a look point 300 cm away at NDC
-- tangent 0.55: the look point is at (262.865, 144.576, 0).
local AT = {key = {52.865, -35.424, 150}, fill = {22.865, 354.576, 0}, rim = {412.865, 94.576, 100}}

local tests = {
    game_makes_no_light = function()
        local lights = world()
        eq(lights.preset(), 'game', 'Game by default')
        eq(lights.factor(), 1, 'x1 by default')
        local a = actor('cam')
        lights.on(a)
        lights.place(300, 0.55)
        eq(#a.added, 0, 'no light')
    end,

    each_preset_makes_its_lights_deferred_and_movable = function()
        for name, want in pairs(WANT) do
            local lights = world()
            lights.set(name, 1)
            local a = actor('cam')
            lights.on(a)
            eq(#a.added, #want, name .. ': lights')
            for i, c in ipairs(a.added) do
                local place, colour, cd = table.unpack(want[i])
                local what = name .. ' ' .. place
                ok(c.class == 'point class' and c.manual == false and c.transform == IDENTITY and c.deferred == true,
                    what .. ': AddComponentByClass(PointLightComponent, false, identity, true)')
                same(c.calls[1], {'SetMobility', 2}, what .. ': Movable first')
                same(calls(c, 'SetIntensityUnits'), {{1}}, what .. ': candelas')
                same(calls(c, 'SetIntensity'), {{cd}}, what .. ': intensity')
                same(calls(c, 'SetLightColor'), {{{R = colour[1], G = colour[2], B = colour[3], A = 1}, true}},
                    what .. ': colour')
                same(calls(c, 'SetSourceRadius'), {{20}}, what .. ': a soft source')
                same(calls(c, 'SetCastShadows'), {{false}}, what .. ': no shadow')
                same(c.calls[#c.calls], {'finish', false, IDENTITY}, what .. ': FinishAddComponent after the setters')
            end
            lights.place(300, 0.55)
            for i, c in ipairs(a.added) do
                local place = want[i][1]
                local moves = calls(c, 'K2_SetRelativeLocation')
                eq(#moves, 1, name .. ' ' .. place .. ': placed')
                local v, sweep, hit, teleport = table.unpack(moves[1])
                ok(sweep == false and type(hit) == 'table' and teleport == false, 'no sweep, no teleport')
                near(v.X, AT[place][1], 0.01, name .. ' ' .. place .. ' X')
                near(v.Y, AT[place][2], 0.01, name .. ' ' .. place .. ' Y')
                near(v.Z, AT[place][3], 0.01, name .. ' ' .. place .. ' Z')
                same(calls(c, 'SetAttenuationRadius'), {{750}}, name .. ' ' .. place .. ': radius 2.5 times 300 cm')
            end
        end
        -- The key above and left of EVE, nearer the camera; the fill right of her; the rim past her.
        ok(AT.key[3] > 0 and AT.key[2] < 144.576 and AT.key[1] < 262.865, 'key')
        ok(AT.fill[2] > 144.576, 'fill')
        ok(AT.rim[1] > 262.865, 'rim')
        -- Zoomed in to 60 cm: the key and the fill stay as far from her look point as at 300 cm (a point light's
        -- brightness grows as its distance shrinks), in the same direction; the radius stays 750 cm.
        local lights = world()
        lights.set('studio', 1)
        local a = actor('cam')
        lights.on(a)
        lights.place(60, 0.55)
        local s = 1 / math.sqrt(1 + 0.55 * 0.55)
        for i, place in ipairs({'key', 'fill'}) do
            local v = calls(a.added[i], 'K2_SetRelativeLocation')[1][1]
            near(v.X - 60 * s, AT[place][1] - 300 * s, 0.01, place .. ': the same offset from the look point, X')
            near(v.Y - 60 * 0.55 * s, AT[place][2] - 300 * 0.55 * s, 0.01, place .. ': Y')
            near(v.Z, AT[place][3], 0.01, place .. ': Z')
            same(calls(a.added[i], 'SetAttenuationRadius'), {{750}}, place .. ': the same radius near')
        end
    end,

    the_preset_cycles_and_game_removes_the_lights = function()
        local lights = world()
        local a = actor('cam')
        lights.on(a)
        local seen = {}
        for _ = 1, 5 do
            local before = {table.unpack(a.added)}
            lights.next()
            seen[#seen + 1] = lights.preset()
            for _, c in ipairs(before) do
                ok(destroyed(c, a), lights.preset() .. ': the old lights removed')
            end
            eq(#a.added - #before, #(WANT[lights.preset()] or {}), lights.preset() .. ': its own lights made')
        end
        same(seen, {'studio', 'warm', 'cool', 'rim', 'game'}, 'the cycle')
        eq(#a.added, 8, 'Game made none')
    end,

    the_intensity_steps_and_stops_at_its_limits = function()
        local lights = world()
        lights.set('studio', 1)
        local a = actor('cam')
        lights.on(a)
        lights.step(1)
        eq(lights.factor(), 1.25, 'up 0.25')
        same(calls(a.added[1], 'SetIntensity'), {{30}, {37.5}}, 'the key set again')
        same(calls(a.added[2], 'SetIntensity'), {{10}, {12.5}}, 'the fill set again')
        eq(#a.added, 2, 'no light added')
        for _ = 1, 10 do lights.step(1) end
        eq(lights.factor(), 2, 'x2 at most')
        for _ = 1, 20 do lights.step(-1) end
        eq(lights.factor(), 0.25, 'x0.25 at least')
        eq(calls(a.added[1], 'SetIntensity')[#calls(a.added[1], 'SetIntensity')][1], 7.5, 'the key at x0.25')
        -- Game has no light: its intensity does not move.
        lights = world()
        lights.step(1)
        eq(lights.factor(), 1, 'Game: no step')
    end,

    the_lights_move_only_when_the_distance_changes = function()
        local lights = world()
        lights.set('rim', 1)
        local a = actor('cam')
        lights.on(a)
        lights.place(300, 0.55)
        lights.place(300.5, 0.55)
        eq(#calls(a.added[1], 'K2_SetRelativeLocation'), 1, 'under 1 cm: not moved')
        lights.place(310, 0.55)
        eq(#calls(a.added[1], 'K2_SetRelativeLocation'), 2, 'moved')
        lights.next() -- Game: none.
        lights.next() -- Studio: new lights, placed at the next frame at the same distance.
        lights.place(310, 0.55)
        eq(#calls(a.added[#a.added], 'K2_SetRelativeLocation'), 1, 'new lights placed')
    end,

    a_camera_that_goes_takes_its_lights = function()
        local lights = world()
        lights.set('studio', 1)
        local a = actor('cam 1')
        lights.on(a)
        lights.off()
        lights.next()
        lights.step(1)
        lights.place(300, 0.55)
        for _, c in ipairs(a.added) do
            same(c.calls[#c.calls], {'finish', false, IDENTITY}, 'nothing called on the lights of a camera gone')
        end
        eq(#a.added, 2, 'nothing added to it')
        eq(lights.preset(), 'warm', 'the preset still changes')
        local b = actor('cam 2')
        lights.on(b)
        eq(#b.added, 2, 'the next camera gets the preset\'s lights')
        same(calls(b.added[1], 'SetIntensity'), {{37.5}}, 'at the intensity')
        same(calls(b.added[1], 'SetLightColor')[1][1], {R = 1, G = 0.8, B = 0.6, A = 1}, 'Warm')
    end,

    an_engine_failure_turns_the_lights_off_for_this_camera = function()
        local lights = world()
        lights.set('studio', 1)
        local a = actor('cam 1')
        L.fail = 'SetLightColor'
        lights.on(a)
        eq(#L.logs, 1, 'one log line')
        has(L.logs, 'camera: lights off: SetLightColor refused', 'why')
        ok(destroyed(a.added[1], a), 'the light made so far removed')
        L.fail = nil
        lights.next()
        lights.place(300, 0.55)
        eq(#a.added, 1, 'off until the next camera')
        eq(#L.logs, 1, 'still one line')
        local b = actor('cam 2')
        lights.on(b)
        eq(#b.added, 2, 'the next camera has lights again')
        -- A failure while placing also turns them off.
        L.fail = 'K2_SetRelativeLocation'
        lights.place(300, 0.55)
        has(L.logs, 'camera: lights off: K2_SetRelativeLocation refused', 'a place failure')
        ok(destroyed(b.added[1], b) and destroyed(b.added[2], b), 'removed')
    end,

    a_saved_preset_and_intensity_read_back = function()
        local lights = world()
        for _, case in ipairs({{'warm', 1.5, 'warm', 1.5}, {'purple', 1, 'game', 1}, {nil, nil, 'game', 1},
                {'studio', nil, 'studio', 1}, {'studio', 7, 'studio', 2}, {'studio', 0.3, 'studio', 0.25},
                {'studio', 1.1, 'studio', 1}, {'studio', 0 / 0, 'studio', 1}, {'rim', -4, 'rim', 0.25}}) do
            lights.set(case[1], case[2])
            eq(lights.preset(), case[3], 'preset of ' .. tostring(case[1]))
            eq(lights.factor(), case[4], 'factor of ' .. tostring(case[2]))
        end
        same(Lights.ORDER, {'game', 'studio', 'warm', 'cool', 'rim'}, 'the presets in order')
    end,
}

run('lights_test', tests)
