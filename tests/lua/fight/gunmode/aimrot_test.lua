-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The chest-turn loop: rotator<->quaternion round trip, a full step turns the bore onto the target, repeated half steps
-- converge, the cap holds, decay goes to zero.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local A=require('fight.gunmode.aimrot')
local close=function(a,b,e) return math.abs(a-b)<=(e or 1e-6) end

-- 1. Round trip.
for _,r in ipairs({{Pitch=10,Yaw=20,Roll=0},{Pitch=-35,Yaw=-70,Roll=0},{Pitch=0,Yaw=0,Roll=0}}) do
    local b=A.q2rot(A.rot2q(r)); assert(close(b.Pitch,r.Pitch,1e-6) and close(b.Yaw,r.Yaw,1e-6) and close(b.Roll,r.Roll,1e-6))
end

-- 2. A full step (gain 1) from zero turns the bore exactly onto the wanted direction.
local bore={X=1,Y=0,Z=0}; local want={X=0.8,Y=0.5,Z=0.3}
local r=A.step({Pitch=0,Yaw=0,Roll=0},bore,want,1,90)
local t=A.qrot(A.rot2q(r),bore); local l=math.sqrt(0.8^2+0.5^2+0.3^2)
assert(close(t.X,0.8/l,1e-6) and close(t.Y,0.5/l,1e-6) and close(t.Z,0.3/l,1e-6))

-- 3. The closed loop: the bore follows the rotator; half steps converge within 0.1 deg in 20 ticks.
r={Pitch=0,Yaw=0,Roll=0}
for _=1,20 do r=A.step(r,A.qrot(A.rot2q(r),bore),want,0.5,90) end
t=A.qrot(A.rot2q(r),bore)
assert(math.deg(math.acos(math.min(1,(t.X*0.8+t.Y*0.5+t.Z*0.3)/l)))<0.1)

-- 4. The cap: a target 170 deg away never turns her more than 60 deg.
r=A.step({Pitch=0,Yaw=0,Roll=0},bore,{X=-1,Y=0.1,Z=0},1,60)
local q=A.rot2q(r); assert(math.deg(2*math.acos(math.min(1,math.abs(q[4]))))<=60+1e-6)

-- 5. Decay.
r={Pitch=20,Yaw=-40,Roll=0}; for _=1,200 do r=A.decay(r,0.1) end
assert(math.abs(r.Pitch)<1e-6 and math.abs(r.Yaw)<1e-6)

-- 6. Yaw-and-pitch step: the closed loop converges onto a target up-left, with the bore never rolled. Start from a
-- rest bore pitched 15 deg up (the clip holds the rifle a little high).
local rest={X=math.cos(math.rad(15)),Y=0,Z=math.sin(math.rad(15))}
local tg={X=0.7,Y=0.6,Z=0.39}; local tl=math.sqrt(0.7^2+0.6^2+0.39^2)
r={Pitch=0,Yaw=0,Roll=0}
for _=1,30 do r=A.step_yp(r,A.qrot(A.rot2q(r),rest),tg,0.4,60,80) end
t=A.qrot(A.rot2q(r),rest)
assert(math.deg(math.acos(math.min(1,(t.X*tg.X+t.Y*tg.Y+t.Z*tg.Z)/tl)))<0.2)
-- no roll: a vector across the rest bore, horizontal at rest, stays horizontal
local side=A.qrot(A.rot2q(r),{X=0,Y=1,Z=0}); assert(math.abs(side.Z)<1e-6)
-- caps: a target straight up only pitches as far as the cap allows
r={Pitch=0,Yaw=0,Roll=0}; for _=1,40 do r=A.step_yp(r,A.qrot(A.rot2q(r),{X=1,Y=0,Z=0}),{X=0.01,Y=0,Z=1},0.5,30,80) end
t=A.qrot(A.rot2q(r),{X=1,Y=0,Z=0}); assert(math.abs(math.deg(math.asin(t.Z))-30)<0.5)

-- 7. Roll about the bore: her chest's up starts tilted 10 deg sideways; after 30 steps it is level with world up across
-- the bore (within 0.5 deg) and the bore is still on the target (under 0.2 deg). max_roll 0 leaves the tilt alone.
do
    local t10=math.rad(10)
    local up0={X=0,Y=-math.sin(t10),Z=math.cos(t10)}
    local function tilt_about_bore(r)
        local q=A.rot2q(r); local b=A.qrot(q,rest); local u=A.qrot(q,up0)
        local function across(v) local k=v.X*b.X+v.Y*b.Y+v.Z*b.Z; return {X=v.X-b.X*k,Y=v.Y-b.Y*k,Z=v.Z-b.Z*k} end
        local ua,za=across(u),across({X=0,Y=0,Z=1})
        local c=(ua.X*za.X+ua.Y*za.Y+ua.Z*za.Z)/math.sqrt((ua.X^2+ua.Y^2+ua.Z^2)*(za.X^2+za.Y^2+za.Z^2))
        return math.deg(math.acos(math.max(-1,math.min(1,c)))),b
    end
    local function run(max_roll)
        local r={Pitch=0,Yaw=0,Roll=0}
        for _=1,30 do local q=A.rot2q(r); r=A.step_yp(r,A.qrot(q,rest),tg,0.4,60,80,A.qrot(q,up0),max_roll) end
        return r
    end
    local tl2,b=tilt_about_bore(run(25))
    assert(tl2<0.5,'chest tilt about the bore '..tl2)
    assert(math.deg(math.acos(math.min(1,(b.X*tg.X+b.Y*tg.Y+b.Z*tg.Z)/tl)))<0.2,'bore off the target')
    assert(tilt_about_bore(run(0))>5,'max_roll 0: no roll')
    -- the cap: a 10 deg tilt with max_roll 4 is cut to about 6
    local t4=tilt_about_bore(run(4)); assert(t4>5 and t4<7.5,'roll cap '..t4)
    -- the pitch the target needs before its cap
    local _,need=A.step_yp({Pitch=0,Yaw=0,Roll=0},{X=1,Y=0,Z=0},{X=math.cos(math.rad(40)),Y=0,Z=math.sin(math.rad(40))},0.5,28,80)
    assert(math.abs(need-40)<1e-6)
