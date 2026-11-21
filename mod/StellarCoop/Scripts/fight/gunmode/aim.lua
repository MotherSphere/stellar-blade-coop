-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Where the rounds go and where the camera looks, standing.
-- * The NIKKE bullet's ProjectileTable row (P_Eve_GunNikke_ShootSlug1_Projectile1) is live data: its Dest is on EVE
--   (DestTarget MainActor, set by fight/gunmode/data.lua) in the drone shot's frame (TransformType and
--   RelativeAxisType copied from P_Eve_Gun_ShootSlug1_Projectile1). In each frame of firing mode
--   DestTargetRelativeLocation becomes the crosshair point in that frame. Every round then flies to the screen-centre
--   point of the frame it spawns in, pitch included. Only FindRow(string) is used: another lookup crashed.
-- * The frame, read in Ghidra on 26123051. DestTarget is a byte at 0x1dd (ESBProjectileTarget, enum params
--   0x146d34f70: MainActor 0, OtherActor 1, StartToDestDirection 3). The shot (0x141c4be30) builds an actor target
--   through 0x14228c020 for 0 and 1 only. The shipped StartToDestDirection put the destination on the line to SB's own
--   target location with the offset in world axes (the zero rotator 0x147112ca8). Its rounds went to the side.
--   The row's fields (property params of DestTargetTransformType at 0x145dfff80, DestTargetRelativeAxisType at
--   0x145dffdc0): DestTargetTransformType a byte at 0x1e0 (ESBTargetLocationTransformType, enum params 0x146d374f0:
--   Base 0, Socket 1, Component 2), DestTargetRelativeLocation an FVector at 0x1f8, DestTargetRelativeAxisType a byte
--   at 0x228 (ESBMovementTargetRelativeAxisType, 0x146d336b0: World 0, ParentAxis 1, RootAxis 2, InputDirection 3).
--   The drone row's pair reads 0/2 in game: Base and RootAxis. The projectile's start (0x141c4ab60) builds its target
--   through 0x14228c020; the target's update (0x142431530) takes, for Base, the actor's RootComponent (AActor+0x178,
--   params 0x1464ca8f0) world location (ComponentToWorld translation, component+0x200) and, for RootAxis, turns the
--   offset by that component's world rotation (its quaternion, component+0x1f0). That is K2_GetActorLocation and
--   K2_GetActorRotation, pitch and roll included. Her mesh's own turn (gun mode's aim_mesh_yaw) is not in it.
-- * TPS mode 2 (NIKKE: fixed camera, the mouse moves a reticle) becomes 0 (the drone aim's: the camera follows the
--   mouse and the game turns EVE with it) while standing, and goes back to 2 crouched and at the exit. If mode 0 ever
--   drops the gun stance, it is put back to 2 for the rest of the Lua load (dead).
-- * CameraBoom.CustomOffset moves the camera over the shoulder while standing.
-- No struct goes to the game as a call's argument from here many times a second: those calls are what the crashes had
-- in common. The row's two vectors are memory writes, so firing mode writes them every frame.
local Aim={}

-- The forward, right and up axes of a rotator ({Pitch, Yaw, Roll}, or a yaw in degrees), as UE's FRotationMatrix
-- rows: nine numbers.
local function axes(rot)
    if type(rot)=='number' then rot={Pitch=0,Yaw=rot,Roll=0} end
    local p,y,r=math.rad(rot.Pitch),math.rad(rot.Yaw),math.rad(rot.Roll)
    local SP,CP,SY,CY,SR,CR=math.sin(p),math.cos(p),math.sin(y),math.cos(y),math.sin(r),math.cos(r)
    return CP*CY,CP*SY,SP, SR*SP*CY-CR*SY,SR*SP*SY+CR*CY,-SR*CP, -(CR*SP*CY+SR*SY),CY*SR-CR*SP*SY,CR*CP
end
-- target's offset from loc in the frame turned rot (EVE's root): forward, right, up.
function Aim.local_offset(target,loc,rot)
    local dx,dy,dz=target.X-loc.X,target.Y-loc.Y,target.Z-loc.Z
    local fx,fy,fz,rx,ry,rz,ux,uy,uz=axes(rot)
    return dx*fx+dy*fy+dz*fz,dx*rx+dy*ry+dz*rz,dx*ux+dy*uy+dz*uz
