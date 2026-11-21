-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's frame: it keeps running while the controller holds the same pawn. It stops when the controller holds
-- another pawn or the rifle component is gone.
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
-- In aim: the barrel turned onto the line to the reticle's point every frame, the whole error up to Rifle.TURN_MAX
-- (an error past it turned nothing before, so the rifle jumped as it crossed the limit), eased in at the aim's start.
do
    local T=50; local clock=os.clock; os.clock=function() return T end
    local have={X=1,Y=0,Z=0}
    local turned
    gun.GetSocketLocation=function() return {X=0,Y=0,Z=0} end
    gun.GetSocketRotation=function() return {} end
    gun.K2_GetComponentToWorld=function() return {Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}} end
    gun.K2_SetWorldTransform=function(_,t) turned=t.Rotation end
    StaticFindObject=function() return obj({GetForwardVector=function() return have end}) end
    local target
    local a=require('fight.gunmode.rifle').new(function() return function() end,function() end end,nil)
    pc.Pawn=pawn(1); a.start(pc,function() return true end,function() return target end)
    local function deg(q) return math.deg(2*math.acos(math.min(1,math.abs(q.W)))) end
    local function at(d) local r=math.rad(d); return {X=1000*math.cos(r),Y=1000*math.sin(r),Z=0} end
    target=at(3); turned=nil; a.frame() -- the aim's first frame: the turn eases in
    assert(turned==nil or deg(turned)<0.5,'eased in')
    T=T+1
    target=at(3); turned=nil; a.frame()
    assert(turned and math.abs(deg(turned)-3)<1e-3 and turned.Z>0,'the whole 3 degrees')
    target=at(10); turned=nil; a.frame()
    assert(turned and math.abs(deg(turned)-Rifle.TURN_MAX)<1e-3,'10 degrees off: the most it turns')
    sent=nil; target=at(30); turned=nil; a.frame()
    assert(turned==nil,'far off: no turn')
    -- The grip goes out again after a turned frame, then not while it stays as it is.
    assert(sent~=nil,'the grip sent again after a turned frame')
    sent=nil; a.frame()
    assert(sent==nil,'an unchanged grip sent again')
    os.clock=clock
end
print('gunmode rifle_frame_test ok')
