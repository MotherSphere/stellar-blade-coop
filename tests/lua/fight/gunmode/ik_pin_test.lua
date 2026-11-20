-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The v4 left-hand pin: the left hand lands at the right hand's transform composed with the clip's entry, the reload
-- (no entry) turns the IK off, and the pin follows a turned right hand.
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
local REAL={pin=IKm.CFG.pin_left,nudge=IKm.CFG.pin_nudge,lnudge=IKm.CFG.pin_lnudge} -- (the shipped entries, for case 19)
IKm.CFG.pin_left={aim={t={X=-13,Y=-27,Z=6},q={0,0,0,1}}}
IKm.CFG.pin_space='component'; IKm.CFG.pin_wrist=false; IKm.CFG.pin_reach=false; IKm.CFG.pin_blend=1e-9 -- (no easing in cases 1-9) -- (cases 1-7 check component-space values; 8 checks the rest)
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

-- 13. The run carry: the run weight by speed; at a run the carried rifle moves (toward aim, muzzle down), in aim speed changes
-- nothing. The clock is stubbed: 1 s of ticks at 60 Hz.
do
    assert(close(IKm.run_target(150,150,300),0) and close(IKm.run_target(300,150,300),1) and close(IKm.run_target(225,150,300),0.5))
    assert(close(IKm.run_target(nil,150,300),0) and close(IKm.run_target(900,150,300),1))
    local A=IKm.CFG.pin_left.aim
    IKm.CFG.pin_left.carry={t=A.t,q=A.q,e=A.e,r=A.r,re=A.re}
    IKm.CFG.pin_nudge.carry={X=0,Y=0,Z=0}
    local clock,t=os.clock,0
    os.clock=function() return t end
    local function run(want,speed)
        local K=IKm.new(g); K.want=want; K.speed=speed; K.rpitch=0
        for _=1,60 do t=t+1/60; K.tick(nil,p,nil,want,pp) end
        local h=pp.RHandLoc_S2; return {X=h.X,Y=h.Y,Z=h.Z}
    end
    local c0,c4=run('carry',0),run('carry',400)
    local Kw=IKm.new(g); Kw.want='carry'; Kw.speed=400; Kw.rpitch=0
    for _=1,60 do t=t+1/60; Kw.tick(nil,p,nil,'carry',pp) end
    assert(Kw.runw and Kw.runw>0.95,'run weight kept for the trace log: '..tostring(Kw.runw))
    assert(dist(c0,c4)>1,'run carry moved '..dist(c0,c4))
    local a0,a4=run('aim',0),run('aim',400)
    assert(dist(a0,a4)<1e-6,'aim moved with speed '..dist(a0,a4))
    -- at a run the right hand lags a 5 cm bob of her chest (the anchor), at most sway_max
    local K=IKm.new(g); K.want='carry'; K.speed=400
    for _=1,60 do t=t+1/60; K.tick(nil,p,nil,'carry',pp) end
    local function rel() local h,a=pp.RHandLoc_S2,B['Bip001-Spine2'][1]; return {X=h.X-a[1],Y=h.Y-a[2],Z=h.Z-a[3]} end
    local r0,old=rel(),B['Bip001-Spine2']
    B['Bip001-Spine2']={{old[1][1],old[1][2],old[1][3]+5},old[2]}
    t=t+1/60; K.tick(nil,p,nil,'carry',pp)
    local lag=dist(r0,rel()); B['Bip001-Spine2']=old
    assert(lag>0.5 and lag<=IKm.CFG.sway_max+1e-6,'sway lag '..lag)
    os.clock=clock
end

-- 14. The sway spring: a step settles within 1% in 2 s at dt 0.05 and stays bounded on the way.
do
    local sp={x=0,y=0,z=0,vx=0,vy=0,vz=0}; local to={X=1,Y=-2,Z=0}; local peak=0
    for _=1,40 do IKm.spring(sp,to,0.05,2.2,0.45); peak=math.max(peak,math.abs(sp.x),math.abs(sp.y)) end
    assert(math.abs(sp.x-1)<0.01 and math.abs(sp.y+2)<0.02 and math.abs(sp.z)<1e-12,'spring '..sp.x..' '..sp.y)
    assert(peak<4,'spring overshoot '..peak)
    local s2={x=0,y=0,z=0,vx=0,vy=0,vz=0}; IKm.spring(s2,to,10,2.2,0.45) -- a long frame is clamped to 0.05
    local s3={x=0,y=0,z=0,vx=0,vy=0,vz=0}; IKm.spring(s3,to,0.05,2.2,0.45)
    assert(close(s2.x,s3.x) and close(s2.y,s3.y))