end
-- The world point of offset (x forward, y right, z up) from loc in the frame turned rot: local_offset backwards, as
-- SB places the round's destination.
function Aim.world_point(x,y,z,loc,rot)
    local fx,fy,fz,rx,ry,rz,ux,uy,uz=axes(rot)
    return {X=loc.X+x*fx+y*rx+z*ux,Y=loc.Y+x*fy+y*ry+z*uy,Z=loc.Z+x*fz+y*rz+z*uz}
end
-- The angle in degrees between the lines from `from` to a and to b.
function Aim.apart(a,b,from)
    local ax,ay,az=a.X-from.X,a.Y-from.Y,a.Z-from.Z
    local bx,by,bz=b.X-from.X,b.Y-from.Y,b.Z-from.Z
    local l=math.sqrt((ax*ax+ay*ay+az*az)*(bx*bx+by*by+bz*bz))
    if l<1e-9 then return 0 end
    return math.deg(math.acos(math.max(-1,math.min(1,(ax*bx+ay*by+az*bz)/l))))
end
-- The spread: target moved across the line from `from` by at most deg degrees seen from there, in a direction and to
-- a share of that given by u and v (each in [0, 1): math.random()). Uniform over the cone's disc. deg 0, no from or a
-- target under 1 cm away: target itself.
function Aim.spread(target,from,deg,u,v)
    if not (target and from and deg and deg>0) then return target end
    local dx,dy,dz=target.X-from.X,target.Y-from.Y,target.Z-from.Z
    local L=math.sqrt(dx*dx+dy*dy+dz*dz)
    if L<1 then return target end
    dx,dy,dz=dx/L,dy/L,dz/L
    local ax,ay=-dy,dx -- across the line, level; straight up or down: along X
    local al=math.sqrt(ax*ax+ay*ay)
    if al<1e-6 then ax,ay=1,0 else ax,ay=ax/al,ay/al end
    local bx,by,bz=-dz*ay,dz*ax,dx*ay-dy*ax -- the line cross the first axis
    local r=L*math.tan(math.rad(deg))*math.sqrt(u)
    local c,s=r*math.cos(2*math.pi*v),r*math.sin(2*math.pi*v)
    return {X=target.X+ax*c+bx*s,Y=target.Y+ay*c+by*s,Z=target.Z+bz*s}
end

local ROW='P_Eve_GunNikke_ShootSlug1_Projectile1'
local DRONE_ROW='P_Eve_Gun_ShootSlug1_Projectile1'
local TABLE='/Game/Local/Data/ProjectileTable.ProjectileTable'

