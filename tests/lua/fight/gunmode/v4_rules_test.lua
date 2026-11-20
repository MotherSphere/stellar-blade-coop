-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- v4 rules: the layer clip choice (hip fire raises the rifle, a ground move carries it, the flip keeps the aim), the
-- native aim bridge through a dodge, and her body tilt for the flip.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local GunMode=require('fight.gunmode.mode')
local Input=require('fight.gunmode.input')
local A=require('fight.gunmode.aimrot')

-- 1. The layer clip.
assert(GunMode.want(nil,false,true,nil,false)=='aim')        -- hip fire raises the rifle
assert(GunMode.want(nil,false,false,nil,false)=='carry')
assert(GunMode.want(nil,true,false,nil,false)=='aim')
assert(GunMode.want(nil,true,true,'Evade',false)=='carry')    -- a dodge on the ground carries it
assert(GunMode.want(nil,true,true,'Flip',true)=='aim')        -- the double-jump flip keeps the aim
assert(GunMode.want(5,true,true,nil,false)=='reload')
assert(GunMode.want(5,false,false,'Evade',false)=='reload')

-- 2. The aim bridge: a dodge with the key held keeps the aim; the game's aim back or the key let go ends it.
assert(Input.bridge(nil,false,true,0.2)==true)     -- aim dropped 0.2 s ago, key held
assert(Input.bridge(true,false,true,5)==true)       -- still held: still aimed
assert(Input.bridge(true,true,true,0)==false)       -- the game aims again: bridge off
assert(Input.bridge(true,false,false,0)==false)     -- key let go
assert(Input.bridge(false,false,true,1.5)==false)   -- long after the aim: not bridged
assert(Input.bridge(false,false,true,nil)==false)   -- never aimed

-- 3. Body tilt: Pelvis->Spine1 against world up.
local close=function(a,b) return math.abs(a-b)<1e-9 end
local o={X=0,Y=0,Z=0}
assert(close(A.tilt(o,{X=0,Y=0,Z=10}),0) and close(A.tilt(o,{X=10,Y=0,Z=0}),90) and close(A.tilt(o,{X=0,Y=0,Z=-5}),180))
assert(close(A.tilt({X=1,Y=2,Z=3},{X=1,Y=9,Z=10}),45))
-- 4. The aim clip by rifle pitch, with hysteresis.
assert(GunMode.aim_clip(nil,0,22,15)=='aim')
assert(GunMode.aim_clip('aim',25,22,15)=='aimup')
assert(GunMode.aim_clip('aimup',18,22,15)=='aimup')   -- inside the band: stays
assert(GunMode.aim_clip('aimup',14,22,15)=='aim')
assert(GunMode.aim_clip('aim',-30,22,15)=='aimdown')
assert(GunMode.aim_clip('aimdown',-16,22,15)=='aimdown')
assert(GunMode.aim_clip('aim',18,22,15)=='aim')       -- from level, 18 is not enough
assert(GunMode.aim_clip('carry',nil,22,15)=='aim')
-- 5. Recoil envelope, hip-fire turn hysteresis, comeback after an interaction.
assert(GunMode.kick(nil,0.06)==0 and GunMode.kick(0,0.06)==1 and GunMode.kick(0.06,0.06)<0.4 and GunMode.kick(1,0.06)==0)
assert(GunMode.turn(false,45,40,12)==true and GunMode.turn(true,30,40,12)==true and GunMode.turn(true,10,40,12)==false)
assert(GunMode.turn(false,-50,40,12)==true and GunMode.turn(false,30,40,12)==false)
assert(GunMode.resume_due(nil,5,1)==false and GunMode.resume_due(4.5,5,1)==false and GunMode.resume_due(4,5,1)==true)
-- The chest turn's ease back: a zero turn is the same table (no garbage a frame), a tiny one snaps to 0, a big one eases.
do
    local z={Pitch=0,Yaw=0,Roll=0}
    assert(GunMode.decay(A,z)==z)
    local t=GunMode.decay(A,{Pitch=0.0002,Yaw=-0.0003,Roll=0})
    assert(t.Pitch==0 and t.Yaw==0 and t.Roll==0)
    local e=GunMode.decay(A,{Pitch=10,Yaw=-20,Roll=0})
    assert(math.abs(e.Pitch-8.5)<1e-9 and math.abs(e.Yaw+17)<1e-9 and e.Roll==0)
end

