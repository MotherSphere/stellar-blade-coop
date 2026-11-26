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
-- moves the height and the pan (SLIDE cm/s); DEAD of each axis is ignored. In region mode the steps, the stick and the
-- triggers move nothing. X released after a hold with no stick toggles region and free (cam_mode too); R3 and cam_reset
-- set the free pose to the region's framing and go to free mode. The mode and the free pose are written to the file
-- at each change (a stick move once the stick is back at rest) and read once a Lua load: only Reset replaces the pose.
-- close() gives the view back while it is still ours, to the view target from before the open or the pawn, with a BLEND
-- s blend; the actor goes BLEND s later, in tick. stop() (coop off) gives it back with no blend and removes the actor at
-- once. A camera gone with its world (a map change) or whose view the game took (a cutscene, photo mode) stops with no
-- call on the view: it never fights for it; the menu's guards then close the menu. The first engine error of an open
-- is logged and closes the camera.
-- o: {store=link.store(Camera.FILE), log=, screen=function() the kit's {w, h} or nil, pad_bits=function() bits (1 X,
-- 4 R3) or nil, pad_levels=function() right stick x, y (-1..1, right and up positive), LT, RT (0..1) or nil; tests
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
local Slots=require('closet.slots')
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
Camera.DEAD=0.2 -- of each stick axis and trigger; the rest is rescaled to 0..1.
Camera.ORBIT,Camera.TILT,Camera.SLIDE=120,80,120 -- deg/s, deg/s, cm/s at full stick.
-- Each region's framing (starting values, to tune in game): {centre, span} in parts of her height from her feet, the
-- span filling the screen's height; {yaw, pitch} in degrees.
Camera.REGIONS={head={0.92,0.20,15,5},torso={0.70,0.34,15,8},arms={0.64,0.46,25,8},hands={0.47,0.20,25,12},
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
-- at k / tan(hfov / 2) of the half width right of centre and at the middle of the height (no roll).
function Camera.place(p,L,yaw,feet,k)
    local a,e=math.rad(yaw+p.yaw),math.rad(p.pitch)
    local right=a-math.pi/2 -- The camera's right before its turn.
    local T={X=L.X+math.cos(right)*p.pan,Y=L.Y+math.sin(right)*p.pan,Z=feet+p.height}
    local at={X=T.X+p.dist*math.cos(e)*math.cos(a),Y=T.Y+p.dist*math.cos(e)*math.sin(a),Z=T.Z+p.dist*math.sin(e)}
    local pitch=-math.deg(math.asin(math.max(-1,math.min(1,math.sin(e)*math.sqrt(1+k*k)))))
    return at,{Pitch=pitch,Yaw=math.deg(a)+180-math.deg(math.atan(k,math.cos(math.rad(pitch)))),Roll=0}
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
    local clock=0
    local dirty=false -- The stick moved the free pose since the last write.
    local x_held,x_moved,r3_held=true,true,true -- Read as held at an open: a hold from before is no press.

    local function is(a,b) return a~=nil and b~=nil and U.address(a)==U.address(b) end
    local function clamp(p)
        p.yaw=(p.yaw+180)%360-180
        p.pitch=math.max(Camera.PITCH[1],math.min(Camera.PITCH[2],p.pitch))
        p.dist=math.max(Camera.DIST[1],math.min(Camera.DIST[2],p.dist))
        p.pan=math.max(-Camera.PAN,math.min(Camera.PAN,p.pan))
        if cam then p.height=math.max(-10,math.min(cam.h+30,p.height)) end
        return p
    end
    -- The file: <camera path or empty>\t<region|free>[\t<yaw>\t<pitch>\t<dist>\t<height>\t<pan>]. Its answer.
    local function write()
        dirty=false
        local f={cam and cam.d.path or dying and dying.d.path or '',mode}
        for _,k in ipairs(free and POSE or {}) do f[#f+1]=string.format('%.3f',free[k]) end
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
    local function framing() return Camera.framing(region,cam.h,cam.k,cam.tanv) end
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
        if axis==0 or axis==2 and aspect<1 then return Camera.NDC*t*aspect,t end
        return Camera.NDC*t,t/aspect
    end
    local function toggle()
        mode=mode=='free' and 'region' or 'free'
        if mode=='free' and not free then free=clamp(framing()) end
        write()
    end
    local function reset()
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
        local x,r3=bits%2==1,bits//4%2==1
        local stick=sx~=0 or sy~=0
        if r3 and not r3_held then reset() end
        r3_held=r3
        if x and not x_held then x_moved=false end
        if x and stick then x_moved=true end
        if not x and x_held and not x_moved then toggle() end
        x_held=x
        if mode~='free' then return end
        local p=free
        if x and stick then p.height,p.pan=p.height+sy*Camera.SLIDE*dt,p.pan+sx*Camera.SLIDE*dt
        elseif stick then p.yaw,p.pitch=p.yaw-sx*Camera.ORBIT*dt,p.pitch+sy*Camera.TILT*dt end
        if lt~=0 or rt~=0 then p.dist=p.dist*2^((lt-rt)*dt) end
        if stick or lt~=0 or rt~=0 then clamp(p); dirty=true
        elseif dirty then write() end
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
    -- One frame: the camera alive and the view ours, else it stops; the pad; the pose eased and placed.
    local function drive(dt)
        local d=cam.d
        if not actors.same(d.actor,d.path) then -- Gone with its world (a map change).
            cam=nil
            log('camera: gone with its world')
            return write()
        end
        local pc=pc_of()
        if not is(pc and U.valid(pc:GetViewTarget()),d.actor) then -- The game took the view: never fought for.
            cam,dying=nil,{d=d,at=clock+Camera.BLEND}
            return log('camera: the game took the view')
        end
        local eve=her()
        if not eve then return end
        pad(dt)
        local L=U.value_of(eve:K2_GetActorLocation())
        local yaw=U.value_of(eve:K2_GetActorRotation()).Yaw
        local target=mode=='free' and free or framing()
        -- The first frame there at once: the view's blend moves from the game's camera.
        cur=cur and ease(cur,target,1-math.exp(-4*dt/Camera.EASE)) or ease(target,target,0)
        local at,rot=Camera.place(cur,L,yaw,L.Z-cam.h/2,cam.k)
        d.mesh:K2_SetWorldLocationAndRotation(at,rot,false,{},false)
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
            cam={d=d,was=view,was_path=view:GetFullName():match('^%S+ (.+)$'),h=2*hh}
            cam.k,cam.tanv=lens(pc,fov)
            if mode=='free' and not free then free=clamp(framing()) end
            -- The file before the view changes: a camera the next Lua load could not sweep never takes it.
            if write()==false then cam=nil; remove(d); d=nil; return 'the file could not be written' end
            d.mesh:SetFieldOfView(fov)
            pc:SetViewTargetWithBlend(d.actor,Camera.BLEND,0,0,false)
            cur,x_held,x_moved,r3_held=nil,true,true,true
            log(string.format('camera: on (%s), FOV %.1f, her height %.0f cm',mode,fov,cam.h))
        end)
        if not ran then
            log('camera: not on: '..tostring(why))
            if cam then self.close() elseif d then remove(d) end
        elseif why then log('camera: not on: '..why) end
    end
    -- The menu's close: the view back while it is still ours, the actor removed BLEND s later (tick).
    function self.close()
        if not cam then
            if dirty then write() end
            return
        end
        local c=cam
        cam=nil
        local ran,why=pcall(give_back,c,Camera.BLEND)
        if not ran then log('camera: the view not given back: '..tostring(why)) end
        dying={d=c.d,at=clock+Camera.BLEND}
        write()
    end
    -- coop off: the view back with no blend, every camera removed at once, the path field cleared.
    function self.stop()
        local c=cam
        cam=nil
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
    -- A camera word of the menu's: cam_mode, cam_reset, or in free mode a step (cam_left, cam_right, cam_up,
    -- cam_down, cam_in, cam_out). Nothing without a camera.
    function self.word(w)
        if not cam then return end
        if w=='cam_mode' then return toggle() end
        if w=='cam_reset' then return reset() end
        if mode~='free' then return end
        local p,s=free,Camera.STEP
        if w=='cam_left' then p.yaw=p.yaw+s elseif w=='cam_right' then p.yaw=p.yaw-s
        elseif w=='cam_up' then p.pitch=p.pitch+s elseif w=='cam_down' then p.pitch=p.pitch-s
        elseif w=='cam_in' then p.dist=p.dist*(1-Camera.ZOOM) elseif w=='cam_out' then p.dist=p.dist/(1-Camera.ZOOM)
        else return end
        clamp(p)
        write()
    end
    function self.running() return cam~=nil end
    function self.mode() return mode end
    return self
end

return Camera
