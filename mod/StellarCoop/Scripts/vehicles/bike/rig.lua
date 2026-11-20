-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- Adapted from kwisatz's puppet ride in Eve Hoverbike, with his written permission: https://github.com/MotherSphere/stellar-blade-coop/pull/11#issuecomment-7047471384
-- The rig: a hidden actor that plays the riding clip while EVE's body and outfit parts copy its bones
-- (SetMasterPoseComponent). No custom animation slot of hers is used, so SB's own plays into slot 0 never end a ride.
-- It is core/actors.lua's spawn (a plain Actor, one SkeletalMeshComponent with her body mesh, collision off), hidden,
-- posing while hidden, its cloth off, snapped to her main mesh, the clip looped in single-node mode. The rig is not
-- online/partner/puppet.lua's puppet (the other player's EVE model).
-- The engine's SetMasterPoseComponent (FUN_144129240, build 26123051; its leader a weak pointer at component +0x570)
-- moves the followers of her main mesh with it on a hook. An unhook (a null leader) moves none back, so each part gets
-- its own call back to her main mesh. A follower is a part of hers hung on her main mesh with no socket, no anim
-- instance of its own and a mesh (kwisatz's rule); the bike part is left out by its address. No log line here: the
-- callers log the counts. tests/lua/vehicles/bike/rig_test.lua covers it.
local U=require('core.unreal')
local Doro=require('core.actors')
local valid,value_of,each,find,address,text=U.valid,U.value_of,U.each,U.find,U.address,U.text
local Rig={}
local SKINNED='/Script/Engine.SkeletalMeshComponent'
local SNAP=2 -- EAttachmentRule::SnapToTarget (value table 0x1465480e0: KeepRelative 0, KeepWorld 1, SnapToTarget 2).
-- EVisibilityBasedAnimTickOption::AlwaysTickPoseAndRefreshBones (value table 0x14665ff00): hidden, it still poses.
local ALWAYS=0

local function main_of(e) return assert(valid(e) and valid(e.Mesh),'her main mesh does not read') end
-- Her skeletal mesh components (her main mesh among them), by address.
local function parts_of(e)
    local by={}
    each(e:K2_GetComponentsByClass(find(SKINNED)),function(_,c)
        c=valid(c)
        if c then by[address(c)]=c end
    end)
    return by
end
-- Whether c follows her main mesh (at: its address) by the rule. Its mesh is read first: a method call on a part with
-- no mesh is never made (kwisatz's note: a null read pcall cannot stop).
local function follows(c,at)
    if not valid(c.SkeletalMesh) then return false end
    local parent=valid(c:GetAttachParent())
    return parent~=nil and address(parent)==at and text(c:GetAttachSocketName())=='None'
        and not valid(c.AnimScriptInstance) -- UPROPERTY at +0x890 (params 0x146656c98).
end
-- The followers among parts (from parts_of) in address order, her main mesh (at) and skip left out. A part whose
-- read raises is left alone.
local function pick(parts,at,skip)
    local list={}
    for a,c in pairs(parts) do
        if a~=at and a~=skip then
            local ok,yes=pcall(follows,c,at)
            if ok and yes then list[#list+1]=c end
        end
    end
    table.sort(list,function(x,y) return address(x)<address(y) end)
    return list
end

-- The rig at EVE e wearing the body mesh at mesh_path (an object path in memory), playing clip (an AnimSequence object
-- in memory) looped. skip: the bike part's address, left out of her followers. Returns core/actors.lua's display
-- {actor=, path=, mesh=} with skip. Raises, with nothing left, when it cannot be made.
function Rig.make(e,mesh_path,clip,skip)
    local main=main_of(e)
    clip=assert(valid(clip),'the riding clip is not in memory')
    local p=value_of(e:K2_GetActorLocation())
    local d=Doro.spawn(e:GetWorld(),{X=p.X,Y=p.Y,Z=p.Z},{Pitch=0,Yaw=0,Roll=0},{path=mesh_path})
    local ok,why=pcall(function()
        local c=d.mesh
        d.actor:SetActorHiddenInGame(true)
        c.VisibilityBasedAnimTickOption=ALWAYS
        c.bDisableClothSimulation=true -- Nobody sees its cloth.
        c:SetComponentTickEnabled(true)
        c:K2_AttachToComponent(main,FName('None'),SNAP,SNAP,SNAP,false)
        c:PlayAnimation(clip,true)
    end)
    if not ok then
        Doro.remove(d)
        error(why,0)
    end
    d.skip=skip
    return d
end
-- Her followers now (skip: an address left out).
function Rig.followers(e,skip)
    local main=main_of(e)
    return pick(parts_of(e),address(main),skip)
end
-- Her main mesh, then each follower, set to copy the rig d's bones. Raises when her main mesh refuses. Returns the
-- followers and how many took the call.
function Rig.hook(e,d)
    local main=main_of(e)
    main:SetMasterPoseComponent(d.mesh,true)
    local list,n=pick(parts_of(e),address(main),d.skip),0
    for _,f in ipairs(list) do
        if pcall(function() f:SetMasterPoseComponent(d.mesh,true) end) then n=n+1 end
    end
    return list,n
end
-- Her main mesh set to copy nothing, then each part of list (hook's) that is still hers and each follower she has now
-- pointed back at her main mesh: each address once, each call in its own pcall. Returns how many went back and how
-- many calls failed. Without her main mesh (her EVE gone) it calls nothing.
function Rig.unhook(e,d,list)
    local main=valid(e) and valid(e.Mesh)
    if not main then return 0,0 end
    local back,failed=0,0
    if not pcall(function() main:SetMasterPoseComponent(nil,true) end) then failed=failed+1 end
    local at,parts=address(main),parts_of(e)
    local todo,seen={},{}
    local function add(c)
        local a=address(c)
        if a~=at and not seen[a] then seen[a]=true; todo[#todo+1]=c end
    end
    -- A part of list that is not hers now is never called: another object can sit at a freed one's address.
    for _,c in ipairs(list or {}) do
        local ok,a=pcall(address,c)
        if ok and parts[a] then add(parts[a]) end
    end
    for _,c in ipairs(pick(parts,at,d.skip)) do add(c) end
    for _,c in ipairs(todo) do
        if pcall(function() c:SetMasterPoseComponent(main,true) end) then back=back+1 else failed=failed+1 end
    end
    return back,failed
end
-- Whether her main mesh still copies the rig d's bones (its MasterPoseComponent).
function Rig.hooked(e,d)
    local main=valid(e) and valid(e.Mesh)
    local leader=main and U.weak(main.MasterPoseComponent)
    local mine=valid(d.mesh)
    return leader~=nil and mine~=nil and address(leader)==address(mine)
end
-- The rig gone, if its actor is still the one made.
Rig.remove=Doro.remove
-- A rig an earlier Lua load made (Ctrl+R), by its actor's path: destroyed with true only while its root shows the mesh
-- at mesh_path.
Rig.sweep=Doro.sweep
return Rig
