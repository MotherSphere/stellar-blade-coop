#!/usr/bin/env python3
# Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
# SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
# SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
"""mod/EveHoverbike's hold to get on and off (docs/vehicles/fusion-strider-handover.md): F3 and the controller button
act only once held Config.HoldTime s (0.5). A tap does nothing; a hold acts once, nothing more until it is let go;
LB or LT with the D-pad (the game's wheels) never starts one; Ctrl+F3 blocks the plain F3 that fires with it. Runs
logic.lua's own ActionKey, PollHold and PollController in lua5.4 over a fake player controller."""
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPTS = ROOT / 'mod/EveHoverbike/Scripts'
src = (SCRIPTS / 'logic.lua').read_text(encoding='utf-8').replace('\r\n', '\n')
main = (SCRIPTS / 'main.lua').read_text(encoding='utf-8').replace('\r\n', '\n')
assert '    HoldTime = 0.5,\n' in src
assert 'Bind(Key.F3, nil, "ActionKey")' in main, 'F3 starts a hold, never Action itself'
assert 'Bind(Key.F3, { ModifierKey.CONTROL }, "Remove")' in main
remove = src[src.index('function L.Remove(S)'):]
assert remove.split('\n')[1].strip().startswith('S.Hold = { done = true }'), 'Ctrl+F3 blocks the plain F3'
assert '    PollHold(S, pc)\n    PollController(S, pc)\n' in src, 'both polled in L.Tick'
start, stop = src.index('function L.ActionKey(S)'), src.index('    S.PadDown = down\nend\n') + len('    S.PadDown = down\nend\n')

chunk = r'''
local L, logs, actions = {}, {}, 0
local Config = { HoldTime = 0.5, ControllerButton1 = "Gamepad_DPad_Right", ControllerButton2 = "" }
local clock = 0
os.clock = function() return clock end
FName = function(s) return s end
local function Log(m) logs[#logs + 1] = m end
function L.Action(S) actions = actions + 1 end
''' + src[start:stop] + r'''
local down = {}
local pc = { IsInputKeyDown = function(_, k) return down[k.KeyName] == true end }
local S = {}
local function tick(dt) clock = clock + dt PollHold(S, pc) PollController(S, pc) end
-- F3: a tap does nothing.
down.F3 = true L.ActionKey(S) tick(0.05) tick(0.2)
down.F3 = false tick(0.05)
assert(actions == 0 and logs[#logs] == "F3 let go before 0.5 s: nothing", logs[#logs])
-- F3 held 0.5 s: once; held on, nothing more; let go, the next hold acts again.
down.F3 = true L.ActionKey(S) tick(0.3) assert(actions == 0)
tick(0.25) assert(actions == 1)
L.ActionKey(S) tick(1) tick(1) assert(actions == 1, "once a hold")
down.F3 = false tick(0.05) down.F3 = true L.ActionKey(S) tick(0.5) assert(actions == 2)
down.F3 = false tick(0.05)
-- Ctrl+F3 (L.Remove sets S.Hold = { done = true }): the plain F3 with it never gets her on.
S.Hold = { done = true } down.F3 = true L.ActionKey(S) tick(1) assert(actions == 2)
down.F3 = false tick(0.05) assert(S.Hold == nil)
-- D-pad right: a tap does nothing, a hold acts once.
down.Gamepad_DPad_Right = true tick(0.05) tick(0.2)
down.Gamepad_DPad_Right = false tick(0.05)
assert(actions == 2 and logs[#logs] == "controller button let go before 0.5 s: nothing", logs[#logs])
down.Gamepad_DPad_Right = true tick(0.05) tick(0.3) assert(actions == 2)
tick(0.2) assert(actions == 3) tick(1) assert(actions == 3, "once a hold")
down.Gamepad_DPad_Right = false tick(0.05)
-- LB held with the D-pad: the game's item wheel, never the bike.
down.Gamepad_LeftShoulder = true down.Gamepad_DPad_Right = true tick(0.05) tick(1)
assert(actions == 3)
print("eve_hoverbike_hold_test ok")
'''
done = subprocess.run(['lua5.4', '-'], input=chunk, capture_output=True, text=True)
assert done.returncode == 0, done.stderr
print(done.stdout.strip())