-- 6. Gun mode's own shots count one round each; the last one starts the reload; none while reloading.
do
    function FName(x) return x end
    local Ammo=require('fight.gunmode.ammo')
    local g={log=function() end,valid=function() return false end,try=function(f) local ok,r=pcall(f); if ok then return r end end}
    local cfg={mag_size=3,spare_mags=2,reload_time=1,fire_interval=0.045,reload_delay=2,round_name='x',round_color={R=1,G=1,B=1,A=1},reload_text='r'}
    local reloads=0
    local a=Ammo.new(g,cfg,function() end,function(on) if on then reloads=reloads+1 end end,nil)
    assert(a.spend(0)==true and a.left==2)
    assert(a.spend(0.1)==true and a.spend(0.2)==true and a.left==0 and reloads==1)
    assert(a.spend(0.3)==false and a.left==0)
    -- the player's reload: the rest of the magazine is thrown away; no reload when lowered
    local b=Ammo.new(g,cfg,function() end,function() end,nil)
    b.spend(0) -- 2 left, 6 spare
    for i=1,600 do b.tick(false,false,1+i/60) end -- 10 s lowered with a part-spent magazine
    assert(b.left==2 and not b.reload_until,'no reload when lowered')
    assert(b.manual(20)==true and b.left==0)
    for i=1,120 do b.tick(false,false,20+i/60) end -- the reload runs out
    assert(b.left==3 and b.reserve==3,'manual reload: left '..b.left..' reserve '..b.reserve)
    assert(b.manual(30)==false,'full magazine: no reload')
end
-- 7. The hip-fire snap: starts on the press with a big gap, its direction latched; ends close to the camera or late.
do
    local sn=GunMode.snap(nil,true,50,1,45,6,0.3)
    assert(sn and sn.dir==1 and sn.at==1)
    assert(GunMode.snap(nil,true,-170,1,45,6,0.3).dir==-1)
    assert(GunMode.snap(nil,true,30,1,45,6,0.3)==nil)     -- a small gap: no snap
    assert(GunMode.snap(nil,false,90,1,45,6,0.3)==nil)    -- not the press: no snap
    assert(GunMode.snap(sn,false,20,1.1,45,6,0.3)==sn)    -- still turning
    assert(GunMode.snap(sn,false,5,1.1,45,6,0.3)==nil)    -- inside stop_deg: done
    assert(GunMode.snap(sn,false,20,1.31,45,6,0.3)==nil)  -- past max_s: done
    local a=GunMode.snap(nil,true,179,0,45,6,0.3)
    local b=GunMode.snap(a,false,-179,0.02,45,6,0.3)      -- the gap's sign flips near 180 deg
    assert(b==a and b.dir==1)
end
-- 8. The sound cache: one load per path; loaded again when the kept object is gone or has another path; a path that
-- did not load is not tried again.
do
    local loads=0
    local function obj(full) return {full=full,ok=true,GetFullName=function(o) return o.full end} end
    local P='/Game/X/Shot_Cue.Shot_Cue'
    local function load(p) loads=loads+1; if p==P then return obj('SoundCue '..P) end end
    local g={valid=function(o) return o.ok end,try=function(f) local ok,r=pcall(f); if ok then return r end end}
    local cues={}
    local a=GunMode.cue(cues,P,g,load)
    assert(a and GunMode.cue(cues,P,g,load)==a and loads==1)
    a.full='Texture2D /Game/Other.Other'                    -- its address reused by another object
    local b=GunMode.cue(cues,P,g,load); assert(b~=a and loads==2)
    b.ok=false                                              -- collected
    assert(GunMode.cue(cues,P,g,load)~=b and loads==3)
    assert(GunMode.cue(cues,'/Game/None.None',g,load)==nil and GunMode.cue(cues,'/Game/None.None',g,load)==nil and loads==4)