end
-- 15. The left hand's rifle-space nudge: the left target moves by the nudge turned by the rifle's rotation; the right
-- hand stays.
do
    IKm.CFG.pin_wrist=false; IKm.CFG.pin_blend=1e-9; IKm.CFG.pin_space='component'
    local saved=IKm.CFG.pin_lnudge
    local function left(nudge)
        IKm.CFG.pin_lnudge=nudge
        local K=IKm.new(g); K.want='aim'; K.rpitch=0; K.tick(nil,p,nil,'aim',pp)
        return {X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z},{X=pp.RHandLoc_S2.X,Y=pp.RHandLoc_S2.Y,Z=pp.RHandLoc_S2.Z}
    end
    local l0,r0=left(nil)
    local l1,r1=left({aim={X=0,Y=0,Z=4}})
    local nq=B['Bip001-Spine2'][2]; local Rq=qmul(nq,IKm.CFG.pin_left.aim.r.q); local d=qrot(Rq,{X=0,Y=0,Z=4})
    local c3=function(a,b) return math.abs(a-b)<1e-3 end
    assert(c3(l1.X-l0.X,d.X) and c3(l1.Y-l0.Y,d.Y) and c3(l1.Z-l0.Z,d.Z),'left nudge '..(l1.X-l0.X)..' '..(l1.Y-l0.Y)..' '..(l1.Z-l0.Z))
    assert(dist(r0,r1)<1e-6,'right hand moved')
    IKm.CFG.pin_lnudge=saved
    assert(IKm.CFG.pin_lnudge.reload==IKm.CFG.pin_lnudge.carry)
end
-- 16. No garbage from the run: a frame of running carry (the blend toward aim, run_down and the sway spring on) makes no more than a frame of
-- standing carry (within 64 bytes), with the clock stubbed and the GC stopped.
do
    local A=IKm.CFG.pin_left.aim
    IKm.CFG.pin_left.carry={t=A.t,q=A.q,e=A.e,r=A.r,re=A.re}
    local clock,t=os.clock,0
    os.clock=function() return t end
    local function per_frame(speed)
        local K=IKm.new(g); K.want='carry'; K.speed=speed; K.rpitch=0
        for _=1,60 do t=t+1/60; K.tick(nil,p,nil,'carry',pp) end
        collectgarbage('collect'); collectgarbage('stop')
        local k0=collectgarbage('count')
        for _=1,100 do t=t+1/60; K.tick(nil,p,nil,'carry',pp) end
        local b=(collectgarbage('count')-k0)*1024/100
        collectgarbage('restart')
        return b,K.runw
    end
    local stand=per_frame(0)
    local run,w=per_frame(400)
    assert(w>0.95,'run weight '..tostring(w))
    assert(run<=stand+64,('a running frame makes %.0f bytes, a standing one %.0f'):format(run,stand))
    os.clock=clock
