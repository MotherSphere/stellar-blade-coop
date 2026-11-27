-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Copies fight/enemies/spectate.lua's view rules (the view taken from our pawn only, given back from our camera only,
-- an earlier Lua load's camera swept by the path its file keeps), fight/bosses/leviathan.lua's give-back (to the view
-- target from before, else the pawn, blend BLEND; the file written before the view changes; one tab-separated line)
-- and online/lobby/sbo.lua's view read (the camera manager's location, rotation and FOV).
-- Stellar Closet's camera, driven by closet/ui/menu.lua while the menu is open. open() sweeps an earlier Lua load's
-- camera (once a Lua load, or at the first tick), then, only while the view is on EVE, spawns a camera actor of
-- core/actors.lua at the game camera's place with its FOV, keeps its path in the file and takes the view with a BLEND s
-- blend. Each tick places it: in region mode at the framing of the region the menu gives (Camera.region of the focused
-- slot or tab), in free mode at the free pose. Both are poses {yaw, pitch, dist, height, pan} relative to EVE: yaw
-- around her from her front, pitch above her, dist from the look point in cm, height of the look point above her feet,
-- pan of the look point along the camera's right. The pose eases there (95% in EASE s). EVE's feet are her actor's Z
-- less her capsule's scaled half height, her height twice that. The camera turns so that her look point shows NDC of
-- the half width right of centre (EVE at about 78% across) and at the middle of the height.
-- Free mode: cam_left, cam_right, cam_up and cam_down orbit STEP degrees, cam_in and cam_out zoom by ZOOM; the pad's
-- right stick orbits (ORBIT, TILT deg/s at full), LT and RT zoom (a factor 2 a second at full), X held with the stick
-- moves the height and the pan (SLIDE cm/s); DEAD of each axis is ignored. Region mode: the right stick (X held or not)
-- pans the region's framing in the screen's plane (SLIDE cm/s, kept so that EVE's look point stays within RPAN on
-- screen), as cam_left, cam_right, cam_up and cam_down do by STEP cm; the triggers and the zoom steps move
-- nothing. That pan is kept until the region changes, the next open or a reset. X released after a hold with no stick
-- toggles region and free (cam_mode too); R3 and cam_reset clear the region pan, set the free pose to the region's
-- framing and go to free mode. With the native held read (main/boot.lua's held_keys), the step words move nothing:
-- I/J/K/L held orbit and U/O held zoom at the stick's full rates, Shift + I/J/K/L move the height and the pan, a right
-- mouse drag orbits (MOUSE deg a layout unit) and a middle drag pans (MPAN cm). In region mode I/J/K/L held (Shift or
-- not) and a middle drag pan the framing; a right drag goes to free mode first (from the saved free pose, else the
-- framing on screen). Each mouse wheel notch (main/boot.lua's mouse_wheel) zooms by ZOOM, up in, down out; in region
-- mode a turn goes to free mode first, as a right drag does. Turns made while the menu was closed are dropped at the
-- open. A right press is Back at its release unless the mouse moved CLICK units (hold_back, take_back).
-- The mode and the free pose are written to the file at each change (a stick, key or drag move once all are back at
-- rest) and read once a Lua load: only Reset replaces the pose.
-- The lens: k and tanv come first from the FOV and the local player's axis rule (lens). Once an open, MEASURE s after it
-- (the view's blend over), the look point is projected by the engine (o.project, the kit's): place put it at tangent
-- k, so tan(hfov / 2) = k / x for its screen x in half widths; k and tanv are then set from that tangent and the
-- screen's aspect, logged once. No projection: the first lens stays.
-- The preview lights (closet/ui/lights.lua) go on the camera actor at the open and follow its pose: light_next and the
-- pad's L3 released after a hold with no trigger (in both modes) take the next preset; light_up and light_down step its
-- intensity, as does each pull of RT (up) or LT (down) while L3 is held, when the triggers zoom nothing. Their preset
-- and intensity are written to the same line at each change and read with the pose.
-- forget() (the menu's Reset Stellar Closet, after its close) goes back to region mode with no free pose and the Game
-- preset at x1. It clears the file: at once, or once a closed camera is removed (its path stays in the file while it
-- blends out).
-- close() gives the view back while it is still ours, to the view target from before the open or the pawn, with a BLEND
-- s blend; the actor goes BLEND s later, in tick. stop() (coop off) gives it back with no blend and removes the actor at
-- once. A camera gone with its world (a map change) or whose view the game took (a cutscene, photo mode) stops with no
-- call on the view: it never fights for it; the menu's guards then close the menu. The first engine error of an open
-- is logged and closes the camera.
-- o: {store=link.store(Camera.FILE), log=, screen=function() the kit's {w, h} or nil, pad_bits=function() bits (1 X,
-- 2 L3, 4 R3) or nil, pad_levels=function() right stick x, y (-1..1, right and up positive), LT, RT (0..1) or nil,
-- held_keys=function() bits (1 right mouse, 2 middle mouse, 4 Shift, 8 I, 16 J, 32 K, 64 L, 128 U, 256 O) or nil,
-- mouse_wheel=function() the wheel's notches since the last call (up positive) or nil,
-- pointer=function() the kit's mouse x, y in layout units or nil, project=function(at, now) the kit's project
-- ({width, height, screen={x, y}} in layout units, screen nil without the engine's projection) or nil; tests
-- give unreal= (core/unreal.lua), actors= (core/actors.lua), pc=function() the player controller, her=function() EVE}.
--
-- The game's parts, read in Ghidra (SB-Win64-Shipping.exe, build 26123051) on 26 Nov 2026:
--   APlayerController.SetViewTargetWithBlend(NewViewTarget Object +0x0, BlendTime float +0x8, BlendFunc byte +0xc,
--     BlendExp float +0x10, bLockOutgoing bool): FFunctionParams 0x146e61550, exec 0x1448d5030.
--   AController.GetViewTarget() -> Object (params 0x146e2c5e0); APlayerController's (0x144477a50) asks its
--     PlayerCameraManager, whose GetViewTarget (FUN_14446d340) answers the pending target (+0x1640, the blend's) first,
--     else the view target (+0xfe0): during our blend it already answers our camera.
--   AController.K2_GetPawn() -> Object: params 0x146e2c7c0.
--   APlayerController.PlayerCameraManager: object at 0x360 (params 0x146616598); APlayerCameraManager GetCameraLocation
--     -> FVector, GetCameraRotation -> FRotator, GetFOVAngle -> float: params 0x146e5e1a0, 0x146e5e1f0, 0x146e5e240.
--   APlayerController.Player: object at 0x340 (params 0x1466164d0); ULocalPlayer.AspectRatioAxisConstraint: byte enum
--     at 0x94 (params 0x1465c49e8), EAspectRatioAxisConstraint AspectRatio_MaintainYFOV 0, _MaintainXFOV 1,
--     _MajorAxisFOV 2 (enumerators 0x1465483b0).
--   UCameraComponent.SetFieldOfView(InFieldOfView float): params 0x146e27470.
--   AActor.K2_GetActorLocation -> FVector, K2_GetActorRotation -> FRotator: params 0x146e1a730, 0x146e1a780.
--   ACharacter.CapsuleComponent: object at 0x338 (params 0x14651b690); UCapsuleComponent.GetScaledCapsuleHalfHeight
--     -> float: params 0x146e28680.
--   USceneComponent.K2_SetWorldLocationAndRotation(NewLocation, NewRotation, bSweep, SweepHitResult, bTeleport):
--     params 0x146e68500.
--   APlayerController.ProjectWorldLocationToScreen (used through ui/kit's project): native table entry 0x14661a7b0,
--     exec 0x1448de940; params (0x18 bytes, property list at 0x146617f18) WorldLocation FVector +0x0, ScreenLocation
--     FVector2D out +0xc, bPlayerViewportRelative bool +0x14 (setter 0x141150bc0), ReturnValue bool +0x15 (setter
--     0x141258890). The native (FUN_144204910) projects through the local player's projection data (its vtable
--     +0x2c0, GetProjectionData): the lens the view really renders.
local Slots=require('closet.slots')
local Lights=require('closet.ui.lights')
local Camera={}
Camera.FILE='coop-closet-camera.txt'
Camera.BLEND=0.3 -- s: the view's blend onto the camera and back (leviathan's); the actor goes after it.
Camera.EASE=0.35 -- s: the pose covers about 98% of a change in that time.
Camera.NDC=0.55 -- EVE's look point right of centre, in half widths: x 2976 of 3840, the middle of x 2112-3840.
Camera.STEP=10 -- degrees a key step orbits.
Camera.ZOOM=0.1 -- cam_in takes 10% off the distance; cam_out undoes it.
Camera.PITCH={-60,60} -- degrees, free mode.
Camera.DIST={40,500} -- cm, free mode.
Camera.PAN=80 -- cm either side, free mode.
-- Region mode's pan limits: EVE's look point stays between NDC 0.35 and 0.85 across and within half the half height up
-- or down. Tuned in game: at 0.9 her far arm was cut by the screen's edge, at 0.2 she stood under the detail panel.
Camera.RPAN={0.35,0.85,0.5}
Camera.DEAD=0.2 -- of each stick axis and trigger; the rest is rescaled to 0..1.
Camera.ORBIT,Camera.TILT,Camera.SLIDE=120,80,120 -- deg/s, deg/s, cm/s at full stick (and for the held keys).
Camera.MOUSE,Camera.MPAN=0.25,0.25 -- degrees a right drag orbits, cm a middle drag pans, per unit of the kit's layout.
Camera.CLICK=8 -- layout units: a right press released with less mouse movement is Back.
Camera.MEASURE=Camera.BLEND+0.1 -- s after an open: the lens is measured once the view is ours.
Camera.LENS_TOL,Camera.LENS_TRIES=0.1,30 -- A reading's tangent within 10% of an axis rule's; readings before giving up.
-- Each region's framing: {centre, span} in parts of her height from her feet, the span filling the screen's height;
-- {yaw, pitch} in degrees. Starting values to tune in game. The head was tuned there: her capsule is taller than her
-- head, so 0.92 aimed above it; her face sits at about 0.80.
Camera.REGIONS={head={0.80,0.22,15,5},torso={0.70,0.34,15,8},arms={0.64,0.46,25,8},hands={0.47,0.20,25,12},
    hips={0.52,0.28,20,5},legs={0.27,0.56,15,8},feet={0.05,0.16,20,25},full={0.52,1.10,15,5}}
-- TAB: each menu tab's region (closet/slots.lua Slots.MENUS); SLOT: the slots that go to the hands or the feet.
local TAB={full='full',head='head',torso='torso',arms='arms',hips='hips',intimate='hips',legs='legs',body='full',
    weapon='full'}
local SLOT={Gloves='hands',Fingernails='hands',TattooHand='hands',BraceletL='hands',BraceletR='hands',Rings='hands',
    Shoes='feet',Toenails='feet',TattooFoot='feet',AnkletL='feet',AnkletR='feet'}
local POSE={'yaw','pitch','dist','height','pan'}

-- The region of a slot id or a menu tab id.
function Camera.region(id) return SLOT[id] or TAB[Slots.menu(id) or id] or 'full' end
-- A region's pose for her height h; k: NDC times the tangent of half the horizontal FOV; tanv: the tangent of half the
-- vertical FOV. The look point's depth along the view is dist / sqrt(1 + k^2).
function Camera.framing(region,h,k,tanv)
    local r=Camera.REGIONS[region] or Camera.REGIONS.full
    return {yaw=r[3],pitch=r[4],dist=r[2]*h/2*math.sqrt(1+k*k)/tanv,height=r[1]*h,pan=0}
end
-- Where pose p puts the camera and how it turns, for EVE at L turned yaw with her feet at feet: the look point shows
-- at k / tan(hfov / 2) of the half width right of centre and at the middle of the height (no roll). Then the look point.
function Camera.place(p,L,yaw,feet,k)
    local a,e=math.rad(yaw+p.yaw),math.rad(p.pitch)
    local right=a-math.pi/2 -- The camera's right before its turn.
    local T={X=L.X+math.cos(right)*p.pan,Y=L.Y+math.sin(right)*p.pan,Z=feet+p.height}
    local at={X=T.X+p.dist*math.cos(e)*math.cos(a),Y=T.Y+p.dist*math.cos(e)*math.sin(a),Z=T.Z+p.dist*math.sin(e)}
    local pitch=-math.deg(math.asin(math.max(-1,math.min(1,math.sin(e)*math.sqrt(1+k*k)))))
    return at,{Pitch=pitch,Yaw=math.deg(a)+180-math.deg(math.atan(k,math.cos(math.rad(pitch)))),Roll=0},T
end

function Camera.new(o)
    local U=o.unreal or require('core.unreal')
    local actors=o.actors or require('core.actors')
    local store,log=o.store,o.log or function() end
    local pc_of=o.pc or U.controller
    local her=o.her or function() return U.her(U.valid(require('UEHelpers').GetPlayer())) end
    local self={}
    local mode,free='region',nil -- free: the free pose, nil until set.
    local loaded,left=false,nil -- The file read; the path of an earlier Lua load's camera it named.
    -- cam: {d=core/actors.lua spawn's, was=the view target from before, was_path=its path, h=her height, k, tanv};
    -- dying: {d=, at=} a closed camera removed at the clock's at; cur: the eased pose.
    local cam,dying,cur=nil,nil,nil
    local region='full'
    local rpan={pan=0,height=0} -- Region mode's pan of the framing, cm along the camera's right and up.
    local clock=0
    local dirty=false -- The stick, a held key or a drag moved the free pose since the last write.
    -- px, py: the mouse at the last tick while the right or middle button was held, else nil; back: {travel=} a right
    -- press hold_back took, until its release; back_due: that release was a click (Back), until take_back.
    local px,py,back,back_due=nil,nil,nil,false
    local forgot=false -- forget() ran: a write with nothing to keep clears the file.
    -- Read as held at an open: a hold from before is no press.
    local x_held,x_moved,r3_held,l3_held,l3_used,lt_held,rt_held=true,true,true,true,true,true,true
    local lights=Lights.new({unreal=U,log=log})

    local function is(a,b) return a~=nil and b~=nil and U.address(a)==U.address(b) end
    local function clamp(p)
        p.yaw=(p.yaw+180)%360-180
        p.pitch=math.max(Camera.PITCH[1],math.min(Camera.PITCH[2],p.pitch))
        p.dist=math.max(Camera.DIST[1],math.min(Camera.DIST[2],p.dist))
        p.pan=math.max(-Camera.PAN,math.min(Camera.PAN,p.pan))
        if cam then p.height=math.max(-10,math.min(cam.h+30,p.height)) end
        return p
    end
    -- The file: <camera path or empty>\t<region|free>\t<yaw>\t<pitch>\t<dist>\t<height>\t<pan>\t<preset>\t<intensity>,
    -- the pose fields empty with no free pose. Its answer. An older line ends after the pose: Game at x1.
    local function write()
        dirty=false
        local f={cam and cam.d.path or dying and dying.d.path or '',mode}
        if forgot and f[1]=='' and mode=='region' and not free and lights.preset()=='game' and lights.factor()==1 then
            store.clear()
            return true
        end
        for i,k in ipairs(POSE) do f[i+2]=free and string.format('%.3f',free[k]) or '' end
        f[8],f[9]=lights.preset(),string.format('%.2f',lights.factor())
        local saved,why=store.save(table.concat(f,'\t'))
        if saved==false then log('camera: '..Camera.FILE..' not written: '..tostring(why)) end
        return saved
    end
    local function load()
        loaded=true
        local f={}
        for x in ((store.load() or '')..'\t'):gmatch('([^\t]*)\t') do f[#f+1]=x end
        left=f[1]~='' and f[1] or nil
        if f[2]=='free' or f[2]=='region' then mode=f[2] end
        lights.set(f[8],f[9])
        local p={}
        for i,k in ipairs(POSE) do
            local v=tonumber(f[i+2])
            if not v or math.abs(v)>1e5 then return end -- A bad pose: none (nan and inf read as nil or above 1e5).
            p[k]=v
        end
        free=clamp(p)
    end
    -- An earlier Lua load's camera: the view back on EVE if it has it, then swept, the path field cleared.
    local function sweep()
        local p=left
        left=nil
        if not p then return end
        local pc,eve=pc_of(),her()
        local view=pc and U.valid(pc:GetViewTarget())
        if view and eve and actors.same(view,p) then pc:SetViewTargetWithBlend(eve,0,0,0,false) end
        log('camera: an earlier Lua load\'s camera '..(actors.sweep(p,'camera') and 'swept' or 'not found'))
        write()
    end
    local function first()
        if loaded then return end
        load()
        local ran,why=pcall(sweep)
        if not ran then log('camera: the sweep failed: '..tostring(why)) end
    end
    -- The region's framing with region mode's pan.
    local function framing()
        local p=Camera.framing(region,cam.h,cam.k,cam.tanv)
        p.pan,p.height=p.pan+rpan.pan,p.height+rpan.height
        return p
    end
    -- Region mode's pan moved by dp cm right and dh cm up, kept so that EVE's look point stays within RPAN on screen.
    -- The pan runs square to the line from the camera to the look point, not in the screen's plane: a pan p puts her
    -- look point at NDC n for p = dist (k - n t) / (1 + n k t), t the tangent of half the horizontal FOV. Up or down:
    -- RPAN[3] of the frame's half height at the look point (the region's span high).
    local function slide(dp,dh)
        local f=Camera.framing(region,cam.h,cam.k,cam.tanv)
        local t=cam.k/Camera.NDC
        local function at(n) return f.dist*(cam.k-n*t)/(1+n*cam.k*t) end
        local half=Camera.RPAN[3]*(Camera.REGIONS[region] or Camera.REGIONS.full)[2]*cam.h/2
        rpan.pan=math.max(at(Camera.RPAN[2]),math.min(at(Camera.RPAN[1]),rpan.pan+dp))
        rpan.height=math.max(-half,math.min(half,rpan.height+dh))
    end
    -- A right drag in region mode: free mode from the saved free pose, else from the framing on screen.
    local function to_free()
        if mode=='free' then return end
        mode='free'
        if not free then free=clamp(framing()) end
        write()
    end
    -- The view back from c while it is still ours: to the view target from before, else the pawn.
    local function give_back(c,blend)
        local pc=pc_of()
        local view=pc and U.valid(pc:GetViewTarget())
        if not is(view,c.d.actor) then return end
        local to=actors.same(c.was,c.was_path) or U.valid(pc:K2_GetPawn())
        if to then pc:SetViewTargetWithBlend(to,blend,0,0,false) end
    end
    local function remove(d)
        local ran,why=pcall(actors.remove,d)
        if not ran then log('camera: not removed: '..tostring(why)) end
    end
    -- k and tanv for the FOV fov: the FOV axis is the horizontal one unless the local player keeps the vertical one
    -- (MaintainYFOV, or MajorAxisFOV on a screen taller than wide). The aspect from the kit's screen (16:9 unread).
    local function lens(pc,fov)
        local v=o.screen and o.screen()
        local aspect=v and v.w>0 and v.h>0 and v.w/v.h or 16/9
        local read,axis=pcall(function() return U.value_of(pc.Player.AspectRatioAxisConstraint) end)
        axis=read and axis or 1
        local t=math.tan(math.rad(fov/2))
        if axis==0 or axis==2 and aspect<1 then return Camera.NDC*t*aspect,t,t,aspect end
        return Camera.NDC*t,t/aspect,t,aspect
    end
    local function toggle()
        mode=mode=='free' and 'region' or 'free'
        if mode=='free' and not free then free=clamp(framing()) end
        write()
    end
    local function reset()
        rpan.pan,rpan.height=0,0
        free,mode=clamp(framing()),'free'
        write()
    end

    -- The dead zone off a stick axis or trigger, the rest rescaled.
    local function dead(v)
        v=tonumber(v) or 0
        if math.abs(v)<=Camera.DEAD then return 0 end
        return (v>0 and 1 or -1)*(math.abs(v)-Camera.DEAD)/(1-Camera.DEAD)
    end
    local function pad(dt)
        local bits=o.pad_bits and o.pad_bits() or 0
        local sx,sy,lt,rt=0,0,0,0
        if o.pad_levels then sx,sy,lt,rt=o.pad_levels() end
        sx,sy,lt,rt=dead(sx),dead(sy),dead(lt),dead(rt)
        local x,l3,r3=bits%2==1,bits//2%2==1,bits//4%2==1
        local stick=sx~=0 or sy~=0
        if r3 and not r3_held then reset() end
        r3_held=r3
        if l3 and not l3_held then l3_used=false end
        if l3 and rt~=0 and not rt_held then lights.step(1); write() end
        if l3 and lt~=0 and not lt_held then lights.step(-1); write() end
        if l3 and (lt~=0 or rt~=0) then l3_used=true end
        if not l3 and l3_held and not l3_used then lights.next(); write() end
        l3_held,lt_held,rt_held=l3,lt~=0,rt~=0
        if l3 then lt,rt=0,0 end -- The triggers are the light's while L3 is held: no zoom.
        if x and not x_held then x_moved=false end
        if x and stick then x_moved=true end
        if not x and x_held and not x_moved then toggle() end
        x_held=x
        if mode~='free' then -- The stick pans the framing, X held or not; it moves no free pose.
            if stick then slide(sx*Camera.SLIDE*dt,sy*Camera.SLIDE*dt) end
            return false
        end
        local p=free
        if x and stick then p.height,p.pan=p.height+sy*Camera.SLIDE*dt,p.pan+sx*Camera.SLIDE*dt
        elseif stick then p.yaw,p.pitch=p.yaw-sx*Camera.ORBIT*dt,p.pitch+sy*Camera.TILT*dt end
        if lt~=0 or rt~=0 then p.dist=p.dist*2^((lt-rt)*dt) end
        return stick or lt~=0 or rt~=0
    end
    -- The native held read (nil with an older DLL): in free mode I/J/K/L held orbit and U/O zoom at the stick's full
    -- rates, Shift + I/J/K/L move the height and the pan; a right drag orbits, a middle drag pans (the kit's mouse
    -- position, read while one of them is held). A right press hold_back took ends here: Back at its release unless the
    -- mouse moved CLICK units or more. Whether the free pose moved.
    local function keys(dt)
        local bits=o.held_keys and o.held_keys()
        if not bits then return false end
        local function on(b) return bits//b%2==1 end
        local rmb,mmb,shift=on(1),on(2),on(4)
        local x,y
        if (rmb or mmb) and o.pointer then x,y=o.pointer() end
        local dx,dy=0,0
        if x and px then dx,dy=x-px,y-py end
        px,py=x,y
        if back then
            back.travel=back.travel+math.abs(dx)+math.abs(dy)
            if not rmb then back_due,back=back.travel<Camera.CLICK,nil end
        end
        local kx=(on(64) and 1 or 0)-(on(16) and 1 or 0) -- L right, J left.
        local ky=(on(8) and 1 or 0)-(on(32) and 1 or 0) -- I up, K down.
        local kz=shift and 0 or (on(256) and 1 or 0)-(on(128) and 1 or 0) -- O out, U in; Shift + U/O are the light's.
        -- A press hold_back took leaves Region mode only once it counts as a drag (CLICK units): jitter stays a Back.
        if rmb and (dx~=0 or dy~=0) and (not back or back.travel>=Camera.CLICK) then to_free()
        elseif mode~='free' then -- I/J/K/L and a middle drag pan the framing; U/O zoom nothing.
            slide(kx*Camera.SLIDE*dt,ky*Camera.SLIDE*dt)
            if mmb then slide(-dx*Camera.MPAN,dy*Camera.MPAN) end
            return false
        end
        local p=free
        if shift then p.height,p.pan=p.height+ky*Camera.SLIDE*dt,p.pan+kx*Camera.SLIDE*dt
        else p.yaw,p.pitch=p.yaw-kx*Camera.ORBIT*dt,p.pitch+ky*Camera.TILT*dt end
        p.dist=p.dist*2^(kz*dt)
        -- A right drag turns as the stick does (right: the camera to its right); down raises the camera. A middle drag
        -- moves the look point against the mouse, as if the scene were grabbed.
        if rmb then p.yaw,p.pitch=p.yaw-dx*Camera.MOUSE,p.pitch+dy*Camera.MOUSE
        elseif mmb then p.pan,p.height=p.pan-dx*Camera.MPAN,p.height+dy*Camera.MPAN end
        return kx~=0 or ky~=0 or kz~=0 or dx~=0 or dy~=0
    end
    -- The mouse wheel's notches since the last read: each up zooms in by ZOOM, down out; region mode goes to free mode
    -- first. Whether the free pose moved.
    local function wheel()
        local n=o.mouse_wheel and o.mouse_wheel() or 0
        if n==0 then return false end
        to_free()
        free.dist=free.dist*(1-Camera.ZOOM)^n
        return true
    end
    local function ease(a,b,k)
        local out={}
        for _,f in ipairs(POSE) do
            local d=b[f]-a[f]
            if f=='yaw' then d=(d+180)%360-180 end -- The short way round.
            out[f]=a[f]+d*k
        end
        return out
    end
    -- The real lens from the engine's projection of the look point T, which place put at tangent cam.k: its screen x
    -- in half widths is k / tan(hfov / 2). Once an open, at the first answer (nil while the kit is hidden: later).
    -- A reading is taken only when its tangent is within LENS_TOL of one an axis rule gives for the FOV:
    -- tan(fov / 2) for the horizontal axis, times the aspect for the vertical one. That rule's tangent is used.
    -- A reading taken while the view still lagged (in game: x 2.5, tan 0.170 for a 0.767 lens) is skipped. After
    -- LENS_TRIES skipped readings the first lens stays, said once with the last reading.
    -- shortcut: T is this frame's; if the view's pose lags a frame, a pose still easing skews it a little.
    local function measure(T)
        local v=o.project(T,os.clock())
        if not v then return end
        local x=v.screen and tonumber(v.width) and v.width>0 and v.height>0 and 2*v.screen.x/v.width-1
        local tanh=x and x>0.05 and cam.k/x
        local fit
        for _,t in ipairs(tanh and {cam.t,cam.t*cam.aspect} or {}) do
            if math.abs(tanh/t-1)<Camera.LENS_TOL then fit=t; break end
        end
        if not fit then
            cam.tries=(cam.tries or 0)+1
            if cam.tries<Camera.LENS_TRIES then return end
            cam.measured=true
            local why=x and string.format('the look point at x %.3f',x) or 'no screen point'
            if tanh then
                why=string.format('the last reading tan(hfov/2)=%.3f fits neither %.3f nor %.3f',tanh,cam.t,
                    cam.t*cam.aspect)
            end
            return log('camera: lens not measured: '..why)
        end
        cam.measured=true
        cam.k,cam.tanv=Camera.NDC*fit,fit*v.height/v.width
        log(string.format('camera: lens measured, tan(hfov/2)=%.3f',fit))
    end
    -- One frame: the camera alive and the view ours, else it stops; the pad; the pose eased and placed.
    local function drive(dt)
        local d=cam.d
        if not actors.same(d.actor,d.path) then -- Gone with its world (a map change), its lights with it.
            cam=nil
            lights.off()
            log('camera: gone with its world')
            return write()
        end
        local pc=pc_of()
        if not is(pc and U.valid(pc:GetViewTarget()),d.actor) then -- The game took the view: never fought for.
            cam,dying=nil,{d=d,at=clock+Camera.BLEND}
            lights.off()
            return log('camera: the game took the view')
        end
        local eve=her()
        if not eve then return end
        local moved=pad(dt)
        moved=keys(dt) or moved
        moved=wheel() or moved
        -- Written once the stick, the keys and the drags are back at rest.
        if moved then clamp(free); dirty=true elseif dirty then write() end
        local L=U.value_of(eve:K2_GetActorLocation())
        local yaw=U.value_of(eve:K2_GetActorRotation()).Yaw
        local target=mode=='free' and free or framing()
        -- The first frame there at once: the view's blend moves from the game's camera.
        cur=cur and ease(cur,target,1-math.exp(-4*dt/Camera.EASE)) or ease(target,target,0)
        local at,rot,T=Camera.place(cur,L,yaw,L.Z-cam.h/2,cam.k)
        cam.at,cam.look=at,T -- shot()'s.
        d.mesh:K2_SetWorldLocationAndRotation(at,rot,false,{},false)
        lights.place(cur.dist,cam.k)
        if not cam.measured and o.project and clock>=cam.since+Camera.MEASURE then measure(T) end
    end

    -- A camera on the menu's open, while the view is on EVE (else none, quietly: the menu works without it).
    function self.open()
        local d
        local ran,why=pcall(function()
            first()
            if dying then remove(dying.d); dying=nil end
            if cam then return end
            local pc,eve=pc_of(),her()
            if not (pc and eve) then return 'no player controller or no EVE' end
            local view=U.valid(pc:GetViewTarget())
            if not is(view,eve) then return 'the view is not on EVE' end
            local m=pc.PlayerCameraManager
            local at,r,fov=U.value_of(m:GetCameraLocation()),U.value_of(m:GetCameraRotation()),U.value_of(m:GetFOVAngle())
            local hh=U.value_of(eve.CapsuleComponent:GetScaledCapsuleHalfHeight())
            d=actors.spawn(eve:GetWorld(),{X=at.X,Y=at.Y,Z=at.Z},{Pitch=r.Pitch,Yaw=r.Yaw,Roll=0},{camera=true})
            cam={d=d,was=view,was_path=view:GetFullName():match('^%S+ (.+)$'),h=2*hh,since=clock}
            cam.k,cam.tanv,cam.t,cam.aspect=lens(pc,fov)
            rpan.pan,rpan.height=0,0
            if mode=='free' and not free then free=clamp(framing()) end
            -- The file before the view changes: a camera the next Lua load could not sweep never takes it.
            if write()==false then cam=nil; remove(d); d=nil; return 'the file could not be written' end
            d.mesh:SetFieldOfView(fov)
            pc:SetViewTargetWithBlend(d.actor,Camera.BLEND,0,0,false)
            cur,x_held,x_moved,r3_held,l3_held,l3_used,lt_held,rt_held=nil,true,true,true,true,true,true,true
            px,py,back,back_due=nil,nil,nil,false
            if o.mouse_wheel then o.mouse_wheel() end -- Turns made while the menu was closed are dropped.
            lights.on(d.actor)
            log(string.format('camera: on (%s), FOV %.1f, her height %.0f cm, lights %s x%g',mode,fov,cam.h,
                lights.preset(),lights.factor()))
        end)
        if not ran then
            log('camera: not on: '..tostring(why))
            if cam then self.close() elseif d then remove(d) end
        elseif why then log('camera: not on: '..why) end
    end
    -- The menu's close: the view back while it is still ours, the actor removed BLEND s later (tick).
    function self.close()
        back,back_due=nil,false
        if not cam then
            if dirty then write() end
            return
        end
        local c=cam
        cam=nil
        lights.off() -- They go with the actor.
        local ran,why=pcall(give_back,c,Camera.BLEND)
        if not ran then log('camera: the view not given back: '..tostring(why)) end
        dying={d=c.d,at=clock+Camera.BLEND}
        write()
    end
    -- coop off: the view back with no blend, every camera removed at once, the path field cleared.
    function self.stop()
        local c=cam
        cam,back,back_due=nil,nil,false
        lights.off()
        if c then
            local ran,why=pcall(give_back,c,0)
            if not ran then log('camera: the view not given back: '..tostring(why)) end
            remove(c.d)
        end
        if dying then remove(dying.d); dying=nil end
        if loaded then write() end -- Never before the file is read: its pose would be lost.
    end
    -- Each frame (the menu's tick): dt s since the last; region: the focused slot's or tab's, nil while closed.
    function self.tick(dt,r)
        dt=math.min(math.max(tonumber(dt) or 0,0),0.1)
        clock=clock+dt
        if r and r~=region then rpan.pan,rpan.height=0,0 end -- A region change clears region mode's pan.
        region=r or region
        first()
        if dying and clock>=dying.at then
            local d=dying.d
            dying=nil
            remove(d)
            write()
        end
        if not cam then return end
        local ran,why=pcall(drive,dt)
        if not ran then
            log('camera: '..tostring(why))
            self.close()
        end
    end
    -- A camera word of the menu's: cam_mode, cam_reset, light_next, light_up, light_down, or a step (cam_left,
    -- cam_right, cam_up, cam_down, cam_in, cam_out; in region mode the first four pan the framing STEP cm). Nothing
    -- without a camera.
    function self.word(w)
        if not cam then return end
        if w=='cam_mode' then return toggle() end
        if w=='cam_reset' then return reset() end
        if w=='light_next' then lights.next(); return write() end
        if w=='light_up' or w=='light_down' then lights.step(w=='light_up' and 1 or -1); return write() end
        if o.held_keys and o.held_keys() then return end -- The held read is live: the held keys move it (tick).
        local s=Camera.STEP
        if mode~='free' then
            if w=='cam_left' then slide(-s,0) elseif w=='cam_right' then slide(s,0)
            elseif w=='cam_up' then slide(0,s) elseif w=='cam_down' then slide(0,-s) end
            return
        end
        local p=free
        if w=='cam_left' then p.yaw=p.yaw+s elseif w=='cam_right' then p.yaw=p.yaw-s
        elseif w=='cam_up' then p.pitch=p.pitch+s elseif w=='cam_down' then p.pitch=p.pitch-s
        elseif w=='cam_in' then p.dist=p.dist*(1-Camera.ZOOM) elseif w=='cam_out' then p.dist=p.dist/(1-Camera.ZOOM)
        else return end
        clamp(p)
        write()
    end
    -- Reset Stellar Closet (after the menu's close): region mode, no free pose, Game at x1, the file cleared.
    function self.forget()
        mode,free,forgot='region',nil,true
        lights.set('game',1)
        write()
    end
    -- The menu's Back from a right press: true while the camera runs and the held read says right mouse is held, so
    -- the press may start a drag; the release then decides (take_back). False: Back at once.
    function self.hold_back()
        local bits=cam and o.held_keys and o.held_keys()
        if not bits or bits%2==0 then return false end
        back={travel=0}
        if o.pointer then px,py=o.pointer() end
        return true
    end
    -- True once after a right press hold_back took was released with less than CLICK units of mouse movement.
    function self.take_back()
        local due=back_due
        back_due=false
        return due
    end
    function self.running() return cam~=nil end
    function self.mode() return mode end
    -- The view as last placed, for the menu's Preview picture (closet/thumbs.lua's snap): {at=the camera, look=its look
    -- point, tanv=the screen's vertical half-angle tangent}; nil with no camera or before its first place.
    function self.shot() return cam and cam.at and {at=cam.at,look=cam.look,tanv=cam.tanv} or nil end
    -- The light preset (closet/ui/lights.lua Lights.ORDER) and its intensity factor.
    function self.light() return lights.preset(),lights.factor() end
    return self
end

return Camera
