-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode's toggle cost: an asset is found once and kept while it has its path, a miss waits 5 s; the drone of the
-- last rifle out is used again while it is that actor and near her; the gun_trace dumps run once per Lua load; the
-- native aim writes make no garbage.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local GunMode=require('fight.gunmode.mode')
local g={valid=function(o) return o~=nil and o.ok==true end,try=function(f) local ok,r=pcall(f); if ok then return r end end}
local function obj(full) return {ok=true,full=full,GetFullName=function(o) return o.full end} end

-- 1. GunMode.asset: one find over many uses; found again when collected or when its address holds another object; a
--    miss is not tried again for 5 s.
do
    local P='/Game/FX/NS_Flash.NS_Flash'
    local finds=0
    local present=true
    local function find(path) finds=finds+1; if present then return obj('NiagaraSystem '..path) end end
    local kept={}
    local a=GunMode.asset(kept,P,g,find,0)
    for t=1,100 do assert(GunMode.asset(kept,P,g,find,t*0.01)==a) end
    assert(finds==1,finds..' finds for 101 uses')
    a.full='Texture2D /Game/Other.Other'
    local b=GunMode.asset(kept,P,g,find,2); assert(b and b~=a and finds==2,'found again after its address changed')
    b.ok=false
    local c=GunMode.asset(kept,P,g,find,3); assert(c and c~=b and finds==3,'found again after it was collected')
    -- a path ending in the asked one is another asset
    c.full='NiagaraSystem /Game/Other'..P
    assert(GunMode.asset(kept,P,g,find,4)~=c and finds==4)
    present=false
    local Q='/Game/None.None'
    assert(GunMode.asset(kept,Q,g,find,10)==nil and finds==5)
    assert(GunMode.asset(kept,Q,g,find,14.9)==nil and finds==5,'a miss tried again within 5 s')
    present=true
    assert(GunMode.asset(kept,Q,g,find,15)~=nil and finds==6,'a miss tried again after 5 s')
end

-- 2. GunMode.kept_drone: the kept drone while it is the same actor and within 3000 units; else nil (walk again).
do
    local at={X=100,Y=0,Z=0}
    local d={ok=true,GetFullName=function() return 'CH_Drone_BP_C /Game/Map.Drone_1' end,K2_GetActorLocation=function() return at end}
    local k={actor=d,name='CH_Drone_BP_C /Game/Map.Drone_1'}
    local her={X=0,Y=0,Z=0}
    assert(GunMode.kept_drone(k,g,her)==d)
    assert(GunMode.kept_drone(nil,g,her)==nil)
    at={X=3100,Y=0,Z=0}; assert(GunMode.kept_drone(k,g,her)==nil,'a far drone kept')
    at={X=0,Y=2000,Z=2000}; assert(GunMode.kept_drone(k,g,her)==d,'2828 units away is near')
    k.name='CH_Drone_BP_C /Game/Map.Drone_2'; assert(GunMode.kept_drone(k,g,her)==nil,'another actor at its address')
    k.name='CH_Drone_BP_C /Game/Map.Drone_1'; d.ok=false; assert(GunMode.kept_drone(k,g,her)==nil,'a gone drone kept')
end

-- 3. GunMode.once: true the first time for each name in this Lua load, false after.
assert(GunMode.once('test_a')==true and GunMode.once('test_a')==false and GunMode.once('test_b')==true)
assert(GunMode.once('test_a')==false)
-- 4. The native aim writes (every frame while firing in the game's aim) make no closure: 1000 writes of each under 1 KB.
do
    local Aim=require('fight.gunmode.aim')
    local row={DestTargetRelativeLocation={X=0,Y=0,Z=0},StartTargetRelativeLocation={X=0,Y=0,Z=0}}
    local loc,rot={X=10,Y=20,Z=30},{Pitch=0,Yaw=45,Roll=0}
    local p={K2_GetActorLocation=function() return loc end,K2_GetActorRotation=function() return rot end}
    local a=Aim.new({log=function() end,try=g.try,valid=g.valid})
    a.row,a.writes,a.starts=row,99,99
    local tgt,mz,fb={X=500,Y=0,Z=40},{X=60,Y=20,Z=150},{X=30,Y=20,Z=140}
    a.write(p,tgt,-75); a.write_start(p,mz,25,fb,-75)
    local d=row.DestTargetRelativeLocation
    local x,y,z=Aim.local_offset(tgt,loc,45-75)
    assert(d.X==x and d.Y==y and d.Z==z,'destination written')
    collectgarbage('collect'); collectgarbage('stop')
    local k0=collectgarbage('count')
    for _=1,1000 do a.write(p,tgt,-75); a.write_start(p,mz,25,fb,-75) end
    local kb=collectgarbage('count')-k0
    collectgarbage('restart')
    assert(kb<1,('1000 aim writes made %.1f KB'):format(kb))
end
-- 5. The shot sound on the game's own aim rounds: only with the aim on and the magazine dropped, at most every 'every' s.
do
    local A=GunMode.aim_shot_sound
    assert(A(true,true,1.0,nil,0.09)==true)
    assert(A(false,true,1.0,nil,0.09)==false,'hip fire: shoot plays it for gun mode rounds')
    assert(A(true,false,1.0,nil,0.09)==false,'no round this frame')
    assert(A(true,true,1.05,1.0,0.09)==false and A(true,true,1.09,1.0,0.09)==true,'rate limit')
end
print('gunmode cost_test ok')
