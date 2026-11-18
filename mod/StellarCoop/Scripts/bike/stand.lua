-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The parked bike as an actor: race/doro.lua's spawn (a plain Actor, one SkeletalMeshComponent with the bike's mesh at
-- scale 1, its reference pose) whose component blocks as WorldDynamic, so EVE and enemies stop at it while the camera
-- passes. Its body is the mesh's own physics asset; no capsule is added. Made hidden and closed, placed by a teleport,
-- shown with its collision. Each pass while shown it is open while she stands inside it (a blocking overlap would shove
-- her out sideways) and solid once she is clear of it (bike/park.lua's rule). Her own bike and other players' copies
-- are both made here; only a copy gets a cull distance. tests/lua/bike/stand_test.lua covers it.
local U=require('core.unreal')
local Doro=require('core.actors')
local Park=require('bike.park')
local Stand={}
Stand.CULL=20000 -- cm: the copies' cull distance, 200 m.
-- A stand in world showing mesh (an object path), hidden and closed until put and shown. Raises, with nothing left,
-- when it cannot be made.
function Stand.make(world,mesh,cull)
    local d=Doro.spawn(world,{X=0,Y=0,Z=0},{Pitch=0,Yaw=0,Roll=0},{path=mesh})
    local ok,why=pcall(function()
        local c=d.mesh
        c:SetCollisionEnabled(0) -- First: whatever fails next, it never blocks.
        c:SetCollisionObjectType(1) -- ECC_WorldDynamic
        c:SetCollisionResponseToAllChannels(2) -- ECR_Block
        c:SetCollisionResponseToChannel(4,0) -- ECC_Camera: ignored.
        c:SetGenerateOverlapEvents(false)
        c.CanCharacterStepUpOn=0 -- ECB_No
        if cull then c:SetCullDistance(cull) end
        d.actor:SetActorHiddenInGame(true)
    end)
    if not ok then
        Doro.remove(d)
        error(why,0)
    end
    d.shown,d.solid,d.k=false,false,{}
    return d
end
-- The stand moved to place ({map, at, rot}), by a teleport with no sweep.
function Stand.put(d,place)
    d.actor:K2_SetActorLocationAndRotation(place.at,place.rot,false,{},true)
    d.place=place
end
-- Shown with the actor's collision on, or hidden with it off (matrix13/world/breakables.lua's show). Hidden also closes
-- the component and forgets whether she stood inside it.
function Stand.show(d,on)
    d.actor:SetActorEnableCollision(on,false) -- SB's Actor takes (bNewActorEnableCollision, inFastUpdate)
    d.actor:SetActorHiddenInGame(not on)
    if not on then
        d.mesh:SetCollisionEnabled(0)
        d.solid,d.k=false,{}
    end
    d.shown=on
end
-- One pass of the collision rule against eve while shown: the component opened or made solid on a change only. The
-- first time it turns solid it returns a line with its object type and collision as the engine reads them back.
function Stand.step(d,eve)
    if not (d.shown and d.place) then return nil end
    local feet=U.value_of(eve.Mesh:K2_GetComponentLocation())
    local on=Park.solid(d.k,Park.clear(d.place,feet,eve.CapsuleComponent:GetUnscaledCapsuleRadius()))
    if on==d.solid then return nil end
    d.mesh:SetCollisionEnabled(on and 1 or 0) -- QueryOnly: her movement's sweeps are queries.
    d.solid=on
    if on and not d.told then
        d.told=true
        return ('bike stand solid: type %s, collision %s'):format(tostring(d.mesh:GetCollisionObjectType()),
            d.mesh:K2_IsCollisionEnabled() and 'on' or 'off')
    end
end
-- The stand's actor while it is still the one made, else nil.
function Stand.alive(d) return Doro.same(d.actor,d.path) end
Stand.remove=Doro.remove
-- A stand an earlier Lua load made (Ctrl+R), by its actor's path: gone, and true, only while its root shows mesh.
Stand.sweep=Doro.sweep
return Stand
