-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's polled input, read every 50 ms from EVE's tick with PlayerController:IsInputKeyDown (key repeat waits and
-- stutters, and a keybind only sees a key pressed with its exact modifiers). Edges and taps are worked out here from
-- the keys' down states, so they can be tested without the game.
local Input={}

-- A key's state s ({down=bool}): true on the press (up -> down).
function Input.edge(s,down)
    local pressed=down and not s.down
    s.down=down
    return pressed
end

-- A tap: down then up again within limit s. s ({down=bool, at=time}); true on the release of a short press.
function Input.tap(s,down,now,limit)
    local tapped=false
    if down and not s.down then s.at=now
    elseif not down and s.down then tapped=s.at~=nil and now-s.at<=limit end
    s.down=down
    return tapped
end

-- The polled keys, as IsInputKeyDown names them.
Input.FIRE_MOUSE,Input.FIRE_PAD='LeftMouseButton','Gamepad_RightTrigger'
Input.AIM_PAD='Gamepad_LeftTrigger'
Input.CTRL={'LeftControl','RightControl'}
Input.ROLL={'LeftShift','Gamepad_FaceButton_Right'}
Input.TOGGLE_PAD,Input.PAD_SHOULDER='Gamepad_DPad_Right','Gamepad_RightShoulder'

-- What the player asks this poll, from down(name) (the key's state) and the previous states in s:
-- {toggle, crouch, roll, fire} (each true once per press), for cfg (gunmode/config.lua's DEFAULTS).
function Input.read(s,down,now,cfg)
    local function any(names) for _,n in ipairs(names) do if down(n) then return true end end return false end
    local out={}
    -- D-pad Right: a tap, not while R1 is held (Unified Projection Suit's R1+D-pad). Held, it is the bike's.
    local dr=down(Input.TOGGLE_PAD) and not down(Input.PAD_SHOULDER)
    out.toggle=Input.tap(s.dpad,dr,now,cfg.pad_tap)
    out.crouch=Input.edge(s.crouch,any(cfg.crouch_keys))
    out.roll=Input.edge(s.roll,any(Input.ROLL))
    local ctrl=any(Input.CTRL)
    local trigger=down(Input.FIRE_PAD)
    out.fire_held=down(Input.FIRE_MOUSE) or trigger
    out.fire_ctrl=(down(Input.FIRE_MOUSE) and ctrl) or (trigger and down(Input.AIM_PAD))
    out.fire=Input.edge(s.fire,out.fire_held)
    out.aim=ctrl or down(Input.AIM_PAD)
    out.aim_start=Input.edge(s.aim,out.aim)
    return out
end

function Input.state() return {dpad={},crouch={},roll={},fire={},aim={}} end

return Input
