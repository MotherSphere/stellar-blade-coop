-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The v4 left-hand pin: the left hand lands at the right hand's transform composed with the clip's entry. The reload
-- (no entry) turns the IK off. The pin follows a turned right hand.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
function FName(s) return s end
local close=function(a,b) return math.abs(a-b)<=1e-4 end
local B={['Bip001-R-Hand']={{10,40,115},{0,0,0,1}},['Bip001-L-UpperArm']={{0,-11.5,140},{0,0,0,1}},
    ['Bip001-L-Forearm']={{5,-30,120},{0,0,0,1}},['Bip001-L-Hand']={{0,-30,96},{0,0,0,1}},['Bip001-R-Forearm']={{0,30,125},{0,0,0,1}},['Bip001-Spine2']={{0,0,0},{0,0,0,1}}}
local mesh={GetSocketTransform=function(_,b) local t=assert(B[b],'no bone '..b)
    return {Translation={X=t[1][1],Y=t[1][2],Z=t[1][3]},Rotation={X=t[2][1],Y=t[2][2],Z=t[2][3],W=t[2][4]}} end}
local p={Mesh=mesh}
local pp={IsValid=function() return true end}
local g={log=print,try=function(f) local ok,r=pcall(f); if ok then return r end end}
local IKm=require('fight.gunmode.ik')
IKm.CFG.pin_left={aim={t={X=-13,Y=-27,Z=6},q={0,0,0,1}}}
IKm.CFG.pin_space='component'; IKm.CFG.pin_wrist=false; IKm.CFG.pin_blend=1e-9 -- (no easing in cases 1-9) -- (cases 1-7 check component-space values; 8 checks the rest)
local IK=IKm.new(g)

-- 1. Identity right hand: the left hand at the offset.
IK.want='aim'; IK.tick(nil,p,nil,'aim',pp)
assert(pp.ArmsAlpha==1)
assert(close(pp.LHandLoc_RH.X,-3) and close(pp.LHandLoc_RH.Y,13) and close(pp.LHandLoc_RH.Z,121))
assert(close(pp.RHandLoc_S2.X,10) and close(pp.RHandLoc_S2.Y,40))

-- 2. Right hand turned 90 deg about Z: the offset turns with it (X -> Y, Y -> -X).
local s=math.sqrt(0.5); B['Bip001-R-Hand'][2]={0,0,s,s}
IK.tick(nil,p,nil,'aim',pp)
assert(close(pp.LHandLoc_RH.X,10+27) and close(pp.LHandLoc_RH.Y,40-13) and close(pp.LHandLoc_RH.Z,121))
assert(close(pp.LHandRot_RH.Yaw,90))

-- 3. A clip without an entry: the IK stands down.
IK.want='nikke'; IK.tick(nil,p,nil,'carry',pp)
assert(pp.ArmsAlpha==0)

-- 4. With an authored elbow the pole is pushed out from it, not from the current elbow.
B['Bip001-R-Hand'][2]={0,0,0,1}
IKm.CFG.pin_left.aim.e={X=-10,Y=-12,Z=25}
IK.want='aim'; IK.tick(nil,p,nil,'aim',pp)
local el={X=0,Y=28,Z=140} -- the authored elbow in component space
local mid={X=(0+(-3))/2,Y=(-11.5+13)/2,Z=(140+121)/2}
local ox,oy,oz=el.X-mid.X,el.Y-mid.Y,el.Z-mid.Z; local ol=math.sqrt(ox*ox+oy*oy+oz*oz)
local P=IKm.CFG.pin_pole
assert(close(pp.LElbowPole_S2.X,el.X+ox/ol*P) and close(pp.LElbowPole_S2.Y,el.Y+oy/ol*P) and close(pp.LElbowPole_S2.Z,el.Z+oz/ol*P))

-- 5. Rifle first: the right hand target composed with the clip's grip gives back the rifle placed off her neck.
local function qmul(a,b) return {a[4]*b[1]+a[1]*b[4]+a[2]*b[3]-a[3]*b[2], a[4]*b[2]-a[1]*b[3]+a[2]*b[4]+a[3]*b[1],
    a[4]*b[3]+a[1]*b[2]-a[2]*b[1]+a[3]*b[4], a[4]*b[4]-a[1]*b[1]-a[2]*b[2]-a[3]*b[3]} end
