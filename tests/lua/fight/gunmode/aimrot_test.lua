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

print('gunmode aimrot_test ok')
