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
print('gunmode v4_rules_test ok')