local function qrot(q,v) local p=qmul(qmul(q,{v.X,v.Y,v.Z,0}),{-q[1],-q[2],-q[3],q[4]}); return {X=p[1],Y=p[2],Z=p[3]} end
local function r2q(r) local DR=math.pi/360
    local sp,cp=math.sin(r.Pitch*DR),math.cos(r.Pitch*DR); local sy,cy=math.sin(r.Yaw*DR),math.cos(r.Yaw*DR)
    local sr,cr=math.sin(r.Roll*DR),math.cos(r.Roll*DR)
    return {cr*sp*sy-sr*cp*cy, -cr*sp*cy-sr*cp*sy, cr*cp*sy-sr*sp*cy, cr*cp*cy+sr*sp*sy} end
B['Bip001-Neck']={{0,0,146},{0,0,s,s}}; B['Bip001-Spine2']=B['Bip001-Neck']; B['Bip001-R-UpperArm']={{0,11.5,140},{0,0,0,1}}
IKm.CFG.pin_left.aim.r={t={X=2,Y=-6,Z=24},q={0.4028,0.8085,-0.3245,0.2807}}; IKm.CFG.pin_left.aim.re={X=22,Y=-17,Z=-12}
IKm.CFG.pin_nudge={aim={X=-3,Y=0,Z=-1}}
IK.tick(nil,p,nil,'aim',pp)
local G=require('fight.gunmode.rifle').GRIPS.aim
local nq={0,0,s,s}; local Rq=qmul(nq,IKm.CFG.pin_left.aim.r.q)
local t0=qrot(nq,IKm.CFG.pin_left.aim.r.t); local nd=qrot(Rq,{X=-3,Y=0,Z=-1})
local Rp={X=t0.X+nd.X,Y=t0.Y+nd.Y,Z=146+t0.Z+nd.Z}
local hq=r2q(pp.RHandRot_CS); local back=qrot(hq,G.Translation)
local c3=function(a,b) return math.abs(a-b)<1e-3 end -- (the rotator round trip and the anchor frame lose ~1e-4 cm)
assert(c3(pp.RHandLoc_S2.X+back.X,Rp.X) and c3(pp.RHandLoc_S2.Y+back.Y,Rp.Y) and c3(pp.RHandLoc_S2.Z+back.Z,Rp.Z))
local rq2=qmul(hq,{G.Rotation.X,G.Rotation.Y,G.Rotation.Z,G.Rotation.W})
local d=math.abs(rq2[1]*Rq[1]+rq2[2]*Rq[2]+rq2[3]*Rq[3]+rq2[4]*Rq[4]); assert(d>1-1e-4,'rifle rotation '..d) -- (the rotator round trip loses a little)

-- 6. Aim pitch: the rifle turns about its butt; the butt stays, the muzzle rises.
local function hand2rifle()
    local hq=r2q(pp.RHandRot_CS); local q=qmul(hq,{G.Rotation.X,G.Rotation.Y,G.Rotation.Z,G.Rotation.W})
    local t=qrot(hq,G.Translation); local o={X=pp.RHandLoc_S2.X+t.X,Y=pp.RHandLoc_S2.Y+t.Y,Z=pp.RHandLoc_S2.Z+t.Z}
    local function at(v) local r=qrot(q,v); return {X=o.X+r.X,Y=o.Y+r.Y,Z=o.Z+r.Z} end
    return at(IKm.CFG.pin_butt), at({X=-53.4,Y=0,Z=9.88})
end
IK.rpitch=0; IK.tick(nil,p,nil,'aim',pp); local b0,m0=hand2rifle()
IK.rpitch=30; IK.tick(nil,p,nil,'aim',pp); local b1,m1=hand2rifle()
local function dist(a,b) return math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2) end
assert(dist(b0,b1)<1e-2,'butt moved '..dist(b0,b1))
local function ang(a,b,c,d) local u={X=b.X-a.X,Y=b.Y-a.Y,Z=b.Z-a.Z}; local v={X=d.X-c.X,Y=d.Y-c.Y,Z=d.Z-c.Z}
    return math.deg(math.acos((u.X*v.X+u.Y*v.Y+u.Z*v.Z)/(dist(a,b)*dist(c,d)))) end
