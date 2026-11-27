-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- The make and attach steps are a copy of closet/dress.lua's added meshes (its wear's AddComponentByClass loop), with
-- the head socket added; the tag write is a copy of vehicles/bike/ride.lua's (its part's ComponentTags).
-- The head components the closet makes for Glasses, Headwear and Mask (closet/head/wear.lua wears them): EVE's
-- blueprint has none for those slots, and probe 8 read no glasses component while none is worn. A made component has
-- no game original: taking it off destroys it.
--   A piece on the body mesh's skeleton follows her pose (SetMasterPoseComponent), attached with no socket, as the
--   dress's added meshes. Any other piece goes on the head socket Bip001-Head with SBAccSlot1's rotation.
--
-- The game's parts (SB-Win64-Shipping.exe, build 26123051, read 27 Nov 2026):
--   AActor.AddComponentByClass: UFunction params 0x146e19150 (name "AddComponentByClass" 0x1464d0868, flags 0x04c20401
--     BlueprintCallable, block 0x50); its property list 0x1464cf720 runs Class (offset 0), bManualAttachment,
--     RelativeTransform (offset 0x10), bDeferredFinish, then the return value: UE4SS passes them in that order. Its
--     exec is UNREAD (StaticRegisterNativesAActor jumps into obfuscated code): called by name.
--   The class: USBSkeletalMeshComponent, "/Script/SB" (FUN_1427ade70), the one the game's slot spawner FUN_14213a400
--     makes through StaticConstructObject FUN_142b9daf0 with Outer the actor and no name.
--   USceneComponent.K2_AttachToComponent(Parent, SocketName, LocationRule, RotationRule, ScaleRule, bWeldSimulated
--     Bodies): native entry 0x14664bb10 (name 0x1464d1500), exec 0x14490c190 reads them in that order and calls
--     AttachToComponent 0x1441090b0. Rule 2 for all three is the dress's (SnapToTarget, tested in game on 26 Nov 2026).
--   USkinnedMeshComponent.SetMasterPoseComponent(NewMasterBoneComponent, bForceUpdate): native entry 0x14665f180
--     (name 0x14665beb0), exec 0x144928a80.
--   USceneComponent.K2_SetRelativeRotation: exec 0x14490f950 (closet/head/wear.lua's header). The rotation is set
--     after the attach: SnapToTarget zeroes the relative transform.
--   USkinnedMeshComponent.SetSkeletalMesh: exec 0x14492a420 (closet/head/wear.lua's header).
--   UActorComponent.ComponentTags: TArray<FName> (property params 0x1464d6318, name 0x1464d2b20, Array, flags
--     0x0010000000000005 Edit | BlueprintVisible, offset 0x60; its FName inner 0x1464d62c8), in UActorComponent's
--     property list 0x1464d6690 (class params 0x1464d6450, functions from AddTickPrerequisiteActor). Its
--     ComponentHasTag: native entry 0x1464d6ad0 (name 0x1464d2e20), exec 0x1446c1b50 jumps into obfuscated code
--     (body UNREAD); vehicles/bike/ride.lua and world/daynight/daynight.lua use both in game.
local U=require('core.unreal')
local valid,each,text,find=U.valid,U.each,U.text,U.find
local Made={}
Made.CLASS='/Script/SB.SBSkeletalMeshComponent'
local SKINNED='/Script/Engine.SkeletalMeshComponent'
-- Asset data, CH_P_EVE_01_Blueprint SCS_Node_7 (SBAccSlot1, the earrings): socket Bip001-Head, RelativeRotation
-- (Pitch -90, Yaw 180, Roll 90) (head-research/assets_report.md (e)). Glasses use it by inference only: the root
-- bone of ACC_GLA_01M_Skeleton has the ref pose of ACC_EAR_01M_Skeleton's, at EVE's Bip001-Head (the same report);
-- the game's own glasses socket and transform are UNREAD. Schizo's in-game test confirms or corrects it.
Made.SOCKET='Bip001-Head'
Made.ROTATION={Pitch=-90,Yaw=180,Roll=90}
-- The tag that marks a component as the closet's: the game's own (its blueprint's, and the unnamed ones its slot
-- spawner FUN_14213a400 makes) never carry it, so the sweep never destroys one of them.
Made.TAG='SBO_ClosetHead'

-- An object's path (closet/head/wear.lua uses this one too).
function Made.path_of(o)
    local ok,p=pcall(function() return text(o:GetFullName()):match('^%S+ (.+)$') end)
    return ok and p or nil
end
local path_of=Made.path_of

-- A new component on EVE wearing mesh: master-posed to her body when on_body (the body mesh's skeleton), else on the
-- head socket. Returns it and, when its tag did not hold, why (a Lua reload cannot sweep it then). Raises when none
-- is made or a call fails; a component made before the failing call is destroyed first.
function Made.put(eve,mesh,on_body)
    local body=assert(valid(eve.Mesh),'EVE has no body mesh')
    local c=valid(eve:AddComponentByClass(find(Made.CLASS),true,
        {Translation={X=0,Y=0,Z=0},Rotation={X=0,Y=0,Z=0,W=1},Scale3D={X=1,Y=1,Z=1}},false))
    if not c then error('could not make a head component on EVE',0) end
    local ok,why=pcall(function()
        pcall(function() c:SetCollisionEnabled(0) end) -- Never blocks her capsule, the camera or the floor.
        if on_body then
            c:K2_AttachToComponent(body,FName('None'),2,2,2,true)
            c:SetSkeletalMesh(mesh,true)
            c:SetMasterPoseComponent(body,true)
            pcall(function() c.bUseBoundsFromMasterPoseComponent=true end) -- No culling pop.
        else
            c:K2_AttachToComponent(body,FName(Made.SOCKET),2,2,2,true)
            c:K2_SetRelativeRotation(Made.ROTATION,false,{},false)
            c:SetSkeletalMesh(mesh,true)
        end
    end)
    if not ok then
        pcall(Made.destroy,c)
        error(why,0)
    end
    -- A new component's ComponentTags is empty: UE4SS 3.0.1 lands a write at 1 there (vehicles/bike/ride.lua's note).
    local tagged,tag_why=pcall(function()
        c.ComponentTags[1]=FName(Made.TAG)
        assert(c:ComponentHasTag(FName(Made.TAG))==true,'the closet\'s tag did not hold')
    end)
    return c,not tagged and U.why(tag_why) or nil
end

function Made.destroy(c)
    c=valid(c)
    if c then c:K2_DestroyComponent(c) end
end

-- An earlier Lua load's made components off EVE: each with the closet's tag wearing one of meshes ({[path]=true}).
-- Returns how many.
function Made.sweep(eve,meshes)
    local n=0
    each(eve:K2_GetComponentsByClass(find(SKINNED)),function(_,c)
        c=valid(c)
        local mesh=c and valid(c.SkeletalMesh)
        if mesh and meshes[path_of(mesh)] and c:ComponentHasTag(FName(Made.TAG))==true then
            pcall(Made.destroy,c)
            n=n+1
        end
    end)
    return n
end

return Made
