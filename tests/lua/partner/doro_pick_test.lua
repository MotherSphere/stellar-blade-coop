-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- partner/doro_pick.lua with lua5.4 alone: the cases of tests/lua/race/doro_test.lua for Doro.pick and Doro.tilted,
-- copied with the code (November 2026 restructure).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Doro=require('partner.doro_pick')
local function close(a,b) return math.abs(a-b)<1e-6 end
-- Doro.pick: the mapping on the ground, each speed from a fresh state (the first frame takes the speed as it is).
local function pick(speed,sprint) return Doro.pick({},{speed=speed,vz=0,falling=false,sprint=sprint,now=0}) end
for _,case in ipairs({{0,0,1},{150,150,1},{300,300,1},{500,500,1},{700,500,1.4},{900,500,1.8},{1000,500,1.8}}) do
    local c=pick(case[1],false)
    assert(c.asset=='two' and c.loop==true and close(c.input,case[2]) and close(c.rate,case[3]) and c.at==nil,
        case[1]..': '..c.asset..' '..c.input..' '..c.rate)
end
-- All fours while she sprints, and 0.3 s after.
local state={}
local function at(s,t,speed,sprint,extra)
    local p={speed=speed,vz=0,falling=false,sprint=sprint,now=t}
    for k,v in pairs(extra or {}) do p[k]=v end
    return Doro.pick(s,p)
end
assert(at(state,0,700,true).asset=='four' and at(state,0.1,700,true).asset=='four')
assert(at(state,0.3,700,false).asset=='four' and at(state,0.39,700,false).asset=='four','0.3 s of hold')
assert(at(state,0.41,700,false).asset=='two','Two legs again after the hold')
assert(at(state,0.5,700,true).asset=='four','Sprinting again')
-- The ghost (no sprint flag): all fours above 560 cm/s, two legs again below 520. 10 s apart: the smoothing settled.
state={}
assert(at(state,0,550).asset=='two' and at(state,10,570).asset=='four','On above 560')
assert(at(state,20,530).asset=='four' and at(state,30,521).asset=='four','Kept down to 520')
assert(at(state,40,515).asset=='two' and at(state,50,550).asset=='two','Off below 520, on again only above 560')
local c=at(state,60,700)
assert(c.asset=='four' and close(c.input,500) and close(c.rate,1.4))
-- The speed is smoothed over about 0.1 s: from standing to 500 cm/s, 0.1 s later 63 % of it.
state={}
at(state,0,0,false)
c=at(state,0.1,500,false)
assert(close(c.input,500*(1-math.exp(-1))),c.input)
assert(close(at(state,0.1,0,false).input,c.input),'No time passed: no change')
-- Take-off (falling with an upward speed): the hop from 0 to 0.5 s; a longer fall holds 0.5 s; landing plays the rest,
-- then the blend space again. Never a notify: SetPosition is told not to fire them (apply below).
state={}
at(state,0,300,false)
local function air(t,falling,vz) return at(state,t,300,false,{falling=falling,vz=vz}) end
c=air(1,true,600)
assert(c.asset=='evade' and c.loop==false and c.rate==1 and c.at==0 and c.input==nil,'Take-off from the start')
c=air(1.3,true,200)
assert(c.asset=='evade' and c.rate==1 and c.at==nil,'The hop plays on')
c=air(1.5,true,-100)
assert(c.asset=='evade' and c.rate==0 and c.at==0.5,'Held at 0.5 s')
c=air(3,true,-900)
assert(c.rate==0 and c.at==0.5,'Still held')
c=air(3.1,false,0)
assert(c.asset=='evade' and c.rate==1 and c.at==0.5,'Landing: from 0.5 s')
c=air(3.6,false,0)
assert(c.asset=='evade' and c.rate==1 and c.at==nil,'The landing plays on')
c=air(3.68,false,0)
assert(c.asset=='two' and c.loop==true,'Back on the blend space after 0.57 s')
-- Walking off a ledge (no upward speed): held at once.
c=air(4,true,-50)
assert(c.rate==0 and c.at==0.5,'A fall with no take-off is held')
-- A landing before the hop ends goes on from 0.5 s.
state={}
c=at(state,0,0,false,{falling=true,vz=500})
c=at(state,0.2,0,false,{falling=false,vz=0})
assert(c.rate==1 and c.at==0.5)
-- The ghost has no falling flag: in the air while her vertical speed is past 400 cm/s.
state={}
local function ghost(t,vz) return Doro.pick(state,{speed=0,vz=vz,now=t}) end
assert(ghost(0,300).asset=='two','A slope: on the ground')
c=ghost(1,500)
assert(c.asset=='evade' and c.at==0,'Up past 400: a take-off')
assert(ghost(2,-800).rate==0,'Falling: held')
assert(ghost(3,0).at==0.5,'Landed')
-- A whole jump as the ghost's feet give it (the mean vertical speed over each 50 ms): the hop, then held through its
-- top, where the speed passes 0, until her feet are down, then one landing. Also a jump whose top comes after the hop's
-- 0.5 s.
for _,v0 in ipairs({800,1200}) do
    state={}
    local function z(t) return math.max(0,v0*t-980*t*t) end
    local down,landed=v0/980,nil -- When her feet are down again; when the Doro landed.
    for k=1,40 do
        local t=k*0.05
        c=Doro.pick(state,{speed=0,vz=(z(t)-z(t-0.05))/0.05,now=t})
        if c.asset=='evade' and c.at==0.5 and c.rate==1 then
            assert(not landed and t>down,v0..': landed in the air at '..t)
            landed=t
        elseif t<down then
            assert(c.asset=='evade' and c.rate==(t-0.05<0.5 and 1 or 0),v0..' at '..t..': '..c.asset..' '..c.rate)
        end
    end
    assert(landed and landed<=down+0.1,v0..': landed at '..tostring(landed))
