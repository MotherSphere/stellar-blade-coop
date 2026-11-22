-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The layer's chest turn (AimRot, added to Bip001-Spine2 in component space since the v3c pak): a closed loop that turns
-- her chest until the rifle's real bore points at the aim point. The NIKKE clip's arms and the rifle in her hands turn
-- with her chest. Pure maths (vectors {X,Y,Z}, quaternions {x,y,z,w} in UE conventions) so lua5.4 tests it.
local A={}

local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b) return {X=a.Y*b.Z-a.Z*b.Y,Y=a.Z*b.X-a.X*b.Z,Z=a.X*b.Y-a.Y*b.X} end
local function len(a) return math.sqrt(dot(a,a)) end
local function nrm(a) local l=len(a); return l>1e-9 and {X=a.X/l,Y=a.Y/l,Z=a.Z/l} or {X=1,Y=0,Z=0} end
local function qmul(a,b)
    return {a[4]*b[1]+a[1]*b[4]+a[2]*b[3]-a[3]*b[2], a[4]*b[2]-a[1]*b[3]+a[2]*b[4]+a[3]*b[1],
        a[4]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[4], a[4]*b[4]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]}
end
function A.rot2q(r) -- FRotator -> FQuat
    local DR=math.pi/360
    local sp,cp=math.sin(r.Pitch*DR),math.cos(r.Pitch*DR)
    local sy,cy=math.sin(r.Yaw*DR),math.cos(r.Yaw*DR)
    local sr,cr=math.sin(r.Roll*DR),math.cos(r.Roll*DR)
    return {cr*sp*sy-sr*cp*cy, -cr*sp*cy-sr*cp*sy, cr*cp*sy-sr*sp*cy, cr*cp*cy+sr*sp*sy}
end
function A.q2rot(q) -- FQuat::Rotator
    local X,Y,Z,W=q[1],q[2],q[3],q[4]
    local st=Z*X-W*Y
    local yaw=math.deg(math.atan(2*(W*Z+X*Y),1-2*(Y*Y+Z*Z)))
    local pitch,roll
    if st<-0.4999995 then pitch=-90; roll=-yaw-2*math.deg(math.atan(X,W))
    elseif st>0.4999995 then pitch=90; roll=yaw-2*math.deg(math.atan(X,W))
    else pitch=math.deg(math.asin(2*st)); roll=math.deg(math.atan(-2*(W*X+Y*Z),1-2*(X*X+Y*Y))) end
    return {Pitch=pitch,Yaw=yaw,Roll=roll}
end
function A.qrot(q,v) local p=qmul(qmul(q,{v.X,v.Y,v.Z,0}),{-q[1],-q[2],-q[3],q[4]}); return {X=p[1],Y=p[2],Z=p[3]} end

-- One step: cur is the rotator now written; bore and want are the rifle's bore and the wanted direction, both in
-- component space. Returns the next rotator: cur turned by gain (0..1) of the bore->want rotation, capped at max_deg
-- from the identity (so a bad frame can never fold her in half).
function A.step(cur,bore,want,gain,max_deg)
    local a,b=nrm(bore),nrm(want)
    local c=math.max(-1,math.min(1,dot(a,b)))
    local axis=cross(a,b)
    local q0=A.rot2q(cur)
    if len(axis)>1e-6 and c<0.9999999 then
        local ang=math.acos(c)*gain; local ax=nrm(axis); local s=math.sin(ang/2)
        q0=qmul({ax.X*s,ax.Y*s,ax.Z*s,math.cos(ang/2)},q0)
    end
    local n=math.sqrt(q0[1]^2+q0[2]^2+q0[3]^2+q0[4]^2); q0={q0[1]/n,q0[2]/n,q0[3]/n,q0[4]/n}
    if q0[4]<0 then q0={-q0[1],-q0[2],-q0[3],-q0[4]} end
    local total=math.deg(2*math.acos(math.min(1,q0[4])))
    if total>max_deg then -- scale back toward identity along the same axis
        local s=math.sin(math.rad(max_deg)/2)/math.sqrt(1-q0[4]^2)
        q0={q0[1]*s,q0[2]*s,q0[3]*s,math.cos(math.rad(max_deg)/2)}
    end
    return A.q2rot(q0)
end

-- Yaw-and-pitch-only step (no roll, so her chest never cants sideways): the rest bore is the bore undone by the current
-- rotation; the target rotation yaws it about the component's up axis (Z) onto the wanted azimuth, then pitches it about
-- the horizontal axis across it onto the wanted elevation; the result moves gain of the way there. Yaw and pitch are
-- capped separately (degrees).
local function slerp(a,b,t)
    local d=a[1]*b[1]+a[2]*b[2]+a[3]*b[3]+a[4]*b[4]
    if d<0 then b={-b[1],-b[2],-b[3],-b[4]}; d=-d end
    if d>0.9995 then
        local r={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t,a[4]+(b[4]-a[4])*t}
        local n=math.sqrt(r[1]^2+r[2]^2+r[3]^2+r[4]^2); return {r[1]/n,r[2]/n,r[3]/n,r[4]/n}
    end
    local th=math.acos(d); local s=math.sin(th); local wa,wb=math.sin((1-t)*th)/s,math.sin(t*th)/s
    return {a[1]*wa+b[1]*wb,a[2]*wa+b[2]*wb,a[3]*wa+b[3]*wb,a[4]*wa+b[4]*wb}
end
local function axis_q(ax,deg) local h=math.rad(deg)/2; local s=math.sin(h); return {ax.X*s,ax.Y*s,ax.Z*s,math.cos(h)} end
function A.step_yp(cur,bore,want,gain,max_pitch,max_yaw)
    local q=A.rot2q(cur)
    local rest=nrm(A.qrot({-q[1],-q[2],-q[3],q[4]},bore)); local w=nrm(want)
    local azr,elr=math.atan(rest.Y,rest.X),math.asin(math.max(-1,math.min(1,rest.Z)))
    local azw,elw=math.atan(w.Y,w.X),math.asin(math.max(-1,math.min(1,w.Z)))
    local yaw=math.deg(azw-azr); yaw=(yaw+180)%360-180
    local pit=math.deg(elw-elr)
    yaw=math.max(-max_yaw,math.min(max_yaw,yaw)); pit=math.max(-max_pitch,math.min(max_pitch,pit))
    local h={X=-math.sin(azr),Y=math.cos(azr),Z=0} -- up x rest azimuth: turning about it by -pitch raises the bore
    local qt=qmul(axis_q({X=0,Y=0,Z=1},yaw),axis_q(h,-pit))
    return A.q2rot(slerp(q,qt,gain))
end

-- Ease the rotator back toward zero (carry, air, off).
function A.decay(cur,k)
    return {Pitch=cur.Pitch*(1-k),Yaw=cur.Yaw*(1-k),Roll=cur.Roll*(1-k)}
end

-- Her body tilt in degrees: the line a->b (Bip001-Pelvis->Spine1, world) against world up. 0 upright, 180 upside down.
function A.tilt(a,b)
    local dx,dy,dz=b.X-a.X,b.Y-a.Y,b.Z-a.Z; local l=math.sqrt(dx*dx+dy*dy+dz*dz)
    if l<1e-6 then return 0 end
    return math.deg(math.acos(math.max(-1,math.min(1,dz/l))))
end

return A
