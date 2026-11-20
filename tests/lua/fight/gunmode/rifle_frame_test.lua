-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's frame: it keeps running while the controller holds the same pawn, and it stops when the controller
-- holds another pawn or the rifle component is gone. The rifle's mesh is loaded once and kept while it has its path.
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
-- The rifle's mesh: one LoadAsset over three rifle outs while it keeps its path; loaded again once another object
-- sits at its address.
do
    local loads,mesh=0,nil
    LoadAsset=function(path) loads=loads+1; mesh=obj({GetFullName=function() return 'SkeletalMesh '..path end}); return mesh end
    for _=1,3 do pc.Pawn=pawn(1); r.start(pc,function() return false end,function() return nil end); r.stop() end
    assert(loads==1,loads..' rifle mesh loads over three rifle outs')
    mesh.GetFullName=function() return 'Texture2D /Game/Other.Other' end
    pc.Pawn=pawn(1); r.start(pc,function() return false end,function() return nil end); r.stop()
    assert(loads==2,loads..' rifle mesh loads after its address changed')
end
print('gunmode rifle_frame_test ok')