end
-- 17. The left arm at a run: the left target is held within pin_reach of her arm's length from the shoulder; the left
-- elbow pole stays fixed on the rifle while her shoulder moves; the sway spring moves the hands, not the poles.
do
    local A=IKm.CFG.pin_left.aim
    IKm.CFG.pin_left.carry={t=A.t,q=A.q,e=A.e,r=A.r,re=A.re}
    IKm.CFG.pin_blend=1e-9; IKm.CFG.pin_wrist=false; IKm.CFG.pin_space='component'
    local clock,t=os.clock,0
    os.clock=function() return t end
    -- (a) a left target far out (the rifle-space nudge 60 cm up): put back to 0.92 of the arm's length
    IKm.CFG.pin_reach=0.92
    local saved=IKm.CFG.pin_lnudge
    IKm.CFG.pin_lnudge={aim={X=0,Y=0,Z=60}}
    local K=IKm.new(g); K.want='aim'; K.rpitch=0; t=t+1/60; K.tick(nil,p,nil,'aim',pp)
    local function v(b) local x=B[b][1]; return {X=x[1],Y=x[2],Z=x[3]} end
    local arm=dist(v('Bip001-L-UpperArm'),v('Bip001-L-Forearm'))+dist(v('Bip001-L-Forearm'),v('Bip001-L-Hand'))
    local reach=dist(pp.LHandLoc_RH,v('Bip001-L-UpperArm'))
    assert(math.abs(reach-0.92*arm)<1e-6,('left target %.2f cm from the shoulder, arm %.2f'):format(reach,arm))
    IKm.CFG.pin_lnudge=saved
    -- (b) running: the shoulder moves 5 cm, the left pole does not
    local function copy(x) return {X=x.X,Y=x.Y,Z=x.Z} end
    K=IKm.new(g); K.want='carry'; K.speed=400; K.rpitch=0
    for _=1,300 do t=t+1/60; K.tick(nil,p,nil,'carry',pp) end -- (5 s: the run weight settled, the rifle still)
    local pole0=copy(pp.LElbowPole_S2)
    local sh=B['Bip001-L-UpperArm']; B['Bip001-L-UpperArm']={{sh[1][1],sh[1][2],sh[1][3]+5},sh[2]}
    t=t+1/60; K.tick(nil,p,nil,'carry',pp)
    B['Bip001-L-UpperArm']=sh
    assert(dist(pole0,pp.LElbowPole_S2)<1e-6,'left pole moved with her shoulder at a run '..dist(pole0,pp.LElbowPole_S2))
    -- (c) running in bone space: a 5 cm bob of her chest (the anchor and both shoulders) makes the hands lag; the poles
    -- (anchor space) stay
    IKm.CFG.pin_space='bone'
    K=IKm.new(g); K.want='carry'; K.speed=400; K.rpitch=0
    for _=1,300 do t=t+1/60; K.tick(nil,p,nil,'carry',pp) end
    local l0,rp0,lp0=copy(pp.LHandLoc_RH),copy(pp.RElbowPole_S2),copy(pp.LElbowPole_S2)
    local an,ls,rs=B['Bip001-Spine2'],B['Bip001-L-UpperArm'],B['Bip001-R-UpperArm']
    local function up5(b) return {{b[1][1],b[1][2],b[1][3]+5},b[2]} end
    B['Bip001-Spine2'],B['Bip001-L-UpperArm'],B['Bip001-R-UpperArm']=up5(an),up5(ls),up5(rs)
    t=t+1/60; K.tick(nil,p,nil,'carry',pp)
    B['Bip001-L-UpperArm'],B['Bip001-R-UpperArm']=ls,rs
    assert(dist(l0,pp.LHandLoc_RH)>0.2,'the left hand did not lag the bob '..dist(l0,pp.LHandLoc_RH))
    assert(dist(rp0,pp.RElbowPole_S2)<1e-6 and dist(lp0,pp.LElbowPole_S2)<1e-6,'a pole swayed: '..
        dist(rp0,pp.RElbowPole_S2)..' '..dist(lp0,pp.LElbowPole_S2))
    B['Bip001-Spine2']=an
    IKm.CFG.pin_space='component'; IKm.CFG.pin_reach=false
    os.clock=clock
end
-- 18. Hip fire's recoil: a kick with scale 0.4 moves the left hand about 0.4 of a full kick's move.
do
    IKm.CFG.pin_blend=1e-9; IKm.CFG.pin_space='component'
    local function moved(scale)
        local K=IKm.new(g); K.want='aim'; K.rpitch=0
        K.tick(nil,p,nil,'aim',pp); local c0={X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z}
        K.kick(scale); K.tick(nil,p,nil,'aim',pp)
        return dist(c0,pp.LHandLoc_RH)
    end
    local full,hip=moved(nil),moved(0.4)
    assert(full>0.5 and math.abs(hip/full-0.4)<0.05,('hip kick %.3f of a full one'):format(hip/full))
    -- a hip kick right after a full one adds to it: the rifle never drops back (the scale is not applied to the rest)
    local K=IKm.new(g); K.want='aim'; K.rpitch=0
    K.tick(nil,p,nil,'aim',pp); local c0={X=pp.LHandLoc_RH.X,Y=pp.LHandLoc_RH.Y,Z=pp.LHandLoc_RH.Z}
    K.kick(1); K.tick(nil,p,nil,'aim',pp); local d1=dist(c0,pp.LHandLoc_RH)
    K.kick(0.4); K.tick(nil,p,nil,'aim',pp); local d2=dist(c0,pp.LHandLoc_RH)
    assert(d2>=d1*0.9,('the kick dropped from %.3f to %.3f'):format(d1,d2))