end
-- Onto a ledge (up, never down): held, then landed 1 s after take-off.
state={}
assert(ghost(0,600).at==0 and ghost(0.6,0).rate==0)
c=ghost(1,0)
assert(c.rate==1 and c.at==0.5,'Landed on the ledge')
-- Emotes: only while standing (under 50 cm/s); a moving racer keeps the speed mapping.
c=pick(0,false); assert(c.asset=='two')
c=Doro.pick({},{speed=20,vz=0,falling=false,sprint=false,emote='win',now=0})
assert(c.asset=='evade' and c.loop==true and c.rate==1 and c.at==nil,'The winner hops, looping')
c=Doro.pick({},{speed=0,vz=0,falling=false,emote='lose',now=0})
assert(c.asset=='exhaust' and c.loop==true,'The others are out of breath')
c=Doro.pick({},{speed=300,vz=0,falling=false,sprint=false,emote='win',now=0})
assert(c.asset=='two' and c.input==300,'Moving: no emote')
c=Doro.pick({},{speed=0,vz=500,falling=true,sprint=false,emote='win',now=0})
assert(c.asset=='evade' and c.loop==false and c.at==0,'In the air: no emote')
-- EVE's dash: a root-motion move the game flags as falling, with no real vertical speed, runs on all fours; a jump
-- with root motion (a fast vertical speed) still hops.
c=Doro.pick({},{speed=1248,vz=30,falling=true,sprint=false,root=true,now=0})
assert(c.asset=='four' and c.loop==true and c.rate==1.8,'A dash is no jump: '..tostring(c.asset))
c=Doro.pick({},{speed=600,vz=700,falling=true,sprint=false,root=true,now=0})
assert(c.asset=='evade' and c.at==0,'A root-motion jump still hops')
local dash={}
Doro.pick(dash,{speed=1200,vz=0,falling=true,sprint=false,root=true,now=0})
c=Doro.pick(dash,{speed=500,vz=0,falling=false,sprint=false,now=0.2})
assert(c.asset=='four','On all fours for 0.3 s after the dash, as after a sprint')
c=Doro.pick(dash,{speed=500,vz=0,falling=false,sprint=false,now=0.6})
assert(c.asset=='two','Two legs again')

