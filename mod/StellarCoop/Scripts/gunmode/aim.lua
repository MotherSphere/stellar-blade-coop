-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Where the rounds go and where the camera looks, standing.
-- * The NIKKE bullet's ProjectileTable row (P_Eve_GunNikke_ShootSlug1_Projectile1) is live data: its Dest takes the
--   drone shot's frame (TransformType and RelativeAxisType copied from P_Eve_Gun_ShootSlug1_Projectile1: EVE's root,
--   yaw only), and before each shot DestTargetRelativeLocation becomes the crosshair point in that frame. Every round
--   then flies to the screen-centre point, pitch included. Only FindRow(string) is used: another lookup crashed.
-- * TPS mode 2 (NIKKE: fixed camera, the mouse moves a reticle) becomes 0 (the drone aim's: the camera follows the
--   mouse and the game turns EVE with it) while standing, and goes back to 2 crouched and at the exit. If mode 0 ever
--   drops the gun stance, it is put back to 2 for the rest of the Lua load (dead).
-- * CameraBoom.CustomOffset moves the camera over the shoulder while standing.
-- No struct goes to the game from EVE's tick many times a second: those calls are what the crashes had in common.
local Aim={}

-- target's offset from loc in a frame turned yaw degrees (EVE's root, yaw only): forward, right, up.
function Aim.local_offset(target,loc,yaw)
    local dx,dy,dz=target.X-loc.X,target.Y-loc.Y,target.Z-loc.Z
    local r=math.rad(yaw)
    local c,s=math.cos(r),math.sin(r)
    return dx*c+dy*s,-dx*s+dy*c,dz
end

local ROW='P_Eve_GunNikke_ShootSlug1_Projectile1'
local DRONE_ROW='P_Eve_Gun_ShootSlug1_Projectile1'
local TABLE='/Game/Local/Data/ProjectileTable.ProjectileTable'

-- g: gun mode's shared state (gunmode/mode.lua): log, try, valid, pawn().
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

    -- Before a shot: the row's destination = target (world) in EVE's root frame.
    function self.write(p,target)
        if not (self.row and target) then return end
        local loc=g.try(function() return p:K2_GetActorLocation() end)
        local rot=g.try(function() return p:K2_GetActorRotation() end)
        if not (loc and rot) then return end
        local x,y,z=Aim.local_offset(target,loc,rot.Yaw)
        local ok=pcall(function() local v=self.row.DestTargetRelativeLocation; v.X=x; v.Y=y; v.Z=z end)
        if self.writes<3 then self.writes=self.writes+1; g.log(('aim: shot at (%.0f, %.0f, %.0f) %s'):format(x,y,z,
            ok and 'written' or 'refused')) end
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
