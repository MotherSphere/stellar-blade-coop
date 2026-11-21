-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Gun mode and what other players see, over fake UE4SS objects: the posed stance keeps its hidden donor body off EVE,
-- so the ghost's capture never sends it (M10); the laser hangs right on no part of EVE, so no partner draws a copy of
-- it ending at their own LaserPosition (M11); the rifle stays away while an SBO match runs, with a notice (M12).
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
local Fake=dofile('tests/lua/fight/gunmode/fake.lua')
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

-- 2. M11: the laser hangs from a plain scene component snapped to the rifle's muzzle socket, never right on the rifle
--    (its end is NC_NikkeMinigame's LaserPosition, one value per world: on a partner's game a copy would end at theirs).
--    The capture and the native effect read take only Niagara components hung right on a part. The engine carries it
--    with the muzzle: no update moves it.
do
    local Laser=require('fight.gunmode.laser')
    local at,beam,holder={},nil,nil
    local instance=object({GetVectorParameter=function() return {X=0,Y=0,Z=0} end})
    instance.SetVectorParameter=function(o,_,v) rawset(o,'end_at',v) end
    local library=object({GetNiagaraParameterCollection=function() return instance end})
    library.SpawnSystemAtLocation=function() error('spawned at a location: it lags the muzzle') end
    library.SpawnSystemAttached=function(_,asset,parent,point,location,rotation,kind,destroy,activate,pool,cull)
        at[#at+1]={asset=asset,parent=parent,point=point,location=location,kind=kind,destroy=destroy,
            activate=activate,pool=pool,cull=cull}
        beam=object({ComponentTags={}})
        beam.K2_SetWorldLocationAndRotation=function() error('the beam moved from Lua') end
        beam.Activate=function(o) rawset(o,'active',true) end
        return beam
    end
    local objects={['/Script/Niagara.Default__NiagaraFunctionLibrary']=library}
    StaticFindObject=function(path)
        objects[path]=objects[path] or object({path=path,LineTraceSingle=function() return false end})
        return objects[path]
    end
    LoadAsset=StaticFindObject
    FName=function(t) return t end
    local pawn=object()
    pawn.AddComponentByClass=function(_,class)
        holder=object({class=class.path,ComponentTags={}})
        holder.K2_AttachToComponent=function(o,parent,socket) rawset(o,'parent',parent); rawset(o,'socket',socket) end
        return holder
    end
    local gun=object({DoesSocketExist=function() return true end,GetSocketLocation=function() return {X=1,Y=2,Z=3} end,
        GetSocketRotation=function() return {Pitch=0,Yaw=90,Roll=0} end})
    local mathlib=object({GetForwardVector=function() return {X=1,Y=0,Z=0} end})
    local update,cleanup=Laser(pawn,gun,mathlib)
    assert(holder.class=='/Script/Engine.SceneComponent' and holder.parent==gun and holder.socket=='FX_Fire',
        'a plain scene component on the muzzle socket')
    assert(#at==1 and at[1].parent==holder and at[1].parent~=gun and at[1].asset.path:find('NS_A_GuideLaser',1,true),
        'spawned once, on the holder: never right on the rifle, a part the capture sends')
    assert(at[1].point=='None' and at[1].location.X==0 and at[1].kind==2,'snapped to the holder')
    assert(at[1].destroy==true and at[1].activate==false and at[1].pool==0 and at[1].cull==false,
        'destroyed when done, activated after its first update')
    assert(beam.active,'activated')
    update({X=900,Y=0,Z=0})
    assert(instance.end_at.X==900,'its end where the rounds go')
    cleanup()
end

-- 3. M11: the rifle layer updates the laser at each frame of aim, with or without the point the rounds go to.
do
    local w=Fake.new(); w.install()
    local Rifle=require('fight.gunmode.rifle')
    local updates=0
    local rifle=Rifle.new(function() return function() updates=updates+1 end,function() end end)
    rifle.start(w.pc,function() return true end,function() return nil end)
    clock=clock+1; rifle.frame() -- aim seen
    clock=clock+1; rifle.frame() -- the laser on, 0.6 s later
    clock=clock+1/60; rifle.frame()
    assert(updates==2,'laser updates: '..updates)
    rifle.stop()
end

-- 4. M12: while an SBO match runs (env.match) the rifle does not come out. A notice says why (ui/text.lua's
--    gun.match). One starting with the rifle out puts it away within 0.25 s with everything back, with the notice.
do
    package.loaded['fight.gunmode.laser']=function() return function() end,function() end end
    package.loaded['fight.gunmode.mode']=nil
    local GunMode=require('fight.gunmode.mode')
    local w=Fake.new(); w.install()
    local keys,match,logs,notices=w.keys(),true,{},{}
    local gun=GunMode.new({log=function(m) logs[#logs+1]=m end,match=function() return match end,
        notice=function(key) notices[#notices+1]=tostring(key) end})
    local function said(text)
        for _,l in ipairs(logs) do if l:find(text,1,true) then return true end end
        return false
    end
    clock=clock+1; gun.toggle_now()
    assert(not gun.state.on and said('not now: an SBO match runs'),table.concat(logs,'|'))
    assert(table.concat(notices,'|')=='match',table.concat(notices,'|'))
    assert(#w.changed()==0 and w.keys()==keys)
    clock=clock+1; gun.toggle_now()
    assert(#notices==1,'one notice in 3 s')
    match=false
    clock=clock+3; gun.toggle_now()
    assert(gun.state.on,'the rifle is out')
    match=true
    for _=1,20 do clock=clock+1/60; gun.tick() end
    assert(not gun.state.on and said('off (an SBO match runs'),table.concat(logs,'|'))
    assert(table.concat(notices,'|')=='match|match',table.concat(notices,'|'))
    assert(#w.changed()==0 and w.keys()==keys)
end

print('gunmode online: ok')
