-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The layer's chest turn (AimRot, added to Bip001-Spine2 in component space since the v3c pak): a closed loop that turns
-- her chest, and with it the NIKKE clip's arms and the rifle in her hands, until the rifle's real bore points at the aim
-- point. Pure maths (vectors {X,Y,Z}, quaternions {x,y,z,w} in UE conventions) so lua5.4 tests it.
local A={}

local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b) return {X=a.Y*b.Z-a.Z*b.Y,Y=a.Z*b.X-a.X*b.Z,Z=a.X*b.Y-a.Y*b.X} end
local function len(a) return math.sqrt(dot(a,a)) end
local function nrm(a) local l=len(a); return l>1e-9 and {X=a.X/l,Y=a.Y/l,Z=a.Z/l} or {X=1,Y=0,Z=0} end
local function qmul(a,b)
    return {a[4]*b[1]+a[1]*b[4]+a[2]*b[3]-a[3]*b[2], a[4]*b[2]-a[1]*b[3]+a[2]*b[4]+a[3]*b[1],
        a[4]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[4], a[4]*b[4]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]}
end
-- (scalar forms, no table per call: step_yp runs every aiming frame; the same operations in the same order as the
-- table forms, so the results are the same to the bit)
local function qmul4(a1,a2,a3,a4,b1,b2,b3,b4)
    return a4*b1+a1*b4+a2*b3-a3*b2, a4*b2-a1*b3+a2*b4+a3*b1, a4*b3+a1*b2-a2*b1+a3*b4, a4*b4-a1*b1-a2*b2-a3*b3
end
local function qrot4(q1,q2,q3,q4,x,y,z) -- A.qrot on numbers
    local p1,p2,p3,p4=qmul4(q1,q2,q3,q4,x,y,z,0)
    local r1,r2,r3=qmul4(p1,p2,p3,p4,-q1,-q2,-q3,q4)
    return r1,r2,r3
end
local function nrm3(x,y,z) local l=math.sqrt(x*x+y*y+z*z); if l>1e-9 then return x/l,y/l,z/l end; return 1,0,0 end
local function rot2q4(r)
    local DR=math.pi/360
    local sp,cp=math.sin(r.Pitch*DR),math.cos(r.Pitch*DR)
    local sy,cy=math.sin(r.Yaw*DR),math.cos(r.Yaw*DR)
    local sr,cr=math.sin(r.Roll*DR),math.cos(r.Roll*DR)
    return cr*sp*sy-sr*cp*cy, -cr*sp*cy-sr*cp*sy, cr*cp*sy-sr*sp*cy, cr*cp*cy+sr*sp*sy
end
local function q2rot4(X,Y,Z,W,out) -- FQuat::Rotator, written into out
    local st=Z*X-W*Y
    local yaw=math.deg(math.atan(2*(W*Z+X*Y),1-2*(Y*Y+Z*Z)))
    local pitch,roll
    if st<-0.4999995 then pitch=-90; roll=-yaw-2*math.deg(math.atan(X,W))
    elseif st>0.4999995 then pitch=90; roll=yaw-2*math.deg(math.atan(X,W))
    else pitch=math.deg(math.asin(2*st)); roll=math.deg(math.atan(-2*(W*X+Y*Z),1-2*(X*X+Y*Y))) end
    out.Pitch,out.Yaw,out.Roll=pitch,yaw,roll
    return out
end
function A.rot2q(r) return {rot2q4(r)} end -- FRotator -> FQuat
function A.q2rot(q) return q2rot4(q[1],q[2],q[3],q[4],{}) end -- FQuat::Rotator
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

