-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The Doro look's actor and display helpers, moved out of online/modes/race/doro.lua for every module to read.
-- resolve, attach, spawn, sweep, remove, apply and same also show another mesh (fight/bosses/leviathan.lua's coop
-- leviathan); attach, spawn, sweep and remove also make and remove its free camera, a plain actor with one
-- CameraComponent.
local U=require('core.unreal')
local valid,find=U.valid,U.find
local Doro={}
local DIR='/Game/DLC_2/Art/Character/NPC/CH_NPC_Dororong/'
local function asset(path) return DIR..path..'.'..path:match('[^/]+$') end
-- What pick() names, by key.
Doro.ASSETS={mesh=asset('CH_NPC_Dororong'),
    two=asset('BlendSpace/IdleRun_BS_Peaceful_2'), -- Idle at 0, Move_Bipedal at 500.
    four=asset('BlendSpace/IdleRun_BS_Peaceful_1'), -- Idle at 0, Move_Quadrupedal at 500.
    evade=asset('Animation/N_Dororong_Evade'),exhaust=asset('Animation/N_Dororong_Exhaust'),
    stumble=asset('Animation/N_Dororong_Exhaust_Evade'), -- A tired hop, 1.2 s: a wall hit in a race.
    idle=asset('Animation/N_Dororong_Idle'),turn=asset('Animation/N_Dororong_Turn_90L'),
    meet1=asset('Animation/event/MV_Nikke_Dororong_1stMeet/MV_Nikke_Dororong_1stMeet_dororong_01'),
    meet3=asset('Animation/event/MV_Nikke_Dororong_1stMeet/MV_Nikke_Dororong_1stMeet_dororong_03')}
local MESH,ANIM,STATIC='/Script/Engine.SkeletalMesh','/Script/Engine.AnimationAsset','/Script/Engine.StaticMesh'
local SKINNED,SOLID='/Script/Engine.SkeletalMeshComponent','/Script/Engine.StaticMeshComponent'
local CAMERA='/Script/Engine.CameraComponent'
local SCALE=1.5 -- The game's own: CharacterTable N_Dororong, MeshScale. About 59 cm tall.
local KEEP_RELATIVE=0 -- EAttachmentRule::KeepRelative
local function path_of(o) return o:GetFullName():match('^%S+ (.+)$') end
-- o while it is still the object met at path: after travel a new object can sit at a freed one's address, and valid()
-- alone passes it.
local function same(o,path)
    o=valid(o)
    return o and path_of(o)==path and o or nil
