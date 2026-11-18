-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's polled input, read every frame from its game-thread loop with PlayerController:IsInputKeyDown (a key
-- bind's callback runs on another thread, key repeat waits and stutters, and a bind only sees its exact modifiers).
-- Edges and taps are worked out here from the keys' down states, so they can be tested without the game.
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

-- The polled keys, as IsInputKeyDown names them. Zoom: RMB / LT, and Luke's aim keys (Left Alt, Left Ctrl).
Input.FIRE={'LeftMouseButton','Gamepad_RightTrigger'}
Input.ZOOM={'RightMouseButton','Gamepad_LeftTrigger','LeftAlt','LeftControl'}
Input.TOGGLE_PAD,Input.PAD_SHOULDER='Gamepad_DPad_Right','Gamepad_RightShoulder'

-- What the player asks this poll, from down(name) (the key's state) and the previous states in s: {toggle (D-pad
-- Right's tap), key (gun_key pressed), fire (held), zoom (held)}, for cfg (gunmode/config.lua's DEFAULTS) and key
-- (UE's key name, 'G' or 'F4').
function Input.read(s,down,now,cfg,key)
    local function any(names) for _,n in ipairs(names) do if down(n) then return true end end return false end
    local out={}
    out.key=key~=nil and Input.edge(s.key,down(key))
    -- D-pad Right: a tap, not while R1 is held (Unified Projection Suit's R1+D-pad). Held, it is the bike's.
    local dr=down(Input.TOGGLE_PAD) and not down(Input.PAD_SHOULDER)
    out.toggle=Input.tap(s.dpad,dr,now,cfg.pad_tap)
    out.fire=any(Input.FIRE)
    out.zoom=any(Input.ZOOM)
    out.zoom_press=Input.edge(s.zoom,out.zoom)
    return out
end

function Input.state() return {dpad={},key={},zoom={}} end

return Input
