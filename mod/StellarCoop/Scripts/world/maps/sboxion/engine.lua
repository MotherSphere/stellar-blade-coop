-- Copyright (C) 2026 MotherSphere and the Stellar Blade Online contributors
-- SPDX-License-Identifier: LicenseRef-SBO-1.0-or-later
-- SBO License 1.0 or later, in LICENSE and at github.com/MotherSphere/stellar-blade-coop; NOTICE adds a permission.
-- SBO Xion's engine reads and its one write (world/maps/sboxion/sboxion.lua's world), on the game thread: the zone's
-- FName index for the native request, the SBEnvControlVolume actors with their bActiveVolume, the world's streaming
-- levels through the three functions SB's exe exposes by name (GetWorldAssetPackageFName, IsLevelLoaded,
-- IsLevelVisible), the characters and the recovery's calls (world/maps/sboxion/recover.lua): EVE's place and movement
-- mode, the put-back, SB's respawn request and the death screen. sboxion.lua and recover.lua call them only while EVE
-- is in SBO Xion or for a command.
-- bActiveVolume is a plain bool of ASBEnvControlVolume (+0x320 on build 26123051: its set-bit stub 0x14265b310 is
-- mov byte ptr [rcx+0x320],1). SB's env pass 0x1425c99b0, run from its registry's tick 0x142272930, skips a volume
-- whose byte is 0 each time it runs, so a write needs no call.
local U=require('core.unreal')
local N=require('core.player')
local Engine={}
local function eve() return assert(N.her(),'no EVE in the world') end
local function path_of(o) return U.text(o:GetFullName()):match('^%S+ (.+)$') or '' end
-- An FName's index, or nil when this game run has not made the name yet (a row name exists once its row is in).
function Engine.zone_index(alias)
    local n=U.value_of(FName(alias,EFindName.FNAME_Find))
    local index=n:GetComparisonIndex()
    if not index or index==0 or U.text(n):lower()~=alias:lower() then return nil end
    return index
end
-- Every SBEnvControlVolume of EVE's world: its path, get() and set(on) of bActiveVolume on the actor while it lives.
function Engine.volumes()
    local out={}
    for _,a in ipairs((U.actors_of(U.find('/Script/SB.SBEnvControlVolume'),'SBEnvControlVolume',eve()))) do
        local function live() return assert(U.valid(a),'it is gone') end
        out[#out+1]={path=path_of(a),get=function() return live().bActiveVolume==true end,
            set=function(on) live().bActiveVolume=on end}
    end
    return out
end
-- The world's streaming levels: each one's package name without its folders, whether it is loaded and visible. The
-- objects are kept for probes().
local held={}
local function state(name,l) return {name=name,loaded=l:IsLevelLoaded()==true,visible=l:IsLevelVisible()==true} end
function Engine.levels()
    local out={}
    held={}
    U.each(eve():GetWorld().StreamingLevels,function(_,l)
        l=U.valid(l)
        if l then
            local name=U.text(l:GetWorldAssetPackageFName()):match('[^/]+$') or '?'
            held[name]=l
            out[#out+1]=state(name,l)
        end
    end)
    return out
end
-- The levels of names as levels() last listed them, read again: two calls a level. One that is gone reads not loaded.
function Engine.probes(names)
    local out={}
    for _,name in ipairs(names) do
        local l=U.valid(held[name])
        out[#out+1]=l and state(name,l) or {name=name,loaded=false,visible=false}
    end
    return out
end
-- The names of the SBCharacter actors of EVE's world, EVE included.
function Engine.characters()
    local out={}
    for _,c in ipairs((U.actors_of(U.find('/Script/SB.SBCharacter'),'SBCharacter',eve()))) do
        out[#out+1]=U.text(c:GetFName())
    end
    return out
end
-- EVE's place, yaw, movement mode, her world's time and her address, all from one EVE in one call; nil with no EVE.
-- recover.lua reads her through this alone: core/where.lua's me() is refreshed after sboxion.tick in main/pass.lua,
-- so it is one pass old. mode is CharacterMovement.MovementMode (EMovementMode: 1 Walking, 2 NavWalking, 3 Falling),
-- nil with no movement component. time is UGameplayStatics::GetTimeSeconds (exec 0x14475bc80 on build 26123051: the
-- context's world, then the float at world +0x748).
function Engine.move()
    local e=N.her()
    if not e then return nil end
    local at,turn=U.value_of(e:K2_GetActorLocation()),U.value_of(e:K2_GetActorRotation())
    local move=U.valid(e.CharacterMovement)
    return {at={X=at.X,Y=at.Y,Z=at.Z},yaw=turn.Yaw,mode=move and move.MovementMode or nil,
        time=U.find('/Script/Engine.Default__GameplayStatics'):GetTimeSeconds(e),pawn=U.address(e)}
end
-- Puts EVE at a place facing yaw; false when the game refused. K2_TeleportTo's exec 0x1446b65a0 calls the actor's
-- vtable +0x548 with (location, rotation, 0, 0): the two zeros leave the engine's test of the spot on, so the call
-- can refuse. Then StopMovementImmediately (exec 0x14488dd80, a jump to the movement component's vtable +0x440), so a
-- fall's speed does not go on at the new place. No stop call follows a refusal. The movement mode is left alone.
function Engine.put(at,yaw)
    local e=eve()
    if e:K2_TeleportTo({X=at.X,Y=at.Y,Z=at.Z},{Pitch=0,Yaw=yaw,Roll=0})==false then return false end
    local move=U.valid(e.CharacterMovement)
    if move then move:StopMovementImmediately() end
    return true
end
-- The respawn's pieces: the SB player controller (or nil), whether the game is standalone, and SB's in-place respawn
-- of the actor of GUID me. ServerRequest_ActorRespawn's exec 0x1427639f0 reads an int and a bool and calls the
-- controller's vtable +0x1488 (0x1423bf600), which queues the job FSBActorRespawn. With the bool false the job's
-- Simulate 0x141b10b30 does not move the actor to a camp. It reads no zone type.
function Engine.controller() return N.controller() end
function Engine.standalone(pc)
    return U.find('/Script/Engine.Default__KismetSystemLibrary'):IsStandalone(pc)==true
end
function Engine.respawn(pc,me) pc:ServerRequest_ActorRespawn(me,false) end
-- The death screen (core/unreal.lua's death_screen), kept while its widget lives. screen(look): true while one of its
-- animations plays, false when none does, nil with no widget; it is looked for only when look is true, since the
-- search walks the object array. hide(): hides the kept widget and returns the call that shows it again as it was,
-- or nil with no widget.
local HIDDEN=2 -- ESlateVisibility Hidden.
local dead_screen=nil
function Engine.screen(look)
    if not U.valid(dead_screen) then dead_screen=look and U.death_screen() or nil end
    if not dead_screen then return nil end
    return dead_screen:IsAnyAnimationPlaying()==true
end
function Engine.hide()
    local s=U.valid(dead_screen)
    if not s then return nil end
    local was=s:GetVisibility()
    s:SetVisibility(HIDDEN)
    return function() if U.valid(s) then s:SetVisibility(was) end end
end
return Engine