-- g: gun mode's shared state (fight/gunmode/mode.lua): log, try, valid, pawn().
function Aim.new(g)
    local self={row=nil,dead=false,mode0=false,cam_saved=nil,writes=0}

    function self.setup()
        if self.row then return true end
        local dt=g.try(function() return StaticFindObject(TABLE) end)
        if not g.valid(dt) then g.log('aim: ProjectileTable not found'); return false end
        local ok,r=pcall(function() return dt:FindRow(ROW) end)
        local okd,d=pcall(function() return dt:FindRow(DRONE_ROW) end)
        if not (ok and r and okd and d) then g.log('aim: rows not found ('..tostring(r)..')'); return false end
        local tt=g.try(function() return d.DestTargetTransformType end)
        local ax=g.try(function() return d.DestTargetRelativeAxisType end)
        if type(tt)~='number' or type(ax)~='number' then g.log('aim: the drone row reads no frame'); return false end
        local okw=pcall(function() r.DestTargetTransformType=tt; r.DestTargetRelativeAxisType=ax end)
        if okw then self.row=r end
        g.log('aim: NIKKE row on the drone frame ('..tt..'/'..ax..') '..(okw and 'set' or 'refused'))
        return okw
    end

    -- The row's destination = target (world) in EVE's root frame. loc, rot: her root's, when the caller read them.
    function self.write(p,target,loc,rot)
        if not (self.row and target) then return end
        loc=loc or g.try(function() return p:K2_GetActorLocation() end)
        rot=rot or g.try(function() return p:K2_GetActorRotation() end)
        if not (loc and rot) then return end
        local x,y,z=Aim.local_offset(target,loc,rot)
        local ok=pcall(function() local v=self.row.DestTargetRelativeLocation; v.X=x; v.Y=y; v.Z=z end)
        if ok then self.dx,self.dy,self.dz=x,y,z end
        if self.writes<6 then self.writes=self.writes+1; g.log(('aim: shot at (%.0f, %.0f, %.0f) %s'):format(x,y,z,
            ok and 'written' or 'refused')) end
    end
    -- Where a round that spawns now goes: the row's destination as SB reads it, placed from her root as it is now
    -- (SB does the same at the round's spawn). It reads the row back, not the last write: a row that does not put the
    -- destination in her root frame (DestTarget MainActor 0, DestTargetTransformType Base 0, DestTargetRelativeAxisType
    -- RootAxis 2) gives nil and the fields it holds. nil before a write.
    function self.went(p)
        local r=self.row
        if not (r and self.dx) then return nil end
        local f=g.try(function() return {r.DestTarget,r.DestTargetTransformType,r.DestTargetRelativeAxisType} end)
        if not (f and f[1]==0 and f[2]==0 and f[3]==2) then
            f=f or {}
            return nil,('dest target %s, transform %s, axis %s: not her root frame'):format(tostring(f[1]),
                tostring(f[2]),tostring(f[3]))
        end
        local d=g.try(function() local v=r.DestTargetRelativeLocation; return {v.X,v.Y,v.Z} end)
        local loc=g.try(function() return p:K2_GetActorLocation() end)
        local rot=g.try(function() return p:K2_GetActorRotation() end)
        return d and loc and rot and Aim.world_point(d[1],d[2],d[3],loc,rot)
    end

    -- Native fire: the bullet's start (fight/gunmode/data.lua made it EVE's base and an offset in her root's frame,
    -- pitch and roll included, like its destination) put on the point muzzle (world), the rifle's FX_Fire socket.
    -- A muzzle less than min_forward ahead of her (the rifle not up yet, or posed wrong: the shot then started on
    -- her body) gives way to fallback, a point at her right shoulder in her frame.
    function self.write_start(p,muzzle,min_forward,fallback,loc,rot)
        if not self.row then return end
        loc=loc or g.try(function() return p:K2_GetActorLocation() end)
        rot=rot or g.try(function() return p:K2_GetActorRotation() end)
        if not (loc and rot) then return end
        local x,y,z
        if muzzle then x,y,z=Aim.local_offset(muzzle,loc,rot) end
        if not x or x<(min_forward or 0) then x,y,z=fallback.X,fallback.Y,fallback.Z end
        local ok=pcall(function() local v=self.row.StartTargetRelativeLocation; v.X=x; v.Y=y; v.Z=z end)
        if (self.starts or 0)<3 then self.starts=(self.starts or 0)+1
            g.log(('aim: shot start (%.0f, %.0f, %.0f) %s'):format(x,y,z,ok and 'written' or 'refused')) end
    end

    local function mode(p) return tonumber(g.try(function() return p:GetTPSModeType() end)) end
    function self.set_mode(m,why)
        local p=g.pawn(); if not p then return false end
        pcall(function() p.TPSModeType=m end)
        local now=mode(p)
        self.mode0=now==0
        g.log(('aim: TPS mode %d (%s), now %s'):format(m,why,tostring(now)))
        return now==m
    end
    -- Standing, once a second: NIKKE's mode 2 to 0; mode 0 with the gun stance gone puts 2 back for good.
    function self.stand_tick(gun_on)
        if self.dead then return end
        local p=g.pawn(); if not p then return end
        local m=mode(p)
        local stance=g.stance(p) or '?'
        if m==0 and not stance:find('GunNikke',1,true) then
            g.log('aim: TPS mode 0 lost the gun stance ('..stance..'): back to 2 for this Lua load')
            self.dead=true; self.set_mode(2,'revert'); gun_on()
            return
        end
        self.mode0=m==0
        if m==2 then self.set_mode(0,'standing') end
    end
    function self.crouch_tick()
        local p=g.pawn()
        if p and mode(p)==0 then self.set_mode(2,'crouched') end
    end

    function self.camera_on(o)
        local p=g.pawn(); if not p then return end
        local boom=g.try(function() return p.CameraBoom end)
        if not g.valid(boom) then return end
        if not self.cam_saved then
            local c=boom.CustomOffset
            self.cam_saved={X=c.X,Y=c.Y,Z=c.Z}
        end
        pcall(function() local c=boom.CustomOffset; c.X=o.X; c.Y=o.Y; c.Z=o.Z end)
    end
    function self.camera_off()
        local p,s=g.pawn(),self.cam_saved
        self.cam_saved=nil
        if not (p and s) then return end
        local boom=g.try(function() return p.CameraBoom end)
        if g.valid(boom) then pcall(function() local c=boom.CustomOffset; c.X=s.X; c.Y=s.Y; c.Z=s.Z end) end
    end

    return self
end

return Aim
