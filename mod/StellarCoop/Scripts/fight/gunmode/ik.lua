-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle-first solver. Each tick, in her body mesh's component space:
--   1. place the rifle: its grip a little in front of her right shoulder; in aim the bore points at the spot 20 m down
--      the camera line, in carry it hangs at low ready (pitched down, across her body)
--   2. right hand = rifle composed with the inverse of the attach GRIP (the attached rifle then lands exactly there)
--   3. left hand = the hand placement that puts her palm on the handguard point (its palm offset measured live)
--   4. elbow poles below and outside each shoulder
-- and writes the layer's variables in one batch (ArmsAlpha, RHandLoc_S2, RHandRot_CS, RElbowPole_S2, LHandLoc_RH,
-- LHandRot_RH, LElbowPole_S2). Whatever their suffixes say, every value here is in component space, which is how the
-- graph's nodes are set. Only property writes reach the post-process instance.
local IK={}

-- quaternions {x,y,z,w}, UE conventions
local function qmul(a,b) -- a after b
    return {a[4]*b[1]+a[1]*b[4]+a[2]*b[3]-a[3]*b[2], a[4]*b[2]-a[1]*b[3]+a[2]*b[4]+a[3]*b[1],
        a[4]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[4], a[4]*b[4]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]}
end
local function qinv(q) return {-q[1],-q[2],-q[3],q[4]} end
local function qrot(q,v) -- rotate vector {X,Y,Z}
    local p=qmul(qmul(q,{v.X,v.Y,v.Z,0}),qinv(q)); return {X=p[1],Y=p[2],Z=p[3]}
end
local function rot2q(r) -- FRotator -> FQuat (UE)
    local DR=math.pi/360
    local sp,cp=math.sin(r.Pitch*DR),math.cos(r.Pitch*DR)
    local sy,cy=math.sin(r.Yaw*DR),math.cos(r.Yaw*DR)
    local sr,cr=math.sin(r.Roll*DR),math.cos(r.Roll*DR)
    return {cr*sp*sy-sr*cp*cy, -cr*sp*cy-sr*cp*sy, cr*cp*sy-sr*sp*cy, cr*cp*cy+sr*sp*sy}
end
local function q2rot(q) -- FQuat::Rotator
    local X,Y,Z,W=q[1],q[2],q[3],q[4]
    local st=Z*X-W*Y
    local yaw=math.deg(math.atan(2*(W*Z+X*Y),1-2*(Y*Y+Z*Z)))
    local pitch,roll
    if st<-0.4999995 then pitch=-90; roll=-yaw-2*math.deg(math.atan(X,W))
    elseif st>0.4999995 then pitch=90; roll=yaw-2*math.deg(math.atan(X,W))
    else pitch=math.deg(math.asin(2*st)); roll=math.deg(math.atan(-2*(W*X+Y*Z),1-2*(X*X+Y*Y))) end
    return {Pitch=pitch,Yaw=yaw,Roll=roll}
end
local function add(a,b) return {X=a.X+b.X,Y=a.Y+b.Y,Z=a.Z+b.Z} end
local function sub(a,b) return {X=a.X-b.X,Y=a.Y-b.Y,Z=a.Z-b.Z} end
local function mul(a,s) return {X=a.X*s,Y=a.Y*s,Z=a.Z*s} end
local function dot(a,b) return a.X*b.X+a.Y*b.Y+a.Z*b.Z end
local function cross(a,b) return {X=a.Y*b.Z-a.Z*b.Y,Y=a.Z*b.X-a.X*b.Z,Z=a.X*b.Y-a.Y*b.X} end
local function len(a) return math.sqrt(dot(a,a)) end
local function nrm(a) local l=len(a); return l>1e-6 and mul(a,1/l) or {X=1,Y=0,Z=0} end
-- the rotation taking orthonormal frame (x1,z1) onto (x2,z2), as a quaternion
local function frame_q(x,z) -- quaternion of the basis (x, y=z cross x, z)
    local y=cross(z,x)
    local m00,m01,m02=x.X,y.X,z.X
    local m10,m11,m12=x.Y,y.Y,z.Y
    local m20,m21,m22=x.Z,y.Z,z.Z
    local tr=m00+m11+m22
    local q
    if tr>0 then local s=math.sqrt(tr+1)*2; q={(m21-m12)/s,(m02-m20)/s,(m10-m01)/s,0.25*s}
    elseif m00>m11 and m00>m22 then local s=math.sqrt(1+m00-m11-m22)*2; q={0.25*s,(m01+m10)/s,(m02+m20)/s,(m21-m12)/s}
    elseif m11>m22 then local s=math.sqrt(1+m11-m00-m22)*2; q={(m01+m10)/s,0.25*s,(m12+m21)/s,(m02-m20)/s}
    else local s=math.sqrt(1+m22-m00-m11)*2; q={(m02+m20)/s,(m12+m21)/s,0.25*s,(m10-m01)/s} end
    return q
