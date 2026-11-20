-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Hip fire's strafe: while she hip fires on the ground and moves, the gun mode pak's rifle walk or run clip of her
-- move's direction (Animation/NGM, in place) loops on her main anim instance's DefaultSlot, so A and D sidestep while
-- she keeps facing the aim. The post-process rifle layer keeps her arms, head and rifle on top of it.
-- The pure part (sector, run, rate, pick) is tested in tests/lua/fight/gunmode/strafe_test.lua; new() is the thin engine part.
local Strafe={}

local NGM='/Game/Art/Character/PC/CH_P_EVE_01/Animation/NGM/'
-- the 8 sectors, clockwise from forward: sector i is centred on (i-1)*45 deg (0 forward, 90 right, 180 back)
Strafe.DIRS={'F','FR','R','BR','B','BL','L','FL'}
local function clip_paths(prefix)
    local t={}
    for i,d in ipairs(Strafe.DIRS) do local n=prefix..d; t[i]=NGM..n..'.'..n end
    return t
end
Strafe.WALK=clip_paths('NGM_R_Aim')
Strafe.RUN=clip_paths('NGM_R_AimRun')
-- shortcut: PlaySlotAnimationAsDynamicMontage has no endless loop count, so a large one stands for it; the montage
-- is stopped by gun mode (stop) long before 1000 loops of a walk cycle run out
Strafe.LOOPS=1000

-- The sector (1..8) of a move at deg (her actor frame: 0 forward, +90 right, -180..180). was keeps its sector until
-- deg is past its 22.5 deg half-width by more than hyst, so the clip does not flip at a border.
function Strafe.sector(was,deg,hyst)
    if was then
        local d=(deg-(was-1)*45+540)%360-180
        if math.abs(d)<=22.5+(hyst or 0) then return was end
    end
    return math.floor(((deg+22.5)%360)/45)+1
end

-- Run (true) or walk at speed (cm/s): run from at+hyst up, back to walk below at-hyst.
function Strafe.run(was,speed,at,hyst)
    if was then return speed>=at-hyst end
    return speed>=at+hyst
end

-- The clip's play rate: speed over the speed it was authored at, clamped to lo..hi.
function Strafe.rate(speed,authored,lo,hi) return math.max(lo,math.min(hi,speed/authored)) end

-- The clip path and play rate for her velocity (vx, vy, world cm/s) at actor yaw (deg), or nil below strafe_min.
-- st keeps the sector and the walk/run choice between frames (st.sec, st.run).
function Strafe.pick(st,vx,vy,yaw,cfg)
    local speed=math.sqrt(vx*vx+vy*vy)
    -- below strafe_min it stops; once going it holds down to strafe_min - strafe_min_hyst (no flicker near the limit)
    if speed<cfg.strafe_min-(st.sec and (cfg.strafe_min_hyst or 0) or 0) then st.sec,st.run=nil,nil; return nil end
    local y=math.rad(yaw)
    local c,s=math.cos(y),math.sin(y)
    local fwd,right=vx*c+vy*s,-vx*s+vy*c -- UE's right vector for yaw y is (-sin y, cos y)
    st.sec=Strafe.sector(st.sec,math.deg(math.atan(right,fwd)),cfg.strafe_hyst)
    st.run=Strafe.run(st.run,speed,cfg.strafe_run_at,cfg.strafe_run_hyst)
    local path=(st.run and Strafe.RUN or Strafe.WALK)[st.sec]
    return path,Strafe.rate(speed,st.run and cfg.strafe_run_speed or cfg.strafe_walk_speed,cfg.strafe_rate_min,cfg.strafe_rate_max)
end

