-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The closet camera (closet/ui/camera.lua) over fakes of the controller, its camera manager, EVE, core/actors.lua,
-- core/unreal.lua, the camera file and the pad reads, in tests/lua/fight/enemies/spectate_test.lua's style: the open
-- (an earlier Lua load's camera swept once, the view taken from EVE only, the path kept before the view changes), the
-- region framing (EVE's look point at 0.55 of the half width right of centre, her band filling the height), the FOV
-- axis, the easing, the free mode's keys and pad, the reset, the file, the give-back on every close path and no fight
-- for the view; the preview lights (closet/ui/lights.lua) on the camera actor: their words, the pad's L3, their preset
-- and intensity in the camera's line (an older line without them still read), their end with the camera.
local run = dofile('tests/lua/closet/run.lua')
local Camera = require('closet.ui.camera')

local W -- One case's world.
local function object(path) return {path = path} end
-- A light component of the camera actor: its calls by name, in order.
local LIGHT = {__index = function(_, name)
    return function(self, ...) self.calls[#self.calls + 1] = {name, ...} end
end}
-- The camera actor: object(path) that takes light components (closet/ui/lights.lua's calls).
local function camera_actor(path)
    local a = object(path)
    a.lights = {}
    a.AddComponentByClass = function(self)
        local c = setmetatable({calls = {}}, LIGHT)
        self.lights[#self.lights + 1] = c
        return c
    end
    a.FinishAddComponent = function() end
    return a
end
-- A camera mesh whose moves and FOV are recorded.
local function mesh()
    return {K2_SetWorldLocationAndRotation = function(_, at, rot, sweep, hit, teleport)
            assert(sweep == false and type(hit) == 'table' and teleport == false)
            if W.move_fails then error('move refused', 0) end
            W.moves[#W.moves + 1] = {at = at, rot = rot}
        end,
        SetFieldOfView = function(_, fov) W.fovs[#W.fovs + 1] = fov end}
end
local actors = {
    spawn = function(world, at, rot, look)
        assert(world == 'world' and look.camera == true)
        local d = {actor = camera_actor('cam path ' .. (#W.spawned + 1)), mesh = mesh()}
        d.path = d.actor.path
        W.spawned[#W.spawned + 1] = {at = at, rot = rot, d = d}
        return d
    end,
    same = function(o, path) return o and o.path == path and not W.dead[path] and o or nil end,
    sweep = function(p, kind) W.swept[#W.swept + 1] = p .. ' ' .. kind; return W.old_exists end,
    remove = function(d) W.removed[#W.removed + 1] = d.path; W.dead[d.path] = true end}
local unreal = {valid = function(o) return o end, address = function(o) return o end,
    value_of = function(v) return v end, find = function(path)
        if path == '/Script/Engine.Default__KismetMathLibrary' then return {MakeTransform = function() return {} end} end
        return path
    end}

-- A new world and camera. change(W) runs before the camera is made.
local function world(change)
    W = {views = {}, moves = {}, fovs = {}, spawned = {}, swept = {}, removed = {}, dead = {}, logs = {}, saves = {},
        at = {X = 1000, Y = 2000, Z = 90}, yaw = 30, hh = 90, fov = 90, axis = 1, bits = 0, levels = {0, 0, 0, 0},
        screen = {w = 3840, h = 2160, s = 1}}
    W.eve = object('eve path')
    W.eve.K2_GetActorLocation = function() return W.at end
    W.eve.K2_GetActorRotation = function() return {Pitch = 0, Yaw = W.yaw, Roll = 0} end
    W.eve.CapsuleComponent = {GetScaledCapsuleHalfHeight = function() return W.hh end}
    W.eve.GetWorld = function() return 'world' end
    W.eve.GetFullName = function() return 'SBCharacter eve path' end
    W.view = W.eve
    W.pc = {PlayerCameraManager = {GetCameraLocation = function() return {X = 1, Y = 2, Z = 3} end,
            GetCameraRotation = function() return {Pitch = -10, Yaw = 45, Roll = 0} end,
            GetFOVAngle = function() return W.fov end},
        Player = setmetatable({}, {__index = function(_, k)
            if k == 'AspectRatioAxisConstraint' then return W.axis end
        end}),
        GetViewTarget = function() return W.view end,
        SetViewTargetWithBlend = function(_, target, blend, f, e, lock)
            W.views[#W.views + 1] = {target = target, blend = blend, f = f, e = e, lock = lock, file = W.file}
            W.view = target
        end,
        K2_GetPawn = function() return W.eve end}
    if change then change(W) end
    return Camera.new({unreal = unreal, actors = actors, log = function(m) W.logs[#W.logs + 1] = m end,
        store = {save = function(line) W.saves[#W.saves + 1] = line; W.file = line; return W.save_result ~= false end,
            load = function() return W.file end, clear = function() W.file = nil end},
        pc = function() return W.pc end, her = function() return W.eve end, screen = function() return W.screen end,
        pad_bits = function() return W.bits end, pad_levels = function() return table.unpack(W.levels) end,
        held_keys = function() return W.keys end,
        mouse_wheel = function() local n = W.wheel or 0; W.wheel = 0; return n end,
        pointer = function() if W.ptr then return W.ptr[1], W.ptr[2] end end,
        project = function(at) if W.project then return W.project(at) end end})
end
-- dt s of ticks at 60 fps, region given.
local function frames(c, s, region)
    for _ = 1, math.floor(s * 60 + 0.5) do c.tick(1 / 60, region) end
end
local function last() return W.moves[#W.moves] end
-- The file's fields: path, mode, then the free pose (yaw, pitch, dist, height, pan) as numbers, the light preset and
-- its intensity factor.
local function fields()
    local f = {}
    for x in ((W.file or '') .. '\t'):gmatch('([^\t]*)\t') do f[#f + 1] = x end
    return {path = f[1], mode = f[2], yaw = tonumber(f[3]), pitch = tonumber(f[4]), dist = tonumber(f[5]),
        height = tonumber(f[6]), pan = tonumber(f[7]), preset = f[8], factor = tonumber(f[9]), count = #f}
end
-- The calls named name on light component c, each as its argument list.
local function calls(c, name)
    local out = {}
    for _, call in ipairs(c.calls) do if call[1] == name then out[#out + 1] = {table.unpack(call, 2)} end end
    return out
end
local function near(got, want, tol, what)
    if math.abs(got - want) > tol then error(('%s: got %.4f, want %.4f'):format(what, got, want), 2) end
end
-- T seen from a camera at at turned rot: its x in the half widths right of centre (hfov), its y in the half heights
-- above centre (tanv: tan of half the vertical FOV), its depth along the view.
local function project(at, rot, T, hfov, tanv)
    local P, Y = math.rad(rot.Pitch), math.rad(rot.Yaw)
    local F = {math.cos(P) * math.cos(Y), math.cos(P) * math.sin(Y), math.sin(P)}
    local R = {-math.sin(Y), math.cos(Y), 0}
    local Up = {-math.sin(P) * math.cos(Y), -math.sin(P) * math.sin(Y), math.cos(P)}
    local D = {T.X - at.X, T.Y - at.Y, T.Z - at.Z}
    local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
    local z = dot(D, F)
    return dot(D, R) / z / math.tan(math.rad(hfov / 2)), dot(D, Up) / z / tanv, z
end
-- The camera's angle around EVE in degrees (0 = in front of her), from her place and yaw.
local function around(m)
    local a = math.deg(math.atan(m.at.Y - W.at.Y, m.at.X - W.at.X)) - W.yaw
    return (a + 180) % 360 - 180
end
local TANV = 1 / (16 / 9) -- hfov 90 at 16:9.
-- Where the camera stands for region's framing (hfov 90 at 16:9) panned pan cm right and up cm up.
local function framed_at(region, pan, up)
    local p = Camera.framing(region, 180, 0.55, TANV)
    p.pan, p.height = p.pan + pan, p.height + up
    return (Camera.place(p, W.at, W.yaw, W.at.Z - 90, 0.55))
end
local function gap(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2) end
-- The lines of W.logs that contain s.
local function logged(s)
    local n = 0
    for _, line in ipairs(W.logs) do if line:find(s, 1, true) then n = n + 1 end end
    return n
end

local tests = {
    open_sweeps_spawns_and_takes_the_view = function()
        local c = world(function(w) w.file = 'old path\tregion'; w.old_exists = true end)
        c.open()
        same(W.swept, {'old path camera'}, 'the earlier Lua load\'s camera swept')
        eq(#W.spawned, 1, 'one camera')
        same(W.spawned[1].at, {X = 1, Y = 2, Z = 3}, 'at the game camera')
        same(W.spawned[1].rot, {Pitch = -10, Yaw = 45, Roll = 0}, 'turned as the game camera')
        same(W.fovs, {90}, 'the game camera\'s FOV')
        eq(#W.views, 1, 'the view taken once')
        local v = W.views[1]
        ok(v.target == W.spawned[1].d.actor and v.blend == 0.3 and v.f == 0 and v.e == 0 and v.lock == false,
            'SetViewTargetWithBlend(cam, 0.3, 0, 0, false)')
        eq(v.file:match('^[^\t]*'), 'cam path 1', 'the path kept before the view changed')
        ok(c.running(), 'running')
        c.close()
        c.open()
        eq(#W.swept, 1, 'swept once a Lua load')
    end,

    a_reload_leftover_holding_the_view_gives_it_to_eve_first = function()
        local old = object('old path')
        local c = world(function(w) w.file = 'old path\tfree'; w.view = old; w.old_exists = true end)
        c.tick(1 / 60)
        ok(W.views[1].target == W.eve and W.views[1].blend == 0, 'the view back on EVE with blend 0')
        same(W.swept, {'old path camera'}, 'swept at the first tick')
        eq(fields().path, '', 'the path field cleared')
        eq(fields().mode, 'free', 'the mode kept')
        c.tick(1 / 60)
        eq(#W.swept, 1, 'once')
    end,

    open_refuses_a_view_not_on_eve = function()
        local theater = object('theater')
        local c = world(function(w) w.view = theater end)
        c.open()
        eq(#W.spawned, 0, 'no camera')
        eq(#W.views, 0, 'no SetViewTargetWithBlend')
        ok(not c.running(), 'not running')
        frames(c, 0.1, 'full')
        eq(#W.moves, 0, 'no move')
    end,

    a_failed_file_write_opens_without_a_camera = function()
        local c = world(function(w) w.save_result = false end)
        c.open()
        eq(#W.spawned, 1, 'spawned')
        same(W.removed, {'cam path 1'}, 'removed again')
        eq(#W.views, 0, 'the view never moved')
        ok(not c.running(), 'not running')
    end,

    region_framing_puts_eve_at_78_percent_and_fills_her_band = function()
        local h = 2 * 90
        for name, r in pairs(Camera.REGIONS) do
            local c = world()
            c.open()
            frames(c, 0.05, name)
            local m = last()
            local T = {X = W.at.X, Y = W.at.Y, Z = W.at.Z - 90 + r[1] * h}
            local x, y, z = project(m.at, m.rot, T, 90, TANV)
            near(x, 0.55, 0.01, name .. ': across')
            near(y, 0, 0.01, name .. ': up')
            near(2 * z * TANV, r[2] * h, 0.5, name .. ': the band fills the height')
            near(around(m), r[3], 0.01, name .. ': yaw around her')
            ok(m.rot.Pitch < 0, name .. ': looks down')
        end
        local feet = Camera.REGIONS.feet
        ok(feet[4] > Camera.REGIONS.full[4], 'the feet are seen from higher up')
    end,

    the_fov_axis_rule = function()
        -- MaintainYFOV (0): the FOV is vertical, the horizontal one wider at 16:9.
        for _, case in ipairs({{axis = 1, fov = 90, hfov = 90}, {axis = 0, fov = 60,
                hfov = 2 * math.deg(math.atan(math.tan(math.rad(30)) * 16 / 9))},
                {axis = 2, fov = 70, hfov = 70}}) do
            local c = world(function(w) w.axis, w.fov = case.axis, case.fov end)
            c.open()
            frames(c, 0.05, 'torso')
            local m = last()
            local T = {X = W.at.X, Y = W.at.Y, Z = W.at.Z - 90 + Camera.REGIONS.torso[1] * 180}
            local tanv = math.tan(math.rad(case.hfov / 2)) * 9 / 16
            local x, y = project(m.at, m.rot, T, case.hfov, tanv)
            near(x, 0.55, 0.01, 'axis ' .. case.axis .. ': across')
            near(y, 0, 0.01, 'axis ' .. case.axis .. ': up')
        end
        -- Level, the turn is atan(0.55 * tan(hfov / 2)).
        local at, rot = Camera.place({yaw = 0, pitch = 0, dist = 300, height = 100, pan = 0}, {X = 0, Y = 0, Z = 0}, 0, 0,
            0.55 * math.tan(math.rad(45)))
        same(at, {X = 300, Y = 0, Z = 100}, 'in front of her')
        near(rot.Yaw, 180 - math.deg(math.atan(0.55)), 1e-9, 'turned left by atan(0.55 tan 45)')
        eq(rot.Pitch, 0, 'level')
    end,

    the_pose_eases_between_regions = function()
        local function dist(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2) end
        local c = world()
        c.open()
        frames(c, 0.5, 'full')
        local before = last().at
        local want = Camera.place(Camera.framing('feet', 180, 0.55, TANV), W.at, W.yaw, W.at.Z - 90, 0.55)
        c.tick(1 / 60, 'feet')
        ok(dist(last().at, want) > 0.5 * dist(before, want), 'no jump: one frame goes a little of the way')
        frames(c, 0.35 - 1 / 60, 'feet')
        ok(dist(last().at, want) < 0.05 * dist(before, want), 'within 5% of the way after 0.35 s')
        ok(dist(last().at, want) > 0, 'eased, not there yet')
        frames(c, 1, 'feet')
        ok(dist(last().at, want) < 0.01, 'there after a second')
    end,

    free_mode_steps_and_clamps = function()
        local c = world()
        c.open()
        frames(c, 0.1, 'full')
        local saves = #W.saves
        c.word('cam_left')
        eq(#W.saves, saves, 'a step in region mode pans the framing: no free pose written')
        eq(c.mode(), 'region', 'a step in region mode stays in region mode')
        c.word('cam_mode')
        local f = fields()
        eq(f.mode, 'free', 'free')
        local full = Camera.framing('full', 180, 0.55, TANV)
        near(f.dist, full.dist, 0.01, 'the first free pose is the region framing')
        c.word('cam_left')
        near(fields().yaw, f.yaw + 10, 1e-6, 'left: 10 degrees')
        c.word('cam_right') c.word('cam_right')
        near(fields().yaw, f.yaw - 10, 1e-6, 'right: 10 degrees')
        c.word('cam_up')
        near(fields().pitch, f.pitch + 10, 1e-6, 'up')
        for _ = 1, 20 do c.word('cam_up') end
        eq(fields().pitch, 60, 'pitch clamped at 60')
        for _ = 1, 20 do c.word('cam_down') end
        eq(fields().pitch, -60, 'pitch clamped at -60')
        local d = fields().dist
        c.word('cam_in')
        near(fields().dist, d * 0.9, 0.01, 'in: 10% nearer')
        c.word('cam_out')
        near(fields().dist, d, 0.01, 'out undoes in')
        for _ = 1, 40 do c.word('cam_in') end
        eq(fields().dist, 40, 'distance clamped at 40')
        for _ = 1, 60 do c.word('cam_out') end
        eq(fields().dist, 500, 'distance clamped at 500')
        c.word('cam_mode')
        eq(fields().mode, 'region', 'back to region')
        eq(fields().dist, 500, 'the free pose kept')
    end,

    the_free_pose_follows_eve = function()
        local c = world(function(w) w.file = '\tfree\t0\t0\t300\t100\t0' end)
        c.open()
        frames(c, 0.05, 'full')
        local a = last().at
        near(math.sqrt((a.X - 1000) ^ 2 + (a.Y - 2000) ^ 2), 300, 0.01, '300 cm away')
        near(around(last()), 0, 0.01, 'in front of her')
        W.yaw = 120
        frames(c, 0.05, 'full')
        near(around(last()), 0, 0.01, 'still in front of her after she turned')
    end,

    the_short_way_across_180 = function()
        local c = world(function(w) w.file = '\tfree\t170\t0\t300\t100\t0' end)
        c.open()
        frames(c, 0.05, 'full')
        c.word('cam_left') c.word('cam_left') -- 190, that is -170.
        for _ = 1, 30 do
            c.tick(1 / 60, 'full')
            local a = around(last())
            ok(a >= 169.9 or a <= -169.9, 'behind her all the way: ' .. a)
        end
        near(around(last()), -170, 0.5, 'reached')
    end,

    the_stick_orbits_and_the_triggers_zoom = function()
        local c = world(function(w) w.file = '\tfree\t0\t0\t300\t100\t0' end)
        c.open()
        frames(c, 0.05, 'full')
        W.levels = {0.15, -0.15, 0.15, 0.15}
        local saves = #W.saves
        frames(c, 0.5, 'full')
        eq(#W.saves, saves, 'inside the dead zone: nothing')
        W.levels = {1, 0, 0, 0}
        frames(c, 0.5, 'full')
        eq(#W.saves, saves, 'saved once the stick is back at rest')
        W.levels = {0, 0, 0, 0}
        c.tick(1 / 60, 'full')
        near(fields().yaw, -60, 0.01, 'right at full: 120 degrees a second, the camera to its right')
        W.levels = {0, 1, 0, 0}
        frames(c, 0.25, 'full')
        W.levels = {0, 0, 0, 0}
        c.tick(1 / 60, 'full')
        near(fields().pitch, 20, 0.01, 'up at full: 80 degrees a second')
        W.levels = {0, 0, 0, 1}
        frames(c, 1, 'full')
        W.levels = {0, 0, 0, 0}
        c.tick(1 / 60, 'full')
        near(fields().dist, 150, 0.5, 'RT held 1 s: half the distance')
        W.levels = {0, 0, 0.6, 0}
        frames(c, 1, 'full')
        W.levels = {0, 0, 0, 0}
        c.tick(1 / 60, 'full')
        near(fields().dist, 150 * 2 ^ 0.5, 0.5, 'LT at 0.6 (0.5 past the dead zone) 1 s: x 2^0.5')
        -- In region mode the stick pans the framing: the free pose stays as it was.
        c.word('cam_mode')
        saves = #W.saves
        W.levels = {1, 1, 1, 0}
        frames(c, 0.25, 'full')
        W.levels = {0, 0, 0, 0}
        c.tick(1 / 60, 'full')
        eq(#W.saves, saves, 'region mode: the stick leaves the free pose')
        eq(c.mode(), 'region', 'region mode: the stick stays in region mode')
    end,

    held_keys_orbit_zoom_and_pan_at_a_rate = function()
        -- The native held read (bits: 1 right mouse, 2 middle mouse, 4 Shift, 8 I, 16 J, 32 K, 64 L, 128 U, 256 O):
        -- the step words move nothing; held keys move at the stick's full rates; Shift + I/J/K/L slide.
        local c = world(function(w) w.file = '\tfree\t0\t0\t300\t100\t0'; w.keys = 0 end)
        c.open()
        frames(c, 0.05, 'full')
        local saves = #W.saves
        c.word('cam_left') c.word('cam_in')
        eq(#W.saves, saves, 'the held read is live: the step words move nothing')
        local function hold(bits, s)
            W.keys = bits
            frames(c, s, 'full')
            W.keys = 0
            c.tick(1 / 60, 'full')
        end
        hold(16, 0.5)
        near(fields().yaw, 60, 0.01, 'J held 0.5 s: 120 degrees a second to the left')
        hold(64, 0.25)
        near(fields().yaw, 30, 0.01, 'L held: to the right')
        hold(8, 0.25)
        near(fields().pitch, 20, 0.01, 'I held 0.25 s: 80 degrees a second up')
        hold(32, 0.5)
        near(fields().pitch, -20, 0.01, 'K held: down')
        hold(128, 1)
        near(fields().dist, 150, 0.5, 'U held 1 s: half the distance')
        hold(256, 1)
        near(fields().dist, 300, 0.5, 'O held 1 s: twice')
        hold(4 + 64, 0.25)
        near(fields().pan, 30, 0.01, 'Shift + L: pan, 120 cm a second')
        near(fields().yaw, 30, 0.01, 'Shift + L: no orbit')
        hold(4 + 8, 0.25)
        near(fields().height, 130, 0.01, 'Shift + I: height')
        hold(4 + 128, 1)
        near(fields().dist, 300, 0.5, 'Shift + U is the light\'s: no zoom')
        saves = #W.saves
        W.keys = 16
        frames(c, 0.5, 'full')
        eq(#W.saves, saves, 'written once the keys are let go')
        W.keys = 0
        c.tick(1 / 60, 'full')
        eq(#W.saves, saves + 1, 'written at the release')
        c.word('cam_mode')
        saves = #W.saves
        hold(16 + 8 + 128, 0.5)
        eq(#W.saves, saves, 'region mode: the held keys leave the free pose')
        eq(c.mode(), 'region', 'region mode: the held keys stay in region mode')
    end,

    the_right_drag_orbits_and_the_middle_drag_pans = function()
        local c = world(function(w) w.file = '\tfree\t0\t0\t300\t100\t0'; w.keys = 0; w.ptr = {500, 500} end)
        c.open()
        frames(c, 0.05, 'full')
        W.keys = 1
        c.tick(1 / 60, 'full')
        W.ptr = {540, 520}
        c.tick(1 / 60, 'full')
        W.ptr = {580, 540}
        c.tick(1 / 60, 'full')
        W.keys = 0
        c.tick(1 / 60, 'full')
        near(fields().yaw, -80 * Camera.MOUSE, 1e-6, 'a drag to the right: the camera to its right, as the stick')
        near(fields().pitch, 40 * Camera.MOUSE, 1e-6, 'a drag down raises the camera')
        W.ptr = {0, 0}
        c.tick(1 / 60, 'full')
        near(fields().yaw, -80 * Camera.MOUSE, 1e-6, 'a move with no button moves nothing')
        W.keys = 2
        c.tick(1 / 60, 'full')
        W.ptr = {40, 20}
        c.tick(1 / 60, 'full')
        W.keys = 0
        c.tick(1 / 60, 'full')
        near(fields().pan, -40 * Camera.MPAN, 1e-6, 'a middle drag to the right moves the look point left')
        near(fields().height, 100 + 20 * Camera.MPAN, 1e-6, 'a middle drag down moves it up')
        -- No mouse position (the kit hidden): no drag.
        W.ptr = nil
        W.keys = 1
        frames(c, 0.1, 'full')
        W.keys = 0
        c.tick(1 / 60, 'full')
        near(fields().yaw, -80 * Camera.MOUSE, 1e-6, 'no mouse position: nothing')
    end,

    a_right_click_without_a_drag_is_back_at_its_release = function()
        local c = world(function(w) w.keys = 0; w.ptr = {500, 500} end)
        eq(c.hold_back(), false, 'no camera: Back at once')
        c.open()
        frames(c, 0.05, 'full')
        eq(c.hold_back(), false, 'right mouse not held: Back at once')
        W.keys = 1
        eq(c.hold_back(), true, 'held: Back waits for the release')
        W.ptr = {503, 504}
        c.tick(1 / 60, 'full')
        eq(c.take_back(), false, 'not yet released')
        W.keys = 0
        c.tick(1 / 60, 'full')
        eq(c.take_back(), true, 'released after 7 units: Back')
        eq(c.take_back(), false, 'once')
        W.keys = 1
        eq(c.hold_back(), true, 'held again')
        W.ptr = {520, 504}
        c.tick(1 / 60, 'full')
        W.keys = 0
        c.tick(1 / 60, 'full')
        eq(c.take_back(), false, 'a drag of 17 units is no Back')
        -- A pending Back goes with the close.
        W.keys = 1
        c.hold_back()
        c.close()
        eq(c.take_back(), false, 'closed: no Back left')
        -- An older DLL (no held read): Back at once.
        c = world(function(w) w.ptr = {500, 500} end)
        c.open()
        eq(c.hold_back(), false, 'no held read: Back at once')
    end,

    region_mode_stick_and_keys_pan_the_framing = function()
        local c = world(function(w) w.keys = 0 end)
        c.open()
        frames(c, 0.05, 'full')
        local saves = #W.saves
        W.levels = {1, 0, 0, 0}
        frames(c, 0.25, 'full')
        W.levels = {0, 0, 0, 0}
        frames(c, 1, 'full')
        ok(gap(last().at, framed_at('full', 30, 0)) < 0.05, 'stick right 0.25 s: the framing pans 30 cm right')
        eq(c.mode(), 'region', 'the stick stays in region mode')
        W.keys = 8 -- I
        frames(c, 0.25, 'full')
        W.keys = 16 -- J
        frames(c, 0.5, 'full')
        W.keys = 0
        frames(c, 1, 'full')
        ok(gap(last().at, framed_at('full', -30, 30)) < 0.05, 'I held 0.25 s: 30 cm up; J held 0.5 s: 60 cm left')
        eq(c.mode(), 'region', 'the keys stay in region mode')
        eq(#W.saves, saves, 'a region pan writes no free pose')
        W.keys = 8
        frames(c, 5, 'full')
        W.keys = 0
        frames(c, 1, 'full')
        ok(gap(last().at, framed_at('full', -30, 49.5)) < 0.05, 'clamped at a quarter of the frame: 49.5 cm up')
        frames(c, 1, 'torso')
        frames(c, 1, 'full')
        ok(gap(last().at, framed_at('full', 0, 0)) < 0.05, 'a region change clears the pan')
        W.keys = 64 -- L
        frames(c, 0.25, 'full')
        W.keys = 0
        c.tick(1 / 60, 'full')
        c.word('cam_reset')
        local f, want = fields(), Camera.framing('full', 180, 0.55, TANV)
        near(f.pan, 0, 0.01, 'Reset: no pan in the free pose')
        near(f.height, want.height, 0.01, 'Reset: the region\'s own height')
        c.word('cam_mode')
        frames(c, 1, 'full')
        ok(gap(last().at, framed_at('full', 0, 0)) < 0.05, 'Reset cleared the pan')
        -- An older DLL (no held read): the step words pan.
        c = world()
        c.open()
        frames(c, 0.05, 'full')
        c.word('cam_left') c.word('cam_up')
        frames(c, 1, 'full')
        ok(gap(last().at, framed_at('full', -10, 10)) < 0.05, 'cam_left and cam_up: 10 cm each')
        eq(c.mode(), 'region', 'the words stay in region mode')
    end,

    a_long_region_pan_keeps_eve_on_screen = function()
        -- EVE's look point (NDC 0.55 right, mid height) stays between 0.35 and 0.85 of the half width
        -- (Camera.RPAN) and within half a half height up or down however long a pan key is held.
        for _, case in ipairs({{16, 'J', 0.85, 0}, {64, 'L', 0.35, 0}, {8, 'I', 0.55, -0.5}, {32, 'K', 0.55, 0.5}}) do
            local c = world(function(w) w.keys = 0 end)
            c.open()
            frames(c, 0.05, 'full')
            W.keys = case[1]
            frames(c, 5, 'full')
            W.keys = 0
            frames(c, 1, 'full')
            local T = {X = W.at.X, Y = W.at.Y, Z = W.at.Z - 90 + Camera.framing('full', 180, 0.55, TANV).height}
            local x, y = project(last().at, last().rot, T, 90, TANV)
            near(x, case[3], 0.03, case[2] .. ' held 5 s: her look point across')
            near(y, case[4], 0.03, case[2] .. ' held 5 s: her look point up')
        end
    end,

    free_mode_stick_orbits_and_x_held_pans = function()
        local c = world(function(w) w.file = '\tfree\t0\t0\t300\t100\t0'; w.keys = 0 end)
        c.open()
        frames(c, 0.05, 'full')
        local function rest() W.levels, W.bits, W.keys = {0, 0, 0, 0}, 0, 0; c.tick(1 / 60, 'full') end
        W.levels = {1, 0, 0, 0}
        frames(c, 0.5, 'full')
        rest()
        near(fields().yaw, -60, 0.01, 'the right stick orbits')
        W.bits = 1
        c.tick(1 / 60, 'full')
        W.levels = {1, 0, 0, 0}
        frames(c, 0.25, 'full')
        W.levels = {0, 0, 0, 0}
        c.tick(1 / 60, 'full')
        rest()
        near(fields().pan, 30, 0.01, 'X held + stick: pan')
        near(fields().yaw, -60, 0.01, 'X held + stick: no orbit')
        eq(c.mode(), 'free', 'X with the stick toggles nothing')
        W.keys = 16
        frames(c, 0.5, 'full')
        rest()
        near(fields().yaw, 0, 0.01, 'J orbits')
        W.keys = 4 + 64
        frames(c, 0.25, 'full')
        rest()
        near(fields().pan, 60, 0.01, 'Shift + L pans')
        near(fields().yaw, 0, 0.01, 'Shift + L: no orbit')
    end,

    a_right_click_with_jitter_in_region_mode_stays_region_and_is_back = function()
        local c = world(function(w) w.keys = 0; w.ptr = {500, 500} end)
        c.open()
        frames(c, 0.05, 'full')
        eq(c.mode(), 'region', 'starts in region mode')
        local saves = #W.saves
        W.keys = 1
        ok(c.hold_back(), 'the press may start a drag')
        c.tick(1 / 60, 'full')
        W.ptr = {502, 501}
        c.tick(1 / 60, 'full')
        W.keys = 0
        c.tick(1 / 60, 'full')
        eq(c.mode(), 'region', '3 units of jitter: still region mode')
        eq(#W.saves, saves, '3 units of jitter: nothing written')
        eq(c.take_back(), true, '3 units of jitter: Back')
    end,

    a_right_drag_in_region_mode_switches_to_free = function()
        local c = world(function(w) w.keys = 0; w.ptr = {500, 500} end)
        c.open()
        frames(c, 0.05, 'full')
        W.keys = 1
        ok(c.hold_back(), 'the press may start a drag')
        for i = 1, 20 do W.ptr = {500 + 10 * i, 500}; c.tick(1 / 60, 'full') end
        W.keys = 0
        c.tick(1 / 60, 'full')
        eq(c.mode(), 'free', 'the drag switched to free mode')
        near(fields().yaw, Camera.REGIONS.full[3] - 200 * Camera.MOUSE, 0.01, 'orbited from the region framing')
        near(fields().dist, Camera.framing('full', 180, 0.55, TANV).dist, 0.01, 'at the region\'s distance')
        eq(c.take_back(), false, 'a drag is no Back')
        -- A saved free pose: the drag starts from it.
        c = world(function(w) w.file = '\tregion\t0\t0\t300\t100\t0'; w.keys = 0; w.ptr = {500, 500} end)
        c.open()
        frames(c, 0.05, 'full')
        W.keys = 1
        c.tick(1 / 60, 'full')
        W.ptr = {540, 500}
        c.tick(1 / 60, 'full')
        W.keys = 0
        c.tick(1 / 60, 'full')
        eq(c.mode(), 'free', 'free mode')
        near(fields().yaw, -40 * Camera.MOUSE, 0.01, 'orbited from the saved free pose')
        near(fields().dist, 300, 0.01, 'the saved free pose\'s distance')
        -- A right click with no move stays in region mode.
        c = world(function(w) w.keys = 0; w.ptr = {500, 500} end)
        c.open()
        frames(c, 0.05, 'full')
        W.keys = 1
        c.tick(1 / 60, 'full')
        W.keys = 0
        c.tick(1 / 60, 'full')
        eq(c.mode(), 'region', 'a click is no drag')
        -- A middle drag pans in region mode.
        W.keys = 2
        c.tick(1 / 60, 'full')
        W.ptr = {540, 520}
        c.tick(1 / 60, 'full')
        W.keys = 0
        frames(c, 1, 'full')
        eq(c.mode(), 'region', 'a middle drag stays in region mode')
        ok(gap(last().at, framed_at('full', -40 * Camera.MPAN, 20 * Camera.MPAN)) < 0.05,
            'a middle drag pans the framing as it pans the free pose')
    end,

    -- The mouse wheel (notches since the last read, up positive): each notch up zooms in by ZOOM, down out. In region
    -- mode a turn goes to free mode first, as a right drag does. Turns before the open are dropped.
    the_mouse_wheel_zooms = function()
        local c = world(function(w) w.file = '	free	0	0	300	100	0'; w.wheel = 5 end)
        c.open()
        frames(c, 0.05, 'full')
        near(fields().dist, 300, 0.01, 'the turns before the open zoom nothing')
        W.wheel = 2
        c.tick(1 / 60, 'full')
        c.tick(1 / 60, 'full')
        near(fields().dist, 300 * (1 - Camera.ZOOM) ^ 2, 0.01, 'two notches up: in by ZOOM twice')
        W.wheel = -2
        c.tick(1 / 60, 'full')
        c.tick(1 / 60, 'full')
        near(fields().dist, 300, 0.01, 'two notches down: back out')
        c = world(function(w) w.keys = 0 end)
        c.open()
        frames(c, 0.05, 'full')
        eq(c.mode(), 'region', 'region mode at first')
        W.wheel = 1
        c.tick(1 / 60, 'full')
        c.tick(1 / 60, 'full')
        eq(c.mode(), 'free', 'a wheel turn goes to free mode')
        near(fields().dist, Camera.framing('full', 180, 0.55, TANV).dist * (1 - Camera.ZOOM), 0.01,
            'zoomed in from the region framing')
    end,

    -- shot() gives the camera's place, its look point and the screen's vertical half-angle tangent as last placed
    -- (closet/thumbs.lua's snap); nil with no camera.
    shot_is_the_last_placed_view = function()
        local c = world()
        eq(c.shot(), nil, 'no camera: no shot')
        c.open()
        frames(c, 0.5, 'full')
        local s = c.shot()
        ok(s and gap(s.at, last().at) < 1e-6, 'at the camera')
        ok(s.look and s.tanv > 0, 'a look point and the lens')
        c.close()
        eq(c.shot(), nil, 'closed: no shot')
    end,

    the_lens_is_measured_from_the_screen = function()
        local hfov = 90 -- What the view really renders.
        local tanv = math.tan(math.rad(hfov / 2)) * 9 / 16
        local c = world(function(w)
            w.axis, w.fov = 0, 90 -- The read says MaintainYFOV: the code's own lens is 16/9 too wide.
            w.project = function(at)
                local m = last()
                if not m then return nil end
                local x, y = project(m.at, m.rot, at, hfov, tanv)
                return {width = 3840, height = 2160, screen = {x = (1 + x) / 2 * 3840, y = (1 - y) / 2 * 2160}}
            end
        end)
        c.open()
        frames(c, 1, 'full')
        local m, r = last(), Camera.REGIONS.full
        local T = {X = W.at.X, Y = W.at.Y, Z = W.at.Z - 90 + r[1] * 180}
        local x, y, z = project(m.at, m.rot, T, hfov, tanv)
        near(x, 0.55, 0.01, 'across, by the engine projection')
        near(y, 0, 0.01, 'up')
        near(2 * z * tanv, r[2] * 180, 1, 'her band fills the real height')
        eq(logged('camera: lens measured, tan(hfov/2)=1.000'), 1, 'the measured lens logged')
        frames(c, 1, 'full')
        eq(logged('camera: lens measured'), 1, 'once an open')
        c.close()
        frames(c, 0.5)
        c.open()
        frames(c, 1, 'full')
        eq(logged('camera: lens measured'), 2, 'again at the next open')
        -- No projection (the kit hidden): the formula's lens, nothing logged.
        c = world()
        c.open()
        frames(c, 1, 'full')
        eq(logged('camera: lens measured'), 0, 'no projection: nothing measured')
    end,

    a_wrong_lens_reading_is_never_taken = function()
        -- In game a reading taken while the view still lagged put the look point at x 2.5: tan 0.170 for a 0.767
        -- lens. The camera stood ten metres off. Only a tangent one of the axis rules can give is taken.
        local hfov = 90
        local tanv = math.tan(math.rad(hfov / 2)) * 9 / 16
        local calls = 0
        local c = world(function(w)
            w.axis, w.fov = 0, 90
            w.project = function(at)
                local m = last()
                if not m then return nil end
                calls = calls + 1
                if calls <= 3 then
                    return {width = 3840, height = 2160, screen = {x = (1 + 2.5) / 2 * 3840, y = 1080}}
                end
                local x, y = project(m.at, m.rot, at, hfov, tanv)
                return {width = 3840, height = 2160, screen = {x = (1 + x) / 2 * 3840, y = (1 - y) / 2 * 2160}}
            end
        end)
        c.open()
        frames(c, 1, 'full')
        eq(logged('camera: lens measured, tan(hfov/2)=1.000'), 1, 'the first good reading after the wrong ones')
        eq(logged('tan(hfov/2)=0.'), 0, 'no wrong tangent taken')
        -- Only wrong readings: the formula's lens stays, said once.
        c = world(function(w)
            w.project = function()
                if not last() then return nil end
                return {width = 3840, height = 2160, screen = {x = (1 + 2.5) / 2 * 3840, y = 1080}}
            end
        end)
        c.open()
        frames(c, 2, 'full')
        eq(logged('camera: lens measured'), 0, 'nothing measured')
        eq(logged('camera: lens not measured'), 1, 'said once')
        local m, r = last(), Camera.REGIONS.full
        local T = {X = W.at.X, Y = W.at.Y, Z = W.at.Z - 90 + r[1] * 180}
        local x = project(m.at, m.rot, T, 90, 9 / 16)
        near(x, 0.55, 0.01, 'the formula lens frames her')
        -- The vertical axis rule: the read says horizontal, the view keeps a 60 degree vertical FOV.
        local vfov = 60
        local tv = math.tan(math.rad(vfov / 2))
        c = world(function(w)
            w.axis, w.fov = 1, vfov
            w.project = function(at)
                local m = last()
                if not m then return nil end
                local px, py = project(m.at, m.rot, at, 2 * math.deg(math.atan(tv * 16 / 9)), tv)
                return {width = 3840, height = 2160, screen = {x = (1 + px) / 2 * 3840, y = (1 - py) / 2 * 2160}}
            end
        end)
        c.open()
        frames(c, 1, 'full')
        eq(logged(string.format('camera: lens measured, tan(hfov/2)=%.3f', tv * 16 / 9)), 1, 'the vertical rule')
    end,

    x_toggles_on_release_only_without_the_stick = function()
        local c = world()
        c.open()
        c.tick(1 / 60, 'full')
        W.bits = 1
        frames(c, 0.2, 'full')
        eq(fields().mode, 'region', 'held: no toggle yet')
        W.bits = 0
        c.tick(1 / 60, 'full')
        eq(fields().mode, 'free', 'released without the stick: free')
        local f = fields()
        W.bits = 1
        c.tick(1 / 60, 'full')
        W.levels = {1, 1, 0, 0}
        frames(c, 0.25, 'full')
        W.levels = {0, 0, 0, 0}
        c.tick(1 / 60, 'full')
        W.bits = 0
        c.tick(1 / 60, 'full')
        eq(fields().mode, 'free', 'the stick moved during the hold: no toggle')
        near(fields().height, f.height + 30, 0.01, 'X held + stick up: height, 120 cm a second')
        near(fields().pan, f.pan + 30, 0.01, 'X held + stick right: pan')
        near(fields().yaw, f.yaw, 1e-6, 'no orbit while X is held')
        -- X held at the open never toggles at its release.
        local d = world()
        W.bits = 1
        d.open()
        frames(d, 0.1, 'full')
        W.bits = 0
        d.tick(1 / 60, 'full')
        eq(d.mode(), 'region', 'a hold from before the open is no tap')
    end,

    r3_and_cam_reset_set_the_free_pose_to_the_region_framing = function()
        local c = world(function(w) w.file = '\tregion\t90\t40\t480\t20\t50' end)
        c.open()
        frames(c, 0.1, 'torso')
        W.bits = 4
        c.tick(1 / 60, 'torso')
        local f, want = fields(), Camera.framing('torso', 180, 0.55, TANV)
        eq(f.mode, 'free', 'reset goes to free')
        for _, k in ipairs({'yaw', 'pitch', 'dist', 'height', 'pan'}) do near(f[k], want[k], 0.01, 'R3: ' .. k) end
        frames(c, 0.2, 'torso')
        W.bits = 0
        c.tick(1 / 60, 'torso')
        eq(fields().mode, 'free', 'one reset a press')
        c.word('cam_left')
        c.word('cam_reset')
        near(fields().yaw, want.yaw, 0.01, 'cam_reset')
        eq(fields().mode, 'free', 'stays free')
    end,

    the_file_survives_a_new_camera = function()
        local c = world()
        c.open()
        c.tick(1 / 60, 'full')
        c.word('cam_mode')
        c.word('cam_left')
        c.close()
        frames(c, 0.5)
        local file = W.file
        local f = fields()
        eq(f.path, '', 'no camera left in the file')
        c = world(function(w) w.file = file end)
        c.open()
        eq(c.mode(), 'free', 'the mode read at the first open')
        c.word('cam_right')
        near(fields().yaw, f.yaw - 10, 0.01, 'the pose read at the first open')
        -- A bad line keeps the defaults.
        for _, bad in ipairs({'\tsideways\tx\t1\t2\t3\t4', '\tfree\tnan\t0\t300\t100\t0', 'garbage'}) do
            c = world(function(w) w.file = bad end)
            c.open()
            frames(c, 0.05, 'full')
            local mode = c.mode()
            ok(mode == 'region' or bad:find('\tfree\t', 1, true), 'mode default: ' .. bad)
            c.word('cam_mode')
            c.word('cam_mode')
            ok(c.mode() == mode, 'toggles: ' .. bad)
            if mode == 'free' then
                near(fields().dist, Camera.framing('full', 180, 0.55, TANV).dist, 0.01, 'no pose read: ' .. bad)
            end
        end
    end,

    reset_stellar_closet_forgets_the_mode_and_the_pose = function()
        -- The menu's Reset answer: close, then forget. Region mode, no free pose; the file keeps the closed camera's
        -- path while it blends out (a Lua load then still sweeps it) and is cleared once the camera is removed.
        local c = world(function(w) w.file = '\tfree\t90\t40\t480\t20\t50' end)
        c.open()
        frames(c, 0.1, 'full')
        c.close()
        c.forget()
        eq(c.mode(), 'region', 'region mode')
        local f = fields()
        eq(f.path, 'cam path 1', 'the path kept while it blends out')
        eq(f.mode, 'region', 'region in the file')
        eq(f.yaw, nil, 'no free pose in the file')
        frames(c, 0.35)
        same(W.removed, {'cam path 1'}, 'removed after the blend')
        eq(W.file, nil, 'the file cleared once the camera is removed')
        -- The next open is in region mode; cam_mode makes a new free pose from the region's framing.
        c.open()
        eq(c.mode(), 'region', 'the next open: region mode')
        frames(c, 0.05, 'full')
        c.word('cam_mode')
        near(fields().yaw, Camera.framing('full', 180, 0.55, TANV).yaw, 0.01, 'a new free pose, not the old one')
        -- With no camera alive or blending out, the file is cleared at once; a new Camera reads nothing back.
        c = world(function(w) w.file = '\tfree\t90\t40\t480\t20\t50' end)
        c.tick(1 / 60)
        c.forget()
        eq(W.file, nil, 'no camera: cleared at once')
        c = world(function(w) w.file = nil end)
        c.open()
        eq(c.mode(), 'region', 'a restart after the reset: region mode')
    end,

    close_gives_the_view_back_while_ours = function()
        local c = world()
        c.open()
        frames(c, 0.1, 'full')
        local d = W.spawned[1].d
        c.close()
        eq(#W.views, 2, 'given back once')
        ok(W.views[2].target == W.eve and W.views[2].blend == 0.3, 'to the view target from before, blend 0.3')
        same(W.removed, {}, 'the actor stays for the blend')
        ok(not c.running(), 'stopped')
        local moves = #W.moves
        frames(c, 0.2)
        same(W.removed, {}, 'not before 0.3 s')
        frames(c, 0.15)
        same(W.removed, {d.path}, 'removed after the blend')
        eq(fields().path, '', 'the path field cleared')
        eq(#W.moves, moves, 'no move once closed')
        -- The view target from before gone: the pawn.
        local other = object('other pawn')
        c = world()
        c.open()
        W.dead['eve path'] = true
        W.pc.K2_GetPawn = function() return other end
        c.close()
        ok(W.views[2].target == other, 'the pawn when the view target from before is gone')
    end,

    no_fight_once_the_game_took_the_view = function()
        local theater = object('theater')
        local c = world()
        c.open()
        frames(c, 0.1, 'full')
        local moves = #W.moves
        W.view = theater
        frames(c, 0.5, 'full')
        eq(#W.views, 1, 'no SetViewTargetWithBlend')
        eq(#W.moves, moves, 'stopped driving')
        ok(not c.running(), 'stopped')
        same(W.removed, {'cam path 1'}, 'removed after the blend time')
        c.close()
        eq(#W.views, 1, 'close gives nothing back')
        W.view = W.eve
        c.open()
        eq(#W.views, 2, 'the next open takes it again')
        -- Taken since the last tick: close gives nothing back either.
        c = world()
        c.open()
        W.view = theater
        c.close()
        eq(#W.views, 1, 'a close finds the view taken: no call')
        frames(c, 0.35)
        same(W.removed, {'cam path 1'}, 'removed after the blend time')
    end,

    a_map_change_leaves_nothing_to_give_back = function()
        local c = world()
        c.open()
        frames(c, 0.1, 'full')
        W.dead['cam path 1'] = true
        c.tick(1 / 60, 'full')
        ok(not c.running(), 'stopped')
        eq(fields().path, '', 'the path field cleared')
        c.close()
        eq(#W.views, 1, 'no call for the dead camera')
    end,

    stop_gives_back_at_once = function()
        local c = world()
        c.open()
        frames(c, 0.1, 'full')
        c.stop()
        ok(W.views[2].target == W.eve and W.views[2].blend == 0, 'blend 0')
        same(W.removed, {'cam path 1'}, 'removed at once')
        eq(fields().path, '', 'the path field cleared')
        -- A camera closed just before coop off goes at once too.
        c = world()
        c.open()
        c.close()
        c.stop()
        same(W.removed, {'cam path 1'}, 'the blending one removed at once')
        -- An open while the last one blends out removes it first: one camera at a time.
        c = world()
        c.open()
        c.close()
        c.open()
        same(W.removed, {'cam path 1'}, 'the old one first')
        eq(#W.spawned, 2, 'then the new one')
    end,

    an_engine_error_logs_once_and_gives_the_view_back = function()
        local c = world()
        c.open()
        W.move_fails = true
        frames(c, 0.2, 'full')
        local n = 0
        for _, line in ipairs(W.logs) do if line:find('move refused', 1, true) then n = n + 1 end end
        eq(n, 1, 'one log line')
        ok(not c.running(), 'dropped')
        ok(W.views[2] and W.views[2].target == W.eve, 'the view given back')
    end,

    the_light_words_set_the_preset_and_the_intensity_kept_in_the_line = function()
        local c = world()
        c.word('light_next')
        eq(c.light(), 'game', 'no camera: no light word')
        c.open()
        frames(c, 0.05, 'full')
        local a = W.spawned[1].d.actor
        eq(#a.lights, 0, 'Game: no light')
        c.word('light_next')
        eq(#a.lights, 2, 'Studio: two lights on the camera actor')
        local f = fields()
        eq(f.preset, 'studio', 'the preset in the line')
        eq(f.factor, 1, 'x1 in the line')
        eq(f.count, 9, 'nine fields')
        eq(f.yaw, nil, 'no free pose: empty pose fields')
        c.word('light_up')
        eq(fields().factor, 1.25, 'light_up: x1.25')
        c.word('light_down') c.word('light_down')
        eq(fields().factor, 0.75, 'light_down twice: x0.75')
        local p, x = c.light()
        ok(p == 'studio' and x == 0.75, 'the hint\'s preset and intensity')
        -- They follow the camera: placed in its frame as it moves.
        frames(c, 0.05, 'feet')
        ok(#calls(a.lights[1], 'K2_SetRelativeLocation') > 0, 'placed')
        c.close()
        frames(c, 0.35)
        same(W.removed, {'cam path 1'}, 'the lights go with the camera actor')
        for _, l in ipairs(a.lights) do eq(#calls(l, 'K2_DestroyComponent'), 0, 'no call: they went with it') end
        c.word('light_next')
        eq(#a.lights, 2, 'closed: no light word')
        eq(c.light(), 'studio', 'closed: the preset kept')
        -- A new camera (a restart) reads them back with the pose.
        local file = W.file
        c = world(function(w) w.file = file end)
        c.open()
        local b = W.spawned[1].d.actor
        eq(#b.lights, 2, 'Studio again')
        same(calls(b.lights[1], 'SetIntensity'), {{30 * 0.75}}, 'at x0.75')
        -- Game removes them.
        for _ = 1, 4 do c.word('light_next') end
        eq(fields().preset, 'game', 'back to Game')
        eq(#b.lights, 8, 'Warm, Cool and Rim made theirs')
        for _, l in ipairs(b.lights) do eq(#calls(l, 'K2_DestroyComponent'), 1, 'each removed once') end
    end,

    an_older_line_without_the_light_fields_still_loads = function()
        local c = world(function(w) w.file = '\tfree\t0\t0\t300\t100\t0' end)
        c.open()
        eq(c.mode(), 'free', 'the mode read')
        local p, x = c.light()
        ok(p == 'game' and x == 1, 'Game x1')
        eq(#W.spawned[1].d.actor.lights, 0, 'no light')
        c.word('cam_left')
        local f = fields()
        near(f.dist, 300, 0.01, 'the pose read')
        near(f.yaw, 10, 0.01, 'the step on the pose read')
        ok(f.preset == 'game' and f.factor == 1, 'Game x1 written')
        -- A line with no free pose and lights: the empty pose fields read as none.
        c = world(function(w) w.file = '\tregion\t\t\t\t\t\twarm\t1.50' end)
        c.open()
        p, x = c.light()
        ok(p == 'warm' and x == 1.5, 'Warm x1.5 read')
        eq(#W.spawned[1].d.actor.lights, 2, 'its lights')
        c.word('cam_mode')
        near(fields().dist, Camera.framing('full', 180, 0.55, TANV).dist, 0.01, 'no free pose read')
    end,

    the_pad_l3_cycles_the_preset_once_a_press = function()
        local c = world()
        W.bits = 2
        c.open()
        frames(c, 0.1, 'full')
        W.bits = 0
        c.tick(1 / 60, 'full')
        eq(c.light(), 'game', 'L3 held at the open: no press')
        W.bits = 2
        frames(c, 0.3, 'full')
        eq(c.light(), 'game', 'the preset changes at the release')
        W.bits = 0
        c.tick(1 / 60, 'full')
        eq(c.light(), 'studio', 'one step a press, in region mode too')
        eq(fields().preset, 'studio', 'written')
        frames(c, 0.1, 'full')
        eq(c.light(), 'studio', 'once')
        W.bits = 2
        c.tick(1 / 60, 'full')
        W.bits = 0
        c.tick(1 / 60, 'full')
        eq(c.light(), 'warm', 'the next press')
        eq(c.mode(), 'region', 'L3 is not X')
    end,

    the_pad_l3_held_with_a_trigger_steps_the_intensity = function()
        local c = world(function(w) w.file = '\tfree\t0\t0\t300\t100\t0\tstudio\t1.00' end)
        local function step(bits, levels)
            W.bits, W.levels = bits, levels
            c.tick(1 / 60, 'full')
        end
        W.bits, W.levels = 2, {0, 0, 0, 1}
        c.open()
        frames(c, 0.1, 'full')
        step(0, {0, 0, 0, 0})
        local p, x = c.light()
        ok(p == 'studio' and x == 1, 'L3 and RT held at the open: no step, no next preset')
        step(2, {0, 0, 0, 0})
        step(2, {0, 0, 0, 1})
        p, x = c.light()
        ok(p == 'studio' and x == 1.25, 'L3 held, RT pulled: x1.25')
        frames(c, 0.3, 'full')
        eq(select(2, c.light()), 1.25, 'one step a pull')
        step(2, {0, 0, 0, 0})
        step(2, {0, 0, 1, 0})
        eq(select(2, c.light()), 1, 'L3 held, LT pulled: x1')
        frames(c, 0.3, 'full')
        step(2, {0, 0, 0, 0})
        step(2, {0, 0, 1, 0})
        eq(select(2, c.light()), 0.75, 'the next LT pull: x0.75')
        eq(fields().factor, 0.75, 'written')
        step(2, {0, 0, 0, 0})
        step(0, {0, 0, 0, 0})
        eq(c.light(), 'studio', 'L3 released after a trigger: no next preset')
        c.word('cam_left')
        near(fields().dist, 300, 0.01, 'no zoom while L3 is held')
        eq(c.mode(), 'free', 'L3 is not X')
        -- Without L3 the triggers zoom again.
        W.levels = {0, 0, 0, 1}
        frames(c, 0.5, 'full')
        step(0, {0, 0, 0, 0})
        ok(fields().dist < 300, 'RT alone zooms in')
        eq(select(2, c.light()), 0.75, 'RT alone: no step')
    end,

    reset_stellar_closet_also_forgets_the_lights = function()
        local c = world(function(w) w.file = '\tregion\t\t\t\t\t\twarm\t1.50' end)
        c.open()
        frames(c, 0.05, 'full')
        c.close()
        c.forget()
        local p, x = c.light()
        ok(p == 'game' and x == 1, 'Game x1')
        frames(c, 0.35)
        eq(W.file, nil, 'the file cleared once the camera is removed')
    end,

    regions_of_slots_and_tabs = function()
        for id, want in pairs({Gloves = 'hands', Fingernails = 'hands', TattooHand = 'hands', Shoes = 'feet',
                Toenails = 'feet', TattooFoot = 'feet', full = 'full', body = 'full', BaseBody = 'full', Chest = 'torso',
                Hair = 'head', head = 'head', Pants = 'hips', Legs = 'legs', Sleeves = 'arms', intimate = 'hips',
                weapon = 'full', FullOutfit = 'full'}) do
            eq(Camera.region(id), want, id)
        end
    end,
}

run('camera_test', tests)
