-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's frame: it keeps running while the controller holds the same pawn. It stops when the controller
-- holds another pawn or the rifle component is gone.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local function obj(t) t=t or {}; if t.IsValid==nil then t.IsValid=function(o) return not o.dead end end; return t end
local nop=function() end
FName=function(n) return n end
StaticFindObject=function() return obj() end
LoadAsset=function() return obj() end
local gun=obj({SetCollisionEnabled=nop,SetSkeletalMesh=nop,K2_AttachToComponent=nop,K2_SetRelativeTransform=nop,
    SetVisibility=nop,SetCastShadow=nop,SetLightingChannels=nop,K2_DestroyComponent=nop})
local function pawn(addr) return obj({Mesh=obj({CastShadow=true,LightingChannels={}}),GetAddress=function() return addr end,
    AddComponentByClass=function() return gun end,FinishAddComponent=nop}) end
local pc=obj({Pawn=pawn(1)})
local r=require('fight.gunmode.rifle').new(function() end,nil)
r.start(pc,function() return false end,function() return nil end)
r.frame(); assert(r.running())
pc.Pawn=pawn(1); r.frame(); assert(r.running(),'the same pawn read again keeps it')
pc.Pawn=pawn(2); r.frame(); assert(not r.running(),'another pawn stops it')
pc.Pawn=pawn(1); r.start(pc,function() return false end,function() return nil end)
gun.dead=true; r.frame(); assert(not r.running(),'a lost rifle stops it')
-- The morph: a scale under 1 goes out in a fresh transform (GRIP itself never scaled) with the spin; nil puts GRIP back.
gun.dead=false
local sent,spun
gun.K2_SetRelativeTransform=function(_,t) sent=t end
gun.K2_AddLocalRotation=function(_,r) spun=r end
local Rifle=require('fight.gunmode.rifle')
pc.Pawn=pawn(1); r.start(pc,function() return false end,function() return nil end)
r.morph(0.5,90); r.frame()
assert(sent.Scale3D.X==0.5 and spun.Yaw==90,'morph scale and spin')
assert(Rifle.GRIP.Scale3D.X==1 and Rifle.GRIPS.aim.Scale3D.X==1,'GRIP not scaled in place')
r.morph(nil); spun=nil; r.frame()
assert(sent==Rifle.GRIP and spun==nil,'back to GRIP')
-- The laser's start: 0.12 s after the aim starts once the barrel is within 25 degrees of the line to the reticle
-- point, else 0.6 s after it. With the layer (no_turn) the test still runs. The rifle is never turned then.
local clock=0
os.clock=function() return clock end
local mathlib={GetForwardVector=function() return {X=1,Y=0,Z=0} end,Conv_VectorToRotator=function() return {} end,
    MakeTransform=function() return {} end,InvertTransform=function() return {} end,
    ComposeTransforms=function() return {Rotation={X=0,Y=0,Z=0,W=1}} end}
StaticFindObject=function() return mathlib end
gun.GetSocketLocation=function() return {X=0,Y=0,Z=0} end
gun.GetSocketRotation=function() return {Pitch=0,Yaw=0,Roll=0} end
gun.K2_GetComponentToWorld=function() return {Rotation={X=0,Y=0,Z=0,W=1}} end
local turned=0
gun.K2_SetWorldTransform=function() turned=turned+1 end
local function laser_at(deg,no_turn)
    local on
    local rl=Rifle.new(function() on=on or clock; return function() end,function() end end,nil)
    rl.no_turn=no_turn
    local a=math.rad(deg)
    clock=0; pc.Pawn=pawn(1)
    rl.start(pc,function() return true end,function() return {X=1000*math.cos(a),Y=1000*math.sin(a),Z=0} end)
    for _,t in ipairs({0,0.05,0.13,0.3,0.61}) do clock=t; rl.frame() end
    rl.stop()
    return on
end
assert(laser_at(3,true)==0.13,'layer: the laser 0.12 s after the aim starts with the barrel 3 degrees off')
assert(turned==0,'layer: the rifle is not turned')
assert(laser_at(39,true)==0.61,'layer: the laser after 0.6 s with the barrel 39 degrees off')
assert(laser_at(3,false)==0.13 and turned>0,'pak: the laser after 0.12 s and the rifle turned onto the line')
print('gunmode rifle_frame_test ok')
