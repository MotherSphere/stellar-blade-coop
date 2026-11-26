-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- coop closet probe (closet/ui/probe.lua) over a fake kit and fake widgets: the runner (steps frames apart, PASS and
-- FAIL lines, the first FAIL ends a test, parts that die, calls that throw, the timeout, off, a second run, coop off,
-- the group added once, input always given back), its console words, and the five tests of the game's parts.
local run = dofile('tests/lua/closet/run.lua')
package.loaded.UEHelpers = {GetPlayer = function() return nil end}
FText = function(s) return {text = s, ToString = function(self) return self.text end} end
FName = function(s) return s end

local function fake_kit()
    local k = {up = true, added = {}, shown = {}, made = {}, dropped = 0, held = nil, inputs = {}, views = {},
        widgets = {}, paused_now = false, refocused = 0}
    function k.ready() return k.up end
    function k.off() return false end
    function k.add(name) k.added[#k.added + 1] = name; k.views[name] = {} end
    function k.view(name) return k.up and k.views[name] or nil end
    function k.show(name, on) k.shown[name] = on end
    function k.part(group, class_path, x, y, w, h, fill, hit)
        if not k.up or not k.views[group] then return nil, 'part: the UI is not up' end
        local make = k.widgets[class_path]
        if not make then return nil, 'part: not in this game build' end
        local widget = make()
        if fill then fill(widget) end
        local rec = {o = widget, live = true, class = class_path, x = x, y = y, hit = hit}
        k.made[#k.made + 1] = rec
        return rec
    end
    function k.alive(rec) return rec and rec.live and k.up and rec.o or nil end
    function k.drop(rec) if rec.live then rec.live = false; k.dropped = k.dropped + 1 end end
    function k.input(on, who)
        k.inputs[#k.inputs + 1] = {on, who}
        if on then k.held = who elseif k.held == who then k.held = nil end
    end
    function k.holding() return k.held ~= nil end
    function k.refocus() k.refocused = k.refocused + 1 end
    function k.paused() return k.paused_now end
    return k
end

local function rig(tests, kit)
    local r = {log = {}, now = 10, kit = kit or fake_kit()}
    package.loaded['closet.ui.probe'] = nil
    local Probe = require('closet.ui.probe')
    r.Probe = Probe
    r.p = Probe.new({kit = function() return r.kit end, log = function(m) r.log[#r.log + 1] = m end,
        clock = function() return r.now end, tests = tests})
    r.ticks = function(n) for _ = 1, n or 1 do r.p.tick() end end
    return r
end
local function has(r, needle)
    for _, line in ipairs(r.log) do if line:find(needle, 1, true) then return true end end
    return false
end
local function count(r, needle)
    local n = 0
    for _, line in ipairs(r.log) do if line:find(needle, 1, true) then n = n + 1 end end
    return n
end
local function released(r)
    local last = r.kit.inputs[#r.kit.inputs]
    return last ~= nil and last[1] == false and last[2] == 'closet_probe' and not r.kit.holding()
end
local PASS = function() return true end
local WIDGET = '/Game/Probe/WB_Fake.WB_Fake_C'

local tests = {
    refuses_when_the_kit_is_not_up = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = PASS}}}})
        r.kit = nil
        local ok_, line = r.p.run('1')
        eq(ok_, false) ok(line:find('not up'), line)
        r.kit = fake_kit()
        r.kit.up = false
        eq((r.p.run('1')), false)
        eq(#r.log, 2) eq(r.log[1], 'probe: FAIL 1 kit: the UI is not up') eq(#r.kit.made, 0)
    end,
    runs_steps_frames_apart_and_logs = function()
        local ran = {}
        local r = rig({['1'] = {steps = {
            {frames = 0, name = 'a', run = function(ctx) ctx.make(WIDGET, 0, 0); ran[#ran + 1] = 'a'; return true end},
            {frames = 2, name = 'b', run = function() ran[#ran + 1] = 'b'; return true end}}}})
        r.kit.widgets[WIDGET] = function() return {} end
        ok((r.p.run('1')))
        same(r.kit.added, {'closet_probe'})
        r.ticks(1)
        eq(r.kit.shown.closet_probe, true) same(ran, {'a'})
        r.ticks(2)
        same(ran, {'a'}, 'b waits two frames')
        r.ticks(1)
        same(ran, {'a', 'b'})
        ok(has(r, 'probe: PASS 1 a')) ok(has(r, 'probe: PASS 1 b')) ok(has(r, 'probe: END 1 2/2'))
        eq(r.kit.dropped, 1) ok(released(r)) eq(r.p.running(), nil)
    end,
    a_part_gone_mid_test_fails_and_cleans_up = function()
        local r = rig({['1'] = {steps = {
            {frames = 0, name = 'a', run = function(ctx) ctx.make(WIDGET, 0, 0); return true end},
            {frames = 1, name = 'b', run = PASS}}}})
        r.kit.widgets[WIDGET] = function() return {} end
        r.p.run('1')
        r.ticks(1)
        r.kit.made[1].live = false -- a map change took it
        r.ticks(3)
        ok(has(r, 'probe: FAIL 1 parts: gone')) ok(not has(r, 'PASS 1 b')) ok(has(r, 'probe: END 1 1/2'))
        ok(released(r))
    end,
    a_throwing_call_fails_the_check = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = function() error('boom') end}}}})
        r.p.run('1')
        r.ticks(2)
        ok(has(r, 'probe: FAIL 1 a:')) ok(has(r, 'boom')) ok(has(r, 'probe: END 1 0/1'))
    end,
    a_step_can_wait_and_fail_with_why = function()
        local polls = 0
        local r = rig({['1'] = {steps = {
            {frames = 0, name = 'poll', run = function() polls = polls + 1; if polls < 3 then return 'wait' end
                return true end},
            {frames = 0, name = 'no', run = function() return false, 'got 2' end}}}})
        r.p.run('1')
        r.ticks(5)
        eq(polls, 3) ok(has(r, 'probe: PASS 1 poll')) ok(has(r, 'probe: FAIL 1 no: got 2'))
        ok(has(r, 'probe: END 1 1/2'))
    end,
    times_out = function()
        local r = rig({['1'] = {steps = {{frames = 100000, name = 'a', run = PASS}}}})
        r.p.run('1')
        r.ticks(3)
        r.now = r.now + r.Probe.TIMEOUT + 1
        r.ticks(1)
        ok(has(r, 'probe: FAIL 1 timeout')) ok(has(r, 'probe: END 1 0/1')) eq(r.p.running(), nil)
    end,
    a_test_can_set_its_own_timeout = function()
        local r = rig({['5'] = {timeout = 90, steps = {{frames = 100000, name = 'a', run = PASS}}}})
        r.p.run('5')
        r.now = r.now + r.Probe.TIMEOUT + 1
        r.ticks(1)
        eq(r.p.running(), '5')
        r.now = r.now + 60
        r.ticks(1)
        ok(has(r, 'probe: FAIL 5 timeout'))
    end,
    off_ends_the_running_test = function()
        local cleaned = false
        local r = rig({['1'] = {cleanup = function() cleaned = true end,
            steps = {{frames = 50, name = 'a', run = PASS}, {frames = 0, name = 'b', run = PASS}}}})
        local ok_, line = r.p.off()
        ok(ok_) eq(line, 'probe: nothing running')
        r.p.run('1')
        r.ticks(1)
        r.kit.input(true, 'closet_probe')
        r.p.off()
        ok(has(r, 'probe: END 1 0/2')) ok(cleaned) ok(released(r)) eq(r.p.running(), nil)
    end,
    a_new_run_ends_the_running_one = function()
        local r = rig({['1'] = {steps = {{frames = 50, name = 'a', run = PASS}}},
            ['2'] = {steps = {{frames = 0, name = 'b', run = PASS}}}})
        r.p.run('1')
        r.p.run('2')
        ok(has(r, 'probe: END 1 0/1')) eq(r.p.running(), '2')
        r.ticks(2)
        ok(has(r, 'probe: END 2 1/1'))
    end,
    coop_off_stops_the_probe = function()
        local r = rig({['1'] = {steps = {{frames = 50, name = 'a', run = PASS}}}})
        r.p.run('1')
        r.kit.input(true, 'closet_probe')
        r.p.stop()
        eq(r.p.running(), nil) ok(released(r)) ok(has(r, 'probe: END 1 0/1'))
        r.p.stop() -- idle: nothing more
        eq(count(r, 'END'), 1)
    end,
    the_group_is_added_once = function()
        local r = rig({['1'] = {steps = {{frames = 0, name = 'a', run = PASS}}}})
        r.p.run('1')
        r.ticks(2)
        r.p.run('1')
        r.ticks(2)
        same(r.kit.added, {'closet_probe'})
    end,
    unknown_test_is_refused = function()
        local r = rig({})
        local ok_, line = r.p.run('9')
        eq(ok_, false) eq(line, r.Probe.USE)
    end,
    commands = function()
        local calls = {}
        local probe = {run = function(n) calls[#calls + 1] = 'run ' .. n; return true, 'ran' end,
            off = function() calls[#calls + 1] = 'off'; return true, 'off' end}
        package.loaded['closet.commands'] = nil
        local Probe = require('closet.ui.probe')
        local C = require('closet.commands').new({dress = {}, fits = {BY_ID = {}}, probe = probe})
        -- As main/commands.lua's M.run calls it: six words, nil-padded.
        eq(select(2, C.closet('probe', nil, nil, nil, nil, nil)), Probe.USE)
        ok((C.closet('probe', '3', nil, nil, nil, nil)))
        ok((C.closet('probe', 'off', nil, nil, nil, nil)))
        eq((C.closet('probe', '3', 'x', nil, nil, nil)), false)
        same(calls, {'run 3', 'off'})
        ok(require('closet.commands').USE:find('probe', 1, true))
    end,
}
run('probe_test', tests)