end
-- 9. One hip-fire frame (GunMode.hip_step): the snap's latched way gives a positive step when the gap flips from 179 to
-- -179; the turn's hysteresis on the gap; the step capped by rate and dt.
do
    local C={snap_deg=45,snap_rate=1440,snap_max=0.3,turn_start=25,turn_stop=6,turn_rate=360}
    local sn,turning,st=GunMode.hip_step(nil,nil,true,179,0,0.016,C)
    assert(sn and sn.dir==1 and turning and st>0 and math.abs(st-1440*0.016)<1e-9)
    sn,turning,st=GunMode.hip_step(sn,turning,false,-179,0.016,0.016,C)
    assert(sn and turning and st>0,'the latched way: step '..st)
    sn,turning,st=GunMode.hip_step(nil,nil,false,-30,1,0.016,C)       -- no press: the turn alone, at turn_rate
    assert(sn==nil and turning and math.abs(st+360*0.016)<1e-9)
    sn,turning,st=GunMode.hip_step(nil,true,false,10,1,0.016,C)       -- inside the band: still turning
    assert(turning and math.abs(st-360*0.016)<1e-9)
    sn,turning,st=GunMode.hip_step(nil,true,false,4,1,0.016,C)        -- inside turn_stop: done
    assert(not turning and st==0)
    sn,turning,st=GunMode.hip_step(nil,false,false,20,1,1,C)          -- a long frame: dt clamped to 0.05
    assert(not turning and st==0)
    sn,turning,st=GunMode.hip_step(nil,false,false,40,1,1,C)
    assert(turning and math.abs(st-360*0.05)<1e-9)
end
-- 10. The bore rule (laser and rounds share it) and the hip-fire alignment gate.
do
    assert(GunMode.on_bore(true,false,true,false))           -- the flip: always the bore
    assert(GunMode.on_bore(false,true,false,true))           -- native hip fire with the layer
    assert(not GunMode.on_bore(false,true,true,true))        -- the game's aim: the crosshair point
    assert(not GunMode.on_bore(false,true,nil,false))        -- gun_fire=own: the crosshair point
    assert(not GunMode.on_bore(false,false,false,true))      -- no layer
    assert(GunMode.aligned(false,nil,2,1,1.05,4))
    assert(not GunMode.aligned(false,{at=1,dir=1},2,1,1.05,4),'no round during a snap')
    assert(not GunMode.aligned(false,nil,5,1,1.05,4) and not GunMode.aligned(false,nil,2,1,1.2,4) and not GunMode.aligned(false,nil,nil,nil,1,4))
    assert(GunMode.aligned(true,{at=1,dir=1},nil,nil,9,4))   -- the flip fires along the bore
end
-- 11. The chest takes the pitch first: below the cap the rifle's pitch stays 0 (or eases out); at the cap it grows by the
-- pitch error; it unwinds when the error turns; it stays within rm.
do
    assert(GunMode.rpitch_step(0,10,15,28,55)==0)                     -- the chest still has room: no rifle pivot
    assert(GunMode.rpitch_step(nil,-10,-20,28,55)==0)
    assert(math.abs(GunMode.rpitch_step(4,5,15,28,55)-3.4)<1e-9)       -- below the cap: eases out
    assert(math.abs(GunMode.rpitch_step(0,10,40,28,55)-3.5)<1e-9)      -- past the cap: grows
    assert(math.abs(GunMode.rpitch_step(0,-10,-27.5,28,55)+3.5)<1e-9)  -- within 1 deg of the cap counts
    assert(GunMode.rpitch_step(12,0,28,28,55)==12)                     -- at the cap, on target: held
    assert(math.abs(GunMode.rpitch_step(12,-4,10,28,55)-10.6)<1e-9)    -- the error turned: unwinds
    assert(GunMode.rpitch_step(54,100,90,28,55)==55)                   -- capped at rm
    -- a closed loop: wanted elevation 40 with a 28 deg chest cap settles on target with the chest within 1 deg of its cap
    local chest,rp,want=0,0,40
    for _=1,200 do
        local need=want-rp                                             -- the rest bore carries the rifle's pitch
        chest=chest+(math.max(-28,math.min(28,need))-chest)*0.35
        rp=GunMode.rpitch_step(rp,want-(chest+rp),need,28,55)
    end
    assert(math.abs(chest+rp-40)<0.1 and chest>=27-0.1 and rp<=13+0.1,'settled at chest '..chest..' rifle '..rp)
    chest,want=chest,20                                                -- aim lower: the rifle pitch goes, the chest takes it
    for _=1,200 do
        local need=want-rp
        chest=chest+(math.max(-28,math.min(28,need))-chest)*0.35
        rp=GunMode.rpitch_step(rp,want-(chest+rp),need,28,55)
    end
    assert(math.abs(rp)<0.1 and math.abs(chest-20)<0.1,'back to chest '..chest..' rifle '..rp)
end
print('gunmode v4_rules_test ok')
