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
    -- false while gun mode is being rebuilt: the toggle only says so and nothing of gun mode runs, unless
    -- the rifle layer (fight/gunmode/overlay.lua's class, in gunmode's pak) is installed, which is the rebuilt path.
    enabled=false,
    key='G',
    pad_tap=0.4,
    fire_interval=0.045, -- s between rounds; the NIKKE shot skill's CoolTime is written as fight/gunmode/data.lua's COOL_SHARE of it (SB ships 0.11 s).
    hip_aligned=6, -- hip fire: a round leaves only while the rifle's bore is within this many degrees of the crosshair point
    -- hip fire's legs: A and D step sideways on this animation set row (the aim stance's own set) as a custom moving
    -- stance; its NormalAnimRangeDegree is a game value to tune (180, 45, 0). false: her run legs as before
    hip_hold_cone=15, -- hip fire: while fire stays held the burst keeps going with the bore within this many degrees
    -- off: the aim stance's set (P_Eve_Gun_Battle) crouched her and once held her running forward in game
    hip_strafe=false,hip_strafe_row='P_Eve_Gun_Battle',hip_strafe_deg=180.0,
    -- the mesh turned back while the strafe set is on (deg): P_Eve_Gun_Battle blades her like the game's aim (use
    -- fight/gunmode/ik.lua's aim_mesh_yaw, -75); a set that does not blade her takes 0. In game, P_Eve_GunNikke crouched her
    -- and P_Eve_Battle ran her toward the move: the game's directional strafe plays only in its lock-on.
    hip_strafe_mesh_yaw=-75,
    -- hip fire's strafe (fight/gunmode/strafe.lua): while she moves, the pak's rifle walk or run clip of her move's direction
    -- (Animation/NGM, 8 ways) loops on her DefaultSlot while she keeps facing the aim. false: her stance's legs as before
    strafe=true,
    strafe_min=40, -- cm/s: below this ground speed no strafe clip plays (her stance's idle)
    strafe_hyst=10, -- deg: her move must be this far past a sector's 22.5 deg half-width before the clip changes way
    strafe_run_at=260, -- cm/s: the run clips from this ground speed, the walk clips below it
    strafe_run_hyst=30, -- cm/s: run from strafe_run_at+this up, back to walk below strafe_run_at-this
    strafe_walk_speed=150, -- cm/s: the speed the walk clips' feet were made for (play rate = speed / this)
    strafe_run_speed=300, -- cm/s: the same for the run clips
    strafe_rate_min=0.6,strafe_rate_max=1.6, -- the play rate's clamp
    strafe_blend=0.2, -- s: the strafe montage's blend in and out
    -- The rifle's round (fight/gunmode/ammo.lua): its name on the reticle's round slot, the magazine, the reload.
    round_name='NIKKE RAPID',reload_text='RELOADING',empty_text='NO AMMO',round_color={0.35,0.85,1.0},
    reload_color={1.0,0.62,0.15},
    mag_size=60,spare_mags=5,reload_time=1.6,reload_delay=1.0,
    -- With a host's round store: the rounds in one unit of it (one Bullet_Nikke is one magazine). A reload takes one
    -- unit for a full magazine. nil: mag_size.
    rounds_per_unit=60,
    -- The reload's sounds (the NIKKE squad's), each at this share of the reload time.
    reload_sounds={{'/Game/DLC_2/Sound/SFX_D2/PC/Gun/P_Eve_GunNikke_Reload_1_Cue.P_Eve_GunNikke_Reload_1_Cue',0.0},
        {'/Game/DLC_2/Sound/SFX_D2/PC/Gun/P_Eve_GunNikke_Reload_2_Cue.P_Eve_GunNikke_Reload_2_Cue',0.6},
        {'/Game/DLC_2/Sound/SFX_D2/PC/Gun/P_Eve_GunNikke_Reload_3_Cue.P_Eve_GunNikke_Reload_3_Cue',0.85}},
    -- The sound of gun mode's own rounds (hip fire) and of the game's aim rounds, played 2D at most every
    -- shot_sound_every s; nil plays none. The NIKKE rifle's shot cue, in the game's pak asset list
    -- (SB/Content/DLC_2/Sound/SFX_D2/PC/Gun/P_Eve_GunNikke_ShootSlug_Cue.uasset).
    shot_sound='/Game/DLC_2/Sound/SFX_D2/PC/Gun/P_Eve_GunNikke_ShootSlug_Cue.P_Eve_GunNikke_ShootSlug_Cue',
    shot_sound_every=0.09,
    -- The gun mode animation pak: one of its animations (to find it) and its blend space, which the
    -- aim stance's animation set points at while the rifle is out.
    -- the laser's end eases toward each new point at this time constant (s), so the dot does not jump with each shot's
    -- kick in hip fire (fight/gunmode/laser.lua); 0: no easing
    laser_smooth=0.08,
    -- the rifle's recoil kick in hip fire (gun mode's own rounds, the game's aim off) as a share of the aim value
    -- (fight/gunmode/ik.lua recoil_up and recoil_back), so the bore the rounds and the laser follow stays steadier
    hip_recoil=0.4,
    muzzle_every=0.09,muzzle_scale=0.45, -- the flash: at most this often (s), at this size (it stacked into a blaze)
    muzzle_fx='/Game/DLC_2/Art/FX/MiniGame/NS_A_NikkeGunFire.NS_A_NikkeGunFire', -- the NIKKE rifle's flash
    -- The animation pak: EVE's rifle animation set, new assets only.
    pak_probe='/Game/Art/Character/PC/CH_P_EVE_01/Animation/NGM/NGM_R_AimIdle.NGM_R_AimIdle',
    pak_bs='Animation/BlendSpace/P_Eve_NGM_R_BS', -- aiming: 8-way walk + run (her lock-on layout), rifle shouldered
    pak={aim_offset='Animation/Additive/NGM_R_Aim_BS', -- aiming up/down/left/right
        carry='Animation/BlendSpace/P_Eve_NGM_RC_BS', -- rifle out, out of a fight (her IdleRun_BS_Peaceful2D layout)
        carry_battle='Animation/BlendSpace/P_Eve_NGM_RCB_BS', -- rifle out, in a fight (her IdleRun_BS_Battle layout)
        -- the aim stance's speeds while the pak is in (cm/s): EVE's own lock-on walk and run, the speeds her aim
        -- clips' legs were animated for (no foot sliding)
        speeds={WalkSpeed=150,RunSpeed=280,JoggingRunSpeed=280,LockOnWalkSpeed=150,LockOnRunSpeed=280},
        -- her own animation sets' jump, fall, landing, sprint and stop clips: Animation/Proto_<x> -> the pak's rifle version
        -- Animation/NGM/NGM_R_C_<x> (both hands stay on the rifle through a jump)
        carry_fields={'DoubleJump','DoubleJump2','DoubleJump3','DoubleJumpFront','DoubleJumpFront2','DoubleJumpFront3','Fall','FallToLowDistToIdle','FallToLowDistToRun','FlyingToIdle','Jump','Jump2','Jump3','JumpFront','JumpFront2','JumpFront3','JumpHighToIdle','JumpHighToRun','JumpHighToWalk','JumpToIdle','JumpToRun','JumpToSprint','JumpToSprintShort','JumpToWalk','RunToIdle_L','RunToIdle_R','ShortMoveToIdle_L','ShortMoveToIdle_R','Sprint','SprintToIdle','SprintToRun','StartFallToLowDist','StartSprint','WalkToIdle_L','WalkToIdle_R','WallJump','WallRunJump'}},
    aim_fov=66,fov_ease=0.2, -- Firing mode on the game's aim: its camera's field of view (SB's is 45), eased in.
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
    -- The rifle's reload keys (keyboard B, gamepad Triangle): every game action on them is masked while the rifle is
    -- out; a press throws the rest of the magazine away and loads a full one (fight/gunmode/ammo.lua manual). B is free in
    -- the game's own bindings (a log: R throws grenades; B, N, O, Y and 5-0 are unbound).
    reload_keys={'B','Gamepad_FaceButton_Top'},
    -- gun_fire=native: firing mode is the game's own aim (TPSMode on its own keys, Ctrl / LT, and TPSFire, LMB / RT:
    -- the drone's shot), with its strafing movement, camera and reticle. mask_on_keys (Luke's combat names) are masked
    -- in this mode too. TPSFire is masked only while dry (fight/gunmode/mode.lua GunMode.mask_names).
    -- native_mask_triggers=true masks LeftTriggerKey and RightTriggerKey in native mode too. Off until a game run shows
    -- the game's aim on the pad still works with them masked.
    native_mask_triggers=false,
    aim_from='LeftControl',aim_to='RightMouseButton', -- The game's keyboard aim key, moved while the rifle is out.
    native_torso=0, -- In the game's aim: how much her spine takes the NIKKE pose (fight/gunmode/stance.lua; off: the arms
                    -- are placed along the camera instead, and her head stays the real one's).
    -- The game's aim: its rounds' start and destination are written in her actor's yaw frame turned by her mesh's turn
    -- (fight/gunmode/ik.lua aim_mesh_yaw, eased) times this. 0 (the actor's frame alone, as before) until a native aim shot
    -- in game shows 1 or -1 lands on the reticle.
    aim_yaw_sign=0,
    start_min_forward=25, -- The shot starts at the rifle's muzzle only when it is this far ahead of her (cm),
    start_fallback={X=45,Y=22,Z=55}, -- else here: forward, right, up from her centre (her right shoulder).
    follow_names={}, -- Parts made to follow the posed copy: none (her face moved off her head that way).
    pose_time=0.08, -- Firing mode between shots: the NIKKE shot montage held at this time (s).
    -- the rifle's arrival and departure (fight/gunmode/morph.lua): a black cube in her right hand (the engine's editor cube,
    -- the one cube mesh the game ships (BasicShapes is not cooked), sized from its bounds
    -- scaled to cube_cm, at cube_at in Bip001-R-Hand's frame) and the effect at the hand-over. morph=false: none.
    morph=true, cube_mesh='/Engine/EditorMeshes/EditorCube.EditorCube', cube_cm=9, cube_at={X=-1.9,Y=-4.6,Z=4.1},
    morph_fx='/Game/Art/FX/Char/PC/WeaponFX/NS_A_Weapon_Fold_02.NS_A_Weapon_Fold_02',
    aim_cam={X=0,Y=35,Z=10}, -- With the rifle layer: the aim camera moved this far (cm; camera space: forward, right, up) while aiming, through gunmode's camera modifier.
    native_speed=1.4, -- In the game's aim: its stance's walk and run speeds times this (CharacterStanceTable).
    -- Hidden from the player's own camera while the rifle is out (Luke's stance shows a posed copy of EVE's body
    -- there): her other mesh components wearing her body's own mesh (Ultra Violence's blood layer, outfit overlays)
    -- and any whose mesh name has one of these (the sword). Co-op partners still see them.
    hide_names={'Sword','CH_W_'},
    -- Head parts copied with the posed body: none. They follow her body through its leader pose and hold no pose of
    -- their own, and copying a pose from one crashed the game.
    copy_names={},
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
    v=get(text,'gun_bs')
    if v and v~='' then out.bs=v end
    v=get(text,'gun_carry_ovr') -- auto (default with the pak): the rifle carry set; off: her own walk; or an animation set row (testing)
    if v and v:match('^[%w_]+$') then out.carry_ovr=v end
    v=get(text,'gun_hip_strafe_row') -- (testing) hip fire's strafe set: an animation set row (fight/gunmode/config.lua hip_strafe_row)
    if v and v:match('^[%w_]+$') then out.hip_strafe_row=v end
    v=get(text,'gun_carry_spare'); if v and tonumber(v) then out.carry_spare=tonumber(v) end
    v=get(text,'gun_carry_idle'); if v and tonumber(v) then out.carry_idle_type=tonumber(v) end
    v=get(text,'gun_probe')
    if v then out.probe=v:lower()=='on' end
    v=get(text,'gun_facts') -- (dev only) the facts probe, fight/gunmode/facts.lua
    if v=='on' then out.facts=true end
    v=get(text,'gun_g0') -- (dev only) gate G0's measurements and capture pictures, fight/gunmode/g0.lua
    if v=='on' then out.g0=true end
    v=get(text,'gun_airtrace') -- (dev only) air state trace for the flip work (fight/gunmode/mode.lua)
    if v=='on' then out.airtrace=true end
    v=get(text,'gun_g1') -- (dev only) gate G1's numbers, AimRot test and fixed captures, fight/gunmode/g1.lua
    if v=='on' then out.g1=true end
    v=get(text,'gun_g1_tag') -- (dev only) a label for G1's log lines and capture files, e.g. red or v3a
    if v and v:match('^[%w_]+$') then out.g1_tag=v end
    v=get(text,'gun_trace') -- (testing) step log around reloads and aim changes
    if v then out.trace=v:lower()=='on' end
    v=get(text,'gun_fire_key') -- (testing) one more fire key, as F
    if v and v:match('^%w+$') then out.fire_key=v end
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