local function is_playing(ai,m) return ai:Montage_IsPlaying(m) end
local function current(ai) return ai:GetCurrentActiveMontage() end
-- A clip of the gun mode pak: UE4SS's LoadAsset cannot see mod-pak packages, so the asset registry loads it (as
-- fight/gunmode/overlay.lua does). Kept by path and checked against it before each use; a miss waits 5 s.
local REG='/Script/AssetRegistry.Default__AssetRegistryHelpers'
local function full(o) return o:GetFullName() end
function Strafe.registry_find(g,kept,path,now)
    local o=kept[path]
    if type(o)=='table' or type(o)=='userdata' then
        local ok,f=pcall(full,o)
        if g.valid(o) and ok and type(f)=='string' and f:sub(-#path)==path then return o end
    elseif type(o)=='number' and now<o then return nil end
    local ok,r=pcall(function() return StaticFindObject(REG):GetAsset({ObjectPath=FName(path)}) end)
    if ok and g.valid(r) then kept[path]=r; return r end
    kept[path]=now+5
end

-- The engine part. g: gun mode's helpers (log, valid, asset). tick(p,active,now) once a frame: active is hip fire on
-- the ground with nothing else owning her legs. hold(ai,m): the hip-fire turn clip just played; the strafe gives way
-- while it plays. stop(): the strafe montage stopped with its blend (strafe end, rifle away, disable, new controller).
function Strafe.new(g,cfg)
    local self={}
    local st={} -- sec, run: Strafe.pick's memory
    local clip,m,ai,rate,seen_at -- the path playing, its montage, the anim instance it plays on, its rate, the last check
    local turn_ai,turn_m
    local SLOT -- FName('DefaultSlot'), made once
    local missing={}
    local reg={} -- path -> clip loaded through the asset registry, or the time its miss expires

    -- the strafe montage stopped (its own end: the turn clip it gives way to is kept)
    local function halt()
        if m and g.valid(ai) then
            local mm,a=m,ai
            pcall(function() a:Montage_Stop(cfg.strafe_blend,mm) end)
        end
        clip,m,ai,rate=nil,nil,nil,nil
        st.sec,st.run=nil,nil
    end
    -- disable, new controller: the turn clip it was waiting on is forgotten too
    function self.stop() halt(); turn_ai,turn_m=nil,nil end
    -- whether a montage other than the strafe's own plays on her (a dodge, a hit, a shot, the turn step): the strafe
    -- gives way to it and never plays over it
    local function other(a)
        local ok,cur=pcall(current,a)
        if not (ok and g.valid(cur)) or cur==m then return false end
        local ok2,r=pcall(is_playing,a,cur)
        return ok2 and r==true
    end

    function self.hold(a,mm) turn_ai,turn_m=a,mm end

    function self.playing() return clip end

    function self.tick(p,active,now)
        if turn_m and g.valid(turn_ai) and g.valid(turn_m) then
            local ok,r=pcall(is_playing,turn_ai,turn_m)
            if ok and r==true then active=false else turn_ai,turn_m=nil,nil end
        else turn_ai,turn_m=nil,nil end
        if not active then if clip then halt() end; return end
        local v=p:GetVelocity()
        local path,k=Strafe.pick(st,v.X,v.Y,p:K2_GetActorRotation().Yaw,cfg)
        if not path then if clip then halt() end; return end
        -- the game may stop the montage (its own moves, stance changes): checked four times a second, played again
        if m and now-(seen_at or 0)>=0.25 then
            seen_at=now
            local ok,r=false,nil
            if g.valid(ai) and g.valid(m) then ok,r=pcall(is_playing,ai,m) end
            if not (ok and r==true) then clip,m=nil,nil end
        end
        if path~=clip then
            local a=p.Mesh:GetAnimInstance()
            if not g.valid(a) or other(a) then if clip then halt() end; return end
            local seq=g.asset(path) or Strafe.registry_find(g,reg,path,now)
            if not seq then
                if not missing[path] then missing[path]=true; g.log('strafe: no '..path) end
                return
            end
            if m and g.valid(ai) then local mm,a=m,ai; pcall(function() a:Montage_Stop(cfg.strafe_blend,mm) end) end
            ai=a
            SLOT=SLOT or FName('DefaultSlot')
            m=ai:PlaySlotAnimationAsDynamicMontage(seq,SLOT,cfg.strafe_blend,cfg.strafe_blend,k,Strafe.LOOPS,-1,0)
            clip,rate,seen_at=path,k,now -- (a failed play is not tried again until the clip changes)
            if not m and not missing[path] then missing[path]=true; g.log('strafe: '..path..' did not play') end
        elseif m and g.valid(ai) and g.valid(m) and math.abs(k-rate)>0.05 then
            ai:Montage_SetPlayRate(m,k); rate=k
        end
    end
    return self
end

return Strafe