end
-- 8. No garbage: step_yp with out gives the same rotator and need to the bit as the table-based step_yp it replaced (a
-- copy below), over random inputs with and without the roll; with out it makes no table (under 1 KB for 2000 calls).
do
    local Old=(function()
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

    -- Yaw-and-pitch step: the rest bore is the bore undone by the current rotation; the target rotation yaws it about the
    -- component's up axis (Z) onto the wanted azimuth, then pitches it about the horizontal axis across it onto the wanted
    -- elevation; the result moves gain of the way there. Yaw and pitch are capped separately (degrees).
    -- up (her chest's up now, component space) and max_roll (deg): the target is also rolled about the turned bore until
    -- that up is level with world up across the bore, at most max_roll. The bore's direction does not change, so the aim
    -- still converges. nil or 0: no roll (the chest keeps whatever cant the stance gives).
    -- Returns the next rotator and the pitch the target needs before its cap (deg).
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
    function A.step_yp(cur,bore,want,gain,max_pitch,max_yaw,up,max_roll)
        local q=A.rot2q(cur)
        local rest=nrm(A.qrot({-q[1],-q[2],-q[3],q[4]},bore)); local w=nrm(want)
        local azr,elr=math.atan(rest.Y,rest.X),math.asin(math.max(-1,math.min(1,rest.Z)))
        local azw,elw=math.atan(w.Y,w.X),math.asin(math.max(-1,math.min(1,w.Z)))
        local yaw=math.deg(azw-azr); yaw=(yaw+180)%360-180
        local need=math.deg(elw-elr)
        yaw=math.max(-max_yaw,math.min(max_yaw,yaw)); local pit=math.max(-max_pitch,math.min(max_pitch,need))
        local h={X=-math.sin(azr),Y=math.cos(azr),Z=0} -- up x rest azimuth: turning about it by -pitch raises the bore
        local qt=qmul(axis_q({X=0,Y=0,Z=1},yaw),axis_q(h,-pit))
        if up and max_roll and max_roll>0 then
            local b=A.qrot(qt,rest) -- the bore after the target turn
            local u=A.qrot(qt,A.qrot({-q[1],-q[2],-q[3],q[4]},up)) -- her up after it
            local function across(v) local k=dot(v,b); return {X=v.X-b.X*k,Y=v.Y-b.Y*k,Z=v.Z-b.Z*k} end
            local ua,za=across(u),across({X=0,Y=0,Z=1})
            if len(ua)>1e-6 and len(za)>1e-6 then
                local roll=math.deg(math.atan(dot(b,cross(ua,za)),dot(ua,za))) -- signed, about the bore
                roll=math.max(-max_roll,math.min(max_roll,roll))
                qt=qmul(axis_q(b,roll),qt)
            end
        end
        return A.q2rot(slerp(q,qt,gain)),need
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
    end)()
    math.randomseed(7)
    local function rv() return {X=math.random()*2-1,Y=math.random()*2-1,Z=math.random()*2-1} end
    local out={}
    for i=1,500 do
        local cur={Pitch=math.random()*120-60,Yaw=math.random()*160-80,Roll=math.random()*40-20}
        local bore,want,up=rv(),rv(),rv()
        local mr=(i%3==0) and 0 or (i%3==1) and 25 or nil
        local a,na=Old.step_yp(cur,bore,want,0.35,28,55,up,mr)
        local b,nb=A.step_yp(cur,bore,want,0.35,28,55,up,mr,out)
        assert(b==out and a.Pitch==b.Pitch and a.Yaw==b.Yaw and a.Roll==b.Roll and na==nb,'step_yp differs at '..i)
        local c=A.step_yp(cur,bore,want,0.35,28,55,up,mr)
        assert(c~=out and c.Pitch==a.Pitch and c.Yaw==a.Yaw and c.Roll==a.Roll)
        assert(A.rot2q(cur)[4]==Old.rot2q(cur)[4] and A.q2rot(Old.rot2q(cur)).Yaw==Old.q2rot(Old.rot2q(cur)).Yaw)
    end
    -- in place (out is cur): the same as into a fresh table
    local cur={Pitch=10,Yaw=-20,Roll=3}; local bore,want,up={X=1,Y=0.1,Z=0.2},{X=0.5,Y=0.6,Z=0.1},{X=0,Y=0.1,Z=1}
    local ref=A.step_yp(cur,bore,want,0.35,28,55,up,25)
    A.step_yp(cur,bore,want,0.35,28,55,up,25,cur)
    assert(cur.Pitch==ref.Pitch and cur.Yaw==ref.Yaw and cur.Roll==ref.Roll)
    collectgarbage('collect'); collectgarbage('stop')
    local k0=collectgarbage('count')
    for _=1,2000 do A.step_yp(cur,bore,want,0.35,28,55,up,25,cur) end
    local kb=collectgarbage('count')-k0
    collectgarbage('restart')
    assert(kb<1,('step_yp made %.1f KB in 2000 calls'):format(kb))
end
print('gunmode aimrot_test ok')