-- While a race drives: all fours from 60% of the top speed (1320 of 2200), two legs again under 55% (1210); the play
-- rate up to 3; the stumble's tired hop at twice its speed, from its start; a lean into the bend from the speed and the
-- turn rate, smoothed; a landing's pitch from its speed, settling; none of it without a drive.
local DRIVE={top=2200,yaw=0}
local function driven(t,speed,extra)
    local p={speed=speed,vz=0,falling=false,sprint=false,now=t,drive=DRIVE}
    for k,v in pairs(extra or {}) do p[k]=v end
    return Doro.pick(state,p)
end
state={}
c=driven(0,1300)
assert(c.asset=='two' and close(c.rate,1300/500) and c.input==500 and c.tilt.lean==0 and c.tilt.pitch==0)
assert(driven(10,1400).asset=='four','All fours past 1320')
assert(driven(20,1220).asset=='four' and driven(30,1200).asset=='two','Kept down to 1210')
c=driven(40,2200)
assert(c.asset=='four' and close(c.rate,3),'The play rate stops at 3')
assert(close(Doro.pick({},{speed=2200,vz=0,falling=false,sprint=false,now=0}).rate,1.8),'1.8 outside a race')
assert(Doro.pick({},{speed=2200,vz=0,falling=false,sprint=false,now=0}).tilt==nil,'No tilt outside a race')
-- The stumble.
c=driven(41,500,{drive={top=2200,yaw=0,stumble=true}})
assert(c.asset=='stumble' and c.loop==false and c.rate==2 and c.at==0)
c=driven(41.1,500,{drive={top=2200,yaw=0,stumble=true}})
assert(c.asset=='stumble' and c.at==nil,'Played on')
assert(driven(41.2,500).asset=='two','Over: the blend space again')
-- The lean: 1000 cm/s turning right at 30 deg/s is 0.53 g: 13.3 degrees once settled.
state={}
for k=0,200 do c=driven(k/100,1000,{drive={top=2200,yaw=k*0.3}}) end
local g=1000*math.rad(30)/981
assert(math.abs(c.tilt.lean-25*g)<1e-3,c.tilt.lean)
for k=201,400 do c=driven(k/100,1000,{drive={top=2200,yaw=60-(k-200)*0.3}}) end
assert(math.abs(c.tilt.lean+25*g)<1e-3,'Left: the other way')
for k=401,600 do c=driven(k/100,2200,{drive={top=2200,yaw=(k-400)*3}}) end
assert(math.abs(c.tilt.lean-25)<1e-3,'At most 25 degrees')
-- A landing at 600 cm/s down: the nose 12 degrees at once, then it settles.
state={}
driven(0,1000)
driven(0.1,1000,{falling=true,vz=-600})
c=driven(0.2,1000,{falling=false,vz=0})
assert(c.asset=='evade' and close(c.tilt.pitch,12),c.tilt.pitch)
c=driven(0.5,1000)
assert(math.abs(c.tilt.pitch)<0.2,c.tilt.pitch)
state={}
driven(0,1000)
driven(0.1,1000,{falling=true,vz=-2000})
assert(close(driven(0.2,1000).tilt.pitch,15),'At most 15')
-- Doro.tilted: the lean on Pitch, the nose on Roll; none: the rotator as it is.
local r=Doro.tilted({Pitch=1,Yaw=90,Roll=2},{lean=10,pitch=-3})
assert(r.Pitch==11 and r.Yaw==90 and r.Roll==-1)
r={Pitch=0,Yaw=0,Roll=0}
assert(Doro.tilted(r,nil)==r)
print('doro_pick_test ok')
