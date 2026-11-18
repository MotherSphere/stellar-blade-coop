-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- vehicles/bike/stand.lua with fake UE4SS objects, built as online/modes/race/doro_test.lua builds them: the parked
-- bike made hidden and closed, WorldDynamic, blocking every channel but the camera, no overlap events, never a step, a
-- cull distance only when given; placed by a teleport; shown and hidden with its collision; open while EVE stands
-- inside it, solid once she is 20 cm clear, with one log line, its collision set on a change only; closed again when
-- hidden; removed; a sweep that takes only an actor whose root shows the bike.
package.path='mod/StellarCoop/Scripts/?.lua;'..package.path
FName=function(t) return {type=function() return 'FName' end,ToString=function() return t end} end
local next_address=0x1000
local function object(fields)
    next_address=next_address+0x100
    local at=next_address
    local o=fields or {}
    o.type=function() return 'UObject' end
    o.IsValid=o.IsValid or function(self) return not self.destroyed end
    o.GetAddress=function() return at end
    return o
end
local invalid=object({destroyed=true})
local function class(path) return object({path=path,MakeTransform=function() return 'identity' end}) end
local MESH,CHAIR='/Game/Test/Bike.Bike','/Game/Test/Chair.Chair'
local function mesh(path)
    return object({GetFullName=function() return 'SkeletalMesh '..path end,
        IsA=function(_,c) return c.path=='/Script/Engine.SkeletalMesh' end})
end
local assets={[MESH]=mesh(MESH),[CHAIR]=mesh(CHAIR)}
local by_path={} -- Actors StaticFindObject finds by path (an earlier Lua load's), beside classes and assets.
StaticFindObject=function(path)
    if by_path[path] then return by_path[path] end
    if path:find('^/Script/') then return class(path) end
    return assets[path] or invalid
end
LoadAsset=function(path) return assets[path] or invalid end
package.loaded.UEHelpers={GetPlayer=function() end}
-- The display's component: what the stand writes on it.
local function component(actor)
    local c=object({channel={},sets=0})
    function c:SetSkeletalMesh(m) self.SkeletalMesh=m end
    function c:SetRelativeScale3D() end
    function c:SetAnimationMode() end
    function c:SetCollisionEnabled(n) self.collision,self.sets=n,self.sets+1 end
    function c:SetCollisionObjectType(n) self.object_type=n end
    function c:SetCollisionResponseToAllChannels(r) self.all=r end
    function c:SetCollisionResponseToChannel(n,r) self.channel[n]=r end
    function c:SetGenerateOverlapEvents(on) self.overlap=on end
    function c:SetCullDistance(cm) self.cull=cm end
    function c:GetCollisionObjectType() return self.object_type end
    function c:K2_IsCollisionEnabled() return self.collision~=0 end
    function c:K2_SetWorldLocationAndRotation(_,_,sweep) assert(sweep==false) end
    function c:K2_DestroyComponent(owner) assert(owner==actor); self.destroyed=true end
    function c:IsA(k) return k.path=='/Script/Engine.SkeletalMeshComponent' end
    return c
end
local world=object({spawned={}})
function world:SpawnActor(c)
    assert(c.path=='/Script/Engine.Actor','A plain Actor only')
    local a=object({components={}})
    function a:SetActorEnableCollision(on,fast) assert(fast==false); self.collision=on end
    function a:SetActorHiddenInGame(on) self.hidden=on end
    function a:K2_SetActorLocationAndRotation(at,rot,sweep,hit,teleport)
        assert(type(hit)=='table')
        self.moved={at=at,rot=rot,sweep=sweep,teleport=teleport}
    end
    function a:AddComponentByClass(k,manual,transform,deferred)
        assert(k.path=='/Script/Engine.SkeletalMeshComponent' and manual==false and transform=='identity'
            and deferred==false)
        local added=component(self)
        self.components[#self.components+1]=added
        return added
    end
    function a:K2_GetRootComponent() return self.components[1] end
    function a:K2_DestroyActor() self.destroyed=true end
    local n=#self.spawned+1
    function a:GetFullName() return 'Actor /Game/Map.Map:PersistentLevel.Actor_'..n end
    self.spawned[n]=a
    return a
end
local eve=object({})
eve.Mesh={K2_GetComponentLocation=function() return eve.feet end}
eve.CapsuleComponent={GetUnscaledCapsuleRadius=function() return eve.radius end}

local Stand=require('vehicles.bike.stand')
assert(Stand.CULL==20000)
local d=Stand.make(world,MESH,Stand.CULL)
assert(#world.spawned==1 and d.actor==world.spawned[1] and d.path and d.shown==false)
local c=d.mesh
assert(c.object_type==1 and c.all==2 and c.channel[4]==0,'WorldDynamic, blocks all but the camera')
assert(c.overlap==false and c.CanCharacterStepUpOn==0 and c.collision==0 and c.cull==20000)
assert(d.actor.hidden==true and d.actor.collision==false,'Hidden and closed until it has a place')
assert(Stand.make(world,MESH).mesh.cull==nil,'Her own bike: no cull distance')
local at,rot={X=100,Y=200,Z=0},{Pitch=0,Yaw=90,Roll=0}
Stand.put(d,{map='/game/map/map',at=at,rot=rot})
assert(d.actor.moved.at==at and d.actor.moved.rot==rot and d.actor.moved.teleport==true and d.actor.moved.sweep==false)
Stand.show(d,true)
assert(d.actor.hidden==false and d.actor.collision==true and d.shown)
-- She stands inside it: open; 120 cm to its side and 20 cm clear: solid, one line; inside again: open.
eve.feet,eve.radius={X=100,Y=200,Z=0},35
assert(Stand.step(d,eve)==nil and c.collision==0)
eve.feet={X=100+83+35+21,Y=200,Z=0} -- Across the bike: it points along +Y at yaw 90.
local line=Stand.step(d,eve)
assert(c.collision==1 and line:find('^bike stand solid: type 1, collision on$'),line)
local sets=c.sets
assert(Stand.step(d,eve)==nil and c.sets==sets,'Set on a change only')
Stand.show(d,false)
assert(d.actor.hidden==true and d.actor.collision==false and c.collision==0 and d.solid==false)
Stand.remove(d)
assert(d.actor.destroyed and Stand.alive(d)==nil)
-- An earlier Lua load's actors: one that shows the bike, one that shows another mesh.
local other,chair=Stand.make(world,MESH),Stand.make(world,CHAIR)
local other_path,chair_path=other.path,chair.path
by_path[other_path],by_path[chair_path]=other.actor,chair.actor
assert(Stand.sweep(other_path,MESH)==true and Stand.sweep(chair_path,MESH)==nil,'Only an actor that shows the bike')
assert(other.actor.destroyed and not chair.actor.destroyed)
print('stand_test ok')