assert(math.abs(ang(b0,m0,b1,m1)-30)<0.05,'turn '..ang(b0,m0,b1,m1))
IK.rpitch=0

-- 7. Reload: at k 0.4 the left hand is on its way down from the magazine (below the handguard target), at 1 it is back.
IKm.CFG.pin_left.reload=IKm.CFG.pin_left.aim
require('fight.gunmode.rifle').GRIPS.reload=G
IK.want='reload'; IK.reload_k=0; IK.tick(nil,p,nil,'carry',pp); local l0={X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z}
IK.reload_k=0.5; IK.tick(nil,p,nil,'carry',pp); local lm=pp.LHandLoc_RH
assert(dist(l0,lm)>5,'hand did not leave the handguard '..dist(l0,lm))
IK.reload_k=1; IK.tick(nil,p,nil,'carry',pp)
assert(dist(l0,pp.LHandLoc_RH)<1e-3,'hand not back '..dist(l0,pp.LHandLoc_RH))
IK.reload_k=nil

-- 8. Bone space: the left target sent in the anchor's frame (anchor turned 90 deg about Z at 0,0,146).
IK.want='aim'; IK.tick(nil,p,nil,'aim',pp); local lc={X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z}
IKm.CFG.pin_space='bone'; IK.tick(nil,p,nil,'aim',pp); local lb=pp.LHandLoc_RH
-- inverse of a +90 deg turn about Z: (x,y) -> (y,-x)
assert(close(lb.X,lc.Y) and close(lb.Y,-lc.X) and close(lb.Z,lc.Z-146),'bone space')
IKm.CFG.pin_space='component'

-- 9. Wrist: with the IK elbow where the authored one is, the hand rotation does not change; elsewhere it turns.
IK.tick(nil,p,nil,'aim',pp); local r0=pp.LHandRot_RH
IKm.CFG.pin_wrist=true; IK.tick(nil,p,nil,'aim',pp); local r1=pp.LHandRot_RH
assert(math.abs(r1.Pitch-r0.Pitch)+math.abs(r1.Yaw-r0.Yaw)+math.abs(r1.Roll-r0.Roll)>0.1,'wrist did not turn')
IKm.CFG.pin_wrist=false

-- 10. Easing: when the placement changes (here the nudge, as a new clip would), the target moves only part of the way
-- at first; the body moving (the anchor) is followed at once, since the easing runs in the anchor's frame.
IKm.CFG.pin_blend=0.14
local function wait(t) local t0=os.clock(); while os.clock()-t0<t do end end
IK.tick(nil,p,nil,'aim',pp); local a={X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z}
IKm.CFG.pin_nudge.aim={X=-13,Y=0,Z=-1}
wait(0.01); IK.tick(nil,p,nil,'aim',pp); local b2={X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z}
IKm.CFG.pin_blend=1e-9; IK.tick(nil,p,nil,'aim',pp); local full={X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z}
assert(dist(a,b2)>1e-3 and dist(a,b2)<dist(a,full)*0.9,'easing '..dist(a,b2)..' of '..dist(a,full))
IKm.CFG.pin_nudge.aim={X=-3,Y=0,Z=-1}; IK.tick(nil,p,nil,'aim',pp)
IKm.CFG.pin_blend=1e-9
IK.tick(nil,p,nil,'aim',pp)
local c0={X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z}
IK.kick(); IK.tick(nil,p,nil,'aim',pp)
assert(dist(c0,pp.LHandLoc_RH)>0.5,'kick '..dist(c0,pp.LHandLoc_RH))

-- 11. Off stays off.
IK.want='aim'; IK.tick(nil,p,nil,'off',pp)
assert(pp.ArmsAlpha==0)

-- 12. Rifle first reads only the bones it uses: the anchor once and both upper arms (not the right hand and forearm
-- it replaces, nor the anchor a second time).
do
    local n,get=0,mesh.GetSocketTransform
    mesh.GetSocketTransform=function(m,b) n=n+1; return get(m,b) end
    IK.want='aim'; IK.tick(nil,p,nil,'aim',pp)
    mesh.GetSocketTransform=get
    assert(n==3,'bone reads '..n)
end
print('gunmode ik_pin_test ok')