end
-- 19. The run carry's chest ready (the shipped entries): standing, the pin is today's carry; at a crawl it has not moved;
-- at a full run the rifle points along the aim entry's bore turned muzzle-down by run_down through the butt, and the left
-- hand sits on the rifle where the aim entry has it.
do
    IKm.CFG.pin_left,IKm.CFG.pin_nudge,IKm.CFG.pin_lnudge=REAL.pin,REAL.nudge,REAL.lnudge
    IKm.CFG.pin_blend=1e-9; IKm.CFG.pin_wrist=false; IKm.CFG.pin_space='component'; IKm.CFG.pin_reach=false
    local clock,t=os.clock,0
    os.clock=function() return t end
    local function out(speed,frames)
        local K=IKm.new(g); K.want='carry'; K.speed=speed; K.rpitch=0
        for _=1,frames do t=t+1/60; K.tick(nil,p,nil,'carry',pp) end
        local c=function(v) return {X=v.X,Y=v.Y,Z=v.Z} end
        return {r=c(pp.RHandLoc_S2),l=c(pp.LHandLoc_RH),rr=c(pp.RHandRot_CS and {X=pp.RHandRot_CS.Pitch,Y=pp.RHandRot_CS.Yaw,Z=pp.RHandRot_CS.Roll}),
            lp=c(pp.LElbowPole_S2),rp=c(pp.RElbowPole_S2)},K.runw
    end
    -- standing: the run branch never runs (no aim entry at all gives the same numbers)
    local s0,w0=out(0,30); assert(w0==0)
    local aim=IKm.CFG.pin_left.aim; IKm.CFG.pin_left.aim=nil
    local s1=out(0,30); IKm.CFG.pin_left.aim=aim
    for _,k in ipairs({'r','l','rr','lp','rp'}) do assert(dist(s0[k],s1[k])<1e-9,'standing carry changed: '..k) end
    -- a crawl (W about 1e-5): the blend starts where the carry is (the left hand's trip through the rifle frame included)
    local s2,w2=out(150.002,300); assert(w2>0 and w2<1e-4,'crawl weight '..w2)
    for _,k in ipairs({'r','l','lp','rp'}) do assert(dist(s0[k],s2[k])<1e-2,'a crawl moved '..k..' '..dist(s0[k],s2[k])) end
    -- a full run: the rifle's direction and the left hand in the rifle's frame
    local _,w1=out(400,600); assert(w1>1-1e-6,'run weight '..w1)
    local Gc,Ga=require('fight.gunmode.rifle').GRIPS.carry,require('fight.gunmode.rifle').GRIPS.aim
    local function gq(G) return {G.Rotation.X,G.Rotation.Y,G.Rotation.Z,G.Rotation.W} end
    local hq=r2q(pp.RHandRot_CS); local Rq=qmul(hq,gq(Gc))
    local nq=B['Bip001-Spine2'][2]; local h=math.rad(-IKm.CFG.run_down)/2
    local Ex=qmul(qmul(nq,aim.r.q),{0,math.sin(h),0,math.cos(h)})
    local d,e=qrot(Rq,{X=-1,Y=0,Z=0}),qrot(Ex,{X=-1,Y=0,Z=0})
    assert(dist(d,e)<1e-3,('rifle direction %.4f %.4f %.4f, wanted %.4f %.4f %.4f'):format(d.X,d.Y,d.Z,e.X,e.Y,e.Z))
    local a0=qrot(qmul(nq,aim.r.q),{X=-1,Y=0,Z=0}); local ang=math.deg(math.acos(math.min(1,a0.X*d.X+a0.Y*d.Y+a0.Z*d.Z)))
    assert(math.abs(ang-IKm.CFG.run_down)<0.1,'turned '..ang..' deg off the aim bore')
    local Rp=qrot(hq,Gc.Translation); Rp={X=pp.RHandLoc_S2.X+Rp.X,Y=pp.RHandLoc_S2.Y+Rp.Y,Z=pp.RHandLoc_S2.Z+Rp.Z}
    local Ri={-Rq[1],-Rq[2],-Rq[3],Rq[4]}
    local L=qrot(Ri,{X=pp.LHandLoc_RH.X-Rp.X,Y=pp.LHandLoc_RH.Y-Rp.Y,Z=pp.LHandLoc_RH.Z-Rp.Z})
    local gi=gq(Ga); gi={-gi[1],-gi[2],-gi[3],gi[4]}; local T=Ga.Translation
    local W=qrot(gi,{X=aim.t.X-T.X,Y=aim.t.Y-T.Y,Z=aim.t.Z-T.Z}); local n=IKm.CFG.pin_lnudge.aim
    W={X=W.X+n.X,Y=W.Y+n.Y,Z=W.Z+n.Z}
    assert(dist(L,W)<1e-2,('left hand on the rifle %.2f %.2f %.2f, the aim entry %.2f %.2f %.2f'):format(L.X,L.Y,L.Z,W.X,W.Y,W.Z))
    os.clock=clock
end
print('gunmode ik_pin_test ok')
