-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's settings: its fixed values (DEFAULTS) and the coop-settings.txt lines it reads itself (parse):
--   gun_mode=on|off       the module at all (on by default; off: no key, no hook, nothing)
--   gun_key=<key>         the keyboard toggle, G unless set: one letter A to Z or F1 to F12 but F10 (Ctrl+<key> toggles
--                         too, so it can be left while aiming)
--   gun_pose=on|off       standing: the posed arms and the muzzle laser (gunmode/pose.lua; off by default for now)
--   gun_fire_effect=on|off  test only: standing hip fire through an EffectTable row (gunmode/data.lua; off: UE4SS's
--                         FindRow on EffectTable can crash the game). Off, the rifle fires aimed (Ctrl / L2 + LMB / R2)
--   gun_real_ammo=on|off  each shot spends one NIKKE round and gun mode ends when the bag is empty (off by default: the
--                         rows that make that work, NGM_AE_RealAmmo and its family, are not in every build of the pak)
-- On a pad, a tap of D-pad Right (released within pad_tap s) toggles: a hold of it is the bike's (bike/ride.lua).
local Config={}

Config.DEFAULTS={
    key='G',
    pad_tap=0.4,
    real_ammo=false,
    -- Crouch <-> stand: keys polled with IsInputKeyDown (Caps Lock, Y and R3; Y because Caps Lock cannot be sent by
    -- every test tool, and SB binds plain Y to nothing).
    crouch_keys={'CapsLock','Y','Gamepad_RightThumbstick'},
    -- Firing: the NIKKE shot skill's own cool time, a short wait for the gun to come up before a burst's first shot.
    fire_interval=0.11,first_shot_delay=0.12,aim_ready=0.35,
    -- The reticle: the NIKKE pin enlarged, and the reference aspect its X is clamped to made the screen's.
    reticle_scale=1.6,wide_reticle=true,
    keep_hud=true, -- Put back what the NIKKE mode hides of the main HUD (HP, skills, enemy info).
    pose=false, -- Standing: the arms posed so the rifle follows the camera (gunmode/pose.lua). Off until its first
                -- frame stops crashing in game (11-17); gun_pose=on turns it on.
    laser=true, -- Standing: the laser sight from the rifle's muzzle to where the rounds go (gunmode/laser.lua).
    cam_offset={X=0,Y=60,Z=0}, -- CameraBoom.CustomOffset while standing (over the shoulder).
    -- Guards: the gun stance re-applied when the game drops it, the sword montage stopped after a battle state change.
    stance_check=0.25,stance_cooldown=1.0,battle_window=2.5,hold_ms=250,
    roll_time=0.9,roll_cooldown=1.2, -- A roll lifts the gun this long; no new roll this long after it comes back.
    crouch_anim='P_Eve_GunNikkeHide', -- The NIKKE kneel animset, forced while crouched.
    starter_ammo=60,
}

local LETTER_OR_F='^[A-Z]$'
-- A key name as UE4SS's Key table spells it ('G', 'F4'), or nil and why.
function Config.key(text)
    local t=text:upper()
    if t:find(LETTER_OR_F) then return t end
    local n=tonumber(t:match('^F([1-9]%d?)$'))
    if n and n<=12 and n~=10 then return 'F'..n end
    if n==10 then return nil,'F10 opens the console' end
    return nil,'use one letter A to Z or F1 to F12'
end

local function onoff(v) local l=v:lower(); return l=='on' or l=='off' end
-- The value of the last line naming key in a settings text (name=value, names in any case, a BOM, CRs and spaces
-- around the value ignored), or nil. Gun mode reads its own lines: it uses nothing of the rest of the mod.
function Config.get(text,key)
    local found
    for line in (text:gsub('^\239\187\191','')..'\n'):gmatch('([^\n]*)\n') do
        local name,value=line:gsub('\r',''):match('^%s*([%w_]+)%s*=%s*(.-)%s*$')
        if name and name:lower()==key then found=value end
    end
    return found
end

-- The settings from coop-settings.txt's text (nil: the file is missing): {on, key, pose, real_ammo} and the
-- lines it refused, as 'name: why'.
function Config.parse(text)
    local get=Config.get
    local out,bad={on=true,key=Config.DEFAULTS.key,real_ammo=Config.DEFAULTS.real_ammo,pose=Config.DEFAULTS.pose,
        fire_effect=false},{}
    if not text then return out,bad end
    local v=get(text,'gun_mode')
    if v then
        if onoff(v) then out.on=v:lower()=='on' else bad[#bad+1]='gun_mode: use on or off' end
    end
    v=get(text,'gun_key')
    if v then
        local k,why=Config.key(v)
        if k then out.key=k else bad[#bad+1]='gun_key: '..why end
    end
    v=get(text,'gun_pose')
    if v then
        if onoff(v) then out.pose=v:lower()=='on' else bad[#bad+1]='gun_pose: use on or off' end
    end
    v=get(text,'gun_fire_effect')
    if v then
        if onoff(v) then out.fire_effect=v:lower()=='on' else bad[#bad+1]='gun_fire_effect: use on or off' end
    end
    v=get(text,'gun_real_ammo')
    if v then
        if onoff(v) then out.real_ammo=v:lower()=='on' else bad[#bad+1]='gun_real_ammo: use on or off' end
    end
    return out,bad
end

return Config