end
local function ortho(x,z) x=nrm(x); z=nrm(sub(z,mul(x,dot(z,x)))); return x,z end
-- The math above, for tests/lua/fight/gunmode/helpers_test.lua.
IK.math={qmul=qmul,qinv=qinv,qrot=qrot,rot2q=rot2q,q2rot=q2rot,frame_q=frame_q,ortho=ortho}

-- tuning (cm / degrees); starting values from the plan, refined in game
IK.CFG={
    grip_aim={fwd=24,right=2,up=-10},     -- rifle grip point from her right shoulder joint, aim
    grip_carry={fwd=18,right=-10,up=-18}, -- carry (low ready)
    carry_pitch=-35, carry_yaw=35, carry_cant=12, aim_cant=3,
    pole_r={right=22,fwd=-5,up=-35}, pole_l={right=-8,fwd=15,up=-40},
    aim_dist=2000,
    handguard_frac=0.62,                  -- the handguard as a fraction of the grip->muzzle distance, until measured
}

function IK.new(g)
    local self={}
    local st={}
    local function valid(o) return o~=nil and g.try(function() return o:IsValid() end)==true end
    local function cs(mesh,bone) -- component-space bone transform: location, quaternion
        local t=mesh:GetSocketTransform(FName(bone),2) -- RTS_Component
        return {X=t.Translation.X,Y=t.Translation.Y,Z=t.Translation.Z},{t.Rotation.X,t.Rotation.Y,t.Rotation.Z,t.Rotation.W}
    end

    -- rifle-space geometry, measured once from the attached rifle: bore axis, up, muzzle, handguard point
    local function measure(rifle,Rifle)
        local ml=g.find('/Script/Engine.Default__KismetMathLibrary')
        local T=rifle:K2_GetComponentToWorld()
        local mz=ml:InverseTransformLocation(T,rifle:GetSocketLocation(FName('FX_Fire')))
        local fwdW=ml:GetForwardVector(rifle:GetSocketRotation(FName('FX_Fire')))
        local bore=nrm(ml:InverseTransformDirection(T,fwdW))
        local up=ml:InverseTransformDirection(T,ml:GetUpVector(rifle:K2_GetComponentRotation()))
        st.geo={muzzle=mz,bore=bore,up=nrm(up)}
        g.log(('ik: rifle muzzle (rifle space) %.1f %.1f %.1f, bore %.2f %.2f %.2f'):format(mz.X,mz.Y,mz.Z,bore.X,bore.Y,bore.Z))
        local G=Rifle.GRIP
        st.gq={G.Rotation.X,G.Rotation.Y,G.Rotation.Z,G.Rotation.W}
        st.gt={X=G.Translation.X,Y=G.Translation.Y,Z=G.Translation.Z}
    end

    -- mode: 'aim' | 'carry' | 'off'; returns a table of numbers for the log
    function self.tick(pc,p,rifle,mode,pp)
        local mesh=p.Mesh
        if not valid(pp) then return end
        if mode=='off' then
            if st.alpha~=0 then pcall(function() pp.ArmsAlpha=0 end); st.alpha=0 end
            return
        end
        if not st.geo then measure(rifle,require('fight.gunmode.rifle')) end
        local ml=g.find('/Script/Engine.Default__KismetMathLibrary')
        local CT=mesh:K2_GetComponentToWorld()
        -- her axes in component space
        local fwd=nrm(ml:InverseTransformDirection(CT,p:GetActorForwardVector()))
        local right=nrm(ml:InverseTransformDirection(CT,p:GetActorRightVector()))
        local up=nrm(cross(fwd,right)); up= (up.Z<0) and mul(up,-1) or up
        local rsh=cs(mesh,'Bip001-R-UpperArm'); local lsh=cs(mesh,'Bip001-L-UpperArm')
        local C=IK.CFG
        local o=(mode=='aim') and C.grip_aim or C.grip_carry
        local gripP=add(add(add(rsh,mul(fwd,o.fwd)),mul(right,o.right)),mul(up,o.up))
        -- bore direction
        local d
        if mode=='aim' then
            local cm=pc.PlayerCameraManager
            local cl=cm:GetCameraLocation()
            local cf=ml:GetForwardVector(cm:GetCameraRotation())
            local aimW={X=cl.X+cf.X*C.aim_dist,Y=cl.Y+cf.Y*C.aim_dist,Z=cl.Z+cf.Z*C.aim_dist}
            local aimC=ml:InverseTransformLocation(CT,aimW)
            d=nrm(sub(aimC,gripP))
        else
            -- low ready: forward, pitched down, turned across her body
            local yaw,pit=math.rad(C.carry_yaw),math.rad(C.carry_pitch)
            local h=add(mul(fwd,math.cos(yaw)),mul(right,-math.sin(yaw)))
            d=nrm(add(mul(h,math.cos(pit)),mul(up,math.sin(pit))))
        end
        -- rifle rotation: its bore onto d, its up as close to her up as possible (plus cant)
        local G=st.geo
        local bx,bz=ortho(G.bore,G.up)
        local tx,tz=ortho(d,up)
        local cant=math.rad((mode=='aim') and C.aim_cant or C.carry_cant)
        local ty=cross(tz,tx); tz=nrm(add(mul(tz,math.cos(cant)),mul(ty,math.sin(cant))))
        local Rr=qmul(frame_q(tx,tz),qinv(frame_q(bx,bz)))
        -- the rifle's origin so that its grip (origin) sits at gripP
        local rifleLoc=gripP
        -- right hand = rifle composed with inverse GRIP:  rifle = hand * GRIP  ->  hand.rot = Rr * gq^-1, hand.loc = rifleLoc - hand.rot*gt
        local hq=qmul(Rr,qinv(st.gq))
        local hloc=sub(rifleLoc,qrot(hq,st.gt))
        -- handguard point (rifle space) along the grip->muzzle line
        local hgR=mul(G.muzzle,C.handguard_frac)
        local hg=add(rifleLoc,qrot(Rr,hgR))
        -- left hand: rotation = right hand's (until the style pose); palm offset measured live in hand space
        local lq=hq
        local lh,lhq=cs(mesh,'Bip001-L-Hand'); local lf=cs(mesh,'Bip001-L-Finger2')
        local palmLocal=qrot(qinv(lhq),mul(sub(lf,lh),0.5))
        st.palm=st.palm or palmLocal -- frozen on first use
        local lloc=sub(hg,qrot(lq,st.palm))
        -- poles
        local pr,pl=C.pole_r,C.pole_l
        local poleR=add(add(add(rsh,mul(right,pr.right)),mul(fwd,pr.fwd)),mul(up,pr.up))
        local poleL=add(add(add(lsh,mul(right,pl.right)),mul(fwd,pl.fwd)),mul(up,pl.up))
        -- one batch of writes
        local ok,e=pcall(function()
            pp.RHandLoc_S2=hloc
            pp.RHandRot_CS=q2rot(hq)
            pp.RElbowPole_S2=poleR
            pp.LHandLoc_RH=lloc
            pp.LHandRot_RH=q2rot(lq)
            pp.LElbowPole_S2=poleL
            pp.ArmsAlpha=1
        end)
        st.alpha=1
        if not ok and not st.err then st.err=true; g.log('ik write: '..tostring(e)) end
        st.last={hloc=hloc,lloc=lloc,hg=hg}
        return st.last
    end
    return self
end

return IK