end
Doro.same=same
-- Doro's own assets (under DIR) found or loaded again after the engine collected them: their count and ms, for the
-- look's minute line. Another mesh's (coop leviathan's) are not counted. A Doro made after none stood for a while loads
-- them again, at its making, so the look sets both to 0 once its Doro is made; its keepers (attach) then hold every
-- clip while it stands, and this stays 0.
Doro.reloads={n=0,ms=0}
local cache={}
-- An asset by its object path: in memory already, else loaded (LoadAsset, synchronous); nil when neither gives one of
-- that class. A cached one is used again only while it is still that object (online/partner/puppet.lua's rule), and its
-- class is checked at each call: coop leviathan list caches a path as any Object before show asks for a mesh.
function Doro.resolve(path,class)
    local a=same(cache[path],path)
    if not a then
        local started,again=os.clock(),cache[path]~=nil
        a=valid(StaticFindObject(path))
        if not a then
            local ok,loaded=pcall(LoadAsset,path)
            a=ok and valid(loaded) or nil
        end
        if again and path:sub(1,#DIR)==DIR then
            Doro.reloads.n,Doro.reloads.ms=Doro.reloads.n+1,Doro.reloads.ms+(os.clock()-started)*1000
        end
        cache[path]=a
    end
    return a and a:IsA(find(class or ANIM)) and a or nil
end
local function name_of(look)
    return look and (look.camera and 'the camera' or look.path:match('[^.]+$')) or 'the Doro'
end
-- The engine's collector unloads an asset nothing of the engine's references (a Lua reference is none), and the next
-- PlayAnimation then loaded it again, synchronously (in game: 5 loads a minute, 185 ms in all, while she sprinted). A
-- Doro carries one keeper per clip of ASSETS, added to keepers: a SkeletalMeshComponent with Doro's mesh whose
-- single-node instance holds the clip (its CurrentAsset, a UPROPERTY, through SetAnimation). Never drawn (bVisible
-- off, so no render proxy), never ticking, its pose never ticked (VisibilityBasedAnimTickOption 3: only while drawn),
-- collision off, unattached (never moved). A clip not in memory is loaded here, when a Doro is made, never in the
-- middle of a race. A clip missing on this PC gets none: apply says so if it is played.
local function keep(actor,mesh,identity,keepers)
    for key,path in pairs(Doro.ASSETS) do
        local clip=key~='mesh' and Doro.resolve(path)
        if clip then
            local k=assert(valid(actor:AddComponentByClass(find(SKINNED),true,identity,false)),
                'a keeper could not be added')
            keepers[#keepers+1]=k
            k:SetVisibility(false,false)
            k:SetComponentTickEnabled(false)
            k.VisibilityBasedAnimTickOption=3 -- OnlyTickPoseWhenRendered
            k:SetCollisionEnabled(0)
            k:SetSkeletalMesh(mesh,true)
            k:SetAnimationMode(1) -- AnimationSingleNode
            k:SetAnimation(clip)
        end
    end
end
-- A Doro component on actor, hung on parent when given (KeepRelative: where the parent is), else the actor's root.
-- look: another mesh, {path=<its object path>, static=true for a StaticMesh}, at scale 1, a static one with no
-- animation mode; or {camera=true}, a CameraComponent alone. Returns the display {mesh=<component>, keepers=<a Doro's
-- keepers, one a clip>}; raises, with no component left, when it cannot be made.
function Doro.attach(actor,parent,look)
    local identity=find('/Script/Engine.Default__KismetMathLibrary'):MakeTransform({X=0,Y=0,Z=0},
        {Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1})
    if look and look.camera then
        return {mesh=assert(valid(actor:AddComponentByClass(find(CAMERA),false,identity,false)),
            'the camera could not be added')}
    end
    local static,name=look and look.static,name_of(look)
    local mesh=assert(Doro.resolve(look and look.path or Doro.ASSETS.mesh,static and STATIC or MESH),
        (look and name or 'the Doro mesh')..' is missing on this PC')
    local c=valid(actor:AddComponentByClass(find(static and SOLID or SKINNED),false,identity,false))
    assert(c,name..' could not be added')
    local d={mesh=c,keepers={}}
    local ok,why=pcall(function()
        if parent then
            c:K2_AttachToComponent(parent,FName('None'),KEEP_RELATIVE,KEEP_RELATIVE,KEEP_RELATIVE,false)
        end
        if static then c:SetStaticMesh(mesh) else c:SetSkeletalMesh(mesh,true) end
        local scale=look and 1 or SCALE
        c:SetRelativeScale3D({X=scale,Y=scale,Z=scale})
        c:SetCollisionEnabled(0)
        if not static then c:SetAnimationMode(1) end -- AnimationSingleNode
        if not look then keep(actor,mesh,identity,d.keepers) end
    end)
    if not ok then
        pcall(Doro.detach,d,actor)
        error(why,0)
    end
    return d
end
-- A display of attach()'s taken off actor while the actor stays (the ghost's Doro mode): its keepers destroyed, each
-- in its own pcall, then its component, which raises when it fails.
function Doro.detach(d,actor)
    for _,k in ipairs(d.keepers or {}) do pcall(function() k:K2_DestroyComponent(actor) end) end
    d.mesh:K2_DestroyComponent(actor)
end
-- A Doro of its own in world, at and turned as given (look: attach's): {actor=, path=<the actor's>, mesh=}. Raises,
-- with nothing left, when it fails.
function Doro.spawn(world,at,rotation,look)
    local actor=valid(world:SpawnActor(find('/Script/Engine.Actor'),at,rotation))
    assert(actor,name_of(look)..' could not be spawned')
    local ok,d=pcall(function()
        actor:SetActorEnableCollision(false,false)
        local d=Doro.attach(actor,nil,look)
        d.mesh:K2_SetWorldLocationAndRotation(at,rotation,false,{},true) -- The root was added at the origin.
        d.path=path_of(actor)
        return d
    end)
    if not ok then
        actor:K2_DestroyActor()
        error(d,0)
    end
    d.actor=actor
    return d
end
-- A Doro an earlier Lua load spawned (Ctrl+R), by its actor's path: gone, and true, only while that actor's root still
-- shows Doro's mesh (mesh: that other mesh's object path; 'camera': a free camera's root, a CameraComponent), so never
-- another object found at that path.
function Doro.sweep(p,mesh)
    local doro=p and valid(StaticFindObject(p))
    local root=doro and valid(doro:K2_GetRootComponent())
    local shows
    if mesh=='camera' then shows=root and root:IsA(find(CAMERA))
    else
        shows=root and (root:IsA(find(SKINNED)) and valid(root.SkeletalMesh)
            or root:IsA(find(SOLID)) and valid(root.StaticMesh))
        shows=shows and path_of(shows)==(mesh or Doro.ASSETS.mesh)
    end
    if shows then
        doro:K2_DestroyActor()
        return true
    end
end
-- A Doro of spawn()'s gone, if its actor is still the one spawn() made: never a call on another object.
function Doro.remove(d)
    local a=same(d.actor,d.path)
    if a then a:K2_DestroyActor() end
end
-- One choice of pick() on a display: PlayAnimation only when the clip or its looping changes, then the blend space
-- input, the play rate and the position (without notifies) as given. c.asset: a key of ASSETS, or an object path.
function Doro.apply(d,c)
    local m=d.mesh
    if c.asset~=d.asset or c.loop~=d.loop then
        m:PlayAnimation(assert(Doro.resolve(Doro.ASSETS[c.asset] or c.asset),c.asset..' is missing on this PC'),c.loop)
        d.asset,d.loop=c.asset,c.loop
    end
    if c.input then m:GetAnimInstance():SetBlendSpaceInput({X=c.input,Y=0,Z=0}) end
    m:SetPlayRate(c.rate)
    if c.at then m:SetPosition(c.at,false) end
end
return Doro