-- Yaw-and-pitch step: the rest bore is the bore undone by the current rotation; the target rotation yaws it about the
-- component's up axis (Z) onto the wanted azimuth, then pitches it about the horizontal axis across it onto the wanted
-- elevation; the result moves gain of the way there. Yaw and pitch are capped separately (degrees).
-- up (her chest's up now, component space) and max_roll (deg): the target is also rolled about the turned bore until
-- that up is level with world up across the bore, at most max_roll. The bore's direction does not change, so the aim
-- still converges. nil or 0: no roll (the chest keeps whatever cant the stance gives).
-- Returns the next rotator and the pitch the target needs before its cap (deg).
local function slerp4(a1,a2,a3,a4,b1,b2,b3,b4,t)
    local d=a1*b1+a2*b2+a3*b3+a4*b4
    if d<0 then b1,b2,b3,b4=-b1,-b2,-b3,-b4; d=-d end
    if d>0.9995 then
        local r1,r2,r3,r4=a1+(b1-a1)*t,a2+(b2-a2)*t,a3+(b3-a3)*t,a4+(b4-a4)*t
        local n=math.sqrt(r1^2+r2^2+r3^2+r4^2); return r1/n,r2/n,r3/n,r4/n
    end
    local th=math.acos(d); local s=math.sin(th); local wa,wb=math.sin((1-t)*th)/s,math.sin(t*th)/s
    return a1*wa+b1*wb,a2*wa+b2*wb,a3*wa+b3*wb,a4*wa+b4*wb
end
-- out (optional): the rotator written into it (it may be cur) instead of a new table.
function A.step_yp(cur,bore,want,gain,max_pitch,max_yaw,up,max_roll,out)
    local q1,q2,q3,q4=rot2q4(cur)
    local rx,ry,rz=nrm3(qrot4(-q1,-q2,-q3,q4,bore.X,bore.Y,bore.Z))
    local wx,wy,wz=nrm3(want.X,want.Y,want.Z)
    local azr,elr=math.atan(ry,rx),math.asin(math.max(-1,math.min(1,rz)))
    local azw,elw=math.atan(wy,wx),math.asin(math.max(-1,math.min(1,wz)))
    local yaw=math.deg(azw-azr); yaw=(yaw+180)%360-180
    local need=math.deg(elw-elr)
    yaw=math.max(-max_yaw,math.min(max_yaw,yaw)); local pit=math.max(-max_pitch,math.min(max_pitch,need))
    -- yaw about up (Z), then -pit about h = up x rest azimuth (turning about it by -pitch raises the bore)
    local hx,hy=-math.sin(azr),math.cos(azr)
    local ha=math.rad(yaw)/2; local sa=math.sin(ha)
    local hb=math.rad(-pit)/2; local sb=math.sin(hb)
    local t1,t2,t3,t4=qmul4(0*sa,0*sa,1*sa,math.cos(ha),hx*sb,hy*sb,0*sb,math.cos(hb))
    if up and max_roll and max_roll>0 then
        local bx,by,bz=qrot4(t1,t2,t3,t4,rx,ry,rz) -- the bore after the target turn
        local ux,uy,uz=qrot4(t1,t2,t3,t4,qrot4(-q1,-q2,-q3,q4,up.X,up.Y,up.Z)) -- her up after it
        -- her up and world up, each across the bore
        local k=ux*bx+uy*by+uz*bz; local ax,ay,az=ux-bx*k,uy-by*k,uz-bz*k
        k=0*bx+0*by+1*bz; local zx,zy,zz=0-bx*k,0-by*k,1-bz*k
        if math.sqrt(ax*ax+ay*ay+az*az)>1e-6 and math.sqrt(zx*zx+zy*zy+zz*zz)>1e-6 then
            local cx,cy,cz=ay*zz-az*zy,az*zx-ax*zz,ax*zy-ay*zx
            local roll=math.deg(math.atan(bx*cx+by*cy+bz*cz,ax*zx+ay*zy+az*zz)) -- signed, about the bore
            roll=math.max(-max_roll,math.min(max_roll,roll))
            local hr=math.rad(roll)/2; local sr=math.sin(hr)
            t1,t2,t3,t4=qmul4(bx*sr,by*sr,bz*sr,math.cos(hr),t1,t2,t3,t4)
        end
    end
    local o1,o2,o3,o4=slerp4(q1,q2,q3,q4,t1,t2,t3,t4,gain)
    return q2rot4(o1,o2,o3,o4,out or {}),need
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
