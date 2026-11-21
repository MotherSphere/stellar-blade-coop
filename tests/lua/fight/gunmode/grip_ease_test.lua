-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The rifle's grip on a change of layer clip (carry to aim and back), at 60 frames a second in mode.lua's order: the
-- rifle's frame, the IK, then the grip of the new clip. The grip eases with the hands, so no frame turns the rifle much
-- more than the next one. The grip swapped at once turned it about 30 degrees in one frame.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(s) return s end
StaticFindObject=function() return {IsValid=function() return true end} end
LoadAsset=StaticFindObject
local T=0; os.clock=function() return T end
local IKm=require('fight.gunmode.ik'); local m=IKm.math
local Rifle=require('fight.gunmode.rifle')
IKm.CFG.pin_space='component'
local B={['Bip001-Spine2']={{0,0,140},{0,0,0,1}},['Bip001-R-UpperArm']={{0,12,145},{0,0,0,1}},
    ['Bip001-L-UpperArm']={{0,-12,145},{0,0,0,1}},['Bip001-L-Forearm']={{20,-20,125},{0,0,0,1}},
    ['Bip001-L-Hand']={{30,-10,110},{0,0,0,1}},['Bip001-R-Hand']={{20,20,110},{0,0,0,1}},
    ['Bip001-R-Forearm']={{10,25,125},{0,0,0,1}}}
local mesh={GetSocketTransform=function(_,b) local t=assert(B[b],b)
    return {Translation={X=t[1][1],Y=t[1][2],Z=t[1][3]},Rotation={X=t[2][1],Y=t[2][2],Z=t[2][3],W=t[2][4]}} end}
local pp={IsValid=function() return true end}
local IK=IKm.new({log=print,try=function(f) local ok,r=pcall(f); return ok and r or nil end})
local nop=function() end
local sent
local gun={IsValid=function() return true end,SetCollisionEnabled=nop,SetSkeletalMesh=nop,K2_AttachToComponent=nop,
    K2_SetRelativeTransform=function(_,t) sent=t end,SetVisibility=nop,SetCastShadow=nop,SetLightingChannels=nop}
local src={IsValid=function() return true end,CastShadow=true,LightingChannels={}}
local pawn={IsValid=function() return true end,Mesh=src,GetAddress=function() return 1 end,
    AddComponentByClass=function() return gun end,FinishAddComponent=nop}
local pc={IsValid=function() return true end,Pawn=pawn}
local r=Rifle.new(function() end,nil)
r.start(pc,function() return false end,function() return nil end)

local function rifle_q() -- the rifle's rotation: the written hand rotation times the grip sent to the engine
    local hq=m.rot2q(pp.RHandRot_CS); local g=sent.Rotation
    return m.qmul(hq,{g.X,g.Y,g.Z,g.W})
end
local function ang(a,b) local d=math.abs(a[1]*b[1]+a[2]*b[2]+a[3]*b[3]+a[4]*b[4]); return math.deg(2*math.acos(math.min(1,d))) end
local function tick(want)
    T=T+1/60
    r.frame()
    IK.want=want; IK.tick(nil,{Mesh=mesh},nil,want,pp)
    r.grip(want)
end
local function switch(from,to)
    for _=1,90 do tick(from) end
    local prev,turns=rifle_q(),{}
    for i=1,40 do tick(to); local q=rifle_q(); turns[i]=ang(prev,q); prev=q end
    local most=0; for i=1,#turns do most=math.max(most,turns[i]) end
    assert(turns[1]<=turns[2]*1.5+0.5 and turns[2]<=turns[3]*1.5+0.5,
        ('%s -> %s: rifle turn per frame %.1f %.1f %.1f'):format(from,to,turns[1],turns[2],turns[3]))
    assert(most<12,from..' -> '..to..': '..most..' deg in one frame')
end
switch('carry','aim')
switch('aim','carry')
-- Once eased, the grip is the clip's own.
for _=1,90 do tick('aim') end
local g,G=sent,Rifle.GRIPS.aim
assert(math.abs(g.Translation.X-G.Translation.X)<1e-3 and math.abs(g.Rotation.W-G.Rotation.W)<1e-3,'aim grip reached')
print('gunmode grip_ease_test ok')
