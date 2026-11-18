-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's settings: its fixed values (DEFAULTS) and the coop-settings.txt lines it reads itself (parse):
--   gun_mode=on|off       the module at all (on by default; off: no key, no hook, nothing)
--   gun_key=<key>         the keyboard toggle, G unless set: one letter A to Z or F1 to F12 but F10
--   gun_aim_key=<key>    the keyboard key the game's aim moves to while the rifle is out (UE's name; RightMouseButton)
--   gun_upper=nikke|off   test: firing mode shows the game's aim with the NIKKE rifle's upper-body animations
--                         (nikke) instead of Luke's aim on her normal stance's spine (off, the default)
--   gun_zoom=hold|toggle  firing mode while RMB / LT is held (default), or turned on and off by a press
-- On a pad, a tap of D-pad Right (released within pad_tap s) toggles: a hold of it is the bike's (bike/ride.lua).
local Config={}

Config.DEFAULTS={
    key='G',
    pad_tap=0.4,
    fire_interval=0.11, -- The NIKKE shot skill's own cool time.
    raise_time=0.2, -- Firing mode: the rifle's time to come up before the first shot.
    cam_offset={X=0,Y=60,Z=0}, -- CameraBoom.CustomOffset while the rifle is out: EVE left of centre.
    -- Firing mode (RMB / LT held): CameraBoom.CustomOffset this (X: toward her, so the camera comes in over her right
    -- shoulder, short of cutting her hips out of the frame), eased in and out at this share of the way each frame.
    zoom_offset={X=95,Y=55,Z=10},zoom_ease=0.18,
    zoom_arm=0.55, -- Firing mode on her normal stance: the camera arm this share of the game's, SocketOffset +Y/+Z above.
    trace_range=10000, -- How far the crosshair's trace looks for what the rounds hit.
    -- Masked while the rifle is out (in memory only, put back when it goes away, never saved): the sword's attacks and
    -- the drone's aim, fire and pad combat keys on the fire and zoom keys (mask_keys), and the drone's aim and fire on
    -- any key (Luke masked TPSMode). Menus, pick-ups, fishing and the death screen keep their keys.
    mask_keys={'LeftMouseButton','RightMouseButton','Gamepad_LeftTrigger','Gamepad_RightTrigger'},
    mask_on_keys={'AttackLight','AttackStrong','SpecialCommand1','SpecialCommand2','CommandKey7','CommandKey8',
        'LeftTriggerKey','RightTriggerKey','Item_UseBullet'},
    mask_actions={'TPSMode','TPSFire'},
    -- gun_fire=native (a test): firing mode is the game's own aim (TPSMode on its own keys, Ctrl / LT, and TPSFire,
    -- LMB / RT: the drone's shot), with its strafing movement, camera and reticle; only the sword is masked.
    native_mask_on_keys={'AttackLight','AttackStrong','SpecialCommand1','SpecialCommand2','Item_UseBullet'},
    aim_from='LeftControl',aim_to='RightMouseButton', -- The game's keyboard aim key, moved while the rifle is out.
    native_torso=0, -- In the game's aim: how much her spine takes the NIKKE pose (gunmode/stance.lua; off: the arms
                    -- are placed along the camera instead, and her head stays the real one's).
    start_min_forward=25, -- The shot starts at the rifle's muzzle only when it is this far ahead of her (cm),
    start_fallback={X=45,Y=22,Z=55}, -- else here: forward, right, up from her centre (her right shoulder).
    follow_names={}, -- Parts made to follow the posed copy: none (her face moved off her head that way, 02:20).
    pose_time=0.08, -- Firing mode between shots: the NIKKE shot montage held at this time (s).
    native_speed=1.4, -- In the game's aim: its stance's walk and run speeds times this (CharacterStanceTable).
    -- Hidden from the player's own camera while the rifle is out (Luke's stance shows a posed copy of EVE's body
    -- there): her other mesh components wearing her body's own mesh (Ultra Violence's blood layer, outfit overlays)
    -- and any whose mesh name has one of these (the sword). Co-op partners still see them.
    hide_names={'Sword','CH_W_'},
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

-- The settings from coop-settings.txt's text (nil: the file is missing): {on, key} and the lines it refused, as
-- 'name: why'.
function Config.parse(text)
    local get=Config.get
    local out,bad={on=true,key=Config.DEFAULTS.key,zoom_toggle=false,native=true,aim_key=Config.DEFAULTS.aim_to,upper=false},{}
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
    v=get(text,'gun_upper')
    if v then
        local l=v:lower()
        if l=='nikke' or l=='off' then out.upper=l=='nikke' else bad[#bad+1]='gun_upper: use nikke or off' end
    end
    v=get(text,'gun_aim_key')
    if v then
        if v:match('^%w+$') then out.aim_key=v else bad[#bad+1]='gun_aim_key: one UE key name, as RightMouseButton' end
    end
    v=get(text,'gun_fire')
    if v then
        local l=v:lower()
        if l=='native' or l=='own' then out.native=l=='native' else bad[#bad+1]='gun_fire: use native or own' end
    end
    v=get(text,'gun_zoom')
    if v then
        local l=v:lower()
        if l=='hold' or l=='toggle' then out.zoom_toggle=l=='toggle' else bad[#bad+1]='gun_zoom: use hold or toggle' end
    end
    return out,bad
end

return Config
