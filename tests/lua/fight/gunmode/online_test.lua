-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and what other players see, over fake UE4SS objects: the posed stance keeps its hidden donor body off EVE,
-- so the ghost's capture never sends it (M10).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local clock=100
os.clock=function() return clock end
local function noop() return function() end end
-- An engine object whose methods not given do nothing.
local function object(t)
    t=t or {}
    t.IsValid=function(o) return not rawget(o,'dead') end
    t.GetAddress=function(o) return o end
    return setmetatable(t,{__index=noop})
end

-- 1. M10: the posed stance adds no skeletal mesh component to EVE. Its donor and the keeper of its hide clip stand on
--    an actor of their own (online/partner/capture.lua lists every SkeletalMeshComponent of hers with a mesh, hidden
--    ones too); the actor goes at stop.
do
    local Stance=require('fight.gunmode.stance')
    local spawned={}
    local function component(owner,class)
        local c=object({owner=owner,class=class.path,VisibilityBasedAnimTickOption=0,
            GetBoneIndex=function() return 0 end,GetNumMaterials=function() return 0 end})
        c.SetSkeletalMesh=function(o,m) rawset(o,'mesh',m) end
        c.K2_DestroyComponent=function(o) rawset(o,'dead',true) end
        owner.comps[#owner.comps+1]=c
        return c
    end
    local world=object({SpawnActor=function(_,class,at,rotation)
        local a=object({class=class.path,at=at,rotation=rotation,comps={}})
        a.AddComponentByClass=function(o,c) return component(o,c) end
        a.K2_DestroyActor=function(o) rawset(o,'dead',true) end
        spawned[#spawned+1]=a
        return a
    end})
    LoadAsset=function(path) return object({path=path,GetPlayLength=function() return 1.6 end}) end
    StaticFindObject=function(path) return object({path=path}) end
    FName=function(t) return t end
    local src=object({LightingChannels={},GetNumMaterials=function() return 0 end,
        GetBoneIndex=function() return 0 end,SkeletalMesh=object({path='EVE body'})})
    local pawn=object({TPSModeType=0,bTPSMode=false,Mesh=src,comps={},GetWorld=function() return world end})
    pawn.AddComponentByClass=function(o,c) return component(o,c) end
    local stance=Stance.new(function() end)
    stance.start(object({Pawn=pawn}),function() return false end,function() return nil end)
    assert(stance.running(),'the posed stance runs')
    for _,c in ipairs(pawn.comps) do
        assert(c.class~='/Script/Engine.SkeletalMeshComponent','a skeletal mesh component on EVE: the capture sends it')
    end
    assert(#spawned==1 and spawned[1].class=='/Script/Engine.Actor','one actor of its own')
    local donors=0
    for _,c in ipairs(spawned[1].comps) do
        if c.class=='/Script/Engine.SkeletalMeshComponent' and c.mesh==src.SkeletalMesh then donors=donors+1 end
    end
    assert(donors==2,'the donor and the keeper on that actor')
    assert(stance.reload(true,1.6) and stance.reload(false),'the donor still plays the reload')
    stance.stop()
    assert(spawned[1].dead,'the actor goes at stop')
    for _,c in ipairs(pawn.comps) do assert(c.dead,'a part left on EVE') end
end

print('gunmode online: ok')
